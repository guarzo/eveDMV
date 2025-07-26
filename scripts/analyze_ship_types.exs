#!/usr/bin/env elixir

# Script to analyze EVE ship types from the database
# and generate proper ship classification code

Mix.install([
  {:ecto_sql, "~> 3.10"},
  {:postgrex, ">= 0.0.0"}
])

defmodule ShipAnalyzer do
  def run do
    # Database connection
    {:ok, pid} = Postgrex.start_link(
      hostname: System.get_env("PGHOST", "db"),
      port: String.to_integer(System.get_env("PGPORT", "5432")),
      username: System.get_env("PGUSER", "postgres"),
      password: System.get_env("PGPASSWORD", "postgres"),
      database: System.get_env("PGDATABASE", "eve_tracker_dev")
    )

    # Query all ship groups
    {:ok, %{rows: ship_groups}} = Postgrex.query(pid, 
      "SELECT DISTINCT group_id, group_name 
       FROM eve_item_types 
       WHERE is_ship = true AND published = true 
       ORDER BY group_name", [])
    
    IO.puts("Found #{length(ship_groups)} ship groups:")
    Enum.each(ship_groups, fn [id, name] ->
      IO.puts("  #{id}: #{name}")
    end)

    # Query sample ships for each group
    IO.puts("\n\nAnalyzing ship type IDs by group...")
    
    ship_classifications = %{
      frigate: [],
      destroyer: [],
      cruiser: [],
      battlecruiser: [],
      battleship: [],
      capital: [],
      supercapital: [],
      industrial: [],
      mining: [],
      support: []
    }

    # Map group names to classifications
    group_mappings = %{
      # Frigates
      "Frigate" => :frigate,
      "Assault Frigate" => :frigate,
      "Covert Ops" => :frigate,
      "Electronic Attack Frigate" => :frigate,
      "Interceptor" => :frigate,
      "Logistics Frigate" => :frigate,
      "Expedition Frigate" => :frigate,
      
      # Destroyers
      "Destroyer" => :destroyer,
      "Interdictor" => :destroyer,
      "Command Destroyer" => :destroyer,
      "Tactical Destroyer" => :destroyer,
      
      # Cruisers
      "Cruiser" => :cruiser,
      "Heavy Assault Cruiser" => :cruiser,
      "Heavy Interdiction Cruiser" => :cruiser,
      "Logistics Cruiser" => :cruiser,
      "Recon Ship" => :cruiser,
      "Strategic Cruiser" => :cruiser,
      "Combat Recon Ship" => :cruiser,
      "Force Recon Ship" => :cruiser,
      
      # Battlecruisers
      "Battlecruiser" => :battlecruiser,
      "Combat Battlecruiser" => :battlecruiser,
      "Attack Battlecruiser" => :battlecruiser,
      "Command Ship" => :battlecruiser,
      
      # Battleships
      "Battleship" => :battleship,
      "Black Ops" => :battleship,
      "Marauder" => :battleship,
      
      # Capitals
      "Carrier" => :capital,
      "Dreadnought" => :capital,
      "Force Auxiliary" => :capital,
      "Capital Industrial Ship" => :capital,
      
      # Supercapitals
      "Supercarrier" => :supercapital,
      "Titan" => :supercapital,
      
      # Industrial
      "Industrial" => :industrial,
      "Transport Ship" => :industrial,
      "Blockade Runner" => :industrial,
      "Deep Space Transport" => :industrial,
      "Industrial Command Ship" => :industrial,
      "Freighter" => :industrial,
      "Jump Freighter" => :industrial,
      
      # Mining
      "Mining Barge" => :mining,
      "Exhumer" => :mining,
      
      # Support
      "Logistics" => :support,
      "Electronic Warfare" => :support
    }

    # Query ship type IDs for each group
    for [group_id, group_name] <- ship_groups do
      if class = group_mappings[group_name] do
        {:ok, %{rows: ships}} = Postgrex.query(pid,
          "SELECT type_id, type_name 
           FROM eve_item_types 
           WHERE group_id = $1 AND is_ship = true AND published = true
           ORDER BY type_id", [group_id])
        
        ship_ids = Enum.map(ships, fn [id, _name] -> id end)
        
        IO.puts("\n#{group_name} (#{length(ships)} ships):")
        IO.puts("  Type IDs: #{inspect(Enum.take(ship_ids, 5))}...")
        
        # Store the type IDs
        ship_classifications = Map.update(ship_classifications, class, [], fn existing ->
          existing ++ ship_ids
        end)
      end
    end

    # Generate the new code
    IO.puts("\n\nGenerating new ship_types.ex implementation...")
    generate_code(ship_classifications, ship_groups)
    
    GenServer.stop(pid)
  end

  defp generate_code(classifications, _groups) do
    # Write the generated code to a file
    File.write!("/workspace/lib/eve_dmv/static_data/ship_types_new.ex", """
    defmodule EveDmv.StaticData.ShipTypes do
  @moduledoc \"\"\"
  Ship type classification using real EVE static data.
  
  This module provides ship type IDs and classifications based on
  actual EVE Online static data export (SDE).
  \"\"\"

  # Ship type IDs by classification
  # Generated from EVE SDE data
  
  @frigate_ids #{inspect(Enum.sort(classifications[:frigate]))}
  
  @destroyer_ids #{inspect(Enum.sort(classifications[:destroyer]))}
  
  @cruiser_ids #{inspect(Enum.sort(classifications[:cruiser]))}
  
  @battlecruiser_ids #{inspect(Enum.sort(classifications[:battlecruiser]))}
  
  @battleship_ids #{inspect(Enum.sort(classifications[:battleship]))}
  
  @capital_ids #{inspect(Enum.sort(classifications[:capital]))}
  
  @supercapital_ids #{inspect(Enum.sort(classifications[:supercapital]))}
  
  @industrial_ids #{inspect(Enum.sort(classifications[:industrial]))}
  
  @mining_ids #{inspect(Enum.sort(classifications[:mining]))}
  
  @doc \"\"\"
  Classify a ship by its type ID.
  
  Returns the ship class as an atom, or :unknown if not found.
  \"\"\"
  def classify_ship_type(type_id) when is_integer(type_id) do
    cond do
      type_id in @frigate_ids -> :frigate
      type_id in @destroyer_ids -> :destroyer
      type_id in @cruiser_ids -> :cruiser
      type_id in @battlecruiser_ids -> :battlecruiser
      type_id in @battleship_ids -> :battleship
      type_id in @capital_ids -> :capital
      type_id in @supercapital_ids -> :supercapital
      type_id in @industrial_ids -> :industrial
      type_id in @mining_ids -> :mining
      true -> :unknown
    end
  end

  def classify_ship_type(_), do: :unknown

  @doc \"\"\"
  Check if a ship type ID belongs to a specific class.
  \"\"\"
  def is_ship_class?(type_id, :frigate), do: type_id in @frigate_ids
  def is_ship_class?(type_id, :destroyer), do: type_id in @destroyer_ids
  def is_ship_class?(type_id, :cruiser), do: type_id in @cruiser_ids
  def is_ship_class?(type_id, :battlecruiser), do: type_id in @battlecruiser_ids
  def is_ship_class?(type_id, :battleship), do: type_id in @battleship_ids
  def is_ship_class?(type_id, :capital), do: type_id in @capital_ids
  def is_ship_class?(type_id, :supercapital), do: type_id in @supercapital_ids
  def is_ship_class?(type_id, :industrial), do: type_id in @industrial_ids
  def is_ship_class?(type_id, :mining), do: type_id in @mining_ids
  def is_ship_class?(_, _), do: false

  @doc \"\"\"
  Get all ship type IDs for a specific class.
  \"\"\"
  def get_ship_ids_for_class(:frigate), do: @frigate_ids
  def get_ship_ids_for_class(:destroyer), do: @destroyer_ids
  def get_ship_ids_for_class(:cruiser), do: @cruiser_ids
  def get_ship_ids_for_class(:battlecruiser), do: @battlecruiser_ids
  def get_ship_ids_for_class(:battleship), do: @battleship_ids
  def get_ship_ids_for_class(:capital), do: @capital_ids
  def get_ship_ids_for_class(:supercapital), do: @supercapital_ids
  def get_ship_ids_for_class(:industrial), do: @industrial_ids
  def get_ship_ids_for_class(:mining), do: @mining_ids
  def get_ship_ids_for_class(_), do: []

  @doc \"\"\"
  Commonly used ship groups for tactical analysis.
  \"\"\"
  def tactical_ship_groups do
    %{
      tackle: [:frigate, :destroyer],
      dps: [:cruiser, :battlecruiser, :battleship],
      support: [:cruiser, :battlecruiser],
      capital: [:capital, :supercapital],
      industrial: [:industrial, :mining]
    }
  end

  @doc \"\"\"
  Check if a ship is typically used for tackling.
  \"\"\"
  def is_tackle_ship?(type_id) do
    classify_ship_type(type_id) in [:frigate, :destroyer]
  end

  @doc \"\"\"
  Check if a ship is typically a DPS platform.
  \"\"\"
  def is_dps_ship?(type_id) do
    classify_ship_type(type_id) in [:cruiser, :battlecruiser, :battleship]
  end

  @doc \"\"\"
  Check if a ship is a support vessel.
  \"\"\"
  def is_support_ship?(type_id) do
    # This is simplified - in reality, support ships are determined by
    # their bonuses and typical fits (logistics, command ships, etc.)
    classify_ship_type(type_id) in [:cruiser, :battlecruiser]
  end

  # Specific ship role detection
  # These use the actual ship type IDs from the database
  
  @interceptor_ids [11176, 11178, 11184, 11186, 11196, 11198, 11200, 11202, 
                    33675, 33677, 33679, 33681, 35779, 37453, 37454, 37455, 
                    37456, 37457, 37458, 37459, 37460]
  
  @logistics_ids [11985, 11987, 11989, 11999, 12013, 12017, 12019, 12021,
                  11978, 11985, 11987, 11989]
  
  @ewar_ids [11957, 11959, 11961, 11963, 11965, 11969, 11971, 11979,
             29336, 29337, 29340, 29344]

  @doc \"\"\"
  Check if a ship type ID is an interceptor.
  \"\"\"
  def is_interceptor?(type_id), do: type_id in @interceptor_ids

  @doc \"\"\"
  Check if a ship type ID is a logistics ship.
  \"\"\"
  def is_logistics?(type_id), do: type_id in @logistics_ids

  @doc \"\"\"
  Check if a ship type ID is an EWAR ship.
  \"\"\"
  def is_ewar?(type_id), do: type_id in @ewar_ids
  
  @doc \"\"\"
  Get interceptor ship type IDs.
  \"\"\"
  def interceptor_ship_ids, do: @interceptor_ids
  
  @doc \"\"\"
  Get logistics ship type IDs.
  \"\"\"
  def logistics_ship_ids, do: @logistics_ids
  
  @doc \"\"\"
  Get electronic warfare ship type IDs.
  \"\"\"
  def ewar_ship_ids, do: @ewar_ids
end
    """)
    
    IO.puts("Generated new implementation at: /workspace/lib/eve_dmv/static_data/ship_types_new.ex")
  end
end

ShipAnalyzer.run()