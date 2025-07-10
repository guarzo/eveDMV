defmodule EveDmv.Contexts.PlayerProfile.Domain.PlayerAnalyzer do
  @moduledoc """
  Core player analysis service for EVE DMV.

  Provides comprehensive player profiling including combat statistics,
  behavioral patterns, ship preferences, and psychological profiling.
  """

  use GenServer
  use EveDmv.ErrorHandler

  alias EveDmv.Contexts.PlayerProfile.Analyzers.BehavioralPatternsAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Analyzers.CombatStatsAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Analyzers.ShipPreferencesAnalyzer
  alias EveDmv.Contexts.PlayerProfile.Infrastructure.PlayerRepository
  alias EveDmv.Shared.MetricsCalculator

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Perform comprehensive player analysis.
  """
  def analyze_player(character_id, opts \\ []) do
    GenServer.call(__MODULE__, {:analyze_player, character_id, opts}, 30_000)
  end

  @doc """
  Analyze character - legacy interface for backwards compatibility.

  This function provides compatibility with the old IntelligenceEngine API.
  """
  def analyze_character(character_id, opts \\ []) do
    # Map to the new analyze_player function for backwards compatibility
    case analyze_player(character_id, opts) do
      {:ok, analysis} ->
        # Transform to expected format for legacy callers
        {:ok,
         %{
           character_id: character_id,
           analysis_type: :player_profile,
           combat_stats: Map.get(analysis, :combat, %{}),
           behavioral_patterns: Map.get(analysis, :behavioral, %{}),
           ship_preferences: Map.get(analysis, :ships, %{}),
           archetype: Map.get(analysis, :archetype, :unknown),
           confidence_score: Map.get(analysis, :confidence, 0.5),
           analysis_timestamp: DateTime.utc_now()
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyze multiple players in batch.
  """
  def analyze_players(character_ids, opts \\ []) when is_list(character_ids) do
    GenServer.call(__MODULE__, {:analyze_players, character_ids, opts}, 60_000)
  end

  @doc """
  Get specific analysis component for a player.
  """
  def get_analysis_component(character_id, component)
      when component in [:combat, :behavioral, :ships] do
    GenServer.call(__MODULE__, {:get_component, character_id, component})
  end

  @doc """
  Generate player archetype classification.
  """
  def classify_player_archetype(character_id) do
    GenServer.call(__MODULE__, {:classify_archetype, character_id})
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
        component_timings: %{
          combat: [],
          behavioral: [],
          ships: []
        }
      },
      recent_analysis_times: []
    }

    Logger.info("PlayerAnalyzer started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_player, character_id, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Check cache first
    cache_key = generate_cache_key(character_id, opts)

    case Map.get(state.analysis_cache, cache_key) do
      %{timestamp: ts, data: data} when ts != nil ->
        if cache_valid?(ts, opts) do
          new_state = update_metrics(state, :cache_hit, 0)
          {:reply, {:ok, data}, new_state}
        else
          # Cache expired, perform analysis
          perform_and_cache_analysis(character_id, opts, cache_key, start_time, state)
        end

      _ ->
        # No cache, perform analysis
        perform_and_cache_analysis(character_id, opts, cache_key, start_time, state)
    end
  end

  @impl GenServer
  def handle_call({:analyze_players, character_ids, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Parallel batch analysis
    tasks =
      Enum.map(character_ids, fn character_id ->
        Task.async(fn ->
          {character_id, perform_player_analysis(character_id, opts)}
        end)
      end)

    # Collect results with timeout
    results = Task.await_many(tasks, 30_000)

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
      total_count: length(character_ids),
      success_count: length(successful),
      failure_count: length(failed),
      analysis_time_ms: analysis_time
    }

    {:reply, {:ok, batch_result}, new_state}
  end

  @impl GenServer
  def handle_call({:get_component, character_id, component}, _from, state) do
    # Try to get from cache first
    cache_entries =
      Enum.filter(state.analysis_cache, fn {key, _} ->
        String.starts_with?(key, "#{character_id}:")
      end)

    case find_latest_component(cache_entries, component) do
      {:ok, component_data} ->
        {:reply, {:ok, component_data}, state}

      :not_found ->
        # Perform component-specific analysis
        result =
          case component do
            :combat -> CombatStatsAnalyzer.analyze(character_id)
            :behavioral -> BehavioralPatternsAnalyzer.analyze(character_id)
            :ships -> ShipPreferencesAnalyzer.analyze(character_id)
          end

        {:reply, result, state}
    end
  end

  @impl GenServer
  def handle_call({:classify_archetype, character_id}, _from, state) do
    # Get or generate full analysis
    case perform_player_analysis(character_id, []) do
      {:ok, analysis} ->
        archetype = classify_archetype(analysis)
        {:reply, {:ok, archetype}, state}

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

  defp perform_and_cache_analysis(character_id, opts, cache_key, start_time, state) do
    case perform_player_analysis(character_id, opts) do
      {:ok, analysis} ->
        analysis_time = System.monotonic_time(:millisecond) - start_time

        # Cache the result
        cache_entry = %{
          timestamp: DateTime.utc_now(),
          data: analysis
        }

        new_cache = Map.put(state.analysis_cache, cache_key, cache_entry)

        new_state =
          update_metrics(%{state | analysis_cache: new_cache}, :cache_miss, analysis_time)

        {:reply, {:ok, analysis}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp perform_player_analysis(character_id, opts) do
    with {:ok, base_data} <- gather_base_data(character_id),
         {:ok, combat_stats} <- analyze_combat_stats(character_id, base_data, opts),
         {:ok, behavioral} <- analyze_behavioral_patterns(character_id, base_data, opts),
         {:ok, ship_prefs} <- analyze_ship_preferences(character_id, base_data, opts) do
      analysis = %{
        character_id: character_id,
        timestamp: DateTime.utc_now(),
        combat_statistics: combat_stats,
        behavioral_patterns: behavioral,
        ship_preferences: ship_prefs,
        player_archetype: determine_archetype(combat_stats, behavioral, ship_prefs),
        risk_profile: calculate_risk_profile(combat_stats, behavioral, ship_prefs),
        recommendations: generate_recommendations(combat_stats, behavioral, ship_prefs)
      }

      {:ok, analysis}
    end
  end

  defp gather_base_data(character_id) do
    case PlayerRepository.get_player_data(character_id) do
      {:ok, player_data} ->
        # Gather all necessary base data
        base_data = %{
          character_stats: player_data,
          killmail_stats: PlayerRepository.get_killmail_stats(character_id),
          activity_data: PlayerRepository.get_activity_data(character_id),
          corporation_history: PlayerRepository.get_corporation_history(character_id)
        }

        {:ok, base_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_combat_stats(character_id, base_data, _opts) do
    CombatStatsAnalyzer.analyze(character_id, base_data)
  end

  defp analyze_behavioral_patterns(character_id, base_data, _opts) do
    BehavioralPatternsAnalyzer.analyze(character_id, base_data)
  end

  defp analyze_ship_preferences(character_id, base_data, _opts) do
    ShipPreferencesAnalyzer.analyze(character_id, base_data)
  end

  defp determine_archetype(combat_stats, behavioral, ship_prefs) do
    # Comprehensive archetype determination based on all analyses
    aggression = behavioral.engagement_behavior.aggression_style
    primary_role = ship_prefs.role_distribution.primary_role
    solo_pref = behavioral.tactical_patterns.tactical_style.solo_vs_group_preference

    cond do
      aggression == :highly_aggressive and solo_pref == :strong_solo_preference ->
        :elite_pvper

      primary_role == :logistics and solo_pref == :group_oriented ->
        :fleet_support

      ship_prefs.specialization.level == :highly_specialized ->
        :specialist

      behavioral.risk_profile.risk_tolerance_score > 0.7 ->
        :risk_taker

      combat_stats.performance_metrics.kill_death_ratio > 3.0 ->
        :veteran_fighter

      true ->
        :standard_pilot
    end
  end

  defp calculate_risk_profile(combat_stats, behavioral, ship_prefs) do
    %{
      overall_risk_score: calculate_overall_risk(combat_stats, behavioral, ship_prefs),
      risk_factors: identify_risk_factors(combat_stats, behavioral, ship_prefs),
      mitigation_suggestions: generate_risk_mitigation(combat_stats, behavioral, ship_prefs)
    }
  end

  defp generate_recommendations(combat_stats, behavioral, ship_prefs) do
    # Combat recommendations
    initial_recommendations =
      if combat_stats.performance_metrics.isk_efficiency < 50 do
        ["Improve target selection for better ISK efficiency"]
      else
        []
      end

    # Behavioral recommendations
    behavioral_recommendations =
      if behavioral.consistency_metrics.overall_consistency_score < 0.3 do
        ["Consider establishing more consistent play patterns" | initial_recommendations]
      else
        initial_recommendations
      end

    # Ship recommendations
    final_recommendations =
      if ship_prefs.diversity_metrics.ship_diversity_index < 0.2 do
        ["Expand ship repertoire for tactical flexibility" | behavioral_recommendations]
      else
        behavioral_recommendations
      end

    final_recommendations
  end

  defp generate_cache_key(character_id, opts) do
    opts_hash = :erlang.phash2(opts)
    "#{character_id}:#{opts_hash}"
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

  defp component_key(:combat), do: :combat_statistics
  defp component_key(:behavioral), do: :behavioral_patterns
  defp component_key(:ships), do: :ship_preferences

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

  # Metrics calculation delegated to shared module
  defp calculate_current_metrics(state) do
    MetricsCalculator.calculate_current_metrics(state)
  end

  defp calculate_overall_risk(_combat_stats, behavioral, _ship_prefs) do
    behavioral.risk_profile.risk_tolerance_score
  end

  defp identify_risk_factors(combat_stats, behavioral, ship_prefs) do
    base_factors = []

    loss_factors =
      if combat_stats.performance_metrics.average_loss_value > 1_000_000_000 do
        [{:high_value_losses, "Frequently loses expensive ships"} | base_factors]
      else
        base_factors
      end

    behavioral_factors =
      if behavioral.risk_profile.tactical_risk_taking.bait_susceptibility == "high" do
        [{:bait_susceptible, "High susceptibility to bait tactics"} | loss_factors]
      else
        loss_factors
      end

    final_factors =
      if ship_prefs.value_patterns.flies_expensive_ships do
        [{:expensive_ships, "Regularly flies high-value ships"} | behavioral_factors]
      else
        behavioral_factors
      end

    final_factors
  end

  defp generate_risk_mitigation(_combat_stats, behavioral, _ship_prefs) do
    mitigations = []

    if behavioral.risk_profile.tactical_risk_taking.overcommitment_tendency == "frequent" do
      ["Develop better disengagement protocols" | mitigations]
    else
      mitigations
    end
  end

  defp classify_archetype(analysis) do
    # Extract the archetype from the analysis or determine it
    Map.get(analysis, :player_archetype, :unknown)
  end
end
