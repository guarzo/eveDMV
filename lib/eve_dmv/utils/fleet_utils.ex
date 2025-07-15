defmodule EveDmv.Utils.FleetUtils do
  @moduledoc """
  Utility functions for fleet operations and battle analysis.

  Extracted from FleetOperationsLive to improve code organization and reusability.
  Contains helper functions for:
  - Ship classification and analysis
  - Fleet composition calculations
  - Performance scoring and metrics
  - Data formatting and display
  """

  @doc """
  Estimate ship value based on ship type ID.
  """
  def estimate_ship_value(ship_type_id) when is_integer(ship_type_id) do
    # Rough ship value estimates in ISK
    case get_ship_class(ship_type_id) do
      "Frigate" -> 400_000
      "Destroyer" -> 1_200_000
      "Cruiser" -> 8_000_000
      "Battlecruiser" -> 45_000_000
      "Battleship" -> 150_000_000
      "Carrier" -> 2_000_000_000
      "Dreadnought" -> 3_500_000_000
      "Titan" -> 120_000_000_000
      _ -> 1_000_000
    end
  end

  def estimate_ship_value(_), do: 1_000_000

  @doc """
  Get ship class based on ship type ID.
  """
  def get_ship_class(ship_type_id) when is_integer(ship_type_id) do
    # More comprehensive ship class detection
    cond do
      # T3 Destroyers (specific IDs)
      ship_type_id in [29_248, 29_984, 29_986, 29_988] -> "T3 Destroyer"
      # Frigates
      ship_type_id in 582..650 -> "Frigate"
      # Regular Destroyers  
      ship_type_id in [16_219, 16_227, 16_236, 16_242] -> "Destroyer"
      ship_type_id in 324..380 -> "Destroyer"
      # Cruisers
      ship_type_id in 620..634 -> "Cruiser"
      # T3 Cruisers (Strategic Cruisers)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> "T3 Cruiser"
      ship_type_id in 11_567..12_034 -> "T3 Cruiser"
      # Battlecruisers
      ship_type_id in 1201..1310 -> "Battlecruiser"
      # Battleships
      ship_type_id in 638..648 -> "Battleship"
      # Capitals
      ship_type_id in 547..554 -> "Carrier"
      ship_type_id in 670..673 -> "Dreadnought"
      ship_type_id in 3514..3518 -> "Titan"
      true -> "Other"
    end
  end

  def get_ship_class(_), do: "Other"

  @doc """
  Get ship category (lowercase ship class).
  """
  def get_ship_category(ship_type_id) when is_integer(ship_type_id) do
    String.downcase(get_ship_class(ship_type_id))
  end

  def get_ship_category(_), do: "other"

  @doc """
  Determine fleet role based on pilot data.
  """
  def determine_fleet_role(pilot) do
    cond do
      Map.get(pilot, :final_blow, false) -> "FC"
      Map.get(pilot, :role) == :attacker -> "DPS"
      Map.get(pilot, :role) == :victim -> "Victim"
      true -> "DPS"
    end
  end

  @doc """
  Format role for display purposes.
  """
  def format_role(role) do
    case role do
      :attacker -> "dps"
      :victim -> "victim"
      _ -> "dps"
    end
  end

  @doc """
  Calculate pilot performance score based on multiple factors.
  """
  def calculate_pilot_score(pilot) do
    base_score = 50
    damage_bonus = min(30, Map.get(pilot, :damage_dealt, 0) / 1000)
    survival_bonus = if Map.get(pilot, :is_victim, false), do: 0, else: 20
    ship_value_bonus = min(20, Map.get(pilot, :ship_value, 0) / 10_000_000)

    score = base_score + damage_bonus + survival_bonus + ship_value_bonus

    %{
      character_name: Map.get(pilot, :character_name, "Unknown"),
      ship_name: Map.get(pilot, :ship_name, "Unknown"),
      score: round(score),
      damage_dealt: Map.get(pilot, :damage_dealt, 0),
      survived: !Map.get(pilot, :is_victim, false)
    }
  end

  @doc """
  Calculate average ship value for a list of participants.
  """
  def calculate_average_ship_value(participants) do
    total_value = Enum.sum(Enum.map(participants, &Map.get(&1, :ship_value, 0)))
    if length(participants) > 0, do: round(total_value / length(participants)), else: 0
  end

  @doc """
  Get the most common ship from ship distribution data.
  """
  def get_most_common_ship(ship_distribution) do
    case Enum.max_by(ship_distribution, &elem(&1, 1), fn -> {"Unknown", 0} end) do
      {ship_name, _count} -> ship_name
      _ -> "Unknown"
    end
  end

  @doc """
  Calculate fleet coordination score based on ship diversity.
  """
  def calculate_fleet_coordination_score(participants) do
    # Simple coordination score based on ship diversity and role distribution
    ship_types =
      Enum.count(Stream.uniq(Stream.map(participants, &Map.get(&1, :ship_name))))

    total_pilots = length(participants)

    if total_pilots > 0 do
      # Higher diversity = better coordination (up to a point)
      diversity_ratio = min(1.0, ship_types / (total_pilots * 0.3))
      round(diversity_ratio * 100)
    else
      0
    end
  end

  @doc """
  Calculate engagement intensity based on survival rate and ship values.
  """
  def calculate_engagement_intensity(participants) do
    # Calculate based on survival rate and ship values
    total_value = Enum.sum(Enum.map(participants, &Map.get(&1, :ship_value, 0)))
    victims = Enum.count(participants, &Map.get(&1, :is_victim, false))

    if length(participants) > 0 do
      risk_factor = victims / length(participants)
      # Normalize to 1B ISK
      value_factor = min(1.0, total_value / 1_000_000_000)
      round((risk_factor + value_factor) * 50)
    else
      0
    end
  end

  @doc """
  Extract victim data from killmail.
  """
  def extract_victim_data(killmail) do
    raw_data = Map.get(killmail, :raw_data, %{})
    victim = Map.get(raw_data, "victim", %{})

    %{
      character_id: Map.get(victim, "character_id"),
      character_name: Map.get(victim, "character_name"),
      corporation_id: Map.get(victim, "corporation_id"),
      alliance_id: Map.get(victim, "alliance_id"),
      ship_type_id: Map.get(victim, "ship_type_id"),
      role: :victim
    }
  end

  @doc """
  Extract attacker data from killmail.
  """
  def extract_attacker_data(killmail) do
    raw_data = Map.get(killmail, :raw_data, %{})
    attackers = Map.get(raw_data, "attackers", [])

    Enum.map(attackers, fn attacker ->
      %{
        character_id: Map.get(attacker, "character_id"),
        character_name: Map.get(attacker, "character_name"),
        corporation_id: Map.get(attacker, "corporation_id"),
        alliance_id: Map.get(attacker, "alliance_id"),
        ship_type_id: Map.get(attacker, "ship_type_id"),
        role: :attacker,
        final_blow: Map.get(attacker, "final_blow", false)
      }
    end)
  end

  @doc """
  Group participants into sides based on alliance/corporation.
  """
  def group_participants_into_sides(participants) do
    # Group by alliance (or corporation if no alliance)
    groups =
      Enum.group_by(participants, fn p ->
        Map.get(p, :alliance_id) || Map.get(p, :corporation_id) || "unknown"
      end)

    groups
    |> Enum.map(fn {group_id, pilots} ->
      %{
        group_id: group_id,
        pilots: pilots,
        ship_count: length(pilots),
        unique_ship_types:
          Enum.count(Stream.uniq(Stream.map(pilots, &Map.get(&1, :ship_type_id))))
      }
    end)
    # Only include _sides with multiple ships
    |> Enum.filter(fn side -> side.ship_count > 1 end)
  end

  @doc """
  Get battle start time from killmails.
  """
  def get_battle_start_time(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :killmail_time))
    |> Enum.min(DateTime, fn -> DateTime.utc_now() end)
  end

  @doc """
  Get battle end time from killmails.
  """
  def get_battle_end_time(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :killmail_time))
    |> Enum.max(DateTime, fn -> DateTime.utc_now() end)
  end

  @doc """
  Format ISK values for display.
  """
  def format_isk(amount) when is_number(amount) do
    cond do
      amount >= 1_000_000_000 -> "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
      amount >= 1_000_000 -> "#{Float.round(amount / 1_000_000, 1)}M ISK"
      amount >= 1_000 -> "#{Float.round(amount / 1_000, 1)}K ISK"
      true -> "#{round(amount)} ISK"
    end
  end

  def format_isk(_), do: "0 ISK"

  @doc """
  Format numbers for display.
  """
  def format_number(number) when is_number(number) do
    cond do
      number >= 1_000_000 -> "#{Float.round(number / 1_000_000, 1)}M"
      number >= 1_000 -> "#{Float.round(number / 1_000, 1)}K"
      true -> "#{round(number)}"
    end
  end

  def format_number(_), do: "0"

  @doc """
  Format EHP (Effective Hit Points) for display.
  """
  def format_ehp(ehp) when is_number(ehp) do
    cond do
      ehp >= 1_000_000_000 -> "#{Float.round(ehp / 1_000_000_000, 1)}B"
      ehp >= 1_000_000 -> "#{Float.round(ehp / 1_000_000, 1)}M"
      ehp >= 1_000 -> "#{Float.round(ehp / 1_000, 1)}K"
      true -> "#{round(ehp)}"
    end
  end

  def format_ehp(_), do: "0"

  @doc """
  Format battle datetime from timestamp.
  """
  def format_battle_datetime(timestamp) do
    # Convert YYYYMMDDHHMMSS to "YYYY-MM-DD HH:MM"
    case String.length(timestamp) do
      14 ->
        <<year::binary-4, month::binary-2, day::binary-2, hour::binary-2, minute::binary-2,
          _second::binary-2>> = timestamp

        "#{year}-#{month}-#{day} #{hour}:#{minute}"

      _ ->
        # Fallback
        String.slice(DateTime.to_string(DateTime.utc_now()), 0..18)
    end
  end

  @doc """
  Generate a user-friendly fleet ID based on battle data.
  """
  def generate_friendly_fleet_id(battle, _main_fleet) do
    battle_id = Map.get(battle, :battle_id, "")

    # Extract timestamp from battle ID and format as readable date/time
    case String.split(battle_id, "_") do
      ["battle", _system_id, timestamp] ->
        format_battle_datetime(timestamp)

      _ ->
        # Fallback to current time
        String.slice(DateTime.to_string(DateTime.utc_now()), 0..18)
    end
  end

  @doc """
  Convert pilot data from battle _participants into fleet member format.
  """
  def convert_pilot_to_fleet_member(pilot, name_resolver_fn \\ &default_ship_name_resolver/1) do
    ship_type_id = Map.get(pilot, :ship_type_id)
    ship_name = name_resolver_fn.(ship_type_id)

    %{
      character_id: Map.get(pilot, :character_id),
      character_name: Map.get(pilot, :character_name, "Unknown Pilot"),
      ship_name: ship_name,
      ship_type: ship_name,
      ship_type_id: ship_type_id,
      ship_group: get_ship_class(ship_type_id),
      ship_value: estimate_ship_value(ship_type_id),
      fleet_role: determine_fleet_role(pilot),
      is_fleet_commander:
        Map.get(pilot, :role) == :attacker && Map.get(pilot, :final_blow, false),
      role: format_role(Map.get(pilot, :role)),
      ship_category: get_ship_category(ship_type_id),
      corporation_name: "Unknown Corp",
      fleet_ops_attended: 1,
      fleet_ops_available: 1,
      avg_fleet_duration: 60,
      leadership_roles: if(Map.get(pilot, :final_blow, false), do: 1, else: 0)
    }
  end

  # Default ship name resolver (can be overridden by caller)
  defp default_ship_name_resolver(ship_type_id) do
    "Ship Type #{ship_type_id}"
  end
end
