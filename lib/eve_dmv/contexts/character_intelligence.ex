defmodule EveDmv.Contexts.CharacterIntelligence do
  @moduledoc """
  Context module for character intelligence and threat analysis.

  Provides the public API for character threat scoring, behavioral analysis,
  and combat effectiveness prediction.
  """

  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoringEngine

  @doc """
  Analyzes a character's threat level based on their combat history.

  Returns comprehensive threat scoring including:
  - Multi-dimensional threat score (0-100)
  - Combat effectiveness metrics
  - Behavioral patterns
  - Threat trends over time

  ## Examples

      iex> CharacterIntelligence.analyze_character_threat(character_id)
      {:ok, %{
        threat_score: 85,
        dimensions: %{combat_skill: 90, ship_mastery: 80, ...},
        behavioral_pattern: :solo_hunter,
        recent_activity: %{...}
      }}
  """
  def analyze_character_threat(character_id) do
    case ThreatScoringEngine.calculate_threat_score(character_id) do
      {:ok, threat_data} ->
        # Enhance with ship specialization analysis
        enhanced_threat_data = enhance_with_ship_intelligence(threat_data, character_id)
        {:ok, enhanced_threat_data}

      {:error, :insufficient_data} ->
        # Return a default threat analysis for characters with limited data
        {:ok,
         %{
           threat_score: 0,
           threat_level: :minimal,
           dimensions: %{
             combat_skill: 0,
             ship_mastery: 0,
             gang_effectiveness: 0,
             unpredictability: 0,
             recent_activity: 0
           },
           ship_specialization: %{
             preferred_roles: [],
             ship_mastery: %{},
             specialization_diversity: 0.0,
             expertise_level: :unknown
           },
           analysis_metadata: %{
             data_quality: :insufficient,
             killmail_count: 0,
             analysis_window_days: 90
           }
         }}

      error ->
        error
    end
  end

  @doc """
  Detects behavioral patterns for a character based on their killmail history.

  Identifies patterns such as:
  - Solo hunter
  - Fleet anchor
  - Specialist
  - Opportunist
  """
  def detect_behavioral_patterns(character_id) do
    # Since ThreatScoringEngine includes behavioral analysis in the threat score,
    # we'll extract it from there
    case analyze_character_threat(character_id) do
      {:ok, threat_data} ->
        {:ok,
         %{
           primary_pattern: threat_data[:behavioral_pattern] || :unknown,
           patterns: extract_behavioral_patterns(threat_data),
           characteristics: generate_behavioral_characteristics(threat_data)
         }}

      error ->
        error
    end
  end

  @doc """
  Calculates threat trends for a character over time.

  Shows how their threat level has evolved based on recent performance.
  """
  def calculate_threat_trends(character_id, days_back \\ 90) do
    case ThreatScoringEngine.analyze_threat_trends(character_id, analysis_window_days: days_back) do
      {:ok, trends} ->
        {:ok, trends}

      {:error, :insufficient_data} ->
        # Return default trends for characters with limited data
        {:ok,
         %{
           periods: [
             %{
               label: "Recent (30 days)",
               date_range: "Limited data",
               threat_score: 0,
               previous_score: nil
             }
           ],
           trend: :stable,
           analysis: "Insufficient combat data for trend analysis"
         }}

      error ->
        error
    end
  end

  @doc """
  Compares threat levels between multiple characters.

  Useful for identifying the most dangerous opponents in a group.
  """
  def compare_character_threats(character_ids) when is_list(character_ids) do
    threat_analyses =
      character_ids
      |> Enum.map(fn id ->
        case analyze_character_threat(id) do
          {:ok, analysis} -> {id, analysis}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(fn {_id, analysis} -> analysis.threat_score end, :desc)

    {:ok, threat_analyses}
  end

  @doc """
  Gets a comprehensive intelligence report for a character.

  Combines threat scoring, behavioral analysis, and performance metrics.
  """
  def get_character_intelligence_report(character_id) do
    require Logger

    with {:ok, threat_analysis} <- analyze_character_threat(character_id),
         {:ok, behavioral_patterns} <- detect_behavioral_patterns(character_id),
         {:ok, threat_trends} <- calculate_threat_trends(character_id),
         {:ok, character_info} <- get_character_info(character_id),
         {:ok, combat_stats} <- get_combat_statistics(character_id) do
      {:ok,
       %{
         character: character_info,
         threat_analysis: threat_analysis,
         behavioral_patterns: behavioral_patterns,
         threat_trends: threat_trends,
         combat_stats: combat_stats,
         summary: generate_intelligence_summary(threat_analysis, behavioral_patterns)
       }}
    else
      {:error, reason} = error ->
        Logger.error("Failed to get character intelligence report: #{inspect(reason)}")
        error

      error ->
        Logger.error("Unexpected error in character intelligence report: #{inspect(error)}")
        {:error, :unknown_error}
    end
  end

  ## Ship Intelligence Integration

  @doc """
  Get comprehensive ship intelligence for a character.

  Returns ship specialization, role preferences, and tactical insights.
  """
  def get_character_ship_intelligence(character_id) do
    EveDmv.Integrations.ShipIntelligenceBridge.calculate_ship_specialization(character_id)
  end

  @doc """
  Get ship preference summary for quick threat assessment.
  """
  def get_ship_preferences(character_id) do
    EveDmv.Integrations.ShipIntelligenceBridge.get_character_ship_preferences(character_id)
  end

  # Private helper functions

  defp enhance_with_ship_intelligence(threat_data, character_id) do
    case EveDmv.Integrations.ShipIntelligenceBridge.calculate_ship_specialization(character_id) do
      {:ok, ship_intelligence} ->
        # Enhance ship mastery dimension with detailed analysis
        enhanced_dimensions =
          Map.update(
            threat_data.dimensions,
            :ship_mastery,
            0,
            fn base_score ->
              # Combine base score with specialization insights
              specialization_bonus = calculate_specialization_bonus(ship_intelligence)
              min(100, base_score + specialization_bonus)
            end
          )

        # Add ship intelligence to threat data
        threat_data
        |> Map.put(:ship_specialization, format_ship_specialization(ship_intelligence))
        |> Map.put(:dimensions, enhanced_dimensions)

      {:error, _reason} ->
        # Add empty ship specialization data
        threat_data
        |> Map.put(:ship_specialization, %{
          preferred_roles: [],
          ship_mastery: %{},
          specialization_diversity: 0.0,
          expertise_level: :unknown
        })
    end
  end

  defp calculate_specialization_bonus(ship_intelligence) do
    # Calculate bonus to ship mastery based on specialization depth
    expertise_bonus =
      case ship_intelligence.expertise_level do
        :expert -> 15
        :experienced -> 10
        :competent -> 5
        :novice -> 2
        _ -> 0
      end

    # Diversity penalty (specialists get higher scores)
    diversity_penalty = ship_intelligence.specialization_diversity * 5

    max(0, expertise_bonus - diversity_penalty)
  end

  defp format_ship_specialization(ship_intelligence) do
    %{
      preferred_roles: ship_intelligence.preferred_roles |> Enum.take(3),
      ship_mastery: ship_intelligence.ship_mastery |> Enum.take(5) |> Enum.into(%{}),
      specialization_diversity: ship_intelligence.specialization_diversity,
      expertise_level: ship_intelligence.expertise_level,
      total_killmails: ship_intelligence.total_killmails || 0
    }
  end

  # Private helper functions

  defp get_combat_statistics(character_id) do
    import Ash.Query
    alias EveDmv.Api
    alias EveDmv.Killmails.KillmailRaw

    # Calculate kills where character was attacker
    kills_query =
      KillmailRaw
      |> new()
      |> sort(killmail_time: :desc)
      |> limit(1000)

    case Ash.read(kills_query, domain: Api) do
      {:ok, killmails} ->
        # Filter for kills where character was attacker
        kills =
          Enum.filter(killmails, fn km ->
            case km.raw_data do
              %{"attackers" => attackers} when is_list(attackers) ->
                Enum.any?(attackers, &(&1["character_id"] == character_id))

              _ ->
                false
            end
          end)

        # Count losses where character was victim
        losses_query =
          KillmailRaw
          |> new()
          |> filter(victim_character_id: character_id)

        losses_count =
          case Ash.count(losses_query, domain: Api) do
            {:ok, count} -> count
            _ -> 0
          end

        kills_count = length(kills)

        # Calculate ISK destroyed and lost
        isk_destroyed =
          Enum.reduce(kills, 0, fn km, acc ->
            acc + Map.get(km.raw_data["zkb"] || %{}, "totalValue", 0)
          end)

        # For now, calculate ISK lost from the raw data since total_value might not be populated
        isk_lost_query =
          KillmailRaw
          |> new()
          |> filter(victim_character_id: character_id)

        isk_lost =
          case Ash.read(isk_lost_query, domain: Api) do
            {:ok, loss_killmails} ->
              Enum.reduce(loss_killmails, 0, fn km, acc ->
                acc + (get_in(km.raw_data, ["zkb", "totalValue"]) || 0)
              end)

            _ ->
              0
          end

        {:ok,
         %{
           total_kills: kills_count,
           total_losses: losses_count,
           kill_death_ratio:
             if(losses_count > 0,
               do: Float.round(kills_count / losses_count, 2),
               else: kills_count
             ),
           isk_destroyed: isk_destroyed,
           isk_lost: isk_lost,
           isk_efficiency:
             if(isk_lost > 0,
               do: Float.round(isk_destroyed / (isk_destroyed + isk_lost) * 100, 1),
               else: 100.0
             ),
           recent_activity: %{
             last_7_days: count_recent_activity(kills, 7),
             last_30_days: count_recent_activity(kills, 30)
           }
         }}

      _ ->
        {:ok,
         %{
           total_kills: 0,
           total_losses: 0,
           kill_death_ratio: 0,
           isk_destroyed: 0,
           isk_lost: 0,
           isk_efficiency: 0,
           recent_activity: %{
             last_7_days: 0,
             last_30_days: 0
           }
         }}
    end
  end

  defp count_recent_activity(kills, days) do
    cutoff = NaiveDateTime.add(NaiveDateTime.utc_now(), -days * 24 * 60 * 60, :second)

    Enum.count(kills, fn km ->
      NaiveDateTime.compare(km.killmail_time, cutoff) == :gt
    end)
  end

  defp get_character_info(character_id) do
    alias EveDmv.Eve.NameResolver
    alias EveDmv.Eve.EsiCharacterClient

    # Get character name
    character_name = NameResolver.character_name(character_id)

    # Get character's corporation and alliance info from ESI
    case EsiCharacterClient.get_character(character_id) do
      {:ok, char_info} ->
        {:ok,
         %{
           character_id: character_id,
           name: character_name,
           corporation_id: char_info["corporation_id"],
           corporation_name: NameResolver.corporation_name(char_info["corporation_id"]),
           alliance_id: char_info["alliance_id"],
           alliance_name:
             if(char_info["alliance_id"],
               do: NameResolver.alliance_name(char_info["alliance_id"]),
               else: nil
             )
         }}

      {:error, _reason} ->
        # Fallback to just the character name if ESI fails
        {:ok,
         %{
           character_id: character_id,
           name: character_name,
           corporation_id: nil,
           corporation_name: nil,
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  defp extract_behavioral_patterns(threat_data) do
    # Extract behavioral patterns from threat data dimensions
    dimensions = Map.get(threat_data, :dimensions, %{})

    patterns =
      []
      |> maybe_add_pattern(:solo_hunter, dimensions[:solo_effectiveness] > 70)
      |> maybe_add_pattern(:fleet_anchor, dimensions[:gang_effectiveness] > 80)
      |> maybe_add_pattern(:specialist, dimensions[:ship_focus] > 0.7)
      |> maybe_add_pattern(:opportunist, dimensions[:target_selection_variance] > 0.6)

    # Convert to pattern map with confidence scores
    Enum.map(patterns, fn pattern ->
      {pattern, calculate_pattern_confidence(pattern, dimensions)}
    end)
    |> Enum.into(%{})
  end

  defp maybe_add_pattern(patterns, pattern, true), do: [pattern | patterns]
  defp maybe_add_pattern(patterns, _pattern, false), do: patterns

  defp calculate_pattern_confidence(:solo_hunter, dimensions) do
    Map.get(dimensions, :solo_effectiveness, 0) / 100.0
  end

  defp calculate_pattern_confidence(:fleet_anchor, dimensions) do
    Map.get(dimensions, :gang_effectiveness, 0) / 100.0
  end

  defp calculate_pattern_confidence(:specialist, dimensions) do
    Map.get(dimensions, :ship_focus, 0)
  end

  defp calculate_pattern_confidence(:opportunist, dimensions) do
    Map.get(dimensions, :target_selection_variance, 0)
  end

  defp generate_behavioral_characteristics(threat_data) do
    dimensions = Map.get(threat_data, :dimensions, %{})
    characteristics = []

    # Add characteristics based on dimensions
    characteristics =
      if dimensions[:combat_skill] > 80 do
        ["Highly skilled combatant" | characteristics]
      else
        characteristics
      end

    characteristics =
      if dimensions[:ship_mastery] > 75 do
        ["Proficient with multiple ship types" | characteristics]
      else
        characteristics
      end

    characteristics =
      if dimensions[:gang_effectiveness] > 70 do
        ["Effective in fleet operations" | characteristics]
      else
        characteristics
      end

    characteristics =
      if dimensions[:unpredictability] > 60 do
        ["Unpredictable engagement patterns" | characteristics]
      else
        characteristics
      end

    characteristics
  end

  defp generate_intelligence_summary(threat_analysis, behavioral_patterns) do
    primary_pattern = behavioral_patterns |> Map.get(:primary_pattern, :unknown)

    threat_level =
      case threat_analysis.threat_score do
        score when score >= 90 -> "Extreme"
        score when score >= 75 -> "High"
        score when score >= 50 -> "Moderate"
        score when score >= 25 -> "Low"
        _ -> "Minimal"
      end

    %{
      threat_level: threat_level,
      threat_score: threat_analysis.threat_score,
      primary_behavior: primary_pattern,
      summary:
        "#{threat_level} threat #{primary_pattern |> to_string() |> String.replace("_", " ")} with #{threat_analysis.threat_score}/100 overall score",
      key_strengths: extract_key_strengths(threat_analysis.dimensions),
      recommendations: generate_tactical_recommendations(threat_analysis, behavioral_patterns)
    }
  end

  defp extract_key_strengths(dimensions) do
    dimensions
    |> Enum.sort_by(fn {_key, value} -> value end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {key, value} ->
      %{
        dimension: key |> to_string() |> String.replace("_", " ") |> String.capitalize(),
        score: value
      }
    end)
  end

  defp generate_tactical_recommendations(threat_analysis, behavioral_patterns) do
    pattern = behavioral_patterns.primary_pattern

    base_recommendations =
      case pattern do
        :solo_hunter ->
          [
            "Avoid isolated engagements",
            "Travel with backup when possible",
            "Use scout alts in adjacent systems"
          ]

        :fleet_anchor ->
          [
            "Primary target in fleet engagements",
            "Likely to have logistics support",
            "Disrupt their fleet coordination"
          ]

        :specialist ->
          [
            "Predictable ship choices",
            "Counter their preferred tactics",
            "Force them out of comfort zone"
          ]

        :opportunist ->
          [
            "Unpredictable target selection",
            "Avoid appearing as easy target",
            "Watch for baiting tactics"
          ]

        _ ->
          [
            "Gather more intelligence",
            "Observe engagement patterns",
            "Assess threat carefully"
          ]
      end

    # Add recommendations based on threat score
    threat_recommendations =
      if threat_analysis.threat_score >= 75 do
        ["Exercise extreme caution", "Consider avoiding direct engagement"]
      else
        []
      end

    base_recommendations ++ threat_recommendations
  end
end
