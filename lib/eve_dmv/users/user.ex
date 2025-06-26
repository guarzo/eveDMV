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

        changeset
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

    # Users can update their own data
    policy action_type(:update) do
      authorize_if(actor_attribute_equals(:id, :id))
    end

    # Only admins can destroy users (we'll implement admin roles later)
    policy action_type(:destroy) do
      forbid_if(always())
    end
  end

  # Private functions
  defp maybe_update_corporation_info(changeset, _user_info) do
    # In a real implementation, we'd call EVE ESI here to get corp/alliance info
    # For now, just pass through the data
    changeset
  end

  def signing_secret(_resource, _opts) do
    Application.get_env(:eve_dmv, :token_signing_secret) ||
      raise "You must configure :token_signing_secret in your application config"
  end

  defp get_eve_sso_config(:client_id, _) do
    Application.get_env(:eve_dmv, :eve_sso)[:client_id] ||
      raise "You must configure :eve_sso client_id in your application config"
  end

  defp get_eve_sso_config(:client_secret, _) do
    Application.get_env(:eve_dmv, :eve_sso)[:client_secret] ||
      raise "You must configure :eve_sso client_secret in your application config"
  end

  defp get_eve_sso_config(:redirect_uri, _) do
    Application.get_env(:eve_dmv, :eve_sso)[:redirect_uri] ||
      raise "You must configure :eve_sso redirect_uri in your application config"
  end
end
