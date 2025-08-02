defmodule EveDmv.Contexts.IntelligenceInfrastructure.Domain.CrossSystem.Analyzers.RegionalAnalyzer do
  @moduledoc """
  Analyzer for regional pattern analysis across multiple systems.
  """

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw

  require Logger
  require Ash.Query

  @doc """
  Analyze regional patterns and trends.
  """
  def analyze_regional_patterns(region_id, options \\ []) do
    Logger.debug("Analyzing regional patterns for region #{region_id}")

    # Default 7 days in hours
    time_window = Keyword.get(options, :time_window, 24 * 7)
    cutoff_time = DateTimeUtils.add(DateTime.utc_now(), -time_window * 3600, :second)

    %{
      region_id: region_id,
      activity_patterns: analyze_regional_activity(region_id, cutoff_time),
      threat_landscape: analyze_regional_threats(region_id, cutoff_time),
      strategic_assessment: assess_regional_strategy(region_id, cutoff_time),
      trends: analyze_regional_trends(region_id, cutoff_time)
    }
  end

  defp analyze_regional_activity(region_id, _cutoff_time) do
    # Get all systems in the region
    systems_query = Ash.Query.filter(SolarSystem, region_id == ^region_id)

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the region (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Query killmails in these systems - simplified
        killmail_query =
          KillmailRaw
          |> Ash.Query.limit(1000)
          |> Ash.Query.select([:solar_system_id, :killmail_time, :total_value])

        case Ash.read(killmail_query, domain: Api) do
          {:ok, killmails} ->
            activity_by_system =
              killmails
              |> Enum.group_by(& &1.solar_system_id)
              |> Enum.map(fn {system_id, kills} ->
                {system_id,
                 %{
                   kill_count: length(kills),
                   total_isk_destroyed:
                     Enum.reduce(kills, Decimal.new(0), fn k, acc ->
                       Decimal.add(acc, k.total_value || Decimal.new(0))
                     end)
                 }}
              end)
              |> Map.new()

            # Identify hotspots (systems with high activity)
            total_kills = length(killmails)

            avg_kills_per_system =
              if Enum.empty?(systems), do: 0, else: total_kills / length(systems)

            hotspots =
              activity_by_system
              |> Enum.filter(fn {_system_id, data} ->
                data.kill_count > avg_kills_per_system * 2
              end)
              |> Enum.map(fn {system_id, data} ->
                system = Enum.find(systems, &(&1.system_id == system_id))

                %{
                  system_id: system_id,
                  system_name: system && system.system_name,
                  kill_count: data.kill_count,
                  isk_destroyed: data.total_isk_destroyed
                }
              end)
              |> Enum.sort_by(& &1.kill_count, :desc)
              |> Enum.take(5)

            activity_level =
              cond do
                avg_kills_per_system > 10 -> :very_high
                avg_kills_per_system > 5 -> :high
                avg_kills_per_system > 2 -> :moderate
                avg_kills_per_system > 0 -> :low
                true -> :minimal
              end

            %{
              activity_level: activity_level,
              hotspots: hotspots,
              activity_distribution: activity_by_system,
              total_kills: total_kills,
              active_systems: Enum.count(activity_by_system)
            }

          {:error, _} ->
            %{
              activity_level: :unknown,
              hotspots: [],
              activity_distribution: %{},
              error: "Failed to query killmail data"
            }
        end

      {:error, _} ->
        %{
          activity_level: :unknown,
          hotspots: [],
          activity_distribution: %{},
          error: "Failed to query systems in region"
        }
    end
  end

  defp analyze_regional_threats(region_id, _cutoff_time) do
    # Get recent killmails with participant data
    systems_query =
      SolarSystem
      |> Ash.Query.filter(region_id == ^region_id)
      |> Ash.Query.select([:system_id])

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the region (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Get killmails with high-value losses - simplified
        threat_query =
          KillmailRaw
          |> Ash.Query.load([:participants])
          |> Ash.Query.limit(100)
          |> Ash.Query.sort(desc: :total_value)

        case Ash.read(threat_query, domain: Api) do
          {:ok, high_value_kills} ->
            # Analyze threat sources (frequent attackers)
            threat_sources =
              high_value_kills
              |> Enum.flat_map(&(&1.participants || []))
              |> Enum.filter(&(!&1.is_victim && &1.corporation_id))
              |> Enum.group_by(& &1.corporation_id)
              |> Enum.map(fn {corp_id, participants} ->
                first_participant = List.first(participants)

                %{
                  corporation_id: corp_id,
                  corporation_name: first_participant.corporation_name,
                  alliance_id: first_participant.alliance_id,
                  alliance_name: first_participant.alliance_name,
                  kill_count: length(participants),
                  total_damage: Enum.reduce(participants, 0, &(&1.damage_done + &2))
                }
              end)
              |> Enum.sort_by(& &1.kill_count, :desc)
              |> Enum.take(10)

            threat_level =
              cond do
                length(high_value_kills) > 50 -> :critical
                length(high_value_kills) > 20 -> :high
                length(high_value_kills) > 10 -> :moderate
                not Enum.empty?(high_value_kills) -> :low
                true -> :minimal
              end

            %{
              threat_level: threat_level,
              threat_sources: threat_sources,
              threat_trends: determine_threat_trend(high_value_kills),
              high_value_losses: length(high_value_kills)
            }

          {:error, _} ->
            %{
              threat_level: :unknown,
              threat_sources: [],
              threat_trends: :unknown
            }
        end

      {:error, _} ->
        %{
          threat_level: :unknown,
          threat_sources: [],
          threat_trends: :unknown
        }
    end
  end

  defp assess_regional_strategy(region_id, _cutoff_time) do
    # Analyze strategic control based on corporation/alliance presence
    systems_query = Ash.Query.filter(SolarSystem, region_id == ^region_id)

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the region (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Get killmail data to assess control
        control_query =
          KillmailRaw
          |> Ash.Query.load([:participants])
          |> Ash.Query.select([:killmail_id, :solar_system_id, :participants])
          |> Ash.Query.limit(500)

        case Ash.read(control_query, domain: Api) do
          {:ok, killmails} ->
            # Analyze alliance presence by system
            alliance_presence =
              killmails
              |> Enum.flat_map(fn km ->
                km.participants ||
                  []
                  |> Enum.filter(& &1.alliance_id)
                  |> Enum.map(&{km.solar_system_id, &1.alliance_id, &1.alliance_name})
              end)
              |> Enum.group_by(fn {system_id, _, _} -> system_id end)
              |> Enum.map(&calculate_system_alliance_counts/1)
              |> Map.new()

            # Determine control status
            dominant_alliances =
              alliance_presence
              |> Enum.flat_map(&extract_alliance_entries/1)
              |> Enum.group_by(fn {id, _} -> id end)
              |> Enum.map(&calculate_alliance_activity/1)
              |> Enum.sort_by(fn {_, data} -> data.total_activity end, :desc)
              |> Enum.take(3)

            control_status =
              case dominant_alliances do
                [{_, data} | rest] when data.total_activity > 100 and length(rest) < 2 ->
                  :controlled

                [_ | _] ->
                  :contested

                [] ->
                  :unoccupied
              end

            strategic_value = calculate_strategic_value(systems)

            %{
              strategic_value: strategic_value,
              control_status: control_status,
              dominant_alliances: dominant_alliances,
              strategic_opportunities:
                identify_strategic_opportunities(systems, alliance_presence)
            }

          {:error, _} ->
            %{
              strategic_value: :unknown,
              control_status: :unknown,
              strategic_opportunities: []
            }
        end

      {:error, _} ->
        %{
          strategic_value: :unknown,
          control_status: :unknown,
          strategic_opportunities: []
        }
    end
  end

  defp analyze_regional_trends(region_id, cutoff_time) do
    # Compare recent activity to historical baseline
    # Last 24h
    _recent_cutoff = DateTimeUtils.add(DateTime.utc_now(), -24 * 3_600, :second)
    # 24h before cutoff
    _historical_cutoff = DateTimeUtils.add(cutoff_time, -24 * 3_600, :second)

    systems_query =
      SolarSystem
      |> Ash.Query.filter(region_id == ^region_id)
      |> Ash.Query.select([:system_id])

    case Ash.read(systems_query, domain: Api) do
      {:ok, systems} ->
        # Get all system IDs in the region (TODO: use for filtering)
        _system_ids = Enum.map(systems, & &1.system_id)

        # Get recent kills - simplified
        recent_query =
          KillmailRaw
          |> Ash.Query.select([:killmail_id])
          |> Ash.Query.limit(100)

        # Get historical kills - simplified
        historical_query =
          KillmailRaw
          |> Ash.Query.select([:killmail_id])
          |> Ash.Query.limit(100)

        with {:ok, recent_kills} <- Ash.read(recent_query, domain: Api),
             {:ok, historical_kills} <- Ash.read(historical_query, domain: Api) do
          recent_count = length(recent_kills)
          historical_count = length(historical_kills)

          trend =
            cond do
              historical_count == 0 and recent_count > 0 -> :increasing
              historical_count == 0 -> :stable
              recent_count / historical_count > 1.5 -> :increasing
              recent_count / historical_count < 0.5 -> :decreasing
              true -> :stable
            end

          %{
            overall_trend: trend,
            recent_activity: recent_count,
            historical_baseline: historical_count,
            trend_percentage:
              if(historical_count > 0, do: (recent_count / historical_count - 1) * 100, else: nil),
            # Would require more sophisticated analysis
            emerging_patterns: [],
            # Would require ML or statistical modeling
            predictive_indicators: []
          }
        else
          {:error, _} ->
            %{
              overall_trend: :unknown,
              emerging_patterns: [],
              predictive_indicators: []
            }
        end

      {:error, _} ->
        %{
          overall_trend: :unknown,
          emerging_patterns: [],
          predictive_indicators: []
        }
    end
  end

  # Helper functions
  defp determine_threat_trend(high_value_kills) do
    # Simple trend based on kill timing distribution
    if length(high_value_kills) < 5 do
      :insufficient_data
    else
      recent_kills = Enum.take(high_value_kills, 5)
      older_kills = Enum.slice(high_value_kills, 5, 5)

      recent_avg_value = average_kill_value(recent_kills)
      older_avg_value = average_kill_value(older_kills)

      cond do
        recent_avg_value > older_avg_value * 1.2 -> :escalating
        recent_avg_value < older_avg_value * 0.8 -> :diminishing
        true -> :stable
      end
    end
  end

  defp average_kill_value(kills) do
    total =
      Enum.reduce(kills, Decimal.new(0), fn k, acc ->
        Decimal.add(acc, k.total_value || Decimal.new(0))
      end)

    if Enum.empty?(kills) do
      Decimal.new(0)
    else
      Decimal.div(total, Decimal.new(length(kills)))
    end
  end

  defp calculate_strategic_value(systems) do
    # Strategic value based on system characteristics
    wormhole_count = Enum.count(systems, & &1.wormhole_class_id)
    lowsec_count = Enum.count(systems, &(&1.security_class == "lowsec"))
    nullsec_count = Enum.count(systems, &(&1.security_class == "nullsec"))

    cond do
      nullsec_count > length(systems) * 0.5 -> :very_high
      wormhole_count > 0 or lowsec_count > length(systems) * 0.3 -> :high
      lowsec_count > 0 -> :moderate
      true -> :low
    end
  end

  defp identify_strategic_opportunities(systems, alliance_presence) do
    # Identify uncontrolled valuable systems
    uncontrolled_systems =
      systems
      |> Enum.filter(fn system ->
        presence = Map.get(alliance_presence, system.system_id, %{})

        length(Map.keys(presence)) < 2 and
          (system.security_class in ["lowsec", "nullsec"] or system.wormhole_class_id)
      end)
      |> Enum.take(5)
      |> Enum.map(fn system ->
        %{
          system_id: system.system_id,
          system_name: system.system_name,
          security_class: system.security_class,
          opportunity_type: :uncontrolled_valuable_system
        }
      end)

    uncontrolled_systems
  end

  defp calculate_system_alliance_counts({system_id, entries}) do
    alliance_counts =
      entries
      |> Enum.group_by(fn {_, alliance_id, _} -> alliance_id end)
      |> Enum.map(&calculate_alliance_count/1)
      |> Map.new()

    {system_id, alliance_counts}
  end

  defp calculate_alliance_count({alliance_id, alliance_entries}) do
    {_, _, alliance_name} = List.first(alliance_entries)

    {alliance_id,
     %{
       name: alliance_name,
       activity: length(alliance_entries)
     }}
  end

  defp extract_alliance_entries({_system, alliances}) do
    Enum.map(alliances, fn {id, data} -> {id, data} end)
  end

  defp calculate_alliance_activity({id, entries}) do
    total_activity = Enum.reduce(entries, 0, fn {_, data}, acc -> acc + data.activity end)
    {_, first_data} = List.first(entries)
    {id, %{name: first_data.name, total_activity: total_activity}}
  end
end
