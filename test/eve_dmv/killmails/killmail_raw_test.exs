defmodule EveDmv.Killmails.KillmailRawTest do
  @moduledoc """
  Tests for KillmailRaw resource operations.
  """

  use ExUnit.Case, async: true
  import EveDmv.TestHelpers
  import Ash.Expr, only: [expr: 1]
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Killmails.{KillmailRaw, TestDataGenerator}

  setup do
    setup_database()
    :ok
  end

  describe "create/1" do
    test "creates a valid killmail raw record" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      attrs = %{
        killmail_id: killmail_data["killmail_id"],
        killmail_time: DateTime.from_iso8601(killmail_data["timestamp"]) |> elem(1),
        killmail_hash: killmail_data["killmail_hash"],
        solar_system_id: killmail_data["solar_system_id"],
        victim_character_id:
          get_in(killmail_data, ["participants", Access.filter(& &1["is_victim"]), "character_id"])
          |> List.first(),
        victim_corporation_id:
          get_in(killmail_data, [
            "participants",
            Access.filter(& &1["is_victim"]),
            "corporation_id"
          ])
          |> List.first(),
        victim_ship_type_id: killmail_data["ship"]["type_id"],
        attacker_count: length(Enum.filter(killmail_data["participants"], &(!&1["is_victim"]))),
        raw_data: killmail_data,
        source: "test"
      }

      assert {:ok, killmail} = Ash.create(KillmailRaw, attrs, domain: Api)
      assert killmail.killmail_id == attrs.killmail_id
      assert killmail.source == "test"
      assert is_map(killmail.raw_data)
    end

    test "fails with invalid data" do
      attrs = %{
        # Invalid: cannot be nil
        killmail_id: nil,
        killmail_time: DateTime.utc_now(),
        killmail_hash: "test-hash",
        solar_system_id: 30_000_142,
        victim_ship_type_id: 22_452,
        raw_data: %{},
        source: "test"
      }

      assert {:error, %Ash.Error.Invalid{}} = Ash.create(KillmailRaw, attrs, domain: Api)
    end
  end

  describe "ingest_from_source/1" do
    @tag :skip
    test "upserts killmail data without duplicates" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      attrs = %{
        killmail_id: killmail_data["killmail_id"],
        killmail_time: DateTime.from_iso8601(killmail_data["timestamp"]) |> elem(1),
        killmail_hash: killmail_data["killmail_hash"],
        solar_system_id: killmail_data["solar_system_id"],
        victim_character_id:
          get_in(killmail_data, ["participants", Access.filter(& &1["is_victim"]), "character_id"])
          |> List.first(),
        victim_corporation_id:
          get_in(killmail_data, [
            "participants",
            Access.filter(& &1["is_victim"]),
            "corporation_id"
          ])
          |> List.first(),
        victim_ship_type_id: killmail_data["ship"]["type_id"],
        attacker_count: length(Enum.filter(killmail_data["participants"], &(!&1["is_victim"]))),
        raw_data: killmail_data,
        source: "wanderer-kills"
      }

      # First insert
      assert {:ok, killmail1} =
               Ash.create(KillmailRaw, attrs, action: :ingest_from_source, domain: Api)

      # Second insert should not create duplicate
      assert {:ok, killmail2} =
               Ash.create(KillmailRaw, attrs, action: :ingest_from_source, domain: Api)

      # Should be the same record
      assert killmail1.killmail_id == killmail2.killmail_id

      # Verify only one record exists
      count = KillmailRaw |> Ash.Query.new() |> Ash.count!(domain: Api)
      assert count == 1
    end
  end

  describe "read queries" do
    setup do
      # Create test data
      killmails = TestDataGenerator.generate_multiple_killmails(3)

      for killmail_data <- killmails do
        attrs = %{
          killmail_id: killmail_data["killmail_id"],
          killmail_time: DateTime.from_iso8601(killmail_data["timestamp"]) |> elem(1),
          killmail_hash: killmail_data["killmail_hash"],
          solar_system_id: killmail_data["solar_system_id"],
          victim_character_id:
            get_in(killmail_data, [
              "participants",
              Access.filter(& &1["is_victim"]),
              "character_id"
            ])
            |> List.first(),
          victim_corporation_id:
            get_in(killmail_data, [
              "participants",
              Access.filter(& &1["is_victim"]),
              "corporation_id"
            ])
            |> List.first(),
          victim_ship_type_id: killmail_data["ship"]["type_id"],
          attacker_count: length(Enum.filter(killmail_data["participants"], &(!&1["is_victim"]))),
          raw_data: killmail_data,
          source: "test"
        }

        Ash.create!(KillmailRaw, attrs, domain: Api)
      end

      :ok
    end

    @tag :skip
    test "recent_kills returns killmails sorted by time" do
      killmails =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.for_read(:recent_kills)
        |> Ash.read!(domain: Api)

      assert length(killmails) == 3

      # Should be sorted by killmail_time desc
      times = Enum.map(killmails, & &1.killmail_time)
      assert times == Enum.sort(times, &(DateTime.compare(&1, &2) != :lt))
    end

    @tag :skip
    test "by_system filters by solar system" do
      killmails =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.for_read(:by_system, %{system_id: 30_000_142})
        |> Ash.read!(domain: Api)

      assert length(killmails) == 3
      assert Enum.all?(killmails, &(&1.solar_system_id == 30_000_142))
    end
  end

  describe "calculations" do
    @tag :skip
    test "age_in_hours calculates correct age" do
      # Create a killmail from 2 hours ago
      two_hours_ago = DateTime.add(DateTime.utc_now(), -2 * 3600, :second)

      killmail_data = TestDataGenerator.generate_sample_killmail(timestamp: two_hours_ago)

      attrs = %{
        killmail_id: killmail_data["killmail_id"],
        killmail_time: two_hours_ago,
        killmail_hash: killmail_data["killmail_hash"],
        solar_system_id: killmail_data["solar_system_id"],
        victim_ship_type_id: killmail_data["ship"]["type_id"],
        attacker_count: 1,
        raw_data: killmail_data,
        source: "test"
      }

      killmail = Ash.create!(KillmailRaw, attrs, domain: Api)

      # Load with calculation
      killmail_with_age =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.load([:age_in_hours])
        |> Ash.Query.filter(expr(killmail_id == ^killmail.killmail_id))
        |> Ash.read_one!(domain: Api)

      # Should be approximately 2 hours (allowing some test execution time)
      assert killmail_with_age.age_in_hours >= 1
      assert killmail_with_age.age_in_hours <= 3
    end

    test "is_recent identifies recent killmails" do
      # Create a recent killmail (1 hour ago)
      recent_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      # Create an old killmail (25 hours ago)
      old_time = DateTime.add(DateTime.utc_now(), -25 * 3600, :second)

      recent_data = TestDataGenerator.generate_sample_killmail(timestamp: recent_time)
      old_data = TestDataGenerator.generate_sample_killmail(timestamp: old_time)

      recent_attrs = %{
        killmail_id: recent_data["killmail_id"],
        killmail_time: recent_time,
        killmail_hash: recent_data["killmail_hash"],
        solar_system_id: recent_data["solar_system_id"],
        victim_ship_type_id: recent_data["ship"]["type_id"],
        attacker_count: 1,
        raw_data: recent_data,
        source: "test"
      }

      old_attrs = %{
        killmail_id: old_data["killmail_id"],
        killmail_time: old_time,
        killmail_hash: old_data["killmail_hash"],
        solar_system_id: old_data["solar_system_id"],
        victim_ship_type_id: old_data["ship"]["type_id"],
        attacker_count: 1,
        raw_data: old_data,
        source: "test"
      }

      recent_killmail = Ash.create!(KillmailRaw, recent_attrs, domain: Api)
      old_killmail = Ash.create!(KillmailRaw, old_attrs, domain: Api)

      # Load with calculation
      killmails =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.load([:is_recent])
        |> Ash.read!(domain: Api)

      recent_result = Enum.find(killmails, &(&1.killmail_id == recent_killmail.killmail_id))
      old_result = Enum.find(killmails, &(&1.killmail_id == old_killmail.killmail_id))

      assert recent_result.is_recent == true
      assert old_result.is_recent == false
    end
  end
end
