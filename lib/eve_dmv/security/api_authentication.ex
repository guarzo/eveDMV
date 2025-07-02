defmodule EveDmv.Security.ApiAuthentication do
  @moduledoc """
  API key authentication for internal endpoints and service-to-service communication.

  This module provides secure API key generation, validation, and management
  for internal API endpoints that need programmatic access.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  require Logger
  alias EveDmv.Security.AuditLogger

  postgres do
    table("api_keys")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      description("Human-readable name for the API key")
    end

    attribute :key_hash, :string do
      allow_nil?(false)
      description("SHA-256 hash of the API key")
    end

    attribute :prefix, :string do
      allow_nil?(false)
      description("Public prefix for key identification")
    end

    attribute :permissions, {:array, :string} do
      allow_nil?(false)
      default([])
      description("List of permissions granted to this API key")
    end

    attribute :last_used_at, :utc_datetime_usec do
      description("When this API key was last used")
    end

    attribute :last_used_ip, :string do
      description("IP address from last usage")
    end

    attribute :expires_at, :utc_datetime_usec do
      description("When this API key expires (optional)")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this API key is active")
    end

    attribute :created_by_character_id, :integer do
      allow_nil?(false)
      description("Character ID that created this API key")
    end

    timestamps()
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:name, :permissions, :expires_at, :created_by_character_id])

      change(fn changeset, _context ->
        if changeset.valid? do
          {api_key, key_hash, prefix} = generate_api_key()

          changeset
          |> Ash.Changeset.change_attribute(:key_hash, key_hash)
          |> Ash.Changeset.change_attribute(:prefix, prefix)
          |> Ash.Changeset.set_context(%{generated_key: api_key})
        else
          changeset
        end
      end)
    end

    update :update do
      accept([:name, :permissions, :expires_at, :is_active])
    end

    update :record_usage do
      accept([:last_used_at, :last_used_ip])
    end

    read :by_prefix do
      argument(:prefix, :string, allow_nil?: false)
      filter(expr(prefix == ^arg(:prefix)))
    end

    read :active_keys do
      filter(expr(is_active == true and (is_nil(expires_at) or expires_at > now())))
    end
  end

  @doc """
  Generate a new API key with secure random values.

  Returns {full_api_key, key_hash, prefix} tuple.
  """
  @spec generate_api_key() :: {String.t(), String.t(), String.t()}
  def generate_api_key do
    # Generate a secure random key
    key_bytes = :crypto.strong_rand_bytes(32)
    key_base64 = Base.encode64(key_bytes, padding: false)

    # Create prefix for identification (first 8 chars)
    prefix = String.slice(key_base64, 0, 8)

    # Full API key format: edv_<prefix>_<key>
    full_key = "edv_#{prefix}_#{key_base64}"

    # Hash for storage
    key_hash = :crypto.hash(:sha256, full_key) |> Base.encode16(case: :lower)

    {full_key, key_hash, prefix}
  end

  @doc """
  Validate an API key and check permissions.

  Returns {:ok, api_key_record} if valid, {:error, reason} if invalid.
  """
  @spec validate_api_key(String.t(), String.t(), [String.t()]) ::
          {:ok, term()} | {:error, atom()}
  def validate_api_key(api_key, client_ip, required_permissions \\ []) do
    with {:ok, prefix} <- extract_prefix(api_key),
         {:ok, api_key_record} <- find_by_prefix(prefix),
         :ok <- verify_key_hash(api_key, api_key_record.key_hash),
         :ok <- check_expiration(api_key_record),
         :ok <- check_active_status(api_key_record),
         :ok <- check_permissions(api_key_record, required_permissions) do
      # Record usage
      record_key_usage(api_key_record, client_ip)

      # Log successful authentication
      AuditLogger.log_data_access(
        api_key_record.created_by_character_id,
        :api_key_auth,
        api_key_record.id,
        :authenticate
      )

      {:ok, api_key_record}
    else
      {:error, reason} ->
        # Log failed authentication attempt
        AuditLogger.log_suspicious_activity(
          nil,
          client_ip,
          :invalid_api_key,
          %{reason: reason, key_prefix: extract_prefix_safe(api_key)}
        )

        {:error, reason}
    end
  end

  @doc """
  Check if an API key has specific permissions.
  """
  @spec has_permission?(term(), String.t()) :: boolean()
  def has_permission?(api_key, required_permission) do
    permissions = Map.get(api_key, :permissions, [])
    required_permission in permissions or "admin" in permissions
  end

  @doc """
  Revoke an API key by setting it inactive.
  """
  @spec revoke_api_key(String.t(), integer()) :: {:ok, term()} | {:error, term()}
  def revoke_api_key(api_key_id, revoked_by_character_id) do
    case Ash.get(__MODULE__, api_key_id, domain: EveDmv.Api) do
      {:ok, api_key} ->
        result = Ash.update(api_key, :update, %{is_active: false}, domain: EveDmv.Api)

        # Log the revocation
        AuditLogger.log_config_change(
          "character_#{revoked_by_character_id}",
          :api_key_revocation,
          "active",
          "revoked"
        )

        result

      error ->
        error
    end
  end

  @doc """
  List API keys for a character with usage statistics.
  """
  @spec list_character_api_keys(integer()) :: {:ok, [map()]} | {:error, term()}
  def list_character_api_keys(character_id) do
    __MODULE__
    |> Ash.Query.filter(created_by_character_id == character_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read(domain: EveDmv.Api)
    |> case do
      {:ok, api_keys} ->
        keys_with_stats = Enum.map(api_keys, &format_key_for_display/1)
        {:ok, keys_with_stats}

      error ->
        error
    end
  end

  # Private helper functions

  defp extract_prefix("edv_" <> rest) do
    case String.split(rest, "_", parts: 2) do
      [prefix, _key] when byte_size(prefix) == 8 -> {:ok, prefix}
      _ -> {:error, :invalid_format}
    end
  end

  defp extract_prefix(_), do: {:error, :invalid_format}

  defp extract_prefix_safe(api_key) do
    case extract_prefix(api_key) do
      {:ok, prefix} -> prefix
      _ -> "invalid"
    end
  end

  defp find_by_prefix(prefix) do
    case Ash.read(__MODULE__, actor: nil, action: :by_prefix, prefix: prefix, domain: EveDmv.Api) do
      {:ok, [api_key]} -> {:ok, api_key}
      {:ok, []} -> {:error, :not_found}
      {:ok, _multiple} -> {:error, :duplicate_prefix}
      error -> error
    end
  end

  defp verify_key_hash(api_key, stored_hash) do
    computed_hash = :crypto.hash(:sha256, api_key) |> Base.encode16(case: :lower)

    if secure_compare(computed_hash, stored_hash) do
      :ok
    else
      {:error, :invalid_key}
    end
  end

  defp secure_compare(a, b) when byte_size(a) == byte_size(b) do
    :crypto.hash_equals(a, b)
  end

  defp secure_compare(_, _), do: false

  defp check_expiration(%{expires_at: nil}), do: :ok

  defp check_expiration(%{expires_at: expires_at}) do
    if DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
      :ok
    else
      {:error, :expired}
    end
  end

  defp check_active_status(%{is_active: true}), do: :ok
  defp check_active_status(%{is_active: false}), do: {:error, :inactive}

  defp check_permissions(_api_key, []), do: :ok

  defp check_permissions(api_key, required_permissions) do
    if Enum.all?(required_permissions, &has_permission?(api_key, &1)) do
      :ok
    else
      {:error, :insufficient_permissions}
    end
  end

  defp record_key_usage(api_key, client_ip) do
    # Update last used timestamp and IP in the background
    Task.start(fn ->
      try do
        Ash.update(
          api_key,
          :record_usage,
          %{
            last_used_at: DateTime.utc_now(),
            last_used_ip: client_ip
          },
          domain: EveDmv.Api
        )
      rescue
        error ->
          Logger.warning("Failed to record API key usage", %{
            error: inspect(error),
            api_key_id: api_key.id
          })
      end
    end)
  end

  defp format_key_for_display(api_key) do
    %{
      id: api_key.id,
      name: api_key.name,
      prefix: api_key.prefix,
      permissions: api_key.permissions,
      last_used_at: api_key.last_used_at,
      last_used_ip: api_key.last_used_ip,
      expires_at: api_key.expires_at,
      is_active: api_key.is_active,
      created_at: api_key.inserted_at
    }
  end
end
