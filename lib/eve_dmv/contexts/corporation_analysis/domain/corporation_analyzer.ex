defmodule EveDmv.Contexts.CorporationAnalysis.Domain.CorporationAnalyzer do
  @moduledoc """
  Core corporation analysis service for EVE DMV.

  Provides comprehensive corporation analysis including member activity,
  organizational health, recruitment effectiveness, and leadership assessment.
  """

  use GenServer
  use EveDmv.ErrorHandler
  alias EveDmv.Contexts.CorporationAnalysis.Analyzers.MemberActivityAnalyzer
  alias EveDmv.Contexts.CorporationAnalysis.Infrastructure.CorporationRepository
  alias EveDmv.Result
  alias EveDmv.Shared.MetricsCalculator
  # Import analyzers

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Perform comprehensive corporation analysis.
  """
  def analyze_corporation(corporation_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_corporation, corporation_id, opts}, 45_000)
  end

  @doc """
  Analyze multiple corporations in batch.
  """
  def analyze_corporations(corporation_ids, opts \\ []) when is_list(corporation_ids) do
    GenServer.call(__MODULE__, {:analyze_corporations, corporation_ids, opts}, 120_000)
  end

  @doc """
  Get specific analysis component for a corporation.
  """
  def get_analysis_component(corporation_id, component)
      when component in [:member_activity, :health, :leadership] do
    GenServer.call(__MODULE__, {:get_component, corporation_id, component})
  end

  @doc """
  Get corporation health score.
  """
  def get_health_score(corporation_id) do
    GenServer.call(__MODULE__, {:get_health_score, corporation_id})
  end

  @doc """
  Get analyzer metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      analysis_cache: %{},
      metrics: %{
        total_analyses: 0,
        cache_hits: 0,
        cache_misses: 0,
        average_analysis_time_ms: 0,
        corporation_health_distribution: %{
          excellent: 0,
          good: 0,
          fair: 0,
          poor: 0
        }
      },
      recent_analysis_times: []
    }

    Logger.info("CorporationAnalyzer started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_corporation, corporation_id, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Check cache first
    cache_key = generate_cache_key(corporation_id, opts)

    case Map.get(state.analysis_cache, cache_key) do
      %{timestamp: ts, data: data} when ts != nil ->
        if cache_valid?(ts, opts) do
          new_state = update_metrics(state, :cache_hit, 0)
          {:reply, {:ok, data}, new_state}
        else
          # Cache expired, perform analysis
          perform_and_cache_analysis(corporation_id, opts, cache_key, start_time, state)
        end

      _ ->
        # No cache, perform analysis
        perform_and_cache_analysis(corporation_id, opts, cache_key, start_time, state)
    end
  end

  @impl GenServer
  def handle_call({:analyze_corporations, corporation_ids, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Parallel batch analysis
    tasks =
      Enum.map(corporation_ids, fn corporation_id ->
        Task.async(fn ->
          {corporation_id, perform_corporation_analysis(corporation_id, opts)}
        end)
      end)

    # Collect results with timeout
    results = Task.await_many(tasks, 45_000)

    # Process results
    {successful, failed} =
      Enum.split_with(results, fn {_id, result} ->
        match?({:ok, _}, result)
      end)

    analysis_time = System.monotonic_time(:millisecond) - start_time
    new_state = update_metrics(state, :batch_analysis, analysis_time)

    batch_result = %{
      successful: Map.new(successful, fn {id, {:ok, data}} -> {id, data} end),
      failed: Map.new(failed, fn {id, {:error, reason}} -> {id, reason} end),
      total_count: length(corporation_ids),
      success_count: length(successful),
      failure_count: length(failed),
      analysis_time_ms: analysis_time
    }

    {:reply, {:ok, batch_result}, new_state}
  end

  @impl GenServer
  def handle_call({:get_component, corporation_id, component}, _from, state) do
    # Try to get from cache first
    cache_entries =
      Enum.filter(state.analysis_cache, fn {key, _} ->
        String.starts_with?(key, "#{corporation_id}:")
      end)

    case find_latest_component(cache_entries, component) do
      {:ok, component_data} ->
        {:reply, {:ok, component_data}, state}

      :not_found ->
        # Perform component-specific analysis
        result =
          case component do
            :member_activity -> MemberActivityAnalyzer.analyze(corporation_id)
            :health -> calculate_health_score(corporation_id)
            :leadership -> analyze_leadership(corporation_id)
          end

        {:reply, result, state}
    end
  end

  @impl GenServer
  def handle_call({:get_health_score, corporation_id}, _from, state) do
    case perform_corporation_analysis(corporation_id, []) do
      {:ok, analysis} ->
        health_score = Map.get(analysis, :health_score, 0.0)
        {:reply, {:ok, health_score}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = calculate_current_metrics(state)
    {:reply, metrics, state}
  end

  # Private functions

  defp perform_and_cache_analysis(corporation_id, opts, cache_key, start_time, state) do
    case perform_corporation_analysis(corporation_id, opts) do
      {:ok, analysis} ->
        analysis_time = System.monotonic_time(:millisecond) - start_time

        # Cache the result
        cache_entry = %{
          timestamp: DateTime.utc_now(),
          data: analysis
        }

        new_cache = Map.put(state.analysis_cache, cache_key, cache_entry)

        new_state =
          %{state | analysis_cache: new_cache}
          |> update_metrics(:cache_miss, analysis_time)
          |> update_health_distribution(analysis.activity_summary.health_rating)

        {:reply, {:ok, analysis}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp perform_corporation_analysis(corporation_id, opts) do
    with {:ok, base_data} <- gather_base_data(corporation_id),
         {:ok, member_activity} <- analyze_member_activity(corporation_id, base_data, opts) do
      analysis = %{
        corporation_id: corporation_id,
        timestamp: DateTime.utc_now(),
        member_activity: member_activity,
        health_score: calculate_corporation_health(member_activity),
        activity_summary: member_activity.activity_summary,
        recommendations: generate_corporation_recommendations(member_activity)
      }

      {:ok, analysis}
    end
  end

  defp gather_base_data(corporation_id) do
    case CorporationRepository.get_corporation_data(corporation_id) do
      {:ok, corporation_data} ->
        # Gather all necessary base data
        base_data = %{
          corporation_data: %{corporation_id => corporation_data},
          member_statistics: %{
            corporation_id => CorporationRepository.get_member_statistics(corporation_id)
          }
        }

        {:ok, base_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_member_activity(corporation_id, base_data, _opts) do
    MemberActivityAnalyzer.analyze(corporation_id, base_data)
  end

  defp calculate_corporation_health(member_activity) do
    # Calculate overall corporation health score
    activity_score = member_activity.overall_activity.activity_rate * 40
    engagement_score = member_activity.member_engagement.overall_engagement_score * 0.3
    leadership_score = member_activity.leadership_activity.leadership_health_score * 0.2
    retention_score = member_activity.retention_indicators.monthly_retention_rate * 10

    Float.round(activity_score + engagement_score + leadership_score + retention_score, 1)
  end

  defp generate_corporation_recommendations(member_activity) do
    initial_recommendations = []

    # Activity-based recommendations
    activity_recommendations =
      if member_activity.overall_activity.activity_rate < 0.5 do
        ["Focus on member recruitment and retention" | initial_recommendations]
      else
        initial_recommendations
      end

    # Engagement recommendations
    engagement_recommendations =
      if member_activity.member_engagement.overall_engagement_score < 50 do
        ["Implement member engagement programs" | activity_recommendations]
      else
        activity_recommendations
      end

    # Leadership recommendations
    leadership_recommendations =
      if member_activity.leadership_activity.leadership_health_score < 70 do
        ["Strengthen leadership team and activities" | engagement_recommendations]
      else
        engagement_recommendations
      end

    # Timezone coverage recommendations
    final_recommendations =
      if length(member_activity.timezone_coverage.coverage_gaps) > 2 do
        ["Improve timezone coverage through targeted recruitment" | leadership_recommendations]
      else
        leadership_recommendations
      end

    final_recommendations
  end

  defp calculate_health_score(corporation_id) do
    case CorporationRepository.get_corporation_data(corporation_id) do
      {:ok, corp_data} ->
        member_stats = CorporationRepository.get_member_statistics(corporation_id)

        # Simple health calculation
        total_members = corp_data.member_count || 0

        active_members =
          Enum.count(member_stats, fn member ->
            (member.recent_kills || 0) + (member.recent_losses || 0) > 0
          end)

        activity_rate = if total_members > 0, do: active_members / total_members, else: 0.0
        health_score = activity_rate * 100

        Result.ok(health_score)

      {:error, reason} ->
        Result.error(:health_calculation_failed, reason)
    end
  end

  defp analyze_leadership(corporation_id) do
    member_stats = CorporationRepository.get_member_statistics(corporation_id)
    
    leadership_members =
      Enum.filter(member_stats, fn member ->
        member.corp_role && member.corp_role in ["CEO", "Director", "Personnel Manager"]
      end)

    leadership_analysis = %{
      leadership_count: length(leadership_members),
      active_leadership_count:
        Enum.count(leadership_members, fn leader ->
          (leader.recent_kills || 0) + (leader.recent_losses || 0) > 0
        end),
      leadership_activity_score: calculate_leadership_activity_score(leadership_members)
    }

    Result.ok(leadership_analysis)
  end

  defp calculate_leadership_activity_score(leadership_members) do
    if Enum.empty?(leadership_members) do
      0.0
    else
      total_score =
        leadership_members
        |> Enum.map(fn leader ->
          recent_activity = (leader.recent_kills || 0) + (leader.recent_losses || 0)
          min(100, recent_activity * 2)
        end)
        |> Enum.sum()

      total_score / length(leadership_members)
    end
  end

  defp generate_cache_key(corporation_id, opts) do
    opts_hash = :erlang.phash2(opts)
    "#{corporation_id}:#{opts_hash}"
  end

  defp cache_valid?(timestamp, opts) do
    ttl = Keyword.get(opts, :cache_ttl_seconds, 600)
    age = DateTime.diff(DateTime.utc_now(), timestamp, :second)
    age < ttl
  end

  defp find_latest_component(cache_entries, component) do
    matching =
      cache_entries
      |> Enum.filter(fn {_, %{data: data}} ->
        Map.has_key?(data, component_key(component))
      end)
      |> Enum.sort_by(fn {_, %{timestamp: ts}} -> ts end, {:desc, DateTime})

    case matching do
      [{_, %{data: data}} | _] ->
        {:ok, Map.get(data, component_key(component))}

      [] ->
        :not_found
    end
  end

  defp component_key(:member_activity), do: :member_activity
  defp component_key(:health), do: :health_score
  defp component_key(:leadership), do: :leadership_activity

  defp update_metrics(state, event_type, duration) do
    new_metrics =
      case event_type do
        :cache_hit ->
          %{state.metrics | cache_hits: state.metrics.cache_hits + 1}

        :cache_miss ->
          %{
            state.metrics
            | cache_misses: state.metrics.cache_misses + 1,
              total_analyses: state.metrics.total_analyses + 1
          }

        :batch_analysis ->
          %{state.metrics | total_analyses: state.metrics.total_analyses + 1}
      end

    # Update timing metrics
    new_times =
      if duration > 0 do
        [duration | Enum.take(state.recent_analysis_times, 99)]
      else
        state.recent_analysis_times
      end

    %{state | metrics: new_metrics, recent_analysis_times: new_times}
  end

  defp update_health_distribution(state, health_rating) do
    new_distribution =
      Map.update(state.metrics.corporation_health_distribution, health_rating, 1, &(&1 + 1))

    new_metrics = %{state.metrics | corporation_health_distribution: new_distribution}
    %{state | metrics: new_metrics}
  end

  # Metrics calculation delegated to shared module
  defp calculate_current_metrics(state) do
    MetricsCalculator.calculate_current_metrics(state)
  end
end
