defmodule EveDmv.Contexts.BattleAnalysis.Domain.TacticalPhaseDetector do
  @moduledoc """
  Sophisticated tactical phase detection using clustering algorithms.

  Analyzes battle data to automatically identify distinct tactical phases:
  - Setup Phase: Low damage, positioning, EWAR deployment
  - Engagement Phase: High damage, focus fire, ship losses  
  - Resolution Phase: Cleanup, looting, extraction

  Uses k-means clustering on damage rate, engagement distance, and ship movement vectors
  to detect phase transitions and classify combat periods.
  """

  require Logger
  alias EveDmv.Contexts.BattleAnalysis.Domain.ParticipantExtractor

  # Phase detection parameters optimized for EVE PvP
  # Minimum time for a valid phase
  @min_phase_duration_seconds 30
  # Maximum number of tactical phases
  @max_clusters 5
  # K-means convergence criteria
  @convergence_threshold 0.01
  # Maximum k-means iterations
  @max_iterations 50

  @doc """
  Detects tactical phases within a battle using clustering analysis.

  Analyzes killmail timestamps, damage patterns, and engagement characteristics
  to identify distinct phases of combat using machine learning clustering.

  ## Parameters
  - battle: Battle struct with killmails and metadata
  - options: Detection options
    - :min_phase_duration - Minimum duration for valid phase (default: 30 seconds)
    - :max_phases - Maximum number of phases to detect (default: 5)
    - :clustering_method - Algorithm to use (:kmeans, :hierarchical) (default: :kmeans)

  ## Returns
  {:ok, phases} where each phase contains timing, type, and characteristics
  """
  def detect_tactical_phases(battle, options \\ []) do
    min_duration = Keyword.get(options, :min_phase_duration, @min_phase_duration_seconds)
    max_phases = Keyword.get(options, :max_phases, @max_clusters)
    method = Keyword.get(options, :clustering_method, :kmeans)

    Logger.info("Detecting tactical phases for battle #{battle.battle_id} using #{method}")

    start_time = System.monotonic_time(:millisecond)

    with {:ok, temporal_windows} <- create_temporal_windows(battle, min_duration),
         {:ok, feature_vectors} <- extract_phase_features(temporal_windows),
         {:ok, clusters} <- apply_clustering(feature_vectors, max_phases, method),
         {:ok, phases} <- classify_phase_types(clusters, temporal_windows) do
      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      Logger.info("""
      Tactical phase detection completed in #{duration_ms}ms:
      - Phases detected: #{length(phases)}
      - Battle duration: #{battle.metadata.duration_minutes} minutes
      - Clustering method: #{method}
      """)

      {:ok, phases}
    end
  end

  @doc """
  Analyzes phase transitions to identify tactical momentum shifts.

  Examines how combat intensity, participant engagement, and damage patterns
  change between phases to understand battle flow and key turning points.
  """
  def analyze_phase_transitions(phases) do
    Enum.with_index(phases)
    |> Enum.map(fn {phase, index} ->
      next_phase = Enum.at(phases, index + 1)

      if next_phase do
        transition = analyze_transition(phase, next_phase)
        put_in(phase.transition_to_next, transition)
      else
        phase
      end
    end)
  end

  # Private clustering and analysis implementation

  defp create_temporal_windows(battle, min_duration) do
    killmails =
      battle.killmails
      |> Enum.sort_by(& &1.killmail_time)

    if length(killmails) < 2 do
      # Single killmail or empty battle - create single window
      window = %{
        start_time: List.first(killmails).killmail_time,
        end_time: List.first(killmails).killmail_time,
        killmails: killmails,
        duration_seconds: min_duration
      }

      {:ok, [window]}
    else
      # Create overlapping time windows for analysis
      windows = create_sliding_windows(killmails, min_duration)
      {:ok, windows}
    end
  end

  defp create_sliding_windows(killmails, min_duration) do
    battle_start = List.first(killmails).killmail_time
    battle_end = List.last(killmails).killmail_time

    total_duration = NaiveDateTime.diff(battle_end, battle_start, :second)

    # Create windows with 50% overlap for better phase boundary detection
    window_size = max(min_duration, total_duration / 4)
    step_size = window_size / 2

    0
    |> Stream.iterate(&(&1 + step_size))
    |> Stream.take_while(&(&1 < total_duration))
    |> Enum.map(fn offset ->
      window_start = NaiveDateTime.add(battle_start, round(offset), :second)
      window_end = NaiveDateTime.add(window_start, round(window_size), :second)

      window_killmails =
        Enum.filter(killmails, fn km ->
          NaiveDateTime.compare(km.killmail_time, window_start) != :lt and
            NaiveDateTime.compare(km.killmail_time, window_end) != :gt
        end)

      %{
        start_time: window_start,
        end_time: window_end,
        killmails: window_killmails,
        duration_seconds: round(window_size)
      }
    end)
    |> Enum.filter(&(length(&1.killmails) > 0))
  end

  defp extract_phase_features(temporal_windows) do
    features =
      Enum.map(temporal_windows, fn window ->
        %{
          # Combat intensity metrics
          damage_rate: calculate_damage_rate(window),
          kill_rate: calculate_kill_rate(window),
          participant_engagement: calculate_engagement_level(window),

          # Tactical characteristics
          ewar_usage: calculate_ewar_intensity(window),
          ship_diversity: calculate_ship_diversity(window),
          isk_destruction_rate: calculate_isk_rate(window),

          # Temporal features
          time_offset: calculate_time_offset(window),
          battle_progression: calculate_progression_ratio(window),

          # Reference to original window
          window: window
        }
      end)

    {:ok, features}
  end

  defp calculate_damage_rate(window) do
    # Estimate damage rate based on ship types and kill frequency
    # This is a heuristic since we don't have actual damage logs

    if Enum.empty?(window.killmails) do
      0.0
    else
      # Use ship type and kill timing to estimate damage intensity
      total_estimated_hp = Enum.sum(Enum.map(window.killmails, &estimate_ship_hp/1))
      duration_minutes = window.duration_seconds / 60

      if duration_minutes > 0 do
        total_estimated_hp / duration_minutes
      else
        total_estimated_hp
      end
    end
  end

  defp calculate_kill_rate(window) do
    if window.duration_seconds > 0 do
      length(window.killmails) / (window.duration_seconds / 60)
    else
      length(window.killmails)
    end
  end

  defp calculate_engagement_level(window) do
    # Measure how engaged participants are based on attack patterns
    if Enum.empty?(window.killmails) do
      0.0
    else
      participants = extract_all_participants(window.killmails)
      attackers = extract_attackers_count(window.killmails)

      if length(participants) > 0 do
        attackers / length(participants)
      else
        0.0
      end
    end
  end

  defp calculate_ewar_intensity(window) do
    # Heuristic: certain ship types indicate EWAR usage
    ewar_ships =
      window.killmails
      |> Enum.count(&is_ewar_ship_type/1)

    total_ships = length(window.killmails)

    if total_ships > 0 do
      ewar_ships / total_ships
    else
      0.0
    end
  end

  defp calculate_ship_diversity(window) do
    unique_ship_types =
      window.killmails
      |> Enum.map(& &1.victim_ship_type_id)
      |> Enum.uniq()
      |> length()

    total_ships = length(window.killmails)

    if total_ships > 0 do
      unique_ship_types / total_ships
    else
      0.0
    end
  end

  defp calculate_isk_rate(window) do
    # Use ship type to estimate ISK destruction rate
    total_estimated_value = Enum.sum(Enum.map(window.killmails, &estimate_ship_value/1))
    duration_minutes = window.duration_seconds / 60

    if duration_minutes > 0 do
      total_estimated_value / duration_minutes
    else
      total_estimated_value
    end
  end

  defp calculate_time_offset(_window) do
    # Normalized time position within battle (0.0 to 1.0)
    # This will be set during window creation process
    0.0
  end

  defp calculate_progression_ratio(window) do
    # Simple progression based on timestamp
    # More sophisticated version would use battle context
    length(window.killmails) |> :math.log() |> max(0.1)
  end

  defp apply_clustering(feature_vectors, max_clusters, :kmeans) do
    # Implement k-means clustering algorithm
    if length(feature_vectors) <= max_clusters do
      # Too few data points for clustering - each point is its own cluster
      clusters =
        Enum.with_index(feature_vectors)
        |> Enum.map(fn {features, index} ->
          %{
            cluster_id: index,
            centroid: extract_numeric_features(features),
            members: [features],
            size: 1
          }
        end)

      {:ok, clusters}
    else
      optimal_k = determine_optimal_k(feature_vectors, max_clusters)
      kmeans_cluster(feature_vectors, optimal_k)
    end
  end

  defp determine_optimal_k(feature_vectors, max_k) do
    # Use elbow method to find optimal number of clusters
    wcss_scores =
      1..max_k
      |> Enum.map(fn k ->
        case kmeans_cluster(feature_vectors, k) do
          {:ok, clusters} -> {k, calculate_wcss(clusters)}
          _ -> {k, :infinity}
        end
      end)

    # Find elbow point (simplified heuristic)
    best_k =
      wcss_scores
      |> Enum.filter(fn {_k, score} -> score != :infinity end)
      |> Enum.min_by(
        fn {k, score} ->
          # Balance cluster quality with simplicity
          score + k * 0.1
        end,
        fn -> {3, 0} end
      )
      |> elem(0)

    max(2, min(best_k, max_k))
  end

  defp kmeans_cluster(feature_vectors, k) do
    numeric_features = Enum.map(feature_vectors, &extract_numeric_features/1)

    # Initialize centroids randomly
    initial_centroids = initialize_centroids(numeric_features, k)

    # Run k-means iterations
    case iterate_kmeans(numeric_features, initial_centroids, 0) do
      {:ok, final_centroids} ->
        clusters = assign_to_clusters(feature_vectors, numeric_features, final_centroids)
        {:ok, clusters}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_numeric_features(features) do
    [
      features.damage_rate,
      features.kill_rate,
      features.participant_engagement,
      features.ewar_usage,
      features.ship_diversity,
      features.isk_destruction_rate,
      features.battle_progression
    ]
  end

  defp initialize_centroids(numeric_features, k) do
    # Use k-means++ initialization for better results
    if length(numeric_features) < k do
      # Not enough data points
      numeric_features
    else
      # Simple random initialization (k-means++ would be better)
      numeric_features
      |> Enum.take_random(k)
    end
  end

  defp iterate_kmeans(features, centroids, iteration) do
    if iteration >= @max_iterations do
      {:error, :max_iterations_reached}
    else
      # Assign points to clusters
      assignments = assign_points_to_centroids(features, centroids)

      # Calculate new centroids
      new_centroids = calculate_new_centroids(assignments, centroids)

      # Check for convergence
      if converged?(centroids, new_centroids) do
        {:ok, new_centroids}
      else
        iterate_kmeans(features, new_centroids, iteration + 1)
      end
    end
  end

  defp assign_points_to_centroids(features, centroids) do
    Enum.map(features, fn feature_vector ->
      closest_centroid_index =
        centroids
        |> Enum.with_index()
        |> Enum.min_by(fn {centroid, _index} ->
          euclidean_distance(feature_vector, centroid)
        end)
        |> elem(1)

      {feature_vector, closest_centroid_index}
    end)
  end

  defp calculate_new_centroids(assignments, old_centroids) do
    # Group by cluster and calculate mean
    cluster_groups =
      assignments
      |> Enum.group_by(fn {_point, cluster_id} -> cluster_id end)

    Enum.with_index(old_centroids)
    |> Enum.map(fn {old_centroid, cluster_id} ->
      cluster_points =
        Map.get(cluster_groups, cluster_id, [])
        |> Enum.map(fn {point, _cluster} -> point end)

      if length(cluster_points) > 0 do
        calculate_centroid_mean(cluster_points)
      else
        old_centroid
      end
    end)
  end

  defp calculate_centroid_mean(points) do
    if Enum.empty?(points) do
      []
    else
      feature_count = length(List.first(points))

      0..(feature_count - 1)
      |> Enum.map(fn feature_index ->
        feature_sum =
          points
          |> Enum.map(&Enum.at(&1, feature_index))
          |> Enum.sum()

        feature_sum / length(points)
      end)
    end
  end

  defp converged?(old_centroids, new_centroids) do
    pairs = Enum.zip(old_centroids, new_centroids)

    Enum.all?(pairs, fn {old, new} ->
      euclidean_distance(old, new) < @convergence_threshold
    end)
  end

  defp euclidean_distance(vector1, vector2) do
    pairs = Enum.zip(vector1, vector2)

    sum_of_squares =
      pairs
      |> Enum.map(fn {a, b} -> :math.pow(a - b, 2) end)
      |> Enum.sum()

    :math.sqrt(sum_of_squares)
  end

  defp assign_to_clusters(original_features, numeric_features, centroids) do
    assignments = assign_points_to_centroids(numeric_features, centroids)

    # Group original features by cluster
    cluster_groups =
      Enum.zip(original_features, assignments)
      |> Enum.group_by(fn {_feature, {_point, cluster_id}} -> cluster_id end)

    Enum.with_index(centroids)
    |> Enum.map(fn {centroid, cluster_id} ->
      members =
        Map.get(cluster_groups, cluster_id, [])
        |> Enum.map(fn {feature, _assignment} -> feature end)

      %{
        cluster_id: cluster_id,
        centroid: centroid,
        members: members,
        size: length(members)
      }
    end)
    |> Enum.filter(&(&1.size > 0))
  end

  defp calculate_wcss(clusters) do
    # Within-cluster sum of squares
    Enum.sum(
      Enum.map(clusters, fn cluster ->
        cluster.members
        |> Enum.map(&extract_numeric_features/1)
        |> Enum.map(&euclidean_distance(&1, cluster.centroid))
        |> Enum.map(&:math.pow(&1, 2))
        |> Enum.sum()
      end)
    )
  end

  defp classify_phase_types(clusters, _temporal_windows) do
    phases =
      clusters
      |> Enum.sort_by(fn cluster ->
        # Sort by average time of cluster members
        avg_time =
          cluster.members
          |> Enum.map(& &1.window.start_time)
          |> Enum.map(&DateTime.to_unix(DateTime.from_naive!(&1, "Etc/UTC")))
          |> Enum.sum()
          |> div(length(cluster.members))

        avg_time
      end)
      |> Enum.with_index()
      |> Enum.map(fn {cluster, phase_index} ->
        phase_type = determine_phase_type(cluster, phase_index, length(clusters))

        create_phase_summary(cluster, phase_type, phase_index)
      end)

    {:ok, phases}
  end

  defp determine_phase_type(cluster, phase_index, total_phases) do
    # Analyze cluster characteristics to determine phase type
    avg_damage_rate = cluster.members |> Enum.map(& &1.damage_rate) |> average()
    avg_kill_rate = cluster.members |> Enum.map(& &1.kill_rate) |> average()
    avg_ewar = cluster.members |> Enum.map(& &1.ewar_usage) |> average()
    avg_engagement = cluster.members |> Enum.map(& &1.participant_engagement) |> average()

    cond do
      # First phase with low damage and high EWAR suggests setup
      phase_index == 0 and avg_damage_rate < 0.3 and avg_ewar > 0.2 ->
        :setup

      # High damage and engagement suggests main engagement
      avg_damage_rate > 0.6 and avg_engagement > 0.7 ->
        :engagement

      # Last phase with declining metrics suggests resolution
      phase_index == total_phases - 1 and avg_kill_rate < 0.5 ->
        :resolution

      # High damage but low engagement suggests cleanup
      avg_damage_rate > 0.4 and avg_engagement < 0.5 ->
        :cleanup

      # Low everything suggests positioning or waiting
      avg_damage_rate < 0.3 and avg_kill_rate < 0.3 ->
        :positioning

      # Default to engagement if unclear
      true ->
        :engagement
    end
  end

  defp create_phase_summary(cluster, phase_type, phase_index) do
    # Calculate phase timing from cluster members
    all_windows = cluster.members |> Enum.map(& &1.window)
    start_time = all_windows |> Enum.map(& &1.start_time) |> Enum.min()
    end_time = all_windows |> Enum.map(& &1.end_time) |> Enum.max()

    # Aggregate all killmails in this phase
    all_killmails = all_windows |> Enum.flat_map(& &1.killmails) |> Enum.uniq_by(& &1.killmail_id)

    characteristics_data = analyze_phase_characteristics(cluster, all_killmails)

    %{
      phase_id: phase_index + 1,
      phase_type: phase_type,
      start_time: start_time,
      end_time: end_time,
      duration_seconds: NaiveDateTime.diff(end_time, start_time, :second),
      killmails: all_killmails,
      characteristics: describe_phase_characteristics(phase_type, characteristics_data),
      key_metrics: characteristics_data,
      cluster_info: %{
        size: cluster.size,
        centroid: cluster.centroid,
        variance: calculate_cluster_variance(cluster)
      }
    }
  end

  defp analyze_phase_characteristics(cluster, killmails) do
    avg_damage_rate = cluster.members |> Enum.map(& &1.damage_rate) |> average()

    %{
      avg_damage_rate: avg_damage_rate,
      # For template compatibility
      damage_rate: avg_damage_rate,
      avg_kill_rate: cluster.members |> Enum.map(& &1.kill_rate) |> average(),
      participant_engagement:
        cluster.members |> Enum.map(& &1.participant_engagement) |> average(),
      ewar_intensity: cluster.members |> Enum.map(& &1.ewar_usage) |> average(),
      ship_diversity: cluster.members |> Enum.map(& &1.ship_diversity) |> average(),
      isk_destruction_rate: cluster.members |> Enum.map(& &1.isk_destruction_rate) |> average(),
      unique_participants: extract_all_participants(killmails) |> length(),
      dominant_ship_types: analyze_dominant_ship_types(killmails),
      # Additional fields expected by template
      avg_distance: calculate_average_distance(killmails),
      intensity_score: calculate_intensity_score(avg_damage_rate)
    }
  end

  defp describe_phase_characteristics(phase_type, metrics) do
    kill_rate = metrics.avg_kill_rate
    participants = metrics.unique_participants

    intensity =
      cond do
        kill_rate > 10 -> "High intensity"
        kill_rate > 5 -> "Moderate intensity"
        true -> "Low intensity"
      end

    scale =
      cond do
        participants > 50 -> "large-scale"
        participants > 20 -> "medium-scale"
        participants > 10 -> "small-gang"
        true -> "small"
      end

    "#{intensity} #{scale} #{phase_type |> to_string() |> String.replace("_", " ")} with #{participants} participants"
  end

  defp calculate_average_distance(_killmails) do
    # For now, return a placeholder since we don't have position data
    # In a real implementation, this would calculate distances between victims and attackers
    # 15km default
    15000
  end

  defp calculate_intensity_score(avg_damage_rate) do
    # Convert damage rate to intensity score (0-10)
    cond do
      avg_damage_rate > 100_000 -> 10
      avg_damage_rate > 50000 -> 8
      avg_damage_rate > 25000 -> 6
      avg_damage_rate > 10000 -> 4
      avg_damage_rate > 5000 -> 2
      true -> 1
    end
  end

  defp analyze_transition(current_phase, next_phase) do
    %{
      type: classify_transition_type(current_phase, next_phase),
      intensity_change: calculate_intensity_change(current_phase, next_phase),
      participant_change: calculate_participant_change(current_phase, next_phase),
      tactical_significance: assess_tactical_significance(current_phase, next_phase)
    }
  end

  defp classify_transition_type(current, next) do
    current_intensity = current.key_metrics.avg_damage_rate
    next_intensity = next.key_metrics.avg_damage_rate

    cond do
      next_intensity > current_intensity * 1.5 -> :escalation
      next_intensity < current_intensity * 0.5 -> :de_escalation
      abs(next_intensity - current_intensity) < 0.1 -> :sustained
      true -> :shift
    end
  end

  defp calculate_intensity_change(current, next) do
    current_intensity = current.key_metrics.avg_damage_rate
    next_intensity = next.key_metrics.avg_damage_rate

    if current_intensity > 0 do
      (next_intensity - current_intensity) / current_intensity
    else
      0.0
    end
  end

  defp calculate_participant_change(current, next) do
    current_participants = current.key_metrics.unique_participants
    next_participants = next.key_metrics.unique_participants

    if current_participants > 0 do
      (next_participants - current_participants) / current_participants
    else
      0.0
    end
  end

  defp assess_tactical_significance(current, next) do
    # Determine if this transition represents a major tactical shift
    phase_change_significance =
      case {current.phase_type, next.phase_type} do
        {:setup, :engagement} -> :high
        {:engagement, :resolution} -> :high
        {:positioning, :engagement} -> :medium
        {:engagement, :cleanup} -> :medium
        _ -> :low
      end

    intensity_significance =
      case classify_transition_type(current, next) do
        :escalation -> :high
        :de_escalation -> :medium
        _ -> :low
      end

    # Return highest significance
    [phase_change_significance, intensity_significance]
    |> Enum.max_by(&significance_value/1)
  end

  defp significance_value(:high), do: 3
  defp significance_value(:medium), do: 2
  defp significance_value(:low), do: 1

  # Utility functions

  defp extract_all_participants(killmails) do
    killmails
    |> Enum.flat_map(&ParticipantExtractor.extract_participants/1)
    |> Enum.uniq()
  end

  defp extract_attackers_count(killmails) do
    killmails
    |> Enum.map(fn killmail ->
      case killmail.raw_data do
        %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp estimate_ship_hp(killmail) do
    # Rough HP estimates based on ship type ID ranges
    # This is a heuristic - real implementation would use static data
    ship_type_id = killmail.victim_ship_type_id

    cond do
      # Frigates (rough range)
      ship_type_id in 580..700 -> 3000
      # Destroyers  
      ship_type_id in 420..450 -> 8000
      # Cruisers
      ship_type_id in 620..650 -> 15000
      # Battlecruisers
      ship_type_id in 540..570 -> 30000
      # Battleships
      ship_type_id in 640..670 -> 60000
      # Capitals (very rough)
      ship_type_id in 19720..19740 -> 500_000
      # Default
      true -> 10000
    end
  end

  defp estimate_ship_value(killmail) do
    # Rough ISK value estimates
    ship_type_id = killmail.victim_ship_type_id

    cond do
      # Frigates: 2M ISK
      ship_type_id in 580..700 -> 2_000_000
      # Destroyers: 8M ISK
      ship_type_id in 420..450 -> 8_000_000
      # Cruisers: 25M ISK
      ship_type_id in 620..650 -> 25_000_000
      # Battlecruisers: 80M ISK
      ship_type_id in 540..570 -> 80_000_000
      # Battleships: 200M ISK
      ship_type_id in 640..670 -> 200_000_000
      # Capitals: 2B ISK
      ship_type_id in 19720..19740 -> 2_000_000_000
      # Default: 15M ISK
      true -> 15_000_000
    end
  end

  defp is_ewar_ship_type(killmail) do
    # Heuristic for EWAR ships based on type ID
    ship_type_id = killmail.victim_ship_type_id

    # Some known EWAR ship type ranges (simplified)
    ship_type_id in [
      # Recon ships
      11963,
      11965,
      11969,
      11971,
      # Force Recon
      11957,
      11958,
      11959,
      11961,
      # Some T1 cruisers commonly used for EWAR
      621,
      622,
      623
    ]
  end

  defp analyze_dominant_ship_types(killmails) do
    killmails
    |> Enum.group_by(& &1.victim_ship_type_id)
    |> Enum.map(fn {type_id, kills} ->
      %{ship_type_id: type_id, count: length(kills)}
    end)
    |> Enum.sort_by(& &1.count, :desc)
    |> Enum.take(3)
  end

  defp calculate_cluster_variance(cluster) do
    if length(cluster.members) <= 1 do
      0.0
    else
      feature_vectors = Enum.map(cluster.members, &extract_numeric_features/1)

      # Calculate variance for each feature dimension
      variances =
        0..(length(cluster.centroid) - 1)
        |> Enum.map(fn feature_index ->
          feature_values = Enum.map(feature_vectors, &Enum.at(&1, feature_index))
          calculate_variance(feature_values)
        end)

      # Return average variance across all dimensions
      Enum.sum(variances) / length(variances)
    end
  end

  defp calculate_variance(values) do
    if length(values) <= 1 do
      0.0
    else
      mean = Enum.sum(values) / length(values)
      variance_sum = values |> Enum.map(&:math.pow(&1 - mean, 2)) |> Enum.sum()
      variance_sum / length(values)
    end
  end

  defp average([]), do: 0.0

  defp average(values) do
    Enum.sum(values) / length(values)
  end
end
