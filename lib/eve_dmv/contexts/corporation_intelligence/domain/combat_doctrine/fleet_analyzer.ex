defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrine.FleetAnalyzer do
  @moduledoc """
  Fleet composition analysis for combat doctrine recognition.

  Analyzes ship compositions, role distributions, and tactical indicators
  from fleet engagements to identify doctrine patterns.
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.StaticData.ShipTypes

  require Ash.Query
  require Logger

  # Engagement time window in seconds (10 minutes)
  @engagement_window_seconds 600

  @doc """
  Analyzes fleet compositions from combat data.

  Groups killmails into engagements and analyzes the ship compositions,
  roles, and tactical indicators for each engagement.
  """
  def analyze_fleet_compositions(combat_data, min_fleet_kills \\ 10) do
    fleet_engagements =
      group_killmails_by_engagement(combat_data.killmails, combat_data.corporation_id)

    fleet_compositions =
      fleet_engagements
      |> Enum.filter(fn engagement -> length(engagement.corp_participants) >= 3 end)
      |> Enum.map(&analyze_single_fleet_composition/1)
      |> Enum.filter(&(&1 != nil))

    if length(fleet_compositions) < min_fleet_kills do
      {:error, :insufficient_fleet_data}
    else
      {:ok, fleet_compositions}
    end
  end

  @doc """
  Groups killmails by engagement based on time proximity and participant overlap.
  """
  def group_killmails_by_engagement(killmails, corporation_id) do
    sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

    sorted_killmails
    |> Enum.reduce([], fn km, acc ->
      corp_participants = extract_corp_participants(km, corporation_id)

      if corp_participants == [] do
        acc
      else
        case find_matching_engagement(km, acc, corporation_id) do
          nil ->
            new_engagement = %{
              start_time: km.killmail_time,
              end_time: km.killmail_time,
              killmails: [km],
              corp_participants: corp_participants,
              systems: [km.solar_system_id]
            }

            [new_engagement | acc]

          {matching_engagement, other_engagements} ->
            updated_engagement = %{
              matching_engagement
              | end_time: km.killmail_time,
                killmails: [km | matching_engagement.killmails],
                corp_participants:
                  Enum.uniq(matching_engagement.corp_participants ++ corp_participants),
                systems: Enum.uniq([km.solar_system_id | matching_engagement.systems])
            }

            [updated_engagement | other_engagements]
        end
      end
    end)
    |> Enum.reverse()
  end

  @doc """
  Extracts corporation participants from a killmail.
  """
  def extract_corp_participants(killmail, corporation_id) do
    initial_participants =
      if killmail.victim_corporation_id == corporation_id do
        [
          %{
            character_id: killmail.victim_character_id,
            ship_type_id: killmail.victim_ship_type_id,
            role: :victim
          }
        ]
      else
        []
      end

    case killmail.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        corp_attackers =
          attackers
          |> Enum.filter(&(&1["corporation_id"] == corporation_id))
          |> Enum.map(fn attacker ->
            %{
              character_id: attacker["character_id"],
              ship_type_id: attacker["ship_type_id"],
              role: :attacker,
              damage_done: attacker["damage_done"] || 0,
              final_blow: attacker["final_blow"] || false
            }
          end)
          |> Enum.filter(&(&1.character_id != nil))

        initial_participants ++ corp_attackers

      _ ->
        initial_participants
    end
  end

  @doc """
  Analyzes ship composition from a list of participants.
  """
  def analyze_ship_composition(participants) do
    ship_types =
      participants
      |> Enum.map(& &1.ship_type_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    ship_classes =
      participants
      |> Enum.map(fn p -> classify_ship_type(p.ship_type_id) end)
      |> Enum.frequencies()

    tank_distribution = analyze_tank_distribution(participants)
    range_distribution = analyze_range_distribution(participants)

    %{
      ship_types: ship_types,
      ship_classes: ship_classes,
      total_ships: length(participants),
      diversity_index: calculate_composition_diversity(ship_types),
      tank_distribution: tank_distribution,
      range_distribution: range_distribution,
      specialized_ships: identify_specialized_ships(participants)
    }
  end

  @doc """
  Analyzes role distribution among participants.
  """
  def analyze_role_distribution(participants) do
    roles =
      participants
      |> Enum.map(fn p -> get_default_role(classify_ship_type(p.ship_type_id)) end)
      |> Enum.frequencies()

    total = length(participants)

    role_percentages =
      Enum.map(roles, fn {role, count} ->
        {role, count / max(total, 1) * 100}
      end)
      |> Map.new()

    %{
      roles: roles,
      role_percentages: role_percentages,
      balance_assessment: assess_role_balance(role_percentages),
      support_ratio: calculate_support_ratio(role_percentages)
    }
  end

  @doc """
  Analyzes tactical indicators from an engagement.
  """
  def analyze_tactical_indicators(engagement) do
    %{
      killmail_density: calculate_killmail_density(engagement),
      coordination_quality: analyze_coordination_quality(engagement),
      target_focus: analyze_target_focus(engagement),
      escalation_pattern: analyze_escalation_pattern(engagement)
    }
  end

  @doc """
  Classifies a ship type by its category.
  Uses the centralized ShipTypes module for consistent classification.
  """
  def classify_ship_type(nil), do: :other

  def classify_ship_type(ship_type_id) do
    case ShipTypes.classify_ship_type(ship_type_id) do
      :unknown -> :other
      class -> class
    end
  end

  # Private functions

  defp find_matching_engagement(killmail, engagements, corporation_id) do
    corp_participants = extract_corp_participants(killmail, corporation_id)
    participant_ids = Enum.map(corp_participants, & &1.character_id)

    matching =
      Enum.find(engagements, fn engagement ->
        time_diff = DateTimeUtils.diff(killmail.killmail_time, engagement.end_time, :second)
        within_time_window = time_diff <= @engagement_window_seconds and time_diff >= 0

        engagement_participant_ids = Enum.map(engagement.corp_participants, & &1.character_id)

        overlap =
          MapSet.intersection(MapSet.new(participant_ids), MapSet.new(engagement_participant_ids))

        has_overlap = MapSet.size(overlap) > 0
        system_match = killmail.solar_system_id in engagement.systems

        within_time_window and (has_overlap or system_match)
      end)

    case matching do
      nil -> nil
      engagement -> {engagement, Enum.filter(engagements, &(&1 != engagement))}
    end
  end

  defp analyze_single_fleet_composition(engagement) do
    participants = engagement.corp_participants

    if length(participants) < 3 do
      nil
    else
      ship_analysis = analyze_ship_composition(participants)
      role_analysis = analyze_role_distribution(participants)
      tactical_analysis = analyze_tactical_indicators(engagement)

      %{
        engagement_id: generate_engagement_id(engagement),
        timestamp: engagement.start_time,
        duration_seconds: DateTimeUtils.diff(engagement.end_time, engagement.start_time, :second),
        participant_count: length(participants),
        ship_composition: ship_analysis,
        role_distribution: role_analysis,
        tactical_indicators: tactical_analysis,
        systems_involved: engagement.systems,
        killmails: length(engagement.killmails),
        doctrine_indicators:
          calculate_doctrine_indicators(ship_analysis, role_analysis, tactical_analysis)
      }
    end
  end

  defp analyze_tank_distribution(_participants), do: %{shield: 50.0, armor: 50.0}
  defp analyze_range_distribution(_participants), do: %{short: 50.0, long: 50.0}

  defp calculate_composition_diversity(ship_types) when map_size(ship_types) == 0, do: 0.0

  defp calculate_composition_diversity(ship_types) do
    total = Enum.sum(Map.values(ship_types))
    unique_types = map_size(ship_types)

    if total > 0 do
      min(1.0, unique_types / max(total / 3, 1))
    else
      0.0
    end
  end

  defp identify_specialized_ships(participants) do
    participants
    |> Enum.filter(fn p -> specialized_ship?(p.ship_type_id) end)
    |> Enum.map(fn p ->
      %{ship_type_id: p.ship_type_id, specialization: get_ship_specialization(p.ship_type_id)}
    end)
  end

  defp specialized_ship?(_ship_type_id), do: false
  defp get_ship_specialization(_ship_type_id), do: :general

  defp get_default_role(ship_class) do
    case ship_class do
      :frigate -> :tackle
      :destroyer -> :dps
      :cruiser -> :dps
      :battlecruiser -> :dps
      :battleship -> :dps
      :capital -> :capital
      _ -> :support
    end
  end

  defp assess_role_balance(role_percentages) do
    dps = Map.get(role_percentages, :dps, 0)
    support = Map.get(role_percentages, :support, 0) + Map.get(role_percentages, :logistics, 0)
    tackle = Map.get(role_percentages, :tackle, 0)

    cond do
      dps > 80 -> :dps_heavy
      support > 40 -> :support_heavy
      tackle > 30 -> :tackle_heavy
      true -> :balanced
    end
  end

  defp calculate_support_ratio(role_percentages) do
    support = Map.get(role_percentages, :support, 0) + Map.get(role_percentages, :logistics, 0)
    dps = Map.get(role_percentages, :dps, 0)
    if dps > 0, do: support / dps, else: 0.0
  end

  defp calculate_killmail_density(engagement) do
    duration = DateTimeUtils.diff(engagement.end_time, engagement.start_time, :second)
    if duration > 0, do: length(engagement.killmails) / (duration / 60), else: 0.0
  end

  defp analyze_coordination_quality(engagement) do
    killmails = engagement.killmails

    if length(killmails) < 2 do
      %{score: 0.5, classification: :unknown}
    else
      time_deltas =
        killmails
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [km1, km2] ->
          DateTimeUtils.diff(km2.killmail_time, km1.killmail_time, :second)
        end)

      avg_delta =
        if time_deltas != [], do: Enum.sum(time_deltas) / length(time_deltas), else: 0

      score = max(0, 1 - avg_delta / 300)

      %{
        score: score,
        classification: classify_coordination_quality(score)
      }
    end
  end

  defp classify_coordination_quality(score) when score >= 0.8, do: :excellent
  defp classify_coordination_quality(score) when score >= 0.6, do: :good
  defp classify_coordination_quality(score) when score >= 0.4, do: :moderate
  defp classify_coordination_quality(_), do: :poor

  defp analyze_target_focus(engagement) do
    killmails = engagement.killmails

    if length(killmails) < 2 do
      %{focus_ratio: 0.0, classification: :unknown}
    else
      victim_types =
        killmails
        |> Enum.map(& &1.victim_ship_type_id)
        |> Enum.frequencies()

      max_count = Enum.max(Map.values(victim_types))
      focus_ratio = max_count / length(killmails)

      %{
        focus_ratio: focus_ratio,
        classification: classify_target_focus(focus_ratio)
      }
    end
  end

  defp classify_target_focus(ratio) when ratio >= 0.7, do: :highly_focused
  defp classify_target_focus(ratio) when ratio >= 0.4, do: :moderately_focused
  defp classify_target_focus(_), do: :distributed

  defp analyze_escalation_pattern(engagement) do
    killmails = engagement.killmails

    if length(killmails) < 3 do
      %{trend: 0.0, classification: :stable}
    else
      values =
        killmails
        |> Enum.map(&estimate_ship_value/1)

      trend = calculate_value_trend(values)

      %{
        trend: trend,
        classification: classify_escalation_pattern(trend)
      }
    end
  end

  defp estimate_ship_value(killmail) do
    case killmail.raw_data do
      %{"zkb" => %{"totalValue" => value}} when is_number(value) -> value
      _ -> 0.0
    end
  end

  defp calculate_value_trend(values) when length(values) < 2, do: 0.0

  defp calculate_value_trend(values) do
    n = length(values)
    indexed = Enum.with_index(values)
    sum_x = n * (n - 1) / 2
    sum_y = Enum.sum(values)
    sum_xy = Enum.reduce(indexed, 0, fn {y, x}, acc -> acc + x * y end)
    sum_x2 = Enum.reduce(0..(n - 1), 0, fn x, acc -> acc + x * x end)

    denominator = n * sum_x2 - sum_x * sum_x

    if denominator != 0 do
      (n * sum_xy - sum_x * sum_y) / denominator
    else
      0.0
    end
  end

  defp classify_escalation_pattern(trend) when trend > 1000, do: :escalating
  defp classify_escalation_pattern(trend) when trend < -1000, do: :de_escalating
  defp classify_escalation_pattern(_), do: :stable

  defp generate_engagement_id(engagement) do
    :crypto.hash(:md5, "#{engagement.start_time}-#{hd(engagement.systems)}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end

  defp calculate_doctrine_indicators(ship_analysis, role_analysis, tactical_analysis) do
    %{
      shield_tank_dominance: Map.get(ship_analysis.tank_distribution, :shield, 0) > 60,
      armor_tank_dominance: Map.get(ship_analysis.tank_distribution, :armor, 0) > 60,
      long_range_weapons: Map.get(ship_analysis.range_distribution, :long, 0) > 60,
      short_range_weapons: Map.get(ship_analysis.range_distribution, :short, 0) > 60,
      high_mobility: calculate_mobility_percentage(ship_analysis) > 40,
      high_dps: role_analysis.balance_assessment == :dps_heavy,
      high_logistics_ratio: role_analysis.support_ratio > 0.3,
      coordination_focus: tactical_analysis.coordination_quality.score > 0.7,
      capital_presence: Map.get(ship_analysis.ship_classes, :capital, 0) > 0
    }
  end

  defp calculate_mobility_percentage(ship_analysis) do
    mobile_classes = [:frigate, :destroyer, :interceptor]
    total = ship_analysis.total_ships

    if total > 0 do
      mobile_count =
        Enum.reduce(mobile_classes, 0, fn class, acc ->
          acc + Map.get(ship_analysis.ship_classes, class, 0)
        end)

      mobile_count / total * 100
    else
      0.0
    end
  end
end
