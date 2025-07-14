defmodule EveDmv.Users.User do
  @moduledoc """
  User resource representing EVE Online characters authenticated via EVE SSO.

  Each user represents an EVE character and can have multiple characters
  linked to the same account for character switching functionality.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    authorizers: [Ash.Policy.Authorizer]

  authentication do
    # EVE SSO OAuth2 authentication strategy
    strategies do
      oauth2 :eve_sso do
        client_id(&get_eve_sso_config/2)
        client_secret(&get_eve_sso_config/2)
        base_url("https://login.eveonline.com")
        authorize_url("/v2/oauth/authorize")
        token_url("/v2/oauth/token")
        user_url("https://esi.evetech.net/verify/")
        redirect_uri(&get_eve_sso_config/2)
        authorization_params(scope: "publicData")
        auth_method(:client_secret_basic)
      end
    end

    tokens do
      enabled?(true)
      token_resource(EveDmv.Users.Token)
      signing_secret(&__MODULE__.signing_secret/2)
      require_token_presence_for_authentication?(true)
    end
  end

  postgres do
    table("users")
    repo(EveDmv.Repo)
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
  end

  # Attributes
  attributes do
    # Primary key
    uuid_primary_key(:id)

    # EVE character information
    attribute :eve_character_id, :integer do
      allow_nil?(false)
      constraints(min: 1)
      description("EVE Online Character ID from ESI")
    end

    attribute :eve_character_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("EVE Online Character Name")
    end

    # Corporation information
    attribute :eve_corporation_id, :integer do
      allow_nil?(true)
      description("EVE Online Corporation ID")
    end

    attribute :eve_corporation_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("EVE Online Corporation Name")
    end

    # Alliance information
    attribute :eve_alliance_id, :integer do
      allow_nil?(true)
      description("EVE Online Alliance ID")
    end

    attribute :eve_alliance_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("EVE Online Alliance Name")
    end

    # OAuth tokens
    # Security: Tokens are marked as sensitive which prevents them from being
    # included in logs and limits their exposure. For additional security,
    # consider implementing field-level encryption for these tokens.
    attribute :access_token, :string do
      allow_nil?(true)
      sensitive?(true)
      description("EVE SSO Access Token")
    end

    attribute :refresh_token, :string do
      allow_nil?(true)
      sensitive?(true)
      description("EVE SSO Refresh Token")
    end

    attribute :token_expires_at, :utc_datetime do
      allow_nil?(true)
      description("When the access token expires")
    end

    attribute :scopes, {:array, :string} do
      allow_nil?(true)
      default([])
      description("EVE SSO scopes granted")
    end

    # Activity tracking
    attribute :last_login_at, :utc_datetime do
      allow_nil?(true)
      description("Last time the user logged in")
    end

    # Admin privileges
    attribute :is_admin, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this user has admin privileges")
    end

    # Automatic timestamps
    timestamps()
  end

  # Identities for authentication
  identities do
    identity :unique_eve_character, [:eve_character_id] do
      description("Each EVE character can only have one user account")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create action for EVE SSO registration
    create :register_with_eve_sso do
      description("Register a new user from EVE SSO authentication")
      upsert?(true)
      upsert_identity(:unique_eve_character)

      accept([
        :eve_character_id,
        :eve_character_name,
        :eve_corporation_id,
        :eve_corporation_name,
        :eve_alliance_id,
        :eve_alliance_name,
        :access_token,
        :refresh_token,
        :token_expires_at,
        :scopes
      ])

      argument :user_info, :map do
        allow_nil?(false)
        description("User info from OAuth2 provider")
      end

      argument :oauth_tokens, :map do
        allow_nil?(false)
        description("OAuth2 tokens from provider")
      end

      change(AshAuthentication.GenerateTokenChange)

      change(fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        oauth_tokens = Ash.Changeset.get_argument(changeset, :oauth_tokens)

        # EVE SSO provides user_info and oauth_tokens

        # Extract EVE SSO data using helper function
        %{
          character_id: character_id,
          character_name: character_name,
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at
        } = extract_eve_sso_data(user_info, oauth_tokens)

        changeset
        |> Ash.Changeset.change_attribute(:eve_character_id, character_id)
        |> Ash.Changeset.change_attribute(:eve_character_name, character_name)
        |> Ash.Changeset.change_attribute(:access_token, access_token)
        |> Ash.Changeset.change_attribute(:refresh_token, refresh_token)
        |> Ash.Changeset.change_attribute(:token_expires_at, expires_at)
        |> Ash.Changeset.change_attribute(:last_login_at, DateTime.utc_now())
        |> maybe_update_corporation_info(user_info)
      end)
    end

    # Sign in action for existing users
    create :sign_in_with_eve_sso do
      description("Sign in an existing user via EVE SSO")
      upsert?(true)
      upsert_identity(:unique_eve_character)

      accept([
        :eve_character_id,
        :eve_character_name,
        :access_token,
        :refresh_token,
        :token_expires_at
      ])

      argument :user_info, :map do
        allow_nil?(false)
        description("User info from OAuth2 provider")
      end

      argument :oauth_tokens, :map do
        allow_nil?(false)
        description("OAuth2 tokens from provider")
      end

      change(AshAuthentication.GenerateTokenChange)

      change(fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        oauth_tokens = Ash.Changeset.get_argument(changeset, :oauth_tokens)

        # Extract EVE SSO data using helper function
        %{
          character_id: character_id,
          character_name: character_name,
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at
        } = extract_eve_sso_data(user_info, oauth_tokens)

        changeset
        |> Ash.Changeset.change_attribute(:eve_character_id, character_id)
        |> Ash.Changeset.change_attribute(:eve_character_name, character_name)
        |> Ash.Changeset.change_attribute(:access_token, access_token)
        |> Ash.Changeset.change_attribute(:refresh_token, refresh_token)
        |> Ash.Changeset.change_attribute(:token_expires_at, expires_at)
        |> Ash.Changeset.change_attribute(:last_login_at, DateTime.utc_now())
        |> maybe_update_corporation_info(user_info)
      end)
    end

    # Update login timestamp
    update :update_last_login do
      description("Update the last login timestamp")
      accept([])

      change(set_attribute(:last_login_at, &DateTime.utc_now/0))
    end

    # Refresh token action
    update :refresh_token do
      description("Refresh the EVE SSO token")

      accept([:access_token, :refresh_token, :token_expires_at])
    end

    # Admin promotion action (only for existing admins)
    update :promote_to_admin do
      description("Promote a user to admin status")
      accept([:is_admin])
    end
  end

  # Authorization policies
  policies do
    # Allow anyone to register (they need valid EVE SSO)
    policy action_type(:create) do
      authorize_if(always())
    end

    # Users can read their own data
    policy action_type(:read) do
      authorize_if(actor_attribute_equals(:id, :id))
    end

    # Users can update their own data (except admin promotion)
    policy action_type(:update) do
      forbid_if(action(:promote_to_admin))
      authorize_if(actor_attribute_equals(:id, :id))
    end

    # Only admins can promote users to admin
    policy action(:promote_to_admin) do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end

    # Only admins can destroy users
    policy action_type(:destroy) do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end
  end

  # Private functions
  defp maybe_update_corporation_info(changeset, _user_info) do
    # Extract character ID to fetch corporation info
    character_id = Ash.Changeset.get_attribute(changeset, :eve_character_id)
    access_token = Ash.Changeset.get_attribute(changeset, :access_token)

    require Logger

    Logger.info(
      "ESI Corp Integration Debug - Character ID: #{character_id}, Has Token: #{!!access_token}"
    )

    if character_id && access_token do
      Logger.info("Attempting to fetch corp info for character #{character_id}")

      case fetch_character_corporation_info(character_id, access_token) do
        {:ok, corp_info} ->
          Logger.info("Successfully fetched corp info: #{inspect(corp_info)}")

          changeset
          |> Ash.Changeset.change_attribute(:eve_corporation_id, corp_info.corporation_id)
          |> Ash.Changeset.change_attribute(:eve_corporation_name, corp_info.corporation_name)
          |> Ash.Changeset.change_attribute(:eve_alliance_id, corp_info.alliance_id)
          |> Ash.Changeset.change_attribute(:eve_alliance_name, corp_info.alliance_name)

        {:error, reason} ->
          Logger.warning(
            "Failed to fetch corporation info for character #{character_id}: #{inspect(reason)}"
          )

          changeset
      end
    else
      Logger.warning("Missing character_id (#{character_id}) or access_token for corp fetch")
      changeset
    end
  end

  defp fetch_character_corporation_info(character_id, _access_token) do
    require Logger
    Logger.info("Fetching corp info from ESI for character #{character_id}")

    # Direct ESI call to avoid fallback strategy issues
    path = "/v4/characters/#{character_id}/"

    case EveDmv.Eve.EsiRequestClient.public_request("GET", path) do
      {:ok, character_response} ->
        Logger.info("Got character response: #{inspect(character_response)}")

        # Handle potential double-wrapping from the request client
        actual_response =
          case character_response do
            {:ok, inner_response} -> inner_response
            {:error, _} = error -> error
            response -> response
          end

        character_data =
          case actual_response do
            {:error, _} -> %{}
            response when is_map(response) -> Map.get(response, :body, %{})
            _ -> %{}
          end

        Logger.info(
          "Character data: #{inspect(Map.take(character_data, ["corporation_id", "name"]))}"
        )

        corporation_id = Map.get(character_data, "corporation_id")

        if corporation_id do
          Logger.info("Fetching corporation #{corporation_id}")

          corp_path = "/v4/corporations/#{corporation_id}/"

          case EveDmv.Eve.EsiRequestClient.public_request("GET", corp_path) do
            {:ok, corp_response} ->
              # Handle potential double-wrapping from the request client
              actual_corp_response =
                case corp_response do
                  {:ok, inner_response} -> inner_response
                  {:error, _} = error -> error
                  response -> response
                end

              corp_data =
                case actual_corp_response do
                  {:error, _} -> %{}
                  response when is_map(response) -> Map.get(response, :body, %{})
                  _ -> %{}
                end

              Logger.info(
                "Got corporation data: #{inspect(Map.take(corp_data, ["name", "alliance_id"]))}"
              )

              alliance_id = Map.get(corp_data, "alliance_id")

              alliance_name =
                if alliance_id do
                  Logger.info("Fetching alliance info for alliance #{alliance_id}")

                  case fetch_alliance_info(alliance_id) do
                    {:ok, alliance} ->
                      name = Map.get(alliance, :name) || Map.get(alliance, "name")
                      Logger.info("Got alliance name: #{name}")
                      name

                    error ->
                      Logger.warning("Failed to fetch alliance info: #{inspect(error)}")
                      nil
                  end
                else
                  Logger.info("No alliance for this corporation")
                  nil
                end

              result = %{
                corporation_id: corporation_id,
                corporation_name: Map.get(corp_data, "name"),
                alliance_id: alliance_id,
                alliance_name: alliance_name
              }

              Logger.info("Final corp info result: #{inspect(result)}")
              {:ok, result}

            error ->
              Logger.error("Failed to fetch corporation data: #{inspect(error)}")
              error
          end
        else
          Logger.error("No corporation_id found in character data")
          {:error, :no_corporation_id}
        end

      error ->
        Logger.error("ESI character fetch failed: #{inspect(error)}")
        error
    end
  end

  defp fetch_alliance_info(alliance_id) when is_integer(alliance_id) do
    # Use ESI to fetch alliance info
    path = "/v3/alliances/#{alliance_id}/"

    case EveDmv.Eve.EsiRequestClient.get_request(path) do
      {:ok, response} ->
        # Handle potential double-wrapping from the request client
        actual_response =
          case response do
            {:ok, inner_response} -> inner_response
            response -> response
          end

        body =
          case actual_response do
            %{body: body} -> body
            other -> other
          end

        alliance = %{
          alliance_id: alliance_id,
          name: Map.get(body, "name"),
          ticker: Map.get(body, "ticker")
        }

        {:ok, alliance}

      error ->
        error
    end
  end

  defp fetch_alliance_info(_), do: {:error, :invalid_alliance_id}

  def signing_secret(_resource, _opts) do
    # Always use SECRET_KEY_BASE for token signing
    case Application.get_env(:eve_dmv, EveDmvWeb.Endpoint)[:secret_key_base] do
      nil -> {:error, "You must configure SECRET_KEY_BASE"}
      secret -> {:ok, secret}
    end
  end

  # Helper function to extract EVE SSO data from user_info and oauth_tokens
  defp extract_eve_sso_data(user_info, oauth_tokens) do
    # Extract character info from EVE SSO response
    character_id = Map.get(user_info, "CharacterID") || Map.get(user_info, "character_id")
    character_name = Map.get(user_info, "CharacterName") || Map.get(user_info, "character_name")

    # Extract token info
    access_token = Map.get(oauth_tokens, "access_token")
    refresh_token = Map.get(oauth_tokens, "refresh_token")

    expires_at =
      case Map.get(oauth_tokens, "expires_in") do
        nil ->
          nil

        expires_in when is_integer(expires_in) ->
          DateTime.add(DateTime.utc_now(), expires_in, :second)

        _ ->
          nil
      end

    %{
      character_id: character_id,
      character_name: character_name,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at
    }
  end

  defp get_eve_sso_config([:authentication, :strategies, :eve_sso, :client_id], _) do
    case System.get_env("EVE_SSO_CLIENT_ID") do
      nil -> {:error, "You must configure EVE_SSO_CLIENT_ID environment variable"}
      value -> {:ok, value}
    end
  end

  defp get_eve_sso_config([:authentication, :strategies, :eve_sso, :client_secret], _) do
    case System.get_env("EVE_SSO_CLIENT_SECRET") do
      nil -> {:error, "You must configure EVE_SSO_CLIENT_SECRET environment variable"}
      value -> {:ok, value}
    end
  end

  defp get_eve_sso_config([:authentication, :strategies, :eve_sso, :redirect_uri], _) do
    case System.get_env("EVE_SSO_REDIRECT_URI") do
      nil -> {:error, "You must configure EVE_SSO_REDIRECT_URI environment variable"}
      value -> {:ok, value}
    end
  end
end
