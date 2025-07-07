defmodule EveDmv.Database.MaterializedViewManager.ViewRefreshScheduler do
  alias Ecto.Adapters.SQL
  alias EveDmv.Database.MaterializedViewManager.ViewDefinitions
  alias EveDmv.Repo

  require Logger
  @moduledoc """
  Handles scheduling and execution of materialized view refreshes.

  Manages refresh strategies (full, incremental, concurrent), schedules
  automatic refreshes, and handles cache-invalidation-triggered refreshes.
  """


  @refresh_interval :timer.hours(4)
  @incremental_refresh_interval :timer.minutes(30)

  @doc """
  Refreshes all materialized views based on their strategies.
  """
  def refresh_all_views(_views, refresh_stats) do
    Logger.info("Starting refresh of all materialized views")
    start_time = System.monotonic_time(:millisecond)

    refreshed_views =
      ViewDefinitions.all_views()
      |> Enum.reduce(%{}, fn view_def, acc ->
        view_name = view_def.name

        case refresh_view(view_def) do
          {:ok, refresh_time_ms} ->
            Map.put(acc, view_name, %{
              status: :refreshed,
              last_refresh: DateTime.utc_now(),
              refresh_time_ms: refresh_time_ms
            })

          {:error, error} ->
            Logger.error("Failed to refresh view #{view_name}: #{inspect(error)}")

            Map.put(acc, view_name, %{
              status: :error,
              error: inspect(error),
              last_refresh: nil
            })
        end
      end)

    total_time_ms = System.monotonic_time(:millisecond) - start_time

    successful_refreshes =
      Enum.count(refreshed_views, fn {_, status} -> status.status == :refreshed end)

    view_defs = ViewDefinitions.all_views()

    Logger.info(
      "Materialized view refresh completed in #{total_time_ms}ms - #{successful_refreshes}/#{length(view_defs)} successful"
    )

    new_stats =
      update_refresh_stats(
        refresh_stats,
        total_time_ms,
        successful_refreshes,
        length(view_defs)
      )

    {refreshed_views, new_stats}
  end

  @doc """
  Refreshes a single materialized view.
  """
  def refresh_view(view_def) do
    view_name = view_def.name
    start_time = System.monotonic_time(:millisecond)

    sql =
      case view_def.refresh_strategy do
        :concurrent -> "REFRESH MATERIALIZED VIEW CONCURRENTLY #{view_name}"
        _ -> "REFRESH MATERIALIZED VIEW #{view_name}"
      end

    case SQL.query(Repo, sql, [], timeout: :timer.minutes(10)) do
      {:ok, _} ->
        refresh_time_ms = System.monotonic_time(:millisecond) - start_time
        Logger.debug("Refreshed materialized view #{view_name} in #{refresh_time_ms}ms")
        {:ok, refresh_time_ms}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Performs incremental refreshes for views that support it.
  """
  def perform_incremental_refreshes(_views) do
    incremental_views = ViewDefinitions.views_by_strategy(:incremental)

    if length(incremental_views) > 0 do
      Logger.debug("Performing incremental refresh for #{length(incremental_views)} views")

      refreshed_views =
        Enum.map(incremental_views, &ViewDefinitions.find_view_by_name/1)
        |> Enum.filter(&(not is_nil(&1)))
        |> Enum.reduce(%{}, fn view_def, acc ->
          case refresh_view(view_def) do
            {:ok, refresh_time_ms} ->
              Map.put(acc, view_def.name, %{
                status: :refreshed,
                last_refresh: DateTime.utc_now(),
                refresh_time_ms: refresh_time_ms
              })

            {:error, error} ->
              Map.put(acc, view_def.name, %{
                status: :error,
                error: inspect(error),
                last_refresh: nil
              })
          end
        end)

      refreshed_views
    else
      %{}
    end
  end

  @doc """
  Refreshes views affected by cache invalidation.
  """
  def refresh_affected_views(cache_pattern, views) do
    table_names = ViewDefinitions.extract_tables_from_pattern(cache_pattern)
    affected_views = ViewDefinitions.find_affected_views(table_names)

    if length(affected_views) > 0 do
      Logger.debug("Refreshing #{length(affected_views)} views affected by cache invalidation")

      refreshed_views =
        affected_views
        |> Enum.reduce(%{}, fn view_def, acc ->
          case refresh_view(view_def) do
            {:ok, refresh_time_ms} ->
              Map.put(acc, view_def.name, %{
                status: :refreshed,
                last_refresh: DateTime.utc_now(),
                refresh_time_ms: refresh_time_ms
              })

            {:error, error} ->
              Map.put(acc, view_def.name, %{
                status: :error,
                error: inspect(error),
                last_refresh: nil
              })
          end
        end)

      Map.merge(views, refreshed_views)
    else
      views
    end
  end

  @doc """
  Refreshes a specific view by name.
  """
  def refresh_view_by_name(view_name, views) do
    case ViewDefinitions.find_view_by_name(view_name) do
      nil ->
        Logger.warning("Unknown view for refresh: #{view_name}")
        views

      view_def ->
        case refresh_view(view_def) do
          {:ok, refresh_time_ms} ->
            view_status = %{
              status: :refreshed,
              last_refresh: DateTime.utc_now(),
              refresh_time_ms: refresh_time_ms
            }

            Map.put(views, view_name, view_status)

          {:error, error} ->
            Logger.error("Failed to refresh view #{view_name}: #{inspect(error)}")

            view_status = %{
              status: :error,
              error: inspect(error),
              last_refresh: nil
            }

            Map.put(views, view_name, view_status)
        end
    end
  end

  @doc """
  Schedules the next full refresh.
  """
  def schedule_refresh do
    Process.send_after(self(), :scheduled_refresh, @refresh_interval)
  end

  @doc """
  Schedules the next incremental refresh.
  """
  def schedule_incremental_refresh do
    Process.send_after(self(), :incremental_refresh, @incremental_refresh_interval)
  end

  @doc """
  Updates refresh statistics with latest operation results.
  """
  def update_refresh_stats(current_stats, duration_ms, successful, total) do
    total_refreshes = current_stats.total_refreshes + 1
    failed_refreshes = current_stats.failed_refreshes + (total - successful)

    # Calculate rolling average
    current_avg = current_stats.avg_refresh_time_ms

    new_avg =
      if total_refreshes == 1 do
        duration_ms
      else
        (current_avg * (total_refreshes - 1) + duration_ms) / total_refreshes
      end

    %{
      total_refreshes: total_refreshes,
      failed_refreshes: failed_refreshes,
      avg_refresh_time_ms: round(new_avg)
    }
  end

  @doc """
  Determines optimal refresh strategy based on view characteristics.
  """
  def determine_refresh_strategy(view_def, view_stats) do
    # Check if concurrent refresh is possible
    can_use_concurrent = check_concurrent_refresh_eligibility(view_def.name)

    cond do
      # Use concurrent if available and view is large
      can_use_concurrent and view_stats[:size_bytes] > 100_000_000 ->
        :concurrent

      # Use incremental for views that support it
      view_def.refresh_strategy == :incremental ->
        :incremental

      # Default to full refresh
      true ->
        :full
    end
  end

  @doc """
  Checks if a view supports concurrent refresh (requires unique index).
  """
  def check_concurrent_refresh_eligibility(view_name) do
    query = """
    SELECT EXISTS (
      SELECT 1
      FROM pg_indexes
      WHERE schemaname = 'public'
      AND tablename = $1
      AND indexdef LIKE '%UNIQUE%'
    )
    """

    case SQL.query(Repo, query, [view_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  @doc """
  Estimates refresh time based on historical data.
  """
  def estimate_refresh_time(_view_name, refresh_stats) do
    # In a real implementation, this would use historical data
    # For now, return average refresh time
    refresh_stats.avg_refresh_time_ms || 5000
  end

  @doc """
  Gets refresh schedule information for all views.
  """
  def get_refresh_schedule do
    Enum.map(ViewDefinitions.all_views(), fn view_def ->
      %{
        view_name: view_def.name,
        refresh_strategy: view_def.refresh_strategy,
        next_refresh: calculate_next_refresh(view_def),
        refresh_interval: get_refresh_interval(view_def.refresh_strategy),
        dependencies: view_def.dependencies
      }
    end)
  end

  defp calculate_next_refresh(view_def) do
    # Calculate based on refresh strategy
    case view_def.refresh_strategy do
      :incremental ->
        DateTime.add(DateTime.utc_now(), @incremental_refresh_interval, :millisecond)

      _ ->
        DateTime.add(DateTime.utc_now(), @refresh_interval, :millisecond)
    end
  end

  defp get_refresh_interval(:incremental), do: @incremental_refresh_interval
  defp get_refresh_interval(_), do: @refresh_interval
end
