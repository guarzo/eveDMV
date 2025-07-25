defmodule EveDmv.StaticData do
  @moduledoc """
  Centralized access to EVE static data with caching.

  This module provides the single source of truth for all static data queries,
  replacing all placeholder implementations with real data from the database.

  ## Features
  - Ship classification based on actual EVE group IDs
  - Mass and volume lookups
  - System security classification
  - High-performance caching with ETS for frequently accessed data
  - Batch query optimization for bulk operations
  """

  import Ash.Query
  alias EveDmv.Api
  alias EveDmv.Eve.ItemType
  alias EveDmv.Eve.ShipGroups
  alias EveDmv.Eve.SolarSystem

  require Logger

  # Cache table names
  @type_cache_table :static_data_type_cache
  @system_cache_table :static_data_system_cache

  # Cache TTL in seconds (30 minutes)
  @cache_ttl 1800

  @doc false
  def start_link do
    # Initialize ETS tables for caching
    :ets.new(@type_cache_table, [:set, :named_table, :public, {:read_concurrency, true}])
    :ets.new(@system_cache_table, [:set, :named_table, :public, {:read_concurrency, true}])
    {:ok, self()}
  end

  @doc """
  Get type information by ID with caching.
  Returns the full ItemType struct or nil if not found.
  """
  def get_type(type_id) when is_integer(type_id) do
    case get_from_cache(@type_cache_table, type_id) do
      {:hit, item} -> item
      :miss -> fetch_and_cache_type(type_id)
    end
  end

  defp fetch_and_cache_type(type_id) do
    item =
      case ItemType
           |> new()
           |> filter(type_id == ^type_id)
           |> limit(1)
           |> Ash.read(domain: Api) do
        {:ok, [item]} -> item
        _ -> nil
      end

    cache_item(@type_cache_table, type_id, item)
    item
  end

  @doc """
  Get type information by name.
  Returns the full ItemType struct or nil if not found.
  """
  def get_type_by_name(type_name) when is_binary(type_name) do
    case ItemType
         |> new()
         |> filter(type_name == ^type_name)
         |> Ash.read_one(domain: Api) do
      {:ok, item} when is_map(item) ->
        # Cache by ID for future lookups
        cache_item(@type_cache_table, item.type_id, item)
        item

      _ ->
        nil
    end
  end

  @doc """
  Get multiple types by IDs with intelligent caching.
  Returns a map of type_id => ItemType.
  """
  def get_types(type_ids) when is_list(type_ids) do
    # Try to get from cache first
    {cached_items, missing_ids} = get_multiple_from_cache(@type_cache_table, type_ids)

    # Fetch missing items from database
    fetched_items =
      if Enum.empty?(missing_ids) do
        %{}
      else
        fetch_multiple_types(missing_ids)
      end

    # Merge cached and fetched results
    Map.merge(cached_items, fetched_items)
  end

  defp fetch_multiple_types(type_ids) do
    items =
      case ItemType
           |> new()
           |> filter(type_id in ^type_ids)
           |> Ash.read(domain: Api) do
        {:ok, items} -> items
        _ -> []
      end

    # Cache the fetched items
    Enum.each(items, fn item ->
      cache_item(@type_cache_table, item.type_id, item)
    end)

    Map.new(items, &{&1.type_id, &1})
  end

  @doc """
  Get ship classification based on group ID.
  Returns atom like :frigate, :cruiser, etc., or :unknown.
  Accepts either a ship type ID (integer) or ship name (string).
  """
  def get_ship_class(ship_name) when is_binary(ship_name) do
    case get_type_by_name(ship_name) do
      %ItemType{type_id: type_id} -> get_ship_class(type_id)
      _ -> :unknown
    end
  end

  def get_ship_class(ship_type_id) when is_integer(ship_type_id) do
    case get_type(ship_type_id) do
      %ItemType{group_id: group_id} when is_integer(group_id) ->
        ShipGroups.get_classification(group_id)

      _ ->
        :unknown
    end
  end

  @doc """
  Get ship group information including group name.
  """
  def get_ship_group(ship_type_id) when is_integer(ship_type_id) do
    case get_type(ship_type_id) do
      %ItemType{} = item ->
        %{
          group_id: item.group_id,
          group_name: item.group_name,
          class: ShipGroups.get_classification(item.group_id)
        }

      _ ->
        nil
    end
  end

  @doc """
  Get type attributes including mass, volume, etc.
  """
  def get_type_attributes(type_id) when is_integer(type_id) do
    case get_type(type_id) do
      %ItemType{} = item ->
        %{
          mass: item.mass || Decimal.new(0),
          volume: item.volume || Decimal.new(0),
          capacity: item.capacity || Decimal.new(0),
          base_price: item.base_price || Decimal.new(0),
          meta_level: item.meta_level || 0,
          tech_level: item.tech_level || 1
        }

      _ ->
        nil
    end
  end

  @doc """
  Get ship mass. Returns {:ok, mass} or {:error, :not_found}.
  Accepts either a ship type ID (integer) or ship name (string).
  """
  def get_ship_mass(ship_name) when is_binary(ship_name) do
    case get_type_by_name(ship_name) do
      %ItemType{type_id: type_id} -> get_ship_mass(type_id)
      _ -> {:error, :ship_not_found}
    end
  end

  def get_ship_mass(ship_type_id) when is_integer(ship_type_id) do
    case get_type(ship_type_id) do
      %ItemType{mass: mass} when is_struct(mass, Decimal) ->
        {:ok, Decimal.to_float(mass)}

      %ItemType{mass: nil} ->
        {:error, :mass_not_available}

      nil ->
        {:error, :ship_not_found}
    end
  end

  @doc """
  Get solar system information by ID.
  """
  def get_system(system_id) when is_integer(system_id) do
    result =
      SolarSystem
      |> Ash.Query.new()
      |> Ash.Query.filter(system_id == ^system_id)
      |> Ash.Query.limit(1)
      |> Ash.read(domain: Api)

    case result do
      {:ok, [system]} -> system
      _ -> nil
    end
  end

  @doc """
  Classify a system based on security status and class.
  Returns :highsec, :lowsec, :nullsec, or wormhole classes.
  """
  def classify_system(system_id) when is_integer(system_id) do
    case get_system(system_id) do
      %SolarSystem{security_status: sec_status, security_class: sec_class} ->
        classify_by_security(sec_status, sec_class, system_id)

      _ ->
        # If system not in database, check if it's a wormhole by ID range
        cond do
          is_wormhole_system?(system_id) ->
            # Unknown class wormhole
            :wormhole_unknown

          system_id >= 30_000_000 and system_id < 31_000_000 ->
            # K-space systems in 30M range
            :known_space

          true ->
            :unknown
        end
    end
  end

  @doc """
  Check if a ship type is an EWAR ship based on group or name.
  """
  def is_ewar_ship?(ship_type_id) when is_integer(ship_type_id) do
    case get_type(ship_type_id) do
      %ItemType{group_id: group_id, type_name: name} ->
        # Check by group
        # Check by name patterns
        group_id in [
          # Electronic Attack Frigates
          893,
          # Force Recon
          833,
          # Combat Recon
          906
        ] or
          String.contains?(name || "", [
            # Caldari ECM
            "Blackbird",
            "Falcon",
            "Rook",
            "Widow",
            # Other ECM/Damp
            "Griffin",
            "Kitsune",
            "Keres",
            "Hyena",
            # Gallente Damp
            "Celestis",
            "Arazu",
            "Lachesis",
            # Other Damp
            "Maulus",
            "Keres",
            # Amarr TD/Neut
            "Crucifier",
            "Sentinel",
            "Curse",
            "Pilgrim",
            # Minmatar TP/Web
            "Vigil",
            "Bellicose",
            "Rapier",
            "Huginn"
          ])

      _ ->
        false
    end
  end

  @doc """
  Get all ships in a specific class.
  """
  def get_ships_by_class(class) when is_atom(class) do
    group_ids = ShipGroups.get_groups_by_classification(class)

    if group_ids == [] do
      []
    else
      result =
        ItemType
        |> Ash.Query.new()
        |> Ash.Query.filter(group_id in ^group_ids)
        |> Ash.Query.filter(published == true)
        |> Ash.read(domain: Api)

      case result do
        {:ok, ships} -> ships
        _ -> []
      end
    end
  end

  @doc """
  Get ship tech level based on meta level and group.
  Returns {:ok, :tech1/:tech2/:tech3/:faction} or {:error, reason}.
  """
  def get_ship_tech_level(ship_type_id) when is_integer(ship_type_id) do
    case get_type(ship_type_id) do
      %ItemType{meta_level: meta_level, tech_level: tech_level, type_name: name} ->
        # Determine tech level from meta level and tech level
        tech =
          cond do
            tech_level == 2 -> :tech2
            tech_level == 3 -> :tech3
            faction_ship?(name, meta_level) -> :faction
            true -> :tech1
          end

        {:ok, tech}

      _ ->
        {:error, :ship_not_found}
    end
  end

  @doc """
  Get ship bonuses (placeholder for now - would need ship bonuses table).
  """
  def get_ship_bonuses(ship_type_id) when is_integer(ship_type_id) do
    # For now, return empty bonuses - would need ship bonuses table
    # This is used for weapon type detection
    {:ok, []}
  end

  @doc """
  Get ship race based on ship name patterns and group classification.
  """
  def get_ship_race(ship_type_id) when is_integer(ship_type_id) do
    case get_type(ship_type_id) do
      %ItemType{type_name: name, group_name: group_name} when is_binary(name) ->
        race = determine_race_from_name(name, group_name)
        {:ok, race}

      _ ->
        {:error, :race_not_found}
    end
  end

  @doc """
  Check if a type is a wormhole by ID range.
  J-space systems are 31000000-32000000.
  """
  def is_wormhole_system?(system_id) when is_integer(system_id) do
    system_id >= 31_000_000 and system_id < 32_000_000
  end

  @doc """
  Get ship role based on ship class and group.
  Returns atom like :dps, :logistics, :tackle, :ewar, :command.
  Accepts either a ship type ID (integer) or ship name (string).
  """
  def get_ship_role(ship_name) when is_binary(ship_name) do
    case get_type_by_name(ship_name) do
      %ItemType{type_id: type_id} -> get_ship_role(type_id)
      _ -> :unknown
    end
  end

  def get_ship_role(ship_type_id) when is_integer(ship_type_id) do
    case get_ship_class(ship_type_id) do
      :logistics -> :logistics
      :command_ship -> :command
      :electronic_attack_frigate -> :ewar
      :force_recon -> :ewar
      :combat_recon -> :ewar
      :interceptor -> :tackle
      :assault_frigate -> :dps
      :heavy_assault_cruiser -> :dps
      :strategic_cruiser -> :dps
      :battlecruiser -> :dps
      :battleship -> :dps
      :dreadnought -> :dps
      :carrier -> :logistics
      :supercarrier -> :dps
      :titan -> :dps
      :frigate -> :tackle
      :destroyer -> :dps
      :cruiser -> :dps
      :industrial -> :support
      :mining_barge -> :support
      :exhumer -> :support
      :transport -> :support
      _ -> :dps
    end
  end

  @doc """
  Get ship category based on group classification.
  Returns atom like :subcapital, :capital, :supercapital.
  """
  def get_ship_category(ship_type_id) when is_integer(ship_type_id) do
    case get_ship_class(ship_type_id) do
      class when class in [:dreadnought, :carrier, :force_auxiliary] -> :capital
      class when class in [:supercarrier, :titan] -> :supercapital
      _ -> :subcapital
    end
  end

  @doc """
  Check if a ship is suitable for wormhole operations.
  Based on mass, size, and capabilities.
  """
  def wormhole_suitable?(ship_type_id) when is_integer(ship_type_id) do
    case get_ship_category(ship_type_id) do
      :supercapital ->
        false

      :capital ->
        # Only some capital ships are suitable for specific wormhole classes
        case get_ship_class(ship_type_id) do
          :dreadnought -> :c5_c6_only
          :carrier -> :c5_c6_only
          :force_auxiliary -> :c5_c6_only
          _ -> true
        end

      :subcapital ->
        true
    end
  end

  @doc """
  Check if a ship is a capital ship.
  """
  def is_capital?(ship_type_id) when is_integer(ship_type_id) do
    get_ship_category(ship_type_id) in [:capital, :supercapital]
  end

  @doc """
  Get wormhole mass restrictions for ship operations.
  Returns mass limits and jump count restrictions.
  """
  def get_wormhole_restrictions(wh_class) do
    case wh_class do
      :c1 ->
        %{
          max_ship_mass: 20_000_000,
          max_total_mass: 1_000_000_000,
          max_jump_mass: 5_000_000,
          capital_allowed: false
        }

      :c2 ->
        %{
          max_ship_mass: 300_000_000,
          max_total_mass: 1_000_000_000,
          max_jump_mass: 62_500_000,
          capital_allowed: false
        }

      :c3 ->
        %{
          max_ship_mass: 300_000_000,
          max_total_mass: 2_000_000_000,
          max_jump_mass: 62_500_000,
          capital_allowed: false
        }

      :c4 ->
        %{
          max_ship_mass: 1_350_000_000,
          max_total_mass: 2_000_000_000,
          max_jump_mass: 187_500_000,
          capital_allowed: false
        }

      :c5 ->
        %{
          max_ship_mass: 1_800_000_000,
          max_total_mass: 3_000_000_000,
          max_jump_mass: 375_000_000,
          capital_allowed: true
        }

      :c6 ->
        %{
          max_ship_mass: 1_800_000_000,
          max_total_mass: 3_000_000_000,
          max_jump_mass: 375_000_000,
          capital_allowed: true
        }

      _ ->
        %{
          max_ship_mass: 0,
          max_total_mass: 0,
          max_jump_mass: 0,
          capital_allowed: false
        }
    end
  end

  @doc """
  Check if a ship is part of a specific doctrine.
  Accepts either a ship type ID (integer) or ship name (string).
  """
  def doctrine_ship?(ship_name, doctrine_name)
      when is_binary(ship_name) and is_binary(doctrine_name) do
    case get_type_by_name(ship_name) do
      %ItemType{type_id: type_id} -> doctrine_ship?(type_id, doctrine_name)
      _ -> false
    end
  end

  def doctrine_ship?(ship_type_id, doctrine_name)
      when is_integer(ship_type_id) and is_binary(doctrine_name) do
    case get_type(ship_type_id) do
      %ItemType{type_name: ship_name} when is_binary(ship_name) ->
        doctrine_lower = String.downcase(doctrine_name)
        ship_lower = String.downcase(ship_name)

        case doctrine_lower do
          # Common wormhole doctrines
          "ahac" ->
            String.contains?(ship_lower, ["zealot", "muninn", "cerberus", "eagle"])

          "logi" ->
            String.contains?(ship_lower, ["guardian", "basilisk", "oneiros", "scimitar"])

          "dps" ->
            get_ship_role(ship_type_id) == :dps

          "support" ->
            get_ship_role(ship_type_id) in [:logistics, :ewar, :command]

          "brawl" ->
            get_ship_class(ship_type_id) in [
              :battleship,
              :heavy_assault_cruiser,
              :strategic_cruiser
            ]

          "kite" ->
            get_ship_class(ship_type_id) in [
              :heavy_assault_cruiser,
              :assault_frigate,
              :interceptor
            ]

          "kitchen_sink" ->
            # Kitchen sink allows most subcapital ships
            get_ship_category(ship_type_id) == :subcapital

          _ ->
            # Check if ship name contains doctrine name
            String.contains?(ship_lower, doctrine_lower)
        end

      _ ->
        false
    end
  end

  # Private functions

  defp classify_by_security(sec_status, sec_class, system_id) do
    if is_wormhole_system?(system_id) do
      # Wormhole systems
      case sec_class do
        "C1" -> :wormhole_c1
        "C2" -> :wormhole_c2
        "C3" -> :wormhole_c3
        "C4" -> :wormhole_c4
        "C5" -> :wormhole_c5
        "C6" -> :wormhole_c6
        # Shattered
        "C13" -> :wormhole_c13
        # Drifter systems
        "C14" -> :wormhole_c14
        _ -> :wormhole_unknown
      end
    else
      # K-space systems
      case Decimal.to_float(sec_status || Decimal.new(0)) do
        sec when sec >= 0.5 -> :highsec
        sec when sec > 0.0 -> :lowsec
        _ -> :nullsec
      end
    end
  end

  # Cache helper functions

  defp get_from_cache(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, timestamp}] ->
        if cache_expired?(timestamp) do
          :ets.delete(table, key)
          :miss
        else
          {:hit, value}
        end

      [] ->
        :miss
    end
  end

  defp get_multiple_from_cache(table, keys) do
    now = System.system_time(:second)

    {cached, missing} =
      Enum.reduce(keys, {%{}, []}, fn key, {cached_acc, missing_acc} ->
        case :ets.lookup(table, key) do
          [{^key, value, timestamp}] ->
            if now - timestamp < @cache_ttl do
              {Map.put(cached_acc, key, value), missing_acc}
            else
              :ets.delete(table, key)
              {cached_acc, [key | missing_acc]}
            end

          [] ->
            {cached_acc, [key | missing_acc]}
        end
      end)

    {cached, missing}
  end

  defp cache_item(table, key, value) do
    timestamp = System.system_time(:second)
    :ets.insert(table, {key, value, timestamp})
  end

  defp cache_expired?(timestamp) do
    System.system_time(:second) - timestamp > @cache_ttl
  end

  # Helper functions for tech level classification

  defp faction_ship?(name, meta_level) when is_binary(name) do
    # Faction ships often have meta level 5-8 and specific name patterns
    (meta_level >= 5 and meta_level <= 8) or
      String.contains?(name, [
        "Navy",
        "Fleet",
        "Republic",
        "Imperial",
        "Federation",
        "State",
        "Guristas",
        "Angel",
        "Serpentis",
        "Blood",
        "Sansha",
        "Shadow",
        "Daredevil",
        "Dramiel",
        "Worm",
        "Succubus",
        "Ashimmu",
        "Bhaalgorn",
        "Vindicator",
        "Machariel",
        "Nightmare",
        "Rattlesnake"
      ])
  end

  defp faction_ship?(_, _), do: false

  # Race determination based on ship names and patterns
  defp determine_race_from_name(ship_name, group_name) do
    name_lower = String.downcase(ship_name)
    group_lower = String.downcase(group_name || "")

    cond do
      # Caldari ships
      String.contains?(name_lower, [
        "blackbird",
        "caracal",
        "cerberus",
        "chimera",
        "condor",
        "cormorant",
        "crow",
        "drake",
        "falcon",
        "ferox",
        "griffin",
        "harpy",
        "hawk",
        "heron",
        "hookbill",
        "hornet",
        "kestrel",
        "kitsune",
        "leviathan",
        "manticore",
        "merlin",
        "nighthawk",
        "osprey",
        "phoenix",
        "raven",
        "rook",
        "scorpion",
        "scythe",
        "tengu",
        "widow"
      ]) or String.contains?(group_lower, "caldari") ->
        "Caldari"

      # Minmatar ships
      String.contains?(name_lower, [
        "bellicose",
        "breacher",
        "burst",
        "cyclone",
        "firetail",
        "huginn",
        "hurricane",
        "hound",
        "jaguar",
        "loki",
        "maelstrom",
        "mammoth",
        "muninn",
        "nidhoggur",
        "probe",
        "prowler",
        "ragnarok",
        "rapier",
        "reaper",
        "rifter",
        "rupture",
        "sabre",
        "scimitar",
        "stabber",
        "stiletto",
        "tempest",
        "thrasher",
        "tornado",
        "typhoon",
        "vagabond",
        "vigil",
        "wolf"
      ]) or String.contains?(group_lower, "minmatar") ->
        "Minmatar"

      # Amarr ships
      String.contains?(name_lower, [
        "abaddon",
        "aeon",
        "amarr",
        "apocalypse",
        "arbitrator",
        "archon",
        "armageddon",
        "avatar",
        "avenger",
        "benediction",
        "confessor",
        "crucifier",
        "crusader",
        "curse",
        "devoter",
        "damnation",
        "dragoon",
        "emperor",
        "executioner",
        "flycatcher",
        "guardian",
        "harbinger",
        "heretic",
        "imperial",
        "impel",
        "inquisitor",
        "legion",
        "magnate",
        "malice",
        "maller",
        "omen",
        "oracle",
        "paladin",
        "pilgrim",
        "pontifex",
        "prophecy",
        "providance",
        "punisher",
        "purifier",
        "retribution",
        "revelation",
        "sacred",
        "sentinel",
        "sigil",
        "tormentor",
        "vengeance",
        "zealot"
      ]) or String.contains?(group_lower, "amarr") ->
        "Amarr"

      # Gallente ships
      String.contains?(name_lower, [
        "algos",
        "ares",
        "astarte",
        "atron",
        "brutix",
        "catalyst",
        "celestis",
        "comet",
        "deimos",
        "dominix",
        "enyo",
        "erebus",
        "eris",
        "exequror",
        "federation",
        "gallente",
        "hyperion",
        "incursus",
        "ishkur",
        "ishtar",
        "lachesis",
        "maulus",
        "megathron",
        "myrmidon",
        "nemesis",
        "nyx",
        "oneiros",
        "proteus",
        "sin",
        "talos",
        "taranis",
        "thanatos",
        "thorax",
        "tristan",
        "vexor",
        "vindicator"
      ]) or String.contains?(group_lower, "gallente") ->
        "Gallente"

      # Default
      true ->
        "Unknown"
    end
  end
end
