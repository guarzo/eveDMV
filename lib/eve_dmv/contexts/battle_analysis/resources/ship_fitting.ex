defmodule EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting do
  @moduledoc """
  Resource for storing ship fittings for performance analysis.
  
  Supports multiple fitting formats:
  - EFT (EVE Fitting Tool)
  - PyFA
  - In-game fitting links
  - Manual entry
  """
  
  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer
  
  postgres do
    table "ship_fittings"
    repo EveDmv.Repo
  end
  
  attributes do
    uuid_primary_key :id
    
    # Basic info
    attribute :name, :string, allow_nil?: false
    attribute :ship_type_id, :integer, allow_nil?: false
    attribute :character_id, :integer
    attribute :source, :atom, constraints: [one_of: [:eft, :pyfa, :ingame, :manual, :detected]], default: :manual
    
    # Fitting data
    attribute :raw_fitting, :string, allow_nil?: false  # Original format
    attribute :parsed_fitting, :map, default: %{}        # Structured format
    
    # Calculated stats (cached)
    attribute :calculated_stats, :map, default: %{}
    attribute :last_calculated, :utc_datetime_usec
    
    # Metadata
    attribute :tags, {:array, :string}, default: []
    attribute :is_public, :boolean, default: false
    attribute :usage_count, :integer, default: 0
    
    timestamps()
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :import_eft do
      argument :eft_text, :string, allow_nil?: false
      argument :character_id, :integer
      
      change fn changeset, _ ->
        eft_text = Ash.Changeset.get_argument(changeset, :eft_text)
        
        case parse_eft_fitting(eft_text) do
          {:ok, parsed} ->
            changeset
            |> Ash.Changeset.change_attribute(:name, parsed.name)
            |> Ash.Changeset.change_attribute(:ship_type_id, parsed.ship_type_id)
            |> Ash.Changeset.change_attribute(:raw_fitting, eft_text)
            |> Ash.Changeset.change_attribute(:parsed_fitting, parsed)
            |> Ash.Changeset.change_attribute(:source, :eft)
            |> Ash.Changeset.change_attribute(:character_id, Ash.Changeset.get_argument(changeset, :character_id))
            
          {:error, reason} ->
            Ash.Changeset.add_error(changeset, field: :eft_text, message: "Invalid EFT format: #{reason}")
        end
      end
    end
    
    create :import_pyfa do
      argument :pyfa_xml, :string, allow_nil?: false
      argument :character_id, :integer
      
      change fn changeset, _ ->
        pyfa_xml = Ash.Changeset.get_argument(changeset, :pyfa_xml)
        
        case parse_pyfa_fitting(pyfa_xml) do
          {:ok, parsed} ->
            changeset
            |> Ash.Changeset.change_attribute(:name, parsed.name)
            |> Ash.Changeset.change_attribute(:ship_type_id, parsed.ship_type_id)
            |> Ash.Changeset.change_attribute(:raw_fitting, pyfa_xml)
            |> Ash.Changeset.change_attribute(:parsed_fitting, parsed)
            |> Ash.Changeset.change_attribute(:source, :pyfa)
            |> Ash.Changeset.change_attribute(:character_id, Ash.Changeset.get_argument(changeset, :character_id))
            
          {:error, reason} ->
            Ash.Changeset.add_error(changeset, field: :pyfa_xml, message: "Invalid PyFA format: #{reason}")
        end
      end
    end
    
    create :detect_from_killmail do
      argument :killmail, :map, allow_nil?: false
      
      change fn changeset, _ ->
        killmail = Ash.Changeset.get_argument(changeset, :killmail)
        
        # Extract fitting from killmail items
        parsed = extract_fitting_from_killmail(killmail)
        
        changeset
        |> Ash.Changeset.change_attribute(:name, "Detected: #{killmail.victim.ship_name || "Unknown"}")
        |> Ash.Changeset.change_attribute(:ship_type_id, killmail.victim.ship_type_id)
        |> Ash.Changeset.change_attribute(:character_id, killmail.victim.character_id)
        |> Ash.Changeset.change_attribute(:raw_fitting, inspect(killmail.items))
        |> Ash.Changeset.change_attribute(:parsed_fitting, parsed)
        |> Ash.Changeset.change_attribute(:source, :detected)
      end
    end
    
    update :calculate_stats do
      # Calculate theoretical ship stats from fitting
      change fn changeset, _ ->
        fitting = changeset.data
        
        stats = calculate_fitting_stats(fitting.parsed_fitting, fitting.ship_type_id)
        
        changeset
        |> Ash.Changeset.change_attribute(:calculated_stats, stats)
        |> Ash.Changeset.change_attribute(:last_calculated, DateTime.utc_now())
      end
    end
    
    update :increment_usage do
      change fn changeset, _ ->
        Ash.Changeset.change_attribute(changeset, :usage_count, changeset.data.usage_count + 1)
      end
    end
  end
  
  code_interface do
    define :import_eft
    define :import_pyfa
    define :detect_from_killmail
    define :calculate_stats
    define :increment_usage
    define :read
    define :destroy
  end
  
  # Parsing helpers
  
  defp parse_eft_fitting(eft_text) do
    lines = String.split(eft_text, "\n", trim: true)
    
    case lines do
      [header | module_lines] ->
        # Parse header like "[Rifter, PvP Fit]"
        case Regex.run(~r/\[(.+?),\s*(.+?)\]/, header) do
          [_, ship_name, fit_name] ->
            ship_type_id = resolve_ship_type_id(ship_name)
            
            # Parse modules
            modules = parse_eft_modules(module_lines)
            
            {:ok, %{
              name: fit_name,
              ship_name: ship_name,
              ship_type_id: ship_type_id,
              high_slots: modules.high,
              mid_slots: modules.mid,
              low_slots: modules.low,
              rig_slots: modules.rigs,
              cargo: modules.cargo
            }}
            
          _ ->
            {:error, "Invalid header format"}
        end
        
      _ ->
        {:error, "Empty fitting"}
    end
  end
  
  defp parse_eft_modules(lines) do
    {_current_section, modules} = Enum.reduce(lines, {:unknown, %{high: [], mid: [], low: [], rigs: [], cargo: []}}, fn line, {section, mods} ->
      cond do
        String.trim(line) == "" ->
          # Empty line indicates section change
          {next_section(section), mods}
          
        String.contains?(line, " x") ->
          # Cargo/drone bay items
          {section, Map.update(mods, :cargo, [line], &[line | &1])}
          
        true ->
          # Regular module
          slot_type = if section == :unknown, do: detect_slot_type(line), else: section
          {section, Map.update(mods, slot_type, [line], &[line | &1])}
      end
    end)
    
    # Reverse to maintain order
    %{
      high: Enum.reverse(modules.high),
      mid: Enum.reverse(modules.mid),
      low: Enum.reverse(modules.low),
      rigs: Enum.reverse(modules.rigs),
      cargo: Enum.reverse(modules.cargo)
    }
  end
  
  defp next_section(:unknown), do: :high
  defp next_section(:high), do: :mid
  defp next_section(:mid), do: :low
  defp next_section(:low), do: :rigs
  defp next_section(:rigs), do: :cargo
  defp next_section(:cargo), do: :cargo
  
  defp detect_slot_type(module_name) do
    # Simple detection based on common module names
    cond do
      String.contains?(module_name, ["Launcher", "Turret", "Laser", "Railgun", "Autocannon", "Artillery"]) -> :high
      String.contains?(module_name, ["Shield", "Afterburner", "Microwarpdrive", "Web", "Scram", "Disruptor"]) -> :mid
      String.contains?(module_name, ["Armor", "Damage", "Gyrostabilizer", "Heat Sink", "Magnetic"]) -> :low
      String.contains?(module_name, ["Rig", "Cache", "Accelerator"]) -> :rigs
      true -> :unknown
    end
  end
  
  defp parse_pyfa_fitting(_xml_text) do
    # Simplified PyFA parsing - in production would use proper XML parser
    {:error, "PyFA import not yet implemented"}
  end
  
  defp extract_fitting_from_killmail(killmail) do
    # Group items by flag (slot location)
    items_by_slot = Enum.group_by(killmail[:items] || [], & &1[:flag])
    
    %{
      name: "Lossmmail Fit",
      ship_name: killmail.victim[:ship_name],
      ship_type_id: killmail.victim.ship_type_id,
      high_slots: extract_slot_items(items_by_slot, 27..34),   # HiSlot0-7
      mid_slots: extract_slot_items(items_by_slot, 19..26),    # MedSlot0-7
      low_slots: extract_slot_items(items_by_slot, 11..18),    # LoSlot0-7
      rig_slots: extract_slot_items(items_by_slot, 92..94),    # RigSlot0-2
      cargo: extract_cargo_items(items_by_slot)
    }
  end
  
  defp extract_slot_items(items_by_slot, slot_range) do
    slot_range
    |> Enum.flat_map(fn slot -> Map.get(items_by_slot, slot, []) end)
    |> Enum.map(& &1[:type_name] || "Unknown Module")
  end
  
  defp extract_cargo_items(items_by_slot) do
    cargo_flag = 5  # Cargo bay
    Map.get(items_by_slot, cargo_flag, [])
    |> Enum.map(fn item ->
      "#{item[:type_name] || "Unknown"} x#{item[:quantity] || 1}"
    end)
  end
  
  defp resolve_ship_type_id(ship_name) do
    # Query the item_types table for the ship
    case Ash.read_one(EveDmv.Eve.ItemType, filter: [type_name: ship_name, is_ship: true]) do
      {:ok, ship} -> ship.type_id
      _ -> 
        # Try case-insensitive search
        case Ash.read(EveDmv.Eve.ItemType, filter: [is_ship: true]) do
          {:ok, ships} ->
            ship = Enum.find(ships, fn s -> 
              String.downcase(s.type_name) == String.downcase(ship_name)
            end)
            if ship, do: ship.type_id, else: 0
          _ -> 0
        end
    end
  end
  
  defp calculate_fitting_stats(parsed_fitting, ship_type_id) do
    # In production, this would use actual EVE formulas and module stats
    # For now, return estimated stats based on modules
    
    _high_slot_count = length(parsed_fitting[:high_slots] || [])
    _mid_slot_count = length(parsed_fitting[:mid_slots] || [])
    _low_slot_count = length(parsed_fitting[:low_slots] || [])
    
    %{
      dps: estimate_dps_from_modules(parsed_fitting),
      ehp: estimate_ehp_from_modules(parsed_fitting, ship_type_id),
      speed: estimate_speed_from_modules(parsed_fitting, ship_type_id),
      signature: estimate_sig_from_modules(parsed_fitting, ship_type_id),
      capacitor: %{
        stable: false,
        duration: 120  # seconds
      }
    }
  end
  
  defp estimate_dps_from_modules(parsed_fitting) do
    weapon_count = parsed_fitting[:high_slots]
    |> Enum.count(fn mod -> 
      String.contains?(mod, ["Launcher", "Turret", "Laser", "Railgun", "Autocannon", "Artillery"])
    end)
    
    weapon_count * 100  # Simplified DPS per weapon
  end
  
  defp estimate_ehp_from_modules(parsed_fitting, ship_type_id) do
    # Base EHP varies by ship class
    base_ehp = cond do
      ship_type_id in 582..650 -> 2000     # Frigates
      ship_type_id in 620..634 -> 15000    # Cruisers
      ship_type_id in 638..645 -> 70000    # Battleships
      true -> 10000
    end
    
    # Add tank module bonuses
    tank_modules = (parsed_fitting[:mid_slots] || []) ++ (parsed_fitting[:low_slots] || [])
    tank_bonus = Enum.count(tank_modules, fn mod ->
      String.contains?(mod, ["Shield", "Armor", "Plate", "Extender", "Resistance"])
    end) * 0.15
    
    base_ehp * (1 + tank_bonus)
  end
  
  defp estimate_speed_from_modules(parsed_fitting, ship_type_id) do
    # Base speed varies by ship class
    base_speed = cond do
      ship_type_id in 582..650 -> 350      # Frigates
      ship_type_id in 620..634 -> 200      # Cruisers
      ship_type_id in 638..645 -> 100      # Battleships
      true -> 150
    end
    
    # Check for prop mods
    has_mwd = Enum.any?(parsed_fitting[:mid_slots] || [], &String.contains?(&1, "Microwarpdrive"))
    has_ab = Enum.any?(parsed_fitting[:mid_slots] || [], &String.contains?(&1, "Afterburner"))
    
    cond do
      has_mwd -> base_speed * 5.5
      has_ab -> base_speed * 2.5
      true -> base_speed
    end
  end
  
  defp estimate_sig_from_modules(parsed_fitting, ship_type_id) do
    # Base signature varies by ship class
    base_sig = cond do
      ship_type_id in 582..650 -> 40       # Frigates
      ship_type_id in 620..634 -> 150      # Cruisers
      ship_type_id in 638..645 -> 400      # Battleships
      true -> 100
    end
    
    # MWD increases sig
    if Enum.any?(parsed_fitting[:mid_slots] || [], &String.contains?(&1, "Microwarpdrive")) do
      base_sig * 5
    else
      base_sig
    end
  end
end