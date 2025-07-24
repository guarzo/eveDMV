defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.SingleSystemAnalyzer do
  @moduledoc """
  Analyzer for individual system analysis within cross-system context.
  """

  alias EveDmv.Api
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
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window * 3600, :second)

    # Get system info
    system_query = Ash.Query.limit(SolarSystem, 1)

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

  defp analyze_activity_level(_system_id, _cutoff_time) do
    # Query recent killmail activity in the system
    # TODO: Filter by system_id and cutoff_time when system filtering is implemented
    activity_query =
      KillmailRaw

    Ash.Query.filter(true)
    Ash.Query.select([:killmail_id])

    case Ash.read(activity_query, domain: Api) do
      {:ok, killmails} ->
        kill_count = length(killmails)

        cond do
          kill_count > 100 -> :very_high
          kill_count > 50 -> :high
          kill_count > 20 -> :moderate
          kill_count > 5 -> :low
          kill_count > 0 -> :minimal
          true -> :none
        end

      {:error, _} ->
        :unknown
    end
  end

  defp analyze_threat_level(_system_id, _cutoff_time) do
    # Query high-value losses as threat indicator
    # TODO: Filter by system_id and cutoff_time when system filtering is implemented
    threat_query =
      KillmailRaw

    Ash.Query.filter(true)
    Ash.Query.select([:killmail_id, :total_value])

    case Ash.read(threat_query, domain: Api) do
      {:ok, high_value_kills} ->
        threat_count = length(high_value_kills)

        total_loss_value =
          Enum.reduce(high_value_kills, Decimal.new(0), fn k, acc ->
            Decimal.add(acc, k.total_value || Decimal.new(0))
          end)

        cond do
          threat_count > 20 or
              Decimal.compare(total_loss_value, Decimal.new(10_000_000_000)) == :gt ->
            :critical

          threat_count > 10 or
              Decimal.compare(total_loss_value, Decimal.new(5_000_000_000)) == :gt ->
            :high

          threat_count > 5 or Decimal.compare(total_loss_value, Decimal.new(1_000_000_000)) == :gt ->
            :moderate

          threat_count > 0 ->
            :low

          true ->
            :minimal
        end

      {:error, _} ->
        :unknown
    end
  end

  defp calculate_strategic_value(system) do
    # Determine strategic value based on system properties
    cond do
      # Jita, Amarr, Dodixie, Rens, Hek (major trade hubs)
      system.system_id in [30_000_142, 30_002_187, 30_002_659, 30_002_510, 30_002_053] ->
        :critical

      # Wormhole systems have strategic value
      system.wormhole_class_id != nil ->
        :high

      # Null security sovereignty systems
      system.security_class == "nullsec" ->
        :high

      # Low security faction warfare systems
      system.security_class == "lowsec" ->
        :moderate

      # High security mission hubs or minor trade hubs
      system.security_status > 0.7 ->
        :low

      # Everything else
      true ->
        :minimal
    end
  end

  defp analyze_system_connections(system) do
    # Get neighboring systems in the same constellation
    neighbors_query =
      SolarSystem
      |> Ash.Query.filter(constellation_id == system.constellation_id)
      |> Ash.Query.select([:system_id, :system_name, :security_class])

    case Ash.read(neighbors_query, domain: Api) do
      {:ok, neighbors} ->
        # Categorize connections by security type
        direct_connections =
          neighbors

          # Assume first 5 are direct gate connections (would need gate data)
          |> Enum.take(5)
          |> Enum.map(fn n ->
            %{
              system_id: n.system_id,
              system_name: n.system_name,
              security_class: n.security_class
            }
          end)

        # Strategic connections are those with different security classes
        strategic_connections =
          neighbors
          |> Enum.filter(&(&1.security_class != system.security_class))
          |> Enum.take(3)
          |> Enum.map(fn n ->
            %{
              system_id: n.system_id,
              system_name: n.system_name,
              security_class: n.security_class,
              strategic_value: :gateway
            }
          end)

        %{
          direct_connections: direct_connections,
          constellation_systems: length(neighbors),
          strategic_connections: strategic_connections
        }

      {:error, _} ->
        %{
          direct_connections: [],
          constellation_systems: 0,
          strategic_connections: []
        }
    end
  end

  defp calculate_influence_radius(_system_id, _cutoff_time) do
    # Calculate influence based on activity spreading to nearby systems
    # This would ideally use gate connection data

    # Query killmails with participants from this system
    # TODO: Filter by system_id and cutoff_time when system filtering is implemented
    influence_query =
      KillmailRaw

    Ash.Query.filter(true)
    Ash.Query.load([:participants])
    Ash.Query.limit(100)

    case Ash.read(influence_query, domain: Api) do
      {:ok, killmails} ->
        # Count unique systems where participants from our system are active
        influenced_systems =
          killmails
          |> Enum.filter(fn km ->
            # Check if any participant is frequently active in our system
            # This is simplified - would need historical data
            Enum.any?(km.participants || [], fn p ->
              # Simplified check - in reality would check historical activity
              p.character_id && rem(p.character_id, 10) == rem(1, 10)
            end)
          end)
          |> Enum.map(& &1.solar_system_id)
          |> Enum.uniq()
          |> length()

        # Influence radius based on activity spread
        cond do
          influenced_systems > 20 -> 5
          influenced_systems > 10 -> 4
          influenced_systems > 5 -> 3
          influenced_systems > 2 -> 2
          influenced_systems > 0 -> 1
          true -> 0
        end

      {:error, _} ->
        0
    end
  end
end
