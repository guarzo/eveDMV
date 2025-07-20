# Verify database infrastructure claims

alias EveDmv.Repo
import Ecto.Query

# 1. Count eve_item_types
{:ok, item_result} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM eve_item_types", [])
[[item_count]] = item_result.rows
IO.puts("\n=== EVE ITEM TYPES ===")
IO.puts("Count: #{item_count}")

# Sample some item types
{:ok, sample_items} = Ecto.Adapters.SQL.query(
  Repo, 
  "SELECT type_id, type_name, group_name, category_name FROM eve_item_types ORDER BY RANDOM() LIMIT 5", 
  []
)
IO.puts("Sample items:")
Enum.each(sample_items.rows, fn [id, name, group, category] ->
  IO.puts("  - #{id}: #{name} (#{group || "N/A"} / #{category || "N/A"})")
end)

# 2. Count eve_solar_systems
{:ok, system_result} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM eve_solar_systems", [])
[[system_count]] = system_result.rows
IO.puts("\n=== EVE SOLAR SYSTEMS ===")
IO.puts("Count: #{system_count}")

# Sample some systems
{:ok, sample_systems} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT system_id, system_name, region_name, security_status, wormhole_class_id FROM eve_solar_systems ORDER BY RANDOM() LIMIT 5",
  []
)
IO.puts("Sample systems:")
Enum.each(sample_systems.rows, fn [id, name, region, sec, wh_class] ->
  IO.puts("  - #{id}: #{name} (#{region || "N/A"}) - Sec: #{sec || "N/A"}, WH Class: #{wh_class || "N/A"}")
end)

# 3. Check for partitioned tables
{:ok, partition_result} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT 
    parent.relname AS parent_table,
    child.relname AS partition_name,
    pg_get_expr(child.relpartbound, child.oid, true) AS partition_constraint
  FROM pg_inherits
  JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
  JOIN pg_class child ON pg_inherits.inhrelid = child.oid
  WHERE parent.relnamespace = 'public'::regnamespace
  ORDER BY parent.relname, child.relname
  """,
  []
)
IO.puts("\n=== PARTITIONED TABLES ===")
if partition_result.rows == [] do
  IO.puts("No partitioned tables found")
else
  IO.puts("Found #{length(partition_result.rows)} partitions:")
  Enum.each(partition_result.rows, fn [parent, partition, constraint] ->
    IO.puts("  - #{parent} -> #{partition}")
    IO.puts("    Constraint: #{constraint}")
  end)
end

# 4. Check for materialized views
{:ok, matview_result} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT matviewname FROM pg_matviews WHERE schemaname = 'public' ORDER BY matviewname",
  []
)
IO.puts("\n=== MATERIALIZED VIEWS ===")
if matview_result.rows == [] do
  IO.puts("No materialized views found")
else
  IO.puts("Found #{length(matview_result.rows)} materialized views:")
  Enum.each(matview_result.rows, fn [view_name] ->
    IO.puts("  - #{view_name}")
    
    # Get row count for each view
    try do
      {:ok, count_result} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM #{view_name}", [])
      [[count]] = count_result.rows
      IO.puts("    Rows: #{count}")
    rescue
      _ -> IO.puts("    (Unable to count rows)")
    end
  end)
end

# 5. Check for partition management functions
{:ok, func_result} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT proname 
  FROM pg_proc 
  WHERE pronamespace = 'public'::regnamespace 
  AND proname LIKE '%partition%'
  """,
  []
)
IO.puts("\n=== PARTITION MANAGEMENT FUNCTIONS ===")
if func_result.rows == [] do
  IO.puts("No partition management functions found")
else
  IO.puts("Found functions:")
  Enum.each(func_result.rows, fn [func_name] ->
    IO.puts("  - #{func_name}")
  end)
end

# 6. Check view refresh tracking table
{:ok, tracking_result} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT view_name, last_refresh_time, refresh_type FROM view_refresh_tracking ORDER BY view_name",
  []
)
IO.puts("\n=== VIEW REFRESH TRACKING ===")
if tracking_result.rows == [] do
  IO.puts("No refresh tracking data found")
else
  IO.puts("Refresh tracking:")
  Enum.each(tracking_result.rows, fn [view, time, type] ->
    IO.puts("  - #{view}: Last refresh #{time || "Never"} (#{type || "N/A"})")
  end)
end

IO.puts("\n=== SUMMARY ===")
IO.puts("1. EVE Item Types: #{item_count} (Claimed: 49,906)")
IO.puts("2. EVE Solar Systems: #{system_count} (Claimed: 8,436)")
IO.puts("3. Partitioned Tables: #{if partition_result.rows == [], do: "NOT FOUND", else: "FOUND (#{length(partition_result.rows)} partitions)"}")
IO.puts("4. Materialized Views: #{if matview_result.rows == [], do: "NOT FOUND", else: "FOUND (#{length(matview_result.rows)} views)"}")
IO.puts("5. Partition Management: #{if func_result.rows == [], do: "No automated functions found", else: "Functions found"}")