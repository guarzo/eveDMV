# Script to create partitions for test data
# Run with: MIX_ENV=test mix run scripts/create_test_partitions.exs

require Logger

# Create partitions for all months in 2024
for month <- 1..12 do
  date = Date.new!(2024, month, 1)
  
  case Ecto.Adapters.SQL.query(
    EveDmv.Repo, 
    "SELECT create_killmail_partition($1::DATE)",
    [date]
  ) do
    {:ok, %{rows: [[result]]}} ->
      Logger.info("Month #{month}: #{result}")
    {:error, error} ->
      Logger.error("Failed to create partition for month #{month}: #{inspect(error)}")
  end
end

Logger.info("Test partitions created successfully!")