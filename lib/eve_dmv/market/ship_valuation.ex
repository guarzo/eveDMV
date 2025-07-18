defmodule EveDmv.Market.ShipValuation do
  @moduledoc """
  Centralized service for ship valuation and market data.

  Provides consistent ship value estimates across the application.
  In the future, this should integrate with actual market data APIs
  or price services.
  """

  alias EveDmv.StaticData.ShipTypes
  require Logger

  # Base values by ship class (in millions of ISK)
  # These are rough estimates and should be replaced with actual market data
  @base_values_by_class %{
    # 5-50M ISK
    frigate: {5, 50},
    # 10-100M ISK
    destroyer: {10, 100},
    # 20-300M ISK
    cruiser: {20, 300},
    # 50-500M ISK
    battlecruiser: {50, 500},
    # 200M-2B ISK
    battleship: {200, 2000},
    # 1-5B ISK
    capital: {1000, 5000},
    # 20-100B ISK
    supercapital: {20000, 100_000},
    # 20M-1B ISK
    industrial: {20, 1000},
    # 30-300M ISK
    mining: {30, 300},
    # Default range
    unknown: {10, 100}
  }

  # Tech level multipliers
  @tech_multipliers %{
    # T1 baseline
    1 => 1.0,
    # T2 ships are ~3x more expensive
    2 => 3.0,
    # T3 ships are ~10x more expensive
    3 => 10.0
  }

  # Faction/pirate multipliers (currently only used in estimate_faction_multiplier)
  # @faction_multipliers %{
  #   standard: 1.0,
  #   navy: 2.0,
  #   pirate: 5.0,
  #   officer: 10.0
  # }

  @doc """
  Get the ship class for a given type ID.
  """
  def get_ship_class(type_id) do
    ShipTypes.classify_ship_type(type_id)
  end

  @doc """
  Estimate the value of a ship based on its type ID.

  Returns value in ISK.
  """
  def estimate_value(type_id) when is_integer(type_id) do
    ship_class = get_ship_class(type_id)
    {min_value, max_value} = Map.get(@base_values_by_class, ship_class, {10, 100})

    # Estimate tech level based on type ID patterns
    tech_level = estimate_tech_level(type_id)
    tech_multiplier = Map.get(@tech_multipliers, tech_level, 1.0)

    # Estimate faction status
    faction_multiplier = estimate_faction_multiplier(type_id)

    # Calculate median value with multipliers
    base_value = (min_value + max_value) / 2
    estimated_value = base_value * tech_multiplier * faction_multiplier * 1_000_000

    # Round to nearest million
    round(estimated_value / 1_000_000) * 1_000_000
  end

  # Default 10M ISK
  def estimate_value(_), do: 10_000_000

  @doc """
  Estimate value range for a ship type.

  Returns {min_value, max_value} in ISK.
  """
  def estimate_value_range(type_id) when is_integer(type_id) do
    ship_class = get_ship_class(type_id)
    {min_value, max_value} = Map.get(@base_values_by_class, ship_class, {10, 100})

    tech_level = estimate_tech_level(type_id)
    tech_multiplier = Map.get(@tech_multipliers, tech_level, 1.0)
    faction_multiplier = estimate_faction_multiplier(type_id)

    {
      round(min_value * tech_multiplier * faction_multiplier * 1_000_000),
      round(max_value * tech_multiplier * faction_multiplier * 1_000_000)
    }
  end

  def estimate_value_range(_), do: {10_000_000, 100_000_000}

  @doc """
  Check if a ship is considered high-value (> 1B ISK).
  """
  def is_high_value?(type_id) do
    estimate_value(type_id) > 1_000_000_000
  end

  @doc """
  Get a human-readable value estimate.
  """
  def format_value(type_id) do
    value = estimate_value(type_id)

    cond do
      value >= 1_000_000_000_000 -> "#{Float.round(value / 1_000_000_000_000, 1)}T ISK"
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B ISK"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M ISK"
      true -> "#{value} ISK"
    end
  end

  # Private functions

  defp estimate_tech_level(type_id) do
    # This is a simplified heuristic - real tech levels should come from static data
    cond do
      # T2 ships often have IDs in certain ranges
      # T2 Frigates
      type_id in 11176..11400 -> 2
      # T2 Cruisers
      type_id in 12003..12048 -> 2
      # T2 Battleships
      type_id in 22428..22474 -> 2
      # T3 ships
      # T3 Cruisers
      type_id in 29984..30000 -> 3
      # T3 Destroyers
      type_id in 32874..32880 -> 3
      # Default to T1
      true -> 1
    end
  end

  defp estimate_faction_multiplier(type_id) do
    # Simplified faction detection - should use static data
    cond do
      # Pirate faction ships
      # Pirate frigates/cruisers
      type_id in 17619..17740 -> 5.0
      # Pirate battleships
      type_id in 17918..17932 -> 5.0
      # Navy ships
      # Navy ships
      type_id in 16227..16240 -> 2.0
      # More navy variants
      type_id in 17619..17636 -> 2.0
      # Standard ships
      true -> 1.0
    end
  end

  @doc """
  Calculate total value of multiple ships.
  """
  def calculate_fleet_value(ship_type_ids) when is_list(ship_type_ids) do
    ship_type_ids
    |> Enum.map(&estimate_value/1)
    |> Enum.sum()
  end

  @doc """
  Get value statistics for a list of ship types.
  """
  def value_statistics(ship_type_ids) when is_list(ship_type_ids) do
    values = Enum.map(ship_type_ids, &estimate_value/1)

    if Enum.empty?(values) do
      %{
        total: 0,
        average: 0,
        min: 0,
        max: 0,
        count: 0
      }
    else
      %{
        total: Enum.sum(values),
        average: round(Enum.sum(values) / length(values)),
        min: Enum.min(values),
        max: Enum.max(values),
        count: length(values)
      }
    end
  end
end
