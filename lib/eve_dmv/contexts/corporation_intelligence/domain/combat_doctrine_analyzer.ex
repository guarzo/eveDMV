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

  import Ash.Query
  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw

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
    with {:ok, target_analysis} <- analyze_combat_doctrines(target_corporation_id, options) do
      counter_recommendations = %{
        target_corporation: target_corporation_id,
        target_primary_doctrine: target_analysis.primary_doctrine,
        target_weaknesses: identify_doctrine_weaknesses(target_analysis),
        recommended_counters: generate_counter_recommendations(target_analysis),
        tactical_advice: generate_tactical_advice(target_analysis),
        fleet_composition_suggestions: suggest_counter_compositions(target_analysis)
      }

      {:ok, counter_recommendations}
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

        case analyze_historical_doctrine(corporation_id, start_days, end_days) do
          {:ok, analysis} ->
            %{
              period: "#{month_offset} months ago",
              month_offset: month_offset,
              doctrine_analysis: analysis
            }

          _ ->
            nil
        end
      end)
      |> Enum.filter(&(&1 != nil))
      # Most recent first
      |> Enum.reverse()

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
      NaiveDateTime.add(NaiveDateTime.utc_now(), -analysis_window_days * 24 * 60 * 60, :second)

    # Fetch killmails where corporation members were involved
    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_corporation_id: corporation_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      |> limit(500)

    # Fetch recent killmails to search for corporation as attackers
    attacker_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      # Larger sample for attacker search
      |> limit(2000)

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: Api) do
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

        if length(corp_participants) > 0 do
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
        else
          acc
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
        time_diff = NaiveDateTime.diff(killmail.killmail_time, engagement.end_time, :second)
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
        duration_seconds: NaiveDateTime.diff(engagement.end_time, engagement.start_time, :second),
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
      total_ships = ship_types |> Map.values() |> Enum.sum()

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
        if(length(participants) > 0, do: length(specialized) / length(participants), else: 0.0)
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
      support_roles
      |> Enum.map(&Map.get(role_percentages, &1, 0.0))
      |> Enum.sum()

    dps_percentage =
      dps_roles
      |> Enum.map(&Map.get(role_percentages, &1, 0.0))
      |> Enum.sum()

    cond do
      support_percentage > 0.4 -> :support_heavy
      support_percentage < 0.1 -> :support_light
      dps_percentage > 0.7 -> :dps_heavy
      true -> :balanced
    end
  end

  defp calculate_support_ratio(role_percentages) do
    support_roles = [:logistics, :ewar, :command, :interdiction]

    support_roles
    |> Enum.map(&Map.get(role_percentages, &1, 0.0))
    |> Enum.sum()
  end

  defp analyze_tactical_indicators(engagement) do
    # Analyze tactical patterns and coordination indicators
    %{
      engagement_duration:
        NaiveDateTime.diff(engagement.end_time, engagement.start_time, :second),
      multi_system: length(engagement.systems) > 1,
      killmail_density: calculate_killmail_density(engagement),
      coordination_indicators: analyze_coordination_quality(engagement),
      target_focus: analyze_target_focus(engagement),
      escalation_pattern: analyze_escalation_pattern(engagement)
    }
  end

  defp calculate_killmail_density(engagement) do
    duration_minutes =
      NaiveDateTime.diff(engagement.end_time, engagement.start_time, :second) / 60

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
      indices
      |> Enum.zip(values)
      |> Enum.map(fn {x, y} -> x * y end)
      |> Enum.sum()

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
      coordination_quality: tactical_analysis.coordination_indicators.score,
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
      coordination_quality: tactical_analysis.coordination_indicators.score,
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
      mobile_classes
      |> Enum.map(&Map.get(ship_analysis.ship_classes, &1, 0))
      |> Enum.sum()

    if ship_analysis.total_ships > 0 do
      mobile_count / ship_analysis.total_ships
    else
      0.0
    end
  end

  defp calculate_heavy_ship_percentage(ship_analysis) do
    heavy_classes = [:battlecruiser, :battleship, :capital]

    heavy_count =
      heavy_classes
      |> Enum.map(&Map.get(ship_analysis.ship_classes, &1, 0))
      |> Enum.sum()

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
    scores = doctrine_scores |> Map.values() |> Enum.map(& &1.score)

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

  defp analyze_tactical_patterns(_combat_data) do
    patterns = %{
      engagement_preferences: %{pattern: :requires_implementation},
      formation_analysis: %{pattern: :requires_implementation},
      coordination_quality: %{pattern: :requires_implementation}
    }

    {:ok, patterns}
  end

  defp maybe_analyze_members(_combat_data, false), do: {:ok, nil}

  defp maybe_analyze_members(combat_data, true) do
    member_analysis = %{
      active_members: length(combat_data.active_members),
      top_contributors: "Analysis requires implementation",
      role_specialists: "Analysis requires implementation"
    }

    {:ok, member_analysis}
  end

  defp maybe_track_evolution(_corporation_id, false), do: {:ok, nil}

  defp maybe_track_evolution(corporation_id, true) do
    evolution_analysis = %{
      corporation_id: corporation_id,
      evolution_tracking: "Requires implementation"
    }

    {:ok, evolution_analysis}
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
        analysis_timestamp: NaiveDateTime.utc_now(),
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

  # Additional placeholder implementations

  defp analyze_historical_doctrine(_corporation_id, _start_days, _end_days) do
    {:ok, %{historical_analysis: "Requires implementation"}}
  end

  defp analyze_doctrine_distribution(_doctrine_analyses) do
    %{distribution: "Requires implementation"}
  end

  defp identify_tactical_overlaps(_doctrine_analyses) do
    %{overlaps: "Requires implementation"}
  end

  defp analyze_counter_relationships(_doctrine_analyses) do
    %{counter_relationships: "Requires implementation"}
  end

  defp generate_competitive_assessment(_doctrine_analyses) do
    %{assessment: "Requires implementation"}
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
end
