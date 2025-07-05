defmodule EveDmv.Security.ApiAuthentication do
  @moduledoc """
  API authentication and API key management.

  Handles creation, validation, and revocation of API keys for external access.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("api_keys")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :api_key, :string do
      allow_nil?(false)
      constraints(min_length: 32, max_length: 64)
    end

    attribute :character_id, :integer do
      allow_nil?(false)
    end

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
    end

    attribute :permissions, {:array, :string} do
      default([])
    end

    attribute(:last_used_at, :utc_datetime)
    attribute(:last_used_ip, :string)

    attribute :is_active, :boolean do
      default(true)
    end

    attribute(:expires_at, :utc_datetime)

    timestamps()
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:character_id, :name, :permissions, :expires_at])

      change(fn changeset, _context ->
        api_key = generate_api_key()
        Ash.Changeset.change_attribute(changeset, :api_key, api_key)
      end)
    end

    update :use_api_key do
      accept([:last_used_at, :last_used_ip])
    end

    update :deactivate do
      accept([])
      change(set_attribute(:is_active, false))
    end

    read :by_character do
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id) and is_active == true))
      prepare(build(sort: [created_at: :desc]))
    end

    read :by_api_key do
      argument(:api_key, :string, allow_nil?: false)
      filter(expr(api_key == ^arg(:api_key) and is_active == true))
    end

    read :by_id_and_character do
      argument(:id, :uuid, allow_nil?: false)
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(id == ^arg(:id) and character_id == ^arg(:character_id)))
    end
  end

  # Public API functions

  @doc """
  List API keys for a character.
  """
  def list_character_api_keys(character_id) do
    __MODULE__
    |> Ash.ActionInput.for_action(:by_character, %{character_id: character_id})
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Create a new API key for a character.
  """
  def create_api_key(character_id, name, permissions \\ [], expires_at \\ nil) do
    %{
      character_id: character_id,
      name: name,
      permissions: permissions,
      expires_at: expires_at
    }
    |> Ash.create!(__MODULE__, :create, domain: EveDmv.Api)
  end

  @doc """
  Validate an API key and return the associated character information.
  """
  def validate_api_key(api_key, client_ip, required_permissions \\ []) do
    case __MODULE__
         |> Ash.ActionInput.for_action(:by_api_key, %{api_key: api_key})
         |> Ash.read_one(domain: EveDmv.Api) do
      {:ok, key_record} when not is_nil(key_record) ->
        cond do
          key_expired?(key_record) ->
            {:error, :expired}

          not has_required_permissions?(key_record, required_permissions) ->
            {:error, :insufficient_permissions}

          true ->
            # Update last used info
            update_last_used(key_record, client_ip)
            {:ok, key_record}
        end

      {:ok, nil} ->
        {:error, :invalid_api_key}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Revoke an API key.
  """
  def revoke_api_key(api_key_id, character_id) do
    case __MODULE__
         |> Ash.ActionInput.for_action(:by_id_and_character, %{
           id: api_key_id,
           character_id: character_id
         })
         |> Ash.read_one(domain: EveDmv.Api) do
      {:ok, api_key} when not is_nil(api_key) ->
        Ash.update!(api_key, :deactivate, %{}, domain: EveDmv.Api)

      {:ok, nil} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Check if an API key has a specific permission.
  """
  def has_permission?(api_key_record, permission) do
    permission in (api_key_record.permissions || [])
  end

  # Private helper functions

  defp has_required_permissions?(key_record, required_permissions) do
    key_permissions = key_record.permissions || []
    Enum.all?(required_permissions, fn perm -> perm in key_permissions end)
  end

  defp generate_api_key do
    :crypto.strong_rand_bytes(32)
    |> Base.encode64()
    |> binary_part(0, 32)
    |> String.replace(["+", "/", "="], "")
  end

  defp key_expired?(%{expires_at: nil}), do: false

  defp key_expired?(%{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :gt
  end

  defp update_last_used(key_record, client_ip) do
    Ash.update!(
      key_record,
      :use_api_key,
      %{
        last_used_at: DateTime.utc_now(),
        last_used_ip: client_ip
      },
      domain: EveDmv.Api
    )
  end
end
