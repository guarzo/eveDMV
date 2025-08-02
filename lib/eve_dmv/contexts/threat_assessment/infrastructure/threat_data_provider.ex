defmodule EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatDataProvider do
  @moduledoc """
  Data provider for threat assessment information.

  Provides temporary stub implementation to resolve Dialyzer errors.
  This module should be fully implemented as part of the threat assessment feature.
  """

  @doc """
  Get character statistics for threat analysis.
  """
  @spec get_character_stats(integer()) :: {:ok, map()} | {:error, term()}
  def get_character_stats(_character_id) do
    {:ok,
     %{
       kill_count: 0,
       death_count: 0,
       isk_destroyed: 0,
       isk_lost: 0,
       threat_rating: 0.0,
       last_activity: nil
     }}
  end

  @doc """
  Get recent activity for a character.
  """
  @spec get_recent_activity(integer(), integer()) :: {:ok, [map()]} | {:error, term()}
  def get_recent_activity(_character_id, _days) do
    {:ok, []}
  end

  @doc """
  Find known associates of a character.
  """
  @spec find_known_associates(integer(), integer()) :: {:ok, [map()]} | {:error, term()}
  def find_known_associates(_character_id, _days) do
    {:ok, []}
  end

  @doc """
  Get inhabitant details.
  """
  @spec get_inhabitant_details(integer()) :: {:ok, map()} | {:error, term()}
  def get_inhabitant_details(_inhabitant_id) do
    {:ok,
     %{
       character_id: 0,
       character_name: "Unknown",
       corporation_id: 0,
       alliance_id: nil,
       threat_level: :unknown
     }}
  end

  @doc """
  Update inhabitant threat level.
  """
  @spec update_inhabitant_threat(integer(), map()) :: {:ok, map()} | {:error, term()}
  def update_inhabitant_threat(_inhabitant_id, threat_data) do
    {:ok, Map.put(threat_data, :updated_at, DateTime.utc_now())}
  end
end
