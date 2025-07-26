defmodule EveDmv.Users.Account do
  @moduledoc """
  Account resource representing a player's account that can contain multiple EVE characters.

  This allows players to manage multiple EVE characters under a single login session,
  enabling character switching without re-authentication.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Ash.Changeset

  postgres do
    table("accounts")
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

    # Account metadata
    attribute :primary_character_id, :uuid do
      allow_nil?(true)
      description("Primary character for this account (usually the first one added)")
    end

    attribute :account_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Optional account name for easier identification")
    end

    # Activity tracking
    attribute :last_login_at, :utc_datetime do
      allow_nil?(true)
      description("Last time any character on this account logged in")
    end

    attribute :last_character_switch_at, :utc_datetime do
      allow_nil?(true)
      description("Last time the user switched characters")
    end

    # Admin privileges (inherited by all characters)
    attribute :is_admin, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this account has admin privileges")
    end

    # Automatic timestamps
    timestamps()
  end

  # Relationships
  relationships do
    # One account can have many characters
    has_many :characters, EveDmv.Users.User do
      source_attribute(:id)
      destination_attribute(:account_id)
      description("All characters belonging to this account")
    end

    # Primary character relationship
    belongs_to :primary_character, EveDmv.Users.User do
      source_attribute(:primary_character_id)
      destination_attribute(:id)
      description("The primary character for this account")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Create account action
    create :create do
      accept([:account_name, :is_admin, :primary_character_id])

      change(fn changeset, _context ->
        Changeset.change_attribute(changeset, :last_login_at, DateTime.utc_now())
      end)
    end

    # Add character to account
    update :add_character do
      accept([])
      argument(:character_id, :uuid, allow_nil?: false)

      change(fn changeset, context ->
        character_id = Ash.Changeset.get_argument(changeset, :character_id)

        # If this is the first character, make it primary
        current_record = changeset.data

        if is_nil(current_record.primary_character_id) do
          changeset
          |> Changeset.change_attribute(:primary_character_id, character_id)
          |> Changeset.change_attribute(:last_character_switch_at, DateTime.utc_now())
        else
          changeset
        end
      end)
    end

    # Switch primary character
    update :switch_primary_character do
      accept([])
      argument(:character_id, :uuid, allow_nil?: false)

      change(fn changeset, _context ->
        character_id = Ash.Changeset.get_argument(changeset, :character_id)

        changeset
        |> Changeset.change_attribute(:primary_character_id, character_id)
        |> Changeset.change_attribute(:last_character_switch_at, DateTime.utc_now())
      end)
    end

    # Update last login
    update :update_last_login do
      accept([])

      change(fn changeset, _context ->
        Changeset.change_attribute(changeset, :last_login_at, DateTime.utc_now())
      end)
    end
  end

  # Calculations
  calculations do
    calculate :character_count, :integer, expr(count(characters)) do
      description("Number of characters in this account")
    end

    calculate :has_multiple_characters, :boolean, expr(count(characters) > 1) do
      description("Whether this account has multiple characters")
    end
  end

  # Policies
  policies do
    # Only allow users to access their own account
    policy action_type(:read) do
      authorize_if(relating_to_actor(:characters))
    end

    policy action_type([:update, :destroy]) do
      authorize_if(relating_to_actor(:characters))
    end

    # Admins can access all accounts
    policy always() do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end
  end

  # Aggregates  
  aggregates do
    count :total_characters, :characters do
      description("Total number of characters in this account")
    end
  end

  # Identities
  identities do
    # Each account should have a unique primary character
    identity :unique_primary_character, [:primary_character_id] do
      description("Each character can only be primary for one account")
    end
  end
end
