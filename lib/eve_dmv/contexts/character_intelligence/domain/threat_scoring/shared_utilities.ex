defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedUtilities do
  @moduledoc """
  Shared utilities for threat scoring engines.

  This module contains common functions used across multiple threat scoring engines
  to avoid code duplication and ensure consistency.
  """

  require Logger

  # Ship type IDs for tactical roles
  @logistics_ids [11_978, 11_987, 11_985, 12_003]
  @ewar_ids [11_957, 11_958, 11_959, 11_961]
  @command_ids [22_470, 22_852, 17_918, 17_920]

  # Ship type ID ranges
  @tackle_range 580..700
  @dps_range 620..670
  @capital_range 19_720..19_740
  @frigate_range 580..700
  @destroyer_range 420..450
  @cruiser_range 620..650
  @battlecruiser_range 540..570
  @battleship_range 640..670

  @doc """
  Extracts unique ship types used from killmail data.

  Returns a map of ship type IDs to their usage counts.
  """
  def extract_ship_types_used(killmails) do
    # Extract ship types used by the character
    killmails
    |> Enum.flat_map(fn km ->
      # Ship type when victim
      victim_ship = if km.victim_character_id, do: [km.victim_ship_type_id], else: []

      # Ship type when attacker
      attacker_ships =
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            attackers
            |> Enum.filter(&(&1["character_id"] != nil))
            |> Enum.map(& &1["ship_type_id"])
            |> Enum.filter(&(&1 != nil))

          _ ->
            []
        end

      victim_ship ++ attacker_ships
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
  end

  @doc """
  Extracts character ship roles from killmail data.

  Returns a map of ship roles to their usage counts.
  """
  def extract_character_ship_roles(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      # Extract ship types used by the character
      victim_ships = if km.victim_character_id, do: [km.victim_ship_type_id], else: []

      attacker_ships =
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            attackers
            |> Enum.filter(&(&1["character_id"] != nil))
            |> Enum.map(& &1["ship_type_id"])
            |> Enum.filter(&(&1 != nil))

          _ ->
            []
        end

      victim_ships ++ attacker_ships
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.map(&classify_ship_role/1)
    |> Enum.frequencies()
  end

  @doc """
  Classifies a ship type ID into its tactical role.
  """
  def classify_ship_role(ship_type_id) do
    cond do
      ship_type_id in @logistics_ids -> :logistics
      ship_type_id in @ewar_ids -> :ewar
      ship_type_id in @command_ids -> :command
      # Check DPS range before tackle since they overlap
      ship_type_id in @dps_range -> :dps
      ship_type_id in @tackle_range -> :tackle
      ship_type_id in @capital_range -> :capital
      true -> :other
    end
  end

  @doc """
  Classifies a ship type ID into its ship class.
  """
  def classify_ship_type(ship_type_id) do
    cond do
      ship_type_id in @frigate_range -> :frigate
      ship_type_id in @destroyer_range -> :destroyer
      ship_type_id in @cruiser_range -> :cruiser
      ship_type_id in @battlecruiser_range -> :battlecruiser
      ship_type_id in @battleship_range -> :battleship
      ship_type_id in @capital_range -> :capital
      true -> :other
    end
  end

  @doc """
  Normalizes a score to a 0-10 scale.
  """
  def normalize_to_10_scale(score) do
    min(10.0, max(0.0, score * 10))
  end

  @doc """
  Calculates survival rate based on combat data.
  """
  def calculate_survival_rate(combat_data, victim_killmails) do
    total_engagements = length(Map.get(combat_data, :killmails, []))
    deaths = length(victim_killmails)

    if total_engagements > 0 do
      (total_engagements - deaths) / total_engagements
    else
      # Neutral score for no data
      0.5
    end
  end

  @doc """
  Calculates damage efficiency from attacker killmails.
  """
  def calculate_damage_efficiency(attacker_killmails) do
    # Analyze damage contribution patterns
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      total_damage_contribution =
        attacker_killmails
        |> Enum.map(&extract_damage_contribution/1)
        |> Enum.sum()

      average_contribution = total_damage_contribution / length(attacker_killmails)

      # Normalize damage contribution (higher is better)
      # 15% average contribution = 1.0 score
      min(1.0, average_contribution / 0.15)
    end
  end

  @doc """
  Extracts damage contribution from a killmail for the character.
  """
  def extract_damage_contribution(killmail, character_id \\ nil) do
    # Use character_id parameter if provided, otherwise try to extract from killmail
    target_character_id = character_id || killmail.victim_character_id

    case killmail.raw_data do
      %{"victim" => %{"damage_taken" => total_damage}, "attackers" => attackers}
      when is_list(attackers) and is_number(total_damage) and total_damage > 0 ->
        character_damage =
          case Enum.find(attackers, &(&1["character_id"] == target_character_id)) do
            %{"damage_done" => damage} when is_number(damage) -> damage
            _ -> 0
          end

        character_damage / total_damage

      _ ->
        0.0
    end
  end

  @doc """
  Checks if a ship type is a tackle ship.
  """
  def tackle_ship?(ship_type_id) do
    # Frigates and some cruisers commonly used for tackle
    # Interceptors
    ship_type_id in @tackle_range or ship_type_id in [11_182, 11_196]
  end

  @doc """
  Checks if a ship type is a DPS ship.
  """
  def dps_ship?(ship_type_id) do
    # Most cruisers, battlecruisers, battleships
    ship_type_id in @dps_range
  end

  @doc """
  Checks if a ship type is a support ship.
  """
  def support_ship?(ship_type_id) do
    # EWAR, logistics, command ships
    ship_type_id in @logistics_ids or ship_type_id in @ewar_ids
  end

  @doc """
  Checks if a ship type is a logistics ship.
  """
  def logistics_ship?(ship_type_id) do
    ship_type_id in @logistics_ids
  end

  @doc """
  Checks if a ship type is an EWAR ship.
  """
  def ewar_ship?(ship_type_id) do
    ship_type_id in @ewar_ids
  end

  @doc """
  Checks if a ship type is a command ship.
  """
  def command_ship?(ship_type_id) do
    ship_type_id in @command_ids
  end

  @doc """
  Estimates the ISK value of a ship based on its type ID.
  """
  def estimate_ship_value(ship_type_id) do
    cond do
      # Frigates: 5M ISK
      ship_type_id in @frigate_range -> 5_000_000
      # Destroyers: 15M ISK
      ship_type_id in @destroyer_range -> 15_000_000
      # Cruisers: 50M ISK
      ship_type_id in @cruiser_range -> 50_000_000
      # Battlecruisers: 150M ISK
      ship_type_id in @battlecruiser_range -> 150_000_000
      # Battleships: 300M ISK
      ship_type_id in @battleship_range -> 300_000_000
      # Capitals: 2B ISK
      ship_type_id in @capital_range -> 2_000_000_000
      # Default: 25M ISK
      true -> 25_000_000
    end
  end

  @doc """
  Checks if a ship type is a tactical target (high priority).
  """
  def tactical_target?(ship_type_id) do
    # Ships that are tactically important targets
    ship_type_id in @logistics_ids or ship_type_id in @ewar_ids or ship_type_id in @command_ids
  end

  @doc """
  Checks if a ship type is a priority target.
  """
  def priority_target?(ship_type_id) do
    tactical_target?(ship_type_id)
  end

  @doc """
  Calculates ship diversity index using Shannon entropy.
  """
  def calculate_ship_diversity_index(ship_types_map) do
    if map_size(ship_types_map) == 0 do
      0.0
    else
      total_uses = Map.values(ship_types_map) |> Enum.sum()
      unique_ships = map_size(ship_types_map)

      # Shannon diversity index adapted for ship usage
      shannon_diversity =
        ship_types_map
        |> Enum.map(fn {_ship, uses} ->
          proportion = uses / total_uses
          -proportion * :math.log(proportion)
        end)
        |> Enum.sum()

      # Normalize to 0-1 scale
      max_diversity = :math.log(unique_ships)
      if max_diversity > 0, do: shannon_diversity / max_diversity, else: 0.0
    end
  end

  @doc """
  Calculates usage distribution percentages for ship types.
  """
  def calculate_usage_distribution(ship_types_map) do
    total_uses = Map.values(ship_types_map) |> Enum.sum()

    ship_types_map
    |> Enum.map(fn {ship_type, uses} ->
      {ship_type, Float.round(uses / total_uses, 3)}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
  end

  @doc """
  Calculates average from a list of numbers.
  """
  def average([]), do: 0.0

  def average(values) do
    Enum.sum(values) / length(values)
  end

  @doc """
  Calculates variance from a list of numbers.
  """
  def calculate_variance(values) do
    if length(values) <= 1 do
      0.0
    else
      mean_val = average(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean_val, 2)) |> Enum.sum()
      variance_sum / length(values)
    end
  end

  @doc """
  Normalizes a score to a 0-1 scale with given min and max values.
  """
  def normalize_score(value, min_val, max_val) do
    clamped_value = min(max_val, max(min_val, value))
    (clamped_value - min_val) / (max_val - min_val)
  end

  @doc """
  Checks if a ship type is a Tech 2 ship.
  """
  def tech2_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} -> item_type.tech_level == 2
      _ -> false
    end
  end

  @doc """
  Checks if a ship type is a capital ship.
  """
  def capital_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} -> item_type.is_capital_ship
      _ -> false
    end
  end

  @doc """
  Gets item type information from the static data.
  """
  def get_item_type_info(ship_type_id) do
    alias EveDmv.Eve.ItemType

    case Ash.get(ItemType, ship_type_id, domain: EveDmv.Api) do
      {:ok, item_type} -> {:ok, item_type}
      {:error, _reason} -> {:error, :not_found}
    end
  rescue
    _ -> {:error, :static_data_unavailable}
  end
end
