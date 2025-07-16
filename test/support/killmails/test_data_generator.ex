defmodule EveDmv.Killmails.TestDataGenerator do
  @moduledoc """
  Generates test killmail data for development and testing purposes.
  """

  @doc """
  Generates a sample killmail payload that matches the expected format
  from wanderer-kills SSE feed.
  """
  def generate_sample_killmail(opts \\ []) do
    # Handle both keyword lists and maps for flexibility
    opts = if is_map(opts), do: Map.to_list(opts), else: opts

    killmail_id = Keyword.get(opts, :killmail_id, Enum.random(100_000_000..999_999_999))
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())
    system_id = Keyword.get(opts, :solar_system_id, Enum.random(30_000_000..30_005_000))

    # Map some common system IDs to names for testing
    system_name =
      case system_id do
        30_000_142 -> "Jita"
        30_000_144 -> "Rens"
        30_002_187 -> "Amarr"
        _ -> "System-#{system_id}"
      end

    %{
      "killmail_id" => killmail_id,
      "killmail_hash" => generate_hash(killmail_id, timestamp),
      "timestamp" => DateTime.to_iso8601(timestamp),
      "system" => %{
        "id" => system_id,
        "name" => system_name
      },
      "solar_system_id" => system_id,
      "solar_system_name" => system_name,
      "ship" => %{
        "type_id" => 22_452,
        "name" => "Rifter"
      },
      "isk_value" => Enum.random(10_000_000..1_000_000_000),
      "total_value" => Enum.random(10_000_000..1_000_000_000),
      "ship_value" => Enum.random(1_000_000..50_000_000),
      "fitted_value" => Enum.random(5_000_000..100_000_000),
      "participants" => [
        generate_victim(),
        # final blow
        generate_attacker(true),
        # regular attacker
        generate_attacker(false)
      ],
      "module_tags" => ["T2 Guns", "Shield Extender", "High Slot"],
      "noteworthy_modules" => ["Autocannon II", "Medium Shield Extender II"],
      "price_data_source" => "test_data"
    }
  end

  @doc """
  Generates a JSON string representation of a sample killmail
  suitable for SSE event data.
  """
  def generate_sample_sse_event(opts \\ []) do
    killmail = generate_sample_killmail(opts)

    %{
      event: "message",
      data: Jason.encode!(killmail),
      id: to_string(killmail["killmail_id"]),
      retry: nil
    }
  end

  @doc """
  Generates multiple sample killmails for bulk testing.
  """
  def generate_multiple_killmails(count \\ 10) do
    Enum.map(1..count, fn i ->
      # Spread timestamps over the last hour
      timestamp = DateTime.add(DateTime.utc_now(), -3600 + i * 360, :second)
      generate_sample_killmail(timestamp: timestamp)
    end)
  end

  # Private helper functions

  defp generate_victim do
    character_id = Enum.random(90_000_000..99_999_999)
    corporation_id = Enum.random(1000..9999)

    %{
      "character_id" => character_id,
      "character_name" => "TestVictim#{character_id}",
      "corporation_id" => corporation_id,
      "corporation_name" => "Test Corp #{corporation_id}",
      "alliance_id" => Enum.random([nil, Enum.random(10_000..19_999)]),
      "alliance_name" => nil,
      "ship_type_id" => 22_452,
      "ship_name" => "Rifter",
      "damage_done" => 0,
      "security_status" => Enum.random(-10..10) / 10,
      "is_victim" => true,
      "final_blow" => false
    }
  end

  defp generate_attacker(final_blow?) do
    character_id = Enum.random(90_000_000..99_999_999)
    corporation_id = Enum.random(1000..9999)
    damage = if final_blow?, do: Enum.random(500..2000), else: Enum.random(100..1000)

    %{
      "character_id" => character_id,
      "character_name" => "TestAttacker#{character_id}",
      "corporation_id" => corporation_id,
      "corporation_name" => "Attack Corp #{corporation_id}",
      "alliance_id" => Enum.random([nil, Enum.random(20_000..29_999)]),
      "alliance_name" => nil,
      # Various frigates
      "ship_type_id" => Enum.random([11_176, 11_178, 22_452]),
      "ship_name" => "Attack Ship",
      "weapon_type_id" => 2488,
      "weapon_name" => "Autocannon II",
      "damage_done" => damage,
      "security_status" => Enum.random(-10..10) / 10,
      "is_victim" => false,
      "final_blow" => final_blow?
    }
  end

  defp generate_hash(killmail_id, timestamp) do
    data = "#{killmail_id}-#{DateTime.to_iso8601(timestamp)}"
    hash = :crypto.hash(:sha256, data)
    Base.encode16(hash, case: :lower)
  end
end
