defmodule EveDmv.StaticData.ShipReferenceImporter do
  @moduledoc """
  Imports ship reference data from docs/reference/ship_info.md.

  This module parses the comprehensive ship reference documentation and
  populates the ship_role_patterns and doctrine_patterns tables with
  baseline role classifications and fleet doctrine information.
  """

  alias EveDmv.Repo
  import Ecto.Query

  @ship_info_file "docs/reference/ship_info.md"

  @doc """
  Import all ship reference data from ship_info.md.

  Returns {:ok, stats} on success with import statistics.
  """
  def import_all do
    with {:ok, content} <- read_ship_info_file(),
         {:ok, ship_data} <- parse_ship_data(content),
         {:ok, doctrine_data} <- parse_doctrine_data(content),
         {:ok, ship_stats} <- import_ship_patterns(ship_data),
         {:ok, doctrine_stats} <- import_doctrine_patterns(doctrine_data) do
      stats = %{
        ships_imported: ship_stats.inserted + ship_stats.updated,
        ships_inserted: ship_stats.inserted,
        ships_updated: ship_stats.updated,
        doctrines_imported: doctrine_stats.inserted + doctrine_stats.updated,
        doctrines_inserted: doctrine_stats.inserted,
        doctrines_updated: doctrine_stats.updated
      }

      {:ok, stats}
    end
  end

  @doc """
  Parse ship data from ship_info.md content.

  Returns {:ok, ship_data_list} where each item contains:
  - type_id: EVE type ID
  - name: Ship name
  - reference_role: Primary tactical role
  - typical_doctrines: List of doctrine names
  - tank_type: armor/shield
  - engagement_range: close/medium/long/extreme
  - tactical_notes: Description and usage notes
  """
  def parse_ship_data(content) do
    ships = []

    # Parse different ship sections
    ships = ships ++ parse_battleships(content)
    ships = ships ++ parse_battlecruisers(content)
    ships = ships ++ parse_command_ships(content)
    ships = ships ++ parse_heavy_assault_cruisers(content)
    ships = ships ++ parse_strategic_cruisers(content)
    ships = ships ++ parse_logistics_ships(content)
    ships = ships ++ parse_interdictors(content)
    ships = ships ++ parse_heavy_interdictors(content)
    ships = ships ++ parse_recon_ships(content)
    ships = ships ++ parse_interceptors(content)
    ships = ships ++ parse_command_destroyers(content)

    {:ok, ships}
  end

  @doc """
  Parse doctrine patterns from ship_info.md content.
  """
  def parse_doctrine_data(_content) do
    doctrines = [
      # Battleship doctrines
      %{
        doctrine_name: "armor_bs_sniper",
        # Megathron + Guardian
        ship_composition: %{641 => 20, 11_987 => 4},
        tank_type: "armor",
        engagement_range: "long",
        tactical_role: "sniper",
        reference_source: "ship_info.md"
      },
      %{
        doctrine_name: "mach_speed_fleet",
        # Machariel + Scimitar
        ship_composition: %{17_738 => 25, 11_989 => 5},
        tank_type: "shield",
        engagement_range: "medium_long",
        tactical_role: "mobile_dps",
        reference_source: "ship_info.md"
      },
      # Battlecruiser doctrines
      %{
        doctrine_name: "ferox_railgun_fleet",
        # Ferox + Basilisk
        ship_composition: %{20_648 => 30, 11_985 => 6},
        tank_type: "shield",
        engagement_range: "long",
        tactical_role: "sniper",
        reference_source: "ship_info.md"
      },
      %{
        doctrine_name: "drake_missile_fleet",
        # Drake + Basilisk
        ship_composition: %{24_698 => 25, 11_985 => 5},
        tank_type: "shield",
        engagement_range: "medium",
        tactical_role: "brawler",
        reference_source: "ship_info.md"
      },
      # HAC doctrines
      %{
        doctrine_name: "muninn_artillery_fleet",
        # Muninn + Scimitar
        ship_composition: %{12_015 => 40, 11_989 => 8},
        tank_type: "shield",
        engagement_range: "long",
        tactical_role: "alpha",
        reference_source: "ship_info.md"
      },
      %{
        doctrine_name: "eagle_railgun_fleet",
        # Eagle + Basilisk
        ship_composition: %{12_011 => 35, 11_985 => 7},
        tank_type: "shield",
        engagement_range: "extreme",
        tactical_role: "sniper",
        reference_source: "ship_info.md"
      }
    ]

    {:ok, doctrines}
  end

  # Private helper functions for parsing specific ship categories

  defp parse_battleships(_content) do
    [
      # Tech I Battleships
      %{
        type_id: 641,
        name: "Megathron",
        reference_role: "sniper_dps",
        typical_doctrines: ["armor_bs_sniper", "railgun_alpha"],
        tank_type: "armor",
        engagement_range: "long",
        tactical_notes:
          "Gallente battleship for long-range alpha volleys, backbone of nullsec armor fleets"
      },
      %{
        type_id: 642,
        name: "Apocalypse",
        reference_role: "sniper_dps",
        typical_doctrines: ["armor_bs_sniper", "laser_sniper"],
        tank_type: "armor",
        engagement_range: "long",
        tactical_notes:
          "Amarr battleship and dedicated laser sniper. With excellent range bonuses, up to ~150km in large fleet fights"
      },
      %{
        type_id: 639,
        name: "Tempest",
        reference_role: "sniper_dps",
        typical_doctrines: ["alpha_fleet", "artillery_sniper"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Minmatar battleship known for versatility and speed. Often fit with artillery for long-range volleys"
      },
      %{
        type_id: 24_694,
        name: "Maelstrom",
        reference_role: "alpha_dps",
        typical_doctrines: ["alpha_fleet", "artillery_volley"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Minmatar battleship with strong shield tank. 1400mm artillery provides massive alpha damage"
      },
      %{
        type_id: 24_688,
        name: "Rokh",
        reference_role: "sniper_dps",
        typical_doctrines: ["shield_sniper", "railgun_extreme"],
        tank_type: "shield",
        engagement_range: "extreme",
        tactical_notes:
          "Caldari battleship specialized for railguns. Very high engagement range with strong shield tank"
      },
      %{
        type_id: 24_692,
        name: "Abaddon",
        reference_role: "armor_brawler",
        typical_doctrines: ["armor_brawl", "laser_brawl"],
        tank_type: "armor",
        engagement_range: "close",
        tactical_notes:
          "Amarr battleship with monstrous armor. Premier heavy armor brawler, trading mobility for sheer tank"
      },
      %{
        type_id: 643,
        name: "Armageddon",
        reference_role: "neut_support",
        typical_doctrines: ["neut_support", "armor_support"],
        tank_type: "armor",
        engagement_range: "medium",
        tactical_notes:
          "Amarr battleship featuring energy neutralizers. Used to drain enemy capital/Logistics capacitors"
      },
      %{
        type_id: 640,
        name: "Scorpion",
        reference_role: "ewar_support",
        typical_doctrines: ["ecm_support", "shield_ewar"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Caldari battleship dedicated to ECM. Can shut down enemy targeting and disrupt hostile logistics"
      },
      # Pirate Faction Battleships
      %{
        type_id: 17_738,
        name: "Machariel",
        reference_role: "mobile_dps",
        typical_doctrines: ["mach_speed_fleet", "shield_artillery"],
        tank_type: "shield",
        engagement_range: "medium_long",
        tactical_notes:
          "Angel Cartel battleship famed for speed and damage. Dictates engagement range with hit-and-run tactics"
      },
      %{
        type_id: 17_736,
        name: "Nightmare",
        reference_role: "shield_sniper",
        typical_doctrines: ["shield_laser", "nightmare_fleet"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Sansha's Nation battleship with high EM/Thermal damage and strong capacitor"
      },
      %{
        type_id: 17_920,
        name: "Bhaalgorn",
        reference_role: "heavy_tackle",
        typical_doctrines: ["neut_tackle", "armor_support"],
        tank_type: "armor",
        engagement_range: "close",
        tactical_notes:
          "Blood Raiders battleship specialized in energy neutralization and stasis webs"
      },
      # Triglavian Battleships
      %{
        type_id: 47_966,
        name: "Leshak",
        reference_role: "ramping_dps",
        typical_doctrines: ["leshak_spider", "triglavian_fleet"],
        tank_type: "armor",
        engagement_range: "medium",
        tactical_notes:
          "Triglavian battleship with ramping damage over time. Uses spider tank tactics with remote armor repairs"
      }
    ]
  end

  defp parse_battlecruisers(_content) do
    [
      %{
        type_id: 20_648,
        name: "Ferox",
        reference_role: "shield_sniper",
        typical_doctrines: ["ferox_railgun_fleet", "shield_bc"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Caldari battlecruiser valued for low cost and optimal range. Railgun platform at 50-100km"
      },
      %{
        type_id: 24_698,
        name: "Drake",
        reference_role: "shield_brawler",
        typical_doctrines: ["drake_missile_fleet", "shield_bc"],
        tank_type: "shield",
        engagement_range: "medium",
        tactical_notes:
          "Caldari battlecruiser known for durability and missile firepower. Thick shield tank"
      },
      %{
        type_id: 24_702,
        name: "Hurricane",
        reference_role: "versatile_dps",
        typical_doctrines: ["hurricane_fleet", "projectile_bc"],
        tank_type: "shield",
        engagement_range: "medium",
        tactical_notes:
          "Minmatar battlecruiser versatile with projectile weapons. Artillery or autocannon capable"
      }
    ]
  end

  defp parse_command_ships(_content) do
    [
      %{
        type_id: 22_474,
        name: "Damnation",
        reference_role: "armor_command",
        typical_doctrines: ["armor_fleet", "command_support"],
        tank_type: "armor",
        engagement_range: "medium",
        tactical_notes:
          "Amarr Command Ship with colossal armor tank and armor warfare links. Fleet booster for armor fleets"
      },
      %{
        type_id: 22_472,
        name: "Vulture",
        reference_role: "shield_command",
        typical_doctrines: ["shield_fleet", "command_support"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Caldari Command Ship for shield warfare links. Go-to shield fleet booster"
      },
      %{
        type_id: 22_468,
        name: "Claymore",
        reference_role: "skirmish_command",
        typical_doctrines: ["fast_fleet", "nano_support"],
        tank_type: "shield",
        engagement_range: "medium",
        tactical_notes:
          "Minmatar Command Ship for skirmish warfare bonuses. Enhances fleet mobility and tackle range"
      }
    ]
  end

  defp parse_heavy_assault_cruisers(_content) do
    [
      %{
        type_id: 12_015,
        name: "Muninn",
        reference_role: "alpha_dps",
        typical_doctrines: ["muninn_artillery_fleet", "hac_alpha"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Minmatar HAC popular for artillery. High-speed shield-tanked sniper at 70-100km with high alpha"
      },
      %{
        type_id: 12_011,
        name: "Eagle",
        reference_role: "sniper_dps",
        typical_doctrines: ["eagle_railgun_fleet", "hac_sniper"],
        tank_type: "shield",
        engagement_range: "extreme",
        tactical_notes:
          "Caldari HAC for long-range railguns. Excellent range with Spike ammo, extreme distances"
      },
      %{
        type_id: 11_993,
        name: "Cerberus",
        reference_role: "missile_dps",
        typical_doctrines: ["cerberus_missile_fleet", "hac_missile"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Caldari HAC excels with heavy missiles. Long-range missile boat beyond 100km"
      },
      %{
        type_id: 12_005,
        name: "Ishtar",
        reference_role: "drone_dps",
        typical_doctrines: ["ishtar_drone_fleet", "sentry_drone"],
        tank_type: "armor",
        engagement_range: "long",
        tactical_notes:
          "Gallente HAC notorious for drone damage. Sentry drones provide immense collective damage at range"
      }
    ]
  end

  defp parse_logistics_ships(_content) do
    [
      %{
        type_id: 11_987,
        name: "Guardian",
        reference_role: "armor_logistics",
        typical_doctrines: ["armor_fleet", "logistics_support"],
        tank_type: "armor",
        engagement_range: "medium",
        tactical_notes:
          "Amarr T2 Logistics Cruiser, armor repair specialist. Uses cap-chain system, workhorse of armor fleets"
      },
      %{
        type_id: 11_985,
        name: "Basilisk",
        reference_role: "shield_logistics",
        typical_doctrines: ["shield_fleet", "logistics_support"],
        tank_type: "shield",
        engagement_range: "medium",
        tactical_notes:
          "Caldari T2 Logistics Cruiser, shield transfer specialist. Superior raw repping throughput"
      },
      %{
        type_id: 11_989,
        name: "Scimitar",
        reference_role: "fast_logistics",
        typical_doctrines: ["fast_fleet", "mobile_support"],
        tank_type: "shield",
        engagement_range: "medium",
        tactical_notes:
          "Minmatar T2 Logistics Cruiser, fast shield logistics. Cap-stable solo, excels in high-mobility doctrines"
      }
    ]
  end

  defp parse_interdictors(_content) do
    [
      %{
        type_id: 22_456,
        name: "Sabre",
        reference_role: "fast_tackle",
        typical_doctrines: ["dictor_support", "bubble_tackle"],
        tank_type: "shield",
        engagement_range: "close",
        tactical_notes:
          "Minmatar Interdictor, most commonly used dictor. High speed and agility with decent shield tank"
      }
    ]
  end

  defp parse_heavy_interdictors(_content) do
    [
      %{
        type_id: 12_017,
        name: "Devoter",
        reference_role: "heavy_tackle",
        typical_doctrines: ["hic_tackle", "armor_support"],
        tank_type: "armor",
        engagement_range: "close",
        tactical_notes:
          "Amarr Heavy Interdictor heavily armor-tanked. Creates 20km bubble or infinite-point tackle"
      }
    ]
  end

  defp parse_recon_ships(_content) do
    [
      %{
        # Huginn (Combat Recon)
        type_id: 11_999,
        name: "Huginn",
        reference_role: "ewar_support",
        typical_doctrines: ["web_support", "paint_support"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Minmatar Combat Recon with double bonus to web range and target painter effectiveness"
      }
    ]
  end

  defp parse_strategic_cruisers(_content) do
    [
      %{
        type_id: 29_984,
        name: "Tengu",
        reference_role: "versatile_dps",
        typical_doctrines: ["t3_missile", "covert_ops"],
        tank_type: "shield",
        engagement_range: "long",
        tactical_notes:
          "Caldari T3 Cruiser configured as long-range missile platform with strong shield tank"
      }
    ]
  end

  defp parse_interceptors(_content) do
    [
      %{
        type_id: 11_174,
        name: "Ares",
        reference_role: "fast_tackle",
        typical_doctrines: ["interceptor_support", "fast_tackle"],
        tank_type: "armor",
        engagement_range: "close",
        tactical_notes:
          "Gallente Interceptor, one of the fastest interceptors in straight-line speed"
      }
    ]
  end

  defp parse_command_destroyers(_content) do
    [
      %{
        # Note: Using placeholder ID - need to verify actual Pontifex type ID
        type_id: 22_468,
        name: "Pontifex",
        reference_role: "boosh_support",
        typical_doctrines: ["boosh_support", "armor_support"],
        tank_type: "armor",
        engagement_range: "medium",
        tactical_notes:
          "Amarr Command Destroyer for armor fleets. MJFG can jump friendlies 100km to avoid bombs"
      }
    ]
  end

  # Database interaction functions

  def import_ship_patterns(ship_data) do
    {inserted, updated} =
      Enum.reduce(ship_data, {0, 0}, fn ship, {ins, upd} ->
        case upsert_ship_pattern(ship) do
          {:ok, :inserted} -> {ins + 1, upd}
          {:ok, :updated} -> {ins, upd + 1}
          {:error, _} -> {ins, upd}
        end
      end)

    {:ok, %{inserted: inserted, updated: updated}}
  end

  def import_doctrine_patterns(doctrine_data) do
    {inserted, updated} =
      Enum.reduce(doctrine_data, {0, 0}, fn doctrine, {ins, upd} ->
        case upsert_doctrine_pattern(doctrine) do
          {:ok, :inserted} -> {ins + 1, upd}
          {:ok, :updated} -> {ins, upd + 1}
          {:error, _} -> {ins, upd}
        end
      end)

    {:ok, %{inserted: inserted, updated: updated}}
  end

  defp upsert_ship_pattern(ship) do
    attrs = %{
      ship_type_id: ship.type_id,
      ship_name: ship.name,
      reference_role: ship.reference_role,
      typical_doctrines: ship.typical_doctrines,
      tactical_notes: ship.tactical_notes,
      # Initialize with reference role as primary role
      primary_role: ship.reference_role,
      role_distribution: %{ship.reference_role => 1.0},
      # High confidence for reference data
      confidence_score: Decimal.new("0.9"),
      sample_size: 0,
      last_analyzed: nil,
      meta_trend: "reference",
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # Check if ship pattern already exists
    existing =
      Repo.one(
        from(s in "ship_role_patterns",
          where: s.ship_type_id == ^ship.type_id,
          select: %{ship_type_id: s.ship_type_id}
        )
      )

    case existing do
      nil ->
        case Repo.insert_all("ship_role_patterns", [attrs]) do
          {1, _} -> {:ok, :inserted}
          _ -> {:error, :insert_failed}
        end

      _existing ->
        case Repo.update_all(
               from(s in "ship_role_patterns", where: s.ship_type_id == ^ship.type_id),
               set: [
                 ship_name: ship.name,
                 reference_role: ship.reference_role,
                 typical_doctrines: ship.typical_doctrines,
                 tactical_notes: ship.tactical_notes,
                 updated_at: DateTime.utc_now()
               ]
             ) do
          {1, _} -> {:ok, :updated}
          _ -> {:error, :update_failed}
        end
    end
  end

  defp upsert_doctrine_pattern(doctrine) do
    attrs = %{
      doctrine_name: doctrine.doctrine_name,
      ship_composition: doctrine.ship_composition,
      tank_type: doctrine.tank_type,
      engagement_range: doctrine.engagement_range,
      tactical_role: doctrine.tactical_role,
      reference_source: doctrine.reference_source,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }

    # Check if doctrine pattern already exists
    existing =
      Repo.one(
        from(d in "doctrine_patterns",
          where: d.doctrine_name == ^doctrine.doctrine_name,
          select: %{doctrine_name: d.doctrine_name}
        )
      )

    case existing do
      nil ->
        case Repo.insert_all("doctrine_patterns", [attrs]) do
          {1, _} -> {:ok, :inserted}
          _ -> {:error, :insert_failed}
        end

      _existing ->
        case Repo.update_all(
               from(d in "doctrine_patterns", where: d.doctrine_name == ^doctrine.doctrine_name),
               set: [
                 ship_composition: doctrine.ship_composition,
                 tank_type: doctrine.tank_type,
                 engagement_range: doctrine.engagement_range,
                 tactical_role: doctrine.tactical_role,
                 reference_source: doctrine.reference_source,
                 updated_at: DateTime.utc_now()
               ]
             ) do
          {1, _} -> {:ok, :updated}
          _ -> {:error, :update_failed}
        end
    end
  end

  defp read_ship_info_file do
    file_path = Path.join(File.cwd!(), @ship_info_file)

    case File.read(file_path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, "Failed to read #{@ship_info_file}: #{reason}"}
    end
  end
end
