defmodule EveDmv.Database.MaterializedViewManager.ViewLifecycle do
  @moduledoc """
  Manages the lifecycle of materialized views.

  Handles creation, dropping, and existence checking of materialized views,
  including index creation and view status management.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Database.MaterializedViewManager.ViewDefinitions
  alias EveDmv.Repo
  require Logger

  @doc """
  Ensures all defined materialized views exist in the database.
  """
  def ensure_all_views_exist do
    view_results = Enum.map(ViewDefinitions.all_views(), &ensure_view_exists/1)
    Enum.into(view_results, %{})
  end

  @doc """
  Ensures a specific materialized view exists, creating it if necessary.
  """
  def ensure_view_exists(view_def) do
    view_name = view_def.name

    if materialized_view_exists?(view_name) do
      {view_name, {:ok, %{status: :exists, last_refresh: nil}}}
    else
      result = create_materialized_view(view_def)
      {view_name, result}
    end
  end

  @doc """
  Checks if a materialized view exists in the database.
  """
  def materialized_view_exists?(view_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM pg_matviews
      WHERE schemaname = 'public'
      AND matviewname = $1
    )
    """

    case SQL.query(Repo, query, [view_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  @doc """
  Creates a materialized view from a definition.
  """
  def create_materialized_view(view_def) when is_map(view_def) do
    sql = "CREATE MATERIALIZED VIEW #{view_def.name} AS #{view_def.query}"

    case SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Created materialized view: #{view_def.name}")
        # Create indexes
        create_view_indexes(view_def.indexes)
        {:ok, %{status: :created, last_refresh: DateTime.utc_now()}}

      {:error, error} ->
        Logger.error("Failed to create materialized view #{view_def.name}: #{inspect(error)}")
        {:error, error}
    end
  end

  def create_materialized_view(view_name) when is_binary(view_name) do
    case ViewDefinitions.find_view_by_name(view_name) do
      nil -> {:error, "Unknown view: #{view_name}"}
      view_def -> create_materialized_view(view_def)
    end
  end

  @doc """
  Drops a materialized view if it exists.
  """
  def drop_materialized_view(view_name) do
    sql = "DROP MATERIALIZED VIEW IF EXISTS #{view_name}"

    case SQL.query(Repo, sql, []) do
      {:ok, _} ->
        Logger.info("Dropped materialized view: #{view_name}")
        {:ok, view_name}

      {:error, error} ->
        Logger.error("Failed to drop materialized view #{view_name}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Drops all defined materialized views.
  """
  def drop_all_views do
    Enum.map(ViewDefinitions.all_views(), fn view_def -> drop_materialized_view(view_def.name) end)
  end

  @doc """
  Creates indexes for a materialized view.
  """
  def create_view_indexes(indexes) when is_list(indexes) do
    Enum.each(indexes, fn index_sql ->
      case SQL.query(Repo, index_sql, []) do
        {:ok, _} ->
          Logger.debug("Created index: #{String.slice(index_sql, 0, 50)}...")

        {:error, error} ->
          Logger.warning("Failed to create index: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Rebuilds a materialized view (drop and recreate).
  """
  def rebuild_view(view_name) when is_binary(view_name) do
    case ViewDefinitions.find_view_by_name(view_name) do
      nil ->
        {:error, "Unknown view: #{view_name}"}

      view_def ->
        with {:ok, _} <- drop_materialized_view(view_name),
             {:ok, result} <- create_materialized_view(view_def) do
          {:ok, result}
        end
    end
  end

  @doc """
  Gets the current status of all materialized views.
  """
  def get_all_view_status do
    query = """
    SELECT
      matviewname,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||matviewname)) as size,
      hasindexes,
      ispopulated
    FROM pg_matviews
    WHERE schemaname = 'public'
    ORDER BY matviewname
    """

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: rows}} ->
        view_statuses =
          Enum.map(rows, fn [name, size, has_indexes, is_populated] ->
            %{
              name: name,
              size: size,
              has_indexes: has_indexes,
              is_populated: is_populated,
              exists: true
            }
          end)

        {:ok, view_statuses}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Validates that all required views exist and are populated.
  """
  def validate_views do
    all_views = ViewDefinitions.all_views()
    expected_views = Enum.map(all_views, & &1.name)

    case get_all_view_status() do
      {:ok, existing_views} ->
        existing_names = Enum.map(existing_views, & &1.name)
        missing_views = expected_views -- existing_names

        filtered_views = Enum.filter(existing_views, &(not &1.is_populated))
        unpopulated_views = Enum.map(filtered_views, & &1.name)

        validation_result = %{
          valid: missing_views == [] and unpopulated_views == [],
          missing_views: missing_views,
          unpopulated_views: unpopulated_views,
          total_expected: length(expected_views),
          total_existing: length(existing_views)
        }

        {:ok, validation_result}

      error ->
        error
    end
  end
end
