defmodule EveDmv.Integrations.ShipIntelligenceBridge do
  import Ecto.Query
  alias EveDmv.Analytics.ModuleClassifier
  alias EveDmv.Analytics.FleetAnalyzer
  alias EveDmv.Repo
  require Logger

  @moduledoc """
  Bridge module that integrates the new ship intelligence features with existing systems.

  This module connects:
  - Ship role classification from ModuleClassifier with battle analysis
  - Fleet composition analysis from FleetAnalyzer with fleet operations
  - Ship performance data with character intelligence
  - Doctrine analysis with surveillance profiles

  Acts as the central integration point for ship intelligence across the application.
  """

  ## Battle Analysis Integration
  @doc """
  Enhanced ship role analysis for battle performance evaluation.
  Takes killmail data and provides enhanced role classification using our
  advanced ModuleClassifier, supplementing the existing estimated fitting approach.
  """
  def analyze_ship_roles_in_battle(battle_data) do
    Logger.debug("Analyzing ship roles in battle using enhanced ship intelligence")

    try do
      # Extract killmail data from battle
      killmails = extract_killmails_from_battle(battle_data)
      # Analyze each ship's role using our ModuleClassifier
      enhanced_roles =
        killmails
        |> Enum.map(&classify_ship_role_from_killmail/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, result} -> result end)

      # Get fleet composition analysis
      ship_types = Enum.map(killmails, &extract_ship_type_id/1) |> Enum.filter(& &1)

      fleet_analysis =
        case FleetAnalyzer.analyze_fleet_composition(ship_types) do
          {:ok, analysis} ->
            analysis

          {:error, :fleet_too_small} ->
            %{
              doctrine_classification: %{doctrine: "unknown", confidence: 0.0},
              tactical_assessment: %{},
              recommendations: [],
              fleet_size: length(ship_types)
            }

          {:error, reason} ->
            Logger.warning("Fleet analysis failed: #{inspect(reason)}")

            %{
              doctrine_classification: %{doctrine: "unknown", confidence: 0.0},
              tactical_assessment: %{},
              recommendations: [],
              fleet_size: length(ship_types)
            }
        end

      # Combine individual ship analysis with fleet-level analysis
      %{
        individual_ship_roles: enhanced_roles,
        fleet_composition: fleet_analysis,
        doctrine_analysis: fleet_analysis.doctrine_classification,
        tactical_assessment: fleet_analysis.tactical_assessment,
        recommendations: fleet_analysis.recommendations,
        enhanced_at: DateTime.utc_now()
      }
    rescue
      error ->
        Logger.error("Failed to analyze ship roles in battle: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Enhance existing ship performance data with ship intelligence insights.
  Takes performance data from ShipPerformanceAnalyzer and enriches it with
  role classification confidence, doctrine compliance, and tactical insights.
  """
  def enhance_ship_performance_data(performance_data, battle_context \\ nil) do
    Enum.map(performance_data, fn ship_perf ->
      # Get ship role classification from our system
      ship_type_id = ship_perf.ship_instance.ship_type_id
      enhanced_role = get_ship_role_classification(ship_type_id)
      # Calculate role execution score based on classification confidence
      role_execution_score = calculate_enhanced_role_execution(ship_perf, enhanced_role)
      # Add doctrine compliance assessment
      doctrine_compliance = assess_doctrine_compliance(ship_perf, battle_context)
      # Enhance tactical analysis
      enhanced_tactical = enhance_tactical_analysis(ship_perf, enhanced_role)

      ship_perf
      |> Map.put(:enhanced_role_classification, enhanced_role)
      |> Map.put(:role_execution_score, role_execution_score)
      |> Map.put(:doctrine_compliance, doctrine_compliance)
      |> Map.update(:tactical_analysis, enhanced_tactical, &Map.merge(&1, enhanced_tactical))
    end)
  end

  ## Character Intelligence Integration
  @doc """
  Calculate ship specialization scores for character intelligence.
  Analyzes a character's killmail history to determine ship specialization
  and expertise levels based on performance and usage patterns.
  """
  def calculate_ship_specialization(character_id, options \\ []) do
    days_back = Keyword.get(options, :days_back, 90)
    min_killmails = Keyword.get(options, :min_killmails, 5)
    Logger.debug("Calculating ship specialization for character #{character_id}")
    # Get character's recent killmail data
    killmail_data = get_character_killmail_data(character_id, days_back)

    if length(killmail_data) < min_killmails do
      {:ok,
       %{
         specializations: %{},
         preferred_roles: [],
         expertise_level: :novice,
         ship_mastery: %{},
         total_killmails: length(killmail_data),
         analysis_period_days: days_back,
         calculated_at: DateTime.utc_now(),
         note: "Insufficient data for analysis"
       }}
    else
      # Analyze ship usage patterns
      ship_usage = analyze_ship_usage_patterns(killmail_data)
      # Calculate role preferences
      role_preferences = calculate_role_preferences(killmail_data)
      # Determine expertise level
      expertise_level = determine_expertise_level(killmail_data, ship_usage)
      # Calculate ship mastery scores
      ship_mastery = calculate_ship_mastery_scores(killmail_data)

      {:ok,
       %{
         specializations: ship_usage,
         preferred_roles: role_preferences,
         expertise_level: expertise_level,
         ship_mastery: ship_mastery,
         total_killmails: length(killmail_data),
         analysis_period_days: days_back,
         calculated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Get ship preference insights for character threat assessment.
  Returns preferred ship classes, tactical roles, and effectiveness patterns.
  """
  def get_character_ship_preferences(character_id) do
    case calculate_ship_specialization(character_id, days_back: 30) do
      {:ok, specialization} ->
        %{
          primary_ship_classes: extract_primary_ship_classes(specialization),
          preferred_roles: specialization.preferred_roles,
          specialization_diversity: calculate_specialization_diversity(specialization),
          mastery_level: specialization.expertise_level
        }

      {:error, reason} ->
        Logger.warning(
          "Failed to get ship preferences for character #{character_id}: #{inspect(reason)}"
        )

        %{
          primary_ship_classes: [],
          preferred_roles: [],
          specialization_diversity: 0.0,
          mastery_level: :unknown
        }
    end
  end

  ## Fleet Operations Integration
  @doc """
  Enhanced fleet composition analysis for fleet operations.
  Provides detailed fleet analysis including role distribution,
  doctrine identification, and tactical recommendations.
  """
  def analyze_fleet_for_operations(fleet_composition) when is_list(fleet_composition) do
    Logger.debug("Analyzing fleet composition for operations")
    # Extract ship type IDs
    ship_types = extract_ship_types_from_composition(fleet_composition)

    if Enum.empty?(ship_types) do
      {:error, :no_ships}
    else
      # Use FleetAnalyzer for comprehensive analysis
      case FleetAnalyzer.analyze_fleet_composition(ship_types) do
        {:ok, analysis} ->
          # Enhance with operational insights
          operational_analysis = %{
            fleet_size: analysis.fleet_size,
            doctrine: analysis.doctrine_classification,
            role_balance: analysis.role_distribution,
            tactical_strengths: analysis.tactical_assessment,
            threat_level: analysis.threat_level,
            recommendations: analysis.recommendations,
            readiness_assessment: assess_operational_readiness(analysis),
            engagement_suitability: assess_engagement_suitability(analysis),
            logistics_sustainability: assess_logistics_sustainability(analysis)
          }

          {:ok, operational_analysis}

        {:error, :fleet_too_small} ->
          # Return minimal analysis for small fleets
          {:ok,
           %{
             fleet_size: length(ship_types),
             doctrine: %{doctrine: "small_gang", confidence: 0.5},
             role_balance: %{},
             tactical_strengths: %{},
             threat_level: 2.0,
             recommendations: ["Fleet too small for doctrine analysis"],
             readiness_assessment: :needs_preparation,
             engagement_suitability: :fair,
             logistics_sustainability: :insufficient
           }}

        {:error, reason} ->
          Logger.error("Fleet analysis failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  ## Surveillance Profiles Integration
  @doc """
  Enhanced ship filtering for surveillance profiles.
  Provides advanced ship classification filters based on tactical roles,
  threat levels, and doctrine compliance.
  """
  def get_ship_filter_options do
    %{
      tactical_roles: [
        %{value: "dps", label: "DPS Ships", description: "Primary damage dealers"},
        %{value: "logistics", label: "Logistics", description: "Repair and support ships"},
        %{value: "ewar", label: "EWAR", description: "Electronic warfare specialists"},
        %{value: "tackle", label: "Tackle", description: "Tackling and interdiction"},
        %{value: "command", label: "Command", description: "Fleet command and bonuses"},
        %{value: "support", label: "Support", description: "Utility and support roles"}
      ],
      doctrine_categories: [
        %{
          value: "armor_doctrine",
          label: "Armor Doctrines",
          description: "Armor-tanked fleet compositions"
        },
        %{
          value: "shield_doctrine",
          label: "Shield Doctrines",
          description: "Shield-tanked fleet compositions"
        },
        %{
          value: "sniper_doctrine",
          label: "Sniper Doctrines",
          description: "Long-range alpha strike"
        },
        %{
          value: "brawler_doctrine",
          label: "Brawler Doctrines",
          description: "Close-range high DPS"
        },
        %{
          value: "kiting_doctrine",
          label: "Kiting Doctrines",
          description: "Mobile hit-and-run tactics"
        }
      ],
      threat_levels: [
        %{value: "high_threat", label: "High Threat", description: "Threat level 7.0+"},
        %{value: "medium_threat", label: "Medium Threat", description: "Threat level 4.0-6.9"},
        %{value: "low_threat", label: "Low Threat", description: "Threat level below 4.0"}
      ]
    }
  end

  @doc """
  Filter killmails by enhanced ship criteria for surveillance.
  """
  def filter_killmails_by_ship_intelligence(killmails, filters) do
    Enum.filter(killmails, fn killmail ->
      ship_classification = classify_killmail_ship(killmail)
      matches_filters?(ship_classification, filters)
    end)
  end

  ## Private Helper Functions
  defp extract_killmails_from_battle(battle_data) do
    # Extract killmail data from battle structure
    case battle_data do
      %{killmails: killmails} when is_list(killmails) ->
        killmails

      %{battles: battles} when is_list(battles) ->
        battles |> Enum.flat_map(fn battle -> battle.killmails || [] end)

      _ ->
        []
    end
  end

  defp classify_ship_role_from_killmail(killmail) do
    try do
      classification = ModuleClassifier.classify_ship_role(killmail)
      ship_type_id = extract_ship_type_id(killmail)

      {:ok,
       %{
         killmail_id: killmail["killmail_id"] || killmail.killmail_id,
         ship_type_id: ship_type_id,
         role_classification: classification,
         confidence: calculate_classification_confidence(classification),
         classified_at: DateTime.utc_now()
       }}
    rescue
      error ->
        Logger.debug("Failed to classify ship role from killmail: #{inspect(error)}")
        {:error, error}
    end
  end

  defp extract_ship_type_id(killmail) do
    case killmail do
      %{"victim" => %{"ship_type_id" => ship_type_id}} -> ship_type_id
      %{victim: %{ship_type_id: ship_type_id}} -> ship_type_id
      %{ship_type_id: ship_type_id} -> ship_type_id
      _ -> nil
    end
  end

  defp calculate_classification_confidence(classification) when is_map(classification) do
    # Calculate confidence based on the highest role score
    classification
    |> Map.values()
    |> Enum.max(fn -> 0.0 end)
  end

  defp calculate_classification_confidence(_), do: 0.0

  defp get_ship_role_classification(ship_type_id) do
    query =
      from(s in "ship_role_patterns",
        where: s.ship_type_id == ^ship_type_id,
        select: %{
          ship_type_id: s.ship_type_id,
          primary_role: s.primary_role,
          role_distribution: s.role_distribution,
          confidence_score: s.confidence_score,
          meta_trend: s.meta_trend
        }
      )

    case Repo.one(query) do
      nil ->
        %{
          ship_type_id: ship_type_id,
          primary_role: "unknown",
          role_distribution: %{},
          confidence_score: 0.0,
          meta_trend: "unknown"
        }

      result ->
        result
    end
  end

  defp calculate_enhanced_role_execution(ship_perf, enhanced_role) do
    # Enhanced role execution based on classification confidence and performance
    base_score = ship_perf.role_effectiveness.effectiveness_score || 0.5
    confidence_bonus = (enhanced_role.confidence_score || 0.0) * 0.3
    min(1.0, base_score + confidence_bonus)
  end

  defp assess_doctrine_compliance(ship_perf, battle_context) do
    # Assess how well the ship fits identified fleet doctrine
    ship_type_id = ship_perf.ship_instance.ship_type_id

    if battle_context && battle_context.fleet_analysis do
      doctrine = battle_context.fleet_analysis.doctrine_classification
      ship_fits_doctrine = ship_fits_doctrine?(ship_type_id, doctrine)

      %{
        doctrine_name: doctrine.doctrine || "unknown",
        compliance_score: if(ship_fits_doctrine, do: 0.8, else: 0.3),
        fits_doctrine: ship_fits_doctrine
      }
    else
      %{
        doctrine_name: "unknown",
        compliance_score: 0.5,
        fits_doctrine: false
      }
    end
  end

  defp enhance_tactical_analysis(ship_perf, enhanced_role) do
    %{
      role_clarity_enhanced: assess_enhanced_role_clarity(enhanced_role),
      specialization_score: enhanced_role.confidence_score || 0.0,
      tactical_suitability: assess_tactical_suitability(ship_perf, enhanced_role)
    }
  end

  defp assess_enhanced_role_clarity(enhanced_role) do
    confidence = enhanced_role.confidence_score || 0.0

    cond do
      confidence >= 0.8 -> :very_clear
      confidence >= 0.6 -> :clear
      confidence >= 0.4 -> :somewhat_clear
      confidence >= 0.2 -> :unclear
      true -> :very_unclear
    end
  end

  defp assess_tactical_suitability(ship_perf, enhanced_role) do
    # How well the ship's performance matched its classified role
    role = enhanced_role.primary_role
    performance_score = ship_perf.role_effectiveness.effectiveness_score || 0.5

    case role do
      "dps" -> performance_score * 1.0
      # Logistics harder to measure
      "logistics" -> performance_score * 0.9
      # EWAR effects hard to quantify
      "ewar" -> performance_score * 0.8
      # Tackle success measurable
      "tackle" -> performance_score * 0.85
      # Command bonuses indirect
      "command" -> performance_score * 0.7
      # Unknown roles get lower weight
      _ -> performance_score * 0.6
    end
  end

  # Character intelligence helper functions
  defp get_character_killmail_data(character_id, days_back) do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    query =
      from(k in "killmails_raw",
        where: k.killmail_time >= ^cutoff_date,
        where: fragment("?->>'character_id' = ?", k.raw_data, ^to_string(character_id)),
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          victim_ship_type_id: k.victim_ship_type_id,
          raw_data: k.raw_data
        },
        limit: 1000
      )

    Repo.all(query)
  end

  defp analyze_ship_usage_patterns(killmail_data) do
    killmail_data
    |> Enum.group_by(& &1.victim_ship_type_id)
    |> Enum.map(fn {ship_type_id, killmails} ->
      {ship_type_id,
       %{
         usage_count: length(killmails),
         usage_percentage: length(killmails) / length(killmail_data) * 100,
         recent_usage: Enum.take(killmails, 10)
       }}
    end)
    |> Enum.into(%{})
  end

  defp calculate_role_preferences(killmail_data) do
    # Classify ships and aggregate role preferences
    role_counts =
      killmail_data
      |> Enum.map(fn km ->
        classification = ModuleClassifier.classify_ship_role(km.raw_data)
        determine_primary_role(classification)
      end)
      |> Enum.frequencies()

    total_kills = length(killmail_data)

    role_counts
    |> Enum.map(fn {role, count} ->
      %{
        role: role,
        count: count,
        percentage: count / total_kills * 100
      }
    end)
    |> Enum.sort_by(& &1.percentage, :desc)
  end

  defp determine_primary_role(classification) when is_map(classification) do
    classification
    |> Enum.max_by(fn {_role, score} -> score end, fn -> {"unknown", 0} end)
    |> elem(0)
  end

  defp determine_primary_role(_), do: "unknown"

  defp determine_expertise_level(killmail_data, ship_usage) do
    total_kills = length(killmail_data)
    ship_diversity = map_size(ship_usage)

    cond do
      total_kills >= 100 and ship_diversity >= 10 -> :expert
      total_kills >= 50 and ship_diversity >= 5 -> :experienced
      total_kills >= 20 and ship_diversity >= 3 -> :competent
      total_kills >= 10 -> :novice
      true -> :beginner
    end
  end

  defp calculate_ship_mastery_scores(killmail_data) do
    # Calculate mastery based on consistency and performance
    ship_performance =
      killmail_data
      |> Enum.group_by(& &1.victim_ship_type_id)
      |> Enum.map(fn {ship_type_id, killmails} ->
        mastery_score = calculate_individual_ship_mastery(killmails)
        {ship_type_id, mastery_score}
      end)
      |> Enum.into(%{})

    ship_performance
  end

  defp calculate_individual_ship_mastery(killmails) do
    # Simple mastery calculation based on usage frequency and consistency
    usage_count = length(killmails)
    # Time span analysis
    times = Enum.map(killmails, & &1.killmail_time)
    time_span_days = calculate_time_span_days(times)
    consistency = usage_count / max(time_span_days, 1)
    # Max score at 20+ killmails
    base_score = min(1.0, usage_count / 20.0)
    consistency_bonus = min(0.3, consistency * 0.1)
    base_score + consistency_bonus
  end

  defp calculate_time_span_days(times) when length(times) < 2, do: 1

  defp calculate_time_span_days(times) do
    sorted_times = Enum.sort(times, DateTime)
    first = List.first(sorted_times)
    last = List.last(sorted_times)
    DateTime.diff(last, first, :day) + 1
  end

  # Fleet operations helper functions
  defp extract_ship_types_from_composition(fleet_composition) do
    Enum.map(fleet_composition, fn ship ->
      case ship do
        %{ship_type_id: id} -> id
        %{"ship_type_id" => id} -> id
        id when is_integer(id) -> id
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  defp assess_operational_readiness(analysis) do
    tactical = analysis.tactical_assessment

    readiness_factors = [
      tactical.logistics.score,
      tactical.tank_consistency.score,
      tactical.support_coverage.score
    ]

    avg_readiness = Enum.sum(readiness_factors) / length(readiness_factors)

    cond do
      avg_readiness >= 0.8 -> :combat_ready
      avg_readiness >= 0.6 -> :mostly_ready
      avg_readiness >= 0.4 -> :needs_preparation
      true -> :not_ready
    end
  end

  defp assess_engagement_suitability(analysis) do
    threat_level = analysis.threat_level
    doctrine_confidence = analysis.doctrine.confidence
    overall_suitability = threat_level / 10.0 * 0.7 + doctrine_confidence * 0.3

    cond do
      overall_suitability >= 0.8 -> :excellent
      overall_suitability >= 0.6 -> :good
      overall_suitability >= 0.4 -> :fair
      true -> :poor
    end
  end

  defp assess_logistics_sustainability(analysis) do
    logistics_ratio = analysis.role_balance["logistics"] || 0.0
    logistics_assessment = analysis.tactical_strengths.logistics.assessment

    case {logistics_ratio, logistics_assessment} do
      {ratio, "optimal"} when ratio >= 0.15 -> :excellent
      {ratio, "adequate"} when ratio >= 0.10 -> :good
      {ratio, _} when ratio >= 0.05 -> :marginal
      _ -> :insufficient
    end
  end

  # Surveillance helper functions
  defp classify_killmail_ship(killmail) do
    ship_type_id = extract_ship_type_id(killmail)
    role_classification = get_ship_role_classification(ship_type_id)

    %{
      ship_type_id: ship_type_id,
      primary_role: role_classification.primary_role,
      confidence: role_classification.confidence_score,
      meta_trend: role_classification.meta_trend
    }
  end

  defp matches_filters?(ship_classification, filters) do
    Enum.all?(filters, fn
      {:tactical_role, role} ->
        ship_classification.primary_role == role

      {:doctrine_category, category} ->
        ship_matches_doctrine_category?(ship_classification, category)

      {:threat_level, level} ->
        ship_matches_threat_level?(ship_classification, level)

      _ ->
        true
    end)
  end

  defp ship_matches_doctrine_category?(ship_classification, category) do
    # Simple doctrine category matching
    role = ship_classification.primary_role

    case category do
      # Simplified
      "armor_doctrine" -> role in ["dps", "logistics", "command"]
      # Simplified
      "shield_doctrine" -> role in ["dps", "logistics", "ewar"]
      "sniper_doctrine" -> role == "dps"
      "brawler_doctrine" -> role in ["dps", "tackle"]
      "kiting_doctrine" -> role in ["dps", "ewar"]
      _ -> false
    end
  end

  defp ship_matches_threat_level?(ship_classification, level) do
    # Simple threat level assessment based on role and confidence
    base_threat =
      case ship_classification.primary_role do
        "dps" -> 6.0
        "tackle" -> 5.0
        "ewar" -> 4.5
        "logistics" -> 3.0
        "command" -> 4.0
        _ -> 2.0
      end

    confidence_modifier = (ship_classification.confidence || 0.0) * 2.0
    total_threat = base_threat + confidence_modifier

    case level do
      "high_threat" -> total_threat >= 7.0
      "medium_threat" -> total_threat >= 4.0 and total_threat < 7.0
      "low_threat" -> total_threat < 4.0
      _ -> false
    end
  end

  defp ship_fits_doctrine?(ship_type_id, doctrine) do
    # Check if ship type matches doctrine primary ships
    case doctrine do
      %{pattern: %{primary_ships: primary_ships}} ->
        ship_type_id in primary_ships

      _ ->
        false
    end
  end

  defp extract_primary_ship_classes(specialization) do
    specialization.specializations
    |> Enum.sort_by(fn {_ship_id, data} -> data.usage_percentage end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {ship_id, _data} -> ship_id end)
  end

  defp calculate_specialization_diversity(specialization) do
    # Calculate diversity index (0.0 = specialized, 1.0 = very diverse)
    ship_count = map_size(specialization.specializations)

    if ship_count <= 1 do
      0.0
    else
      # Simple diversity calculation
      min(1.0, (ship_count - 1) / 10.0)
    end
  end
end
