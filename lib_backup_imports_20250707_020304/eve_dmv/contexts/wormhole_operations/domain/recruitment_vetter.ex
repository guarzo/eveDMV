defmodule EveDmv.Contexts.WormholeOperations.Domain.RecruitmentVetter do
  use EveDmv.ErrorHandler
  use GenServer

  alias EveDmv.Contexts.WormholeOperations.Infrastructure.{VettingRepository, WormholeDataProvider}
  alias EveDmv.DomainEvents.VettingComplete
  alias EveDmv.Infrastructure.EventBus
  alias EveDmv.Result

  require Logger
  @moduledoc """
  Recruitment vetting service specialized for wormhole corporations.

  Provides comprehensive candidate analysis including:
  - Corporation history evaluation
  - Killboard activity assessment
  - OpSec risk analysis
  - Wormhole experience evaluation
  - Cultural fit assessment
  """





  # Vetting score weights
  @vetting_weights %{
    corp_history: 0.25,
    killboard_activity: 0.20,
    opsec_risk: 0.25,
    wormhole_experience: 0.15,
    character_age: 0.10,
    skill_focus: 0.05
  }

  # Risk thresholds
  @high_risk_threshold 0.7
  @medium_risk_threshold 0.4

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Perform comprehensive vetting analysis for a recruitment candidate.
  """
  def perform_vetting_analysis(character_id, vetting_criteria) do
    GenServer.call(__MODULE__, {:perform_vetting, character_id, vetting_criteria}, 30_000)
  end

  @doc """
  Generate recruitment recommendations for a character.
  """
  def generate_recruitment_recommendations(character_id) do
    GenServer.call(__MODULE__, {:generate_recommendations, character_id})
  end

  @doc """
  Force re-vetting of a candidate with updated criteria.
  """
  def force_revett_candidate(character_id) do
    GenServer.call(__MODULE__, {:force_revett, character_id})
  end

  @doc """
  Get vetting service metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      vetting_cache: %{},
      metrics: %{
        total_vettings: 0,
        approved_candidates: 0,
        rejected_candidates: 0,
        pending_reviews: 0,
        average_vetting_time_ms: 0
      },
      recent_vetting_times: []
    }

    Logger.info("RecruitmentVetter started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:perform_vetting, character_id, vetting_criteria}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    case perform_comprehensive_vetting(character_id, vetting_criteria) do
      {:ok, vetting_report} ->
        end_time = System.monotonic_time(:millisecond)
        vetting_time = end_time - start_time

        # Store vetting report
        VettingRepository.store_vetting_report(vetting_report)

        # Extract character name from the detailed analysis
        character_name =
          get_in(vetting_report, [:detailed_analysis, :character_assessment, :character_name]) ||
            "Character_#{character_id}"

        # Publish vetting complete event
        EventBus.publish(%VettingComplete{
          character_id: character_id,
          character_name: character_name,
          recommendation: vetting_report.recommendation,
          timestamp: DateTime.utc_now()
        })

        # Update metrics
        new_state = update_vetting_metrics(state, vetting_report, vetting_time)

        Logger.info(
          "Completed vetting for character #{character_id}: #{vetting_report.recommendation}"
        )

        {:reply, {:ok, vetting_report}, new_state}

      {:error, reason} ->
        Logger.error("Failed to vet character #{character_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:generate_recommendations, character_id}, _from, state) do
    case VettingRepository.get_latest_vetting(character_id) do
      {:ok, vetting_report} ->
        recommendations = generate_detailed_recommendations(vetting_report)
        {:reply, {:ok, recommendations}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:force_revett, character_id}, _from, state) do
    # Clear any cached vetting data and force fresh analysis
    new_cache = Map.delete(state.vetting_cache, character_id)
    new_state = %{state | vetting_cache: new_cache}

    Logger.info("Forcing re-vetting for character: #{character_id}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    # Calculate current average vetting time
    current_avg =
      case state.recent_vetting_times do
        [] -> 0
        times -> Enum.sum(times) / length(times)
      end

    metrics = %{
      state.metrics
      | average_vetting_time_ms: Float.round(current_avg, 2)
    }

    {:reply, metrics, state}
  end

  # Private vetting functions

  defp perform_comprehensive_vetting(character_id, vetting_criteria) do
    vetting_id = generate_vetting_id()

    # Gather character data
    with {:ok, character_data} <- gather_character_data(character_id),
         {:ok, corp_history} <- analyze_corporation_history(character_data, vetting_criteria),
         {:ok, killboard_analysis} <-
           analyze_killboard_activity(character_data, vetting_criteria),
         {:ok, opsec_assessment} <- assess_opsec_risks(character_data, vetting_criteria),
         {:ok, wh_experience} <- evaluate_wormhole_experience(character_data),
         {:ok, character_assessment} <- assess_character_metrics(character_data) do
      # Calculate overall scores
      vetting_scores = %{
        corp_history_score: corp_history.score,
        killboard_score: killboard_analysis.score,
        opsec_risk_score: opsec_assessment.risk_score,
        wormhole_experience_score: wh_experience.score,
        character_age_score: character_assessment.age_score,
        skill_focus_score: character_assessment.skill_focus_score
      }

      overall_score = calculate_overall_vetting_score(vetting_scores)
      risk_score = calculate_overall_risk_score(vetting_scores)

      recommendation =
        determine_vetting_recommendation(overall_score, risk_score, vetting_criteria)

      # Compile comprehensive report
      vetting_report = %{
        vetting_id: vetting_id,
        character_id: character_id,
        vetting_criteria: vetting_criteria,
        vetting_scores: vetting_scores,
        overall_score: overall_score,
        overall_risk_score: risk_score,
        recommendation: recommendation,
        detailed_analysis: %{
          corp_history: corp_history,
          killboard_analysis: killboard_analysis,
          opsec_assessment: opsec_assessment,
          wormhole_experience: wh_experience,
          character_assessment: character_assessment
        },
        red_flags: identify_red_flags(corp_history, killboard_analysis, opsec_assessment),
        green_flags: identify_green_flags(corp_history, killboard_analysis, wh_experience),
        improvement_areas: identify_improvement_areas(vetting_scores),
        vetted_at: DateTime.utc_now(),
        # 30 days
        expires_at: DateTime.add(DateTime.utc_now(), 30 * 24 * 3600, :second)
      }

      {:ok, vetting_report}
    end
  end

  defp gather_character_data(character_id) do
    # Simulate gathering character data from EVE ESI and other sources
    # In real implementation, this would call EVE ESI APIs

    character_data = %{
      character_id: character_id,
      character_name: "Character_#{character_id}",
      corporation_id: 1_000_000 + rem(character_id, 1000),
      alliance_id:
        if(rem(character_id, 3) == 0, do: 99_000_000 + rem(character_id, 100), else: nil),
      creation_date:
        DateTime.add(DateTime.utc_now(), -rem(character_id, 3000) * 24 * 3600, :second),
      total_sp: 50_000_000 + rem(character_id, 100_000_000),
      # -1.0 to 1.0
      security_status: (rem(character_id, 200) - 100) / 100,
      corporation_history: generate_mock_corp_history(character_id),
      killboard_data: generate_mock_killboard_data(character_id)
    }

    {:ok, character_data}
  end

  defp analyze_corporation_history(character_data, vetting_criteria) do
    corp_history = character_data.corporation_history

    # Analyze corporation changes
    corp_changes = length(corp_history)
    # Last 90 days
    recent_changes = count_recent_corp_changes(corp_history, 90)

    # Analyze corporation types and reputation
    corp_reputation_analysis = analyze_corporation_reputations(corp_history)

    # Check for suspicious patterns
    suspicious_patterns = identify_suspicious_corp_patterns(corp_history)

    # Calculate corporation history score
    history_score =
      calculate_corp_history_score(
        corp_changes,
        recent_changes,
        corp_reputation_analysis,
        suspicious_patterns
      )

    corp_analysis = %{
      score: history_score,
      total_corporations: corp_changes,
      recent_changes: recent_changes,
      average_tenure_days: calculate_average_corp_tenure(corp_history),
      reputation_analysis: corp_reputation_analysis,
      suspicious_patterns: suspicious_patterns,
      stability_rating: determine_corp_stability_rating(corp_changes, recent_changes)
    }

    {:ok, corp_analysis}
  end

  defp analyze_killboard_activity(character_data, vetting_criteria) do
    killboard_data = character_data.killboard_data

    # Activity metrics
    activity_metrics = %{
      total_kills: killboard_data.total_kills,
      total_losses: killboard_data.total_losses,
      isk_efficiency: calculate_isk_efficiency(killboard_data),
      solo_ratio: killboard_data.solo_kills / max(killboard_data.total_kills, 1),
      gang_ratio:
        (killboard_data.total_kills - killboard_data.solo_kills) /
          max(killboard_data.total_kills, 1),
      avg_gang_size: killboard_data.total_kills / max(killboard_data.total_engagements, 1),
      recent_activity: killboard_data.kills_last_30d + killboard_data.losses_last_30d
    }

    # Ship usage analysis
    ship_analysis = analyze_ship_usage_patterns(killboard_data.ship_usage)

    # Combat patterns
    combat_patterns = analyze_combat_patterns(killboard_data)

    # Wormhole activity specifically
    wh_activity = analyze_wormhole_activity(killboard_data)

    # Calculate killboard score
    killboard_score =
      calculate_killboard_score(activity_metrics, ship_analysis, combat_patterns, wh_activity)

    killboard_analysis = %{
      score: killboard_score,
      activity_metrics: activity_metrics,
      ship_analysis: ship_analysis,
      combat_patterns: combat_patterns,
      wormhole_activity: wh_activity,
      activity_level: categorize_activity_level(activity_metrics.recent_activity),
      preferred_engagement_style: determine_engagement_style(activity_metrics)
    }

    {:ok, killboard_analysis}
  end

  defp assess_opsec_risks(character_data, vetting_criteria) do
    # Analyze potential OpSec risks
    security_risks = assess_security_status_risks(character_data)
    corp_pattern_risks = assess_corp_pattern_risks(character_data.corporation_history)
    spy_indicators = assess_spy_risk_indicators(character_data)

    all_risks = security_risks ++ corp_pattern_risks ++ spy_indicators

    # Calculate overall OpSec risk score
    risk_score = calculate_opsec_risk_score(all_risks)

    opsec_assessment = %{
      risk_score: risk_score,
      risk_level: categorize_risk_level(risk_score),
      identified_risks: all_risks,
      mitigation_recommendations: generate_opsec_mitigations(all_risks),
      background_check_passed: risk_score < @medium_risk_threshold
    }

    {:ok, opsec_assessment}
  end

  defp assess_security_status_risks(character_data) do
    if character_data.security_status < -2.0 do
      [
        %{
          type: :low_security_status,
          severity: :medium,
          description: "Low security status indicates high-sec ganking"
        }
      ]
    else
      []
    end
  end

  defp evaluate_wormhole_experience(character_data) do
    killboard_data = character_data.killboard_data

    # Analyze wormhole-specific experience
    wh_kills = Map.get(killboard_data, :wormhole_kills, 0)
    wh_losses = Map.get(killboard_data, :wormhole_losses, 0)
    wh_systems_visited = Map.get(killboard_data, :unique_wh_systems, 0)

    # Ship types used in wormholes
    wh_ship_diversity = analyze_wh_ship_diversity(killboard_data)

    # Doctrine ship usage
    doctrine_experience = assess_doctrine_ship_experience(killboard_data)

    # Calculate wormhole experience score
    wh_score =
      calculate_wormhole_experience_score(
        wh_kills,
        wh_losses,
        wh_systems_visited,
        wh_ship_diversity,
        doctrine_experience
      )

    wh_experience = %{
      score: wh_score,
      wormhole_kills: wh_kills,
      wormhole_losses: wh_losses,
      wormhole_systems_visited: wh_systems_visited,
      ship_diversity: wh_ship_diversity,
      doctrine_experience: doctrine_experience,
      experience_level: categorize_wh_experience_level(wh_score),
      suitability_assessment: assess_wh_suitability(wh_score, doctrine_experience)
    }

    {:ok, wh_experience}
  end

  defp assess_character_metrics(character_data) do
    # Character age assessment
    character_age_days = DateTime.diff(DateTime.utc_now(), character_data.creation_date, :day)
    age_score = calculate_age_score(character_age_days)

    # Skill point assessment
    sp_score = calculate_sp_score(character_data.total_sp, character_age_days)

    # Skill focus assessment (simulated)
    skill_focus_score = calculate_skill_focus_score(character_data.total_sp)

    character_assessment = %{
      character_name: character_data.character_name,
      age_score: age_score,
      skill_focus_score: skill_focus_score,
      character_age_days: character_age_days,
      total_sp: character_data.total_sp,
      sp_per_day: character_data.total_sp / max(character_age_days, 1),
      skill_focus: determine_skill_focus(character_data.total_sp)
    }

    {:ok, character_assessment}
  end

  # Scoring and calculation functions

  defp calculate_overall_vetting_score(vetting_scores) do
    # Invert risk for score
    weighted_score =
      vetting_scores.corp_history_score * @vetting_weights.corp_history +
        vetting_scores.killboard_score * @vetting_weights.killboard_activity +
        (1.0 - vetting_scores.opsec_risk_score) * @vetting_weights.opsec_risk +
        vetting_scores.wormhole_experience_score * @vetting_weights.wormhole_experience +
        vetting_scores.character_age_score * @vetting_weights.character_age +
        vetting_scores.skill_focus_score * @vetting_weights.skill_focus

    Float.round(weighted_score, 3)
  end

  defp calculate_overall_risk_score(vetting_scores) do
    # Risk score combines OpSec risks with other negative indicators
    base_risk = vetting_scores.opsec_risk_score

    # Add risk from poor corporation history
    corp_risk = if vetting_scores.corp_history_score < 0.3, do: 0.2, else: 0.0

    # Add risk from suspicious killboard patterns
    killboard_risk = if vetting_scores.killboard_score < 0.2, do: 0.1, else: 0.0

    total_risk = base_risk + corp_risk + killboard_risk

    Float.round(min(1.0, total_risk), 3)
  end

  defp determine_vetting_recommendation(overall_score, risk_score, vetting_criteria) do
    min_score = Map.get(vetting_criteria, :min_overall_score, 0.6)
    max_risk = Map.get(vetting_criteria, :max_risk_score, 0.4)

    cond do
      risk_score > @high_risk_threshold -> :reject
      overall_score < 0.3 -> :reject
      risk_score > max_risk -> :conditional_approval
      overall_score < min_score -> :conditional_approval
      overall_score >= 0.8 and risk_score < 0.2 -> :strong_approve
      overall_score >= min_score and risk_score <= max_risk -> :approve
      true -> :review_required
    end
  end

  # Helper functions for specific analyses

  defp generate_mock_corp_history(character_id) do
    # Generate realistic corporation history
    # 1-5 corporations
    num_corps = 1 + rem(character_id, 5)

    start_date = DateTime.add(DateTime.utc_now(), -rem(character_id, 3000) * 24 * 3600, :second)

    1..num_corps
    |> Enum.reduce({[], start_date}, fn i, {history, current_date} ->
      corp_id = 1_000_000 + rem(character_id * i, 10_000)

      # Random tenure between 30 and 800 days
      tenure_days = 30 + rem(character_id * i * 7, 770)
      end_date = DateTime.add(current_date, tenure_days * 24 * 3600, :second)

      corp_entry = %{
        corporation_id: corp_id,
        corporation_name: "Corporation #{corp_id}",
        joined_at: current_date,
        left_at: if(i == num_corps, do: nil, else: end_date),
        tenure_days: tenure_days,
        reputation: determine_corp_reputation(corp_id)
      }

      {[corp_entry | history], end_date}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp generate_mock_killboard_data(character_id) do
    # Generate realistic killboard statistics
    base_activity = rem(character_id, 1000)

    total_kills = base_activity * 2
    total_losses = div(base_activity, 3) + 1
    solo_kills = div(total_kills, 4)

    %{
      total_kills: total_kills,
      total_losses: total_losses,
      solo_kills: solo_kills,
      total_engagements: total_kills + total_losses,
      isk_destroyed: total_kills * 50_000_000,
      isk_lost: total_losses * 45_000_000,
      kills_last_30d: rem(character_id, 20),
      losses_last_30d: rem(character_id, 8),
      wormhole_kills: rem(character_id, 50),
      wormhole_losses: rem(character_id, 15),
      unique_wh_systems: rem(character_id, 30),
      ship_usage: generate_ship_usage_pattern(character_id)
    }
  end

  defp generate_ship_usage_pattern(character_id) do
    # Generate ship usage statistics
    ship_classes = [:frigate, :destroyer, :cruiser, :battlecruiser, :battleship, :capital]

    Map.new(ship_classes, fn ship_class ->
      usage_count = rem(character_id * Enum.find_index(ship_classes, &(&1 == ship_class)), 100)
      {ship_class, usage_count}
    end)
  end

  defp determine_corp_reputation(corp_id) do
    case rem(corp_id, 10) do
      0..1 -> :excellent
      2..4 -> :good
      5..7 -> :neutral
      8 -> :poor
      9 -> :suspicious
    end
  end

  defp count_recent_corp_changes(corp_history, days) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)

    Enum.count(corp_history, fn corp_entry ->
      not is_nil(corp_entry.left_at) and
        DateTime.compare(corp_entry.left_at, cutoff_date) == :gt
    end)
  end

  defp calculate_average_corp_tenure(corp_history) do
    if length(corp_history) > 0 do
      total_tenure = Enum.sum(Enum.map(corp_history, & &1.tenure_days))
      Float.round(total_tenure / length(corp_history), 1)
    else
      0.0
    end
  end

  defp analyze_corporation_reputations(corp_history) do
    reputation_counts = Enum.frequencies(Enum.map(corp_history, & &1.reputation))

    %{
      excellent: Map.get(reputation_counts, :excellent, 0),
      good: Map.get(reputation_counts, :good, 0),
      neutral: Map.get(reputation_counts, :neutral, 0),
      poor: Map.get(reputation_counts, :poor, 0),
      suspicious: Map.get(reputation_counts, :suspicious, 0),
      reputation_score: calculate_reputation_score(reputation_counts)
    }
  end

  defp calculate_reputation_score(reputation_counts) do
    total_corps = Enum.sum(Map.values(reputation_counts))

    if total_corps > 0 do
      weighted_score =
        (Map.get(reputation_counts, :excellent, 0) * 1.0 +
           Map.get(reputation_counts, :good, 0) * 0.8 +
           Map.get(reputation_counts, :neutral, 0) * 0.5 +
           Map.get(reputation_counts, :poor, 0) * 0.2 +
           Map.get(reputation_counts, :suspicious, 0) * 0.0) / total_corps

      Float.round(weighted_score, 3)
    else
      0.5
    end
  end

  defp identify_suspicious_corp_patterns(corp_history) do
    # Check for rapid corporation hopping
    hopping_patterns =
      if count_recent_corp_changes(corp_history, 30) > 2 do
        [
          %{
            type: :rapid_corp_hopping,
            severity: :high,
            description: "Multiple corporation changes in 30 days"
          }
        ]
      else
        []
      end

    # Check for very short tenures
    short_tenures = Enum.count(corp_history, &(&1.tenure_days < 7))

    short_tenure_patterns =
      if short_tenures > length(corp_history) / 3 do
        [
          %{
            type: :short_tenures,
            severity: :medium,
            description: "Multiple corporations with very short tenure"
          }
        ]
      else
        []
      end

    hopping_patterns ++ short_tenure_patterns
  end

  defp calculate_corp_history_score(
         corp_changes,
         recent_changes,
         reputation_analysis,
         suspicious_patterns
       ) do
    initial_score = 1.0

    # Penalize excessive corporation changes
    change_penalty_score = initial_score - min(0.3, corp_changes * 0.05)

    # Penalize recent changes more heavily
    recent_penalty_score = change_penalty_score - min(0.4, recent_changes * 0.15)

    # Factor in reputation
    reputation_adjusted_score = recent_penalty_score * reputation_analysis.reputation_score

    # Penalize suspicious patterns
    pattern_penalty = length(suspicious_patterns) * 0.1
    final_score = reputation_adjusted_score - pattern_penalty

    Float.round(max(0.0, final_score), 3)
  end

  defp determine_corp_stability_rating(corp_changes, recent_changes) do
    cond do
      recent_changes > 2 -> :unstable
      corp_changes > 8 -> :very_low
      corp_changes > 5 -> :low
      corp_changes > 3 -> :moderate
      corp_changes > 1 -> :stable
      true -> :very_stable
    end
  end

  defp calculate_isk_efficiency(killboard_data) do
    total_isk = killboard_data.isk_destroyed + killboard_data.isk_lost

    if total_isk > 0 do
      Float.round(killboard_data.isk_destroyed / total_isk * 100, 2)
    else
      50.0
    end
  end

  defp analyze_ship_usage_patterns(ship_usage) do
    total_usage = Enum.sum(Map.values(ship_usage))

    if total_usage > 0 do
      ship_distribution =
        Map.new(ship_usage, fn {ship_class, count} ->
          {ship_class, Float.round(count / total_usage * 100, 1)}
        end)

      %{
        distribution: ship_distribution,
        primary_ship_class: get_primary_ship_class(ship_distribution),
        diversity_score: calculate_ship_diversity_score(ship_distribution)
      }
    else
      %{
        distribution: %{},
        primary_ship_class: :unknown,
        diversity_score: 0.0
      }
    end
  end

  defp get_primary_ship_class(ship_distribution) do
    max_entry =
      Enum.max_by(ship_distribution, fn {_, percentage} -> percentage end, fn -> {:unknown, 0} end)

    case max_entry do
      {ship_class, percentage} when percentage > 30 -> ship_class
      _ -> :mixed
    end
  end

  defp calculate_ship_diversity_score(ship_distribution) do
    # Shannon diversity index adapted for ship usage
    non_zero_percentages =
      ship_distribution
      |> Map.values()
      |> Enum.filter(&(&1 > 0))
      # Convert to proportions
      |> Enum.map(&(&1 / 100))

    if length(non_zero_percentages) > 0 do
      entropy =
        -Enum.sum(
          Enum.map(non_zero_percentages, fn p ->
            p * :math.log(p)
          end)
        )

      max_entropy = :math.log(length(non_zero_percentages))

      if max_entropy > 0 do
        Float.round(entropy / max_entropy, 3)
      else
        0.0
      end
    else
      0.0
    end
  end

  defp analyze_combat_patterns(killboard_data) do
    %{
      engagement_rate: calculate_engagement_rate(killboard_data),
      survival_rate: calculate_survival_rate(killboard_data),
      aggression_level: determine_aggression_level(killboard_data),
      preferred_gang_size: determine_preferred_gang_size(killboard_data)
    }
  end

  defp calculate_engagement_rate(killboard_data) do
    total_activity = killboard_data.kills_last_30d + killboard_data.losses_last_30d
    # Engagements per day
    Float.round(total_activity / 30, 2)
  end

  defp calculate_survival_rate(killboard_data) do
    total_engagements = killboard_data.total_engagements

    if total_engagements > 0 do
      survival_rate = (total_engagements - killboard_data.total_losses) / total_engagements * 100
      Float.round(survival_rate, 2)
    else
      0.0
    end
  end

  defp determine_aggression_level(killboard_data) do
    if killboard_data.total_kills > killboard_data.total_losses * 2 do
      :aggressive
    else
      :defensive
    end
  end

  defp determine_preferred_gang_size(killboard_data) do
    avg_gang_size = killboard_data.total_kills / max(killboard_data.total_engagements, 1)

    cond do
      avg_gang_size < 2 -> :solo
      avg_gang_size < 5 -> :small_gang
      avg_gang_size < 15 -> :medium_gang
      true -> :large_fleet
    end
  end

  defp analyze_wormhole_activity(killboard_data) do
    total_wh_activity = killboard_data.wormhole_kills + killboard_data.wormhole_losses
    total_activity = killboard_data.total_kills + killboard_data.total_losses

    wh_activity_percentage =
      if total_activity > 0 do
        Float.round(total_wh_activity / total_activity * 100, 1)
      else
        0.0
      end

    %{
      wormhole_activity_percentage: wh_activity_percentage,
      wormhole_experience_level: categorize_wh_activity_level(wh_activity_percentage),
      systems_explored: killboard_data.unique_wh_systems
    }
  end

  defp categorize_wh_activity_level(percentage) do
    cond do
      percentage >= 80 -> :expert
      percentage >= 50 -> :experienced
      percentage >= 20 -> :moderate
      percentage >= 5 -> :novice
      true -> :minimal
    end
  end

  defp calculate_killboard_score(activity_metrics, ship_analysis, combat_patterns, wh_activity) do
    # Activity score component
    # Cap at 20 activities per month
    activity_score = min(1.0, activity_metrics.recent_activity / 20)

    # ISK efficiency component
    isk_score = activity_metrics.isk_efficiency / 100

    # Ship diversity component
    diversity_score = ship_analysis.diversity_score

    # Wormhole experience component
    # Cap at 50%
    wh_score = min(1.0, wh_activity.wormhole_activity_percentage / 50)

    # Weighted average
    killboard_score =
      activity_score * 0.3 + isk_score * 0.3 + diversity_score * 0.2 + wh_score * 0.2

    Float.round(killboard_score, 3)
  end

  defp categorize_activity_level(recent_activity) do
    cond do
      recent_activity >= 30 -> :very_active
      recent_activity >= 15 -> :active
      recent_activity >= 5 -> :moderate
      recent_activity >= 1 -> :low
      true -> :inactive
    end
  end

  defp determine_engagement_style(activity_metrics) do
    cond do
      activity_metrics.solo_ratio > 0.7 -> :solo_hunter
      activity_metrics.gang_ratio > 0.8 -> :fleet_fighter
      activity_metrics.solo_ratio > 0.3 -> :mixed_engagement
      true -> :support_role
    end
  end

  # Additional helper functions for vetting analysis...

  defp assess_corp_pattern_risks(corp_history) do
    # Check for spy corp indicators
    spy_corps =
      Enum.filter(corp_history, fn corp ->
        corp.reputation == :suspicious or corp.tenure_days < 3
      end)

    if length(spy_corps) > 0 do
      [
        %{
          type: :spy_corp_history,
          severity: :high,
          description: "History with suspicious corporations"
        }
      ]
    else
      []
    end
  end

  defp assess_spy_risk_indicators(character_data) do
    # Very new character with high SP
    character_age_days = DateTime.diff(DateTime.utc_now(), character_data.creation_date, :day)
    sp_per_day = character_data.total_sp / max(character_age_days, 1)

    # Unrealistically high SP gain
    if sp_per_day > 100_000 do
      [
        %{
          type: :unrealistic_sp_gain,
          severity: :high,
          description: "Unrealistic skill point gain rate"
        }
      ]
    else
      []
    end
  end

  defp calculate_opsec_risk_score(opsec_risks) do
    if Enum.empty?(opsec_risks) do
      0.0
    else
      total_risk =
        Enum.sum(
          Enum.map(opsec_risks, fn risk ->
            case risk.severity do
              :critical -> 0.4
              :high -> 0.3
              :medium -> 0.2
              :low -> 0.1
            end
          end)
        )

      Float.round(min(1.0, total_risk), 3)
    end
  end

  defp categorize_risk_level(risk_score) do
    cond do
      risk_score >= @high_risk_threshold -> :high
      risk_score >= @medium_risk_threshold -> :medium
      risk_score >= 0.1 -> :low
      true -> :minimal
    end
  end

  defp generate_opsec_mitigations(opsec_risks) do
    Enum.map(opsec_risks, fn risk ->
      case risk.type do
        :low_security_status -> "Monitor for continued high-sec ganking activity"
        :spy_corp_history -> "Require additional background verification"
        :unrealistic_sp_gain -> "Verify character legitimacy through additional channels"
        _ -> "Standard monitoring procedures"
      end
    end)
  end

  defp analyze_wh_ship_diversity(killboard_data) do
    # Simplified wormhole ship diversity analysis
    wh_ships = [:strategic_cruiser, :cloaky_ship, :scanner_ship, :logistics]

    Map.new(wh_ships, fn ship_type ->
      {ship_type, rem(killboard_data.wormhole_kills, 10)}
    end)
  end

  defp assess_doctrine_ship_experience(killboard_data) do
    # Simplified doctrine ship experience
    doctrine_ships = [:strategic_cruiser, :recon_ship, :heavy_assault_cruiser, :logistics_cruiser]

    total_doctrine_usage =
      Enum.sum(
        Enum.map(doctrine_ships, fn ship_type ->
          Map.get(killboard_data.ship_usage, ship_type, 0)
        end)
      )

    %{
      total_doctrine_usage: total_doctrine_usage,
      doctrine_familiarity: min(1.0, total_doctrine_usage / 50),
      preferred_doctrine_role: determine_doctrine_role(killboard_data.ship_usage)
    }
  end

  defp determine_doctrine_role(ship_usage) do
    logistics_usage = Map.get(ship_usage, :logistics_cruiser, 0)

    dps_usage =
      Map.get(ship_usage, :heavy_assault_cruiser, 0) + Map.get(ship_usage, :strategic_cruiser, 0)

    support_usage = Map.get(ship_usage, :recon_ship, 0)

    cond do
      logistics_usage > dps_usage and logistics_usage > support_usage -> :logistics
      support_usage > dps_usage -> :support
      true -> :dps
    end
  end

  defp calculate_wormhole_experience_score(
         wh_kills,
         wh_losses,
         systems_visited,
         ship_diversity,
         doctrine_experience
       ) do
    # Activity component
    # Cap at 100 wh activities
    activity_component = min(1.0, (wh_kills + wh_losses) / 100)

    # Exploration component
    # Cap at 50 systems
    exploration_component = min(1.0, systems_visited / 50)

    # Ship diversity component
    diversity_total = Enum.sum(Map.values(ship_diversity))
    # Cap at 20 diverse ship uses
    diversity_component = min(1.0, diversity_total / 20)

    # Doctrine experience component
    doctrine_component = doctrine_experience.doctrine_familiarity

    # Weighted average
    wh_score =
      activity_component * 0.4 + exploration_component * 0.2 + diversity_component * 0.2 +
        doctrine_component * 0.2

    Float.round(wh_score, 3)
  end

  defp categorize_wh_experience_level(wh_score) do
    cond do
      wh_score >= 0.8 -> :expert
      wh_score >= 0.6 -> :experienced
      wh_score >= 0.4 -> :intermediate
      wh_score >= 0.2 -> :novice
      true -> :beginner
    end
  end

  defp assess_wh_suitability(wh_score, doctrine_experience) do
    suitability_score = (wh_score + doctrine_experience.doctrine_familiarity) / 2

    %{
      suitability_score: Float.round(suitability_score, 3),
      suitability_level: categorize_wh_experience_level(suitability_score),
      recommended_role: doctrine_experience.preferred_doctrine_role
    }
  end

  defp calculate_age_score(character_age_days) do
    cond do
      # 1+ years
      character_age_days >= 365 -> 1.0
      # 6+ months
      character_age_days >= 180 -> 0.8
      # 3+ months
      character_age_days >= 90 -> 0.6
      # 1+ month
      character_age_days >= 30 -> 0.4
      # 1+ week
      character_age_days >= 7 -> 0.2
      # < 1 week
      true -> 0.1
    end
  end

  defp calculate_sp_score(total_sp, character_age_days) do
    # Rough SP per day estimate
    expected_sp = character_age_days * 1500

    if expected_sp > 0 do
      sp_ratio = total_sp / expected_sp
      # Score based on reasonable SP progression
      cond do
        # Suspiciously high (possible SP farm/injectors)
        sp_ratio >= 2.0 -> 0.3
        # High but reasonable
        sp_ratio >= 1.5 -> 0.6
        # Perfect progression
        sp_ratio >= 1.0 -> 1.0
        # Good progression
        sp_ratio >= 0.7 -> 0.8
        # Moderate progression
        sp_ratio >= 0.5 -> 0.6
        # Low progression
        true -> 0.3
      end
    else
      0.5
    end
  end

  defp calculate_skill_focus_score(total_sp) do
    # Simplified skill focus assessment
    # In reality, this would analyze actual skill distributions
    cond do
      # High SP suggests focused training
      total_sp >= 50_000_000 -> 0.9
      # Medium-high SP
      total_sp >= 20_000_000 -> 0.8
      # Medium SP
      total_sp >= 10_000_000 -> 0.7
      # Low-medium SP
      total_sp >= 5_000_000 -> 0.6
      # Low SP
      true -> 0.4
    end
  end

  defp determine_skill_focus(total_sp) do
    # Simplified skill focus determination
    case rem(total_sp, 5) do
      0 -> :combat_specialist
      1 -> :support_specialist
      2 -> :exploration_specialist
      3 -> :logistics_specialist
      4 -> :generalist
    end
  end

  defp identify_red_flags(corp_history, killboard_analysis, opsec_assessment) do
    initial_red_flags = []

    # Corporation history red flags
    corp_red_flags = initial_red_flags ++ corp_history.suspicious_patterns

    # OpSec red flags
    combined_red_flags =
      corp_red_flags ++
        Enum.filter(opsec_assessment.identified_risks, &(&1.severity in [:critical, :high]))

    combined_red_flags
  end

  defp identify_green_flags(corp_history, killboard_analysis, wh_experience) do
    initial_green_flags = []

    # Stable corporation history
    corp_stability_flags =
      if corp_history.stability_rating in [:stable, :very_stable] do
        [
          %{type: :stable_corp_history, description: "Stable corporation history"}
          | initial_green_flags
        ]
      else
        initial_green_flags
      end

    # Good wormhole experience
    wh_experience_flags =
      if wh_experience.experience_level in [:expert, :experienced] do
        [
          %{type: :wormhole_experience, description: "Extensive wormhole experience"}
          | corp_stability_flags
        ]
      else
        corp_stability_flags
      end

    # High activity
    activity_flags =
      if killboard_analysis.activity_level in [:very_active, :active] do
        [%{type: :high_activity, description: "High PvP activity level"} | wh_experience_flags]
      else
        wh_experience_flags
      end

    activity_flags
  end

  defp identify_improvement_areas(vetting_scores) do
    []
    |> maybe_add_wormhole_area(vetting_scores.wormhole_experience_score)
    |> maybe_add_pvp_area(vetting_scores.killboard_score)
    |> maybe_add_corp_area(vetting_scores.corp_history_score)
  end

  defp maybe_add_wormhole_area(areas, wormhole_score) do
    if wormhole_score < 0.5 do
      [:wormhole_experience | areas]
    else
      areas
    end
  end

  defp maybe_add_pvp_area(areas, killboard_score) do
    if killboard_score < 0.5 do
      [:pvp_activity | areas]
    else
      areas
    end
  end

  defp maybe_add_corp_area(areas, corp_history_score) do
    if corp_history_score < 0.7 do
      [:corporation_stability | areas]
    else
      areas
    end
  end

  defp generate_detailed_recommendations(vetting_report) do
    recommendations = []

    case vetting_report.recommendation do
      :approve ->
        ["Standard recruitment process", "Normal trial period recommended"]

      :strong_approve ->
        ["Fast-track recruitment", "Consider for leadership roles", "Minimal trial period needed"]

      :conditional_approval ->
        ["Extended trial period required"] ++
          generate_conditional_recommendations(vetting_report)

      :review_required ->
        ["Manual review by leadership required"] ++
          generate_review_recommendations(vetting_report)

      :reject ->
        ["Recruitment not recommended"] ++
          generate_rejection_recommendations(vetting_report)
    end
  end

  defp generate_conditional_recommendations(vetting_report) do
    []
    |> maybe_add_background_verification(vetting_report.overall_risk_score)
    |> maybe_add_mentor_assignment(vetting_report.vetting_scores.wormhole_experience_score)
  end

  defp maybe_add_background_verification(recommendations, risk_score) do
    if risk_score > 0.3 do
      ["Additional background verification required" | recommendations]
    else
      recommendations
    end
  end

  defp maybe_add_mentor_assignment(recommendations, wormhole_score) do
    if wormhole_score < 0.3 do
      ["Assign experienced mentor for wormhole operations" | recommendations]
    else
      recommendations
    end
  end

  defp generate_review_recommendations(vetting_report) do
    ["Leadership review of red flags required", "Consider probationary membership"]
  end

  defp generate_rejection_recommendations(vetting_report) do
    high_risk_factors =
      Enum.filter(vetting_report.red_flags, &(&1.severity in [:critical, :high]))

    case length(high_risk_factors) do
      0 -> ["Insufficient qualifications for wormhole operations"]
      _ -> ["High security risk factors identified", "Consider permanent blacklist"]
    end
  end

  defp update_vetting_metrics(state, vetting_report, vetting_time) do
    recommendation_updated_metrics =
      case vetting_report.recommendation do
        rec when rec in [:approve, :strong_approve] ->
          %{state.metrics | approved_candidates: state.metrics.approved_candidates + 1}

        :reject ->
          %{state.metrics | rejected_candidates: state.metrics.rejected_candidates + 1}

        _ ->
          %{state.metrics | pending_reviews: state.metrics.pending_reviews + 1}
      end

    total_vettings_updated_metrics = %{
      recommendation_updated_metrics
      | total_vettings: recommendation_updated_metrics.total_vettings + 1
    }

    new_vetting_times = [vetting_time | Enum.take(state.recent_vetting_times, 99)]

    %{
      state
      | metrics: total_vettings_updated_metrics,
        recent_vetting_times: new_vetting_times
    }
  end

  defp generate_vetting_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
