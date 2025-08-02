defmodule EveDmv.Contexts.Corporation.Core.CorporationAnalyzer do
  @moduledoc """
  Main corporation analysis engine that provides comprehensive analysis
  of corporation statistics, member composition, and organizational health.

  Consolidates functionality from:
  - Corporation Analysis domain analyzers
  - Corporation Intelligence analyzers
  """

  use GenServer

  alias EveDmv.Contexts.Corporation.Core.MemberActivityAnalyzer
  alias EveDmv.Contexts.Corporation.Core.OrganizationalHealthAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  alias EveDmv.Platform.Database.CorporationRepository

  require Logger

  @analysis_timeout 60_000
  @cache_ttl :timer.hours(2)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Perform comprehensive corporation analysis.

  Options:
    - include_members: Include detailed member analysis
    - include_health: Include organizational health assessment
    - include_threats: Include threat assessment
    - time_range: Time period for analysis
  """
  def analyze_corporation(corporation_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_corporation, corporation_id, opts}, @analysis_timeout)
  end

  @doc """
  Get basic corporation statistics.
  """
  def get_corporation_stats(corporation_id) do
    case CorporationCache.get({:corporation_stats, corporation_id}) do
      nil ->
        CorporationRepository.get_corporation_stats(corporation_id)

      stats ->
        {:ok, stats}
    end
  end

  @doc """
  Get comprehensive corporation profile.
  """
  def get_corporation_profile(corporation_id) do
    GenServer.call(__MODULE__, {:get_profile, corporation_id}, @analysis_timeout)
  end

  @doc """
  Calculate corporation threat level based on member analysis.
  """
  def calculate_corporation_threat_level(corporation_id) do
    with {:ok, member_data} <- get_member_threat_data(corporation_id) do
      threat_level = %{
        overall_threat: calculate_overall_threat(member_data),
        member_count: length(member_data),
        high_threat_members: count_high_threat_members(member_data),
        average_member_threat: calculate_average_threat(member_data),
        threat_distribution: analyze_threat_distribution(member_data),
        combat_readiness: assess_combat_readiness(member_data)
      }

      {:ok, threat_level}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :member_data_unavailable}
    end
  end

  @doc """
  Get intelligence summary for corporation members.
  """
  def get_member_intelligence_summary(corporation_id) do
    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id) do
      summary = %{
        total_members: length(members),
        active_members: count_active_members(members),
        veteran_members: count_veteran_members(members),
        recent_recruits: count_recent_recruits(members),
        intelligence_gaps: identify_intelligence_gaps(members),
        key_personnel: identify_key_personnel(members)
      }

      {:ok, summary}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :members_unavailable}
    end
  end

  @doc """
  Assess threats posed by corporation.
  """
  def assess_corporation_threats(corporation_id) do
    with {:ok, analysis} <- analyze_corporation(corporation_id, include_threats: true) do
      threats = %{
        military_threat: analysis.combat_capability,
        economic_threat: analysis.economic_power,
        intelligence_threat: analysis.intelligence_capability,
        diplomatic_threat: analysis.alliance_strength,
        overall_assessment: determine_overall_threat_assessment(analysis)
      }

      {:ok, threats}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :analysis_failed}
    end
  end

  @doc """
  Analyze multiple enemy corporations.
  """
  def analyze_enemy_corporations(corporation_ids) do
    corporation_ids
    |> Task.async_stream(
      fn corp_id ->
        {corp_id, analyze_corporation(corp_id, include_threats: true)}
      end,
      max_concurrency: 5,
      timeout: @analysis_timeout
    )
    |> Enum.reduce({[], []}, fn
      {:ok, {corp_id, {:ok, analysis}}}, {successes, failures} ->
        {[{corp_id, analysis} | successes], failures}

      {:ok, {corp_id, {:error, reason}}}, {successes, failures} ->
        {successes, [{corp_id, reason} | failures]}

      {:exit, reason}, {successes, failures} ->
        Logger.error("Enemy corporation analysis failed: #{inspect(reason)}")
        {successes, failures}
    end)
    |> then(fn {successes, failures} ->
      {:ok,
       %{
         analyses: successes |> Enum.reverse() |> Map.new(),
         failures: Enum.reverse(failures),
         comparative_assessment: generate_comparative_assessment(successes)
       }}
    end)
  end

  @doc """
  Batch analyze multiple corporations.
  """
  def analyze_batch(corporation_ids, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_batch, corporation_ids, opts}, :infinity)
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    state = %{
      active_analyses: %{},
      metrics: %{
        total_analyses: 0,
        cache_hits: 0,
        cache_misses: 0
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_corporation, corporation_id, opts}, from, state) do
    cache_key = {:corporation_analysis, corporation_id, opts}

    case CorporationCache.get(cache_key) do
      nil ->
        # Start async analysis
        task =
          Task.async(fn ->
            perform_corporation_analysis(corporation_id, opts)
          end)

        new_state = %{
          state
          | active_analyses: Map.put(state.active_analyses, task.ref, {from, cache_key}),
            metrics: Map.update!(state.metrics, :cache_misses, &(&1 + 1))
        }

        {:noreply, new_state}

      cached_result ->
        new_state = %{state | metrics: Map.update!(state.metrics, :cache_hits, &(&1 + 1))}

        {:reply, {:ok, cached_result}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_profile, corporation_id}, _from, state) do
    profile = build_corporation_profile(corporation_id)
    {:reply, profile, state}
  end

  @impl GenServer
  def handle_call({:analyze_batch, corporation_ids, opts}, _from, state) do
    results =
      corporation_ids
      |> Task.async_stream(
        fn corp_id ->
          {corp_id, perform_corporation_analysis(corp_id, opts)}
        end,
        max_concurrency: 5,
        timeout: @analysis_timeout
      )
      |> Enum.reduce(%{successes: [], failures: []}, fn
        {:ok, {corp_id, {:ok, analysis}}}, acc ->
          %{acc | successes: [{corp_id, analysis} | acc.successes]}

        {:ok, {corp_id, {:error, reason}}}, acc ->
          %{acc | failures: [{corp_id, reason} | acc.failures]}

        {:exit, _reason}, acc ->
          acc
      end)

    {:reply, {:ok, results}, state}
  end

  @impl GenServer
  def handle_info({ref, result}, state) when is_reference(ref) do
    case Map.get(state.active_analyses, ref) do
      {from, cache_key} ->
        # Cache the result
        if match?({:ok, _}, result) do
          {:ok, analysis} = result
          CorporationCache.put(cache_key, analysis, ttl: @cache_ttl)
        end

        # Reply to caller
        GenServer.reply(from, result)

        # Update state
        new_state = %{
          state
          | active_analyses: Map.delete(state.active_analyses, ref),
            metrics: Map.update!(state.metrics, :total_analyses, &(&1 + 1))
        }

        {:noreply, new_state}

      nil ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    new_state = %{state | active_analyses: Map.delete(state.active_analyses, ref)}

    {:noreply, new_state}
  end

  # Private Functions

  defp perform_corporation_analysis(corporation_id, opts) do
    with {:ok, basic_data} <- gather_basic_corporation_data(corporation_id),
         {:ok, member_data} <- maybe_gather_member_data(corporation_id, opts),
         {:ok, health_data} <- maybe_gather_health_data(corporation_id, opts),
         {:ok, threat_data} <- maybe_gather_threat_data(corporation_id, opts) do
      analysis = build_comprehensive_analysis(basic_data, member_data, health_data, threat_data)
      {:ok, analysis}
    else
      {:error, reason} = error ->
        Logger.error("Corporation analysis failed for #{corporation_id}: #{inspect(reason)}")
        error
    end
  end

  defp gather_basic_corporation_data(corporation_id) do
    with {:ok, corp_info} <- CorporationRepository.get_corporation_info(corporation_id),
         {:ok, corp_stats} <- CorporationRepository.get_corporation_stats(corporation_id) do
      basic_data = %{
        corporation_id: corporation_id,
        corporation_info: corp_info,
        corporation_stats: corp_stats,
        member_count: corp_stats.member_count || 0,
        total_kills: corp_stats.total_kills || 0,
        total_losses: corp_stats.total_losses || 0,
        isk_efficiency: corp_stats.isk_efficiency || 0,
        avg_member_age: corp_stats.avg_member_age || 0
      }

      {:ok, basic_data}
    end
  end

  defp maybe_gather_member_data(corporation_id, opts) do
    if Keyword.get(opts, :include_members, true) do
      MemberActivityAnalyzer.analyze_member_activity(corporation_id)
    else
      {:ok, %{}}
    end
  end

  defp maybe_gather_health_data(corporation_id, opts) do
    if Keyword.get(opts, :include_health, true) do
      OrganizationalHealthAnalyzer.assess_organizational_health(corporation_id)
    else
      {:ok, %{}}
    end
  end

  defp maybe_gather_threat_data(corporation_id, opts) do
    if Keyword.get(opts, :include_threats, false) do
      calculate_corporation_threat_level(corporation_id)
    else
      {:ok, %{}}
    end
  end

  defp build_comprehensive_analysis(basic_data, member_data, health_data, threat_data) do
    %{
      corporation_id: basic_data.corporation_id,
      basic_info: extract_basic_info(basic_data),
      member_analysis: member_data,
      organizational_health: health_data,
      threat_assessment: threat_data,
      combat_capability: assess_combat_capability(basic_data, member_data),
      economic_power: assess_economic_power(basic_data, member_data),
      intelligence_capability: assess_intelligence_capability(member_data),
      alliance_strength: assess_alliance_strength(basic_data),
      strategic_assessment: generate_strategic_assessment(basic_data, member_data, health_data),
      analyzed_at: DateTime.utc_now()
    }
  end

  defp extract_basic_info(basic_data) do
    corp_info = basic_data.corporation_info
    corp_stats = basic_data.corporation_stats

    %{
      corporation_name: corp_info.corporation_name,
      ticker: corp_info.ticker,
      alliance_id: corp_info.alliance_id,
      alliance_name: corp_info.alliance_name,
      member_count: basic_data.member_count,
      founded_date: corp_info.founded_date,
      ceo_id: corp_info.ceo_id,
      headquarters: corp_info.headquarters,
      activity_level: classify_activity_level(corp_stats),
      public_info: corp_info.public_info || %{}
    }
  end

  defp classify_activity_level(corp_stats) do
    weekly_kills = (corp_stats.total_kills || 0) / max(corp_stats.weeks_active || 1, 1)

    cond do
      weekly_kills >= 100 -> :very_active
      weekly_kills >= 50 -> :active
      weekly_kills >= 20 -> :moderate
      weekly_kills >= 5 -> :low
      true -> :inactive
    end
  end

  defp assess_combat_capability(basic_data, member_data) do
    base_capability = calculate_base_combat_capability(basic_data)
    member_multiplier = calculate_member_combat_multiplier(member_data)

    %{
      base_score: base_capability,
      member_multiplier: member_multiplier,
      overall_score: Float.round(base_capability * member_multiplier, 2),
      assessment: categorize_combat_capability(base_capability * member_multiplier)
    }
  end

  defp calculate_base_combat_capability(basic_data) do
    # Base calculation from corporation statistics
    kd_ratio =
      if basic_data.total_losses > 0 do
        basic_data.total_kills / basic_data.total_losses
      else
        basic_data.total_kills * 1.0
      end

    member_factor = :math.log10(max(basic_data.member_count, 1)) * 10

    activity_factor =
      case classify_activity_level(basic_data.corporation_stats) do
        :very_active -> 30
        :active -> 25
        :moderate -> 15
        :low -> 8
        :inactive -> 2
      end

    kd_score = min(kd_ratio * 15, 40)
    total = kd_score + member_factor + activity_factor

    Float.round(total, 2)
  end

  defp calculate_member_combat_multiplier(member_data) do
    if Map.has_key?(member_data, :combat_effectiveness) do
      1.0 + member_data.combat_effectiveness / 100
    else
      1.0
    end
  end

  defp categorize_combat_capability(score) do
    cond do
      score >= 80 -> :elite_military_corporation
      score >= 65 -> :strong_military_presence
      score >= 50 -> :competent_fighters
      score >= 30 -> :moderate_capability
      true -> :limited_combat_ability
    end
  end

  defp assess_economic_power(basic_data, member_data) do
    # Economic assessment based on ISK efficiency and activity
    isk_efficiency = basic_data.corporation_stats.isk_efficiency || 0
    member_count = basic_data.member_count

    base_score = isk_efficiency * 0.6 + member_count * 0.4

    # Factor in member economic activity if available
    economic_multiplier =
      if Map.has_key?(member_data, :economic_activity) do
        1.0 + member_data.economic_activity / 200
      else
        1.0
      end

    total_score = base_score * economic_multiplier

    %{
      base_score: Float.round(base_score, 2),
      economic_multiplier: Float.round(economic_multiplier, 2),
      overall_score: Float.round(total_score, 2),
      assessment: categorize_economic_power(total_score)
    }
  end

  defp categorize_economic_power(score) do
    cond do
      score >= 80 -> :economic_powerhouse
      score >= 60 -> :financially_strong
      score >= 40 -> :stable_economy
      score >= 20 -> :developing_economy
      true -> :limited_resources
    end
  end

  defp assess_intelligence_capability(member_data) do
    # Intelligence capability based on member diversity and activity patterns
    # Default assumption
    base_capability = 50

    # Factor in member intelligence if available
    intelligence_score =
      if Map.has_key?(member_data, :intelligence_rating) do
        member_data.intelligence_rating
      else
        base_capability
      end

    %{
      score: intelligence_score,
      assessment: categorize_intelligence_capability(intelligence_score)
    }
  end

  defp categorize_intelligence_capability(score) do
    cond do
      score >= 80 -> :advanced_intelligence_network
      score >= 60 -> :good_intelligence_capability
      score >= 40 -> :basic_intelligence_operations
      score >= 20 -> :limited_intelligence
      true -> :minimal_intelligence_capability
    end
  end

  defp assess_alliance_strength(basic_data) do
    if basic_data.corporation_info.alliance_id do
      # Would normally query alliance data
      %{
        in_alliance: true,
        alliance_id: basic_data.corporation_info.alliance_id,
        alliance_name: basic_data.corporation_info.alliance_name,
        # Would calculate from alliance stats
        strength_rating: :unknown
      }
    else
      %{
        in_alliance: false,
        strength_rating: :independent
      }
    end
  end

  defp generate_strategic_assessment(basic_data, member_data, health_data) do
    initial_assessments = []

    # Activity assessment
    activity = classify_activity_level(basic_data.corporation_stats)
    activity_assessments = ["Activity level: #{activity}" | initial_assessments]

    # Size assessment
    size_category = categorize_corporation_size(basic_data.member_count)
    size_assessments = ["Corporation size: #{size_category}" | activity_assessments]

    # Health assessment
    health_assessments =
      if Map.has_key?(health_data, :overall_health) do
        ["Organizational health: #{health_data.overall_health}" | size_assessments]
      else
        size_assessments
      end

    # Combat readiness
    final_assessments =
      if Map.has_key?(member_data, :combat_readiness) do
        ["Combat readiness: #{member_data.combat_readiness}" | health_assessments]
      else
        health_assessments
      end

    Enum.reverse(final_assessments)
  end

  defp categorize_corporation_size(member_count) do
    cond do
      member_count >= 1000 -> :mega_corporation
      member_count >= 500 -> :large_corporation
      member_count >= 100 -> :medium_corporation
      member_count >= 20 -> :small_corporation
      true -> :micro_corporation
    end
  end

  defp build_corporation_profile(corporation_id) do
    with {:ok, analysis} <- analyze_corporation(corporation_id) do
      {:ok,
       %{
         corporation_id: corporation_id,
         analysis: analysis,
         profile_generated_at: DateTime.utc_now()
       }}
    end
  end

  defp get_member_threat_data(corporation_id) do
    # Would integrate with intelligence context to get member threat data
    case CorporationRepository.get_corporation_members(corporation_id) do
      {:ok, members} ->
        # Simulate threat data gathering
        threat_data =
          Enum.map(members, fn member ->
            %{
              character_id: member.character_id,
              # Would get from intelligence context
              threat_score: 50,
              threat_level: :moderate
            }
          end)

        {:ok, threat_data}

      error ->
        error
    end
  end

  defp calculate_overall_threat(member_data) do
    if Enum.empty?(member_data) do
      0
    else
      avg_threat =
        member_data
        |> Enum.map(& &1.threat_score)
        |> Enum.sum()
        |> Kernel./(length(member_data))

      # Factor in member count
      size_multiplier = :math.log10(length(member_data) + 1) / 3

      Float.round(avg_threat * (1 + size_multiplier), 2)
    end
  end

  defp count_high_threat_members(member_data) do
    Enum.count(member_data, fn member ->
      member.threat_level in [:high, :critical]
    end)
  end

  defp calculate_average_threat(member_data) do
    if Enum.empty?(member_data) do
      0
    else
      threat_scores = Enum.map(member_data, & &1.threat_score)
      Enum.sum(threat_scores) / length(threat_scores)
    end
  end

  defp analyze_threat_distribution(member_data) do
    member_data
    |> Enum.map(& &1.threat_level)
    |> Enum.frequencies()
  end

  defp assess_combat_readiness(member_data) do
    high_threat_ratio = count_high_threat_members(member_data) / max(length(member_data), 1)

    cond do
      high_threat_ratio > 0.3 -> :high_readiness
      high_threat_ratio > 0.15 -> :moderate_readiness
      high_threat_ratio > 0.05 -> :low_readiness
      true -> :minimal_readiness
    end
  end

  defp count_active_members(members) do
    # Would check recent activity
    # Simplified
    length(members)
  end

  defp count_veteran_members(members) do
    # Would check join dates and experience
    Enum.count(members, fn member ->
      # Simplified check
      member.join_date &&
        DateTimeUtils.diff(DateTime.utc_now(), member.join_date, :day) > 365
    end)
  end

  defp count_recent_recruits(members) do
    cutoff = DateTime.utc_now() |> DateTimeUtils.add(-30 * 24 * 60 * 60, :second)

    Enum.count(members, fn member ->
      member.join_date && DateTimeUtils.compare(member.join_date, cutoff) == :gt
    end)
  end

  defp identify_intelligence_gaps(members) do
    # Identify members with limited intelligence data
    initial_gaps = []

    # Check for members without recent activity data
    inactive_count =
      Enum.count(members, fn member ->
        is_nil(member.last_seen) ||
          DateTimeUtils.diff(DateTime.utc_now(), member.last_seen, :day) > 30
      end)

    final_gaps =
      if inactive_count > length(members) * 0.2 do
        ["High number of inactive/unknown members (#{inactive_count})" | initial_gaps]
      else
        initial_gaps
      end

    final_gaps
  end

  defp identify_key_personnel(members) do
    # Identify leadership and key members
    _key_members = []

    # CEO and directors (would need role data)
    key_members =
      Enum.filter(members, fn member ->
        member.roles && ("CEO" in member.roles || "Director" in member.roles)
      end)

    # High activity members
    active_members =
      Enum.filter(members, fn member ->
        member.recent_activity_score && member.recent_activity_score > 80
      end)

    key_members ++ Enum.take(active_members, 5)
  end

  defp determine_overall_threat_assessment(analysis) do
    factors = [
      analysis.combat_capability.overall_score * 0.4,
      analysis.economic_power.overall_score * 0.2,
      analysis.intelligence_capability.score * 0.2,
      if(analysis.alliance_strength.in_alliance, do: 20, else: 0) * 0.2
    ]

    total_score = Enum.sum(factors)

    cond do
      total_score >= 80 -> :critical_threat
      total_score >= 65 -> :high_threat
      total_score >= 45 -> :moderate_threat
      total_score >= 25 -> :low_threat
      true -> :minimal_threat
    end
  end

  defp generate_comparative_assessment(corp_analyses) do
    if length(corp_analyses) < 2 do
      %{comparison: "Insufficient data for comparison"}
    else
      scores =
        Enum.map(corp_analyses, fn {_corp_id, analysis} ->
          analysis.combat_capability.overall_score
        end)

      %{
        highest_threat: Enum.max(scores),
        lowest_threat: Enum.min(scores),
        average_threat: Enum.sum(scores) / length(scores),
        threat_spread: Enum.max(scores) - Enum.min(scores)
      }
    end
  end
end
