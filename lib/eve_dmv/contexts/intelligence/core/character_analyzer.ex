defmodule EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer do
  @moduledoc """
  Comprehensive character analysis engine that combines player profiling
  with statistical analysis.

  Merges functionality from:
  - Character Intelligence character analysis
  - Player Profile player analyzer
  """

  use GenServer

  alias EveDmv.Cache
  alias EveDmv.Contexts.Intelligence.Core.BehavioralPatternAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.CombatStatsAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.PerformanceAnalyzer
  alias EveDmv.Contexts.Intelligence.Core.ShipPreferenceAnalyzer
  alias EveDmv.Database.CharacterRepository

  require Logger

  @analysis_timeout 30_000
  @cache_ttl :timer.hours(1)

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Perform comprehensive character analysis.

  Options:
    - include_combat_stats: Include detailed combat statistics
    - include_ship_prefs: Include ship preference analysis
    - include_behavior: Include behavioral patterns
    - include_performance: Include performance metrics
    - time_range: Time period for analysis
  """
  def analyze_character(character_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_character, character_id, opts}, @analysis_timeout)
  end

  @doc """
  Get cached character statistics.
  """
  def get_character_stats(character_id) do
    case Cache.get(:analysis, {:character_stats, character_id}) do
      nil ->
        # Fetch from database if not cached
        CharacterRepository.get_character_stats(character_id)

      stats ->
        {:ok, stats}
    end
  end

  @doc """
  Get comprehensive character profile.
  """
  def get_character_profile(character_id) do
    GenServer.call(__MODULE__, {:get_profile, character_id}, @analysis_timeout)
  end

  @doc """
  Classify pilot type based on behavior and preferences.
  """
  def classify_pilot_type(character_id) do
    with {:ok, analysis} <- analyze_character(character_id),
         {:ok, combat_stats} <- CombatStatsAnalyzer.analyze_combat_stats(character_id),
         {:ok, ship_prefs} <- ShipPreferenceAnalyzer.analyze_ship_preferences(character_id) do
      classification = determine_pilot_classification(analysis, combat_stats, ship_prefs)
      {:ok, classification}
    end
  end

  @doc """
  Analyze multiple characters in batch.
  """
  def analyze_batch(character_ids, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_batch, character_ids, opts}, :infinity)
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
  def handle_call({:analyze_character, character_id, opts}, from, state) do
    # Check cache first
    cache_key = {:character_analysis, character_id, opts}

    case Cache.get(:analysis, cache_key) do
      nil ->
        # Start async analysis
        task =
          Task.async(fn ->
            perform_character_analysis(character_id, opts)
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
  def handle_call({:get_profile, character_id}, _from, state) do
    profile = build_character_profile(character_id)
    {:reply, profile, state}
  end

  @impl GenServer
  def handle_call({:analyze_batch, character_ids, opts}, _from, state) do
    results =
      character_ids
      |> Task.async_stream(
        fn char_id ->
          {char_id, perform_character_analysis(char_id, opts)}
        end,
        max_concurrency: 10,
        timeout: @analysis_timeout
      )
      |> Enum.reduce(%{successes: [], failures: []}, fn
        {:ok, {char_id, {:ok, analysis}}}, acc ->
          %{acc | successes: [{char_id, analysis} | acc.successes]}

        {:ok, {char_id, {:error, reason}}}, acc ->
          %{acc | failures: [{char_id, reason} | acc.failures]}

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
          Cache.put(:analysis, cache_key, analysis, ttl: @cache_ttl)
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
    # Clean up failed analysis
    new_state = %{state | active_analyses: Map.delete(state.active_analyses, ref)}

    {:noreply, new_state}
  end

  # Private Functions

  defp perform_character_analysis(character_id, opts) do
    case gather_character_data(character_id, opts) do
      {:ok, data} ->
        analysis = build_analysis(data, opts)
        {:ok, analysis}

      {:error, reason} = error ->
        Logger.error("Character analysis failed for #{character_id}: #{inspect(reason)}")
        error
    end
  end

  defp gather_character_data(character_id, opts) do
    # Gather all required data in parallel
    base_tasks = [Task.async(fn -> get_character_stats(character_id) end)]

    tasks =
      base_tasks
      |> maybe_add_task(
        Keyword.get(opts, :include_combat_stats, true),
        Task.async(fn -> CombatStatsAnalyzer.analyze_combat_stats(character_id) end)
      )
      |> maybe_add_task(
        Keyword.get(opts, :include_ship_prefs, true),
        Task.async(fn -> ShipPreferenceAnalyzer.analyze_ship_preferences(character_id) end)
      )
      |> maybe_add_task(
        Keyword.get(opts, :include_behavior, true),
        Task.async(fn -> BehavioralPatternAnalyzer.analyze_behavior(character_id) end)
      )
      |> maybe_add_task(
        Keyword.get(opts, :include_performance, true),
        Task.async(fn -> PerformanceAnalyzer.analyze_performance(character_id) end)
      )

    # Wait for all tasks
    results = Task.await_many(tasks, @analysis_timeout)

    # Check if all succeeded
    if Enum.all?(results, &match?({:ok, _}, &1)) do
      data =
        results
        |> Enum.map(fn {:ok, result} -> result end)
        |> merge_analysis_data()

      {:ok, data}
    else
      {:error, :data_gathering_failed}
    end
  end

  defp merge_analysis_data(results) do
    Enum.reduce(results, %{}, fn result, acc ->
      Map.merge(acc, extract_result_data(result))
    end)
  end

  defp extract_result_data(%{combat_stats: _} = data), do: %{combat_stats: data}
  defp extract_result_data(%{ship_preferences: _} = data), do: %{ship_preferences: data}
  defp extract_result_data(%{behavioral_patterns: _} = data), do: %{behavioral_patterns: data}
  defp extract_result_data(%{performance_metrics: _} = data), do: %{performance_metrics: data}
  defp extract_result_data(%{character_id: _} = stats), do: %{basic_stats: stats}
  defp extract_result_data(data), do: data

  defp build_analysis(data, _opts) do
    %{
      character_id: get_character_id(data),
      summary: build_summary(data),
      classifications: build_classifications(data),
      strengths: identify_strengths(data),
      weaknesses: identify_weaknesses(data),
      notable_patterns: identify_patterns(data),
      risk_profile: assess_risk_profile(data),
      data: data,
      analyzed_at: DateTime.utc_now()
    }
  end

  defp get_character_id(data) do
    data
    |> get_in([:basic_stats, :character_id])
    |> Kernel.||(data[:character_id])
  end

  defp build_summary(data) do
    combat = data[:combat_stats] || %{}
    behavior = data[:behavioral_patterns] || %{}

    %{
      total_kills: combat[:total_kills] || 0,
      total_losses: combat[:total_losses] || 0,
      isk_efficiency: combat[:isk_efficiency] || 0,
      favorite_ship: get_favorite_ship(data),
      primary_timezone: behavior[:timezone] || "Unknown",
      activity_level: determine_activity_level(data)
    }
  end

  defp get_favorite_ship(data) do
    case get_in(data, [:ship_preferences, :favorite_ships]) do
      [favorite | _] -> favorite.ship_name
      _ -> "Unknown"
    end
  end

  defp determine_activity_level(data) do
    kills = get_in(data, [:combat_stats, :total_kills]) || 0

    cond do
      kills > 1000 -> :very_active
      kills > 500 -> :active
      kills > 100 -> :moderate
      kills > 20 -> :casual
      true -> :inactive
    end
  end

  defp build_classifications(data) do
    %{
      pilot_type: classify_pilot_type_internal(data),
      skill_level: classify_skill_level(data),
      threat_category: classify_threat_category(data),
      engagement_style: classify_engagement_style(data)
    }
  end

  defp classify_pilot_type_internal(data) do
    solo_ratio = get_in(data, [:combat_stats, :solo_ratio]) || 0
    gang_sizes = get_in(data, [:behavioral_patterns, :gang_sizes]) || []

    cond do
      solo_ratio > 0.7 -> :elite_solo_hunter
      solo_ratio > 0.4 -> :solo_specialist
      Enum.any?(gang_sizes, &(&1 > 50)) -> :fleet_pilot
      Enum.any?(gang_sizes, &(&1 > 10)) -> :gang_specialist
      true -> :generalist
    end
  end

  defp classify_skill_level(data) do
    kd_ratio = get_in(data, [:combat_stats, :kill_death_ratio]) || 0
    isk_eff = get_in(data, [:combat_stats, :isk_efficiency]) || 0

    cond do
      kd_ratio > 5 && isk_eff > 80 -> :elite
      kd_ratio > 2 && isk_eff > 60 -> :veteran
      kd_ratio > 1 && isk_eff > 40 -> :experienced
      kd_ratio > 0.5 -> :intermediate
      true -> :novice
    end
  end

  defp classify_threat_category(data) do
    # Based on various factors
    kd_ratio = get_in(data, [:combat_stats, :kill_death_ratio]) || 0
    total_kills = get_in(data, [:combat_stats, :total_kills]) || 0

    cond do
      kd_ratio > 4 && total_kills > 500 -> :extreme_threat
      kd_ratio > 2 && total_kills > 200 -> :high_threat
      kd_ratio > 1 && total_kills > 50 -> :moderate_threat
      total_kills > 20 -> :low_threat
      true -> :minimal_threat
    end
  end

  defp classify_engagement_style(data) do
    patterns = get_in(data, [:behavioral_patterns, :engagement_patterns]) || %{}

    cond do
      patterns[:hot_dropper] -> :hot_dropper
      patterns[:gate_camper] -> :gate_camper
      patterns[:roamer] -> :roamer
      patterns[:home_defender] -> :home_defender
      true -> :opportunist
    end
  end

  defp identify_strengths(data) do
    combat = data[:combat_stats] || %{}
    ships = data[:ship_preferences] || %{}

    []
    |> maybe_add_strength(combat[:kill_death_ratio] > 3, "Excellent kill/death ratio")
    |> maybe_add_strength(combat[:solo_effectiveness] > 0.7, "Strong solo pilot")
    |> maybe_add_strength(ships[:capital_usage] > 0.2, "Capital ship pilot")
  end

  defp identify_weaknesses(data) do
    patterns = data[:behavioral_patterns] || %{}

    []
    |> maybe_add_weakness(patterns[:predictable_timezone], "Predictable activity times")
    |> maybe_add_weakness(patterns[:limited_ship_variety], "Limited ship variety")
  end

  defp identify_patterns(data) do
    patterns = data[:behavioral_patterns] || %{}
    notable = []

    gang_notable =
      if patterns[:consistent_gang_size] do
        ["Consistent gang composition" | notable]
      else
        notable
      end

    final_notable =
      if patterns[:regional_preference] do
        ["Strong regional preference" | gang_notable]
      else
        gang_notable
      end

    final_notable
  end

  defp assess_risk_profile(data) do
    threat_level = classify_threat_category(data)
    predictability = get_in(data, [:behavioral_patterns, :predictability]) || 0.5

    %{
      threat_level: threat_level,
      predictability: predictability,
      engagement_recommendation: generate_engagement_rec(threat_level, predictability)
    }
  end

  defp generate_engagement_rec(threat_level, predictability) do
    case {threat_level, predictability > 0.7} do
      {:extreme_threat, _} -> "Avoid unless heavily outnumbering"
      {:high_threat, true} -> "Engage with caution - predictable patterns"
      {:high_threat, false} -> "High risk - unpredictable opponent"
      {:moderate_threat, _} -> "Standard engagement protocols"
      _ -> "Low risk target"
    end
  end

  defp build_character_profile(character_id) do
    with {:ok, analysis} <- analyze_character(character_id),
         {:ok, threat} <-
           EveDmv.Contexts.Intelligence.Core.ThreatAssessmentEngine.assess_threat(character_id) do
      {:ok,
       %{
         character_id: character_id,
         analysis: analysis,
         threat_assessment: threat,
         profile_generated_at: DateTime.utc_now()
       }}
    end
  end

  defp determine_pilot_classification(analysis, combat_stats, ship_prefs) do
    %{
      primary_type: analysis.classifications.pilot_type,
      combat_focus: determine_combat_focus(combat_stats),
      ship_specialization: determine_ship_spec(ship_prefs),
      confidence: :high
    }
  end

  defp determine_combat_focus(combat_stats) do
    cond do
      combat_stats.solo_ratio > 0.7 -> :solo
      combat_stats.small_gang_ratio > 0.5 -> :small_gang
      combat_stats.fleet_ratio > 0.5 -> :fleet
      true -> :mixed
    end
  end

  defp determine_ship_spec(ship_prefs) do
    case ship_prefs.primary_ship_class do
      :frigate -> :tackle_specialist
      :cruiser -> :versatile
      :battleship -> :heavy_dps
      :capital -> :capital_pilot
      _ -> :generalist
    end
  end

  defp maybe_add_task(tasks, true, task), do: [task | tasks]
  defp maybe_add_task(tasks, false, _task), do: tasks

  defp maybe_add_strength(strengths, true, strength_message), do: [strength_message | strengths]
  defp maybe_add_strength(strengths, false, _strength_message), do: strengths

  defp maybe_add_weakness(weaknesses, true, weakness_message), do: [weakness_message | weaknesses]
  defp maybe_add_weakness(weaknesses, false, _weakness_message), do: weaknesses
end
