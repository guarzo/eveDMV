defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedUtilities do
  @moduledoc """
  Shared utilities for threat scoring engines.

  This module contains common functions used across multiple threat scoring engines
  to avoid code duplication and ensure consistency.

  ## Ship Classification

  Ship classification is performed by querying the EVE Static Data Export (SDE)
  via the ItemType resource. Ships are classified by their group_id, which
  represents CCP's official ship categorization.

  ## Price Estimation

  Ship values are estimated using a priority fallback:
  1. Market Intelligence service (real market prices)
  2. SDE base_price (official CCP pricing)
  3. Explicit error if no price data available
  """

  alias EveDmv.Contexts.CharacterIntelligence.ThreatConfig
  alias EveDmv.Eve.ItemType
  alias EveDmv.StaticData.ShipTypes

  require Logger

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

  Uses the SDE group_id to determine the ship's role in fleet combat.
  Falls back to :other if the ship type cannot be classified.
  """
  def classify_ship_role(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        ThreatConfig.classify_by_group_id(item_type.group_id)

      {:error, _} ->
        :other
    end
  end

  @doc """
  Classifies a ship type ID into its ship class.

  Uses the centralized ShipTypes module for consistent classification.
  Falls back to :other if the ship type cannot be classified.
  """
  def classify_ship_type(ship_type_id) do
    case ShipTypes.classify_ship_type(ship_type_id) do
      :unknown -> :other
      class -> class
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

  Returns {:ok, rate} on success or {:error, :insufficient_data} if no engagements.
  Rate is between 0.0 and 1.0, where 1.0 means perfect survival.
  """
  @spec calculate_survival_rate(map(), list()) :: {:ok, float()} | {:error, :insufficient_data}
  def calculate_survival_rate(combat_data, victim_killmails) do
    total_engagements = length(Map.get(combat_data, :killmails, []))
    deaths = length(victim_killmails)

    if total_engagements > 0 do
      {:ok, (total_engagements - deaths) / total_engagements}
    else
      {:error, :insufficient_data}
    end
  end

  @doc """
  Calculates damage efficiency from attacker killmails.

  Returns {:ok, efficiency} on success or {:error, :insufficient_data} if no kills.
  Efficiency is normalized to 0.0-1.0 where 1.0 means excellent damage contribution.
  """
  @spec calculate_damage_efficiency(list()) :: {:ok, float()} | {:error, :insufficient_data}
  def calculate_damage_efficiency(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      {:error, :insufficient_data}
    else
      total_damage_contribution =
        attacker_killmails
        |> Enum.map(&extract_damage_contribution/1)
        |> Enum.sum()

      average_contribution = total_damage_contribution / length(attacker_killmails)

      # Normalize damage contribution (higher is better)
      # Use ThreatConfig for the normalization constant
      {:ok, min(1.0, average_contribution / ThreatConfig.damage_contribution_excellent())}
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

  Uses group_id from SDE to identify interceptors, interdictors, and other tackle ships.
  """
  def tackle_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        item_type.group_id in ThreatConfig.tackle_group_ids()

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a ship type is a DPS ship.

  DPS ships are combat-focused vessels: cruisers, battlecruisers, battleships.
  """
  def dps_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        item_type.group_id in ThreatConfig.subcapital_combat_group_ids()

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a ship type is a support ship.

  Support ships include logistics, EWAR, and command ships.
  """
  def support_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        item_type.group_id in ThreatConfig.tactical_support_group_ids()

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a ship type is a logistics ship.
  """
  def logistics_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        item_type.group_id in ThreatConfig.logistics_group_ids()

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a ship type is an EWAR ship.
  """
  def ewar_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        item_type.group_id in ThreatConfig.ewar_group_ids()

      {:error, _} ->
        false
    end
  end

  @doc """
  Checks if a ship type is a command ship.
  """
  def command_ship?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        item_type.group_id in ThreatConfig.command_group_ids()

      {:error, _} ->
        false
    end
  end

  @doc """
  Estimates the ISK value of a ship based on its type ID.

  Priority order:
  1. Market Intelligence service (if available)
  2. SDE base_price from ItemType
  3. Returns 0 if no price data available (explicit handling)

  Returns an integer representing the estimated ISK value.
  """
  def estimate_ship_value(ship_type_id) do
    # First try Market Intelligence for real market prices
    case try_market_price(ship_type_id) do
      {:ok, price} when price > 0 ->
        trunc(price)

      _ ->
        # Fallback to SDE base_price
        case get_item_type_info(ship_type_id) do
          {:ok, item_type} when not is_nil(item_type.base_price) ->
            # base_price is a Decimal, convert to integer
            item_type.base_price
            |> Decimal.to_float()
            |> trunc()

          _ ->
            # No price data available - return 0 instead of fake value
            0
        end
    end
  end

  # Attempts to get market price from MarketIntelligence context
  # Safely handles test environments where the service may not be running
  defp try_market_price(type_id) do
    alias EveDmv.Contexts.MarketIntelligence

    # Check if the price service is running before calling it
    # This avoids EXIT signals in test environments
    case Process.whereis(EveDmv.Contexts.MarketIntelligence.Domain.PriceService) do
      nil ->
        {:error, :service_unavailable}

      _pid ->
        try do
          case MarketIntelligence.get_price(type_id) do
            {:ok, %{price: price}} -> {:ok, price}
            _ -> {:error, :no_market_price}
          end
        rescue
          # Handle any exceptions
          _ -> {:error, :service_unavailable}
        catch
          # Catch :exit when GenServer call fails
          :exit, _ -> {:error, :service_unavailable}
        end
    end
  end

  @doc """
  Checks if a ship type is a tactical target (high priority).

  Tactical targets are ships that provide force multipliers:
  logistics, EWAR, and command ships.
  """
  def tactical_target?(ship_type_id) do
    case get_item_type_info(ship_type_id) do
      {:ok, item_type} ->
        ThreatConfig.tactical_target_group?(item_type.group_id)

      {:error, _} ->
        false
    end
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
