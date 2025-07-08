defmodule EveDmv.Database.MaterializedViewManager.ViewQueryService do
  @moduledoc """
  Provides query services for materialized views.

  Handles data retrieval from materialized views with support for filtering,
  pagination, and specialized queries for different view types.
  """

  alias EveDmv.Repo
  alias SQL

  @doc """
  Queries data from a materialized view with optional limit.
  """
  def query_view(view_name, limit \\ 100) do
    sql = "SELECT * FROM #{view_name} LIMIT $1"
    execute_query(sql, [limit])
  end

  @doc """
  Queries a view with WHERE clause conditions.
  """
  def query_view_where(view_name, where_clause, params, limit \\ 100) do
    sql = "SELECT * FROM #{view_name} WHERE #{where_clause} LIMIT $#{length(params) + 1}"
    execute_query(sql, Enum.reverse([limit | params]))
  end

  @doc """
  Gets character activity data from the summary view.
  """
  def get_character_activity(character_id) when is_integer(character_id) do
    query_view_where("character_activity_summary", "character_id = $1", [character_id], 1)
  end

  @doc """
  Gets system activity data from the summary view.
  """
  def get_system_activity(system_id) when is_integer(system_id) do
    query_view_where("system_activity_summary", "solar_system_id = $1", [system_id], 1)
  end

  @doc """
  Gets alliance statistics from the summary view.
  """
  def get_alliance_stats(alliance_id) when is_integer(alliance_id) do
    query_view_where("alliance_statistics", "alliance_id = $1", [alliance_id], 1)
  end

  @doc """
  Gets top hunters with optional limit.
  """
  def get_top_hunters(limit \\ 10) do
    query_view("top_hunters_summary", limit)
  end

  @doc """
  Gets daily activity summary for specified number of days.
  """
  def get_daily_activity(days_back \\ 30) do
    cutoff_date = Date.add(Date.utc_today(), -days_back)

    query_view_where(
      "daily_killmail_summary",
      "activity_date >= $1",
      [cutoff_date],
      days_back + 1
    )
  end

  @doc """
  Gets paginated results from a materialized view.
  """
  def get_paginated_view_data(view_name, page \\ 1, page_size \\ 50) do
    offset = (page - 1) * page_size

    count_sql = "SELECT COUNT(*) FROM #{view_name}"
    data_sql = "SELECT * FROM #{view_name} LIMIT $1 OFFSET $2"

    with {:ok, %{rows: [[total_count]]}} <- SQL.query(Repo, count_sql, []),
         {:ok, %{columns: columns, rows: rows}} <- SQL.query(Repo, data_sql, [page_size, offset]) do
      data =
        Enum.map(rows, fn row ->
          Map.new(Enum.zip(columns, row))
        end)

      {:ok,
       %{
         data: data,
         page: page,
         page_size: page_size,
         total_count: total_count,
         total_pages: ceil(total_count / page_size)
       }}
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Searches character activity by name pattern.
  """
  def search_character_activity(name_pattern, limit \\ 20) do
    query_view_where(
      "character_activity_summary",
      "character_name ILIKE $1",
      ["%#{name_pattern}%"],
      limit
    )
  end

  @doc """
  Gets system activity ranked by various metrics.
  """
  def get_system_rankings(metric \\ :total_killmails, limit \\ 50) do
    order_column =
      case metric do
        :total_value -> "total_value_destroyed"
        :expensive_kills -> "expensive_kills"
        :unique_characters -> "unique_characters"
        :last_activity -> "last_activity"
        _ -> "total_killmails"
      end

    sql = """
    SELECT * FROM system_activity_summary
    ORDER BY #{order_column} DESC
    LIMIT $1
    """

    execute_query(sql, [limit])
  end

  @doc """
  Gets alliance rankings by specified metric.
  """
  def get_alliance_rankings(metric \\ :member_count, limit \\ 50) do
    order_column =
      case metric do
        :kills -> "kills"
        :value_destroyed -> "value_destroyed"
        :system_count -> "system_count"
        :last_activity -> "last_activity"
        _ -> "member_count"
      end

    sql = """
    SELECT * FROM alliance_statistics
    ORDER BY #{order_column} DESC
    LIMIT $1
    """

    execute_query(sql, [limit])
  end

  @doc """
  Gets time-series data for a specific metric.
  """
  def get_time_series_data(metric, start_date, end_date) do
    sql =
      case metric do
        :daily_kills ->
          """
          SELECT
            activity_date,
            total_killmails as value
          FROM daily_killmail_summary
          WHERE activity_date BETWEEN $1 AND $2
          ORDER BY activity_date
          """

        :daily_value ->
          """
          SELECT
            activity_date,
            total_value_destroyed as value
          FROM daily_killmail_summary
          WHERE activity_date BETWEEN $1 AND $2
          ORDER BY activity_date
          """

        :active_systems ->
          """
          SELECT
            activity_date,
            systems_active as value
          FROM daily_killmail_summary
          WHERE activity_date BETWEEN $1 AND $2
          ORDER BY activity_date
          """

        _ ->
          nil
      end

    if sql do
      execute_query(sql, [start_date, end_date])
    else
      {:error, "Unknown metric: #{metric}"}
    end
  end

  @doc """
  Gets aggregated statistics across all views.
  """
  def get_aggregated_stats do
    queries = %{
      total_characters: "SELECT COUNT(DISTINCT character_id) FROM character_activity_summary",
      total_systems: "SELECT COUNT(DISTINCT solar_system_id) FROM system_activity_summary",
      total_alliances: "SELECT COUNT(DISTINCT alliance_id) FROM alliance_statistics",
      total_kills: "SELECT SUM(total_killmails) FROM character_activity_summary",
      total_value_destroyed: "SELECT SUM(total_value_destroyed) FROM system_activity_summary"
    }

    stats =
      Enum.reduce(queries, %{}, fn {key, query}, acc ->
        case SQL.query(Repo, query, []) do
          {:ok, %{rows: [[value]]}} ->
            Map.put(acc, key, value || 0)

          _ ->
            Map.put(acc, key, 0)
        end
      end)

    {:ok, stats}
  end

  @doc """
  Exports view data to a specified format.
  """
  def export_view_data(view_name, format \\ :csv, options \\ %{}) do
    limit = Map.get(options, :limit, 10_000)

    case query_view(view_name, limit) do
      {:ok, data} when data != [] ->
        case format do
          :csv -> export_to_csv(data)
          :json -> {:ok, Jason.encode!(data)}
          _ -> {:error, "Unsupported format: #{format}"}
        end

      {:ok, []} ->
        {:error, "No data to export"}

      error ->
        error
    end
  end

  defp export_to_csv(data) when is_list(data) and length(data) > 0 do
    headers = data |> List.first() |> Map.keys() |> Enum.join(",")

    rows =
      Enum.map(data, fn row ->
        Enum.join(Enum.map(Map.values(row), &to_string/1), ",")
      end)

    csv_content = Enum.join([headers | rows], "\n")
    {:ok, csv_content}
  end

  defp export_to_csv(_), do: {:error, "Invalid data for CSV export"}

  defp execute_query(sql, params) do
    case SQL.query(Repo, sql, params) do
      {:ok, %{columns: columns, rows: rows}} ->
        data =
          Enum.map(rows, fn row ->
            columns
            |> Enum.zip(row)
            |> Map.new()
          end)

        {:ok, data}

      {:error, error} ->
        {:error, error}
    end
  end
end
