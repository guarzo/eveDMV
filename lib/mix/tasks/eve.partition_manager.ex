defmodule Mix.Tasks.Eve.PartitionManager do
  @moduledoc """
  Partition management commands for EVE DMV killmail tables.

  ## Examples

      # Show current partition status
      mix eve.partition_manager status

      # Create partitions for next 3 months
      mix eve.partition_manager create_future

      # Create partition for specific month
      mix eve.partition_manager create 2024-12

      # Clean up old partitions (default: 12 months retention)
      mix eve.partition_manager cleanup

      # Clean up with custom retention (6 months)
      mix eve.partition_manager cleanup --months=6

      # Show partition statistics
      mix eve.partition_manager stats
  """

  @shortdoc "Manage database table partitions"

  use Mix.Task

  alias EveDmv.Database.PartitionAutomation

  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["status"] ->
        show_status()

      ["create_future"] ->
        create_future_partitions()

      ["create", date_str] ->
        create_partition_for_date(date_str)

      ["cleanup"] ->
        cleanup_old_partitions(12)

      ["cleanup", "--months=" <> months_str] ->
        cleanup_old_partitions(String.to_integer(months_str))

      ["stats"] ->
        show_statistics()

      _ ->
        show_help()
    end
  end

  defp show_status do
    Mix.shell().info("📊 EVE DMV Partition Manager - Status")
    Mix.shell().info("=====================================")

    case PartitionAutomation.get_partition_stats() do
      {:ok, stats} ->
        Mix.shell().info("Total partitions: #{stats.total_partitions}")
        Mix.shell().info("")

        if stats.total_partitions > 0 do
          Mix.shell().info("Partition Details:")

          Enum.each(stats.partitions, fn partition ->
            Mix.shell().info("  • #{partition["tablename"]} - Size: #{partition["size"]}")
          end)
        else
          Mix.shell().info(
            "⚠️  No partitions found. Run 'mix eve.partition_manager create_future' to create initial partitions."
          )
        end

      {:error, error} ->
        Mix.shell().error("❌ Failed to get partition status: #{inspect(error)}")
    end
  end

  defp create_future_partitions do
    Mix.shell().info("🔧 Creating partitions for next 3 months...")

    case PartitionAutomation.ensure_future_partitions(3) do
      {:ok, messages} ->
        Mix.shell().info("✅ Success!")
        Enum.each(messages, &Mix.shell().info("  • #{&1}"))

      {:error, error} ->
        Mix.shell().error("❌ Failed to create partitions: #{inspect(error)}")
    end
  end

  defp create_partition_for_date(date_str) do
    Mix.shell().info("🔧 Creating partition for #{date_str}...")

    case parse_date(date_str) do
      {:ok, date} ->
        case PartitionAutomation.create_partition_for_month(date) do
          {:ok, message} ->
            Mix.shell().info("✅ #{message}")

          {:error, error} ->
            Mix.shell().error("❌ Failed to create partition: #{inspect(error)}")
        end

      {:error, error} ->
        Mix.shell().error("❌ Invalid date format: #{error}")
        Mix.shell().info("Expected format: YYYY-MM (e.g., 2024-12)")
    end
  end

  defp cleanup_old_partitions(retention_months) do
    Mix.shell().info("🧹 Cleaning up partitions older than #{retention_months} months...")

    case PartitionAutomation.cleanup_old_partitions(retention_months) do
      {:ok, {count, dropped}} ->
        Mix.shell().info("✅ Cleaned up #{count} old partitions")

        if count > 0 do
          Enum.each(dropped, &Mix.shell().info("  • Dropped: #{&1}"))
        end

      {:error, error} ->
        Mix.shell().error("❌ Failed to cleanup partitions: #{inspect(error)}")
    end
  end

  defp show_statistics do
    Mix.shell().info("📈 Partition Statistics")
    Mix.shell().info("======================")

    case PartitionAutomation.get_partition_stats() do
      {:ok, stats} ->
        if stats.total_partitions > 0 do
          # Calculate total size across all partitions
          total_size_bytes =
            stats.partitions
            |> Enum.map(fn p -> parse_size_to_bytes(p["size"]) end)
            |> Enum.sum()

          Mix.shell().info("Total partitions: #{stats.total_partitions}")
          Mix.shell().info("Total estimated size: #{format_bytes(total_size_bytes)}")
          Mix.shell().info("")

          Mix.shell().info("Individual partitions:")

          stats.partitions
          |> Enum.sort_by(& &1["tablename"])
          |> Enum.each(fn partition ->
            # Extract date from partition name for better display
            date_str = extract_date_from_partition_name(partition["tablename"])
            Mix.shell().info("  #{date_str}: #{partition["size"]}")
          end)
        else
          Mix.shell().info("No partitions found.")
        end

      {:error, error} ->
        Mix.shell().error("❌ Failed to get statistics: #{inspect(error)}")
    end
  end

  defp parse_date(date_str) do
    case String.split(date_str, "-") do
      [year_str, month_str] ->
        try do
          year = String.to_integer(year_str)
          month = String.to_integer(month_str)
          {:ok, Date.new!(year, month, 1)}
        rescue
          _ -> {:error, "Invalid year or month"}
        end

      _ ->
        {:error, "Expected format YYYY-MM"}
    end
  end

  defp extract_date_from_partition_name(tablename) do
    case Regex.run(~r/y(\d{4})m(\d{2})/, tablename) do
      [_, year, month] -> "#{year}-#{month}"
      _ -> "unknown"
    end
  end

  defp parse_size_to_bytes(size_string) when is_binary(size_string) do
    case Regex.run(~r/(\d+\.?\d*)\s*(\w+)/, size_string) do
      [_, size_str, unit] ->
        size = if String.contains?(size_str, ".") do
          String.to_float(size_str)
        else
          String.to_integer(size_str) * 1.0
        end

        case String.upcase(unit) do
          "BYTES" -> size
          "KB" -> size * 1024
          "MB" -> size * 1024 * 1024
          "GB" -> size * 1024 * 1024 * 1024
          _ -> 0.0
        end

      _ ->
        0.0
    end
  end

  defp parse_size_to_bytes(_), do: 0.0

  defp format_bytes(bytes) when bytes < 1024, do: "#{:erlang.round(bytes)} bytes"
  defp format_bytes(bytes) when bytes < 1024 * 1024, do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_bytes(bytes) when bytes < 1024 * 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / (1024 * 1024 * 1024), 1)} GB"

  defp show_help do
    Mix.shell().info(@moduledoc)
  end
end
