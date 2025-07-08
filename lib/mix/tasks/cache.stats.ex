defmodule Mix.Tasks.Cache.Stats do
  @moduledoc """
  Mix task to show cache statistics and manage cache entries.
  
  ## Examples
  
      # Show cache statistics
      mix cache.stats
      
      # Clear specific corporation cache
      mix cache.stats --clear-corp 12345
      
      # Clear specific character cache  
      mix cache.stats --clear-char 67890
      
      # Clear all cache
      mix cache.stats --clear-all
  """
  
  use Mix.Task
  
  @shortdoc "Show cache statistics and manage cache entries"
  
  def run(args) do
    Mix.Task.run("app.start")
    
    {opts, _, _} = OptionParser.parse(args, 
      switches: [
        clear_corp: :integer,
        clear_char: :integer,
        clear_all: :boolean
      ],
      aliases: [c: :clear_corp, a: :clear_all]
    )
    
    # Handle cache operations
    cond do
      opts[:clear_all] ->
        clear_all_cache()
        
      corp_id = opts[:clear_corp] ->
        clear_corporation_cache(corp_id)
        
      char_id = opts[:clear_char] ->
        clear_character_cache(char_id)
        
      true ->
        show_cache_stats()
    end
  end
  
  defp show_cache_stats do
    stats = EveDmv.Cache.AnalysisCache.stats()
    
    Mix.shell().info("📊 Analysis Cache Statistics")
    Mix.shell().info("=" <> String.duplicate("=", 40))
    Mix.shell().info("Total Entries: #{stats.total_entries}")
    Mix.shell().info("Memory Usage: #{stats.memory_mb} MB (#{stats.memory_bytes} bytes)")
    
    if stats.total_entries > 0 do
      Mix.shell().info("\n💡 Cache Management:")
      Mix.shell().info("  Clear corporation cache: mix cache.stats --clear-corp CORP_ID")
      Mix.shell().info("  Clear character cache: mix cache.stats --clear-char CHAR_ID")
      Mix.shell().info("  Clear all cache: mix cache.stats --clear-all")
    else
      Mix.shell().info("\n✨ Cache is empty")
    end
  end
  
  defp clear_all_cache do
    EveDmv.Cache.AnalysisCache.clear_all()
    Mix.shell().info("✅ Cleared all cache entries")
    show_cache_stats()
  end
  
  defp clear_corporation_cache(corp_id) do
    EveDmv.Cache.AnalysisCache.invalidate_corporation(corp_id)
    Mix.shell().info("✅ Cleared cache for corporation #{corp_id}")
    show_cache_stats()
  end
  
  defp clear_character_cache(char_id) do
    EveDmv.Cache.AnalysisCache.invalidate_character(char_id)
    Mix.shell().info("✅ Cleared cache for character #{char_id}")
    show_cache_stats()
  end
end