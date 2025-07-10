defmodule Mix.Tasks.Eve.CheckIndexes do
  @moduledoc """
  Mix task to check current database indexes and suggest missing ones.
  """

  @shortdoc "Check database indexes and suggest optimizations"

  use Mix.Task
  alias EveDmv.Repo
  require Logger

  @impl Mix.Task
  def run(_args) do
    # Start the application to access Repo
    Mix.Task.run("app.start")

    Mix.shell().info("🔍 Checking EVE DMV database indexes...")
    
    # Check existing indexes
    check_existing_indexes()
    
    # Check for missing critical indexes
    check_missing_indexes()
    
    Mix.shell().info("✅ Index check complete!")
  end
  
  defp check_existing_indexes do
    Mix.shell().info("\n📊 Existing Indexes by Table")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    
    query = """
    SELECT 
      tablename,
      indexname,
      pg_size_pretty(pg_relation_size(indexrelid)) as index_size
    FROM pg_indexes
    JOIN pg_stat_user_indexes USING (schemaname, tablename, indexname)
    WHERE schemaname = 'public'
    AND tablename IN ('killmails_raw', 'participants', 'eve_solar_systems', 'eve_item_types', 
                      'character_stats', 'surveillance_profiles', 'surveillance_profile_matches')
    ORDER BY tablename, indexname
    """
    
    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        current_table = nil
        Enum.each(rows, fn [table, index, size] ->
          if table != current_table do
            Mix.shell().info("\n#{table}:")
          end
          Mix.shell().info("  - #{index} (#{size})")
        end)
      {:error, error} ->
        Mix.shell().error("Failed to query indexes: #{inspect(error)}")
    end
  end
  
  defp check_missing_indexes do
    Mix.shell().info("\n\n💡 Recommended Missing Indexes")
    Mix.shell().info("=" <> String.duplicate("=", 50))
    
    # Check for common query patterns without indexes
    critical_indexes = [
      # Killmails_raw indexes
      {"killmails_raw", ["killmail_time"], "Timeline queries"},
      {"killmails_raw", ["solar_system_id", "killmail_time"], "System activity queries"},
      {"killmails_raw", ["victim_character_id", "killmail_time"], "Character intelligence"},
      
      # Participants indexes
      {"participants", ["character_id", "killmail_time"], "Character activity analysis"},
      {"participants", ["corporation_id", "killmail_time"], "Corporation activity"},
      {"participants", ["ship_type_id", "killmail_time"], "Ship usage analysis"},
      {"participants", ["killmail_id"], "Foreign key performance"},
      
      # Static data indexes
      {"eve_solar_systems", ["system_id"], "System name lookups"},
      {"eve_item_types", ["type_id"], "Item name lookups"},
      
      # Character stats
      {"character_stats", ["character_id"], "Character lookups"},
      {"character_stats", ["corporation_id", "dangerous_rating"], "Corp threat assessment"}
    ]
    
    Enum.each(critical_indexes, fn {table, columns, purpose} ->
      if not index_exists?(table, columns) do
        column_list = Enum.join(columns, ", ")
        Mix.shell().info("\n⚠️  Missing: #{table}(#{column_list})")
        Mix.shell().info("   Purpose: #{purpose}")
        Mix.shell().info("   SQL: CREATE INDEX ON #{table} (#{column_list});")
      end
    end)
  end
  
  defp index_exists?(table, columns) do
    # Check if an index exists for the given columns
    column_names = Enum.join(columns, ",")
    
    query = """
    SELECT COUNT(*) 
    FROM pg_indexes 
    WHERE tablename = $1 
    AND schemaname = 'public'
    AND indexdef LIKE '%(' || $2 || ')%'
    """
    
    case Repo.query(query, [table, column_names]) do
      {:ok, %{rows: [[count]]}} -> count > 0
      _ -> false
    end
  end
end