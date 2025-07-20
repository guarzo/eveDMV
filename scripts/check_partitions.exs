# Script to check existing partitions
# Run with: MIX_ENV=test mix run scripts/check_partitions.exs

# Check what partitions exist
{:ok, %{rows: partitions}} = Ecto.Adapters.SQL.query(
  EveDmv.Repo,
  """
  SELECT 
    tablename
  FROM pg_tables 
  WHERE tablename LIKE 'killmails_raw_y%'
  ORDER BY tablename
  """
)

IO.puts("Existing partitions:")
for [name] <- partitions do
  IO.puts("  #{name}")
end

# Check if killmails_raw is partitioned
{:ok, %{rows: [[is_partitioned]]}} = Ecto.Adapters.SQL.query(
  EveDmv.Repo,
  """
  SELECT 
    relkind = 'p' as is_partitioned
  FROM pg_class
  WHERE relname = 'killmails_raw'
  """
)

IO.puts("\nkillmails_raw is partitioned: #{is_partitioned}")