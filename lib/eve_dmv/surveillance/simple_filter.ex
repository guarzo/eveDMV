defmodule EveDmv.Surveillance.SimpleFilter do
  @moduledoc """
  Simplified filter condition for surveillance profiles.

  This embedded resource represents a single filter rule with a clear structure
  that integrates natively with AshPhoenix.Form. Filters are combined using
  AND logic at the profile level.

  ## Supported Filter Types

  ### Entity Filters
  Match killmails involving specific entities:
  - `:character` - Match specific character IDs
  - `:corporation` - Match specific corporation IDs
  - `:alliance` - Match specific alliance IDs
  - `:system` - Match specific solar system IDs
  - `:ship` - Match specific ship type IDs

  ### Value Filters
  - `:isk_range` - Match killmails within an ISK value range

  ### Time Filters
  - `:active_hours` - Match killmails occurring within specified hours (UTC)

  ## Examples

      # Match kills involving specific characters
      %SimpleFilter{
        filter_type: :character,
        entity_ids: [12345, 67890],
        match_victim: true,
        match_attacker: true
      }

      # Match high-value kills
      %SimpleFilter{
        filter_type: :isk_range,
        min_value: 100_000_000,
        max_value: nil  # No upper limit
      }

      # Match kills during EU prime time
      %SimpleFilter{
        filter_type: :active_hours,
        hour_start: 18,
        hour_end: 23
      }
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    data_layer: :embedded

  attributes do
    attribute :filter_type, :atom do
      allow_nil?(false)

      constraints(
        one_of: [
          # Entity matching
          :character,
          :corporation,
          :alliance,
          :system,
          :ship,
          # Value filtering
          :isk_range,
          # Time filtering
          :active_hours
        ]
      )

      description("Type of filter condition")
    end

    # For entity-type filters (character, corporation, alliance, system, ship)
    attribute :entity_ids, {:array, :integer} do
      default([])
      description("List of entity IDs to match against")
    end

    # For entity filters - which side to match
    attribute :match_victim, :boolean do
      default(true)
      description("Match if entity appears as victim")
    end

    attribute :match_attacker, :boolean do
      default(true)
      description("Match if entity appears as attacker")
    end

    # For isk_range filter
    attribute :min_value, :integer do
      allow_nil?(true)
      description("Minimum ISK value (for isk_range filter)")
    end

    attribute :max_value, :integer do
      allow_nil?(true)
      description("Maximum ISK value (for isk_range filter)")
    end

    # For active_hours filter
    attribute :hour_start, :integer do
      allow_nil?(true)
      constraints(min: 0, max: 23)
      description("Start hour in UTC (0-23)")
    end

    attribute :hour_end, :integer do
      allow_nil?(true)
      constraints(min: 0, max: 23)
      description("End hour in UTC (0-23)")
    end
  end

  validations do
    # Entity filters must have at least one entity ID
    validate(fn changeset, _context ->
      filter_type = Ash.Changeset.get_attribute(changeset, :filter_type)

      if filter_type in [:character, :corporation, :alliance, :system, :ship] do
        entity_ids = Ash.Changeset.get_attribute(changeset, :entity_ids) || []

        if Enum.empty?(entity_ids) do
          {:error, field: :entity_ids, message: "at least one ID is required for entity filters"}
        else
          :ok
        end
      else
        :ok
      end
    end)

    # ISK range filter must have at least one bound
    validate(fn changeset, _context ->
      filter_type = Ash.Changeset.get_attribute(changeset, :filter_type)

      if filter_type == :isk_range do
        min_value = Ash.Changeset.get_attribute(changeset, :min_value)
        max_value = Ash.Changeset.get_attribute(changeset, :max_value)

        cond do
          is_nil(min_value) and is_nil(max_value) ->
            {:error,
             field: :min_value, message: "at least one of min_value or max_value is required"}

          not is_nil(min_value) and not is_nil(max_value) and min_value > max_value ->
            {:error, field: :min_value, message: "min_value must be less than max_value"}

          true ->
            :ok
        end
      else
        :ok
      end
    end)

    # Active hours filter must have both start and end
    validate(fn changeset, _context ->
      filter_type = Ash.Changeset.get_attribute(changeset, :filter_type)

      if filter_type == :active_hours do
        hour_start = Ash.Changeset.get_attribute(changeset, :hour_start)
        hour_end = Ash.Changeset.get_attribute(changeset, :hour_end)

        if is_nil(hour_start) or is_nil(hour_end) do
          {:error, field: :hour_start, message: "both hour_start and hour_end are required"}
        else
          :ok
        end
      else
        :ok
      end
    end)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :filter_type,
        :entity_ids,
        :match_victim,
        :match_attacker,
        :min_value,
        :max_value,
        :hour_start,
        :hour_end
      ])
    end

    update :update do
      primary?(true)

      accept([
        :filter_type,
        :entity_ids,
        :match_victim,
        :match_attacker,
        :min_value,
        :max_value,
        :hour_start,
        :hour_end
      ])
    end
  end

  @doc """
  Returns the display name for a filter type.
  """
  def filter_type_display(:character), do: "Character"
  def filter_type_display(:corporation), do: "Corporation"
  def filter_type_display(:alliance), do: "Alliance"
  def filter_type_display(:system), do: "Solar System"
  def filter_type_display(:ship), do: "Ship Type"
  def filter_type_display(:isk_range), do: "ISK Value Range"
  def filter_type_display(:active_hours), do: "Active Hours (UTC)"
  def filter_type_display(_), do: "Unknown"

  @doc """
  Returns all available filter types with their display names.
  """
  def available_filter_types do
    [
      {:character, "Character"},
      {:corporation, "Corporation"},
      {:alliance, "Alliance"},
      {:system, "Solar System"},
      {:ship, "Ship Type"},
      {:isk_range, "ISK Value Range"},
      {:active_hours, "Active Hours (UTC)"}
    ]
  end

  @doc """
  Checks if this filter matches a killmail.

  Returns `true` if the killmail matches this filter condition.

  Note: Uses map pattern matching instead of struct pattern matching to avoid
  compile-time issues with Ash resource struct expansion.
  """
  def matches?(%{__struct__: __MODULE__, filter_type: :character} = filter, killmail) do
    check_entity_match(filter.entity_ids, killmail, :character_id, filter)
  end

  def matches?(%{__struct__: __MODULE__, filter_type: :corporation} = filter, killmail) do
    check_entity_match(filter.entity_ids, killmail, :corporation_id, filter)
  end

  def matches?(%{__struct__: __MODULE__, filter_type: :alliance} = filter, killmail) do
    check_entity_match(filter.entity_ids, killmail, :alliance_id, filter)
  end

  def matches?(%{__struct__: __MODULE__, filter_type: :system} = filter, killmail) do
    system_id = get_in(killmail, [:solar_system_id]) || get_in(killmail, ["solar_system_id"])
    system_id in filter.entity_ids
  end

  def matches?(%{__struct__: __MODULE__, filter_type: :ship} = filter, killmail) do
    check_ship_match(filter.entity_ids, killmail, filter)
  end

  def matches?(%{__struct__: __MODULE__, filter_type: :isk_range} = filter, killmail) do
    value = get_killmail_value(killmail)
    min_ok = is_nil(filter.min_value) or value >= filter.min_value
    max_ok = is_nil(filter.max_value) or value <= filter.max_value
    min_ok and max_ok
  end

  def matches?(%{__struct__: __MODULE__, filter_type: :active_hours} = filter, killmail) do
    killmail_time =
      get_in(killmail, [:killmail_time]) || get_in(killmail, ["killmail_time"])

    case killmail_time do
      %DateTime{hour: hour} ->
        in_hour_range?(hour, filter.hour_start, filter.hour_end)

      time_string when is_binary(time_string) ->
        case DateTime.from_iso8601(time_string) do
          {:ok, dt, _} -> in_hour_range?(dt.hour, filter.hour_start, filter.hour_end)
          _ -> false
        end

      _ ->
        false
    end
  end

  def matches?(_, _), do: false

  # Private helpers

  defp check_entity_match(entity_ids, killmail, field, filter) do
    victim_match =
      filter.match_victim and
        (get_in(killmail, [:victim, field]) || get_in(killmail, ["victim", to_string(field)])) in entity_ids

    attacker_match =
      filter.match_attacker and
        check_attackers(entity_ids, killmail, field)

    victim_match or attacker_match
  end

  defp check_attackers(entity_ids, killmail, field) do
    attackers =
      get_in(killmail, [:attackers]) || get_in(killmail, ["attackers"]) || []

    Enum.any?(attackers, fn attacker ->
      (get_in(attacker, [field]) || get_in(attacker, [to_string(field)])) in entity_ids
    end)
  end

  defp check_ship_match(ship_ids, killmail, filter) do
    victim_ship =
      get_in(killmail, [:victim, :ship_type_id]) ||
        get_in(killmail, ["victim", "ship_type_id"])

    victim_match = filter.match_victim and victim_ship in ship_ids

    attacker_match =
      filter.match_attacker and check_attacker_ships(ship_ids, killmail)

    victim_match or attacker_match
  end

  defp check_attacker_ships(ship_ids, killmail) do
    attackers =
      get_in(killmail, [:attackers]) || get_in(killmail, ["attackers"]) || []

    Enum.any?(attackers, fn attacker ->
      ship_id =
        get_in(attacker, [:ship_type_id]) || get_in(attacker, ["ship_type_id"])

      ship_id in ship_ids
    end)
  end

  defp get_killmail_value(killmail) do
    get_in(killmail, [:zkb, :totalValue]) ||
      get_in(killmail, ["zkb", "totalValue"]) ||
      get_in(killmail, [:zkb_total_value]) ||
      get_in(killmail, ["zkb_total_value"]) ||
      0
  end

  defp in_hour_range?(hour, start_hour, end_hour) when start_hour <= end_hour do
    hour >= start_hour and hour <= end_hour
  end

  # Handle wrap-around (e.g., 22:00 to 02:00)
  defp in_hour_range?(hour, start_hour, end_hour) do
    hour >= start_hour or hour <= end_hour
  end
end
