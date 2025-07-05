defmodule EveDmv.Intelligence.Analyzers.WHVettingAnalyzer do
  @moduledoc """
  Simplified wormhole vetting analysis for corporation recruitment.

  Provides focused analysis of potential recruits with clear risk assessment
  and recommendation generation without over-engineering.

  Implements the Intelligence.Analyzer behavior for consistent interface and telemetry.
  """

  use EveDmv.Intelligence.Analyzer

  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.WhSpace.Vetting, as: WHVetting
  alias EveDmv.Killmails.Participant
  alias EveDmv.Intelligence.Core.{CacheHelper, TimeoutHelper, ValidationHelper, Config}

  # Behavior implementations

  @impl true
  def analysis_type, do: :vetting

  @impl true
  def validate_params(character_id, opts) do
    ValidationHelper.validate_character_analysis(character_id, opts)
  end

  @impl true
  def analyze(character_id, opts \\ %{}) do
    cache_ttl = Config.get_cache_ttl(:vetting)

    CacheHelper.get_or_compute(:vetting, character_id, cache_ttl, fn ->
      do_analyze_character(character_id, opts)
    end)
  end

  @impl true
  def invalidate_cache(character_id) do
    CacheHelper.invalidate_analysis(:vetting, character_id)
  end

  @doc """
  Legacy interface for backwards compatibility.
  """
  def analyze_character(character_id, requested_by_id \\ nil) do
    opts = if requested_by_id, do: %{requested_by_id: requested_by_id}, else: %{}

    case analyze_with_telemetry(character_id, opts) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error("Vetting analysis failed for character #{character_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Calculate J-space experience from killmail data.

  Analyzes wormhole activity patterns and competency indicators.
  """
  @spec calculate_j_space_experience(list()) :: map()
  def calculate_j_space_experience(killmails) when is_list(killmails) do
    j_space_kills = Enum.filter(killmails, &is_j_space_system?(&1.solar_system_id))

    if Enum.empty?(j_space_kills) do
      %{
        experience_level: :none,
        j_space_kills: 0,
        j_space_ratio: 0.0,
        wormhole_competency: :unknown,
        experience_score: 0
      }
    else
      total_kills = length(killmails)
      j_space_count = length(j_space_kills)
      j_space_ratio = j_space_count / total_kills

      %{
        experience_level: classify_experience_level(j_space_ratio, j_space_count),
        j_space_kills: j_space_count,
        j_space_ratio: j_space_ratio,
        wormhole_competency: assess_wormhole_competency(j_space_kills),
        experience_score: calculate_experience_score(j_space_ratio, j_space_count)
      }
    end
  end

  @doc """
  Analyze security risks based on character and employment data.
  """
  @spec analyze_security_risks(map(), list()) :: map()
  def analyze_security_risks(character_data, employment_history) do
    age_risk = assess_character_age_risk(character_data)
    employment_risk = assess_employment_risk(employment_history)
    pattern_risk = assess_pattern_risk(character_data, employment_history)

    total_risk = age_risk + employment_risk + pattern_risk

    %{
      total_risk_score: total_risk,
      age_risk: age_risk,
      employment_risk: employment_risk,
      pattern_risk: pattern_risk,
      risk_level: classify_risk_level(total_risk),
      risk_factors: identify_risk_factors(age_risk, employment_risk, pattern_risk)
    }
  end

  @doc """
  Detect eviction group associations from killmail patterns.
  """
  @spec detect_eviction_groups(list()) :: map()
  def detect_eviction_groups(killmails) when is_list(killmails) do
    # Known eviction group corporations/alliances (simplified)
    eviction_corps =
      MapSet.new([
        # Add known eviction group corp IDs here - using placeholder values
        98_000_001,
        98_000_002,
        98_000_003
      ])

    eviction_activity =
      killmails
      |> Enum.filter(fn km ->
        has_eviction_group_participation?(km.participants, eviction_corps)
      end)

    %{
      eviction_group_associations: length(eviction_activity),
      has_eviction_ties: length(eviction_activity) > 0,
      eviction_ratio:
        if(length(killmails) > 0, do: length(eviction_activity) / length(killmails), else: 0),
      threat_level: classify_eviction_threat(length(eviction_activity))
    }
  end

  @doc """
  Calculate small gang competency from killmail analysis.
  """
  @spec calculate_small_gang_competency(list()) :: map()
  def calculate_small_gang_competency(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{competency_level: :unknown, competency_score: 0}
    else
      small_gang_kills = Enum.filter(killmails, &is_small_gang_kill?/1)
      competency_score = calculate_competency_score(small_gang_kills, killmails)

      %{
        competency_level: classify_competency_level(competency_score),
        competency_score: competency_score,
        small_gang_ratio: length(small_gang_kills) / length(killmails),
        total_small_gang_kills: length(small_gang_kills)
      }
    end
  end

  @doc """
  Generate recruitment recommendation based on analysis.
  """
  @spec generate_recommendation(map()) :: atom()
  def generate_recommendation(analysis_data) do
    risk_score = Map.get(analysis_data, :risk_score, 100)
    competency = Map.get(analysis_data, :competency_assessment, %{})
    j_space_exp = Map.get(analysis_data, :j_space_experience, %{})

    competency_score = Map.get(competency, :competency_score, 0)
    experience_score = Map.get(j_space_exp, :experience_score, 0)

    cond do
      risk_score > 75 -> :reject
      risk_score > 50 and (competency_score < 30 or experience_score < 20) -> :reject
      risk_score > 30 -> :caution
      experience_score > 60 and competency_score > 60 -> :accept
      experience_score > 40 and competency_score > 40 -> :caution
      true -> :investigate
    end
  end

  @doc """
  Format analysis summary for display.
  """
  @spec format_analysis_summary(map()) :: String.t()
  def format_analysis_summary(analysis) do
    recommendation = Map.get(analysis, :recommendation, :unknown)
    risk_score = Map.get(analysis, :risk_score, 0)
    j_space_exp = Map.get(analysis, :j_space_experience, %{})
    experience_level = Map.get(j_space_exp, :experience_level, :unknown)

    """
    Vetting Analysis Summary:
    - Recommendation: #{recommendation}
    - Risk Score: #{risk_score}/100
    - J-Space Experience: #{experience_level}
    - Analysis Date: #{Map.get(analysis, :analysis_timestamp, "Unknown")}
    """
  end

  @doc """
  Classify system type (J-space, K-space, etc).
  """
  @spec classify_system_type(integer()) :: atom()
  def classify_system_type(system_id) when is_integer(system_id) do
    cond do
      system_id >= 31_000_000 and system_id < 32_000_000 -> :j_space
      system_id >= 30_000_000 and system_id < 31_000_000 -> :k_space
      true -> :unknown
    end
  end

  def classify_system_type(_), do: :unknown

  # Private implementation functions

  defp do_analyze_character(character_id, opts) do
    requested_by_id = Map.get(opts, :requested_by_id)

    with {:ok, character_info} <-
           TimeoutHelper.with_default_timeout(fn -> get_character_info(character_id) end, :api),
         {:ok, killmails} <-
           TimeoutHelper.with_default_timeout(
             fn -> get_character_killmails(character_id) end,
             :query
           ),
         {:ok, employment_history} <-
           TimeoutHelper.with_default_timeout(
             fn -> get_employment_history(character_id) end,
             :api
           ) do
      perform_vetting_analysis(
        character_id,
        character_info,
        killmails,
        employment_history,
        requested_by_id
      )
    else
      {:error, :character_not_found} ->
        {:error, "Character not found in ESI"}

      {:error, reason} ->
        {:error, "Failed to gather vetting analysis data: #{inspect(reason)}"}
    end
  end

  defp perform_vetting_analysis(
         character_id,
         character_info,
         killmails,
         employment_history,
         requested_by_id
       ) do
    try do
      # Perform simplified analysis
      j_space_experience = calculate_j_space_experience(killmails)
      security_risks = analyze_security_risks(character_info, employment_history)
      eviction_groups = detect_eviction_groups(killmails)
      competency = calculate_small_gang_competency(killmails)

      # Generate risk score and recommendation
      risk_score = calculate_risk_score(j_space_experience, security_risks, eviction_groups)
      # Create temporary analysis data for recommendation
      temp_analysis = %{
        risk_score: risk_score,
        competency_assessment: competency,
        j_space_experience: j_space_experience
      }

      recommendation = generate_recommendation(temp_analysis)

      analysis = %{
        character_id: character_id,
        character_name: character_info.name,
        risk_score: risk_score,
        recommendation: recommendation,
        confidence_score: calculate_confidence(killmails, employment_history),
        j_space_experience: j_space_experience,
        security_risks: security_risks,
        eviction_group_detection: eviction_groups,
        competency_assessment: competency,
        analysis_timestamp: DateTime.utc_now(),
        requested_by_id: requested_by_id
      }

      # Save analysis to database
      save_vetting_analysis(analysis)

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Error in vetting analysis calculation: #{inspect(error)}")
        {:error, "Vetting analysis calculation failed"}
    end
  end

  defp get_character_info(character_id) do
    case EsiClient.get_character(character_id) do
      {:ok, character} -> {:ok, character}
      {:error, :not_found} -> {:error, :character_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_character_killmails(character_id) do
    # Simplified killmail retrieval - last 30 days
    case Ash.read(Participant, actor: nil, character_id: character_id, domain: Api) do
      {:ok, participants} ->
        killmails = Enum.map(participants, & &1.killmail)
        {:ok, killmails}

      {:error, reason} ->
        Logger.warning("Could not fetch killmails for #{character_id}: #{inspect(reason)}")
        {:ok, []}
    end
  rescue
    error ->
      Logger.warning("Error fetching killmails: #{inspect(error)}")
      {:ok, []}
  end

  defp get_employment_history(character_id) do
    case EsiClient.get_character_employment_history(character_id) do
      {:ok, history} ->
        {:ok, history}

      {:error, reason} ->
        Logger.warning("Could not fetch employment history: #{inspect(reason)}")
        {:ok, []}
    end
  rescue
    error ->
      Logger.warning("Error fetching employment history: #{inspect(error)}")
      {:ok, []}
  end

  defp is_j_space_system?(system_id) do
    classify_system_type(system_id) == :j_space
  end

  defp classify_experience_level(j_space_ratio, j_space_count) do
    cond do
      j_space_count > 50 and j_space_ratio > 0.6 -> :expert
      j_space_count > 20 and j_space_ratio > 0.4 -> :experienced
      j_space_count > 5 and j_space_ratio > 0.2 -> :moderate
      j_space_count > 0 -> :beginner
      true -> :none
    end
  end

  defp assess_wormhole_competency(j_space_kills) do
    if length(j_space_kills) > 10 do
      :competent
    else
      :developing
    end
  end

  defp calculate_experience_score(j_space_ratio, j_space_count) do
    ratio_score = min(50, j_space_ratio * 100)
    count_score = min(50, j_space_count * 2)
    round(ratio_score + count_score)
  end

  defp assess_character_age_risk(character_data) do
    # Placeholder character age risk assessment
    creation_date = Map.get(character_data, :birthday, DateTime.utc_now())
    age_days = DateTime.diff(DateTime.utc_now(), creation_date, :day)

    cond do
      # Very new character
      age_days < 30 -> 30
      # New character
      age_days < 90 -> 20
      # Young character
      age_days < 365 -> 10
      # Established character
      true -> 0
    end
  end

  defp assess_employment_risk(employment_history) do
    if length(employment_history) > 5 do
      # High corporation turnover
      15
    else
      0
    end
  end

  defp assess_pattern_risk(_character_data, _employment_history) do
    # Placeholder pattern risk assessment
    0
  end

  defp classify_risk_level(total_risk) do
    cond do
      total_risk > 50 -> :high
      total_risk > 25 -> :medium
      true -> :low
    end
  end

  defp identify_risk_factors(age_risk, employment_risk, pattern_risk) do
    []
    |> maybe_add_risk_factor(age_risk > 20, "New character")
    |> maybe_add_risk_factor(employment_risk > 10, "High corporation turnover")
    |> maybe_add_risk_factor(pattern_risk > 15, "Suspicious patterns detected")
  end

  defp maybe_add_risk_factor(factors, true, factor), do: [factor | factors]
  defp maybe_add_risk_factor(factors, false, _factor), do: factors

  defp has_eviction_group_participation?(participants, eviction_corps) do
    Enum.any?(participants, fn participant ->
      MapSet.member?(eviction_corps, participant.corporation_id)
    end)
  end

  defp classify_eviction_threat(eviction_count) do
    cond do
      eviction_count > 5 -> :high
      eviction_count > 1 -> :medium
      true -> :low
    end
  end

  defp is_small_gang_kill?(killmail) do
    participant_count = length(killmail.participants || [])
    participant_count <= 10
  end

  defp calculate_competency_score(small_gang_kills, all_killmails) do
    if Enum.empty?(all_killmails) do
      0
    else
      small_gang_ratio = length(small_gang_kills) / length(all_killmails)
      round(small_gang_ratio * 100)
    end
  end

  defp classify_competency_level(score) do
    cond do
      score > 70 -> :high
      score > 40 -> :medium
      score > 10 -> :low
      true -> :minimal
    end
  end

  defp calculate_risk_score(j_space_experience, security_risks, eviction_groups) do
    # Base risk from security assessment
    base_risk = Map.get(security_risks, :total_risk_score, 0)

    # Reduce risk for J-space experience
    experience_bonus = Map.get(j_space_experience, :experience_score, 0) * -0.3

    # Increase risk for eviction group ties
    eviction_penalty = if Map.get(eviction_groups, :has_eviction_ties, false), do: 25, else: 0

    final_risk = base_risk + eviction_penalty + experience_bonus
    max(0, min(100, round(final_risk)))
  end

  defp calculate_confidence(killmails, employment_history) do
    # Base confidence on data availability
    killmail_factor = min(0.6, length(killmails) * 0.02)
    employment_factor = min(0.3, length(employment_history) * 0.1)
    # Minimum confidence
    base_confidence = 0.1

    killmail_factor + employment_factor + base_confidence
  end

  defp save_vetting_analysis(analysis) do
    # Save to WHVetting resource
    vetting_params = %{
      character_id: analysis.character_id,
      status: :analyzed,
      recommendation: analysis.recommendation,
      risk_score: analysis.risk_score,
      confidence_score: analysis.confidence_score,
      analysis_data: analysis,
      created_at: DateTime.utc_now()
    }

    case Ash.create(WHVetting, vetting_params, domain: Api) do
      {:ok, _vetting} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to save vetting analysis: #{inspect(reason)}")
        # Don't fail the analysis if save fails
        :ok
    end
  rescue
    error ->
      Logger.warning("Error saving vetting analysis: #{inspect(error)}")
      :ok
  end
end
