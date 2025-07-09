defmodule EveDmv.Eve.StaticDataLoader.WormholeClassLoader do
  @moduledoc """
  Loads wormhole class data from Fuzzwork's mapLocationWormholeClasses.csv
  and updates the solar systems table with wormhole class information.
  """
  
  alias EveDmv.Api
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Eve.StaticDataLoader.CsvParser
  
  require Logger
  require Ash.Query
  
  @fuzzwork_url "https://www.fuzzwork.co.uk/dump/latest/mapLocationWormholeClasses.csv"
  
  def load_wormhole_classes do
    Logger.info("Starting wormhole class data import from Fuzzwork")
    
    with {:ok, csv_data} <- fetch_csv_data(),
         {:ok, wormhole_data} <- parse_wormhole_data(csv_data),
         {:ok, updated_count} <- update_solar_systems(wormhole_data) do
      Logger.info("Successfully updated #{updated_count} solar systems with wormhole class data")
      {:ok, updated_count}
    else
      {:error, reason} ->
        Logger.error("Failed to load wormhole class data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  defp fetch_csv_data do
    Logger.info("Fetching wormhole class data from: #{@fuzzwork_url}")
    
    case HTTPoison.get(@fuzzwork_url, [], timeout: 30_000) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      
      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, "HTTP #{status_code} error fetching wormhole class data"}
      
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Network error: #{reason}"}
    end
  end
  
  defp parse_wormhole_data(csv_data) do
    Logger.info("Parsing wormhole class CSV data")
    
    try do
      wormhole_data =
        csv_data
        |> CsvParser.parse_csv_content(&parse_wormhole_row/1)
        |> Enum.filter(& &1)
        |> Map.new()
      
      Logger.info("Parsed #{map_size(wormhole_data)} wormhole class mappings")
      {:ok, wormhole_data}
    rescue
      error ->
        {:error, "CSV parsing error: #{Exception.message(error)}"}
    end
  end
  
  defp parse_wormhole_row(%{"locationID" => location_id, "wormholeClassID" => class_id}) do
    with {location_id_int, ""} <- Integer.parse(location_id),
         {class_id_int, ""} <- Integer.parse(class_id) do
      {location_id_int, class_id_int}
    else
      _ -> nil
    end
  end
  
  defp parse_wormhole_row(_), do: nil
  
  defp update_solar_systems(wormhole_data) do
    Logger.info("Updating solar systems with wormhole class data")
    
    # Get all solar systems that need wormhole class updates
    systems_to_update = 
      wormhole_data
      |> Map.keys()
      |> Enum.chunk_every(1000)
      |> Enum.flat_map(&get_systems_batch/1)
    
    Logger.info("Found #{length(systems_to_update)} solar systems to update")
    
    # Update systems in batches
    update_count = 
      systems_to_update
      |> Enum.chunk_every(500)
      |> Enum.map(&update_systems_batch(&1, wormhole_data))
      |> Enum.sum()
    
    {:ok, update_count}
  end
  
  defp get_systems_batch(system_ids) do
    SolarSystem
    |> Ash.Query.new()
    |> Ash.Query.filter(system_id in ^system_ids)
    |> Ash.read!(domain: Api)
  end
  
  defp update_systems_batch(systems, wormhole_data) do
    systems
    |> Enum.map(fn system ->
      wormhole_class_id = Map.get(wormhole_data, system.system_id)
      
      if wormhole_class_id do
        Logger.debug("Updating system #{system.system_id} with wormhole class #{wormhole_class_id}")
        case Ash.update(system, %{wormhole_class_id: wormhole_class_id}, action: :update_wormhole_data, domain: Api) do
          {:ok, _updated_system} -> 
            Logger.debug("Successfully updated system #{system.system_id}")
            1
          {:error, error} -> 
            Logger.error("Failed to update system #{system.system_id}: #{inspect(error)}")
            0
        end
      else
        Logger.debug("No wormhole class found for system #{system.system_id}")
        0
      end
    end)
    |> Enum.sum()
  end
end