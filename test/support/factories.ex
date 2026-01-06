defmodule EveDmv.Factories do
  @moduledoc """
  Test data factories for EVE DMV testing
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Users.User

  # Real EVE ship type IDs from static data
  # Rifter, Punisher, Merlin, Incursus, etc.
  @frigates [587, 588, 589, 590, 591, 592, 593, 594]
  # Algos, Catalyst, Cormorant, Coercer
  @destroyers [16_219, 16_227, 16_236, 16_242]
  # Arbitrator, Augoror, Bellicose, etc.
  @cruisers [620, 621, 622, 623, 624, 625, 626, 627]
  # Abaddon, Apocalypse, Armageddon, Megathron, etc.
  @battleships [638, 639, 640, 641, 642, 643, 644, 645]
  # Ares, Crow, Malediction, Stiletto
  @interceptors [11_985, 11_987, 11_989, 11_993]
  # Enyo, Hawk, Jaguar, Retribution
  @assault_frigates [22_442, 22_444, 22_446, 22_448]
  # Legion, Loki, Proteus, Tengu
  @strategic_cruisers [29_984, 29_986, 29_988, 29_990]
  # Basilisk, Guardian, Augoror, Osprey
  @logistics [11_978, 11_987, 16, 624]
  # Sabre, Eris, Flycatcher, Heretic
  @interdictors [22_456, 22_460, 22_464, 22_468]

  # Ship name mappings for real EVE ships
  @ship_names %{
    587 => "Rifter",
    588 => "Punisher",
    589 => "Merlin",
    590 => "Incursus",
    591 => "Kestrel",
    592 => "Imicus",
    593 => "Heron",
    594 => "Magnate",
    620 => "Arbitrator",
    621 => "Augoror",
    622 => "Bellicose",
    623 => "Celestis",
    624 => "Osprey",
    625 => "Exequror",
    626 => "Rupture",
    627 => "Thorax",
    638 => "Abaddon",
    639 => "Apocalypse",
    640 => "Armageddon",
    641 => "Megathron",
    642 => "Rokh",
    643 => "Scorpion",
    644 => "Raven",
    645 => "Hyperion",
    11_985 => "Ares",
    11_987 => "Crow",
    11_989 => "Malediction",
    11_993 => "Stiletto",
    11_978 => "Basilisk",
    16 => "Augoror",
    22_456 => "Sabre",
    22_460 => "Eris"
  }

  # Get a random ship by role
  @spec random_ship_by_role(atom()) :: integer()
  def random_ship_by_role(role) do
    ship_ids =
      case role do
        :frigate -> @frigates
        :destroyer -> @destroyers
        :cruiser -> @cruisers
        :battleship -> @battleships
        :interceptor -> @interceptors
        :assault_frigate -> @assault_frigates
        :strategic_cruiser -> @strategic_cruisers
        :logistics -> @logistics
        :interdictor -> @interdictors
        # default mix
        _ -> @frigates ++ @cruisers
      end

    Enum.random(ship_ids)
  end

  @spec ship_name_for_id(integer()) :: String.t()
  def ship_name_for_id(ship_type_id), do: Map.get(@ship_names, ship_type_id, "Unknown Ship")

  @spec character_factory() :: map()
  def character_factory do
    %{
      eve_character_id: Enum.random(90_000_000..100_000_000),
      eve_character_name: "Test Character #{System.unique_integer([:positive])}",
      eve_corporation_id: Enum.random(1_000_000..2_000_000),
      eve_alliance_id: Enum.random(99_000_000..100_000_000)
    }
  end

  @spec killmail_raw_factory() :: map()
  def killmail_raw_factory do
    killmail_time = DateTime.add(DateTime.utc_now(), -Enum.random(1..3600), :second)
    killmail_data = build_realistic_killmail_data()

    %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: killmail_time,
      killmail_hash: "test_hash_#{System.unique_integer([:positive])}",
      solar_system_id: Enum.random([30_000_142, 30_002_187, 30_003_715]),
      victim_character_id: get_in(killmail_data, ["victim", "character_id"]),
      victim_corporation_id: get_in(killmail_data, ["victim", "corporation_id"]),
      victim_alliance_id: get_in(killmail_data, ["victim", "alliance_id"]),
      victim_ship_type_id: get_in(killmail_data, ["victim", "ship_type_id"]),
      attacker_count: length(Map.get(killmail_data, "attackers", [])),
      total_value: Decimal.new(Enum.random(5_000_000..500_000_000)),
      raw_data: killmail_data,
      source: "wanderer-kills"
    }
  end

  @spec user_factory() :: map()
  def user_factory do
    character_id = Enum.random(90_000_000..100_000_000)

    %{
      eve_character_id: character_id,
      eve_character_name: "Test Character #{System.unique_integer([:positive])}",
      eve_corporation_id: Enum.random(1_000_000..2_000_000),
      eve_alliance_id: Enum.random(99_000_000..100_000_000),
      access_token: "test_access_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh_token_#{System.unique_integer([:positive])}",
      token_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }
  end

  @spec killmail_enriched_factory() :: map()
  def killmail_enriched_factory do
    # Since KillmailEnriched was removed, we create a KillmailRaw with enriched-like data
    killmail_time = DateTime.add(DateTime.utc_now(), -Enum.random(1..3600), :second)
    victim_character_id = Enum.random(90_000_000..100_000_000)
    victim_corporation_id = Enum.random(1_000_000..2_000_000)
    victim_alliance_id = Enum.random(99_000_000..100_000_000)
    victim_ship_type_id = Enum.random(@frigates ++ @cruisers)
    attacker_count = Enum.random(1..10)

    # Build realistic killmail data with the victim information
    raw_data = %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.to_iso8601(killmail_time),
      "solar_system_id" => Enum.random([30_000_142, 30_002_187, 30_003_715]),
      "victim" => %{
        "character_id" => victim_character_id,
        "corporation_id" => victim_corporation_id,
        "alliance_id" => victim_alliance_id,
        "ship_type_id" => victim_ship_type_id,
        "damage_taken" => Enum.random(1000..50_000)
      },
      "attackers" =>
        Enum.map(1..attacker_count, fn _i ->
          %{
            "character_id" => Enum.random(90_000_000..100_000_000),
            "corporation_id" => Enum.random(1_000_000..2_000_000),
            "alliance_id" => Enum.random(99_000_000..100_000_000),
            "ship_type_id" => Enum.random([587, 588, 589]),
            "weapon_type_id" => Enum.random([2185, 2873, 3074]),
            "damage_done" => Enum.random(100..10_000),
            "final_blow" => false,
            "security_status" => 0.5
          }
        end),
      "zkb" => %{
        "locationID" => Enum.random([30_000_142, 30_002_187, 30_003_715]),
        "hash" => "test_hash_#{System.unique_integer([:positive])}",
        "fittedValue" => Enum.random(1_000_000..100_000_000),
        "totalValue" => Enum.random(5_000_000..500_000_000)
      }
    }

    # Set one attacker as final blow
    updated_raw_data =
      if attacker_count > 0 do
        attackers = Map.get(raw_data, "attackers", [])

        updated_attackers =
          case attackers do
            [first | rest] -> [Map.put(first, "final_blow", true) | rest]
            [] -> []
          end

        Map.put(raw_data, "attackers", updated_attackers)
      else
        raw_data
      end

    %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: killmail_time,
      killmail_hash: "test_hash_#{System.unique_integer([:positive])}",
      solar_system_id: Enum.random([30_000_142, 30_002_187, 30_003_715]),
      victim_character_id: victim_character_id,
      victim_corporation_id: victim_corporation_id,
      victim_alliance_id: victim_alliance_id,
      victim_ship_type_id: victim_ship_type_id,
      attacker_count: attacker_count,
      total_value: Decimal.new(Enum.random(5_000_000..500_000_000)),
      raw_data: updated_raw_data,
      source: "test"
    }
  end

  @spec build(atom(), map()) :: map()
  def build(factory_name, attrs \\ %{}) do
    factory_name
    |> build_factory()
    |> Map.merge(attrs)
  end

  @spec create(atom(), map() | keyword()) :: map()
  def create(factory_name, attrs \\ %{}) do
    # Convert keyword list to map if needed
    attrs_map = if is_list(attrs), do: Enum.into(attrs, %{}), else: attrs

    factory_name
    |> build(attrs_map)
    |> insert_into_database()
  end

  defp build_factory(:character), do: character_factory()
  defp build_factory(:killmail_raw), do: killmail_raw_factory()
  defp build_factory(:killmail_enriched), do: killmail_enriched_factory()
  defp build_factory(:participant), do: participant_factory()
  defp build_factory(:user), do: user_factory()
  defp build_factory(:token), do: token_factory()

  def participant_factory do
    killmail_time = DateTime.add(DateTime.utc_now(), -Enum.random(1..3600), :second)

    %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: killmail_time,
      character_id: Enum.random(90_000_000..100_000_000),
      character_name: "Test Character #{System.unique_integer([:positive])}",
      corporation_id: Enum.random(1_000_000..2_000_000),
      corporation_name: "Test Corp #{System.unique_integer([:positive])}",
      alliance_id: Enum.random(99_000_000..100_000_000),
      alliance_name: "Test Alliance #{System.unique_integer([:positive])}",
      ship_type_id: random_ship_by_role(:cruiser),
      ship_name: "Real EVE Ship",
      weapon_type_id: Enum.random([2185, 2873, 3074]),
      weapon_name: "Test Weapon",
      damage_done: Enum.random(100..10_000),
      security_status: Decimal.new("0.5"),
      is_victim: false,
      final_blow: false,
      is_npc: false,
      solar_system_id: Enum.random([30_000_142, 30_002_187, 30_003_715])
    }
  end

  defp build_realistic_killmail_data do
    # Create realistic killmail JSON structure
    victim_character_id = Enum.random(90_000_000..100_000_000)

    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.to_iso8601(DateTime.utc_now()),
      "solar_system_id" => Enum.random([30_000_142, 30_002_187, 30_003_715]),
      "victim" => %{
        "character_id" => victim_character_id,
        "corporation_id" => Enum.random(1_000_000..2_000_000),
        "alliance_id" => Enum.random(99_000_000..100_000_000),
        # Real EVE ships from frigates and cruisers
        "ship_type_id" => Enum.random(@frigates ++ @cruisers),
        "damage_taken" => Enum.random(1000..50_000),
        "items" => build_random_items()
      },
      "attackers" => build_random_attackers(),
      "moon_id" => nil,
      "war_id" => nil,
      "zkb" => %{
        "locationID" => Enum.random(1_000_000_000..1_100_000_000),
        "hash" => generate_hash(),
        "fittedValue" => Enum.random(1_000_000..100_000_000),
        "totalValue" => Enum.random(1_000_000..100_000_000),
        "points" => Enum.random(1..100),
        "npc" => false,
        "solo" => Enum.random([true, false]),
        "awox" => false
      }
    }
  end

  defp insert_into_database(%{eve_character_id: _} = character_attrs)
       when not is_map_key(character_attrs, :access_token) do
    # This is a character, not a user - just return the attrs for now since we don't have a Character resource
    character_attrs
  end

  defp insert_into_database(%{eve_character_id: _, access_token: _} = user_attrs) do
    # Insert user data using Ash with proper action and arguments
    user_info = %{
      "CharacterID" => user_attrs.eve_character_id,
      "CharacterName" => user_attrs.eve_character_name
    }

    oauth_tokens = %{
      "access_token" => user_attrs.access_token,
      "refresh_token" => user_attrs.refresh_token,
      "expires_in" => 3600
    }

    Ash.create!(
      User,
      %{
        user_info: user_info,
        oauth_tokens: oauth_tokens
      },
      action: :register_with_eve_sso,
      domain: Api
    )
  end

  # No longer needed since KillmailEnriched was removed
  # defp insert_into_database(%{_enriched_marker: true} = enriched_attrs) do

  # NOTE: Participant clause must come BEFORE killmail clause because it's more specific
  # (participants have both killmail_id and is_victim, while killmails only have killmail_id)
  defp insert_into_database(%{killmail_id: _, is_victim: _} = participant_attrs) do
    # Insert participant data using Ash
    alias EveDmv.Killmails.Participant

    # Ensure we have all required fields
    attrs = %{
      killmail_id: participant_attrs.killmail_id,
      killmail_time: participant_attrs.killmail_time,
      character_id: participant_attrs.character_id,
      character_name: Map.get(participant_attrs, :character_name),
      corporation_id: participant_attrs.corporation_id,
      corporation_name: Map.get(participant_attrs, :corporation_name),
      alliance_id: Map.get(participant_attrs, :alliance_id),
      alliance_name: Map.get(participant_attrs, :alliance_name),
      ship_type_id: participant_attrs.ship_type_id,
      ship_name: Map.get(participant_attrs, :ship_name),
      weapon_type_id: Map.get(participant_attrs, :weapon_type_id),
      weapon_name: Map.get(participant_attrs, :weapon_name),
      damage_done: Map.get(participant_attrs, :damage_done, 0),
      security_status: Map.get(participant_attrs, :security_status),
      is_victim: participant_attrs.is_victim,
      final_blow: Map.get(participant_attrs, :final_blow, false),
      is_npc: Map.get(participant_attrs, :is_npc, false),
      solar_system_id: participant_attrs.solar_system_id
    }

    Ash.create!(Participant, attrs, domain: Api)
  end

  defp insert_into_database(%{killmail_id: _} = killmail_attrs) do
    # Extract required fields for KillmailRaw resource
    # Support both old 'killmail_data' and new 'raw_data' attribute names
    killmail_data =
      Map.get(killmail_attrs, :raw_data) || Map.get(killmail_attrs, :killmail_data, %{})

    attrs = %{
      killmail_id: killmail_attrs.killmail_id,
      killmail_time: killmail_attrs.killmail_time,
      killmail_hash:
        Map.get(killmail_attrs, :killmail_hash) || get_in(killmail_data, ["zkb", "hash"]) ||
          generate_hash(),
      solar_system_id: killmail_attrs.solar_system_id,
      victim_character_id:
        Map.get(killmail_attrs, :victim_character_id) ||
          get_in(killmail_data, ["victim", "character_id"]),
      victim_corporation_id:
        Map.get(killmail_attrs, :victim_corporation_id) ||
          get_in(killmail_data, ["victim", "corporation_id"]),
      victim_alliance_id:
        Map.get(killmail_attrs, :victim_alliance_id) ||
          get_in(killmail_data, ["victim", "alliance_id"]),
      victim_ship_type_id:
        Map.get(killmail_attrs, :victim_ship_type_id) ||
          get_in(killmail_data, ["victim", "ship_type_id"]),
      attacker_count:
        Map.get(killmail_attrs, :attacker_count) ||
          length(Map.get(killmail_data, "attackers", [])),
      total_value:
        Map.get(killmail_attrs, :total_value) ||
          Decimal.new(get_in(killmail_data, ["zkb", "totalValue"]) || 0),
      raw_data: killmail_data,
      source: Map.get(killmail_attrs, :source, "test")
    }

    Ash.create!(KillmailRaw, attrs, domain: Api)
  end

  defp insert_into_database(attrs) do
    # Generic fallback - just return the attrs
    attrs
  end

  defp generate_hash do
    Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
  end

  defp build_random_items do
    item_count = Enum.random(0..10)

    if item_count == 0 do
      []
    else
      for _i <- 1..item_count do
        %{
          # Various modules
          "item_type_id" => Enum.random([2185, 1541, 438, 215]),
          "singleton" => 0,
          "flag" => Enum.random(11..34),
          "quantity_destroyed" => Enum.random(0..5),
          "quantity_dropped" => Enum.random(0..5)
        }
      end
    end
  end

  defp build_random_attackers do
    attacker_count = Enum.random(1..5)

    attackers =
      for _i <- 1..attacker_count do
        %{
          "character_id" => Enum.random(90_000_000..100_000_000),
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "alliance_id" => Enum.random(99_000_000..100_000_000),
          # Rifter, Rupture, Stabber, Loki
          "ship_type_id" => Enum.random([587, 588, 589, 17_738]),
          # Various weapons
          "weapon_type_id" => Enum.random([2185, 2873, 3074]),
          "damage_done" => Enum.random(100..10_000),
          "final_blow" => false,
          # -5.0 to 5.0
          "security_status" => :rand.uniform() * 10 - 5
        }
      end

    # Ensure one attacker has final_blow
    if attacker_count > 0 do
      [first | rest] = attackers
      [Map.put(first, "final_blow", true) | rest]
    else
      attackers
    end
  end

  # Specialized factory functions for specific test scenarios

  def build_high_threat_killmail(character_id) do
    build(:killmail_raw, %{
      killmail_data: %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.to_iso8601(DateTime.utc_now()),
        "solar_system_id" => Enum.random([30_000_142, 30_002_187, 30_003_715]),
        "attackers" => [
          %{
            "character_id" => character_id,
            "final_blow" => true,
            # Loki (T3 cruiser)
            "ship_type_id" => 17_738,
            "damage_done" => Enum.random(3000..8000)
          }
        ],
        "victim" => %{
          "character_id" => Enum.random(90_000_000..95_000_000),
          # Cheap ships
          "ship_type_id" => Enum.random([587, 588, 589]),
          "damage_taken" => Enum.random(1000..3000)
        },
        "zkb" => %{
          "hash" => generate_hash(),
          "points" => Enum.random(50..100),
          "solo" => true
        }
      }
    })
  end

  def build_wormhole_killmail(character_id, wh_class \\ "C3") do
    # J-space system IDs typically start with 310_00000
    wh_system_id =
      case wh_class do
        "C1" -> Enum.random(31_000_000..31_001_000)
        "C2" -> Enum.random(31_001_000..31_002_000)
        "C3" -> Enum.random(31_002_000..31_003_000)
        "C4" -> Enum.random(31_003_000..31_004_000)
        "C5" -> Enum.random(31_004_000..31_005_000)
        "C6" -> Enum.random(31_005_000..31_006_000)
        _ -> Enum.random(31_000_000..31_006_000)
      end

    build(:killmail_raw, %{
      solar_system_id: wh_system_id,
      killmail_data: %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.to_iso8601(DateTime.utc_now()),
        "solar_system_id" => wh_system_id,
        "victim" => %{
          "character_id" => character_id,
          # T3 Cruisers
          "ship_type_id" => Enum.random([29_984, 29_986, 29_988])
        },
        "attackers" => [
          %{
            "character_id" => Enum.random(90_000_000..100_000_000),
            "ship_type_id" => Enum.random([29_984, 29_986, 29_988]),
            "final_blow" => true
          }
        ],
        "zkb" => %{
          "hash" => generate_hash(),
          "locationID" => wh_system_id,
          "points" => Enum.random(100..200)
        }
      }
    })
  end

  def create_realistic_killmail_set(character_id, opts \\ []) do
    count = Keyword.get(opts, :count, 10)
    days_back = Keyword.get(opts, :days_back, 30)

    for _i <- 1..count do
      time_offset = -Enum.random(1..(days_back * 24 * 3600))
      killmail_time = DateTime.add(DateTime.utc_now(), time_offset, :second)

      killmail_data = %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.to_iso8601(killmail_time),
        "solar_system_id" => Enum.random([30_000_142, 30_002_187, 30_003_715]),
        "victim" => %{"character_id" => character_id},
        "attackers" => [
          %{
            "character_id" => Enum.random(90_000_000..100_000_000),
            "final_blow" => true
          }
        ],
        "zkb" => %{"hash" => generate_hash()}
      }

      attrs = %{
        killmail_id: killmail_data["killmail_id"],
        killmail_time: killmail_time,
        killmail_hash: killmail_data["zkb"]["hash"],
        solar_system_id: killmail_data["solar_system_id"],
        victim_character_id: character_id,
        victim_corporation_id: Enum.random(1_000_000..2_000_000),
        victim_alliance_id: Enum.random(99_000_000..100_000_000),
        victim_ship_type_id: Enum.random([587, 588, 589]),
        attacker_count: 1,
        raw_data: killmail_data,
        source: "test"
      }

      Ash.create!(KillmailRaw, attrs, domain: Api)
    end
  end

  def random_datetime_in_past(days_back) do
    # Limit to current month to avoid partition issues
    now = DateTime.utc_now()
    start_of_month = %{now | day: 1, hour: 0, minute: 0, second: 0, microsecond: {0, 0}}

    # Get seconds from start of month to now
    max_seconds = DateTime.diff(now, start_of_month, :second)

    # Limit days_back to current month to avoid partition errors
    max_days_in_month = max_seconds / (24 * 3600)
    actual_days_back = min(days_back, trunc(max_days_in_month))

    if actual_days_back > 0 do
      seconds_back = Enum.random(1..(actual_days_back * 24 * 3600))
      DateTime.add(now, -seconds_back, :second)
    else
      # If we can't go back, just use a few hours ago
      DateTime.add(now, -Enum.random(1..3600), :second)
    end
  end

  # Helper functions for creating specific patterns

  def create_killmails_for_character(character_id, count, opts \\ []) do
    for _i <- 1..count do
      killmail_data = build_realistic_killmail_data()

      # Determine if character is victim or attacker
      if Keyword.get(opts, :as_victim, false) do
        _killmail_data = put_in(killmail_data, ["victim", "character_id"], character_id)
      else
        # Add character as an attacker
        attackers = killmail_data["attackers"]

        new_attacker = %{
          "character_id" => character_id,
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "alliance_id" => Enum.random(99_000_000..100_000_000),
          "ship_type_id" => Enum.random([587, 588, 589, 17_738]),
          "weapon_type_id" => Enum.random([2185, 2873, 3074]),
          "damage_done" => Enum.random(100..10_000),
          "final_blow" => Keyword.get(opts, :final_blow, false),
          "security_status" => :rand.uniform() * 10 - 5
        }

        _killmail_data = Map.put(killmail_data, "attackers", [new_attacker | attackers])
      end

      # Override solar system if specified
      final_killmail_data =
        if system_id = Keyword.get(opts, :solar_system_id) do
          Map.put(killmail_data, "solar_system_id", system_id)
        else
          killmail_data
        end

      # Create the killmail
      create(:killmail_raw, %{killmail_data: final_killmail_data})
    end
  end

  def create_wormhole_activity(character_id, wh_class, opts \\ []) do
    # Wormhole system IDs are in specific ranges
    system_id =
      case wh_class do
        1 -> Enum.random(31_000_001..31_000_100)
        2 -> Enum.random(31_000_101..31_000_200)
        3 -> Enum.random(31_000_201..31_000_300)
        4 -> Enum.random(31_000_301..31_000_400)
        5 -> Enum.random(31_000_401..31_000_500)
        6 -> Enum.random(31_000_501..31_000_600)
        _ -> Enum.random(31_000_001..31_000_600)
      end

    # Use appropriate ship types for WH space
    ship_types =
      case wh_class do
        # Smaller ships
        c when c in [1, 2, 3] -> [587, 588, 589, 624]
        # T3 cruisers, Tengu
        c when c in [4, 5] -> [17_738, 22_428, 11_993]
        # Dreads and carriers
        6 -> [23_917, 23_919, 24_483]
        _ -> [587, 588, 589]
      end

    create_killmails_for_character(
      character_id,
      1,
      Keyword.merge(
        [
          solar_system_id: system_id,
          ship_type_id: Enum.random(ship_types)
        ],
        opts
      )
    )
  end

  def create_high_threat_pattern(character_id, opts \\ []) do
    # Create pattern indicating dangerous player
    count = Keyword.get(opts, :count, 20)

    for _i <- 1..count do
      killmail_data = %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" =>
          DateTime.utc_now()
          |> DateTime.add(-Enum.random(1..86_400), :second)
          |> DateTime.to_iso8601(),
        "solar_system_id" => Enum.random([30_000_142, 30_002_187, 30_003_715]),
        "attackers" => [
          %{
            "character_id" => character_id,
            "corporation_id" => Enum.random(1_000_000..2_000_000),
            "alliance_id" => Enum.random(99_000_000..100_000_000),
            # Loki (T3 cruiser)
            "ship_type_id" => 17_738,
            "weapon_type_id" => 2873,
            "damage_done" => Enum.random(5000..15_000),
            "final_blow" => true,
            "security_status" => -5.0
          }
        ],
        "victim" => %{
          "character_id" => Enum.random(90_000_000..95_000_000),
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          # Cheap ships
          "ship_type_id" => Enum.random([587, 588, 589]),
          "damage_taken" => Enum.random(5000..15_000),
          "items" => []
        },
        "moon_id" => nil,
        "war_id" => nil,
        "zkb" => %{
          "hash" => generate_hash(),
          "points" => Enum.random(50..100),
          "solo" => true
        }
      }

      create(:killmail_raw, %{killmail_data: killmail_data})
    end
  end

  def token_factory do
    %{
      access_token: "test_access_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh_token_#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      character_id: Enum.random(90_000_000..99_999_999),
      user_id: nil
    }
  end

  # Helper functions for generating consistent test IDs
  @spec character_id() :: integer()
  def character_id do
    Enum.random(90_000_000..100_000_000)
  end

  @spec corporation_id() :: integer()
  def corporation_id do
    Enum.random(1_000_000..2_000_000)
  end

  # Convenience functions for direct insertion (aligns with sprint plan patterns)

  @doc """
  Build and insert a killmail_raw record in one step.
  Returns the created Ash resource.
  """
  @spec insert_killmail_raw!(map()) :: KillmailRaw.t()
  def insert_killmail_raw!(attrs \\ %{}) do
    create(:killmail_raw, attrs)
  end

  @doc """
  Build and insert a participant record in one step.
  Returns the created Ash resource.
  """
  @spec insert_participant!(map()) :: EveDmv.Killmails.Participant.t()
  def insert_participant!(attrs \\ %{}) do
    create(:participant, attrs)
  end

  @doc """
  Build and insert a user record in one step.
  Returns the created Ash resource.
  """
  @spec insert_user!(map()) :: User.t()
  def insert_user!(attrs \\ %{}) do
    create(:user, attrs)
  end

  @doc """
  Create a killmail with participants in one step.
  Useful for testing scenarios that need both killmail and participant data.
  """
  @spec create_killmail_with_participants!(map(), keyword()) ::
          {KillmailRaw.t(), [EveDmv.Killmails.Participant.t()]}
  def create_killmail_with_participants!(killmail_attrs \\ %{}, opts \\ []) do
    attacker_count = Keyword.get(opts, :attacker_count, 1)

    killmail = insert_killmail_raw!(killmail_attrs)

    # Create victim participant
    victim =
      insert_participant!(%{
        killmail_id: killmail.killmail_id,
        killmail_time: killmail.killmail_time,
        character_id: killmail.victim_character_id,
        corporation_id: killmail.victim_corporation_id,
        alliance_id: killmail.victim_alliance_id,
        ship_type_id: killmail.victim_ship_type_id,
        solar_system_id: killmail.solar_system_id,
        is_victim: true,
        damage_done: 0
      })

    # Create attacker participants (handle attacker_count = 0 case)
    attackers =
      if attacker_count > 0 do
        for i <- 1..attacker_count do
          insert_participant!(%{
            killmail_id: killmail.killmail_id,
            killmail_time: killmail.killmail_time,
            character_id: Enum.random(90_000_000..99_999_999),
            corporation_id: Enum.random(98_000_000..98_999_999),
            ship_type_id: random_ship_by_role(:cruiser),
            solar_system_id: killmail.solar_system_id,
            is_victim: false,
            final_blow: i == 1,
            damage_done: Enum.random(100..10_000)
          })
        end
      else
        []
      end

    {killmail, [victim | attackers]}
  end
end
