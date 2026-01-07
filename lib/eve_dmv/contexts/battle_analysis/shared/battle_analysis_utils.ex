defmodule EveDmv.Contexts.BattleAnalysis.Shared.BattleAnalysisUtils do
  @moduledoc """
  Shared utilities for battle analysis modules.

  This module contains common functions used across multiple battle analysis modules
  (BattleAnalysis.Core.BattleAnalyzer and CombatIntelligence.Domain.BattleAnalyzer)
  to eliminate code duplication and ensure consistency.

  ## Participant Statistics

  Functions for counting unique participants, corporations, and alliances from killmail data.

  ## Fleet Composition Analysis

  Functions for analyzing role balance, distribution balance, and doctrine coherence.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedUtilities

  # Maximum expected ship classes in a coherent doctrine
  # Based on EVE fleet doctrines which typically use 5-10 distinct ship classes
  @max_ship_classes 10.0

  @doc """
  Counts unique character participants from killmail data.

  Extracts all unique character IDs from both victims and attackers.

  ## Parameters

    - killmails: List of killmail structs/maps with victim and attackers data

  ## Returns

    - Integer count of unique participants
  """
  @spec count_unique_participants(list()) :: non_neg_integer()
  def count_unique_participants(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_id = get_in(km.victim, ["character_id"]) || get_in(km, [:victim_character_id])

      attacker_ids =
        get_attackers(km)
        |> Enum.map(&get_in(&1, ["character_id"]))
        |> Enum.reject(&is_nil/1)

      [victim_id | attacker_ids] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  @doc """
  Counts unique corporations from killmail data.

  Extracts all unique corporation IDs from both victims and attackers.

  ## Parameters

    - killmails: List of killmail structs/maps with victim and attackers data

  ## Returns

    - Integer count of unique corporations
  """
  @spec count_unique_corporations(list()) :: non_neg_integer()
  def count_unique_corporations(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_corp =
        get_in(km.victim, ["corporation_id"]) || get_in(km, [:victim_corporation_id])

      attacker_corps =
        get_attackers(km)
        |> Enum.map(&get_in(&1, ["corporation_id"]))
        |> Enum.reject(&is_nil/1)

      [victim_corp | attacker_corps] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  @doc """
  Counts unique alliances from killmail data.

  Extracts all unique alliance IDs from both victims and attackers.

  ## Parameters

    - killmails: List of killmail structs/maps with victim and attackers data

  ## Returns

    - Integer count of unique alliances
  """
  @spec count_unique_alliances(list()) :: non_neg_integer()
  def count_unique_alliances(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_alliance = get_in(km.victim, ["alliance_id"]) || get_in(km, [:victim_alliance_id])

      attacker_alliances =
        get_attackers(km)
        |> Enum.map(&get_in(&1, ["alliance_id"]))
        |> Enum.reject(&is_nil/1)

      [victim_alliance | attacker_alliances] |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
    |> length()
  end

  @doc """
  Calculates average number of attackers per killmail.

  ## Parameters

    - killmails: List of killmail structs/maps with attackers data

  ## Returns

    - Float representing the average number of attackers per kill
  """
  @spec calculate_average_on_kill(list()) :: float()
  def calculate_average_on_kill([]), do: 0.0

  def calculate_average_on_kill(killmails) do
    total_attackers =
      Enum.reduce(killmails, 0, fn km, acc ->
        acc + length(get_attackers(km))
      end)

    Float.round(total_attackers / length(killmails), 1)
  end

  @doc """
  Calculates role balance score from role distribution.

  Evaluates how well-balanced the fleet composition is in terms of roles
  (DPS, logistics, tackle, etc.).

  ## Parameters

    - role_distribution: Map of role atoms to count maps (e.g., %{dps: %{count: 5}, logistics: %{count: 2}})
      or Map of role atoms to integers (e.g., %{dps: 5, logistics: 2})

  ## Returns

    - Map with :score (0.0-1.0) and :balance (0.0-1.0) keys
  """
  @spec calculate_role_balance(map()) :: %{score: float(), balance: float()}
  def calculate_role_balance(role_distribution) when role_distribution == %{} do
    %{score: 0.0, balance: 0.0}
  end

  def calculate_role_balance(role_distribution) when is_map(role_distribution) do
    # Check for key roles
    has_dps = Map.has_key?(role_distribution, :dps)
    has_logistics = Map.has_key?(role_distribution, :logistics)
    has_tackle = Map.has_key?(role_distribution, :tackle)

    base_score =
      case {has_dps, has_logistics, has_tackle} do
        {true, true, true} -> 0.8
        {true, true, false} -> 0.6
        {true, false, true} -> 0.6
        {true, false, false} -> 0.4
        _ -> 0.2
      end

    # Calculate distribution balance
    role_counts =
      role_distribution
      |> Map.values()
      |> Enum.map(&extract_count/1)

    balance = calculate_distribution_balance(role_counts)

    %{score: base_score * balance, balance: balance}
  end

  @doc """
  Calculates distribution balance from a list of counts.

  Uses variance-based calculation where lower variance means better balance.

  ## Parameters

    - counts: List of integers representing counts in each category

  ## Returns

    - Float between 0.0 and 1.0 where higher means more balanced
  """
  @spec calculate_distribution_balance(list()) :: float()
  def calculate_distribution_balance([]), do: 0.0

  def calculate_distribution_balance(counts) when is_list(counts) do
    mean = SharedUtilities.average(counts)
    variance = SharedUtilities.calculate_variance(counts)
    # Higher balance when variance is lower
    max(0.0, 1.0 - variance / (mean * mean + 1))
  end

  @doc """
  Calculates doctrine coherence based on ship classes.

  Lower diversity in ship classes indicates better doctrine adherence.

  ## Parameters

    - ship_classes: Map of ship class to ship data or count

  ## Returns

    - Float between 0.0 and 1.0 where higher means more coherent
  """
  @spec calculate_doctrine_coherence(map() | list()) :: float()
  def calculate_doctrine_coherence(ship_classes) when ship_classes == %{}, do: 0.0

  def calculate_doctrine_coherence(ship_classes) when is_map(ship_classes) do
    class_count = map_size(ship_classes)
    # Higher coherence with fewer ship classes
    max(0.0, 1.0 - class_count / @max_ship_classes)
  end

  def calculate_doctrine_coherence(participants) when is_list(participants) do
    ship_types = Enum.map(participants, &get_ship_type_id/1)
    unique_types = Enum.uniq(ship_types) |> length()
    total = length(ship_types)

    if total > 0 do
      # Lower diversity = higher coherence
      max(0.0, 1.0 - unique_types / total)
    else
      0.0
    end
  end

  @doc """
  Delegates average calculation to SharedUtilities.
  """
  @spec average(list()) :: float()
  defdelegate average(list), to: SharedUtilities

  @doc """
  Delegates variance calculation to SharedUtilities.
  """
  @spec calculate_variance(list()) :: float()
  defdelegate calculate_variance(list), to: SharedUtilities

  # Private helper functions

  defp get_attackers(%{attackers: attackers}) when is_list(attackers), do: attackers

  defp get_attackers(%{raw_data: %{"attackers" => attackers}}) when is_list(attackers),
    do: attackers

  defp get_attackers(km) when is_map(km) do
    case Map.get(km, :attackers) || get_in(km, [:raw_data, "attackers"]) do
      attackers when is_list(attackers) -> attackers
      _ -> []
    end
  end

  defp get_attackers(_), do: []

  defp extract_count(%{count: count}) when is_integer(count), do: count
  defp extract_count(count) when is_integer(count), do: count
  defp extract_count(_), do: 0

  defp get_ship_type_id(%{ship_type_id: id}) when not is_nil(id), do: id
  defp get_ship_type_id(%{"ship_type_id" => id}) when not is_nil(id), do: id
  defp get_ship_type_id(participant) when is_map(participant), do: participant[:ship_type_id]
  defp get_ship_type_id(_), do: nil
end
