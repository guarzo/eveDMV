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
  alias EveDmv.Telemetry.OtelSpans

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
    if Enum.empty?(system_ids) do
      {:ok,
       %{
         scope: :multi_system,
         systems: [],
         killmail_data: [],
         metrics: %{
           total_killmails: 0,
           systems_with_activity: 0,
           average_kills_per_system: 0.0,
           most_active_system: nil,
           temporal_distribution: %{},
           entity_participation: %{
             unique_attackers: 0,
             unique_victims: 0,
             corporation_participation: 0,
             alliance_participation: 0
           }
         },
         time_range: %{since: since, until: DateTime.utc_now()}
       }}
    else
      # Per-system queries using Task.async_stream to ensure fair representation.
      # Each system gets its own query with a 500 killmail limit, preventing
      # high-activity systems from consuming disproportionate share of results.
      # Concurrency is limited to 4 to avoid overwhelming the database.
      system_count = length(system_ids)

      # Start OpenTelemetry span for the collection operation
      span =
        OtelSpans.start_task_span("battle_analysis.collect_killmails", %{
          system_count: system_count
        })

      collection_start = System.monotonic_time(:microsecond)

      # Track per-system query durations for aggregation
      query_durations = :ets.new(:query_durations, [:set, :public])

      killmail_data =
        system_ids
        |> Task.async_stream(
          fn system_id ->
            query_start = System.monotonic_time(:microsecond)

            killmails =
              Ash.read!(KillmailRaw,
                filter: [
                  solar_system_id: system_id,
                  killmail_time: [greater_than: since]
                ],
                limit: 500,
                domain: Api
              )

            query_duration = System.monotonic_time(:microsecond) - query_start
            kill_count = length(killmails)

            # Store per-system query duration for later aggregation
            :ets.insert(query_durations, {system_id, query_duration, kill_count})

            %{
              system_id: system_id,
              killmails: killmails,
              kill_count: kill_count
            }
          end,
          max_concurrency: 4,
          timeout: 30_000,
          on_timeout: :kill_task
        )
        |> Enum.reduce([], fn
          {:ok, data}, acc -> [data | acc]
          {:exit, _reason}, acc -> acc
        end)
        |> Enum.reverse()

      # Calculate final metrics
      total_duration = System.monotonic_time(:microsecond) - collection_start
      total_killmails = Enum.sum(Enum.map(killmail_data, & &1.kill_count))
      successful_systems = length(killmail_data)
      failed_systems = system_count - successful_systems

      # Record per-system query durations as span events
      :ets.tab2list(query_durations)
      |> Enum.each(fn {system_id, query_duration_us, kill_count} ->
        OtelSpans.add_span_event(span, "system_query_completed", %{
          system_id: system_id,
          query_duration_us: query_duration_us,
          kill_count: kill_count
        })
      end)

      :ets.delete(query_durations)

      # Emit final telemetry metrics
      :telemetry.execute(
        [:eve_dmv, :battle_analysis, :collect_killmails],
        %{
          duration_us: total_duration,
          total_killmails: total_killmails,
          successful_systems: successful_systems,
          failed_systems: failed_systems
        },
        %{
          system_count: system_count,
          avg_killmails_per_system:
            if(successful_systems > 0,
              do: Float.round(total_killmails / successful_systems, 2),
              else: 0.0
            )
        }
      )

      # End the span with final measurements
      OtelSpans.end_task_span(span, %{
        duration_us: total_duration,
        total_killmails: total_killmails,
        successful_systems: successful_systems,
        failed_systems: failed_systems
      })

      metrics = calculate_multi_system_metrics(killmail_data)

      {:ok,
       %{
         scope: :multi_system,
         systems: system_ids,
         killmail_data: killmail_data,
         metrics: metrics,
         time_range: %{since: since, until: DateTime.utc_now()}
       }}
    end
  catch
    error ->
      Logger.error("Failed to collect multi-system data: #{inspect(error)}")
      {:error, :data_collection_failed}
  end

  defp collect_single_system_data(system_id, since) do
    killmails =
      Ash.read!(KillmailRaw,
        filter: [
          solar_system_id: system_id,
          killmail_time: [greater_than: since]
        ],
        limit: 1000,
        domain: Api
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
      km.killmail_time
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
    |> Enum.group_by(fn km -> km.killmail_time.hour end)
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
