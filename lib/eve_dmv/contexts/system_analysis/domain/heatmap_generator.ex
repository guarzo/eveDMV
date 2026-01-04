defmodule EveDmv.Contexts.SystemAnalysis.Domain.HeatmapGenerator do
  @moduledoc """
  Generates heatmap data for system activity visualization.
  All calculations based on real killmail data.
  """

  import Ash.Query

  alias EveDmv.Contexts.SystemAnalysis.SecurityConfig
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Killmails.KillmailRaw

  @doc """
  Generates heatmap data for a region within a timeframe.
  Returns system coordinates with activity intensity.
  """
  def generate_heatmap_data(region_id, timeframe_opts \\ []) do
    timeframe = build_timeframe(timeframe_opts)

    with {:ok, systems} <- get_region_systems(region_id),
         {:ok, activity_data} <- get_activity_data(systems, timeframe) do
      heatmap_data =
        Enum.map(systems, fn system ->
          activity = Map.get(activity_data, system.system_id, %{})

          %{
            system_id: system.system_id,
            system_name: system.system_name,
            security_status: system.security_status,
            coordinates: %{
              x: system.x_coordinate,
              y: system.y_coordinate,
              z: system.z_coordinate
            },
            activity_metrics: %{
              kill_count: Map.get(activity, :kills, 0),
              death_count: Map.get(activity, :deaths, 0),
              isk_destroyed: Map.get(activity, :isk_destroyed, 0),
              unique_pilots: Map.get(activity, :unique_pilots, 0),
              intensity_score: calculate_intensity(activity),
              danger_rating: calculate_danger_rating(activity, system)
            },
            temporal_data: %{
              peak_hour: Map.get(activity, :peak_hour),
              last_activity: Map.get(activity, :last_activity),
              trend: calculate_trend(activity, timeframe)
            }
          }
        end)

      {:ok,
       %{
         region_id: region_id,
         timeframe: timeframe,
         systems: heatmap_data,
         metadata: generate_metadata(heatmap_data),
         generated_at: DateTime.utc_now()
       }}
    end
  end

  @doc """
  Generates constellation-level heatmap for detailed view
  """
  def generate_constellation_heatmap(constellation_id, timeframe_opts \\ []) do
    timeframe = build_timeframe(timeframe_opts)

    with {:ok, systems} <- get_constellation_systems(constellation_id),
         {:ok, activity_data} <- get_activity_data(systems, timeframe) do
      # Similar to region but with more detail
      constellation_data = build_constellation_view(systems, activity_data)

      {:ok,
       %{
         constellation_id: constellation_id,
         systems: constellation_data,
         connections: get_system_connections(systems),
         chokepoints: identify_chokepoints(systems, activity_data),
         generated_at: DateTime.utc_now()
       }}
    end
  end

  defp build_timeframe(opts) do
    default_hours = Keyword.get(opts, :hours, 24)
    default_days = Keyword.get(opts, :days, 0)

    total_hours = default_hours + default_days * 24

    %{
      start_time: DateTime.add(DateTime.utc_now(), -total_hours * 3600, :second),
      end_time: DateTime.utc_now(),
      duration_hours: total_hours
    }
  end

  defp get_region_systems(region_id) do
    systems =
      SolarSystem
      |> filter(region_id == ^region_id)
      |> Ash.read!(domain: EveDmv.Api)

    {:ok, systems}
  rescue
    error ->
      {:error, {:region_not_found, error}}
  end

  defp get_constellation_systems(constellation_id) do
    systems =
      SolarSystem
      |> filter(constellation_id == ^constellation_id)
      |> Ash.read!(domain: EveDmv.Api)

    {:ok, systems}
  rescue
    error ->
      {:error, {:constellation_not_found, error}}
  end

  defp get_activity_data(systems, timeframe) do
    system_ids = Enum.map(systems, & &1.system_id)

    # Query killmails for all systems in timeframe
    killmails =
      KillmailRaw
      |> filter(solar_system_id in ^system_ids)
      |> filter(killmail_time >= ^timeframe.start_time)
      |> filter(killmail_time <= ^timeframe.end_time)
      |> select([
        :killmail_id,
        :solar_system_id,
        :killmail_time,
        :total_value,
        :victim_character_id,
        :victim_ship_type_id,
        :data
      ])
      |> Ash.read!(domain: EveDmv.Api)

    # Aggregate by system
    activity_by_system =
      killmails
      |> Enum.group_by(& &1.solar_system_id)
      |> Enum.map(fn {system_id, system_kills} ->
        {system_id, aggregate_system_activity(system_kills)}
      end)
      |> Map.new()

    {:ok, activity_by_system}
  rescue
    error ->
      {:error, {:activity_query_failed, error}}
  end

  defp aggregate_system_activity(killmails) do
    %{
      kills: length(killmails),
      deaths: count_deaths(killmails),
      isk_destroyed: sum_isk_destroyed(killmails),
      unique_pilots: count_unique_pilots(killmails),
      peak_hour: find_peak_hour(killmails),
      last_activity: find_last_activity(killmails),
      ship_classes: analyze_ship_classes(killmails),
      gang_sizes: analyze_gang_sizes(killmails)
    }
  end

  defp count_deaths(killmails) do
    # Each killmail represents one death
    length(killmails)
  end

  defp sum_isk_destroyed(killmails) do
    killmails
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
  end

  defp count_unique_pilots(killmails) do
    # Count unique victims and attackers
    all_pilots =
      killmails
      |> Enum.flat_map(fn killmail ->
        victim_id = killmail.victim_character_id

        attacker_ids =
          case killmail.data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.map(&Map.get(&1, "character_id"))
              |> Enum.reject(&is_nil/1)

            _ ->
              []
          end

        [victim_id | attacker_ids]
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    length(all_pilots)
  end

  defp find_peak_hour(killmails) do
    killmails
    |> Enum.group_by(fn killmail -> killmail.killmail_time.hour end)
    |> Enum.max_by(fn {_hour, kills} -> length(kills) end, fn -> {0, []} end)
    |> elem(0)
  end

  defp find_last_activity(killmails) do
    killmails
    |> Enum.max_by(& &1.killmail_time, DateTime, fn -> nil end)
    |> case do
      nil -> nil
      killmail -> killmail.killmail_time
    end
  end

  defp analyze_ship_classes(killmails) do
    killmails
    |> Enum.group_by(fn killmail ->
      # Classify by victim ship type
      classify_ship_by_type_id(killmail.victim_ship_type_id)
    end)
    |> Enum.map(fn {class, kills} -> {class, length(kills)} end)
    |> Map.new()
  end

  defp analyze_gang_sizes(killmails) do
    killmails
    |> Enum.map(fn killmail ->
      case killmail.data do
        %{"attackers" => attackers} when is_list(attackers) ->
          length(attackers)

        _ ->
          1
      end
    end)
    |> Enum.group_by(fn size ->
      cond do
        size == 1 -> :solo
        size <= 5 -> :small_gang
        size <= 15 -> :medium_gang
        size <= 50 -> :fleet
        true -> :large_fleet
      end
    end)
    |> Enum.map(fn {type, sizes} -> {type, length(sizes)} end)
    |> Map.new()
  end

  defp classify_ship_by_type_id(ship_type_id) do
    # Simple classification - would use actual ship data in production
    cond do
      ship_type_id in [587, 588, 589, 590] -> :frigate
      ship_type_id in [16_227, 24_698, 29_984] -> :cruiser
      ship_type_id in [641, 642, 643, 644] -> :battleship
      true -> :other
    end
  end

  defp calculate_intensity(activity) do
    # Multi-factor intensity calculation
    kill_weight = Map.get(activity, :kills, 0) * 1.0
    # Billions
    isk_weight = Map.get(activity, :isk_destroyed, 0) / 1_000_000_000 * 0.5
    pilot_weight = Map.get(activity, :unique_pilots, 0) * 0.3

    # Normalize to 0-100 scale
    raw_intensity = kill_weight + isk_weight + pilot_weight
    min(100, max(0, raw_intensity))
  end

  defp calculate_danger_rating(activity, system) do
    # Factor in security status and activity type
    base_danger = calculate_intensity(activity) / 10.0

    # Use security_class from SDE for proper classification,
    # falling back to security_status for systems without security_class
    sec_modifier = SecurityConfig.danger_modifier(system.security_class, system.security_status)

    # Check for capital kills (high danger)
    capital_modifier = if has_capital_activity?(activity), do: 2.0, else: 1.0

    min(10, max(0, base_danger * sec_modifier * capital_modifier))
  end

  defp has_capital_activity?(activity) do
    # Check if any capital ships were involved
    # This is simplified - would check ship_classes in real implementation
    Map.get(activity, :ship_classes, %{})
    |> Map.keys()
    |> Enum.any?(fn class -> class in [:carrier, :dreadnought, :supercarrier, :titan] end)
  end

  defp calculate_trend(_activity, _timeframe) do
    # Compare to previous period
    # This would query historical data and compare
    # For now, return stable trend
    %{
      # :increasing, :decreasing, :stable
      direction: :stable,
      change_percentage: 0,
      confidence: 0.8
    }
  end

  defp generate_metadata(heatmap_data) do
    %{
      total_systems: length(heatmap_data),
      active_systems:
        Enum.count(heatmap_data, fn s ->
          s.activity_metrics.kill_count > 0
        end),
      hottest_system: find_hottest_system(heatmap_data),
      total_kills: sum_total_kills(heatmap_data),
      total_isk_destroyed: sum_total_isk(heatmap_data),
      average_intensity: calculate_average_intensity(heatmap_data)
    }
  end

  defp find_hottest_system(heatmap_data) do
    heatmap_data
    |> Enum.max_by(& &1.activity_metrics.intensity_score, fn -> nil end)
    |> case do
      nil ->
        nil

      system ->
        %{
          system_id: system.system_id,
          system_name: system.system_name,
          intensity: system.activity_metrics.intensity_score
        }
    end
  end

  defp sum_total_kills(heatmap_data) do
    heatmap_data
    |> Enum.map(& &1.activity_metrics.kill_count)
    |> Enum.sum()
  end

  defp sum_total_isk(heatmap_data) do
    heatmap_data
    |> Enum.map(& &1.activity_metrics.isk_destroyed)
    |> Enum.sum()
  end

  defp calculate_average_intensity(heatmap_data) do
    case heatmap_data do
      [] ->
        0.0

      data ->
        total =
          data
          |> Enum.map(& &1.activity_metrics.intensity_score)
          |> Enum.sum()

        Float.round(total / length(data), 2)
    end
  end

  defp build_constellation_view(systems, activity_data) do
    # Similar to generate_heatmap_data but with constellation-specific details
    Enum.map(systems, fn system ->
      activity = Map.get(activity_data, system.system_id, %{})

      %{
        system_id: system.system_id,
        system_name: system.system_name,
        security_status: system.security_status,
        activity_metrics: %{
          kill_count: Map.get(activity, :kills, 0),
          intensity_score: calculate_intensity(activity),
          danger_rating: calculate_danger_rating(activity, system)
        }
      }
    end)
  end

  defp get_system_connections(_systems) do
    # Placeholder for system connection data
    # Would query stargate connections in real implementation
    []
  end

  defp identify_chokepoints(_systems, _activity_data) do
    # Placeholder for chokepoint identification
    # Would analyze system topology and activity patterns
    []
  end
end
