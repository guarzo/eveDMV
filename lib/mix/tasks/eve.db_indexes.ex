defmodule Mix.Tasks.Eve.DbIndexes do
  @moduledoc """
  Manage database indexes for EVE DMV performance optimization.

  ## Usage

      mix eve.db_indexes                # List current indexes
      mix eve.db_indexes --create       # Create missing indexes
      mix eve.db_indexes --analyze      # Analyze query performance
  """

  use Mix.Task
  # import Ecto.Query
  require Logger

  @shortdoc "Manage database indexes for performance"

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _args} =
      OptionParser.parse!(args,
        strict: [create: :boolean, analyze: :boolean],
        aliases: [c: :create, a: :analyze]
      )

    cond do
      opts[:create] -> create_indexes()
      opts[:analyze] -> analyze_performance()
      true -> list_indexes()
    end
  end

  defp list_indexes do
    Logger.info("Current indexes on killmails_raw table:")
    Logger.info("=====================================")

    query = """
    SELECT 
      indexname,
      indexdef,
      pg_size_pretty(pg_relation_size(indexname::regclass)) as size
    FROM pg_indexes 
    WHERE tablename = 'killmails_raw' 
    ORDER BY indexname
    """

    case EveDmv.Repo.query(query) do
      {:ok, %{rows: rows}} ->
        Enum.each(rows, fn [name, definition, size] ->
          Logger.info("#{name} (#{size})")
          Logger.info("  #{definition}")
        end)

      {:error, error} ->
        Logger.error("Failed to list indexes: #{inspect(error)}")
    end

    # Check for missing critical indexes
    Logger.info("\nChecking for missing performance indexes...")
    check_missing_indexes()
  end

  defp check_missing_indexes do
    required_indexes = [
      {"idx_killmails_victim_character", "victim_character_id"},
      {"idx_killmails_killmail_time", "killmail_time"},
      {"idx_killmails_solar_system", "solar_system_id"},
      {"idx_killmails_victim_corp", "victim_corporation_id"},
      {"idx_killmails_victim_alliance", "victim_alliance_id"},
      {"idx_killmails_victim_ship", "victim_ship_type_id"}
    ]

    # Get existing indexes
    {:ok, %{rows: existing}} =
      EveDmv.Repo.query("""
        SELECT indexname 
        FROM pg_indexes 
        WHERE tablename = 'killmails_raw'
      """)

    existing_names = Enum.map(existing, fn [name] -> name end)

    missing =
      Enum.filter(required_indexes, fn {name, _} ->
        name not in existing_names
      end)

    if Enum.empty?(missing) do
      Logger.info("✅ All recommended indexes exist")
    else
      Logger.warning("⚠️  Missing indexes that could improve performance:")

      Enum.each(missing, fn {name, column} ->
        Logger.warning("  - #{name} on column: #{column}")
      end)

      Logger.info("\nRun 'mix eve.db_indexes --create' to create missing indexes")
    end
  end

  defp create_indexes do
    Logger.info("Creating performance indexes...")

    indexes = [
      # Character queries
      {"idx_killmails_victim_character", "victim_character_id", nil},

      # Time-based queries
      {"idx_killmails_killmail_time", "killmail_time", nil},

      # System queries
      {"idx_killmails_solar_system", "solar_system_id", nil},

      # Corporation queries
      {"idx_killmails_victim_corp", "victim_corporation_id", nil},

      # Alliance queries
      {"idx_killmails_victim_alliance", "victim_alliance_id", nil},

      # Ship analysis
      {"idx_killmails_victim_ship", "victim_ship_type_id", nil},

      # Composite indexes for common queries
      {"idx_killmails_victim_char_time", "victim_character_id, killmail_time DESC", nil},
      {"idx_killmails_victim_corp_time", "victim_corporation_id, killmail_time DESC", nil},
      {"idx_killmails_victim_alliance_time", "victim_alliance_id, killmail_time DESC", nil},

      # Partial index for recent data (last 90 days)
      {"idx_killmails_recent", "killmail_time DESC",
       "WHERE killmail_time > CURRENT_TIMESTAMP - INTERVAL '90 days'"},

      # JSONB GIN index for attacker searches (most expensive but necessary)
      {"idx_killmails_attackers_gin", "((raw_data->'attackers'))", nil, "GIN"}
    ]

    Enum.each(indexes, fn index_spec ->
      case index_spec do
        {name, columns, where_clause, index_type} ->
          create_index(name, columns, where_clause, index_type)

        {name, columns, where_clause} ->
          create_index(name, columns, where_clause)
      end
    end)

    Logger.info("\n✅ Index creation complete")
  end

  defp create_index(name, columns, where_clause, index_type \\ "BTREE") do
    where_sql = if where_clause, do: " #{where_clause}", else: ""
    using_sql = " USING #{index_type}"

    sql = """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS #{name} 
    ON killmails_raw #{using_sql} (#{columns})#{where_sql}
    """

    Logger.info("Creating index: #{name}...")

    case EveDmv.Repo.query(sql) do
      {:ok, _} ->
        Logger.info("  ✅ Created successfully")

      {:error, %{postgres: %{code: :duplicate_table}}} ->
        Logger.info("  ℹ️  Already exists")

      {:error, error} ->
        Logger.error("  ❌ Failed: #{inspect(error)}")
    end
  end

  defp analyze_performance do
    Logger.info("Analyzing query performance...")
    Logger.info("==============================")

    # Check slow queries
    slow_query = """
    SELECT 
      calls,
      mean_exec_time,
      total_exec_time,
      query
    FROM pg_stat_statements
    WHERE query LIKE '%killmails_raw%'
      AND query NOT LIKE '%pg_stat_statements%'
    ORDER BY mean_exec_time DESC
    LIMIT 10
    """

    case EveDmv.Repo.query(slow_query) do
      {:ok, %{rows: [_ | _] = rows}} ->
        Logger.info("\nTop slow queries involving killmails_raw:")

        Enum.each(rows, fn [calls, mean_time, total_time, query] ->
          Logger.info(
            "\nCalls: #{calls}, Mean: #{Float.round(mean_time, 2)}ms, Total: #{Float.round(total_time, 2)}ms"
          )

          Logger.info("Query: #{String.slice(query, 0, 200)}...")
        end)

      _ ->
        Logger.info("No pg_stat_statements data available")
        Logger.info("Enable pg_stat_statements extension for query analysis")
    end

    # Table statistics
    stats_query = """
    SELECT 
      n_live_tup as live_rows,
      n_dead_tup as dead_rows,
      last_vacuum,
      last_autovacuum,
      last_analyze,
      last_autoanalyze
    FROM pg_stat_user_tables
    WHERE tablename = 'killmails_raw'
    """

    {:ok, %{rows: [[live, dead, vacuum, autovacuum, analyze, autoanalyze]]}} =
      EveDmv.Repo.query(stats_query)

    Logger.info("\nTable Statistics:")
    Logger.info("  Live rows: #{live}")
    Logger.info("  Dead rows: #{dead}")
    Logger.info("  Last vacuum: #{vacuum || "never"}")
    Logger.info("  Last autovacuum: #{autovacuum || "never"}")
    Logger.info("  Last analyze: #{analyze || "never"}")
    Logger.info("  Last autoanalyze: #{autoanalyze || "never"}")

    if dead > live * 0.2 do
      Logger.warning("\n⚠️  High number of dead rows. Consider running VACUUM ANALYZE")
    end
  end
end
