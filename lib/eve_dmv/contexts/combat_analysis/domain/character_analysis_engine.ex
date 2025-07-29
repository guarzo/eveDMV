defmodule EveDmv.Contexts.CombatAnalysis.Domain.CharacterAnalysisEngine do
  @moduledoc """
  Engine for comprehensive character combat analysis.

  Provides detailed analysis of character combat patterns, ship preferences,
  tactical behavior, and performance metrics.
  """

  use GenServer

  alias EveDmv.DomainEvents.KillmailEnriched
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.Shared.Infrastructure.UnifiedRepository

  require Logger

  # Analysis time ranges
  @time_ranges %{
    last_7_days: 7 * 24 * 3600,
    last_30_days: 30 * 24 * 3600,
    last_90_days: 90 * 24 * 3600,
    last_year: 365 * 24 * 3600
  }

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze character combat patterns and behavior.
  """
  def analyze_combat_patterns(character_id, options \\ []) do
    GenServer.call(__MODULE__, {:analyze_combat_patterns, character_id, options})
  end

  @doc """
  Get character threat assessment.
  """
  def assess_character_threat(character_id, options \\ []) do
    GenServer.call(__MODULE__, {:assess_character_threat, character_id, options})
  end

  @doc """
  Analyze character ship preferences and usage patterns.
  """
  def analyze_ship_preferences(character_id, options \\ []) do
    GenServer.call(__MODULE__, {:analyze_ship_preferences, character_id, options})
  end

  @doc """
  Get character activity patterns and peak hours.
  """
  def analyze_activity_patterns(character_id, options \\ []) do
    GenServer.call(__MODULE__, {:analyze_activity_patterns, character_id, options})
  end

  @doc """
  Process killmail for character analysis updates.
  """
  def process_killmail(%KillmailEnriched{} = killmail) do
    GenServer.cast(__MODULE__, {:process_killmail, killmail})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      analyses_performed: 0,
      killmails_processed: 0,
      character_cache: %{}
    }

    Logger.info("CharacterAnalysisEngine started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_combat_patterns, character_id, options}, _from, state) do
    case perform_combat_patterns_analysis(character_id, options) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, %{state | analyses_performed: state.analyses_performed + 1}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:assess_character_threat, character_id, options}, _from, state) do
    case perform_character_threat_assessment(character_id, options) do
      {:ok, assessment} ->
        {:reply, {:ok, assessment}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:analyze_ship_preferences, character_id, options}, _from, state) do
    case perform_ship_preferences_analysis(character_id, options) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:analyze_activity_patterns, character_id, options}, _from, state) do
    case perform_activity_patterns_analysis(character_id, options) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, killmail}, state) do
    # Update character analysis for all involved characters
    involved_characters = extract_character_ids_from_killmail(killmail)

    Enum.each(involved_characters, fn character_id ->
      invalidate_character_cache(character_id)
    end)

    {:noreply, %{state | killmails_processed: state.killmails_processed + 1}}
  rescue
    error ->
      Logger.error("Failed to process killmail for character analysis: #{inspect(error)}")
      {:noreply, state}
  end

  # Private functions

  defp perform_combat_patterns_analysis(character_id, options) do
    time_range = Keyword.get(options, :time_range, :last_30_days)
    cache_key = {:combat_patterns, character_id, time_range}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, cached_analysis} ->
        {:ok, cached_analysis}

      {:error, :not_found} ->
        analysis = %{
          character_id: character_id,
          analyzed_at: DateTime.utc_now(),
          time_range: time_range,
          combat_statistics: get_combat_statistics(character_id, time_range),
          engagement_patterns: analyze_engagement_patterns(character_id, time_range),
          tactical_behavior: analyze_tactical_behavior(character_id, time_range),
          fleet_participation: analyze_fleet_participation(character_id, time_range),
          risk_assessment: assess_combat_risk_taking(character_id, time_range),
          effectiveness_metrics: calculate_combat_effectiveness(character_id, time_range),
          behavioral_analysis: analyze_behavioral_patterns(character_id, time_range),
          predictions: generate_behavior_predictions(character_id, time_range)
        }

        # Cache the analysis
        # 30 minutes
        UnifiedCache.cache_combat_analysis(cache_key, analysis, 1800)
        {:ok, analysis}
    end
  rescue
    error ->
      Logger.error("Failed to analyze combat patterns: #{inspect(error)}")
      {:error, :analysis_failed}
  end

  defp perform_character_threat_assessment(character_id, options) do
    time_range = Keyword.get(options, :time_range, :last_30_days)

    threat_assessment = %{
      character_id: character_id,
      assessed_at: DateTime.utc_now(),
      time_range: time_range,
      threat_score: calculate_threat_score(character_id, time_range),
      threat_level: determine_threat_level(character_id, time_range),
      threat_factors: identify_threat_factors(character_id, time_range),
      activity_intensity: calculate_activity_intensity(character_id, time_range),
      combat_aggression: assess_combat_aggression(character_id, time_range),
      unpredictability: assess_unpredictability(character_id, time_range),
      alliance_influence: assess_alliance_influence(character_id),
      recommendations: generate_threat_recommendations(character_id, time_range)
    }

    {:ok, threat_assessment}
  rescue
    error ->
      Logger.error("Failed to assess character threat: #{inspect(error)}")
      {:error, :assessment_failed}
  end

  defp perform_ship_preferences_analysis(character_id, options) do
    time_range = Keyword.get(options, :time_range, :last_90_days)

    preferences = %{
      character_id: character_id,
      analyzed_at: DateTime.utc_now(),
      time_range: time_range,
      ship_usage: analyze_ship_usage_patterns(character_id, time_range),
      preferred_ships: identify_preferred_ships(character_id, time_range)
    }

    {:ok, preferences}
  rescue
    error ->
      Logger.error("Failed to analyze ship preferences: #{inspect(error)}")
      {:error, :analysis_failed}
  end

  defp perform_activity_patterns_analysis(character_id, options) do
    time_range = Keyword.get(options, :time_range, :last_90_days)

    patterns = %{
      character_id: character_id,
      analyzed_at: DateTime.utc_now(),
      time_range: time_range,
      engagement_frequency: calculate_engagement_frequency(character_id, time_range),
      activity_intensity: calculate_activity_intensity(character_id, time_range),
      total_kills: get_character_kills_count(character_id, time_range),
      total_losses: get_character_losses_count(character_id, time_range)
    }

    {:ok, patterns}
  rescue
    error ->
      Logger.error("Failed to analyze activity patterns: #{inspect(error)}")
      {:error, :analysis_failed}
  end

  # Analysis helper functions

  defp get_combat_statistics(character_id, time_range) do
    # This would query actual killmail data
    %{
      total_kills: get_character_kills_count(character_id, time_range),
      total_losses: get_character_losses_count(character_id, time_range),
      kill_death_ratio: calculate_kill_death_ratio(character_id, time_range),
      isk_destroyed: calculate_isk_destroyed(character_id, time_range),
      isk_lost: calculate_isk_lost(character_id, time_range),
      isk_efficiency: calculate_isk_efficiency(character_id, time_range),
      average_gang_size: calculate_average_gang_size(character_id, time_range),
      solo_percentage: calculate_solo_percentage(character_id, time_range)
    }
  end

  defp analyze_engagement_patterns(character_id, time_range) do
    %{
      preferred_engagement_size: determine_preferred_engagement_size(character_id, time_range),
      average_gang_size: calculate_average_gang_size(character_id, time_range),
      solo_percentage: calculate_solo_percentage(character_id, time_range)
    }
  end

  defp analyze_tactical_behavior(character_id, time_range) do
    %{
      aggression_level: assess_aggression_level(character_id, time_range),
      risk_tolerance: assess_risk_tolerance(character_id, time_range),
      unpredictability: assess_unpredictability(character_id, time_range)
    }
  end

  defp analyze_fleet_participation(character_id, time_range) do
    %{
      fleet_percentage: calculate_fleet_participation_percentage(character_id, time_range),
      preferred_fleet_size: determine_preferred_fleet_size(character_id, time_range),
      average_gang_size: calculate_average_gang_size(character_id, time_range)
    }
  end

  defp assess_combat_risk_taking(character_id, time_range) do
    %{
      risk_score: calculate_risk_score(character_id, time_range),
      risk_tolerance: assess_risk_tolerance(character_id, time_range),
      solo_percentage: calculate_solo_percentage(character_id, time_range)
    }
  end

  defp calculate_combat_effectiveness(character_id, time_range) do
    %{
      overall_effectiveness: calculate_overall_effectiveness(character_id, time_range),
      survival_effectiveness: calculate_survival_effectiveness(character_id, time_range),
      kill_death_ratio: calculate_kill_death_ratio(character_id, time_range),
      isk_efficiency: calculate_isk_efficiency(character_id, time_range)
    }
  end

  defp analyze_behavioral_patterns(character_id, time_range) do
    %{
      unpredictability: assess_unpredictability(character_id, time_range),
      risk_tolerance: assess_risk_tolerance(character_id, time_range),
      aggression_level: assess_aggression_level(character_id, time_range)
    }
  end

  defp generate_behavior_predictions(character_id, time_range) do
    %{
      activity_intensity: calculate_activity_intensity(character_id, time_range),
      preferred_ships: identify_preferred_ships(character_id, time_range),
      engagement_preference: determine_preferred_engagement_size(character_id, time_range)
    }
  end

  # Helper functions for threat assessment

  defp calculate_threat_score(character_id, time_range) do
    # Multi-factor threat scoring
    activity_score = get_activity_threat_score(character_id, time_range)
    aggression_score = get_aggression_threat_score(character_id, time_range)
    capability_score = get_capability_threat_score(character_id, time_range)
    unpredictability_score = get_unpredictability_threat_score(character_id, time_range)

    # Weighted average
    (activity_score * 0.3 + aggression_score * 0.25 + capability_score * 0.25 +
       unpredictability_score * 0.2)
    |> Float.round(3)
  end

  defp determine_threat_level(character_id, time_range) do
    threat_score = calculate_threat_score(character_id, time_range)

    cond do
      threat_score >= 0.8 -> :critical
      threat_score >= 0.6 -> :high
      threat_score >= 0.4 -> :medium
      threat_score >= 0.2 -> :low
      true -> :minimal
    end
  end

  defp identify_threat_factors(character_id, time_range) do
    initial_factors = []

    high_kill_factors =
      if get_character_kills_count(character_id, time_range) > 50 do
        ["High kill activity" | initial_factors]
      else
        initial_factors
      end

    solo_factors =
      if calculate_solo_percentage(character_id, time_range) > 30.0 do
        ["Frequent solo operations" | high_kill_factors]
      else
        high_kill_factors
      end

    unpredictability_factors =
      if assess_unpredictability(character_id, time_range) > 0.7 do
        ["Unpredictable behavior" | solo_factors]
      else
        solo_factors
      end

    final_factors =
      if assess_aggression_level(character_id, time_range) > 0.8 do
        ["High aggression" | unpredictability_factors]
      else
        unpredictability_factors
      end

    final_factors
  end

  # Cache management

  defp invalidate_character_cache(character_id) do
    # Invalidate all cached analyses for this character
    cache_keys = [
      {:combat_patterns, character_id, :last_7_days},
      {:combat_patterns, character_id, :last_30_days},
      {:combat_patterns, character_id, :last_90_days},
      {:ship_preferences, character_id, :last_90_days},
      {:activity_patterns, character_id, :last_90_days}
    ]

    Enum.each(cache_keys, fn key ->
      UnifiedCache.delete(:combat, key)
    end)
  end

  defp extract_character_ids_from_killmail(killmail) do
    victim_id = get_in(killmail.victim, [:character_id])
    attacker_ids = Enum.map(killmail.attackers, & &1[:character_id]) |> Enum.filter(& &1)

    [victim_id | attacker_ids] |> Enum.filter(& &1) |> Enum.uniq()
  end

  # Real implementations using database queries

  defp get_character_kills_count(character_id, time_range) do
    seconds_ago = Map.get(@time_ranges, time_range, @time_ranges.last_30_days)
    time_threshold = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    case EveDmv.Api.read(EveDmv.Killmails.Participant,
           filter: [character_id: character_id, is_victim: false],
           filters: [{:killmail_time, {:>, time_threshold}}]
         ) do
      {:ok, participants} -> length(participants)
      _ -> 0
    end
  end

  defp get_character_losses_count(character_id, time_range) do
    seconds_ago = Map.get(@time_ranges, time_range, @time_ranges.last_30_days)
    time_threshold = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    case EveDmv.Api.read(EveDmv.Killmails.Participant,
           filter: [character_id: character_id, is_victim: true],
           filters: [{:killmail_time, {:>, time_threshold}}]
         ) do
      {:ok, participants} -> length(participants)
      _ -> 0
    end
  end

  defp calculate_kill_death_ratio(character_id, time_range) do
    kills = get_character_kills_count(character_id, time_range)
    losses = get_character_losses_count(character_id, time_range)

    if losses > 0 do
      Float.round(kills / losses, 2)
    else
      if kills > 0, do: kills * 1.0, else: 0.0
    end
  end

  defp calculate_isk_destroyed(character_id, time_range) do
    # Note: This requires ship value data which would come from market pricing
    # For now, return 0 as we don't have pricing integration
    _ = {character_id, time_range}
    0
  end

  defp calculate_isk_lost(character_id, time_range) do
    # Note: This requires ship value data which would come from market pricing
    # For now, return 0 as we don't have pricing integration
    _ = {character_id, time_range}
    0
  end

  defp calculate_isk_efficiency(character_id, time_range) do
    destroyed = calculate_isk_destroyed(character_id, time_range)
    lost = calculate_isk_lost(character_id, time_range)

    total = destroyed + lost

    if total > 0 do
      Float.round(destroyed / total * 100, 1)
    else
      0.0
    end
  end

  defp calculate_average_gang_size(character_id, time_range) do
    seconds_ago = Map.get(@time_ranges, time_range, @time_ranges.last_30_days)
    time_threshold = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    # Get killmails where character participated as attacker
    case EveDmv.Api.read(EveDmv.Killmails.Participant,
           filter: [character_id: character_id, is_victim: false],
           filters: [{:killmail_time, {:>, time_threshold}}]
         ) do
      {:ok, participations} when participations != [] ->
        # For each killmail, count total attackers
        gang_sizes =
          Enum.map(participations, fn participation ->
            case EveDmv.Api.read(EveDmv.Killmails.Participant,
                   filter: [killmail_id: participation.killmail_id, is_victim: false]
                 ) do
              {:ok, attackers} -> length(attackers)
              _ -> 1
            end
          end)

        if not Enum.empty?(gang_sizes) do
          Float.round(Enum.sum(gang_sizes) / length(gang_sizes), 1)
        else
          1.0
        end

      _ ->
        1.0
    end
  end

  defp calculate_solo_percentage(character_id, time_range) do
    seconds_ago = Map.get(@time_ranges, time_range, @time_ranges.last_30_days)
    time_threshold = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    case EveDmv.Api.read(EveDmv.Killmails.Participant,
           filter: [character_id: character_id, is_victim: false],
           filters: [{:killmail_time, {:>, time_threshold}}]
         ) do
      {:ok, participations} when participations != [] ->
        solo_kills =
          Enum.count(participations, fn participation ->
            case EveDmv.Api.read(EveDmv.Killmails.Participant,
                   filter: [killmail_id: participation.killmail_id, is_victim: false]
                 ) do
              {:ok, attackers} -> length(attackers) == 1
              _ -> false
            end
          end)

        Float.round(solo_kills / length(participations) * 100, 1)

      _ ->
        0.0
    end
  end

  defp determine_preferred_engagement_size(character_id, time_range) do
    avg_gang_size = calculate_average_gang_size(character_id, time_range)

    cond do
      avg_gang_size <= 2.0 -> :solo
      avg_gang_size <= 5.0 -> :small
      avg_gang_size <= 15.0 -> :medium
      true -> :large
    end
  end

  defp assess_aggression_level(character_id, time_range) do
    # Base aggression on kill/death ratio and activity frequency
    kd_ratio = calculate_kill_death_ratio(character_id, time_range)
    kills = get_character_kills_count(character_id, time_range)

    # Higher kills and better K/D suggests more aggressive play
    base_score = min(kd_ratio / 5.0, 1.0) * 0.7
    activity_score = min(kills / 50.0, 1.0) * 0.3

    Float.round(base_score + activity_score, 2)
  end

  defp assess_risk_tolerance(character_id, time_range) do
    solo_percentage = calculate_solo_percentage(character_id, time_range)

    # Higher solo percentage suggests higher risk tolerance
    Float.round(solo_percentage / 100.0, 2)
  end

  defp calculate_fleet_participation_percentage(character_id, time_range) do
    avg_gang_size = calculate_average_gang_size(character_id, time_range)

    # Consider fleet participation as gang size > 5
    if avg_gang_size > 5.0 do
      # Higher gang size = higher fleet participation
      Float.round(min(avg_gang_size / 20.0, 1.0), 2)
    else
      0.0
    end
  end

  defp determine_preferred_fleet_size(character_id, time_range) do
    determine_preferred_engagement_size(character_id, time_range)
  end

  defp calculate_risk_score(character_id, time_range) do
    # Calculate risk based on measurable factors
    solo_risk = calculate_solo_percentage(character_id, time_range) / 100.0 * 0.4
    activity_risk = min(get_character_kills_count(character_id, time_range) / 100.0, 1.0) * 0.3
    aggression_risk = assess_aggression_level(character_id, time_range) * 0.3

    Float.round(solo_risk + activity_risk + aggression_risk, 2)
  end

  defp calculate_overall_effectiveness(character_id, time_range) do
    kd_ratio = calculate_kill_death_ratio(character_id, time_range)

    # Normalize K/D ratio to 0-1 scale
    normalized_kd = min(kd_ratio / 3.0, 1.0)
    Float.round(normalized_kd, 2)
  end

  defp calculate_survival_effectiveness(character_id, time_range) do
    kills = get_character_kills_count(character_id, time_range)
    losses = get_character_losses_count(character_id, time_range)
    total = kills + losses

    if total > 0 do
      Float.round(kills / total, 2)
    else
      0.0
    end
  end

  defp calculate_activity_intensity(character_id, time_range) do
    kills = get_character_kills_count(character_id, time_range)
    losses = get_character_losses_count(character_id, time_range)
    total_activity = kills + losses

    seconds_ago = Map.get(@time_ranges, time_range, @time_ranges.last_30_days)
    days = seconds_ago / (24 * 3600)

    # Activity per day, normalized to 0-1 scale
    activity_per_day = total_activity / days
    Float.round(min(activity_per_day / 5.0, 1.0), 2)
  end

  defp assess_combat_aggression(character_id, time_range) do
    assess_aggression_level(character_id, time_range)
  end

  defp assess_unpredictability(character_id, time_range) do
    # Base unpredictability on variety of engagement sizes
    avg_gang_size = calculate_average_gang_size(character_id, time_range)
    solo_percentage = calculate_solo_percentage(character_id, time_range)

    # More variation in engagement style = higher unpredictability
    if solo_percentage > 0 and solo_percentage < 90 do
      Float.round(0.5 + abs(avg_gang_size - 5.0) / 10.0, 2)
    else
      # Very predictable if always solo or always fleet
      0.2
    end
  end

  defp generate_threat_recommendations(character_id, time_range) do
    recommendations = []

    aggression = assess_combat_aggression(character_id, time_range)
    activity = calculate_activity_intensity(character_id, time_range)

    recommendations =
      if aggression > 0.7 do
        ["High aggression - monitor closely" | recommendations]
      else
        recommendations
      end

    recommendations =
      if activity > 0.8 do
        ["Very active - frequent engagement" | recommendations]
      else
        recommendations
      end

    solo_pct = calculate_solo_percentage(character_id, time_range)

    recommendations =
      if solo_pct > 50 do
        ["Prefers solo operations" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  defp analyze_ship_usage_patterns(character_id, time_range) do
    seconds_ago = Map.get(@time_ranges, time_range, @time_ranges.last_30_days)
    time_threshold = DateTime.add(DateTime.utc_now(), -seconds_ago, :second)

    case EveDmv.Api.read(EveDmv.Killmails.Participant,
           filter: [character_id: character_id],
           filters: [{:killmail_time, {:>, time_threshold}}]
         ) do
      {:ok, participations} when participations != [] ->
        ship_counts =
          Enum.reduce(participations, %{}, fn p, acc ->
            Map.update(acc, p.ship_type_id, 1, &(&1 + 1))
          end)

        total = length(participations)

        ship_percentages =
          Enum.map(ship_counts, fn {ship_id, count} ->
            {ship_id, Float.round(count / total * 100, 1)}
          end)

        %{
          total_engagements: total,
          ship_usage: Map.new(ship_percentages),
          most_used_ship: Enum.max_by(ship_counts, fn {_, count} -> count end) |> elem(0),
          ship_variety: map_size(ship_counts)
        }

      _ ->
        %{}
    end
  end

  defp identify_preferred_ships(character_id, time_range) do
    patterns = analyze_ship_usage_patterns(character_id, time_range)

    case patterns do
      %{ship_usage: ship_usage} when map_size(ship_usage) > 0 ->
        ship_usage
        |> Enum.filter(fn {_, percentage} -> percentage >= 10.0 end)
        |> Enum.sort_by(fn {_, percentage} -> percentage end, :desc)
        |> Enum.map(fn {ship_id, _} -> ship_id end)

      _ ->
        []
    end
  end

  defp calculate_engagement_frequency(character_id, time_range) do
    calculate_activity_intensity(character_id, time_range)
  end

  defp get_activity_threat_score(character_id, time_range) do
    calculate_activity_intensity(character_id, time_range)
  end

  defp get_aggression_threat_score(character_id, time_range) do
    assess_combat_aggression(character_id, time_range)
  end

  defp get_capability_threat_score(character_id, time_range) do
    # Base capability on effectiveness and activity
    effectiveness = calculate_overall_effectiveness(character_id, time_range)
    activity = calculate_activity_intensity(character_id, time_range)
    Float.round(effectiveness * 0.7 + activity * 0.3, 2)
  end

  defp get_unpredictability_threat_score(character_id, time_range) do
    assess_unpredictability(character_id, time_range)
  end

  defp assess_alliance_influence(character_id) do
    # Query character's alliance participation and member count
    case UnifiedRepository.get_character_alliance_info(character_id) do
      {:ok, %{alliance_id: nil}} ->
        0.0

      {:ok, %{alliance_id: alliance_id, member_count: member_count}} ->
        # Calculate influence based on alliance size and activity
        base_influence =
          case member_count do
            count when count > 10000 -> 0.9
            count when count > 5000 -> 0.7
            count when count > 1000 -> 0.5
            count when count > 100 -> 0.3
            _ -> 0.1
          end

        # Get alliance activity in last 30 days
        case UnifiedRepository.get_alliance_activity(alliance_id, 30) do
          {:ok, %{killmail_count: km_count}} when km_count > 100 ->
            Float.round(base_influence * 1.2, 2)

          {:ok, %{killmail_count: km_count}} when km_count > 50 ->
            base_influence

          _ ->
            Float.round(base_influence * 0.8, 2)
        end

      _ ->
        0.0
    end
  end
end
