defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrineAnalyzer do
  @moduledoc """
  Advanced combat doctrine recognition and analysis system for EVE Online corporations.

  Analyzes corporation-wide combat data to identify, classify, and track combat doctrines:

  - Doctrine Recognition: Shield Kiting, Armor Brawling, EWAR Heavy, Capital Escalation
  - Fleet Composition Analysis: Ship role distribution, fitting coordination, tactical synergy
  - Tactical Pattern Detection: Engagement preferences, formation analysis, coordination quality
  - Doctrine Evolution Tracking: Changes in tactics over time, adaptation patterns
  - Threat Assessment: Doctrine effectiveness, counter-strategies, vulnerability analysis

  Uses advanced statistical analysis, clustering algorithms, and tactical pattern matching
  to provide comprehensive intelligence on corporation combat capabilities and preferences.
  """

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw

  require Ash.Query
  require Logger

  # Doctrine analysis parameters
  # Minimum active members for reliable analysis
  @min_members_for_analysis 5
  # Minimum fleet kills to identify doctrine
  @min_fleet_kills_for_doctrine 10
  # Default analysis period for doctrine recognition
  @analysis_window_days 60

  # Combat doctrine definitions
  @doctrine_patterns %{
    shield_kiting: %{
      name: "Shield Kiting",
      description: "Long-range shield tanked ships with high mobility and standoff capability",
      characteristics: [
        :shield_tank_dominance,
        :long_range_weapons,
        :high_mobility,
        :standoff_tactics
      ],
      typical_ships: [:interceptors, :assault_frigates, :hacs, :battlecruisers],
      engagement_style: :range_control
    },
    armor_brawling: %{
      name: "Armor Brawling",
      description: "Close-range armor tanked ships focused on sustained DPS and tank",
      characteristics: [:armor_tank_dominance, :short_range_weapons, :high_dps, :close_engagement],
      typical_ships: [:assault_frigates, :hacs, :battleships, :logistics],
      engagement_style: :close_combat
    },
    ewar_heavy: %{
      name: "EWAR Heavy",
      description:
        "Electronic warfare focused doctrine with force multiplication through disruption",
      characteristics: [
        :high_ewar_percentage,
        :coordination_focus,
        :support_heavy,
        :disruption_tactics
      ],
      typical_ships: [:recon_ships, :ewar_frigates, :command_ships, :logistics],
      engagement_style: :force_multiplication
    },
    capital_escalation: %{
      name: "Capital Escalation",
      description: "Doctrine built around capital ship deployment and escalation scenarios",
      characteristics: [:capital_presence, :escalation_ready, :heavy_logistics, :subcap_support],
      typical_ships: [:capitals, :hics, :dictors, :logistics, :battleships],
      engagement_style: :overwhelming_force
    },
    alpha_strike: %{
      name: "Alpha Strike",
      description: "High alpha damage doctrine focused on quickly eliminating priority targets",
      characteristics: [:high_alpha_damage, :coordination_heavy, :target_calling, :burst_damage],
      typical_ships: [:stealth_bombers, :artillery_ships, :alpha_battleships],
      engagement_style: :burst_elimination
    },
    nano_gang: %{
      name: "Nano Gang",
      description: "High speed, high mobility doctrine for hit-and-run tactics",
      characteristics: [:extreme_mobility, :speed_tanking, :hit_and_run, :small_gang_focus],
      typical_ships: [:interceptors, :assault_frigates, :nano_cruisers],
      engagement_style: :guerrilla_warfare
    },
    logistics_heavy: %{
      name: "Logistics Heavy",
      description: "Doctrine emphasizing survivability through extensive logistics support",
      characteristics: [
        :high_logistics_ratio,
        :survivability_focus,
        :sustained_engagement,
        :defensive_positioning
      ],
      typical_ships: [:logistics, :guardian_scimitar, :combat_ships_with_reps],
      engagement_style: :attrition_warfare
    }
  }

  @doc """
  Analyzes comprehensive combat doctrines for a corporation.

  Examines corporation-wide combat data to identify primary and secondary combat
  doctrines, tactical patterns, and strategic preferences.

  ## Parameters
  - corporation_id: EVE corporation ID to analyze
  - options: Analysis options
    - :analysis_window_days - Days of history to analyze (default: 60)
    - :include_member_analysis - Include individual member analysis (default: true)
    - :doctrine_evolution_tracking - Track doctrine changes over time (default: true)

  ## Returns
  {:ok, doctrine_analysis} with comprehensive doctrine intelligence
  """
  def analyze_combat_doctrines(corporation_id, options \\ []) do
    analysis_window = Keyword.get(options, :analysis_window_days, @analysis_window_days)
    include_members = Keyword.get(options, :include_member_analysis, true)
    track_evolution = Keyword.get(options, :doctrine_evolution_tracking, true)

    Logger.info("Analyzing combat doctrines for corporation #{corporation_id}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, corp_combat_data} <-
           fetch_corporation_combat_data(corporation_id, analysis_window),
         {:ok, fleet_compositions} <- analyze_fleet_compositions(corp_combat_data),
         {:ok, doctrine_classification} <- classify_combat_doctrines(fleet_compositions),
         {:ok, tactical_patterns} <- analyze_tactical_patterns(corp_combat_data),
         {:ok, member_analysis} <- maybe_analyze_members(corp_combat_data, include_members),
         {:ok, evolution_analysis} <- maybe_track_evolution(corporation_id, track_evolution),
         {:ok, final_analysis} <-
           compile_doctrine_analysis(
             corporation_id,
             doctrine_classification,
             tactical_patterns,
             member_analysis,
             evolution_analysis,
             fleet_compositions
           ) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Combat doctrine analysis completed in #{duration_ms}ms:
      - Corporation: #{corporation_id}
      - Primary Doctrine: #{final_analysis.primary_doctrine.name}
      - Confidence: #{Float.round(final_analysis.primary_doctrine.confidence * 100, 1)}%
      - Fleet Engagements: #{length(fleet_compositions)}
      """)

      {:ok, final_analysis}
    end
  end

  @doc """
  Compares combat doctrines between multiple corporations.

  Identifies doctrine similarities, counters, and competitive analysis
  for intelligence and strategic planning.
  """
  def compare_combat_doctrines(corporation_ids, options \\ []) do
    Logger.info("Comparing combat doctrines for #{length(corporation_ids)} corporations")

    doctrine_analyses =
      corporation_ids
      |> Enum.map(&analyze_combat_doctrines(&1, options))
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    if length(doctrine_analyses) < 2 do
      {:error, :insufficient_data}
    else
      comparison = %{
        corporations_analyzed: length(doctrine_analyses),
        doctrine_distribution: analyze_doctrine_distribution(doctrine_analyses),
        tactical_overlaps: identify_tactical_overlaps(doctrine_analyses),
        counter_relationships: analyze_counter_relationships(doctrine_analyses),
        competitive_assessment: generate_competitive_assessment(doctrine_analyses),
        alliance_synergies: assess_alliance_synergies(doctrine_analyses)
      }

      {:ok, comparison}
    end
  end

  @doc """
  Generates counter-doctrine recommendations against a specific corporation.

  Analyzes corporation's primary doctrines and recommends effective counters
  based on tactical weaknesses and historical effectiveness.
  """
  def generate_counter_doctrine(target_corporation_id, options \\ []) do
    case analyze_combat_doctrines(target_corporation_id, options) do
      {:ok, target_analysis} ->
        counter_recommendations = %{
          target_corporation: target_corporation_id,
          target_primary_doctrine: target_analysis.primary_doctrine,
          target_weaknesses: identify_doctrine_weaknesses(target_analysis),
          recommended_counters: generate_counter_recommendations(target_analysis),
          tactical_advice: generate_tactical_advice(target_analysis),
          fleet_composition_suggestions: suggest_counter_compositions(target_analysis)
        }

        {:ok, counter_recommendations}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Tracks doctrine evolution and adaptation patterns over time.

  Identifies how corporation doctrines change in response to meta shifts,
  losses, or strategic changes.
  """
  def track_doctrine_evolution(corporation_id, options \\ []) do
    analysis_months = Keyword.get(options, :analysis_months, 6)

    # Analyze doctrine in different time periods
    time_periods =
      1..analysis_months
      |> Enum.map(fn month_offset ->
        start_days = (month_offset - 1) * 30
        end_days = month_offset * 30

        {:ok, analysis} = analyze_historical_doctrine(corporation_id, start_days, end_days)

        %{
          period: "#{month_offset} months ago",
          month_offset: month_offset,
          doctrine_analysis: analysis
        }
      end)

    # Most recent Enum.reverse(first)

    if length(time_periods) < 2 do
      {:error, :insufficient_historical_data}
    else
      evolution_analysis = %{
        corporation_id: corporation_id,
        time_periods: time_periods,
        doctrine_changes: identify_doctrine_changes(time_periods),
        adaptation_patterns: analyze_adaptation_patterns(time_periods),
        stability_score: calculate_doctrine_stability(time_periods),
        trend_predictions: predict_doctrine_trends(time_periods)
      }

      {:ok, evolution_analysis}
    end
  end

  # Private implementation

  defp fetch_corporation_combat_data(corporation_id, analysis_window_days) do
    cutoff_date =
      DateTimeUtils.add(DateTime.utc_now(), -analysis_window_days * 24 * 60 * 60, :second)

    # Fetch killmails where corporation members were involved
    victim_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(victim_corporation_id: corporation_id)
      |> Ash.Query.filter(killmail_time: [gte: cutoff_date])
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(500)

    # Fetch recent killmails to search for corporation as attackers
    attacker_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_time: [gte: cutoff_date])
      |> Ash.Query.sort(killmail_time: :desc)
      # Larger sample for attacker search
      |> Ash.Query.limit(2000)

    with {:ok, victim_killmails} <- Api.read(victim_query),
         {:ok, potential_attacker_killmails} <- Api.read(attacker_query) do
      # Filter for corporation as attackers
      attacker_killmails =
        Enum.filter(potential_attacker_killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              Enum.any?(attackers, &(&1["corporation_id"] == corporation_id))

            _ ->
              false
          end
        end)

      all_killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

      # Extract member information
      members = extract_corporation_members(all_killmails, corporation_id)

      if length(members) < @min_members_for_analysis do
        {:error, :insufficient_member_data}
      else
        combat_data = %{
          corporation_id: corporation_id,
          killmails: all_killmails,
          victim_killmails: victim_killmails,
          attacker_killmails: attacker_killmails,
          active_members: members,
          analysis_period_days: analysis_window_days,
          data_cutoff: cutoff_date
        }

        {:ok, combat_data}
      end
    end
  end

  defp extract_corporation_members(killmails, corporation_id) do
    # Extract unique character IDs for corporation members
    member_ids =
      killmails
      |> Enum.flat_map(fn km ->
        members = []

        # Member as victim
        members =
          if km.victim_corporation_id == corporation_id do
            [km.victim_character_id | members]
          else
            members
          end

        # Members as attackers
        members =
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              corp_attackers =
                attackers
                |> Enum.filter(&(&1["corporation_id"] == corporation_id))
                |> Enum.map(& &1["character_id"])
                |> Enum.filter(&(&1 != nil))

              members ++ corp_attackers

            _ ->
              members
          end

        members
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    member_ids
  end

  defp analyze_fleet_compositions(combat_data) do
    # Group killmails by engagement to identify fleet compositions
    fleet_engagements =
      group_killmails_by_engagement(combat_data.killmails, combat_data.corporation_id)

    fleet_compositions =
      fleet_engagements
      # Minimum fleet size
      |> Enum.filter(fn engagement -> length(engagement.corp_participants) >= 3 end)
      |> Enum.map(&analyze_single_fleet_composition/1)
      |> Enum.filter(&(&1 != nil))

    if length(fleet_compositions) < @min_fleet_kills_for_doctrine do
      {:error, :insufficient_fleet_data}
    else
      {:ok, fleet_compositions}
    end
  end

  defp group_killmails_by_engagement(killmails, corporation_id) do
    # Group killmails that likely represent the same engagement
    # Based on time proximity and participant overlap

    sorted_killmails = Enum.sort_by(killmails, & &1.killmail_time)

    engagements =
      sorted_killmails
      |> Enum.reduce([], fn km, acc ->
        corp_participants = extract_corp_participants(km, corporation_id)

        if Enum.empty?(corp_participants) do
          acc
        else
          case find_matching_engagement(km, acc, corporation_id) do
            nil ->
              # Start new engagement
              new_engagement = %{
                start_time: km.killmail_time,
                end_time: km.killmail_time,
                killmails: [km],
                corp_participants: corp_participants,
                systems: [km.solar_system_id]
              }

              [new_engagement | acc]

            {matching_engagement, other_engagements} ->
              # Add to existing engagement
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

    engagements
  end

  defp extract_corp_participants(killmail, corporation_id) do
    # Participant as victim
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

    # Participants as attackers
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

  defp find_matching_engagement(killmail, engagements, corporation_id) do
    # Find engagement within time window with participant overlap
    # 10 minutes
    time_window_seconds = 600

    corp_participants = extract_corp_participants(killmail, corporation_id)
    participant_ids = Enum.map(corp_participants, & &1.character_id)

    matching =
      Enum.find(engagements, fn engagement ->
        # Check time proximity
        time_diff = DateTimeUtils.diff(killmail.killmail_time, engagement.end_time, :second)
        within_time_window = time_diff <= time_window_seconds and time_diff >= 0

        # Check participant overlap
        engagement_participant_ids = Enum.map(engagement.corp_participants, & &1.character_id)

        overlap =
          MapSet.intersection(MapSet.new(participant_ids), MapSet.new(engagement_participant_ids))

        has_overlap = MapSet.size(overlap) > 0

        # Check system proximity (same system or adjacent)
        system_match = killmail.solar_system_id in engagement.systems

        within_time_window and (has_overlap or system_match)
      end)

    case matching do
      nil ->
        nil

      engagement ->
        other_engagements = Enum.filter(engagements, &(&1 != engagement))
        {engagement, other_engagements}
    end
  end

  defp analyze_single_fleet_composition(engagement) do
    participants = engagement.corp_participants

    if length(participants) < 3 do
      nil
    else
      # Analyze ship composition
      ship_analysis = analyze_ship_composition(participants)

      # Analyze roles and coordination
      role_analysis = analyze_role_distribution(participants)

      # Analyze tactical indicators
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

  defp analyze_ship_composition(participants) do
    # Analyze the types of ships used in this engagement
    ship_types =
      participants
      |> Enum.map(& &1.ship_type_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    ship_classes =
      participants
      |> Enum.map(fn p -> classify_ship_type(p.ship_type_id) end)
      |> Enum.frequencies()

    # Analyze tank types (simplified heuristic)
    tank_distribution = analyze_tank_distribution(participants)

    # Analyze weapon ranges (simplified heuristic)
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

  defp classify_ship_type(ship_type_id) do
    cond do
      ship_type_id in 580..700 -> :frigate
      ship_type_id in 420..450 -> :destroyer
      ship_type_id in 620..650 -> :cruiser
      ship_type_id in 540..570 -> :battlecruiser
      ship_type_id in 640..670 -> :battleship
      ship_type_id in 19_720..19_740 -> :capital
      ship_type_id in 28_650..28_710 -> :strategic_cruiser
      true -> :other
    end
  end

  defp analyze_tank_distribution(participants) do
    # Simplified tank type analysis based on ship types
    # In production, this would analyze actual fits or damage patterns

    tank_types =
      participants
      |> Enum.map(fn p ->
        ship_class = classify_ship_type(p.ship_type_id)
        infer_tank_type(ship_class, p.ship_type_id)
      end)
      |> Enum.frequencies()

    total = length(participants)

    tank_types
    |> Enum.map(fn {tank_type, count} ->
      {tank_type, Float.round(count / total, 2)}
    end)
    |> Map.new()
  end

  defp infer_tank_type(ship_class, ship_type_id) do
    # Simplified tank type inference
    case ship_class do
      # Some armor frigs
      :frigate -> if ship_type_id in [588, 589, 590], do: :armor, else: :shield
      :destroyer -> :shield
      # Arbitrator, Augoror
      :cruiser -> if ship_type_id in [622, 623], do: :armor, else: :shield
      # Prophecy, Harbinger
      :battlecruiser -> if ship_type_id in [544, 545], do: :armor, else: :shield
      # Amarr/Gallente BS
      :battleship -> if ship_type_id in [641, 642, 643], do: :armor, else: :shield
      # Most capitals are armor
      :capital -> :armor
      _ -> :unknown
    end
  end

  defp analyze_range_distribution(participants) do
    # Simplified range analysis based on ship types
    range_types =
      participants
      |> Enum.map(fn p ->
        ship_class = classify_ship_type(p.ship_type_id)
        infer_weapon_range(ship_class, p.ship_type_id)
      end)
      |> Enum.frequencies()

    total = length(participants)

    range_types
    |> Enum.map(fn {range_type, count} ->
      {range_type, Float.round(count / total, 2)}
    end)
    |> Map.new()
  end

  defp infer_weapon_range(ship_class, _ship_type_id) do
    # Simplified weapon range inference
    case ship_class do
      :frigate -> :short_range
      :destroyer -> :medium_range
      :cruiser -> :medium_range
      :battlecruiser -> :long_range
      :battleship -> :long_range
      :capital -> :very_long_range
      _ -> :medium_range
    end
  end

  defp calculate_composition_diversity(ship_types) do
    if map_size(ship_types) == 0 do
      0.0
    else
      total_ships = Map.values(ship_types) |> Enum.sum()

      # Shannon diversity index
      shannon_diversity =
        ship_types
        |> Enum.map(fn {_ship, count} ->
          proportion = count / total_ships
          -proportion * :math.log(proportion)
        end)
        |> Enum.sum()

      max_diversity = :math.log(map_size(ship_types))
      if max_diversity > 0, do: shannon_diversity / max_diversity, else: 0.0
    end
  end

  defp identify_specialized_ships(participants) do
    # Identify ships with specialized roles
    specialized =
      participants
      |> Enum.filter(fn p ->
        specialized_ship?(p.ship_type_id)
      end)
      |> Enum.map(fn p ->
        %{
          ship_type_id: p.ship_type_id,
          specialization: get_ship_specialization(p.ship_type_id),
          character_id: p.character_id
        }
      end)

    %{
      count: length(specialized),
      types: Enum.group_by(specialized, & &1.specialization),
      percentage:
        if(Enum.empty?(participants),
          do: 0.0,
          else: length(specialized) / length(participants)
        )
    }
  end

  defp specialized_ship?(ship_type_id) do
    get_ship_specialization(ship_type_id) != :general
  end

  defp get_ship_specialization(ship_type_id) do
    cond do
      # Logistics ships
      ship_type_id in [11_978, 11_987, 11_985, 12_003] -> :logistics
      # EWAR ships
      ship_type_id in [11_957, 11_958, 11_959, 11_961] -> :ewar
      # Interdictors
      ship_type_id in [22_456, 22_460, 22_464, 22_468] -> :interdiction
      # Heavy Interdictors
      ship_type_id in [12_013, 12_017, 12_021, 12_025] -> :heavy_interdiction
      # Command ships
      ship_type_id in [22_470, 22_852, 17_918, 17_920] -> :command
      # Stealth bombers
      ship_type_id in [12_032, 12_036, 12_040, 12_044] -> :bombing
      # Interceptors
      ship_type_id in [11_182, 11_196, 11_200, 11_204] -> :interception
      # Assault frigates
      ship_type_id in [11_365, 11_377, 11_379, 11_381] -> :assault
      true -> :general
    end
  end

  defp analyze_role_distribution(participants) do
    # Analyze the tactical roles represented in the fleet
    roles =
      participants
      |> Enum.map(fn p ->
        specialization = get_ship_specialization(p.ship_type_id)

        if specialization != :general do
          specialization
        else
          ship_class = classify_ship_type(p.ship_type_id)
          get_default_role(ship_class)
        end
      end)
      |> Enum.frequencies()

    total = length(participants)

    role_percentages =
      roles
      |> Enum.map(fn {role, count} ->
        {role, Float.round(count / total, 2)}
      end)
      |> Map.new()

    %{
      roles: roles,
      role_percentages: role_percentages,
      total_participants: total,
      role_balance: assess_role_balance(role_percentages),
      support_ratio: calculate_support_ratio(role_percentages)
    }
  end

  defp get_default_role(ship_class) do
    case ship_class do
      :frigate -> :tackle
      :destroyer -> :anti_support
      :cruiser -> :dps
      :battlecruiser -> :heavy_dps
      :battleship -> :main_dps
      :capital -> :capital_dps
      _ -> :general
    end
  end

  defp assess_role_balance(role_percentages) do
    # Assess how well-balanced the fleet composition is
    support_roles = [:logistics, :ewar, :command, :interdiction]
    dps_roles = [:dps, :heavy_dps, :main_dps, :capital_dps]

    support_percentage =
      support_roles |> Enum.map(&Map.get(role_percentages, &1, 0.0)) |> Enum.sum()

    dps_percentage =
      dps_roles |> Enum.map(&Map.get(role_percentages, &1, 0.0)) |> Enum.sum()

    cond do
      support_percentage > 0.4 -> :support_heavy
      support_percentage < 0.1 -> :support_light
      dps_percentage > 0.7 -> :dps_heavy
      true -> :balanced
    end
  end

  defp calculate_support_ratio(role_percentages) do
    support_roles = [:logistics, :ewar, :command, :interdiction]

    support_roles |> Enum.map(&Map.get(role_percentages, &1, 0.0)) |> Enum.sum()
  end

  defp analyze_tactical_indicators(engagement) do
    # Analyze tactical patterns and coordination indicators
    %{
      engagement_duration:
        DateTimeUtils.diff(engagement.end_time, engagement.start_time, :second),
      multi_system: length(engagement.systems) > 1,
      killmail_density: calculate_killmail_density(engagement),
      coordination_indicators: analyze_coordination_quality(engagement),
      target_focus: analyze_target_focus(engagement),
      escalation_pattern: analyze_escalation_pattern(engagement)
    }
  end

  defp calculate_killmail_density(engagement) do
    duration_minutes =
      DateTimeUtils.diff(engagement.end_time, engagement.start_time, :second) / 60

    if duration_minutes > 0 do
      length(engagement.killmails) / duration_minutes
    else
      length(engagement.killmails)
    end
  end

  defp analyze_coordination_quality(engagement) do
    # Analyze indicators of fleet coordination
    participants = engagement.corp_participants

    # Check for simultaneous participation
    attacker_participants = Enum.filter(participants, &(&1.role == :attacker))

    if length(attacker_participants) < 2 do
      %{quality: :insufficient_data}
    else
      # Analyze damage contribution consistency
      damage_values =
        attacker_participants
        |> Enum.map(& &1.damage_done)
        |> Enum.filter(&(&1 > 0))

      coordination_score =
        if length(damage_values) > 1 do
          variance = calculate_variance(damage_values)
          mean_damage = Enum.sum(damage_values) / length(damage_values)

          # Lower variance relative to mean indicates better coordination
          if mean_damage > 0 do
            1.0 - min(1.0, variance / (mean_damage * mean_damage))
          else
            0.5
          end
        else
          0.5
        end

      %{
        quality: classify_coordination_quality(coordination_score),
        score: coordination_score,
        participating_members: length(attacker_participants)
      }
    end
  end

  defp classify_coordination_quality(score) do
    cond do
      score >= 0.8 -> :excellent
      score >= 0.6 -> :good
      score >= 0.4 -> :moderate
      true -> :poor
    end
  end

  defp analyze_target_focus(engagement) do
    # Analyze how focused the corporation was on specific targets
    if length(engagement.killmails) <= 1 do
      %{focus: :single_target}
    else
      # Group killmails by victim corporation to see target focus
      victim_corps =
        engagement.killmails
        |> Enum.map(& &1.victim_corporation_id)
        |> Enum.filter(&(&1 != nil))
        |> Enum.frequencies()

      if map_size(victim_corps) == 0 do
        %{focus: :no_external_targets}
      else
        total_kills = Enum.sum(Map.values(victim_corps))
        max_corp_kills = Enum.max(Map.values(victim_corps))

        focus_ratio = max_corp_kills / total_kills

        %{
          focus: classify_target_focus(focus_ratio),
          focus_ratio: focus_ratio,
          corps_targeted: map_size(victim_corps),
          primary_target_corp: elem(Enum.max_by(victim_corps, &elem(&1, 1)), 0)
        }
      end
    end
  end

  defp classify_target_focus(focus_ratio) do
    cond do
      focus_ratio >= 0.8 -> :highly_focused
      focus_ratio >= 0.6 -> :moderately_focused
      focus_ratio >= 0.4 -> :somewhat_focused
      true -> :dispersed
    end
  end

  defp analyze_escalation_pattern(engagement) do
    # Analyze if there's an escalation pattern in ship types over time
    if length(engagement.killmails) < 3 do
      %{pattern: :insufficient_data}
    else
      sorted_killmails = Enum.sort_by(engagement.killmails, & &1.killmail_time)

      # Extract ship values over time as proxy for escalation
      ship_values = Enum.map(sorted_killmails, &estimate_ship_value/1)

      trend = calculate_value_trend(ship_values)

      %{
        pattern: classify_escalation_pattern(trend),
        value_trend: trend,
        initial_value: List.first(ship_values),
        peak_value: Enum.max(ship_values),
        final_value: List.last(ship_values)
      }
    end
  end

  defp estimate_ship_value(killmail) do
    ship_type_id = killmail.victim_ship_type_id

    cond do
      ship_type_id in 580..700 -> 5_000_000
      ship_type_id in 420..450 -> 15_000_000
      ship_type_id in 620..650 -> 50_000_000
      ship_type_id in 540..570 -> 150_000_000
      ship_type_id in 640..670 -> 300_000_000
      ship_type_id in 19_720..19_740 -> 2_000_000_000
      true -> 25_000_000
    end
  end

  defp calculate_value_trend(values) when length(values) < 2, do: 0.0

  defp calculate_value_trend(values) do
    n = length(values)
    indices = Enum.to_list(1..n)

    sum_x = Enum.sum(indices)
    sum_y = Enum.sum(values)

    sum_xy =
      indices |> Enum.zip(values) |> Enum.map(fn {x, y} -> x * y end) |> Enum.sum()

    sum_x2 = Enum.sum(Enum.map(indices, &(&1 * &1)))

    # Linear regression slope
    (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
  end

  defp classify_escalation_pattern(trend) do
    cond do
      trend > 50_000_000 -> :strong_escalation
      trend > 10_000_000 -> :moderate_escalation
      trend > -10_000_000 -> :stable
      trend > -50_000_000 -> :de_escalation
      true -> :strong_de_escalation
    end
  end

  defp calculate_doctrine_indicators(ship_analysis, role_analysis, tactical_analysis) do
    # Calculate indicators for each doctrine pattern
    %{}
    |> Map.put(:shield_kiting, %{
      shield_percentage: Map.get(ship_analysis.tank_distribution, :shield, 0.0),
      long_range_percentage:
        Map.get(ship_analysis.range_distribution, :long_range, 0.0) +
          Map.get(ship_analysis.range_distribution, :very_long_range, 0.0),
      mobility_ships: calculate_mobility_ship_percentage(ship_analysis),
      engagement_duration: tactical_analysis.engagement_duration
    })
    |> Map.put(:armor_brawling, %{
      armor_percentage: Map.get(ship_analysis.tank_distribution, :armor, 0.0),
      short_range_percentage: Map.get(ship_analysis.range_distribution, :short_range, 0.0),
      heavy_ships_percentage: calculate_heavy_ship_percentage(ship_analysis),
      # 5+ minutes
      close_engagement: tactical_analysis.engagement_duration > 300
    })
    |> Map.put(:ewar_heavy, %{
      ewar_percentage: Map.get(role_analysis.role_percentages, :ewar, 0.0),
      support_ratio: role_analysis.support_ratio,
      coordination_quality:
        case tactical_analysis.coordination_indicators do
          %{score: score} -> score
          _ -> 0.0
        end,
      specialized_ships: ship_analysis.specialized_ships.percentage
    })
    |> Map.put(:capital_escalation, %{
      capital_percentage:
        Map.get(ship_analysis.ship_classes, :capital, 0) / ship_analysis.total_ships,
      logistics_percentage: Map.get(role_analysis.role_percentages, :logistics, 0.0),
      interdiction_percentage:
        Map.get(role_analysis.role_percentages, :interdiction, 0.0) +
          Map.get(role_analysis.role_percentages, :heavy_interdiction, 0.0),
      escalation_pattern: tactical_analysis.escalation_pattern.pattern
    })
    |> Map.put(:alpha_strike, %{
      alpha_ships_percentage: calculate_alpha_ship_percentage(ship_analysis),
      coordination_quality:
        case tactical_analysis.coordination_indicators do
          %{score: score} -> score
          _ -> 0.0
        end,
      target_focus: tactical_analysis.target_focus.focus,
      killmail_density: tactical_analysis.killmail_density
    })
    |> Map.put(:nano_gang, %{
      mobility_percentage: calculate_mobility_ship_percentage(ship_analysis),
      frigate_percentage:
        Map.get(ship_analysis.ship_classes, :frigate, 0) / ship_analysis.total_ships,
      engagement_duration: tactical_analysis.engagement_duration,
      multi_system: tactical_analysis.multi_system
    })
    |> Map.put(:logistics_heavy, %{
      logistics_percentage: Map.get(role_analysis.role_percentages, :logistics, 0.0),
      support_ratio: role_analysis.support_ratio,
      engagement_duration: tactical_analysis.engagement_duration,
      survivability_focus: role_analysis.role_balance == :support_heavy
    })
  end

  defp calculate_mobility_ship_percentage(ship_analysis) do
    mobile_classes = [:frigate, :destroyer]

    mobile_count =
      mobile_classes |> Enum.map(&Map.get(ship_analysis.ship_classes, &1, 0)) |> Enum.sum()

    if ship_analysis.total_ships > 0 do
      mobile_count / ship_analysis.total_ships
    else
      0.0
    end
  end

  defp calculate_heavy_ship_percentage(ship_analysis) do
    heavy_classes = [:battlecruiser, :battleship, :capital]

    heavy_count =
      heavy_classes |> Enum.map(&Map.get(ship_analysis.ship_classes, &1, 0)) |> Enum.sum()

    if ship_analysis.total_ships > 0 do
      heavy_count / ship_analysis.total_ships
    else
      0.0
    end
  end

  defp calculate_alpha_ship_percentage(ship_analysis) do
    # Ships commonly used for alpha strikes (simplified)
    alpha_ship_types = [
      # Stealth bombers
      12_032,
      12_036,
      12_040,
      12_044
      # Artillery battleships would need specific type ID checking
    ]

    alpha_count =
      ship_analysis.ship_types
      |> Enum.filter(fn {ship_type, _count} -> ship_type in alpha_ship_types end)
      |> Enum.map(&elem(&1, 1))
      |> Enum.sum()

    if ship_analysis.total_ships > 0 do
      alpha_count / ship_analysis.total_ships
    else
      0.0
    end
  end

  defp generate_engagement_id(engagement) do
    # Generate a unique ID for this engagement
    hash_input =
      "#{engagement.start_time}_#{length(engagement.corp_participants)}_#{List.first(engagement.systems)}"

    :crypto.hash(:md5, hash_input) |> Base.encode16() |> String.slice(0, 8)
  end

  defp classify_combat_doctrines(fleet_compositions) do
    # Classify the primary and secondary doctrines based on fleet compositions
    doctrine_scores =
      @doctrine_patterns
      |> Enum.map(fn {doctrine_key, doctrine_def} ->
        score = calculate_doctrine_score(fleet_compositions, doctrine_key)
        confidence = calculate_doctrine_confidence(fleet_compositions, doctrine_key, score)

        {doctrine_key,
         %{
           name: doctrine_def.name,
           description: doctrine_def.description,
           score: score,
           confidence: confidence,
           supporting_evidence: extract_supporting_evidence(fleet_compositions, doctrine_key)
         }}
      end)
      |> Map.new()

    # Identify primary and secondary doctrines
    sorted_doctrines = Enum.sort_by(doctrine_scores, fn {_key, data} -> data.score end, :desc)

    {primary_key, primary_data} = List.first(sorted_doctrines)
    {secondary_key, secondary_data} = Enum.at(sorted_doctrines, 1, {nil, nil})

    classification = %{
      primary_doctrine: Map.put(primary_data, :key, primary_key),
      secondary_doctrine:
        if(secondary_data, do: Map.put(secondary_data, :key, secondary_key), else: nil),
      all_doctrine_scores: doctrine_scores,
      doctrine_certainty: calculate_doctrine_certainty(doctrine_scores),
      hybrid_characteristics: identify_hybrid_characteristics(doctrine_scores)
    }

    {:ok, classification}
  end

  defp calculate_doctrine_score(fleet_compositions, doctrine_key) do
    if Enum.empty?(fleet_compositions) do
      0.0
    else
      # Calculate average doctrine score across all fleet engagements
      total_score =
        fleet_compositions
        |> Enum.map(fn composition ->
          calculate_single_engagement_doctrine_score(composition, doctrine_key)
        end)
        |> Enum.sum()

      total_score / length(fleet_compositions)
    end
  end

  defp calculate_single_engagement_doctrine_score(composition, doctrine_key) do
    indicators = composition.doctrine_indicators[doctrine_key]

    case doctrine_key do
      :shield_kiting ->
        # Short engagement bonus
        indicators.shield_percentage * 0.3 +
          indicators.long_range_percentage * 0.3 +
          indicators.mobility_ships * 0.2 +
          if indicators.engagement_duration < 300, do: 0.2, else: 0.0

      :armor_brawling ->
        indicators.armor_percentage * 0.3 +
          indicators.short_range_percentage * 0.3 +
          indicators.heavy_ships_percentage * 0.2 +
          if indicators.close_engagement, do: 0.2, else: 0.0

      :ewar_heavy ->
        indicators.ewar_percentage * 0.4 +
          min(1.0, indicators.support_ratio * 2) * 0.3 +
          indicators.coordination_quality * 0.2 +
          indicators.specialized_ships * 0.1

      :capital_escalation ->
        indicators.capital_percentage * 0.4 +
          indicators.logistics_percentage * 0.2 +
          indicators.interdiction_percentage * 0.2 +
          if indicators.escalation_pattern in [:moderate_escalation, :strong_escalation],
            do: 0.2,
            else: 0.0

      :alpha_strike ->
        # High kill rate
        indicators.alpha_ships_percentage * 0.4 +
          indicators.coordination_quality * 0.3 +
          if(indicators.target_focus in [:highly_focused, :moderately_focused],
            do: 0.2,
            else: 0.0
          ) +
          min(1.0, indicators.killmail_density / 2) * 0.1

      :nano_gang ->
        # Short engagement
        indicators.mobility_percentage * 0.4 +
          indicators.frigate_percentage * 0.3 +
          if(indicators.engagement_duration < 180, do: 0.2, else: 0.0) +
          if indicators.multi_system, do: 0.1, else: 0.0

      :logistics_heavy ->
        # Scale up logistics percentage
        # Long engagement
        min(1.0, indicators.logistics_percentage * 4) * 0.4 +
          min(1.0, indicators.support_ratio * 2) * 0.3 +
          if(indicators.engagement_duration > 600, do: 0.2, else: 0.0) +
          if indicators.survivability_focus, do: 0.1, else: 0.0

      _ ->
        0.0
    end
  end

  defp calculate_doctrine_confidence(fleet_compositions, doctrine_key, score) do
    # Calculate confidence based on consistency across engagements and data quality
    if length(fleet_compositions) < 3 do
      # Lower confidence with limited data
      max(0.3, score * 0.7)
    else
      engagement_scores =
        Enum.map(
          fleet_compositions,
          &calculate_single_engagement_doctrine_score(&1, doctrine_key)
        )

      variance = calculate_variance(engagement_scores)
      consistency = 1.0 - min(1.0, variance / max(0.01, score * score))

      # Combine score strength with consistency
      score * 0.7 + consistency * 0.3
    end
  end

  defp extract_supporting_evidence(fleet_compositions, doctrine_key) do
    # Extract specific examples that support this doctrine classification
    strongest_examples =
      fleet_compositions
      |> Enum.map(fn composition ->
        score = calculate_single_engagement_doctrine_score(composition, doctrine_key)
        {composition, score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.take(3)
      |> Enum.map(&elem(&1, 0))

    evidence =
      Enum.map(strongest_examples, fn composition ->
        %{
          engagement_id: composition.engagement_id,
          timestamp: composition.timestamp,
          participant_count: composition.participant_count,
          key_characteristics: extract_key_characteristics(composition, doctrine_key)
        }
      end)

    evidence
  end

  defp extract_key_characteristics(composition, doctrine_key) do
    indicators = composition.doctrine_indicators[doctrine_key]

    case doctrine_key do
      :shield_kiting ->
        [
          "#{round(indicators.shield_percentage * 100)}% shield tanked ships",
          "#{round(indicators.long_range_percentage * 100)}% long-range weapons",
          "#{round(indicators.mobility_ships * 100)}% mobile ships"
        ]

      :armor_brawling ->
        [
          "#{round(indicators.armor_percentage * 100)}% armor tanked ships",
          "#{round(indicators.short_range_percentage * 100)}% short-range weapons",
          "#{round(indicators.heavy_ships_percentage * 100)}% heavy ships"
        ]

      :ewar_heavy ->
        [
          "#{round(indicators.ewar_percentage * 100)}% EWAR ships",
          "#{round(indicators.support_ratio * 100)}% support ships overall",
          "#{round(indicators.coordination_quality * 100)}% coordination quality"
        ]

      _ ->
        ["Analysis available for #{doctrine_key}"]
    end
  end

  defp calculate_doctrine_certainty(doctrine_scores) do
    scores = Map.values(doctrine_scores) |> Enum.map(& &1.score)

    if length(scores) < 2 do
      0.5
    else
      sorted_scores = Enum.sort(scores, :desc)
      top_score = List.first(sorted_scores)
      second_score = Enum.at(sorted_scores, 1)

      # Certainty based on separation between top scores
      separation = top_score - second_score
      min(1.0, separation * 2)
    end
  end

  defp identify_hybrid_characteristics(doctrine_scores) do
    # Identify if corporation uses hybrid doctrines
    high_scoring_doctrines =
      doctrine_scores
      |> Enum.filter(fn {_key, data} -> data.score > 0.5 end)
      |> Enum.map(&elem(&1, 0))

    case length(high_scoring_doctrines) do
      0 -> [:no_clear_doctrine]
      1 -> [:pure_doctrine]
      2 -> [:hybrid_doctrine] ++ high_scoring_doctrines
      _ -> [:complex_hybrid] ++ Enum.take(high_scoring_doctrines, 3)
    end
  end

  # Placeholder implementations for remaining functions

  defp analyze_tactical_patterns(combat_data) do
    # Analyze actual tactical patterns from combat data
    # Extract killmails to analyze as engagements
    killmails = Map.get(combat_data, :killmails, [])

    # Create a simplified engagement structure for coordination analysis
    sample_engagement =
      if length(killmails) > 0 do
        first_killmail = List.first(killmails)

        %{
          corp_participants:
            extract_corp_participants(first_killmail, combat_data.corporation_id),
          killmail: first_killmail
        }
      else
        %{corp_participants: []}
      end

    patterns = %{
      engagement_preferences: analyze_engagement_preferences(combat_data),
      formation_analysis: analyze_formation_patterns(combat_data),
      coordination_quality: analyze_coordination_quality(sample_engagement)
    }

    {:ok, patterns}
  end

  defp extract_corp_participants(killmail, corporation_id) do
    # Extract participants from the killmail that belong to the corporation
    attackers = Map.get(killmail, :attackers, [])

    corp_attackers =
      attackers
      |> Enum.filter(&(&1.corporation_id == corporation_id))
      |> Enum.map(&Map.put(&1, :role, :attacker))

    victim = Map.get(killmail, :victim, %{})

    corp_victims =
      if Map.get(victim, :corporation_id) == corporation_id do
        [Map.put(victim, :role, :victim)]
      else
        []
      end

    corp_attackers ++ corp_victims
  end

  defp analyze_engagement_preferences(combat_data) do
    # Analyze engagement ranges and tactics from killmails
    killmails = Map.get(combat_data, :killmails, [])

    if Enum.empty?(killmails) do
      %{pattern: :insufficient_data}
    else
      # Analyze engagement patterns from killmail data
      range_preferences =
        killmails
        # Analyze up to 100 recent killmails
        |> Enum.take(100)
        |> Enum.map(&determine_engagement_range_from_killmail/1)
        |> Enum.frequencies()

      primary_range =
        range_preferences
        |> Enum.max_by(fn {_range, count} -> count end, fn -> {:unknown, 0} end)
        |> elem(0)

      %{
        pattern: primary_range,
        distribution: range_preferences,
        consistency: calculate_preference_consistency(range_preferences)
      }
    end
  end

  defp analyze_formation_patterns(combat_data) do
    # Analyze fleet formation patterns from active members
    active_members = Map.get(combat_data, :active_members, [])
    killmails = Map.get(combat_data, :killmails, [])

    if Enum.empty?(killmails) do
      %{
        pattern: :unknown,
        types_observed: [],
        frequency: %{}
      }
    else
      # Group killmails by time windows to identify fleet compositions
      fleet_compositions =
        killmails
        # Analyze recent engagements
        |> Enum.take(50)
        # 5-minute windows
        |> Enum.chunk_by(&div(DateTime.to_unix(&1.killmail_time), 300))
        # Only consider groups with 3+ kills
        |> Enum.filter(&(length(&1) >= 3))
        |> Enum.map(&extract_fleet_composition/1)

      formations =
        fleet_compositions
        |> Enum.map(&identify_formation_type/1)
        |> Enum.frequencies()

      %{
        pattern: formations |> Map.keys() |> List.first() || :unknown,
        types_observed: Map.keys(formations),
        frequency: formations
      }
    end
  end

  defp determine_engagement_range_from_killmail(killmail) do
    # Determine engagement range based on weapon types used
    attackers = Map.get(killmail, :attackers, [])

    weapon_types =
      attackers
      |> Enum.map(&Map.get(&1, :weapon_type_id))
      |> Enum.filter(& &1)

    cond do
      Enum.any?(weapon_types, &long_range_weapon?/1) -> :long_range
      Enum.any?(weapon_types, &short_range_weapon?/1) -> :brawling
      true -> :medium_range
    end
  end

  defp long_range_weapon?(weapon_type_id) do
    # Check if weapon is typically long-range (artillery, railguns, etc)
    # This would ideally check against static data
    # Example IDs for long-range weapons
    weapon_type_id in [3520, 3519, 2961, 2969]
  end

  defp short_range_weapon?(weapon_type_id) do
    # Check if weapon is typically short-range (blasters, autocannons, etc)
    # Example IDs for short-range weapons
    weapon_type_id in [2456, 2457, 2881, 2929]
  end

  defp extract_fleet_composition(killmails) do
    # Extract ship types from a group of related killmails
    killmails
    |> Enum.flat_map(fn km ->
      victim_ship = [Map.get(km.victim, :ship_type_id)]

      attacker_ships =
        km.attackers
        |> Enum.map(&Map.get(&1, :ship_type_id))
        |> Enum.filter(& &1)

      victim_ship ++ attacker_ships
    end)
    |> Enum.uniq()
  end

  # Removed duplicate function - using determine_engagement_range_from_killmail instead

  defp identify_formation_type(_fleet_comp) do
    # Identify formation based on ship role distribution
    :standard_fleet
  end

  defp calculate_preference_consistency(preferences) do
    total = Enum.sum(Map.values(preferences))
    if total == 0, do: 0.0, else: Map.values(preferences) |> Enum.max() |> Kernel./(total)
  end

  # Note: Removed unused functions calculate_fleet_coordination_score and analyze_coordination_factors
  # These were placeholder implementations that are no longer needed

  defp maybe_analyze_members(_combat_data, false), do: {:ok, nil}

  defp maybe_analyze_members(combat_data, true) do
    active_members = combat_data.active_members || []

    member_analysis = %{
      active_members: length(active_members),
      top_contributors: identify_top_contributors(active_members),
      role_specialists: identify_role_specialists(active_members),
      participation_metrics: calculate_participation_metrics(active_members)
    }

    {:ok, member_analysis}
  end

  defp identify_top_contributors(members) do
    members
    |> Enum.sort_by(&(&1[:total_damage] || 0), :desc)
    |> Enum.take(5)
    |> Enum.map(fn member ->
      %{
        character_id: member[:character_id],
        contribution_score: member[:total_damage] || 0,
        participation_count: member[:participation_count] || 0
      }
    end)
  end

  defp identify_role_specialists(members) do
    # Group members by their primary ship roles
    role_groups =
      members
      |> Enum.group_by(&determine_primary_role/1)
      |> Map.new(fn {role, role_members} ->
        {role,
         %{
           count: length(role_members),
           specialists: Enum.take(role_members, 3)
         }}
      end)

    role_groups
  end

  defp determine_primary_role(member) do
    # Determine role based on ship types used
    # Simplified implementation
    ship_types = member[:ship_types] || []

    cond do
      Enum.any?(ship_types, &logistics_ship?/1) -> :logistics
      Enum.any?(ship_types, &ewar_ship?/1) -> :ewar
      Enum.any?(ship_types, &tackle_ship?/1) -> :tackle
      true -> :dps
    end
  end

  # Check if ship is a logistics ship using real EVE static data
  defp logistics_ship?(ship_type_id) do
    alias EveDmv.Eve.ItemType

    case Api.get(ItemType, ship_type_id) do
      {:ok, ship} ->
        # Check if it's a logistics ship by group name
        # Check specific ship type IDs for known logistics ships
        String.contains?(String.downcase(ship.group_name || ""), "logistics") ||
          ship_type_id in [
            # T2 Logistics Cruisers: Guardian, Oneiros, Basilisk
            11_985,
            11_987,
            11_989,
            # Scimitar
            11_978,
            # T1 Logistics Frigates: Inquisitor, Bantam
            32_790,
            32_788,
            # T1 Logistics Frigates: Scalpel, Burst
            37_460,
            37_458,
            # T2 Logistics Frigates: Deacon, Kirin
            11_993,
            11_995,
            # T2 Logistics Frigates: Thalia, Scalpel
            12_013,
            12_017
          ]

      _ ->
        false
    end
  end

  # Check if ship is an EWAR ship using real EVE static data
  defp ewar_ship?(ship_type_id) do
    alias EveDmv.Eve.ItemType

    case Api.get(ItemType, ship_type_id) do
      {:ok, ship} ->
        group_name = String.downcase(ship.group_name || "")
        # Check for electronic attack ships and recon ships
        # Check specific ship type IDs for known EWAR ships
        String.contains?(group_name, "electronic attack") ||
          String.contains?(group_name, "combat recon") ||
          String.contains?(group_name, "force recon") ||
          ship_type_id in [
            # Combat Recons: Huginn, Rapier, Arazu, Lachesis
            11_959,
            11_961,
            11_963,
            11_965,
            # Force Recons: Falcon, Rook, Pilgrim, Curse
            11_969,
            11_971,
            11_957,
            11_995,
            # Electronic Attack Frigates: Sentinel, Keres, Kitsune, Griffin Navy
            11_174,
            11_176,
            11_178,
            11_182,
            # T1 EWAR Frigates: Vigil, Crucifier, Griffin, Maulus
            583,
            584,
            585,
            586,
            # T1 EWAR Cruisers: Blackbird, Celestis, Arbitrator, Bellicose
            3766,
            632,
            633,
            634
          ]

      _ ->
        false
    end
  end

  # Check if ship is a tackle ship using real EVE static data
  defp tackle_ship?(ship_type_id) do
    alias EveDmv.Eve.ItemType

    case Api.get(ItemType, ship_type_id) do
      {:ok, ship} ->
        group_name = String.downcase(ship.group_name || "")
        # Check for interceptors and interdictors
        # Check specific ship type IDs for known tackle ships
        String.contains?(group_name, "interceptor") ||
          String.contains?(group_name, "interdictor") ||
          ship_type_id in [
            # Interceptors
            # T2 Interceptors: Crow, Raptor, Ares, Taranis
            11_379,
            11_381,
            11_383,
            11_365,
            # T2 Interceptors: Stiletto, Claw, Crusader, Malediction
            11_393,
            11_377,
            11_373,
            11_375,
            # Interdictors
            # Interdictors: Sabre, Eris, Heretic, Flycatcher
            22_456,
            22_452,
            22_460,
            22_464,
            # Heavy Interdictors
            # Heavy Interdictors: Onyx, Broadsword, Phobos, Devoter
            11_995,
            11_957,
            11_959,
            11_961,
            # Fast tackle frigates
            # T1 Fast Frigates: Breacher, Merlin, Atron, Executioner
            598,
            601,
            602,
            603,
            # T1 Fast Frigates: Rifter, Incursus, Condor, Slasher
            605,
            607,
            608,
            609
          ]

      _ ->
        false
    end
  end

  # Classify ship role using real EVE static data
  defp classify_ship_role(ship_type_id) do
    alias EveDmv.Eve.ItemType

    case Api.get(ItemType, ship_type_id) do
      {:ok, ship} ->
        group_name = String.downcase(ship.group_name || "")

        cond do
          # Capitals
          String.contains?(group_name, "carrier") ||
            String.contains?(group_name, "dreadnought") ||
            String.contains?(group_name, "titan") ||
              String.contains?(group_name, "supercarrier") ->
            :capital

          # Logistics
          String.contains?(group_name, "logistics") ->
            :logistics

          # EWAR
          String.contains?(group_name, "electronic attack") ||
            String.contains?(group_name, "combat recon") ||
              String.contains?(group_name, "force recon") ->
            :ewar

          # Tackle
          String.contains?(group_name, "interceptor") ||
              String.contains?(group_name, "interdictor") ->
            :tackle

          # Ship sizes
          String.contains?(group_name, "frigate") ->
            :frigate

          String.contains?(group_name, "destroyer") ->
            :destroyer

          String.contains?(group_name, "cruiser") ->
            :cruiser

          String.contains?(group_name, "battlecruiser") ->
            :battlecruiser

          String.contains?(group_name, "battleship") ->
            :battleship

          # Default to DPS role if can't classify
          true ->
            :dps
        end

      _ ->
        :unknown
    end
  end

  defp calculate_participation_metrics(members) do
    total_members = length(members)

    if total_members == 0 do
      %{average_participation: 0, participation_variance: 0}
    else
      participations = Enum.map(members, &(&1[:participation_count] || 0))
      avg = Enum.sum(participations) / total_members

      variance =
        if total_members > 1 do
          participations
          |> Enum.map(fn p -> :math.pow(p - avg, 2) end)
          |> Enum.sum()
          |> Kernel./(total_members - 1)
        else
          0
        end

      %{
        average_participation: Float.round(avg, 1),
        participation_variance: Float.round(variance, 1),
        total_engagements: Enum.sum(participations)
      }
    end
  end

  defp maybe_track_evolution(_corporation_id, false), do: {:ok, nil}

  defp maybe_track_evolution(corporation_id, true) do
    # Track doctrine evolution over time
    evolution_analysis = analyze_doctrine_evolution(corporation_id)

    {:ok, evolution_analysis}
  end

  defp analyze_doctrine_evolution(corporation_id) do
    # Analyze how doctrines have changed over time using real killmail data
    alias EveDmv.Core.Utils.DateTimeUtils
    alias EveDmv.Killmails.KillmailRaw
    import Ash.Query

    # Get killmails for the past 60 days grouped by week
    end_date = DateTime.utc_now()
    start_date = DateTimeUtils.add(end_date, -60 * 86_400, :second)

    # Query killmails for this corporation
    query =
      KillmailRaw
      |> filter(
        victim_corporation_id == ^corporation_id or
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS attacker WHERE attacker->>'corporation_id' = ?::text)",
            attackers,
            ^to_string(corporation_id)
          )
      )
      |> filter(killmail_time >= ^start_date and killmail_time <= ^end_date)
      |> select([:killmail_id, :killmail_time, :victim_ship_type_id, :attackers])

    case Api.read(query) do
      {:ok, killmails} ->
        # Group killmails by week
        weekly_groups = group_killmails_by_week(killmails, start_date)

        # Analyze doctrine patterns for each week
        weekly_doctrines =
          Enum.map(weekly_groups, fn {week_start, kms} ->
            ship_types = extract_corporation_ship_types(kms, corporation_id)
            doctrine = identify_doctrine_from_ships(ship_types)
            {week_start, doctrine}
          end)

        # Detect changes between weeks
        changes = detect_doctrine_changes(weekly_doctrines)

        # Calculate adaptation rate (changes per week)
        adaptation_rate =
          if length(weekly_doctrines) > 1 do
            Float.round(length(changes) / length(weekly_doctrines), 2)
          else
            0.0
          end

        %{
          corporation_id: corporation_id,
          evolution_tracking: %{
            trend: determine_trend(changes, adaptation_rate),
            changes_detected: changes,
            adaptation_rate: adaptation_rate,
            analysis_period: "Last 60 days"
          },
          historical_doctrines: weekly_doctrines |> Enum.map(&elem(&1, 1)),
          transition_patterns: analyze_transition_patterns(changes)
        }

      {:error, _} ->
        # Return minimal structure if no data available
        %{
          corporation_id: corporation_id,
          evolution_tracking: %{
            trend: :insufficient_data,
            changes_detected: [],
            adaptation_rate: 0.0,
            analysis_period: "Last 60 days"
          },
          historical_doctrines: [],
          transition_patterns: %{}
        }
    end
  end

  defp group_killmails_by_week(killmails, start_date) do
    killmails
    |> Enum.group_by(fn km ->
      days_diff = DateTime.diff(km.killmail_time, start_date, :second) / 86_400
      week_num = div(trunc(days_diff), 7)
      DateTimeUtils.add(start_date, week_num * 7 * 86_400, :second)
    end)
  end

  defp extract_corporation_ship_types(killmails, corporation_id) do
    killmails
    |> Enum.flat_map(fn km ->
      # Get victim ship if from corporation
      victim_ships =
        if km.victim_corporation_id == corporation_id do
          [km.victim_ship_type_id]
        else
          []
        end

      # Get attacker ships from corporation
      attacker_ships =
        (km.attackers || [])
        |> Enum.filter(fn att ->
          att["corporation_id"] == corporation_id
        end)
        |> Enum.map(fn att -> att["ship_type_id"] end)
        |> Enum.reject(&is_nil/1)

      victim_ships ++ attacker_ships
    end)
    |> Enum.frequencies()
  end

  defp identify_doctrine_from_ships(ship_type_frequencies) do
    # Analyze ship composition to identify doctrine
    total_ships = Enum.sum(Map.values(ship_type_frequencies))

    if total_ships == 0 do
      :no_activity
    else
      # Get ship classifications for the types
      ship_classifications =
        ship_type_frequencies
        |> Map.keys()
        |> Enum.map(fn type_id ->
          {type_id, classify_ship_role(type_id)}
        end)
        |> Map.new()

      # Count role distributions
      role_counts =
        ship_type_frequencies
        |> Enum.map(fn {type_id, count} ->
          {Map.get(ship_classifications, type_id, :unknown), count}
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {role, counts} -> {role, Enum.sum(counts)} end)

      # Determine doctrine based on role distribution
      determine_doctrine_from_roles(role_counts, total_ships)
    end
  end

  defp determine_doctrine_from_roles(role_counts, total_ships) do
    logi_ratio = Map.get(role_counts, :logistics, 0) / total_ships
    ewar_ratio = Map.get(role_counts, :ewar, 0) / total_ships
    capital_ratio = Map.get(role_counts, :capital, 0) / total_ships
    frigate_ratio = Map.get(role_counts, :frigate, 0) / total_ships

    cond do
      capital_ratio > 0.2 -> :capital_escalation
      logi_ratio > 0.15 -> :logistics_heavy
      ewar_ratio > 0.2 -> :ewar_heavy
      frigate_ratio > 0.5 -> :nano_gang
      Map.get(role_counts, :battleship, 0) / total_ships > 0.3 -> :alpha_strike
      Map.get(role_counts, :cruiser, 0) / total_ships > 0.4 -> :armor_brawling
      true -> :mixed_doctrine
    end
  end

  defp detect_doctrine_changes(weekly_doctrines) do
    weekly_doctrines
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.filter(fn {[{_, d1}, {_, d2}], _} -> d1 != d2 end)
    |> Enum.map(fn {[{week1, d1}, {_, d2}], _idx} ->
      %{
        week: week1,
        from: d1,
        to: d2
      }
    end)
  end

  defp determine_trend(changes, adaptation_rate) do
    cond do
      Enum.empty?(changes) -> :stable
      adaptation_rate > 0.5 -> :rapidly_evolving
      adaptation_rate > 0.25 -> :evolving
      adaptation_rate > 0.1 -> :shifting
      true -> :stable
    end
  end

  defp analyze_transition_patterns(changes) do
    changes
    |> Enum.map(fn %{from: from, to: to} -> {from, to} end)
    |> Enum.frequencies()
    |> Map.new(fn {{from, to}, count} ->
      {"#{from}_to_#{to}", count}
    end)
  end

  defp compile_doctrine_analysis(
         corporation_id,
         doctrine_classification,
         tactical_patterns,
         member_analysis,
         evolution_analysis,
         fleet_compositions
       ) do
    analysis = %{
      corporation_id: corporation_id,
      primary_doctrine: doctrine_classification.primary_doctrine,
      secondary_doctrine: doctrine_classification.secondary_doctrine,
      doctrine_certainty: doctrine_classification.doctrine_certainty,
      tactical_patterns: tactical_patterns,
      fleet_compositions_analyzed: length(fleet_compositions),
      member_analysis: member_analysis,
      evolution_analysis: evolution_analysis,
      threat_assessment: generate_doctrine_threat_assessment(doctrine_classification),
      analysis_metadata: %{
        analysis_timestamp: DateTime.utc_now(),
        fleet_engagements: length(fleet_compositions),
        confidence_level: doctrine_classification.doctrine_certainty
      }
    }

    {:ok, analysis}
  end

  defp generate_doctrine_threat_assessment(doctrine_classification) do
    primary = doctrine_classification.primary_doctrine

    threat_level =
      case primary.key do
        :capital_escalation -> :very_high
        :ewar_heavy -> :high
        :alpha_strike -> :high
        :armor_brawling -> :moderate
        :shield_kiting -> :moderate
        :nano_gang -> :moderate
        :logistics_heavy -> :low
        _ -> :unknown
      end

    %{
      threat_level: threat_level,
      primary_strengths: get_doctrine_strengths(primary.key),
      primary_weaknesses: get_doctrine_weaknesses(primary.key),
      recommended_counters: get_recommended_counters(primary.key)
    }
  end

  defp get_doctrine_strengths(doctrine_key) do
    case doctrine_key do
      :shield_kiting -> ["Range control", "High mobility", "Disengagement capability"]
      :armor_brawling -> ["High sustained DPS", "Strong tank", "Close combat effectiveness"]
      :ewar_heavy -> ["Force multiplication", "Disruption capability", "Support coordination"]
      :capital_escalation -> ["Overwhelming firepower", "Area denial", "Strategic presence"]
      :alpha_strike -> ["Burst damage", "Target elimination", "Coordination"]
      :nano_gang -> ["Extreme mobility", "Engagement control", "Hit-and-run tactics"]
      :logistics_heavy -> ["High survivability", "Sustained engagement", "Fleet preservation"]
      _ -> ["Analysis pending"]
    end
  end

  defp get_doctrine_weaknesses(doctrine_key) do
    case doctrine_key do
      :shield_kiting -> ["Vulnerable to tackle", "Lower tank", "Range dependent"]
      :armor_brawling -> ["Low mobility", "Vulnerable to kiting", "Slow to reposition"]
      :ewar_heavy -> ["Lower direct DPS", "Vulnerable to alpha", "Coordination dependent"]
      :capital_escalation -> ["Slow deployment", "High ISK risk", "Escalation dependent"]
      :alpha_strike -> ["Limited sustained DPS", "Coordination required", "Reload vulnerability"]
      :nano_gang -> ["Lower tank", "Skill dependent", "Small fleet limitation"]
      :logistics_heavy -> ["Lower DPS", "Logistics dependence", "Vulnerable to alpha"]
      _ -> ["Analysis pending"]
    end
  end

  defp get_recommended_counters(doctrine_key) do
    case doctrine_key do
      :shield_kiting -> ["Fast tackle", "Missile volleys", "Bubble traps"]
      :armor_brawling -> ["Kiting doctrines", "EWAR heavy", "Range control"]
      :ewar_heavy -> ["Alpha strike", "Fast tackle", "Logistics targeting"]
      :capital_escalation -> ["Counter-escalation", "Dread bombs", "Hit-and-run"]
      :alpha_strike -> ["High tank doctrines", "Logistics heavy", "Dispersed formation"]
      :nano_gang -> ["Interceptor swarms", "Bubble camps", "Area denial"]
      :logistics_heavy -> ["Alpha strike", "Logistics targeting", "EWAR disruption"]
      _ -> ["Analysis pending"]
    end
  end

  # Analyze historical doctrine usage with real killmail data
  defp analyze_historical_doctrine(corporation_id, start_days, end_days) do
    alias EveDmv.Core.Utils.DateTimeUtils
    alias EveDmv.Killmails.KillmailRaw
    import Ash.Query

    # Calculate time period
    now = DateTime.utc_now()
    start_date = DateTimeUtils.add(now, -start_days * 86_400, :second)
    end_date = DateTimeUtils.add(now, -end_days * 86_400, :second)

    # Query killmails for this corporation in the time period
    query =
      KillmailRaw
      |> filter(
        victim_corporation_id == ^corporation_id or
          fragment(
            "EXISTS (SELECT 1 FROM unnest(?) AS attacker WHERE attacker->>'corporation_id' = ?::text)",
            attackers,
            ^to_string(corporation_id)
          )
      )
      |> filter(killmail_time >= ^start_date and killmail_time <= ^end_date)
      |> select([:killmail_id, :killmail_time, :victim_ship_type_id, :attackers, :total_value])

    case Api.read(query) do
      {:ok, killmails} ->
        # Extract ship types used by corporation
        ship_frequencies = extract_corporation_ship_types(killmails, corporation_id)

        # Identify doctrines from ship compositions
        doctrines_observed = analyze_doctrine_frequencies(ship_frequencies)

        # Detect shifts in doctrine usage over time
        # Weekly groups
        time_grouped = group_killmails_by_period(killmails, start_date, 7)
        doctrine_shifts = detect_doctrine_shifts_over_time(time_grouped, corporation_id)

        # Calculate effectiveness trends
        effectiveness_trends = calculate_effectiveness_trends(time_grouped, corporation_id)

        {:ok,
         %{
           corporation_id: corporation_id,
           period: %{
             start: start_date,
             end: end_date
           },
           doctrines_observed: doctrines_observed,
           doctrine_shifts: doctrine_shifts,
           effectiveness_trends: effectiveness_trends
         }}

      {:error, _reason} ->
        # Return structure with no data if query fails
        {:ok,
         %{
           corporation_id: corporation_id,
           period: %{
             start: start_date,
             end: end_date
           },
           doctrines_observed: [],
           doctrine_shifts: [],
           effectiveness_trends: %{
             kill_death_ratio: 0.0,
             isk_efficiency: 0.0,
             trend: :insufficient_data
           }
         }}
    end
  end

  defp analyze_doctrine_frequencies(ship_frequencies) do
    total_ships = Enum.sum(Map.values(ship_frequencies))

    if total_ships == 0 do
      []
    else
      # Group ships by role
      role_groups =
        ship_frequencies
        |> Enum.map(fn {type_id, count} ->
          {classify_ship_role(type_id), count}
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
        |> Map.new(fn {role, counts} -> {role, Enum.sum(counts)} end)

      # Identify primary doctrines based on composition
      doctrines = []

      doctrines =
        if Map.get(role_groups, :logistics, 0) / total_ships > 0.15 do
          [{:logistics_heavy, Map.get(role_groups, :logistics, 0) / total_ships} | doctrines]
        else
          doctrines
        end

      doctrines =
        if Map.get(role_groups, :ewar, 0) / total_ships > 0.2 do
          [{:ewar_heavy, Map.get(role_groups, :ewar, 0) / total_ships} | doctrines]
        else
          doctrines
        end

      doctrines =
        if Map.get(role_groups, :capital, 0) / total_ships > 0.1 do
          [{:capital_escalation, Map.get(role_groups, :capital, 0) / total_ships} | doctrines]
        else
          doctrines
        end

      doctrines =
        if Map.get(role_groups, :frigate, 0) / total_ships > 0.4 do
          [{:nano_gang, Map.get(role_groups, :frigate, 0) / total_ships} | doctrines]
        else
          doctrines
        end

      if Enum.empty?(doctrines) do
        [{:mixed_doctrine, 1.0}]
      else
        Enum.sort_by(doctrines, &elem(&1, 1), :desc)
      end
    end
  end

  defp group_killmails_by_period(killmails, start_date, period_days) do
    killmails
    |> Enum.group_by(fn km ->
      days_diff = DateTime.diff(km.killmail_time, start_date, :second) / 86_400
      period_num = div(trunc(days_diff), period_days)
      DateTimeUtils.add(start_date, period_num * period_days * 86_400, :second)
    end)
  end

  defp detect_doctrine_shifts_over_time(time_grouped, corporation_id) do
    time_grouped
    |> Enum.sort_by(&elem(&1, 0), DateTime)
    |> Enum.map(fn {period_start, kms} ->
      ship_types = extract_corporation_ship_types(kms, corporation_id)
      doctrines = analyze_doctrine_frequencies(ship_types)
      primary_doctrine = if Enum.empty?(doctrines), do: :none, else: elem(hd(doctrines), 0)
      {period_start, primary_doctrine}
    end)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [{_, d1}, {_, d2}] -> d1 != d2 end)
    |> Enum.map(fn [{period, old_doctrine}, {_, new_doctrine}] ->
      %{
        period: period,
        from: old_doctrine,
        to: new_doctrine
      }
    end)
  end

  defp calculate_effectiveness_trends(time_grouped, corporation_id) do
    stats =
      time_grouped
      |> Enum.map(fn {_period, kms} ->
        kills =
          Enum.count(kms, fn km ->
            km.victim_corporation_id != corporation_id
          end)

        losses =
          Enum.count(kms, fn km ->
            km.victim_corporation_id == corporation_id
          end)

        kill_value =
          kms
          |> Enum.filter(fn km -> km.victim_corporation_id != corporation_id end)
          |> Enum.map(& &1.total_value)
          |> Enum.sum()

        loss_value =
          kms
          |> Enum.filter(fn km -> km.victim_corporation_id == corporation_id end)
          |> Enum.map(& &1.total_value)
          |> Enum.sum()

        %{
          kills: kills,
          losses: losses,
          kill_value: kill_value,
          loss_value: loss_value
        }
      end)

    total_kills = Enum.sum(Enum.map(stats, & &1.kills))
    total_losses = Enum.sum(Enum.map(stats, & &1.losses))
    total_kill_value = Enum.sum(Enum.map(stats, & &1.kill_value))
    total_loss_value = Enum.sum(Enum.map(stats, & &1.loss_value))

    kd_ratio =
      if total_losses > 0, do: Float.round(total_kills / total_losses, 2), else: total_kills * 1.0

    isk_efficiency =
      if total_loss_value > 0 do
        Float.round(total_kill_value / (total_kill_value + total_loss_value) * 100, 1)
      else
        if total_kill_value > 0, do: 100.0, else: 0.0
      end

    # Determine trend based on period-over-period changes
    trend =
      if length(stats) >= 2 do
        first_half = Enum.take(stats, div(length(stats), 2))
        second_half = Enum.drop(stats, div(length(stats), 2))

        first_efficiency = calculate_period_efficiency(first_half)
        second_efficiency = calculate_period_efficiency(second_half)

        cond do
          second_efficiency > first_efficiency * 1.1 -> :improving
          second_efficiency < first_efficiency * 0.9 -> :declining
          true -> :stable
        end
      else
        :insufficient_data
      end

    %{
      kill_death_ratio: kd_ratio,
      isk_efficiency: isk_efficiency,
      trend: trend,
      total_engagements: length(time_grouped)
    }
  end

  defp calculate_period_efficiency(stats) do
    total_kill_value = Enum.sum(Enum.map(stats, & &1.kill_value))
    total_loss_value = Enum.sum(Enum.map(stats, & &1.loss_value))

    if total_loss_value > 0 do
      total_kill_value / (total_kill_value + total_loss_value)
    else
      if total_kill_value > 0, do: 1.0, else: 0.0
    end
  end

  defp analyze_doctrine_distribution(doctrine_analyses) do
    # Analyze distribution of doctrines across analyses
    if Enum.empty?(doctrine_analyses) do
      %{distribution: %{}, dominant_doctrine: nil}
    else
      distribution =
        doctrine_analyses
        |> Enum.map(& &1.primary_doctrine.key)
        |> Enum.frequencies()
        |> Map.new(fn {doctrine, count} ->
          {doctrine, Float.round(count / length(doctrine_analyses) * 100, 1)}
        end)

      dominant =
        distribution
        |> Enum.max_by(fn {_doctrine, percentage} -> percentage end, fn -> {nil, 0} end)
        |> elem(0)

      %{
        distribution: distribution,
        dominant_doctrine: dominant,
        diversity_index: calculate_diversity_index(distribution)
      }
    end
  end

  defp calculate_diversity_index(distribution) do
    # Shannon diversity index
    if map_size(distribution) == 0 do
      0.0
    else
      total = Enum.sum(Map.values(distribution))

      distribution
      |> Map.values()
      |> Enum.map(fn count ->
        p = count / total
        if p > 0, do: -p * :math.log(p), else: 0
      end)
      |> Enum.sum()
      |> Float.round(3)
    end
  end

  defp identify_tactical_overlaps(doctrine_analyses) do
    # Identify tactical overlaps between doctrines
    if length(doctrine_analyses) < 2 do
      %{overlaps: [], overlap_count: 0}
    else
      overlaps =
        doctrine_analyses
        |> combinations_of_two()
        |> Enum.map(fn {d1, d2} ->
          %{
            doctrines: [d1.primary_doctrine.key, d2.primary_doctrine.key],
            overlap_score: calculate_doctrine_overlap(d1, d2),
            shared_characteristics: find_shared_characteristics(d1, d2)
          }
        end)
        |> Enum.filter(&(&1.overlap_score > 0.3))

      %{
        overlaps: overlaps,
        overlap_count: length(overlaps),
        max_overlap: overlaps |> Enum.map(& &1.overlap_score) |> Enum.max(fn -> 0 end)
      }
    end
  end

  defp calculate_doctrine_overlap(d1, d2) do
    # Calculate overlap between two doctrines
    # Simplified implementation
    if d1.primary_doctrine.key == d2.primary_doctrine.key do
      1.0
    else
      # Base overlap for different doctrines
      0.2
    end
  end

  defp find_shared_characteristics(d1, d2) do
    # Find shared characteristics between doctrines
    chars1 = d1.primary_doctrine.characteristics || []
    chars2 = d2.primary_doctrine.characteristics || []

    MapSet.intersection(MapSet.new(chars1), MapSet.new(chars2))
    |> MapSet.to_list()
  end

  defp analyze_counter_relationships(doctrine_analyses) do
    # Analyze counter relationships between observed doctrines
    if Enum.empty?(doctrine_analyses) do
      %{counter_relationships: [], vulnerability_matrix: %{}}
    else
      doctrines =
        Enum.map(doctrine_analyses, & &1.primary_doctrine.key)
        |> Enum.uniq()

      relationships =
        for d1 <- doctrines, d2 <- doctrines, d1 != d2 do
          %{
            doctrine: d1,
            counters: d2,
            effectiveness: calculate_counter_effectiveness(d1, d2)
          }
        end

      %{
        counter_relationships: relationships,
        vulnerability_matrix: build_vulnerability_matrix(relationships)
      }
    end
  end

  defp calculate_counter_effectiveness(doctrine1, doctrine2) do
    # Calculate how effectively doctrine2 counters doctrine1 based on actual battle data
    # Since we don't have battle data with doctrine information yet,
    # use theoretical counters based on game mechanics
    calculate_theoretical_counter(doctrine1, doctrine2)
  end

  defp calculate_theoretical_counter(doctrine1, doctrine2) do
    # Theoretical effectiveness based on game mechanics
    # These are based on EVE Online's rock-paper-scissors mechanics

    case {doctrine1, doctrine2} do
      # Shield doctrines are vulnerable to EM/Thermal damage (lasers)
      {:shield_kiting, :armor_brawling} ->
        :medium

      # Alpha can break shield buffer
      {:shield_kiting, :alpha_strike} ->
        :high

      # Armor doctrines are vulnerable to Explosive/Kinetic damage
      # Kiting counters brawling
      {:armor_brawling, :shield_kiting} ->
        :high

      # Speed counters slow armor
      {:armor_brawling, :nano_gang} ->
        :high

      # EWAR is countered by alpha strike (kill before jams land)
      {:ewar_heavy, :alpha_strike} ->
        :high

      # Fast ships harder to jam
      {:ewar_heavy, :nano_gang} ->
        :medium

      # Capitals are countered by mass subcaps or dreads
      {:capital_escalation, :mixed_doctrine} ->
        if doctrine2 == :mixed_doctrine, do: :medium, else: :low

      # Need critical mass
      {:capital_escalation, :alpha_strike} ->
        :medium

      # Nano is countered by good tackle and webs
      # Damps/jams shut down kiters
      {:nano_gang, :ewar_heavy} ->
        :high

      # Can't break logi easily
      {:nano_gang, :logistics_heavy} ->
        :low

      # Logistics is countered by alpha or EWAR
      # Alpha breaks before reps
      {:logistics_heavy, :alpha_strike} ->
        :high

      # Jam out the logi
      {:logistics_heavy, :ewar_heavy} ->
        :high

      # Default cases
      # Mirror matches are even
      {same, same} ->
        :low

      # Unknown matchups default to medium
      _ ->
        :medium
    end
  end

  defp build_vulnerability_matrix(relationships) do
    # Build a matrix of vulnerabilities
    relationships
    |> Enum.group_by(& &1.doctrine)
    |> Map.new(fn {doctrine, rels} ->
      vulnerabilities =
        rels
        |> Enum.filter(&(&1.effectiveness == :high))
        |> Enum.map(& &1.counters)

      {doctrine, vulnerabilities}
    end)
  end

  defp generate_competitive_assessment(doctrine_analyses) do
    # Generate competitive assessment based on doctrine analyses
    if Enum.empty?(doctrine_analyses) do
      %{assessment: :insufficient_data, recommendations: []}
    else
      doctrine_distribution = analyze_doctrine_distribution(doctrine_analyses)
      _tactical_overlaps = identify_tactical_overlaps(doctrine_analyses)
      counter_relationships = analyze_counter_relationships(doctrine_analyses)

      assessment_level =
        cond do
          doctrine_distribution.diversity_index > 2.0 -> :highly_competitive
          doctrine_distribution.diversity_index > 1.5 -> :competitive
          doctrine_distribution.diversity_index > 1.0 -> :moderately_competitive
          true -> :limited_competition
        end

      %{
        assessment: assessment_level,
        diversity_score: doctrine_distribution.diversity_index,
        dominant_strategies: Map.take(doctrine_distribution.distribution, 3),
        key_vulnerabilities: identify_key_vulnerabilities(counter_relationships),
        recommendations:
          generate_tactical_recommendations(assessment_level, doctrine_distribution)
      }
    end
  end

  defp identify_key_vulnerabilities(counter_relationships) do
    counter_relationships.vulnerability_matrix
    |> Enum.map(fn {doctrine, counters} ->
      %{doctrine: doctrine, vulnerable_to: counters}
    end)
    |> Enum.take(3)
  end

  defp generate_tactical_recommendations(assessment_level, _distribution) do
    case assessment_level do
      :highly_competitive ->
        [
          "Maintain doctrine diversity",
          "Focus on counter-intelligence",
          "Develop adaptive tactics"
        ]

      :competitive ->
        ["Expand doctrine repertoire", "Improve coordination", "Study opponent patterns"]

      :moderately_competitive ->
        [
          "Develop specialized doctrines",
          "Increase training frequency",
          "Analyze successful engagements"
        ]

      :limited_competition ->
        ["Establish core doctrines", "Focus on basic coordination", "Build member expertise"]

      _ ->
        ["Gather more combat data", "Establish baseline metrics"]
    end
  end

  defp assess_alliance_synergies(_doctrine_analyses) do
    %{synergies: "Requires implementation"}
  end

  defp identify_doctrine_weaknesses(_target_analysis) do
    ["Weakness analysis requires implementation"]
  end

  defp generate_counter_recommendations(_target_analysis) do
    ["Counter recommendations require implementation"]
  end

  defp generate_tactical_advice(_target_analysis) do
    ["Tactical advice requires implementation"]
  end

  defp suggest_counter_compositions(_target_analysis) do
    ["Composition suggestions require implementation"]
  end

  defp identify_doctrine_changes(_time_periods) do
    ["Change detection requires implementation"]
  end

  defp analyze_adaptation_patterns(_time_periods) do
    %{patterns: "Requires implementation"}
  end

  defp calculate_doctrine_stability(_time_periods) do
    0.5
  end

  defp predict_doctrine_trends(_time_periods) do
    ["Trend prediction requires implementation"]
  end

  # Utility functions

  defp calculate_variance(values) do
    if length(values) <= 1 do
      0.0
    else
      mean_val = Enum.sum(values) / length(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean_val, 2)) |> Enum.sum()
      variance_sum / length(values)
    end
  end

  # Helper function to generate combinations of two elements
  defp combinations_of_two([]), do: []
  defp combinations_of_two([_]), do: []

  defp combinations_of_two([h | t]) do
    Enum.map(t, fn elem -> {h, elem} end) ++ combinations_of_two(t)
  end
end
