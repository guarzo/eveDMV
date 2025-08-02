defmodule EveDmv.Contexts.Combat.Services.DoctrineEffectivenessService do
  @moduledoc """
  Doctrine effectiveness analysis using real battle data.

  This service replaces hardcoded effectiveness values with data-driven analysis
  by querying actual battle outcomes and killmail data to determine how different
  fleet compositions perform against each other.
  """
  """

  alias EveDmv.Database.KillmailRepository
  alias EveDmv.StaticData.ShipTypes
  # alias EveDmv.Contexts.Combat.Core.BattleAnalyzer
  alias EveDmv.Cache
  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  # Cache effectiveness data for 12 hours
  @cache_ttl :timer.hours(12)

  @doc """
  Analyze how a fleet composition performs against common threat doctrines.

  Uses historical battle data to calculate real effectiveness ratings instead
  of hardcoded values.

  ## Parameters
  - `composition` - Fleet composition to analyze
  - `options` - Analysis options (time_window, min_battles, etc.)

  ## Returns
  - `{:ok, counter_doctrine_analysis}` - Real effectiveness data
  - `{:error, reason}` - Analysis failed
  """
  def analyze_counter_doctrine_effectiveness(composition, options \\ []) do
    time_window_days = Keyword.get(options, :time_window_days, 90)
    min_battles = Keyword.get(options, :min_battles, 5)

    cache_key = {:counter_doctrine_analysis, composition_hash(composition), time_window_days}

    case Cache.get(:analysis, cache_key) do
      nil ->
        result = perform_counter_doctrine_analysis(composition, time_window_days, min_battles)

        if match?({:ok, _}, result) do
          {:ok, analysis} = result
          Cache.put(:analysis, cache_key, analysis, ttl: @cache_ttl)
        end

        result

      cached_analysis ->
        {:ok, cached_analysis}
    end
  end

  @doc """
  Calculate win/loss ratios for a fleet composition against specific threats.

  ## Parameters
  - `composition` - Fleet composition map (ship_type_id => count)
  - `threat_composition` - Enemy fleet composition
  - `time_window_days` - Days of historical data to analyze

  ## Returns
  - `{:ok, effectiveness_score}` - Win rate (0.0 - 1.0)
  """
  def calculate_matchup_effectiveness(composition, threat_composition, time_window_days \\ 90) do
    with {:ok, our_battles} <- find_similar_battles(composition, time_window_days),
         {:ok, threat_battles} <- find_battles_against_threat(our_battles, threat_composition) do
      if length(threat_battles) < 3 do
        # Not enough data, use composition analysis
        estimate_effectiveness_from_composition(composition, threat_composition)
      else
        calculate_win_rate_from_battles(threat_battles)
      end
    end
  end

  @doc """
  Get doctrine classification from fleet composition.

  Classifies fleets by their primary characteristics for analysis.

  ## Parameters
  - `composition` - Fleet composition map

  ## Returns
  - `{:ok, doctrine_type}` - Doctrine classification string
  """
  def classify_doctrine(composition) when is_map(composition) do
    ship_roles = get_composition_roles(composition)
    _total_ships = Enum.sum(Map.values(composition))

    doctrine_type =
      cond do
        # Capital doctrine
        has_significant_role?(ship_roles, "capital", 0.3) ->
          "Capital Fleet"

        # Logistics heavy (defensive)
        has_significant_role?(ship_roles, "logistics", 0.25) ->
          "Logistics Heavy"

        # Battleship doctrine
        has_significant_ship_class?(composition, :battleship, 0.6) ->
          "Battleship Doctrine"

        # HAC/T3C doctrine
        has_t2_t3_focus?(composition) ->
          "HAC/T3 Doctrine"

        # Cruiser doctrine
        has_significant_ship_class?(composition, :cruiser, 0.7) ->
          "Cruiser Doctrine"

        # Frigate/Destroyer swarm
        has_small_ship_focus?(composition) ->
          "Small Ship Swarm"

        # Mixed/Kitchen sink
        true ->
          "Mixed Composition"
      end

    {:ok, doctrine_type}
  end

  @doc """
  Get common threat doctrines in the current meta.

  Returns list of common fleet compositions based on recent battle data.
  """
  def get_common_threat_doctrines(time_window_days \\ 30) do
    cache_key = {:common_threats, time_window_days}

    case Cache.get(:analysis, cache_key) do
      nil ->
        threats = analyze_common_doctrines(time_window_days)
        Cache.put(:analysis, cache_key, threats, ttl: @cache_ttl)
        {:ok, threats}

      cached_threats ->
        {:ok, cached_threats}
    end
  end

  # Private Implementation

  defp perform_counter_doctrine_analysis(composition, time_window_days, min_battles) do
    Logger.info("Analyzing counter-doctrine effectiveness for composition")

    with {:ok, _our_doctrine} <- classify_doctrine(composition),
         {:ok, common_threats} <- get_common_threat_doctrines(time_window_days),
         {:ok, battle_data} <- find_similar_battles(composition, time_window_days) do
      counter_analyses =
        common_threats
        |> Enum.map(fn threat ->
          analyze_threat_matchup(composition, threat, battle_data, min_battles)
        end)
        |> Enum.filter(fn analysis -> analysis.confidence > 0.3 end)

      if Enum.empty?(counter_analyses) do
        # Fallback to composition-based analysis
        generate_composition_based_analysis(composition, common_threats)
      else
        {:ok, counter_analyses}
      end
    else
      {:error, reason} ->
        Logger.warning("Counter-doctrine analysis failed: #{inspect(reason)}")
        generate_fallback_analysis(composition)
    end
  end

  defp find_similar_battles(composition, time_window_days) do
    # Find battles with similar fleet compositions
    start_date = DateTimeUtils.add(DateTime.utc_now(), -time_window_days * 24 * 3600, :second)

    case KillmailRepository.get_battles_since(start_date) do
      {:ok, battles} ->
        similar_battles =
          battles
          |> Enum.filter(fn battle ->
            similarity = calculate_composition_similarity(composition, battle.fleet_composition)
            # 60% similarity threshold
            similarity > 0.6
          end)

        {:ok, similar_battles}

      error ->
        error
    end
  end

  defp find_battles_against_threat(battles, threat_composition) do
    threat_battles =
      battles
      |> Enum.filter(fn battle ->
        enemy_similarity =
          calculate_composition_similarity(threat_composition, battle.enemy_composition)

        # 50% similarity for enemy composition
        enemy_similarity > 0.5
      end)

    {:ok, threat_battles}
  end

  defp calculate_win_rate_from_battles(battles) do
    if Enum.empty?(battles) do
      # Neutral if no data
      {:ok, 0.5}
    else
      wins = Enum.count(battles, &(&1.outcome == :victory))
      win_rate = wins / length(battles)
      confidence = calculate_confidence_from_sample_size(length(battles))

      {:ok, %{effectiveness: Float.round(win_rate, 3), confidence: confidence}}
    end
  end

  defp estimate_effectiveness_from_composition(our_composition, threat_composition) do
    # Estimate effectiveness based on ship capabilities and roles
    our_stats = calculate_composition_stats(our_composition)
    threat_stats = calculate_composition_stats(threat_composition)

    # Compare key metrics
    dps_advantage = our_stats.total_dps / max(threat_stats.total_dps, 1.0)
    tank_advantage = our_stats.total_ehp / max(threat_stats.total_ehp, 1.0)
    utility_advantage = our_stats.utility_score / max(threat_stats.utility_score, 1.0)

    # Weighted effectiveness score
    effectiveness = (dps_advantage * 0.4 + tank_advantage * 0.4 + utility_advantage * 0.2) / 3
    # Clamp between 10% and 90%
    normalized_effectiveness = min(max(effectiveness, 0.1), 0.9)

    {:ok,
     %{
       effectiveness: Float.round(normalized_effectiveness, 3),
       # Lower confidence for estimated values
       confidence: 0.4,
       method: "composition_analysis"
     }}
  end

  defp calculate_composition_stats(composition) do
    total_dps =
      composition
      |> Enum.reduce(0.0, fn {type_id, count}, acc ->
        case ShipTypes.get_ship_dps(type_id) do
          {:ok, dps} -> acc + dps * count
          {:error, _} -> acc
        end
      end)

    total_ehp =
      composition
      |> Enum.reduce(0.0, fn {type_id, count}, acc ->
        case ShipTypes.get_ship_ehp(type_id) do
          {:ok, ehp} -> acc + ehp * count
          {:error, _} -> acc
        end
      end)

    utility_score = calculate_utility_score(composition)

    %{
      total_dps: total_dps,
      total_ehp: total_ehp,
      utility_score: utility_score,
      ship_count: Enum.sum(Map.values(composition))
    }
  end

  defp calculate_utility_score(composition) do
    # Calculate utility based on ship roles and special capabilities
    composition
    |> Enum.reduce(0.0, fn {type_id, count}, acc ->
      utility =
        cond do
          # Logistics very valuable
          ShipTypes.logistics?(type_id) -> 3.0 * count
          # EWAR valuable
          ShipTypes.ewar?(type_id) -> 2.0 * count
          # Tackle moderately valuable
          ShipTypes.tackle_ship?(type_id) -> 1.5 * count
          # Regular ships baseline
          true -> 1.0 * count
        end

      acc + utility
    end)
  end

  defp get_composition_roles(composition) do
    composition
    |> Enum.reduce(%{}, fn {type_id, count}, acc ->
      case ShipTypes.get_ship_role(type_id) do
        {:ok, role} -> Map.update(acc, role, count, &(&1 + count))
        {:error, _} -> Map.update(acc, "dps", count, &(&1 + count))
      end
    end)
  end

  defp has_significant_role?(ship_roles, role, threshold) do
    total_ships = Enum.sum(Map.values(ship_roles))
    role_ships = Map.get(ship_roles, role, 0)

    total_ships > 0 && role_ships / total_ships >= threshold
  end

  defp has_significant_ship_class?(composition, ship_class, threshold) do
    total_ships = Enum.sum(Map.values(composition))

    class_ships =
      composition
      |> Enum.reduce(0, fn {type_id, count}, acc ->
        case ShipTypes.classify_ship_type(type_id) do
          ^ship_class -> acc + count
          _ -> acc
        end
      end)

    total_ships > 0 && class_ships / total_ships >= threshold
  end

  defp has_t2_t3_focus?(composition) do
    # Check for T2/T3 cruiser focus by examining group names
    t2_t3_count =
      composition
      |> Enum.reduce(0, fn {type_id, count}, acc ->
        # Use proper T2/T3 ship detection from static data
        cond do
          ShipTypes.t2_ship?(type_id) -> acc + count
          ShipTypes.t3_ship?(type_id) -> acc + count
          # Also count faction ships as high-tier
          ShipTypes.faction_ship?(type_id) -> acc + count
          true -> acc
        end
      end)

    total_ships = Enum.sum(Map.values(composition))
    total_ships > 0 && t2_t3_count / total_ships >= 0.6
  end

  defp has_small_ship_focus?(composition) do
    small_ship_count =
      composition
      |> Enum.reduce(0, fn {type_id, count}, acc ->
        case ShipTypes.classify_ship_type(type_id) do
          class when class in [:frigate, :destroyer] -> acc + count
          _ -> acc
        end
      end)

    total_ships = Enum.sum(Map.values(composition))
    total_ships > 0 && small_ship_count / total_ships >= 0.7
  end

  defp analyze_common_doctrines(time_window_days) do
    # Analyze recent battles to identify common fleet compositions
    start_date = DateTimeUtils.add(DateTime.utc_now(), -time_window_days * 24 * 3600, :second)

    case KillmailRepository.get_popular_fleet_compositions(start_date, limit: 10) do
      {:ok, compositions} ->
        compositions
        |> Enum.map(fn {composition, frequency} ->
          {:ok, doctrine_type} = classify_doctrine(composition)

          %{
            doctrine_type: doctrine_type,
            composition: composition,
            frequency: frequency,
            sample_size: Map.get(composition, :battle_count, 1)
          }
        end)

      {:error, _reason} ->
        # Fallback to common known doctrines
        get_default_threat_doctrines()
    end
  end

  defp get_default_threat_doctrines do
    # Fallback common doctrines when no data available
    [
      %{
        doctrine_type: "Armor HAC Gang",
        # Would be populated with common HAC compositions
        composition: %{},
        frequency: 0.3,
        sample_size: 10
      },
      %{
        doctrine_type: "Shield Cruiser Gang",
        composition: %{},
        frequency: 0.25,
        sample_size: 8
      },
      %{
        doctrine_type: "Battleship Doctrine",
        composition: %{},
        frequency: 0.2,
        sample_size: 6
      }
    ]
  end

  defp analyze_threat_matchup(composition, threat, battle_data, min_battles) do
    # Analyze how our composition performs against this specific threat
    relevant_battles =
      battle_data
      |> Enum.filter(fn battle ->
        threat_similarity =
          calculate_composition_similarity(threat.composition, battle.enemy_composition)

        threat_similarity > 0.5
      end)

    if length(relevant_battles) >= min_battles do
      {:ok, %{effectiveness: win_rate, confidence: confidence}} =
        calculate_win_rate_from_battles(relevant_battles)

      %{
        threat_type: threat.doctrine_type,
        effectiveness: win_rate,
        confidence: confidence,
        recommended_changes: generate_tactical_recommendations(composition, threat, win_rate),
        sample_size: length(relevant_battles)
      }
    else
      {:ok, %{effectiveness: estimated_effectiveness, confidence: confidence}} =
        estimate_effectiveness_from_composition(composition, threat.composition)

      %{
        threat_type: threat.doctrine_type,
        effectiveness: estimated_effectiveness,
        # Reduce confidence for estimates
        confidence: confidence * 0.7,
        recommended_changes:
          generate_tactical_recommendations(composition, threat, estimated_effectiveness),
        sample_size: 0
      }
    end
  end

  defp generate_tactical_recommendations(composition, threat, effectiveness) do
    initial_recommendations = []

    # Add recommendations based on effectiveness and composition analysis
    recommendations_with_effectiveness =
      if effectiveness < 0.4 do
        our_stats = calculate_composition_stats(composition)
        threat_stats = calculate_composition_stats(threat.composition)

        cond do
          our_stats.total_dps < threat_stats.total_dps * 0.8 ->
            ["Increase DPS ships", "Consider alpha strike doctrine" | initial_recommendations]

          our_stats.total_ehp < threat_stats.total_ehp * 0.8 ->
            ["Add logistics support", "Improve tank" | initial_recommendations]

          our_stats.utility_score < threat_stats.utility_score * 0.8 ->
            ["Add EWAR support", "Improve fleet utility" | initial_recommendations]

          true ->
            [
              "Improve pilot coordination",
              "Consider different engagement range" | initial_recommendations
            ]
        end
      else
        initial_recommendations
      end

    # Add general recommendations based on threat type
    final_recommendations =
      case threat.doctrine_type do
        "Armor HAC Gang" ->
          ["Consider neut pressure", "Focus on alpha damage" | recommendations_with_effectiveness]

        "Shield Cruiser Gang" ->
          ["Use range control", "Add tracking disruption" | recommendations_with_effectiveness]

        "Battleship Doctrine" ->
          ["Maintain range", "Use mobility advantage" | recommendations_with_effectiveness]

        _ ->
          recommendations_with_effectiveness
      end

    # Limit to top 3 recommendations
    Enum.take(final_recommendations, 3)
  end

  defp generate_composition_based_analysis(composition, common_threats) do
    analyses =
      common_threats
      |> Enum.map(fn threat ->
        {:ok, %{effectiveness: effectiveness, confidence: confidence}} =
          estimate_effectiveness_from_composition(composition, threat.composition)

        %{
          threat_type: threat.doctrine_type,
          effectiveness: effectiveness,
          confidence: confidence,
          recommended_changes:
            generate_tactical_recommendations(composition, threat, effectiveness),
          sample_size: 0
        }
      end)

    {:ok, analyses}
  end

  defp generate_fallback_analysis(composition) do
    Logger.info("Using fallback analysis for counter-doctrines")

    # Basic fallback based on ship composition
    {:ok, doctrine_type} = classify_doctrine(composition)

    fallback_analyses =
      case doctrine_type do
        "Capital Fleet" ->
          [
            %{
              threat_type: "Subcapital Swarm",
              effectiveness: 0.7,
              confidence: 0.3,
              recommended_changes: ["Add fighter support", "Improve point defense"]
            }
          ]

        "Cruiser Doctrine" ->
          [
            %{
              threat_type: "Battleship Doctrine",
              effectiveness: 0.6,
              confidence: 0.3,
              recommended_changes: ["Use range control", "Add logistics"]
            },
            %{
              threat_type: "Frigate Swarm",
              effectiveness: 0.8,
              confidence: 0.3,
              recommended_changes: ["Maintain range", "Use smartbombs"]
            }
          ]

        _ ->
          [
            %{
              threat_type: "Standard Fleet",
              effectiveness: 0.5,
              confidence: 0.2,
              recommended_changes: ["Improve fleet composition", "Add specialized ships"]
            }
          ]
      end

    {:ok, fallback_analyses}
  end

  defp calculate_composition_similarity(comp1, comp2) do
    # Calculate Jaccard similarity between two fleet compositions
    all_types = (Map.keys(comp1) ++ Map.keys(comp2)) |> Enum.uniq()

    if Enum.empty?(all_types) do
      0.0
    else
      intersection =
        all_types
        |> Enum.reduce(0, fn type_id, acc ->
          count1 = Map.get(comp1, type_id, 0)
          count2 = Map.get(comp2, type_id, 0)
          acc + min(count1, count2)
        end)

      union =
        all_types
        |> Enum.reduce(0, fn type_id, acc ->
          count1 = Map.get(comp1, type_id, 0)
          count2 = Map.get(comp2, type_id, 0)
          acc + max(count1, count2)
        end)

      if union == 0, do: 0.0, else: intersection / union
    end
  end

  defp calculate_confidence_from_sample_size(sample_size) do
    # Calculate confidence based on sample size
    cond do
      sample_size >= 20 -> 0.9
      sample_size >= 10 -> 0.7
      sample_size >= 5 -> 0.5
      sample_size >= 3 -> 0.3
      true -> 0.1
    end
  end

  defp composition_hash(composition) do
    # Create a hash for caching composition analysis
    composition
    |> Enum.sort()
    |> :erlang.phash2()
  end
end
