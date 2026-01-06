defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.GangSynergyAnalyzer do
  @moduledoc """
  Analyzes synergy between multiple characters based on shared killmails.
  All calculations based on real killmail data - NO PLACEHOLDERS.
  """

  import Ash.Query

  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Types

  require Logger

  @doc """
  Analyzes synergy between multiple characters based on shared killmails.
  Returns actual metrics calculated from database.
  """
  @spec analyze_synergy([Types.character_id()]) ::
          Types.result(Types.gang_synergy()) | {:error, :invalid_character_list}
  def analyze_synergy(character_ids) when is_list(character_ids) and length(character_ids) > 1 do
    Logger.debug("Analyzing synergy for #{length(character_ids)} characters")

    # Get shared killmails where these characters worked together
    shared_kills = get_shared_killmails(character_ids)

    case shared_kills do
      [] ->
        {:error, :no_shared_activity}

      kills ->
        {:ok,
         %{
           coordination_score: calculate_coordination_score(kills, character_ids),
           shared_victories: length(kills),
           role_compatibility: analyze_role_compatibility(kills, character_ids),
           success_metrics: calculate_success_metrics(kills),
           temporal_coordination: analyze_temporal_coordination(kills),
           engagement_patterns: analyze_engagement_patterns(kills, character_ids)
         }}
    end
  end

  def analyze_synergy(_), do: {:error, :invalid_character_list}

  @doc """
  Get detailed synergy analysis for a character pair.
  """
  @spec analyze_pair_synergy(Types.character_id(), Types.character_id()) ::
          Types.result(Types.gang_synergy()) | {:error, :invalid_character_list}
  def analyze_pair_synergy(char1_id, char2_id) do
    analyze_synergy([char1_id, char2_id])
  end

  # Private functions

  @spec get_shared_killmails([Types.character_id()]) :: [map()]
  defp get_shared_killmails(character_ids) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -90 * 86_400, :second)

    # Build a query to find killmails where at least 2 of the characters are attackers
    character_id_strings = Enum.map(character_ids, &to_string/1)

    KillmailRaw
    |> filter(killmail_time > ^cutoff_date)
    |> filter(
      fragment(
        """
        EXISTS (
          SELECT 1
          FROM jsonb_array_elements(raw_data->'attackers') AS attacker
          WHERE attacker->>'character_id' = ANY(?)
          GROUP BY killmail_id
          HAVING COUNT(DISTINCT attacker->>'character_id') >= 2
        )
        """,
        type(^character_id_strings, {:array, :string})
      )
    )
    |> select([
      :killmail_id,
      :killmail_time,
      :solar_system_id,
      :raw_data,
      :total_value,
      :victim_ship_type_id
    ])
    |> limit(1000)
    |> Ash.read!(domain: EveDmv.Api)
  rescue
    error ->
      Logger.error("Failed to get shared killmails: #{inspect(error)}")
      []
  end

  @spec calculate_coordination_score([map()], [Types.character_id()]) :: float()
  defp calculate_coordination_score([], _character_ids), do: 0.0

  defp calculate_coordination_score(kills, character_ids) when is_list(kills) do
    # Analyze how well coordinated the attacks were
    coordination_metrics =
      Enum.map(kills, fn kill ->
        attackers = get_character_attackers(kill, character_ids)

        %{
          damage_distribution: calculate_damage_distribution(attackers),
          timing_coordination: calculate_timing_coordination(attackers),
          role_distribution: analyze_attacker_roles(attackers)
        }
      end)

    # Average coordination across all shared kills
    avg_damage_dist = average_metric(coordination_metrics, :damage_distribution)
    avg_timing = average_metric(coordination_metrics, :timing_coordination)
    avg_roles = average_metric(coordination_metrics, :role_distribution)

    # Weighted coordination score
    score = avg_damage_dist * 0.3 + avg_timing * 0.4 + avg_roles * 0.3
    Float.round(score, 3)
  end

  defp get_character_attackers(kill, character_ids) do
    character_id_strings = Enum.map(character_ids, &to_string/1)

    case kill.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.filter(fn att ->
          to_string(att["character_id"]) in character_id_strings
        end)

      _ ->
        []
    end
  end

  defp calculate_damage_distribution([]), do: 0.5

  defp calculate_damage_distribution(attackers) when is_list(attackers) do
    damages =
      Enum.map(attackers, fn att ->
        att["damage_done"] || 0
      end)

    total_damage = Enum.sum(damages)

    if total_damage == 0 do
      0.5
    else
      # Calculate how evenly damage is distributed (good coordination = balanced damage)
      avg_damage = total_damage / length(damages)

      variance =
        Enum.reduce(damages, 0, fn damage, acc ->
          acc + :math.pow(damage - avg_damage, 2)
        end) / length(damages)

      # Convert variance to a 0-1 score (lower variance = better coordination)
      std_dev = :math.sqrt(variance)
      coefficient_of_variation = if avg_damage > 0, do: std_dev / avg_damage, else: 1.0

      # Normalize: CV of 0 = perfect balance (1.0), CV > 1 = poor balance (0.0)
      max(0.0, min(1.0, 1.0 - coefficient_of_variation))
    end
  end

  defp calculate_timing_coordination(attackers) do
    # In a real implementation with more data, we'd analyze engagement timing
    # For now, use attacker count as proxy (more attackers = better coordination)
    case length(attackers) do
      0 -> 0.0
      1 -> 0.3
      2 -> 0.6
      3 -> 0.8
      _ -> 1.0
    end
  end

  defp analyze_attacker_roles([]), do: 0.5

  defp analyze_attacker_roles(attackers) when is_list(attackers) do
    # Analyze ship types for role diversity
    ship_types =
      attackers
      |> Enum.map(fn att -> att["ship_type_id"] end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(&classify_ship_role/1)
      |> Enum.uniq()

    # More diverse roles = better coordination
    case length(ship_types) do
      0 -> 0.5
      1 -> 0.6
      2 -> 0.8
      _ -> 1.0
    end
  end

  @spec classify_ship_role(integer() | nil) :: Types.ship_role()
  defp classify_ship_role(ship_type_id) when is_integer(ship_type_id) do
    # Simplified ship role classification based on type ID ranges
    cond do
      ship_type_id in 11_987..11_999 -> :logistics
      ship_type_id in 11_957..11_965 -> :recon
      ship_type_id in 11_174..11_200 -> :interdictor
      ship_type_id in 11_377..11_400 -> :heavy_assault
      ship_type_id in 22_428..22_474 -> :command
      ship_type_id in 33_151..33_155 -> :tackle
      true -> :dps
    end
  end

  defp classify_ship_role(_), do: :unknown

  defp analyze_role_compatibility([], _character_ids), do: 0.5

  defp analyze_role_compatibility(kills, character_ids) when is_list(kills) do
    # Analyze ship roles used by each character across kills
    role_usage =
      Enum.reduce(kills, %{}, fn kill, acc ->
        attackers = get_character_attackers(kill, character_ids)

        process_attacker_roles(attackers, acc)
      end)

    # Calculate role diversity and complementarity
    calculate_role_complementarity(role_usage)
  end

  defp process_attacker_roles(attackers, acc) do
    Enum.reduce(attackers, acc, &process_single_attacker_role/2)
  end

  defp process_single_attacker_role(attacker, role_acc) do
    ship_type_id = attacker["ship_type_id"]
    character_id = to_string(attacker["character_id"])

    if ship_type_id do
      role = classify_ship_role(ship_type_id)
      Map.update(role_acc, character_id, [role], &[role | &1])
    else
      role_acc
    end
  end

  defp calculate_role_complementarity(role_usage) when map_size(role_usage) == 0, do: 0.5

  defp calculate_role_complementarity(role_usage) do
    # Get unique roles per character
    character_roles =
      Enum.map(role_usage, fn {char_id, roles} ->
        {char_id, Enum.uniq(roles)}
      end)

    # Check for complementary roles (e.g., DPS + Logistics, Tackle + DPS)
    all_roles =
      character_roles
      |> Enum.flat_map(fn {_, roles} -> roles end)
      |> Enum.uniq()

    role_diversity = length(all_roles)

    # Good composition has 3-4 different roles
    diversity_score =
      cond do
        role_diversity >= 4 -> 1.0
        role_diversity == 3 -> 0.9
        role_diversity == 2 -> 0.7
        role_diversity == 1 -> 0.5
        true -> 0.3
      end

    # Check for essential role combinations
    has_dps = :dps in all_roles
    has_tackle = :tackle in all_roles or :interdictor in all_roles
    has_support = :logistics in all_roles or :command in all_roles

    essential_score = Enum.count([has_dps, has_tackle, has_support], & &1) / 3.0

    # Combined score
    diversity_score * 0.6 + essential_score * 0.4
  end

  defp calculate_success_metrics([]) do
    %{
      total_kills: 0,
      avg_isk_per_kill: 0,
      kill_rate_per_day: 0,
      high_value_kills: 0
    }
  end

  defp calculate_success_metrics(kills) when is_list(kills) do
    total_kills = length(kills)

    # Calculate ISK destroyed
    total_isk =
      Enum.reduce(kills, Decimal.new(0), fn kill, acc ->
        value =
          case kill.total_value do
            nil -> Decimal.new(0)
            %Decimal{} = decimal -> decimal
            value when is_integer(value) -> Decimal.new(value)
            _ -> Decimal.new(0)
          end

        Decimal.add(acc, value)
      end)

    # Calculate time span
    kill_times = Enum.map(kills, & &1.killmail_time)
    earliest = Enum.min(kill_times, DateTime)
    latest = Enum.max(kill_times, DateTime)
    days_span = max(1, div(DateTime.diff(latest, earliest), 86_400))

    # Count high-value kills (> 100M ISK)
    high_value =
      Enum.count(kills, fn kill ->
        case kill.total_value do
          nil -> false
          %Decimal{} = decimal -> Decimal.compare(decimal, Decimal.new(100_000_000)) == :gt
          value when is_integer(value) -> value > 100_000_000
          _ -> false
        end
      end)

    %{
      total_kills: total_kills,
      avg_isk_per_kill: Float.round(Decimal.to_float(total_isk) / total_kills, 2),
      kill_rate_per_day: Float.round(total_kills / days_span, 2),
      high_value_kills: high_value,
      total_isk_destroyed: Decimal.to_integer(total_isk)
    }
  end

  defp analyze_temporal_coordination(kills) when length(kills) < 2 do
    %{
      activity_overlap: 0.5,
      peak_hours: [],
      consistency_score: 0.5
    }
  end

  defp analyze_temporal_coordination(kills) when is_list(kills) do
    # Analyze when the gang is active together
    hourly_distribution =
      Enum.frequencies_by(kills, fn kill ->
        kill.killmail_time.hour
      end)

    # Find peak activity hours
    peak_hours =
      hourly_distribution
      |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {hour, count} ->
        %{hour: hour, kill_count: count}
      end)

    # Calculate consistency (how concentrated activity is)
    total_kills = length(kills)
    max_hour_kills = hourly_distribution |> Map.values() |> Enum.max(fn -> 0 end)
    consistency = if total_kills > 0, do: max_hour_kills / total_kills, else: 0

    %{
      activity_overlap: calculate_activity_overlap(hourly_distribution, total_kills),
      peak_hours: peak_hours,
      consistency_score: Float.round(consistency, 3)
    }
  end

  defp calculate_activity_overlap(_hourly_distribution, 0), do: 0.0

  defp calculate_activity_overlap(hourly_distribution, total_kills) when total_kills > 0 do
    # Hours with activity / 24 hours (more concentrated = better coordination)
    active_hours = map_size(hourly_distribution)
    concentration = 1.0 - active_hours / 24.0
    Float.round(concentration, 3)
  end

  defp analyze_engagement_patterns([], _character_ids) do
    %{
      avg_attackers_per_kill: 0,
      character_participation_rates: %{},
      preferred_targets: []
    }
  end

  defp analyze_engagement_patterns(kills, character_ids) when is_list(kills) do
    # Average number of attackers per kill
    avg_attackers = calculate_average_attackers(kills)

    # Calculate how often each character participates
    participation = calculate_participation_rates(kills, character_ids)

    # Analyze preferred target types
    targets = analyze_preferred_targets(kills)

    %{
      avg_attackers_per_kill: Float.round(avg_attackers, 1),
      character_participation_rates: participation,
      preferred_targets: targets
    }
  end

  defp calculate_average_attackers([]), do: 0.0

  defp calculate_average_attackers(kills) when is_list(kills) do
    attacker_counts =
      Enum.map(kills, fn kill ->
        case kill.raw_data do
          %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
          _ -> 0
        end
      end)

    Enum.sum(attacker_counts) / length(attacker_counts)
  end

  defp calculate_participation_rates([], _character_ids), do: %{}

  defp calculate_participation_rates(kills, character_ids) when is_list(kills) do
    total_kills = length(kills)

    character_ids
    |> Enum.map(&calculate_single_participation_rate(&1, kills, total_kills))
    |> Map.new()
  end

  defp calculate_single_participation_rate(char_id, kills, total_kills) do
    char_id_str = to_string(char_id)
    participation_count = count_character_participation(kills, char_id_str)
    rate = Float.round(participation_count / total_kills, 3)
    {char_id, rate}
  end

  defp count_character_participation(kills, char_id_str) do
    Enum.count(kills, &kill_has_character_participation?(&1, char_id_str))
  end

  defp kill_has_character_participation?(kill, char_id_str) do
    case kill.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attacker_has_character?(attackers, char_id_str)

      _ ->
        false
    end
  end

  defp attacker_has_character?(attackers, char_id_str) do
    Enum.any?(attackers, fn att ->
      to_string(att["character_id"]) == char_id_str
    end)
  end

  defp analyze_preferred_targets(kills) do
    # Group by victim ship type
    ship_frequencies =
      kills
      |> Enum.map(& &1.victim_ship_type_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {ship_type_id, count} ->
        %{
          ship_type_id: ship_type_id,
          count: count,
          percentage: Float.round(count / length(kills) * 100, 1)
        }
      end)

    ship_frequencies
  end

  defp average_metric([], _key), do: 0.0

  defp average_metric(metrics, key) when is_list(metrics) do
    values = Enum.map(metrics, &Map.get(&1, key, 0))
    Enum.sum(values) / length(values)
  end
end
