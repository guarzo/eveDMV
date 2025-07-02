defmodule EveDmv.Factories do
  @moduledoc """
  Test data factories for EVE DMV testing
  """

  alias EveDmv.{Api, Killmails.KillmailRaw, Users.User}

  def character_factory do
    %{
      eve_character_id: Enum.random(90_000_000..100_000_000),
      eve_character_name: "Test Character #{System.unique_integer([:positive])}",
      eve_corporation_id: Enum.random(1_000_000..2_000_000),
      eve_alliance_id: Enum.random(99_000_000..100_000_000)
    }
  end

  def killmail_raw_factory do
    killmail_time = DateTime.utc_now() |> DateTime.add(-Enum.random(1..3600), :second)

    %{
      killmail_id: System.unique_integer([:positive]),
      killmail_time: killmail_time,
      solar_system_id: Enum.random(30_000_000..31_000_000),
      killmail_data: build_realistic_killmail_data()
    }
  end

  def user_factory do
    character_id = Enum.random(90_000_000..100_000_000)

    %{
      eve_character_id: character_id,
      eve_character_name: "Test Character #{System.unique_integer([:positive])}",
      eve_corporation_id: Enum.random(1_000_000..2_000_000),
      eve_alliance_id: Enum.random(99_000_000..100_000_000),
      access_token: "test_access_token_#{System.unique_integer([:positive])}",
      refresh_token: "test_refresh_token_#{System.unique_integer([:positive])}",
      token_expires_at: DateTime.utc_now() |> DateTime.add(3600, :second)
    }
  end

  def build(factory_name, attrs \\ %{}) do
    factory_name
    |> build_factory()
    |> Map.merge(attrs)
  end

  def create(factory_name, attrs \\ %{}) do
    factory_name
    |> build(attrs)
    |> insert_into_database()
  end

  defp build_factory(:character), do: character_factory()
  defp build_factory(:killmail_raw), do: killmail_raw_factory()
  defp build_factory(:user), do: user_factory()

  defp build_realistic_killmail_data do
    # Create realistic killmail JSON structure
    victim_character_id = Enum.random(90_000_000..100_000_000)
    attacker_character_id = Enum.random(90_000_000..100_000_000)

    %{
      "killmail_id" => System.unique_integer([:positive]),
      "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "solar_system_id" => Enum.random(30_000_000..31_000_000),
      "victim" => %{
        "character_id" => victim_character_id,
        "corporation_id" => Enum.random(1_000_000..2_000_000),
        "alliance_id" => Enum.random(99_000_000..100_000_000),
        # Rifter, Rupture, Stabber
        "ship_type_id" => Enum.random([587, 588, 589]),
        "damage_taken" => Enum.random(1000..5000)
      },
      "attackers" => [
        %{
          "character_id" => attacker_character_id,
          "corporation_id" => Enum.random(1_000_000..2_000_000),
          "alliance_id" => Enum.random(99_000_000..100_000_000),
          "ship_type_id" => Enum.random([587, 588, 589]),
          "final_blow" => true,
          "damage_done" => Enum.random(1000..5000),
          "security_status" => Enum.random(-10..10) / 1,
          "weapon_type_id" => Enum.random([1000..2000])
        }
      ],
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

  defp insert_into_database(%{eve_character_id: _} = user_attrs) do
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

  defp insert_into_database(%{killmail_id: _} = killmail_attrs) do
    # Extract required fields for KillmailRaw resource
    killmail_data = Map.get(killmail_attrs, :killmail_data, %{})

    attrs = %{
      killmail_id: killmail_attrs.killmail_id,
      killmail_time: killmail_attrs.killmail_time,
      killmail_hash: get_in(killmail_data, ["zkb", "hash"]) || generate_hash(),
      solar_system_id: killmail_attrs.solar_system_id,
      victim_character_id: get_in(killmail_data, ["victim", "character_id"]),
      victim_corporation_id: get_in(killmail_data, ["victim", "corporation_id"]),
      victim_alliance_id: get_in(killmail_data, ["victim", "alliance_id"]),
      victim_ship_type_id: get_in(killmail_data, ["victim", "ship_type_id"]),
      attacker_count: length(Map.get(killmail_data, "attackers", [])),
      raw_data: killmail_data,
      source: "test"
    }

    Ash.create!(KillmailRaw, attrs, domain: Api)
  end

  defp insert_into_database(attrs) do
    # Generic fallback - just return the attrs
    attrs
  end

  defp generate_hash do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  # Specialized factory functions for specific test scenarios

  def build_high_threat_killmail(character_id) do
    build(:killmail_raw, %{
      killmail_data: %{
        "killmail_id" => System.unique_integer([:positive]),
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "solar_system_id" => Enum.random(30_000_000..31_000_000),
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
    # J-space system IDs typically start with 31000000
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
        "killmail_time" => DateTime.utc_now() |> DateTime.to_iso8601(),
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
        "solar_system_id" => Enum.random(30_000_000..31_000_000),
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
    seconds_back = Enum.random(1..(days_back * 24 * 3600))
    DateTime.add(DateTime.utc_now(), -seconds_back, :second)
  end
end
