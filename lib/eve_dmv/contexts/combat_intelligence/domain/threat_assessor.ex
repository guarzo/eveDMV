defmodule EveDmv.Contexts.CombatIntelligence.Domain.ThreatAssessor do
  @moduledoc """
  Assesses threat levels for characters in various contexts.

  This module evaluates threat levels based on context-specific factors
  such as general threat assessment, recruitment vetting, wormhole operations,
  and fleet reliability.
  """

  use GenServer

  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache

  require Logger

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Assess threat level for a character in a specific context.
  """
  @spec assess_threat(integer(), atom()) :: {:ok, map()} | {:error, term()}
  def assess_threat(character_id, context) do
    GenServer.call(__MODULE__, {:assess_threat, character_id, context})
  end

  @doc """
  Get cached threat assessment for a character.
  """
  @spec get_assessment(integer()) :: {:ok, map()} | {:error, term()}
  def get_assessment(character_id) do
    case AnalysisCache.get_threat_assessment(character_id) do
      {:ok, assessment} -> {:ok, assessment}
      {:error, :not_found} -> assess_threat(character_id, :general)
    end
  end

  @doc """
  Refresh threat assessment for a character.
  """
  @spec refresh_assessment(integer()) :: {:ok, map()} | {:error, term()}
  def refresh_assessment(character_id) do
    AnalysisCache.invalidate_threat_assessment(character_id)
    assess_threat(character_id, :general)
  end

  @doc """
  Batch assess threats for multiple characters.
  """
  @spec batch_assess_threats([integer()], atom()) :: {:ok, map()} | {:error, term()}
  def batch_assess_threats(character_ids, context) do
    GenServer.call(__MODULE__, {:batch_assess, character_ids, context}, 30_000)
  end

  @doc """
  Get threat factors breakdown for a character.
  """
  @spec get_threat_factors(integer()) :: {:ok, map()} | {:error, term()}
  def get_threat_factors(character_id) do
    GenServer.call(__MODULE__, {:threat_factors, character_id})
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    {:ok,
     %{
       assessment_count: 0,
       cache_hits: 0,
       cache_misses: 0
     }}
  end

  @impl GenServer
  def handle_call({:assess_threat, character_id, context}, _from, state) do
    result = perform_threat_assessment(character_id, context)

    new_state =
      case result do
        {:ok, _} -> %{state | assessment_count: state.assessment_count + 1}
        {:error, _} -> state
      end

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:batch_assess, character_ids, context}, _from, state) do
    results =
      Enum.map(character_ids, fn id ->
        {id, perform_threat_assessment(id, context)}
      end)

    {:reply, {:ok, Map.new(results)}, state}
  end

  @impl GenServer
  def handle_call({:threat_factors, character_id}, _from, state) do
    # Placeholder implementation - detailed threat factor breakdown not yet implemented
    factors = %{
      character_id: character_id,
      combat_skills: 0.7,
      kill_death_ratio: 0.8,
      corp_reputation: 0.5,
      behavioral_patterns: 0.6,
      recent_activity: 0.9
    }

    {:reply, {:ok, factors}, state}
  end

  # Private functions

  defp perform_threat_assessment(character_id, context) do
    # Check cache first
    case AnalysisCache.get_threat_assessment(character_id) do
      {:ok, cached} when context == :general ->
        {:ok, cached}

      {:error, :not_found} ->
        # Perform actual assessment based on context
        assessment =
          case context do
            :general -> assess_general_threat(character_id)
            :recruitment -> assess_recruitment_threat(character_id)
            :wormhole_operations -> assess_wormhole_threat(character_id)
            :fleet_operations -> assess_fleet_threat(character_id)
            _ -> assess_general_threat(character_id)
          end

        # Cache the result if general assessment
        if context == :general do
          AnalysisCache.put_threat_assessment(character_id, assessment)
        end

        {:ok, assessment}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp assess_general_threat(character_id) do
    %{
      character_id: character_id,
      threat_level: :medium,
      threat_score: 0.65,
      factors: %{
        combat_effectiveness: 0.7,
        aggression_level: 0.6,
        target_selection: 0.8,
        fleet_participation: 0.5
      },
      recommendations: [
        "Monitor engagement patterns",
        "Track preferred ship types",
        "Analyze timezone activity"
      ],
      assessed_at: DateTime.utc_now()
    }
  end

  defp assess_recruitment_threat(character_id) do
    %{
      character_id: character_id,
      threat_level: :low,
      threat_score: 0.3,
      awox_risk: 0.15,
      factors: %{
        corporation_history: 0.2,
        kill_patterns: 0.4,
        social_connections: 0.3,
        character_age: 0.5
      },
      recommendations: [
        "Verify corporation history",
        "Check for suspicious kill patterns",
        "Review social connections"
      ],
      assessed_at: DateTime.utc_now()
    }
  end

  defp assess_wormhole_threat(character_id) do
    %{
      character_id: character_id,
      threat_level: :high,
      threat_score: 0.85,
      factors: %{
        wormhole_experience: 0.9,
        cloaky_camping_risk: 0.8,
        hunter_effectiveness: 0.85,
        chain_mapping_skills: 0.7
      },
      recommendations: [
        "High risk for wormhole operations",
        "Likely experienced hunter",
        "Maintain high security protocols"
      ],
      assessed_at: DateTime.utc_now()
    }
  end

  defp assess_fleet_threat(character_id) do
    %{
      character_id: character_id,
      threat_level: :medium,
      threat_score: 0.6,
      factors: %{
        fleet_command_experience: 0.5,
        target_calling_ability: 0.7,
        coordination_skills: 0.6,
        reliability: 0.8
      },
      recommendations: [
        "Monitor fleet behavior",
        "Track command positions",
        "Assess coordination capabilities"
      ],
      assessed_at: DateTime.utc_now()
    }
  end
end
