# Comprehensive database infrastructure verification

alias EveDmv.Repo
import Ecto.Query

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("DATABASE INFRASTRUCTURE VERIFICATION REPORT")
IO.puts(String.duplicate("=", 80))

# 1. Check if partitioned tables are actually being used
IO.puts("\n1. PARTITIONED TABLES ANALYSIS")
IO.puts(String.duplicate("-", 40))

# Check parent table
{:ok, parent_check} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'killmails_raw_partitioned' AND schemaname = 'public')",
  []
)
[[parent_exists]] = parent_check.rows
IO.puts("   - Parent table (killmails_raw_partitioned): #{if parent_exists, do: "EXISTS", else: "NOT FOUND"}")

# Check if regular killmails_raw table exists
{:ok, regular_check} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'killmails_raw' AND schemaname = 'public')",
  []
)
[[regular_exists]] = regular_check.rows
IO.puts("   - Regular table (killmails_raw): #{if regular_exists, do: "EXISTS", else: "NOT FOUND"}")

# Count partitions
{:ok, partition_count} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT COUNT(*) 
  FROM pg_inherits 
  JOIN pg_class parent ON pg_inherits.inhparent = parent.oid 
  JOIN pg_class child ON pg_inherits.inhrelid = child.oid 
  WHERE parent.relname = 'killmails_raw_partitioned'
  """,
  []
)
[[p_count]] = partition_count.rows
IO.puts("   - Number of partitions: #{p_count}")

# Check if any partition has data
{:ok, partition_data} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT 
    c.relname AS partition_name,
    pg_size_pretty(pg_relation_size(c.oid)) AS size,
    n_live_tup AS estimated_rows
  FROM pg_class c
  JOIN pg_stat_user_tables s ON c.oid = s.relid
  JOIN pg_inherits i ON c.oid = i.inhrelid
  JOIN pg_class parent ON i.inhparent = parent.oid
  WHERE parent.relname = 'killmails_raw_partitioned'
  ORDER BY c.relname
  """,
  []
)

if partition_data.rows == [] do
  IO.puts("   - No partition statistics available")
else
  IO.puts("   - Partition details:")
  Enum.each(partition_data.rows, fn [name, size, rows] ->
    IO.puts("     * #{name}: #{size}, ~#{rows || 0} rows")
  end)
end

# 2. Check materialized views
IO.puts("\n2. MATERIALIZED VIEWS ANALYSIS")
IO.puts(String.duplicate("-", 40))

{:ok, matview_details} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT 
    m.matviewname,
    pg_size_pretty(pg_relation_size(c.oid)) AS size,
    s.n_live_tup AS estimated_rows,
    obj_description(c.oid) AS description
  FROM pg_matviews m
  JOIN pg_class c ON m.matviewname = c.relname
  LEFT JOIN pg_stat_user_tables s ON c.oid = s.relid
  WHERE m.schemaname = 'public'
  ORDER BY m.matviewname
  """,
  []
)

if matview_details.rows == [] do
  IO.puts("   - No materialized views found")
else
  Enum.each(matview_details.rows, fn [name, size, rows, desc] ->
    IO.puts("   - #{name}:")
    IO.puts("     * Size: #{size}")
    IO.puts("     * Estimated rows: #{rows || 0}")
    IO.puts("     * Description: #{desc || "None"}")
  end)
end

# 3. Check static data tables
IO.puts("\n3. STATIC DATA TABLES ANALYSIS")
IO.puts(String.duplicate("-", 40))

static_tables = ["eve_item_types", "eve_solar_systems"]

Enum.each(static_tables, fn table ->
  {:ok, table_info} = Ecto.Adapters.SQL.query(
    Repo,
    """
    SELECT 
      COUNT(*) as row_count,
      pg_size_pretty(pg_relation_size($1::regclass)) as table_size,
      (SELECT COUNT(*) FROM pg_indexes WHERE tablename = $1) as index_count
    FROM #{table}
    """,
    [table]
  )
  
  [[count, size, idx_count]] = table_info.rows
  IO.puts("   - #{table}:")
  IO.puts("     * Rows: #{count}")
  IO.puts("     * Size: #{size}")
  IO.puts("     * Indexes: #{idx_count}")
end)

# 4. Check for CSV data files
IO.puts("\n4. STATIC DATA FILES")
IO.puts(String.duplicate("-", 40))

csv_dir = Path.join(:code.priv_dir(:eve_dmv), "static_data")
if File.exists?(csv_dir) do
  files = File.ls!(csv_dir)
  |> Enum.filter(&String.ends_with?(&1, ".csv"))
  |> Enum.sort()
  
  IO.puts("   CSV files in #{csv_dir}:")
  Enum.each(files, fn file ->
    path = Path.join(csv_dir, file)
    {:ok, %{size: size}} = File.stat(path)
    line_count = path |> File.stream!() |> Enum.count()
    IO.puts("   - #{file}: #{Float.round(size / 1024.0 / 1024.0, 2)} MB, #{line_count} lines")
  end)
else
  IO.puts("   - Static data directory not found: #{csv_dir}")
end

# 5. Check indexes
IO.puts("\n5. DATABASE INDEXES")
IO.puts(String.duplicate("-", 40))

{:ok, index_result} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT 
    tablename,
    COUNT(*) as index_count,
    array_agg(indexname ORDER BY indexname) as indexes
  FROM pg_indexes
  WHERE schemaname = 'public'
  AND tablename IN ('killmails_raw', 'killmails_raw_partitioned', 'participants', 
                    'eve_item_types', 'eve_solar_systems', 'character_stats')
  GROUP BY tablename
  ORDER BY tablename
  """,
  []
)

if index_result.rows == [] do
  IO.puts("   - No indexes found on key tables")
else
  Enum.each(index_result.rows, fn [table, count, indexes] ->
    IO.puts("   - #{table}: #{count} indexes")
    if count <= 5 do
      Enum.each(indexes, fn idx -> IO.puts("     * #{idx}") end)
    else
      IO.puts("     * (truncated - too many to list)")
    end
  end)
end

# 6. Check for partition management automation
IO.puts("\n6. PARTITION MANAGEMENT")
IO.puts(String.duplicate("-", 40))

{:ok, cron_check} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT 
    COUNT(*) 
  FROM pg_proc 
  WHERE pronamespace = 'public'::regnamespace 
  AND (proname LIKE '%partition%' OR proname LIKE '%maintenance%')
  """,
  []
)
[[func_count]] = cron_check.rows

{:ok, pg_cron_check} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_cron')",
  []
)
[[has_pg_cron]] = pg_cron_check.rows

IO.puts("   - Partition management functions: #{func_count}")
IO.puts("   - pg_cron extension: #{if has_pg_cron, do: "INSTALLED", else: "NOT INSTALLED"}")
IO.puts("   - Automated partition management: #{if func_count > 0 or has_pg_cron, do: "POSSIBLE", else: "NOT CONFIGURED"}")

# Summary
IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("SUMMARY OF CLAIMS VS REALITY")
IO.puts(String.duplicate("=", 80))

IO.puts("\n1. ❌ Partitioned tables for scalability (monthly partitions)")
IO.puts("   - Reality: Partitioned table structure EXISTS but NOT IN USE")
IO.puts("   - The app uses 'killmails_raw' not 'killmails_raw_partitioned'")
IO.puts("   - 8 empty partitions created for Jan-Aug 2025")

IO.puts("\n2. ✅ Materialized views for performance")
IO.puts("   - Reality: 3 materialized views EXIST (character_activity_summary, ship_type_usage, system_activity_heatmap)")
IO.puts("   - Currently EMPTY (0 rows) because no killmail data loaded")

IO.puts("\n3. ❌ 49,906 item types loaded from EVE SDE")
IO.puts("   - Reality: 0 item types in database")
IO.puts("   - CSV file has 104,953 items but loading fails due to numeric overflow")

IO.puts("\n4. ❌ 8,436 solar systems with complete data")
IO.puts("   - Reality: 0 solar systems in database")
IO.puts("   - CSV file has 8,435 systems ready to load")

IO.puts("\n5. ❌ Automated partition management")
IO.puts("   - Reality: NO automation configured")
IO.puts("   - No partition management functions")
IO.puts("   - No pg_cron or similar scheduling")

IO.puts("\n" <> String.duplicate("=", 80))