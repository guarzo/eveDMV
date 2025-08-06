defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.SingleSystemAnalyzer do
  @moduledoc """
  Analyzer for individual system analysis within cross-system context.
  """

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw

  require Logger
  require Ash.Query

  @doc """
  Analyze a single system for cross-system context.
  """
  def analyze_system(system_id, options \\ []) do
    Logger.debug("Analyzing system #{system_id} for cross-system context")

    # Default 7 days in hours
    time_window = Keyword.get(options, :time_window, 24 * 7)
    cutoff_time = DateTimeUtils.add(DateTime.utc_now(), -time_window * 3600, :second)

    # Get system info
    system_query =
      SolarSystem
      |> Ash.Query.filter(system_id == ^system_id)
      |> Ash.Query.limit(1)

    case Api.read_one(system_query) do
      {:ok, system} when system != nil ->
        %{
          system_id: system_id,
          system_name: system.system_name,
          security_class: system.security_class,
          activity_level: analyze_activity_level(system_id, cutoff_time),
          threat_level: analyze_threat_level(system_id, cutoff_time),
          strategic_value: calculate_strategic_value(system),
          connections: analyze_system_connections(system),
          influence_radius: calculate_influence_radius(system_id, cutoff_time)
        }

      _ ->
        %{
          system_id: system_id,
          activity_level: :unknown,
          threat_level: :unknown,
          strategic_value: :unknown,
          connections: %{},
          influence_radius: 0,
          error: "System not found"
        }
    end
  end

  defp analyze_activity_level(system_id, cutoff_time) do
    # Query recent killmail activity in the system
    activity_query =
      KillmailRaw
      |> Ash.Query.filter(solar_system_id == ^system_id)
      |> Ash.Query.filter(killmail_time >= ^cutoff_time)

    case Api.count(activity_query) do
      {:ok, count} when is_integer(count) ->
        Logger.debug("Activity count for system #{system_id}: #{count}")
        classify_activity_level(count)

      {:ok, nil} ->
        Logger.debug("Activity count for system #{system_id}: nil (treating as 0)")
        classify_activity_level(0)

      error ->
        Logger.debug("Failed to count activity for system #{system_id}: #{inspect(error)}")
        :unknown
    end
  end

  defp classify_activity_level(count) when count == 0, do: :none
  defp classify_activity_level(count) when count > 0 and count < 10, do: :minimal
  defp classify_activity_level(count) when count >= 10 and count < 30, do: :low
  defp classify_activity_level(count) when count >= 30 and count < 60, do: :moderate
  defp classify_activity_level(count) when count >= 60 and count < 150, do: :high
  defp classify_activity_level(count) when count >= 150, do: :very_high

  defp analyze_threat_level(system_id, cutoff_time) do
    # Query for threat indicators (high-value kills)
    # Consider kills over 100M ISK as significant
    threat_query =
      KillmailRaw
      |> Ash.Query.filter(solar_system_id == ^system_id)
      |> Ash.Query.filter(killmail_time >= ^cutoff_time)
      |> Ash.Query.filter(total_value > 100_000_000)

    case Api.count(threat_query) do
      {:ok, high_value_count} when is_integer(high_value_count) ->
        classify_threat_level(high_value_count)

      {:ok, nil} ->
        classify_threat_level(0)

      _ ->
        :unknown
    end
  end

  defp classify_threat_level(0), do: :minimal
  defp classify_threat_level(count) when count < 5, do: :low
  defp classify_threat_level(count) when count < 10, do: :moderate
  defp classify_threat_level(count) when count < 20, do: :high
  defp classify_threat_level(_), do: :critical

  defp calculate_strategic_value(system) do
    # Strategic value based on security, location, etc.
    cond do
      # Major trade hubs have critical strategic value
      # Jita
      system.system_id == 30_000_142 -> :critical
      # Amarr
      system.system_id == 30_002_187 -> :critical
      # Dodixie
      system.system_id == 30_000_144 -> :critical
      # Rens
      system.system_id == 30_002_659 -> :critical
      system.security_class == "wormhole" -> :high
      system.security_class == "nullsec" -> :high
      system.security_class == "lowsec" -> :medium
      system.security_class == "highsec" -> :low
      true -> :unknown
    end
  end

  defp analyze_system_connections(system) do
    # Get strategic connections (systems in same constellation with different security class)
    strategic_connections = find_strategic_connections(system)

    %{
      gates: Map.get(system, :gate_count, 0),
      constellation_id: Map.get(system, :constellation_id),
      region_id: Map.get(system, :region_id),
      security_status: Map.get(system, :security_status, 0.0),
      strategic_connections: strategic_connections
    }
  end

  defp find_strategic_connections(system) do
    # Find systems in same constellation with different security class
    query =
      SolarSystem
      |> Ash.Query.filter(constellation_id == ^system.constellation_id)
      |> Ash.Query.filter(system_id != ^system.system_id)
      |> Ash.Query.filter(security_class != ^system.security_class)

    case Api.read(query) do
      {:ok, connections} ->
        Enum.map(connections, fn conn ->
          %{
            system_id: conn.system_id,
            system_name: conn.system_name,
            security_class: conn.security_class
          }
        end)

      _ ->
        []
    end
  end

  defp calculate_influence_radius(_system_id, _cutoff_time) do
    # Calculate how many adjacent systems show related activity
    # Simplified for now - return a static value
    # In future, could check killmails with participants from this system
    # appearing in adjacent systems
    3
  end
end
