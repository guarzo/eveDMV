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

    case Ash.read_one(system_query, domain: Api) do
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

    case Ash.count(activity_query, domain: Api) do
      {:ok, count} ->
        classify_activity_level(count)

      _ ->
        :unknown
    end
  end

  defp classify_activity_level(count) when count < 10, do: :low
  defp classify_activity_level(count) when count < 50, do: :medium
  defp classify_activity_level(count) when count < 200, do: :high
  defp classify_activity_level(_), do: :extreme

  defp analyze_threat_level(system_id, cutoff_time) do
    # Query for threat indicators (capital kills, fleet battles, etc.)
    threat_query =
      KillmailRaw
      |> Ash.Query.filter(solar_system_id == ^system_id)
      |> Ash.Query.filter(killmail_time >= ^cutoff_time)
      |> Ash.Query.filter(victim_ship_class in ["capital", "supercapital"])

    case Ash.count(threat_query, domain: Api) do
      {:ok, capital_count} ->
        classify_threat_level(capital_count)

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
      system.security_class == "null" -> :high
      system.security_class == "lowsec" -> :medium
      system.security_class == "highsec" -> :low
      system.security_class == "wormhole" -> :special
      true -> :unknown
    end
  end

  defp analyze_system_connections(system) do
    # For now, return basic connection data
    # In future, could integrate with gate/wormhole data
    %{
      gates: Map.get(system, :gate_count, 0),
      constellation_id: Map.get(system, :constellation_id),
      region_id: Map.get(system, :region_id),
      security_status: Map.get(system, :security_status, 0.0)
    }
  end

  defp calculate_influence_radius(_system_id, _cutoff_time) do
    # Calculate how many adjacent systems show related activity
    # Simplified for now - return a static value
    # In future, could check killmails with participants from this system
    # appearing in adjacent systems
    3
  end
end
