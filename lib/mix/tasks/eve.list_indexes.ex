defmodule Mix.Tasks.Eve.ListIndexes do
  @moduledoc """
  Mix task to list all indexes in the database.
  """

  @shortdoc "List all database indexes"

  use Mix.Task
  alias EveDmv.Repo

  @impl Mix.Task
  def run(_args) do
    # Start the application to access Repo
    Mix.Task.run("app.start")

    Mix.shell().info("📊 Database Indexes")
    Mix.shell().info("=" <> String.duplicate("=", 60))
    
    query = """
    SELECT 
      p.tablename,
      p.indexname,
      p.indexdef,
      pg_size_pretty(pg_relation_size(p.indexname::regclass)) as index_size
    FROM pg_indexes p
    WHERE p.schemaname = 'public'
    AND p.tablename IN ('killmails_raw', 'participants', 'character_stats', 
                        'eve_solar_systems', 'eve_item_types')
    ORDER BY p.tablename, p.indexname
    """
    
    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        current_table = nil
        
        Enum.each(rows, fn [table, index, indexdef, size] ->
          if table != current_table do
            Mix.shell().info("\n📁 #{table}")
            Mix.shell().info("  " <> String.duplicate("-", 58))
          end
          
          # Extract column names from indexdef
          columns = case Regex.run(~r/\((.*?)\)/, indexdef) do
            [_, cols] -> cols
            _ -> "unknown"
          end
          
          Mix.shell().info("  #{index}")
          Mix.shell().info("    Columns: #{columns}")
          Mix.shell().info("    Size: #{size}")
        end)
        
        Mix.shell().info("\n\nTotal indexes: #{length(rows)}")
        
      {:error, error} ->
        Mix.shell().error("Failed to query indexes: #{inspect(error)}")
    end
  end
end