defmodule EveDmv.Analytics.CharacterComparisonService do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Service for comparing EVE Online characters based on their combat statistics,
  behavioral patterns, and tactical preferences.

  Provides:
  - Multi-character comparison across various metrics
  - Head-to-head character matchup analysis
  - Similar character discovery based on patterns
  - Combat style classification
  - Performance benchmarking

  All analysis is based on real killmail data from the database.
  """

  import Ecto.Query

  # alias EveDmv.Api
  alias EveDmv.Contexts.ThreatSurveillance.Domain.BehavioralPatternAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Shared.Infrastructure.UnifiedCache

  require Logger

  # 10 minutes
  @cache_ttl 600

  # Known column mappings for killmails_raw table to avoid atom table exhaustion
  # Only columns actually used by this module are mapped
  @killmail_columns %{
    "id" => :id,
    "killmail_id" => :killmail_id,
    "killmail_time" => :killmail_time,
    "solar_system_id" => :solar_system_id,
    "victim" => :victim,
    "victim_character_id" => :victim_character_id,
    "attackers" => :attackers,
    "zkb_total_value" => :zkb_total_value,
    "zkb_points" => :zkb_points,
    "raw_data" => :raw_data,
    "inserted_at" => :inserted_at,
    "updated_at" => :updated_at
  }

  @doc """
  Compare multiple characters across various metrics.

  ## Parameters
  - `character_ids` - List of character IDs to compare
  - `options` - Comparison options:
    - `:metrics` - List of specific metrics to compare (default: all)
    - `:timeframe` - Analysis timeframe in days (default: 90)

  ## Returns
  - `{:ok, comparison}` - Detailed comparison results
  - `{:error, reason}` - Error if comparison fails
  """
  def compare_characters(character_ids, options \\ []) when is_list(character_ids) do
    Logger.info("Comparing #{length(character_ids)} characters")

    timeframe = Keyword.get(options, :timeframe, 90)
    metrics = Keyword.get(options, :metrics, :all)

    cache_key = {:character_comparison, character_ids, timeframe, metrics}

    case UnifiedCache.get(:combat, cache_key) do
      {:ok, cached_comparison} ->
        {:ok, cached_comparison}

      {:error, :not_found} ->
        with {:ok, character_data} <- fetch_character_data(character_ids, timeframe),
             {:ok, comparison} <- perform_comparison(character_data, metrics) do
          UnifiedCache.put(:combat, cache_key, comparison, @cache_ttl)
          {:ok, comparison}
        end
    end
  end

  @doc """
  Perform head-to-head comparison between two characters.

  ## Parameters
  - `char1_id` - First character ID
  - `char2_id` - Second character ID
  - `options` - Comparison options

  ## Returns
  - `{:ok, matchup_analysis}` - Detailed matchup analysis
  - `{:error, reason}` - Error if comparison fails
  """
  def head_to_head_comparison(char1_id, char2_id, options \\ []) do
    Logger.info("Head-to-head comparison: #{char1_id} vs #{char2_id}")

    timeframe = Keyword.get(options, :timeframe, 90)
    end_time = DateTime.utc_now()
    start_time = DateTimeUtils.add(end_time, -timeframe * 24 * 60 * 60, :second)

    with {:ok, char1_data} <- fetch_detailed_character_data(char1_id, options),
         {:ok, char2_data} <- fetch_detailed_character_data(char2_id, options),
         {:ok, encounters} <- fetch_mutual_encounters(char1_id, char2_id, start_time, end_time) do
      analysis = %{
        character_1: summarize_character(char1_data),
        character_2: summarize_character(char2_data),
        direct_encounters: analyze_encounters(encounters, char1_id, char2_id),
        predicted_matchup: predict_matchup(char1_data, char2_data),
        tactical_advantages: identify_tactical_advantages(char1_data, char2_data),
        historical_performance: compare_historical_performance(char1_data, char2_data)
      }

      {:ok, analysis}
    end
  end

  @doc """
  Find characters similar to a given character based on combat patterns.

  ## Parameters
  - `character_id` - Reference character ID
  - `limit` - Maximum number of similar characters to return
  - `options` - Search options

  ## Returns
  - `{:ok, similar_characters}` - List of similar characters with similarity scores
  - `{:error, reason}` - Error if search fails
  """
  def find_similar_characters(character_id, limit \\ 10, options \\ []) do
    Logger.info("Finding characters similar to #{character_id}")

    with {:ok, reference_profile} <- build_character_profile(character_id, options),
         {:ok, candidates} <- find_candidate_characters(reference_profile, options),
         {:ok, similarities} <- calculate_similarities(reference_profile, candidates) do
      similar_chars =
        similarities
        |> Enum.sort_by(& &1.similarity_score, :desc)
        |> Enum.take(limit)

      {:ok, similar_chars}
    end
  end

  # Private implementation functions

  defp fetch_character_data(character_ids, timeframe) do
    since = DateTimeUtils.add(DateTime.utc_now(), -timeframe * 24 * 60 * 60, :second)

    # Fetch stats from materialized view
    stats_query =
      from(cs in CharacterStats,
        where: cs.character_id in ^character_ids
      )

    stats =
      case EveDmv.Repo.all(stats_query) do
        results when is_list(results) ->
          Map.new(results, &{&1.character_id, &1})

        _ ->
          %{}
      end

    # Fetch recent killmails for each character
    killmail_data =
      Enum.reduce(character_ids, %{}, fn char_id, acc ->
        killmails = fetch_character_killmails(char_id, since)
        Map.put(acc, char_id, killmails)
      end)

    # Fetch behavioral patterns
    behavioral_data =
      Enum.reduce(character_ids, %{}, fn char_id, acc ->
        case BehavioralPatternAnalyzer.analyze_patterns(char_id, :character, timeframe: timeframe) do
          {:ok, patterns} -> Map.put(acc, char_id, patterns)
          {:error, _} -> Map.put(acc, char_id, %{})
        end
      end)

    character_data =
      Enum.map(character_ids, fn char_id ->
        %{
          character_id: char_id,
          stats: Map.get(stats, char_id, %{}),
          killmails: Map.get(killmail_data, char_id, []),
          behavioral_patterns: Map.get(behavioral_data, char_id, %{})
        }
      end)

    {:ok, character_data}
  end

  defp fetch_character_killmails(character_id, since) do
    query =
      from(k in KillmailRaw,
        where: fragment("?->>'character_id' = ?", k.victim, ^to_string(character_id)),
        where: k.killmail_time > ^since,
        order_by: [desc: k.killmail_time],
        limit: 500
      )

    EveDmv.Repo.all(query)
  end

  defp perform_comparison(character_data, metrics) do
    comparison_metrics =
      if metrics == :all do
        [
          :combat_efficiency,
          :ship_preferences,
          :engagement_patterns,
          :timezone_activity,
          :risk_profile,
          :tactical_preferences
        ]
      else
        metrics
      end

    base_comparison = %{
      characters: Enum.map(character_data, &extract_character_summary/1),
      metrics: %{},
      rankings: %{},
      insights: []
    }

    # Calculate each metric and generate insights
    final_comparison =
      comparison_metrics
      |> Enum.reduce(base_comparison, fn metric, acc ->
        metric_data = calculate_metric(metric, character_data)

        acc
        |> put_in([:metrics, metric], metric_data)
        |> update_in([:rankings], &Map.put(&1, metric, rank_characters(metric_data)))
      end)
      |> then(&Map.put(&1, :insights, generate_comparison_insights(&1)))

    {:ok, final_comparison}
  end

  defp extract_character_summary(char_data) do
    stats = char_data.stats

    %{
      character_id: char_data.character_id,
      total_kills: Map.get(stats, :total_kills, 0),
      total_losses: Map.get(stats, :total_losses, 0),
      kill_death_ratio: calculate_kdr(stats),
      isk_efficiency: Map.get(stats, :isk_efficiency, 0),
      danger_rating: Map.get(stats, :danger_rating, 0),
      last_seen: Map.get(stats, :last_seen),
      data_points: length(char_data.killmails)
    }
  end

  defp calculate_kdr(%{total_kills: kills, total_losses: losses}) when losses > 0 do
    Float.round(kills / losses, 2)
  end

  defp calculate_kdr(%{total_kills: kills}) when kills > 0, do: kills
  defp calculate_kdr(_), do: 0.0

  defp calculate_metric(:combat_efficiency, character_data) do
    Enum.map(character_data, fn char ->
      stats = char.stats
      killmails = char.killmails

      %{
        character_id: char.character_id,
        kill_death_ratio: calculate_kdr(stats),
        isk_efficiency: Map.get(stats, :isk_efficiency, 0),
        average_damage_per_kill: calculate_average_damage(killmails),
        solo_efficiency: calculate_solo_efficiency(killmails),
        small_gang_efficiency: calculate_gang_efficiency(killmails, 2..5),
        fleet_efficiency: calculate_gang_efficiency(killmails, 6..100)
      }
    end)
  end

  defp calculate_metric(:ship_preferences, character_data) do
    Enum.map(character_data, fn char ->
      ship_usage = analyze_ship_usage(char.killmails)

      %{
        character_id: char.character_id,
        preferred_ships: Enum.take(ship_usage.top_ships, 5),
        ship_diversity: ship_usage.diversity_index,
        preferred_ship_classes: ship_usage.class_distribution,
        average_ship_value: ship_usage.average_value
      }
    end)
  end

  defp calculate_metric(:engagement_patterns, character_data) do
    Enum.map(character_data, fn char ->
      patterns = char.behavioral_patterns

      %{
        character_id: char.character_id,
        solo_percentage: get_in(patterns, [:engagement_patterns, :solo_percentage]) || 0,
        small_gang_percentage:
          get_in(patterns, [:engagement_patterns, :small_gang_percentage]) || 0,
        fleet_percentage: get_in(patterns, [:engagement_patterns, :fleet_percentage]) || 0,
        average_gang_size: get_in(patterns, [:engagement_patterns, :average_gang_size]) || 0,
        preferred_engagement_size: determine_preferred_size(patterns)
      }
    end)
  end

  defp calculate_metric(:timezone_activity, character_data) do
    Enum.map(character_data, fn char ->
      patterns = char.behavioral_patterns

      %{
        character_id: char.character_id,
        peak_hours: get_in(patterns, [:activity_patterns, :peak_hours]) || [],
        estimated_timezone:
          get_in(patterns, [:activity_patterns, :estimated_timezone]) || "Unknown",
        activity_concentration:
          get_in(patterns, [:activity_patterns, :activity_concentration]) || 0
      }
    end)
  end

  defp calculate_metric(:risk_profile, character_data) do
    Enum.map(character_data, fn char ->
      %{
        character_id: char.character_id,
        average_loss_value: calculate_average_loss_value(char.killmails),
        high_value_losses: count_high_value_losses(char.killmails),
        security_preference: analyze_security_preference(char.killmails),
        risk_tolerance_score: calculate_risk_tolerance(char)
      }
    end)
  end

  defp calculate_metric(:tactical_preferences, character_data) do
    Enum.map(character_data, fn char ->
      %{
        character_id: char.character_id,
        preferred_targets: analyze_target_preferences(char.killmails),
        engagement_range: estimate_engagement_range(char.killmails),
        tactical_role: classify_tactical_role(char),
        specialized_tactics: identify_specialized_tactics(char.killmails)
      }
    end)
  end

  defp rank_characters(metric_data) do
    # Rank characters based on the primary value in each metric
    metric_data
    |> Enum.map(fn data ->
      score = calculate_metric_score(data)
      {data.character_id, score}
    end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.with_index(1)
    |> Enum.map(fn {{char_id, score}, rank} ->
      %{character_id: char_id, rank: rank, score: score}
    end)
  end

  defp calculate_metric_score(data) do
    # Calculate a composite score based on the metric data
    cond do
      Map.has_key?(data, :kill_death_ratio) ->
        # Combat efficiency score
        kdr_score = min(data.kill_death_ratio * 20, 100)
        isk_score = min(data.isk_efficiency, 100)
        (kdr_score + isk_score) / 2

      Map.has_key?(data, :ship_diversity) ->
        # Ship preference score based on diversity
        data.ship_diversity * 100

      Map.has_key?(data, :solo_percentage) ->
        # Engagement pattern score - reward balanced approach
        balance =
          100 - abs(33.3 - data.solo_percentage) -
            abs(33.3 - data.small_gang_percentage) -
            abs(33.3 - data.fleet_percentage)

        max(balance, 0)

      Map.has_key?(data, :risk_tolerance_score) ->
        data.risk_tolerance_score

      true ->
        50.0
    end
  end

  defp generate_comparison_insights(comparison) do
    []
    |> Kernel.++(identify_standout_performers(comparison))
    |> Kernel.++(identify_similar_playstyles(comparison))
    |> Kernel.++(identify_contrasts(comparison))
  end

  defp identify_standout_performers(comparison) do
    comparison.rankings
    |> Enum.flat_map(fn {metric, rankings} ->
      case List.first(rankings) do
        %{character_id: char_id, score: score} when score > 80 ->
          [
            %{
              type: :standout_performer,
              character_id: char_id,
              metric: metric,
              description: "Top performer in #{format_metric_name(metric)}"
            }
          ]

        _ ->
          []
      end
    end)
  end

  defp identify_similar_playstyles(comparison) do
    # Compare engagement patterns to find similar playstyles
    case comparison.metrics[:engagement_patterns] do
      patterns when is_list(patterns) and length(patterns) > 1 ->
        find_similar_patterns(patterns)

      _ ->
        []
    end
  end

  defp find_similar_patterns(patterns) do
    # Find pairs with similar engagement preferences
    for p1 <- patterns,
        p2 <- patterns,
        p1.character_id < p2.character_id,
        similar_engagement_style?(p1, p2) do
      %{
        type: :similar_playstyle,
        characters: [p1.character_id, p2.character_id],
        description: "Similar #{p1.preferred_engagement_size} preference"
      }
    end
  end

  defp similar_engagement_style?(p1, p2) do
    p1.preferred_engagement_size == p2.preferred_engagement_size &&
      abs(p1.average_gang_size - p2.average_gang_size) < 2
  end

  defp identify_contrasts(_comparison) do
    # Find interesting contrasts between characters
    []
  end

  defp format_metric_name(metric) do
    metric
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  # Helper functions for metric calculations

  defp calculate_average_damage(killmails) do
    damages =
      killmails
      |> Enum.map(&(get_in(&1.raw_data, ["victim", "damage_taken"]) || 0))
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(damages) do
      0
    else
      round(Enum.sum(damages) / length(damages))
    end
  end

  defp calculate_solo_efficiency(killmails) do
    solo_kills = Enum.filter(killmails, &(length(&1.attackers) == 1))

    if Enum.empty?(solo_kills) do
      0.0
    else
      # Efficiency based on ISK destroyed vs average
      total_value = Enum.sum(Enum.map(solo_kills, &(&1.zkb_total_value || 0)))
      avg_value = total_value / length(solo_kills)

      # Normalize to 0-100 scale
      min(avg_value / 1_000_000, 100)
    end
  end

  defp calculate_gang_efficiency(killmails, gang_size_range) do
    gang_kills =
      Enum.filter(killmails, fn km ->
        attacker_count = length(km.attackers)
        attacker_count in gang_size_range
      end)

    if Enum.empty?(gang_kills) do
      0.0
    else
      # Similar efficiency calculation
      total_value = Enum.sum(Enum.map(gang_kills, &(&1.zkb_total_value || 0)))
      avg_value = total_value / length(gang_kills)

      min(avg_value / 1_000_000, 100)
    end
  end

  defp analyze_ship_usage(killmails) do
    ship_counts =
      killmails
      |> Enum.map(&get_in(&1.victim, ["ship_type_id"]))
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    total_losses = length(killmails)

    top_ships =
      ship_counts
      |> Enum.sort_by(&elem(&1, 1), :desc)
      |> Enum.map(fn {ship_id, count} ->
        %{
          ship_type_id: ship_id,
          usage_count: count,
          percentage: Float.round(count / total_losses * 100, 1)
        }
      end)

    %{
      top_ships: top_ships,
      diversity_index: calculate_diversity_index(ship_counts, total_losses),
      # Would need ship class mapping
      class_distribution: %{},
      average_value: calculate_average_ship_value(killmails)
    }
  end

  defp calculate_diversity_index(item_counts, total) do
    if total == 0 do
      0.0
    else
      # Shannon diversity index
      item_counts
      |> Map.values()
      |> Enum.reduce(0.0, fn count, acc ->
        proportion = count / total

        if proportion > 0 do
          acc - proportion * :math.log(proportion)
        else
          acc
        end
      end)
      |> Float.round(3)
    end
  end

  defp calculate_average_ship_value(killmails) do
    values =
      killmails
      |> Enum.map(&(&1.zkb_total_value || 0))
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(values) do
      0
    else
      round(Enum.sum(values) / length(values))
    end
  end

  defp determine_preferred_size(patterns) do
    engagement = Map.get(patterns, :engagement_patterns, %{})

    cond do
      Map.get(engagement, :solo_percentage, 0) > 50 -> :solo
      Map.get(engagement, :small_gang_percentage, 0) > 50 -> :small_gang
      Map.get(engagement, :fleet_percentage, 0) > 50 -> :fleet
      true -> :mixed
    end
  end

  defp calculate_average_loss_value(killmails) do
    calculate_average_ship_value(killmails)
  end

  defp count_high_value_losses(killmails) do
    # 500M ISK
    threshold = 500_000_000

    killmails
    |> Enum.count(fn km ->
      (km.zkb_total_value || 0) > threshold
    end)
  end

  defp analyze_security_preference(_killmails) do
    # Would need system security data
    %{
      highsec: 0,
      lowsec: 0,
      nullsec: 100,
      wormhole: 0
    }
  end

  defp calculate_risk_tolerance(char_data) do
    stats = char_data.stats
    avg_loss = calculate_average_loss_value(char_data.killmails)

    # Higher average loss value = higher risk tolerance
    risk_score = min(avg_loss / 10_000_000, 100)

    # Adjust based on K/D ratio - lower K/D with high losses = very high risk
    kdr = calculate_kdr(stats)

    if kdr < 1.0 and risk_score > 50 do
      min(risk_score * 1.2, 100)
    else
      risk_score
    end
  end

  defp analyze_target_preferences(_killmails) do
    # Would analyze what ship types this character typically engages
    [:cruisers, :frigates]
  end

  defp estimate_engagement_range(_killmails) do
    # Would analyze weapon types to estimate preferred range
    :medium_range
  end

  defp classify_tactical_role(char_data) do
    patterns = char_data.behavioral_patterns

    cond do
      get_in(patterns, [:engagement_patterns, :solo_percentage]) > 70 -> :solo_hunter
      get_in(patterns, [:ship_patterns, :ship_classes, "Logistics"]) > 0 -> :support
      true -> :damage_dealer
    end
  end

  defp identify_specialized_tactics(_killmails) do
    # Would identify special tactics like hot dropping, gate camping, etc
    []
  end

  # Head-to-head comparison functions

  defp fetch_detailed_character_data(character_id, options) do
    timeframe = Keyword.get(options, :timeframe, 90)

    with {:ok, [char_data]} <- fetch_character_data([character_id], timeframe) do
      {:ok, char_data}
    end
  end

  defp fetch_mutual_encounters(char1_id, char2_id, start_time, end_time) do
    # Optimized: Uses participants table instead of JSONB extraction
    # Find killmails where these characters fought each other
    # (char1 killed char2 OR char2 killed char1)
    # Time filter on killmail_time enables partition pruning on both killmails_raw and participants
    query = """
    SELECT k.*
    FROM killmails_raw k
    WHERE k.killmail_time BETWEEN $3 AND $4
      AND (
        (
          -- Char1 was victim, Char2 was attacker
          k.victim_character_id = $1
          AND EXISTS (
            SELECT 1 FROM participants p
            WHERE p.killmail_id = k.killmail_id
              AND p.killmail_time = k.killmail_time
              AND p.killmail_time BETWEEN $3 AND $4
              AND p.character_id = $2
              AND p.is_victim = false
          )
        ) OR (
          -- Char2 was victim, Char1 was attacker
          k.victim_character_id = $2
          AND EXISTS (
            SELECT 1 FROM participants p
            WHERE p.killmail_id = k.killmail_id
              AND p.killmail_time = k.killmail_time
              AND p.killmail_time BETWEEN $3 AND $4
              AND p.character_id = $1
              AND p.is_victim = false
          )
        )
      )
    ORDER BY k.killmail_time DESC
    LIMIT 50
    """

    case EveDmv.Repo.query(query, [char1_id, char2_id, start_time, end_time]) do
      {:ok, %{rows: rows, columns: columns}} ->
        encounters =
          Enum.map(rows, fn row ->
            Enum.zip(columns, row) |> Map.new() |> atomize_keys()
          end)

        {:ok, encounters}

      {:error, reason} = error ->
        Logger.error(
          "Failed to fetch mutual encounters for #{char1_id} vs #{char2_id}: #{inspect(reason)}"
        )

        error
    end
  end

  defp atomize_keys(map) do
    # Log any unknown columns for debugging (schema drift detection)
    unknown_columns =
      map
      |> Map.keys()
      |> Enum.reject(&Map.has_key?(@killmail_columns, &1))

    if unknown_columns != [] do
      Logger.warning(
        "atomize_keys encountered unknown column(s): #{inspect(unknown_columns)}. " <>
          "Add these to @killmail_columns if they should be included."
      )
    end

    # Only include known columns to prevent atom table exhaustion
    map
    |> Enum.filter(fn {k, _v} -> Map.has_key?(@killmail_columns, k) end)
    |> Map.new(fn {k, v} -> {Map.fetch!(@killmail_columns, k), v} end)
  end

  defp summarize_character(char_data) do
    _stats = char_data.stats

    %{
      character_id: char_data.character_id,
      combat_rating: calculate_combat_rating(char_data),
      preferred_ships: get_top_ships(char_data.killmails, 3),
      combat_style: classify_combat_style(char_data),
      strengths: identify_strengths(char_data),
      weaknesses: identify_weaknesses(char_data)
    }
  end

  defp calculate_combat_rating(char_data) do
    stats = char_data.stats

    kdr_score = min(calculate_kdr(stats) * 20, 40)
    isk_score = min(Map.get(stats, :isk_efficiency, 0) / 2, 40)
    danger_score = min(Map.get(stats, :danger_rating, 0) / 5, 20)

    round(kdr_score + isk_score + danger_score)
  end

  defp get_top_ships(killmails, limit) do
    killmails
    |> Enum.map(&get_in(&1.victim, ["ship_type_id"]))
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(limit)
    |> Enum.map(&elem(&1, 0))
  end

  defp classify_combat_style(char_data) do
    patterns = char_data.behavioral_patterns

    %{
      primary_style: determine_primary_style(patterns),
      aggression_level: calculate_aggression_level(char_data),
      flexibility_rating: calculate_flexibility_rating(char_data)
    }
  end

  defp determine_primary_style(patterns) do
    engagement = Map.get(patterns, :engagement_patterns, %{})

    cond do
      Map.get(engagement, :solo_percentage, 0) > 60 -> :solo_specialist
      Map.get(engagement, :small_gang_percentage, 0) > 60 -> :small_gang_expert
      Map.get(engagement, :fleet_percentage, 0) > 60 -> :fleet_warrior
      true -> :versatile
    end
  end

  defp calculate_aggression_level(char_data) do
    stats = char_data.stats
    kdr = calculate_kdr(stats)

    cond do
      kdr > 3.0 -> :very_aggressive
      kdr > 1.5 -> :aggressive
      kdr > 0.8 -> :balanced
      true -> :cautious
    end
  end

  defp calculate_flexibility_rating(char_data) do
    ship_diversity =
      length(Enum.uniq(Enum.map(char_data.killmails, &get_in(&1.victim, ["ship_type_id"]))))

    cond do
      ship_diversity > 20 -> :highly_flexible
      ship_diversity > 10 -> :flexible
      ship_diversity > 5 -> :moderate
      true -> :specialized
    end
  end

  defp identify_strengths(char_data) do
    stats = char_data.stats
    patterns = char_data.behavioral_patterns

    []
    |> then(fn acc ->
      if calculate_kdr(stats) > 2.0, do: [:high_kill_ratio | acc], else: acc
    end)
    |> then(fn acc ->
      if Map.get(stats, :isk_efficiency, 0) > 70,
        do: [:isk_efficient | acc],
        else: acc
    end)
    |> then(fn acc ->
      if get_in(patterns, [:engagement_patterns, :solo_percentage]) > 50,
        do: [:solo_capable | acc],
        else: acc
    end)
  end

  defp identify_weaknesses(char_data) do
    stats = char_data.stats

    []
    |> then(fn acc ->
      if calculate_kdr(stats) < 1.0, do: [:low_survival_rate | acc], else: acc
    end)
    |> then(fn acc ->
      if Map.get(stats, :isk_efficiency, 0) < 40,
        do: [:isk_inefficient | acc],
        else: acc
    end)
  end

  defp analyze_encounters(encounters, _char1_id, char2_id) do
    char1_wins =
      Enum.count(encounters, fn km ->
        get_in(km.victim, ["character_id"]) == char2_id
      end)

    char2_wins = length(encounters) - char1_wins

    encounter_count = length(encounters)

    %{
      total_encounters: encounter_count,
      character_1_wins: char1_wins,
      character_2_wins: char2_wins,
      win_rate:
        if(encounter_count > 0,
          do: Float.round(char1_wins / encounter_count * 100, 1),
          else: 0
        ),
      recent_encounters: Enum.take(encounters, 5) |> Enum.map(&summarize_encounter/1)
    }
  end

  defp summarize_encounter(killmail) do
    %{
      killmail_id: killmail.id,
      timestamp: killmail.killmail_time,
      victim_id: get_in(killmail.victim, ["character_id"]),
      victim_ship: get_in(killmail.victim, ["ship_type_id"]),
      value: killmail.zkb_total_value || 0
    }
  end

  defp predict_matchup(char1_data, char2_data) do
    char1_rating = calculate_combat_rating(char1_data)
    char2_rating = calculate_combat_rating(char2_data)

    rating_diff = char1_rating - char2_rating

    prediction =
      cond do
        rating_diff > 20 -> :character_1_favored
        rating_diff < -20 -> :character_2_favored
        true -> :even_match
      end

    %{
      prediction: prediction,
      confidence: calculate_prediction_confidence(rating_diff),
      character_1_win_probability: calculate_win_probability(rating_diff),
      factors: identify_key_factors(char1_data, char2_data)
    }
  end

  defp calculate_prediction_confidence(rating_diff) do
    # Higher difference = higher confidence
    abs_diff = abs(rating_diff)

    cond do
      abs_diff > 30 -> :high
      abs_diff > 15 -> :medium
      true -> :low
    end
  end

  defp calculate_win_probability(rating_diff) do
    # Simple logistic function
    probability = 1 / (1 + :math.exp(-rating_diff / 10))
    Float.round(probability * 100, 1)
  end

  defp identify_key_factors(char1_data, char2_data) do
    # Compare key metrics
    char1_kdr = calculate_kdr(char1_data.stats)
    char2_kdr = calculate_kdr(char2_data.stats)

    []
    |> then(fn acc ->
      if abs(char1_kdr - char2_kdr) > 1.0 do
        [{:kill_death_ratio, "Significant K/D ratio difference"} | acc]
      else
        acc
      end
    end)
  end

  defp identify_tactical_advantages(char1_data, char2_data) do
    %{
      character_1_advantages: find_advantages(char1_data, char2_data),
      character_2_advantages: find_advantages(char2_data, char1_data)
    }
  end

  defp find_advantages(char_data, opponent_data) do
    # Check engagement style advantage
    char_style = determine_preferred_size(char_data.behavioral_patterns)
    opp_style = determine_preferred_size(opponent_data.behavioral_patterns)

    []
    |> then(fn acc ->
      if char_style == :solo and opp_style == :fleet do
        ["More experienced in small-scale combat" | acc]
      else
        acc
      end
    end)
  end

  defp compare_historical_performance(char1_data, char2_data) do
    %{
      character_1: %{
        recent_performance: analyze_recent_performance(char1_data),
        trend: calculate_performance_trend(char1_data)
      },
      character_2: %{
        recent_performance: analyze_recent_performance(char2_data),
        trend: calculate_performance_trend(char2_data)
      }
    }
  end

  defp analyze_recent_performance(char_data) do
    recent_kills = Enum.take(char_data.killmails, 20)

    %{
      kills_analyzed: length(recent_kills),
      average_value: calculate_average_ship_value(recent_kills),
      survival_rate: calculate_recent_survival_rate(recent_kills)
    }
  end

  defp calculate_recent_survival_rate(_killmails) do
    # Would need to analyze both kills and losses
    50.0
  end

  defp calculate_performance_trend(_char_data) do
    # Would analyze performance over time
    :stable
  end

  # Similar character finding functions

  defp build_character_profile(character_id, options) do
    timeframe = Keyword.get(options, :timeframe, 90)

    with {:ok, [char_data]} <- fetch_character_data([character_id], timeframe),
         {:ok, patterns} <-
           BehavioralPatternAnalyzer.analyze_patterns(
             character_id,
             :character,
             timeframe: timeframe
           ) do
      profile = %{
        character_id: character_id,
        combat_metrics: extract_combat_metrics(char_data),
        ship_preferences: extract_ship_preferences(char_data),
        behavioral_patterns: patterns,
        activity_profile: extract_activity_profile(char_data)
      }

      {:ok, profile}
    end
  end

  @dialyzer {:nowarn_function, extract_combat_metrics: 1}
  defp extract_combat_metrics(char_data) do
    stats = char_data.stats

    %{
      kill_death_ratio: calculate_kdr(stats),
      isk_efficiency: Map.get(stats, :isk_efficiency, 0),
      danger_rating: Map.get(stats, :danger_rating, 0),
      total_engagements: Map.get(stats, :total_kills, 0) + Map.get(stats, :total_losses, 0)
    }
  end

  @dialyzer {:nowarn_function, extract_ship_preferences: 1}
  defp extract_ship_preferences(char_data) do
    ship_usage = analyze_ship_usage(char_data.killmails)

    %{
      favorite_ships: Enum.take(ship_usage.top_ships, 10),
      ship_diversity: ship_usage.diversity_index,
      average_ship_value: ship_usage.average_value
    }
  end

  @dialyzer {:nowarn_function, extract_activity_profile: 1}
  defp extract_activity_profile(char_data) do
    patterns = char_data.behavioral_patterns

    %{
      timezone: get_in(patterns, [:activity_patterns, :estimated_timezone]),
      peak_hours: get_in(patterns, [:activity_patterns, :peak_hours]) || [],
      preferred_systems: get_in(patterns, [:system_patterns, :top_systems]) || []
    }
  end

  defp find_candidate_characters(reference_profile, options) do
    limit = Keyword.get(options, :candidate_limit, 100)

    # Find characters with similar activity levels
    min_engagements = reference_profile.combat_metrics.total_engagements * 0.5
    max_engagements = reference_profile.combat_metrics.total_engagements * 2.0

    query =
      from(cs in CharacterStats,
        where: cs.total_kills + cs.total_losses >= ^min_engagements,
        where: cs.total_kills + cs.total_losses <= ^max_engagements,
        where: cs.character_id != ^reference_profile.character_id,
        order_by: [desc: cs.danger_rating],
        limit: ^limit
      )

    candidates = EveDmv.Repo.all(query)

    # Build basic profiles for candidates
    candidate_profiles =
      Enum.map(candidates, fn stats ->
        %{
          character_id: stats.character_id,
          combat_metrics: %{
            kill_death_ratio:
              if(stats.total_losses > 0,
                do: stats.total_kills / stats.total_losses,
                else: stats.total_kills
              ),
            isk_efficiency: stats.isk_efficiency || 0,
            danger_rating: stats.danger_rating || 0,
            total_engagements: stats.total_kills + stats.total_losses
          }
        }
      end)

    {:ok, candidate_profiles}
  end

  defp calculate_similarities(reference_profile, candidates) do
    similarities =
      Enum.map(candidates, fn candidate ->
        similarity_score = calculate_similarity_score(reference_profile, candidate)

        %{
          character_id: candidate.character_id,
          similarity_score: similarity_score,
          matching_aspects: identify_matching_aspects(reference_profile, candidate)
        }
      end)

    {:ok, similarities}
  end

  defp calculate_similarity_score(ref_profile, candidate) do
    # Compare combat metrics
    combat_similarity =
      calculate_combat_similarity(
        ref_profile.combat_metrics,
        candidate.combat_metrics
      )

    # Weight the similarity score
    combat_similarity * 100
  end

  defp calculate_combat_similarity(ref_metrics, cand_metrics) do
    # Calculate normalized differences for each metric
    kdr_diff =
      normalized_difference(ref_metrics.kill_death_ratio, cand_metrics.kill_death_ratio, 5.0)

    eff_diff =
      normalized_difference(ref_metrics.isk_efficiency, cand_metrics.isk_efficiency, 100.0)

    danger_diff =
      normalized_difference(ref_metrics.danger_rating, cand_metrics.danger_rating, 100.0)

    # Average similarity (1 - average difference)
    avg_diff = (kdr_diff + eff_diff + danger_diff) / 3
    1 - avg_diff
  end

  defp normalized_difference(val1, val2, max_expected_diff) do
    diff = abs(val1 - val2)
    min(diff / max_expected_diff, 1.0)
  end

  defp identify_matching_aspects(ref_profile, candidate) do
    # Check similar K/D ratio
    ref_kdr = ref_profile.combat_metrics.kill_death_ratio
    cand_kdr = candidate.combat_metrics.kill_death_ratio

    # Check similar danger rating
    ref_danger = ref_profile.combat_metrics.danger_rating
    cand_danger = candidate.combat_metrics.danger_rating

    []
    |> then(fn acc ->
      if abs(ref_kdr - cand_kdr) < 0.5 do
        [:similar_combat_effectiveness | acc]
      else
        acc
      end
    end)
    |> then(fn acc ->
      if abs(ref_danger - cand_danger) < 10 do
        [:similar_threat_level | acc]
      else
        acc
      end
    end)
  end
end
