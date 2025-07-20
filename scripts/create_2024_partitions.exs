# Script to create 2024 partitions directly
# Run with: MIX_ENV=test mix run scripts/create_2024_partitions.exs

require Logger

# Create partitions for all months in 2024 directly
for month <- 1..12 do
  month_str = String.pad_leading(Integer.to_string(month), 2, "0")
  partition_name = "killmails_raw_y2024m#{month_str}"
  
  start_date = "2024-#{month_str}-01"
  end_month = if month == 12, do: 1, else: month + 1
  end_year = if month == 12, do: 2025, else: 2024
  end_month_str = String.pad_leading(Integer.to_string(end_month), 2, "0")
  end_date = "#{end_year}-#{end_month_str}-01"
  
  # Create partition
  case Ecto.Adapters.SQL.query(
    EveDmv.Repo,
    """
    CREATE TABLE #{partition_name} PARTITION OF killmails_raw
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
    """
  ) do
    {:ok, _} ->
      Logger.info("Created partition #{partition_name}")
      
      # Create indexes
      Ecto.Adapters.SQL.query!(
        EveDmv.Repo,
        "CREATE INDEX #{partition_name}_system_time_idx ON #{partition_name} (solar_system_id, killmail_time)"
      )
      
      Ecto.Adapters.SQL.query!(
        EveDmv.Repo,
        "CREATE INDEX #{partition_name}_victim_time_idx ON #{partition_name} (victim_character_id, killmail_time)"
      )
      
    {:error, %{postgres: %{code: :duplicate_table}}} ->
      Logger.info("Partition #{partition_name} already exists")
      
    {:error, error} ->
      Logger.error("Failed to create partition #{partition_name}: #{inspect(error)}")
  end
end

Logger.info("2024 partitions created successfully!")