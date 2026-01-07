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

  ## Submodules

  This module is organized into the following submodules for maintainability:

  - `CombatDoctrine.FleetAnalyzer` - Fleet composition and engagement analysis
  - `CombatDoctrine.DoctrineClassifier` - Doctrine classification and scoring
  - `CombatDoctrine.ThreatAssessor` - Threat assessment and counter-strategy analysis
  """

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.StaticData.ShipTypes

  require Ash.Query
  require Logger

  # Note: get_doctrine_strengths/1, get_doctrine_weaknesses/1, get_recommended_counters/1
  # are all defined locally in this module with detailed implementations

  # Doctrine analysis parameters
  # Minimum active members for reliable analysis
  @min_members_for_analysis 5
  # Minimum fleet kills to identify doctrine
  @min_fleet_kills_for_doctrine 10
  # Default analysis period for doctrine recognition
  @analysis_window_days 60
  # Engagement time window in seconds (10 minutes)
  @engagement_window_seconds 600

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

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: EveDmv.Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: EveDmv.Api) do
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

        if corp_participants == [] do
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
    corp_participants = extract_corp_participants(killmail, corporation_id)
    participant_ids = Enum.map(corp_participants, & &1.character_id)

    matching =
      Enum.find(engagements, fn engagement ->
        # Check time proximity
        time_diff = DateTimeUtils.diff(killmail.killmail_time, engagement.end_time, :second)
        within_time_window = time_diff <= @engagement_window_seconds and time_diff >= 0

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
    case ShipTypes.classify_ship_type(ship_type_id) do
      :unknown -> :other
      class -> class
    end
  end

  defp analyze_tank_distribution(_participants) do
    # Tank distribution requires actual fitting data from killmails
    # Without access to module fits, return unavailable
    %{
      status: :data_unavailable,
      reason: "Tank analysis requires actual fitting data"
    }
  end

  defp analyze_range_distribution(_participants) do
    # Range distribution requires actual weapon data from killmails
    # Without access to weapon modules, return unavailable
    %{
      status: :data_unavailable,
      reason: "Range analysis requires actual weapon data"
    }
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
        if(participants == [],
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
    # Use actual total_value from killmail if available
    case Map.get(killmail, :total_value) do
      nil -> 0
      value when is_number(value) -> value
      _ -> 0
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
    alias EveDmv.Eve.ItemType

    # Check each ship type to see if it's an alpha-strike ship
    alpha_count =
      ship_analysis.ship_types
      |> Enum.filter(fn {ship_type_id, _count} ->
        case Ash.get(ItemType, ship_type_id, domain: EveDmv.Api) do
          {:ok, item} ->
            group = String.downcase(item.group_name || "")
            # Stealth bombers and artillery ships are alpha-strike capable
            String.contains?(group, "stealth bomber") or
              String.contains?(group, "attack battlecruiser") or
              (String.contains?(group, "battleship") and
                 item.type_name =~ ~r/maelstrom|tempest|rokh|apocalypse|abaddon/i)

          _ ->
            false
        end
      end)
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
    if fleet_compositions == [] do
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
      if killmails != [] do
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

  defp analyze_engagement_preferences(combat_data) do
    # Analyze engagement ranges and tactics from killmails
    killmails =
      combat_data
      |> Map.get(:killmails, [])
      |> Enum.sort_by(&DateTime.to_unix(&1.killmail_time), :desc)

    if killmails == [] do
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
    _active_members = Map.get(combat_data, :active_members, [])
    killmails = Map.get(combat_data, :killmails, [])

    if killmails == [] do
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
        # Group by 5-minute windows
        |> Enum.group_by(&div(DateTime.to_unix(&1.killmail_time), 300))
        |> Map.values()
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
    # Handle both raw_data JSON and materialized attackers
    attackers =
      case killmail do
        %{attackers: list} when is_list(list) -> list
        %{raw_data: %{"attackers" => list}} when is_list(list) -> list
        _ -> []
      end

    weapon_types =
      attackers
      |> Enum.map(fn attacker ->
        # Handle both map string keys and atom keys
        case attacker do
          %{weapon_type_id: id} when not is_nil(id) -> id
          %{"weapon_type_id" => id} when not is_nil(id) -> id
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    cond do
      Enum.any?(weapon_types, &long_range_weapon?/1) -> :long_range
      Enum.any?(weapon_types, &short_range_weapon?/1) -> :brawling
      true -> :medium_range
    end
  end

  defp long_range_weapon?(weapon_type_id) do
    alias EveDmv.Eve.ItemType

    case Ash.get(ItemType, weapon_type_id, domain: EveDmv.Api) do
      {:ok, weapon} ->
        name = String.downcase(weapon.type_name || "")
        group = String.downcase(weapon.group_name || "")

        # Check for long-range weapon types by name patterns
        String.contains?(name, ["artillery", "railgun", "beam laser", "pulse laser"]) or
          String.contains?(group, ["artillery", "railgun", "beam", "pulse"]) or
          String.contains?(name, ["1400mm", "1200mm", "800mm", "720mm", "650mm", "425mm"])

      _ ->
        false
    end
  end

  defp short_range_weapon?(weapon_type_id) do
    alias EveDmv.Eve.ItemType

    case Ash.get(ItemType, weapon_type_id, domain: EveDmv.Api) do
      {:ok, weapon} ->
        name = String.downcase(weapon.type_name || "")
        group = String.downcase(weapon.group_name || "")

        # Check for short-range weapon types by name patterns
        String.contains?(name, ["blaster", "autocannon", "rocket", "torpedo"]) or
          String.contains?(group, ["blaster", "autocannon", "rocket", "torpedo"]) or
          String.contains?(name, ["neutron", "ion", "electron", "200mm", "220mm", "240mm"])

      _ ->
        false
    end
  end

  defp extract_fleet_composition(killmails) do
    # Extract ship types from a group of related killmails
    killmails
    |> Enum.flat_map(fn km ->
      # Use victim_ship_type_id from KillmailRaw
      victim_ship = [km.victim_ship_type_id]

      # Handle both raw_data JSON and materialized attackers
      attacker_ships =
        km
        |> extract_attacker_list()
        |> extract_ship_type_ids()

      (victim_ship ++ attacker_ships) |> Enum.reject(&is_nil/1)
    end)
    |> Enum.uniq()
  end

  defp identify_formation_type(fleet_comp) do
    # Analyze actual fleet composition to identify formation type
    if fleet_comp == [] do
      :unknown
    else
      # Count ship roles in the fleet
      role_counts =
        fleet_comp
        |> Enum.reduce(%{}, fn ship_type_id, acc ->
          role = classify_ship_role(ship_type_id)
          Map.update(acc, role, 1, &(&1 + 1))
        end)

      total_ships = Enum.sum(Map.values(role_counts))

      # Calculate role percentages
      logi_percent = Map.get(role_counts, :logistics, 0) / total_ships
      ewar_percent = Map.get(role_counts, :ewar, 0) / total_ships
      tackle_percent = Map.get(role_counts, :tackle, 0) / total_ships
      capital_percent = Map.get(role_counts, :capital, 0) / total_ships
      dps_percent = Map.get(role_counts, :dps, 0) / total_ships

      # Identify formation based on composition patterns
      cond do
        # Capital heavy formation
        capital_percent > 0.3 ->
          :capital_fleet

        # Balanced fleet with logistics
        logi_percent >= 0.15 && logi_percent <= 0.25 ->
          :mainline_doctrine

        # EWAR heavy composition
        ewar_percent > 0.25 ->
          :ewar_doctrine

        # Fast tackle/roaming gang
        tackle_percent > 0.3 ->
          :roaming_gang

        # Heavy DPS focus
        dps_percent > 0.7 ->
          :dps_doctrine

        # Small gang (less than 10 ships)
        total_ships < 10 ->
          :small_gang

        # Default to mixed doctrine
        true ->
          :mixed_doctrine
      end
    end
  end

  defp calculate_preference_consistency(preferences) do
    total = Enum.sum(Map.values(preferences))
    if total == 0, do: 0.0, else: Map.values(preferences) |> Enum.max() |> Kernel./(total)
  end

  defp extract_attacker_list(km) do
    case km do
      %{attackers: list} when is_list(list) -> list
      %{raw_data: %{"attackers" => list}} when is_list(list) -> list
      _ -> []
    end
  end

  defp extract_ship_type_ids(attackers) do
    attackers
    |> Enum.map(&extract_ship_type_id/1)
    |> Enum.filter(& &1)
  end

  defp extract_ship_type_id(attacker) do
    case attacker do
      %{ship_type_id: id} when not is_nil(id) -> id
      %{"ship_type_id" => id} when not is_nil(id) -> id
      _ -> nil
    end
  end

  defp maybe_analyze_members(_combat_data, false), do: {:ok, nil}

  defp maybe_analyze_members(combat_data, true) do
    active_members = combat_data.active_members || []

    # Calculate participation from killmail data, not from member IDs
    top_contributors = identify_top_contributors(combat_data)

    member_analysis = %{
      active_members: length(active_members),
      top_contributors: top_contributors,
      role_specialists: identify_role_specialists(combat_data),
      participation_metrics: calculate_participation_metrics_from_contributors(top_contributors)
    }

    {:ok, member_analysis}
  end

  defp identify_top_contributors(combat_data) do
    # Analyze actual killmail data to identify top contributors
    corporation_id = combat_data.corporation_id
    killmails = combat_data.killmails || []

    # Count participation and damage for each member
    member_stats =
      killmails
      |> Enum.reduce(%{}, fn km, acc ->
        process_killmail_attackers(km, corporation_id, acc)
      end)

    # Calculate contribution scores and sort
    member_stats
    |> Enum.map(fn {char_id, stats} ->
      # Weighted score: damage + kills * 10000 + final_blows * 5000
      score = stats.damage + stats.kills * 10_000 + stats.final_blows * 5_000

      %{
        character_id: char_id,
        contribution_score: score,
        participation_count: stats.kills,
        total_damage: stats.damage,
        final_blows: stats.final_blows
      }
    end)
    |> Enum.sort_by(& &1.contribution_score, :desc)
    |> Enum.take(5)
  end

  defp identify_role_specialists(combat_data) do
    # Analyze actual ship usage by corporation members
    corporation_id = combat_data.corporation_id
    killmails = combat_data.killmails || []

    # Track ship roles used by each member
    member_roles =
      killmails
      |> Enum.reduce(%{}, fn km, acc ->
        acc
        |> process_victim_role(km, corporation_id)
        |> process_attacker_roles(km, corporation_id)
      end)

    # Group members by their most common role
    role_groups =
      member_roles
      |> Enum.reduce(%{}, fn {char_id, role_counts}, acc ->
        # Find the most used role for this character
        {primary_role, count} = Enum.max_by(role_counts, fn {_role, cnt} -> cnt end)

        Map.update(acc, primary_role, [{char_id, count}], fn specialists ->
          [{char_id, count} | specialists]
        end)
      end)
      |> Enum.map(fn {role, specialists} ->
        # Sort specialists by their usage count and take top 3
        top_specialists =
          specialists
          |> Enum.sort_by(fn {_char_id, count} -> count end, :desc)
          |> Enum.take(3)
          |> Enum.map(fn {char_id, _count} -> char_id end)

        {role,
         %{
           count: length(specialists),
           specialists: top_specialists
         }}
      end)
      |> Map.new()

    # Ensure we have at least basic categories
    %{
      dps: Map.get(role_groups, :dps, %{count: 0, specialists: []}),
      logistics: Map.get(role_groups, :logistics, %{count: 0, specialists: []}),
      ewar: Map.get(role_groups, :ewar, %{count: 0, specialists: []}),
      tackle: Map.get(role_groups, :tackle, %{count: 0, specialists: []}),
      capital: Map.get(role_groups, :capital, %{count: 0, specialists: []})
    }
  end

  defp update_role_count(acc, char_id, role) do
    Map.update(acc, char_id, %{role => 1}, fn role_counts ->
      Map.update(role_counts, role, 1, &(&1 + 1))
    end)
  end

  # Helper function to process attackers from killmail data
  defp process_killmail_attackers(km, corporation_id, acc) do
    case km.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.filter(&(&1["corporation_id"] == corporation_id))
        |> Enum.reduce(acc, fn attacker, acc2 ->
          update_attacker_stats(attacker, acc2)
        end)

      _ ->
        acc
    end
  end

  # Helper function to update stats for an attacker
  defp update_attacker_stats(attacker, acc) do
    char_id = attacker["character_id"]

    if char_id do
      damage = attacker["damage_done"] || 0
      final_blow = if attacker["final_blow"], do: 1, else: 0

      Map.update(acc, char_id, %{kills: 1, damage: damage, final_blows: final_blow}, fn stats ->
        %{
          kills: stats.kills + 1,
          damage: stats.damage + damage,
          final_blows: stats.final_blows + final_blow
        }
      end)
    else
      acc
    end
  end

  # Helper function to process victim role from killmail
  defp process_victim_role(acc, km, corporation_id) do
    if km.victim_corporation_id == corporation_id && km.victim_character_id do
      ship_role = classify_ship_role(km.victim_ship_type_id)
      update_role_count(acc, km.victim_character_id, ship_role)
    else
      acc
    end
  end

  # Helper function to process attacker roles from killmail
  defp process_attacker_roles(acc, km, corporation_id) do
    case km.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.filter(&(&1["corporation_id"] == corporation_id))
        |> Enum.reduce(acc, fn attacker, acc2 ->
          process_single_attacker_role(attacker, acc2)
        end)

      _ ->
        acc
    end
  end

  # Helper to process a single attacker's role
  defp process_single_attacker_role(attacker, acc) do
    char_id = attacker["character_id"]
    ship_type_id = attacker["ship_type_id"]

    if char_id && ship_type_id do
      ship_role = classify_ship_role(ship_type_id)
      update_role_count(acc, char_id, ship_role)
    else
      acc
    end
  end

  # Classify ship role using real EVE static data
  defp classify_ship_role(ship_type_id) do
    alias EveDmv.Eve.ItemType

    case Ash.get(ItemType, ship_type_id, domain: EveDmv.Api) do
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

  # Calculate participation metrics from contributor data (maps with :participation_count)
  defp calculate_participation_metrics_from_contributors(contributors) do
    # Filter out nil and non-map values
    valid_contributors =
      contributors
      |> List.wrap()
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&is_map/1)

    total_contributors = length(valid_contributors)

    if total_contributors == 0 do
      %{average_participation: 0, participation_variance: 0, total_engagements: 0}
    else
      participations =
        Enum.map(valid_contributors, fn contributor ->
          contributor[:participation_count] || contributor["participation_count"] || 0
        end)

      avg = Enum.sum(participations) / total_contributors

      variance =
        if total_contributors > 1 do
          participations
          |> Enum.map(fn p -> :math.pow(p - avg, 2) end)
          |> Enum.sum()
          |> Kernel./(total_contributors - 1)
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

    case Ash.read(query, domain: EveDmv.Api) do
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
      changes == [] -> :stable
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
    # First get victim killmails
    victim_query =
      KillmailRaw
      |> filter(victim_corporation_id == ^corporation_id)
      |> filter(killmail_time >= ^start_date and killmail_time <= ^end_date)
      |> limit(500)

    # Then get a broader set for attacker search
    attacker_query =
      KillmailRaw
      |> filter(killmail_time >= ^start_date and killmail_time <= ^end_date)
      |> limit(2000)

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: EveDmv.Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: EveDmv.Api) do
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

      killmails = Enum.uniq_by(victim_killmails ++ attacker_killmails, & &1.killmail_id)

      if killmails == [] do
        {:ok,
         %{
           period_start: start_date,
           period_end: end_date,
           doctrine_breakdown: %{},
           ship_preferences: %{},
           tactical_patterns: [],
           fleet_sizes: [],
           primary_doctrine: %{name: "Unknown", confidence: 0.0}
         }}
      else
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
      end
    else
      {:error, reason} ->
        # Return error tuple with the actual failure reason
        {:error, reason}
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

      if doctrines == [] do
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
    |> Enum.sort_by(fn {period_start, _} -> DateTime.to_unix(period_start) end)
    |> Enum.map(fn {period_start, kms} ->
      ship_types = extract_corporation_ship_types(kms, corporation_id)
      doctrines = analyze_doctrine_frequencies(ship_types)
      primary_doctrine = if doctrines == [], do: :none, else: elem(hd(doctrines), 0)
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
    if doctrine_analyses == [] do
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
    if doctrine_analyses == [] do
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
    if doctrine_analyses == [] do
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
        dominant_strategies:
          doctrine_distribution.distribution
          |> Enum.sort_by(&elem(&1, 1), :desc)
          |> Enum.take(3)
          |> Map.new(),
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
    {:error, :not_implemented}
  end

  defp identify_doctrine_weaknesses(_target_analysis) do
    {:error, :not_implemented}
  end

  defp generate_counter_recommendations(_target_analysis) do
    {:error, :not_implemented}
  end

  defp generate_tactical_advice(_target_analysis) do
    {:error, :not_implemented}
  end

  defp suggest_counter_compositions(_target_analysis) do
    {:error, :not_implemented}
  end

  defp identify_doctrine_changes(_time_periods) do
    {:error, :not_implemented}
  end

  defp analyze_adaptation_patterns(_time_periods) do
    {:error, :not_implemented}
  end

  defp calculate_doctrine_stability(_time_periods) do
    {:error, :not_implemented}
  end

  defp predict_doctrine_trends(_time_periods) do
    {:error, :not_implemented}
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
