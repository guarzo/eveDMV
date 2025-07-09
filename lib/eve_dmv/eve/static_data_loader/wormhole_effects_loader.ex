defmodule EveDmv.Eve.StaticDataLoader.WormholeEffectsLoader do
  @moduledoc """
  Loads wormhole effect types from reference data and updates the solar systems
  table with wormhole effect information.
  """
  
  alias EveDmv.Api
  alias EveDmv.Eve.SolarSystem
  
  require Logger
  require Ash.Query
  
  def load_wormhole_effects do
    Logger.info("Starting wormhole effects data import from reference files")
    
    with {:ok, wormhole_systems} <- load_wormhole_systems_data(),
         {:ok, effects_data} <- load_effects_data(),
         {:ok, updated_count} <- update_solar_systems(wormhole_systems, effects_data) do
      Logger.info("Successfully updated #{updated_count} solar systems with wormhole effect data")
      {:ok, updated_count}
    else
      {:error, reason} ->
        Logger.error("Failed to load wormhole effects data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp load_wormhole_systems_data do
    Logger.info("Loading wormhole systems data from tmp/wormholeSystems.json")
    
    case File.read("tmp/wormholeSystems.json") do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, systems} ->
            # Create map of solarSystemID -> effectName
            effect_mapping = 
              systems
              |> Enum.filter(fn system -> 
                system["effectName"] != nil and system["effectName"] != ""
              end)
              |> Enum.into(%{}, fn system ->
                {system["solarSystemID"], normalize_effect_name(system["effectName"])}
              end)
            
            Logger.info("Loaded #{map_size(effect_mapping)} wormhole systems with effects")
            {:ok, effect_mapping}
          
          {:error, reason} ->
            {:error, "JSON parsing error: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        {:error, "File read error: #{inspect(reason)}"}
    end
  end
  
  defp load_effects_data do
    Logger.info("Loading effects data from tmp/effects.json")
    
    case File.read("tmp/effects.json") do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, effects} ->
            Logger.info("Loaded #{length(effects)} effect definitions")
            {:ok, effects}
          
          {:error, reason} ->
            {:error, "JSON parsing error: #{inspect(reason)}"}
        end
      
      {:error, reason} ->
        {:error, "File read error: #{inspect(reason)}"}
    end
  end
  
  defp normalize_effect_name(effect_name) do
    case effect_name do
      "Wolf-Rayet Star" -> "Wolf Rayet"
      name -> name
    end
  end
  
  defp update_solar_systems(wormhole_systems, _effects_data) do
    Logger.info("Updating solar systems with wormhole effect data")
    
    # Get all solar systems that need effect updates
    system_ids = Map.keys(wormhole_systems)
    
    systems_to_update = 
      system_ids
      |> Enum.chunk_every(1000)
      |> Enum.flat_map(&get_systems_batch/1)
    
    Logger.info("Found #{length(systems_to_update)} solar systems to update")
    
    # Update systems in batches
    update_count = 
      systems_to_update
      |> Enum.chunk_every(500)
      |> Enum.map(&update_systems_batch(&1, wormhole_systems))
      |> Enum.sum()
    
    {:ok, update_count}
  end
  
  defp get_systems_batch(system_ids) do
    SolarSystem
    |> Ash.Query.new()
    |> Ash.Query.filter(system_id in ^system_ids)
    |> Ash.read!(domain: Api)
  end
  
  defp update_systems_batch(systems, wormhole_systems) do
    systems
    |> Enum.map(fn system ->
      effect_type = Map.get(wormhole_systems, system.system_id)
      
      if effect_type do
        Logger.debug("Updating system #{system.system_id} with effect type: #{effect_type}")
        
        case Ash.update(system, %{wormhole_effect_type: effect_type}, 
                       action: :update_wormhole_data, domain: Api) do
          {:ok, _updated_system} -> 
            Logger.debug("Successfully updated system #{system.system_id}")
            1
          {:error, error} -> 
            Logger.error("Failed to update system #{system.system_id}: #{inspect(error)}")
            0
        end
      else
        0
      end
    end)
    |> Enum.sum()
  end
end