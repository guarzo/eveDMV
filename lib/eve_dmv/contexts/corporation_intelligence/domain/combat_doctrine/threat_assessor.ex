defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrine.ThreatAssessor do
  @moduledoc """
  Threat assessment for combat doctrine analysis.

  Evaluates doctrine threats, strengths, weaknesses, and recommends
  counter-strategies based on identified combat doctrines.
  """

  require Logger

  @doc """
  Generates a threat assessment for a doctrine classification.
  """
  def generate_doctrine_threat_assessment(doctrine_classification) do
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

  @doc """
  Gets the strengths for a given doctrine.
  """
  def get_doctrine_strengths(doctrine_key) do
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

  @doc """
  Gets the weaknesses for a given doctrine.
  """
  def get_doctrine_weaknesses(doctrine_key) do
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

  @doc """
  Gets recommended counters for a given doctrine.
  """
  def get_recommended_counters(doctrine_key) do
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

  @doc """
  Analyzes counter relationships between doctrines.
  """
  def analyze_counter_relationships(doctrine_analyses) do
    pairs = combinations_of_two(doctrine_analyses)

    relationships =
      Enum.map(pairs, fn {d1, d2} ->
        %{
          doctrines: {d1[:corporation_id], d2[:corporation_id]},
          counter_effectiveness: calculate_counter_effectiveness(d1, d2),
          mutual_vulnerabilities: calculate_mutual_vulnerabilities(d1, d2)
        }
      end)

    %{
      pairwise_relationships: relationships,
      vulnerability_matrix: build_vulnerability_matrix(relationships)
    }
  end

  @doc """
  Generates competitive assessment from doctrine analyses.
  """
  def generate_competitive_assessment(doctrine_analyses) do
    if length(doctrine_analyses) < 2 do
      %{
        assessment_level: :insufficient_data,
        recommendations: ["Need at least 2 corporations for competitive analysis"]
      }
    else
      # Analyze doctrine distribution
      distribution = analyze_doctrine_distribution(doctrine_analyses)

      # Identify relationships
      counter_relationships = analyze_counter_relationships(doctrine_analyses)

      assessment_level =
        cond do
          distribution.diversity_index > 0.7 -> :highly_competitive
          distribution.diversity_index > 0.4 -> :moderately_competitive
          true -> :low_competition
        end

      %{
        assessment_level: assessment_level,
        doctrine_distribution: distribution,
        counter_relationships: counter_relationships,
        key_vulnerabilities: identify_key_vulnerabilities(counter_relationships),
        tactical_recommendations:
          generate_tactical_recommendations(assessment_level, distribution)
      }
    end
  end

  # Private functions

  defp calculate_counter_effectiveness(d1, d2) do
    d1_primary = get_in(d1, [:doctrine_classification, :primary_doctrine, :key])
    d2_primary = get_in(d2, [:doctrine_classification, :primary_doctrine, :key])

    calculate_theoretical_counter(d1_primary, d2_primary)
  end

  defp calculate_mutual_vulnerabilities(d1, d2) do
    d1_weaknesses =
      get_doctrine_weaknesses(get_in(d1, [:doctrine_classification, :primary_doctrine, :key]))

    d2_strengths =
      get_doctrine_strengths(get_in(d2, [:doctrine_classification, :primary_doctrine, :key]))

    overlap = MapSet.intersection(MapSet.new(d1_weaknesses), MapSet.new(d2_strengths))
    MapSet.to_list(overlap)
  end

  defp calculate_theoretical_counter(doctrine1, doctrine2) do
    counter_matrix = %{
      {:shield_kiting, :armor_brawling} => 0.7,
      {:armor_brawling, :shield_kiting} => 0.3,
      {:shield_kiting, :nano_gang} => 0.5,
      {:nano_gang, :shield_kiting} => 0.5,
      {:armor_brawling, :ewar_heavy} => 0.4,
      {:ewar_heavy, :armor_brawling} => 0.6,
      {:alpha_strike, :logistics_heavy} => 0.7,
      {:logistics_heavy, :alpha_strike} => 0.3,
      {:capital_escalation, :nano_gang} => 0.8,
      {:nano_gang, :capital_escalation} => 0.2,
      {:ewar_heavy, :alpha_strike} => 0.3,
      {:alpha_strike, :ewar_heavy} => 0.7
    }

    Map.get(counter_matrix, {doctrine1, doctrine2}, 0.5)
  end

  defp build_vulnerability_matrix(relationships) do
    Enum.reduce(relationships, %{}, fn rel, acc ->
      {corp1, corp2} = rel.doctrines
      effectiveness = rel.counter_effectiveness

      acc
      |> Map.update(corp1, %{corp2 => effectiveness}, &Map.put(&1, corp2, effectiveness))
      |> Map.update(
        corp2,
        %{corp1 => 1.0 - effectiveness},
        &Map.put(&1, corp1, 1.0 - effectiveness)
      )
    end)
  end

  defp analyze_doctrine_distribution(doctrine_analyses) do
    doctrines =
      Enum.map(doctrine_analyses, fn analysis ->
        get_in(analysis, [:doctrine_classification, :primary_doctrine, :key])
      end)
      |> Enum.filter(&(&1 != nil))

    frequencies = Enum.frequencies(doctrines)
    total = length(doctrines)

    diversity_index =
      if total > 0 do
        unique = map_size(frequencies)
        min(1.0, unique / max(total / 2, 1))
      else
        0.0
      end

    %{
      doctrine_counts: frequencies,
      total_analyzed: total,
      diversity_index: diversity_index,
      dominant_doctrine: find_dominant_doctrine(frequencies)
    }
  end

  defp find_dominant_doctrine(frequencies) when map_size(frequencies) == 0, do: nil

  defp find_dominant_doctrine(frequencies) do
    {doctrine, _count} = Enum.max_by(frequencies, fn {_k, v} -> v end)
    doctrine
  end

  defp identify_key_vulnerabilities(counter_relationships) do
    counter_relationships.pairwise_relationships
    |> Enum.filter(fn rel -> rel.counter_effectiveness > 0.6 end)
    |> Enum.map(fn rel ->
      {dominant, vulnerable} = rel.doctrines

      %{
        vulnerable_corp: vulnerable,
        dominant_corp: dominant,
        effectiveness: rel.counter_effectiveness
      }
    end)
  end

  defp generate_tactical_recommendations(assessment_level, _distribution) do
    case assessment_level do
      :highly_competitive ->
        [
          "Consider doctrine diversification to counter multiple threats",
          "Monitor competitor doctrine evolution closely",
          "Prepare counter-doctrines for dominant threats"
        ]

      :moderately_competitive ->
        [
          "Focus on strengthening primary doctrine",
          "Develop secondary counter-doctrine",
          "Improve coordination and execution"
        ]

      :low_competition ->
        [
          "Opportunity to establish doctrine dominance",
          "Focus on member skill development",
          "Consider expansion of tactical options"
        ]

      _ ->
        ["Gather more intelligence for tactical recommendations"]
    end
  end

  defp combinations_of_two([]), do: []
  defp combinations_of_two([_]), do: []

  defp combinations_of_two([h | t]) do
    pairs_with_head = Enum.map(t, fn x -> {h, x} end)
    pairs_with_head ++ combinations_of_two(t)
  end
end
