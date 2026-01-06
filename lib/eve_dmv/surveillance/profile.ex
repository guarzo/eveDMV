defmodule EveDmv.Surveillance.Profile do
  @moduledoc """
  Surveillance profile for tracking specific types of killmails.

  Profiles define filters that match against incoming killmails and trigger
  notifications when matched. Each profile has a name, filter rules, and
  notification settings.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api.SurveillanceApi,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [
      EveDmv.Ash.Notifiers.PubSubNotifier,
      EveDmv.Ash.Notifiers.TelemetryNotifier
    ]

  postgres do
    table("surveillance_profiles")
    repo(EveDmv.Repo)

    custom_indexes do
      index([:user_id], name: "surveillance_profiles_user_idx")
      index([:is_active], name: "surveillance_profiles_active_idx")
      index([:user_id, :is_active], name: "surveillance_profiles_user_active_idx")
    end
  end

  # Identity constraints
  identities do
    identity :unique_user_profile, [:user_id, :name] do
      description("Each user can only have one profile with the same name")
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api.SurveillanceApi)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:update, action: :update)
    define(:update_profile, action: :update_profile)
    define(:destroy, action: :destroy)
    define(:active_profiles, action: :active_profiles)
    define(:user_profiles, args: [:user_id])
  end

  # Attributes
  attributes do
    # Primary key
    uuid_primary_key(:id)

    # Profile metadata
    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 100, min_length: 1)
      description("Human-readable name for the profile")
    end

    attribute :description, :string do
      allow_nil?(true)
      constraints(max_length: 500)
      description("Optional description of what this profile tracks")
    end

    # User ownership
    attribute :user_id, :uuid do
      allow_nil?(false)
      description("User who owns this profile")
    end

    # Profile status
    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this profile is actively matching killmails")
    end

    # Simplified filter configuration using embedded resources
    attribute :filters, {:array, EveDmv.Surveillance.SimpleFilter} do
      default([])
      description("List of filter conditions combined with AND logic")
    end

    # Legacy filter configuration (deprecated - kept for migration)
    attribute :filter_tree, :map do
      allow_nil?(true)
      description("Deprecated: Use filters instead. Legacy JSON filter tree.")
    end

    # Notification settings
    attribute :notification_settings, :map do
      allow_nil?(false)

      default(%{
        "enabled" => true,
        "sound_enabled" => true,
        "volume" => 0.5,
        "duration_s" => 5,
        "email_enabled" => false,
        "discord_webhook" => nil
      })

      description("Notification configuration for matches")
    end

    # Statistics
    attribute :match_count, :integer do
      allow_nil?(false)
      default(0)
      description("Total number of killmails matched by this profile")
    end

    attribute :last_match_at, :utc_datetime do
      allow_nil?(true)
      description("When this profile last matched a killmail")
    end

    # Automatic timestamps
    timestamps()
  end

  # Relationships
  relationships do
    # Note: User relationship will be added when we implement authentication
    # belongs_to :user, EveDmv.Accounts.User

    has_many :matches, EveDmv.Surveillance.ProfileMatch do
      destination_attribute(:profile_id)
      description("Killmails matched by this profile")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create action with validation
    create :create do
      primary?(true)
      description("Create a surveillance profile")

      accept([
        :name,
        :description,
        :user_id,
        :is_active,
        :filters,
        :filter_tree,
        :notification_settings
      ])

      validate(present(:name))
      validate(present(:user_id))

      # Validate that at least one filter is present (either new or legacy format)
      validate(fn changeset, _context ->
        filters = Ash.Changeset.get_attribute(changeset, :filters) || []
        filter_tree = Ash.Changeset.get_attribute(changeset, :filter_tree)

        cond do
          not Enum.empty?(filters) ->
            :ok

          is_map(filter_tree) and map_size(filter_tree) > 0 ->
            # Legacy format - still valid
            :ok

          true ->
            {:error, field: :filters, message: "at least one filter is required"}
        end
      end)

      # Validate legacy filter_tree if present
      change(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :filter_tree) do
          nil ->
            changeset

          %{} = filter_tree when map_size(filter_tree) > 0 ->
            case validate_filter_tree(filter_tree) do
              :ok ->
                changeset

              {:error, message} ->
                Ash.Changeset.add_error(changeset, field: :filter_tree, message: message)
            end

          _ ->
            changeset
        end
      end)
    end

    # Read actions
    read :active_profiles do
      description("Get all active surveillance profiles")
      filter(expr(is_active == true))
      prepare(build(sort: [:updated_at]))
    end

    read :user_profiles do
      description("Get profiles for a specific user")

      argument :user_id, :uuid do
        allow_nil?(false)
        description("User ID to filter by")
      end

      filter(expr(user_id == ^arg(:user_id)))
      prepare(build(sort: [is_active: :desc, updated_at: :desc]))
    end

    # Update actions
    update :update_profile do
      description("Update a surveillance profile")

      accept([
        :name,
        :description,
        :is_active,
        :filters,
        :notification_settings
      ])
    end

    update :toggle_active do
      description("Toggle the active status of a profile")
      change(atomic_update(:is_active, expr(not is_active)))
    end

    update :increment_match_count do
      description("Increment match count and update last match time")
      change(atomic_update(:match_count, expr(match_count + 1)))
      change(set_attribute(:last_match_at, &DateTime.utc_now/0))
    end
  end

  # Validations
  validations do
    validate(present(:name), message: "Name is required")
    validate(present(:user_id), message: "User ID is required")
    # Note: filter validation is handled in the create action
    # to support both new (filters) and legacy (filter_tree) formats
  end

  # Authorization policies
  policies do
    # Public read access for active profiles (for the matching engine)
    policy action(:active_profiles) do
      authorize_if(always())
    end

    # Users can only access their own profiles
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if(expr(user_id == ^actor(:id)))
    end

    # Admin users can access all profiles
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if(actor_attribute_equals(:role, "admin"))
    end
  end

  # Calculations
  calculations do
    calculate :is_recently_active, :boolean, expr(last_match_at > ago(24, :hour)) do
      description("Whether this profile has matched killmails in the last 24 hours")
    end

    calculate :matches_per_day,
              :decimal,
              expr(match_count / datetime_diff(now(), inserted_at, :day)) do
      description("Average matches per day since creation")
    end
  end

  # Private validation functions
  defp validate_filter_tree(%{"condition" => condition, "rules" => rules})
       when condition in ["and", "or"] and is_list(rules) do
    if Enum.empty?(rules) do
      {:error, "rules cannot be empty"}
    else
      Enum.reduce_while(rules, :ok, fn rule, :ok ->
        case validate_rule(rule) do
          :ok -> {:cont, :ok}
          error -> {:halt, error}
        end
      end)
    end
  end

  defp validate_filter_tree(_), do: {:error, "invalid filter tree structure"}

  defp validate_rule(%{"condition" => _, "rules" => _} = nested_group) do
    validate_filter_tree(nested_group)
  end

  defp validate_rule(%{"field" => field, "operator" => operator, "value" => value}) do
    with :ok <- validate_field(field),
         :ok <- validate_operator(operator),
         :ok <- validate_value_for_operator(operator, value) do
      :ok
    end
  end

  defp validate_rule(_), do: {:error, "invalid rule structure"}

  defp validate_field(field)
       when field in [
              "killmail_id",
              "victim_character_id",
              "victim_corporation_id",
              "victim_alliance_id",
              "solar_system_id",
              "victim_ship_type_id",
              "total_value",
              "ship_value",
              "fitted_value",
              "attacker_count",
              "final_blow_character_id",
              "kill_category",
              "victim_ship_category",
              "module_tags",
              "noteworthy_modules",
              "killmail_time",
              "victim_character_name",
              "victim_corporation_name",
              "victim_alliance_name",
              "solar_system_name",
              "victim_ship_name"
            ] do
    :ok
  end

  defp validate_field(_), do: {:error, "invalid field name"}

  defp validate_operator(op)
       when op in [
              "eq",
              "ne",
              "gt",
              "lt",
              "gte",
              "lte",
              "in",
              "not_in",
              "contains_any",
              "contains_all",
              "not_contains"
            ] do
    :ok
  end

  defp validate_operator(_), do: {:error, "invalid operator"}

  defp validate_value_for_operator(op, value)
       when op in ["in", "not_in", "contains_any", "contains_all", "not_contains"] do
    if is_list(value) and not Enum.empty?(value) do
      :ok
    else
      {:error, "#{op} requires a non-empty list"}
    end
  end

  defp validate_value_for_operator(_, _), do: :ok

  # Public API functions

  @doc """
  Check if a killmail matches this profile's filters.

  All filters must match (AND logic). Returns true if the killmail
  matches all configured filters, or if no filters are configured.
  """
  def matches_killmail?(%{__struct__: __MODULE__, filters: filters}, killmail)
      when is_list(filters) do
    if Enum.empty?(filters) do
      false
    else
      Enum.all?(filters, fn filter ->
        EveDmv.Surveillance.SimpleFilter.matches?(filter, killmail)
      end)
    end
  end

  def matches_killmail?(_, _), do: false

  @doc """
  Get a human-readable summary of the profile's filters.
  """
  def filter_summary(%{__struct__: __MODULE__, filters: filters}) when is_list(filters) do
    count = length(filters)

    if count == 0 do
      "No filters configured"
    else
      filter_types =
        filters
        |> Enum.map(& &1.filter_type)
        |> Enum.uniq()
        |> Enum.map_join(", ", &EveDmv.Surveillance.SimpleFilter.filter_type_display/1)

      "#{count} filter#{if count == 1, do: "", else: "s"}: #{filter_types}"
    end
  end

  def filter_summary(_), do: "No filters configured"
end
