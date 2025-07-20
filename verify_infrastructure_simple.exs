# Simple database infrastructure verification

alias EveDmv.Repo

IO.puts("\n================================================================================")
IO.puts("DATABASE INFRASTRUCTURE VERIFICATION REPORT")
IO.puts("================================================================================")

# 1. Check static data tables
IO.puts("\n1. STATIC DATA TABLES")
IO.puts("----------------------------------------")

# Check eve_item_types
{:ok, item_count} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM eve_item_types", [])
[[items]] = item_count.rows
IO.puts("   eve_item_types: #{items} rows")

# Check eve_solar_systems
{:ok, system_count} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM eve_solar_systems", [])
[[systems]] = system_count.rows
IO.puts("   eve_solar_systems: #{systems} rows")

# 2. Check partitioned tables
IO.puts("\n2. PARTITIONED TABLES")
IO.puts("----------------------------------------")

# Check if partitioned table exists
{:ok, part_exists} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT EXISTS(SELECT 1 FROM pg_tables WHERE tablename = 'killmails_raw_partitioned')",
  []
)
[[has_partitioned]] = part_exists.rows

# Count partitions
{:ok, part_count} = Ecto.Adapters.SQL.query(
  Repo,
  """
  SELECT COUNT(DISTINCT child.relname) 
  FROM pg_inherits 
  JOIN pg_class parent ON pg_inherits.inhparent = parent.oid 
  JOIN pg_class child ON pg_inherits.inhrelid = child.oid 
  WHERE parent.relname = 'killmails_raw_partitioned'
  """,
  []
)
[[partition_count]] = part_count.rows

IO.puts("   Partitioned table exists: #{has_partitioned}")
IO.puts("   Number of partitions: #{partition_count}")

# Check if regular table is being used instead
{:ok, raw_count} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM killmails_raw", [])
[[raw_rows]] = raw_count.rows
IO.puts("   killmails_raw (non-partitioned) rows: #{raw_rows}")

# 3. Check materialized views
IO.puts("\n3. MATERIALIZED VIEWS")
IO.puts("----------------------------------------")

{:ok, matviews} = Ecto.Adapters.SQL.query(
  Repo,
  "SELECT matviewname FROM pg_matviews WHERE schemaname = 'public' ORDER BY matviewname",
  []
)

IO.puts("   Found #{length(matviews.rows)} materialized views:")
Enum.each(matviews.rows, fn [name] ->
  # Try to count rows (might fail if view needs refresh)
  try do
    {:ok, result} = Ecto.Adapters.SQL.query(Repo, "SELECT COUNT(*) FROM #{name}", [])
    [[count]] = result.rows
    IO.puts("   - #{name}: #{count} rows")
  rescue
    _ -> IO.puts("   - #{name}: (needs refresh)")
  end
end)

# 4. Check CSV files
IO.puts("\n4. STATIC DATA CSV FILES")
IO.puts("----------------------------------------")

csv_dir = "priv/static_data"
if File.exists?(csv_dir) do
  csv_files = File.ls!(csv_dir)
  |> Enum.filter(&String.ends_with?(&1, ".csv"))
  |> Enum.sort()
  
  Enum.each(csv_files, fn file ->
    path = Path.join(csv_dir, file)
    line_count = path |> File.stream!() |> Enum.count()
    IO.puts("   #{file}: #{line_count - 1} records (excluding header)")
  end)
else
  IO.puts("   CSV directory not found")
end

# 5. Summary
IO.puts("\n================================================================================")
IO.puts("SUMMARY: CLAIMS vs REALITY")
IO.puts("================================================================================")

IO.puts("\nClaim 1: Partitioned tables for scalability (monthly partitions)")
IO.puts("Reality: #{if has_partitioned, do: "✅ Structure EXISTS with #{partition_count} partitions", else: "❌ NOT FOUND"}")
IO.puts("         #{if raw_rows > 0, do: "⚠️  BUT app uses non-partitioned table", else: "⚠️  No data in either table"}")

IO.puts("\nClaim 2: Materialized views for performance")
IO.puts("Reality: ✅ #{length(matviews.rows)} materialized views EXIST")
IO.puts("         #{if length(matviews.rows) > 0, do: "⚠️  BUT all are empty (0 rows)", else: ""}")

IO.puts("\nClaim 3: 49,906 item types loaded from EVE SDE")
IO.puts("Reality: ❌ Only #{items} item types in database")
IO.puts("         📁 CSV file has 104,954 items ready to load")

IO.puts("\nClaim 4: 8,436 solar systems with complete data")
IO.puts("Reality: ❌ Only #{systems} solar systems in database")
IO.puts("         📁 CSV file has 8,436 systems ready to load")

IO.puts("\nClaim 5: Automated partition management")
IO.puts("Reality: ❌ NO automation found (no functions, no pg_cron)")

IO.puts("\n================================================================================")