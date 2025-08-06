defmodule EveDmv.Shared.Strategic.DataCollector do
  @moduledoc """
  Handles strategic data collection for pattern analysis.

  Responsible for:
  - Collecting killmail data across different scopes
  - Basic metric calculations
  - Data preparation for analysis
  """

  alias EveDmv.Api
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw

  require Logger

  @doc """
  Collects strategic data for the specified scope and timeframe.
  """
  def collect_strategic_data(analysis_scope, analysis_window_days) do
    since = DateTime.utc_now() |> DateTimeUtils.add(-analysis_window_days * 24 * 3600, :second)

    case analysis_scope do
      %{systems: system_ids} when is_list(system_ids) ->
        collect_multi_system_data(system_ids, since)

      %{system_id: system_id} ->
        collect_single_system_data(system_id, since)

      %{region: region_data} ->
        collect_regional_data(region_data, since)

      _ ->
        {:error, :invalid_analysis_scope}
    end
  end

  @doc """
  Calculates basic activity metrics from collected data.
  """
  def calculate_activity_metrics(strategic_data) do
    %{
      total_killmails: count_total_killmails(strategic_data),
      unique_pilots: count_unique_pilots(strategic_data),
      unique_corporations: count_unique_corporations(strategic_data),
      unique_alliances: count_unique_alliances(strategic_data),
      activity_by_system: calculate_system_activity(strategic_data),
      activity_by_hour: calculate_hourly_activity(strategic_data),
      ship_type_distribution: calculate_ship_distribution(strategic_data)
    }
  end

  @doc """
  Classifies activity levels based on metrics.
  """
  def classify_activity_level(metrics) do
    kill_count = Map.get(metrics, :total_killmails, 0)

    cond do
      kill_count >= 100 -> :very_high
      kill_count >= 50 -> :high
      kill_count >= 20 -> :medium
      kill_count >= 5 -> :low
      true -> :minimal
    end
  end

  # Private functions

  defp collect_multi_system_data(system_ids, since) do
    killmail_data =
      Enum.map(system_ids, fn system_id ->
        killmails =
          Api.read!(KillmailRaw,
            filter: [
              solar_system_id: system_id,
              timestamp: [greater_than: since]
            ],
            limit: 500
          )

        %{
          system_id: system_id,
          killmails: killmails,
          kill_count: length(killmails)
        }
      end)

    metrics = calculate_multi_system_metrics(killmail_data)

    {:ok,
     %{
       scope: :multi_system,
       systems: system_ids,
       killmail_data: killmail_data,
       metrics: metrics,
       time_range: %{since: since, until: DateTime.utc_now()}
     }}
  catch
    error ->
      Logger.error("Failed to collect multi-system data: #{inspect(error)}")
      {:error, :data_collection_failed}
  end

  defp collect_single_system_data(system_id, since) do
    killmails =
      Api.read!(KillmailRaw,
        filter: [
          solar_system_id: system_id,
          timestamp: [greater_than: since]
        ],
        limit: 1000
      )

    metrics = calculate_single_system_metrics(killmails)

    {:ok,
     %{
       scope: :single_system,
       system_id: system_id,
       killmails: killmails,
       metrics: metrics,
       time_range: %{since: since, until: DateTime.utc_now()}
     }}
  catch
    error ->
      Logger.error("Failed to collect single system data: #{inspect(error)}")
      {:error, :data_collection_failed}
  end

  defp collect_regional_data(region_data, since) do
    # For now, treat region as a collection of systems
    system_ids = Map.get(region_data, :system_ids, [])

    if system_ids == [] do
      {:error, :no_systems_in_region}
    else
      collect_multi_system_data(system_ids, since)
    end
  end

  defp calculate_multi_system_metrics(killmail_data) do
    all_killmails =
      killmail_data
      |> Enum.flat_map(& &1.killmails)

    %{
      total_killmails: length(all_killmails),
      systems_with_activity: Enum.count(killmail_data, &(&1.kill_count > 0)),
      average_kills_per_system: calculate_average_kills(killmail_data),
      most_active_system: find_most_active_system(killmail_data),
      temporal_distribution: calculate_temporal_distribution(all_killmails),
      entity_participation: calculate_entity_participation(all_killmails)
    }
  end

  defp calculate_single_system_metrics(killmails) do
    %{
      total_killmails: length(killmails),
      temporal_distribution: calculate_temporal_distribution(killmails),
      entity_participation: calculate_entity_participation(killmails),
      ship_types_involved: extract_ship_types(killmails),
      isk_destroyed: calculate_isk_destroyed(killmails)
    }
  end

  defp calculate_average_kills(killmail_data) do
    total_kills = Enum.sum(Enum.map(killmail_data, & &1.kill_count))
    system_count = length(killmail_data)

    if system_count > 0 do
      Float.round(total_kills / system_count, 2)
    else
      0.0
    end
  end

  defp find_most_active_system(killmail_data) do
    killmail_data
    |> Enum.max_by(& &1.kill_count, fn -> nil end)
    |> case do
      nil -> nil
      data -> %{system_id: data.system_id, kill_count: data.kill_count}
    end
  end

  defp calculate_temporal_distribution(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.timestamp
      |> DateTime.to_date()
    end)
    |> Enum.map(fn {date, kms} ->
      {date, length(kms)}
    end)
    |> Map.new()
  end

  defp calculate_entity_participation(killmails) do
    %{
      unique_attackers: count_unique_attackers(killmails),
      unique_victims: count_unique_victims(killmails),
      corporation_participation: count_corporation_participation(killmails),
      alliance_participation: count_alliance_participation(killmails)
    }
  end

  defp count_unique_attackers(killmails) do
    killmails
    |> Enum.flat_map(& &1.attackers)
    |> Enum.map(& &1.character_id)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_victims(killmails) do
    killmails
    |> Enum.map(& &1.victim.character_id)
    |> Enum.uniq()
    |> length()
  end

  defp count_corporation_participation(killmails) do
    attacker_corps =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.corporation_id)
      |> Enum.reject(&is_nil/1)

    victim_corps =
      killmails
      |> Enum.map(& &1.victim.corporation_id)
      |> Enum.reject(&is_nil/1)

    (attacker_corps ++ victim_corps)
    |> Enum.uniq()
    |> length()
  end

  defp count_alliance_participation(killmails) do
    attacker_alliances =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.alliance_id)
      |> Enum.reject(&is_nil/1)

    victim_alliances =
      killmails
      |> Enum.map(& &1.victim.alliance_id)
      |> Enum.reject(&is_nil/1)

    (attacker_alliances ++ victim_alliances)
    |> Enum.uniq()
    |> length()
  end

  defp extract_ship_types(killmails) do
    killmails
    |> Enum.map(& &1.victim.ship_type_id)
    |> Enum.frequencies()
  end

  defp calculate_isk_destroyed(killmails) do
    killmails
    |> Enum.map(&Map.get(&1, :zkb_total_value, 0))
    |> Enum.sum()
  end

  defp count_total_killmails(strategic_data) do
    case strategic_data.scope do
      :single_system ->
        length(strategic_data.killmails)

      :multi_system ->
        strategic_data.killmail_data
        |> Enum.map(& &1.kill_count)
        |> Enum.sum()
    end
  end

  defp count_unique_pilots(strategic_data) do
    killmails = get_all_killmails(strategic_data)

    attackers =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(& &1.character_id)
      |> Enum.reject(&is_nil/1)

    victims =
      killmails
      |> Enum.map(& &1.victim.character_id)
      |> Enum.reject(&is_nil/1)

    (attackers ++ victims)
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_corporations(strategic_data) do
    killmails = get_all_killmails(strategic_data)
    count_corporation_participation(killmails)
  end

  defp count_unique_alliances(strategic_data) do
    killmails = get_all_killmails(strategic_data)
    count_alliance_participation(killmails)
  end

  defp calculate_system_activity(strategic_data) do
    case strategic_data.scope do
      :single_system ->
        %{strategic_data.system_id => length(strategic_data.killmails)}

      :multi_system ->
        strategic_data.killmail_data
        |> Enum.map(fn data -> {data.system_id, data.kill_count} end)
        |> Map.new()
    end
  end

  defp calculate_hourly_activity(strategic_data) do
    killmails = get_all_killmails(strategic_data)

    killmails
    |> Enum.group_by(fn km -> km.timestamp.hour end)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Map.new()
  end

  defp calculate_ship_distribution(strategic_data) do
    killmails = get_all_killmails(strategic_data)
    extract_ship_types(killmails)
  end

  defp get_all_killmails(strategic_data) do
    case strategic_data.scope do
      :single_system -> strategic_data.killmails
      :multi_system -> Enum.flat_map(strategic_data.killmail_data, & &1.killmails)
    end
  end
end
