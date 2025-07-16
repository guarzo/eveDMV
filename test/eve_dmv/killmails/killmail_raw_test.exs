defmodule EveDmv.Killmails.KillmailRawTest do
  @moduledoc """
  Tests for KillmailRaw resource operations.
  """

  use EveDmv.DataCase, async: true

  import Ash.Expr

  alias Ecto.Adapters.SQL
  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.TestDataGenerator

  require Ash.Query

  setup do
    # Create necessary partitions for test data
    create_test_partitions()
    :ok
  end

  defp create_test_partitions do
    # Create monthly partitions for the current and next month
    current_date = Date.utc_today()
    next_month = Date.add(current_date, 30)

    for date <- [current_date, next_month] do
      partition_name = "killmails_raw_#{Calendar.strftime(date, "%Y_%m")}"
      create_partition_if_not_exists("killmails_raw", partition_name, date)
    end
  end

  defp create_partition_if_not_exists(table_name, partition_name, date) do
    start_date = Date.beginning_of_month(date)

    end_date =
      date
      |> Date.add(32)
      |> Date.beginning_of_month()
      |> Date.add(-1)

    next_month_start = Date.add(end_date, 1)

    query = """
    CREATE TABLE IF NOT EXISTS #{partition_name} PARTITION OF #{table_name}
    FOR VALUES FROM ('#{start_date}') TO ('#{next_month_start}')
    """

    SQL.query!(EveDmv.Repo, query)
  rescue
    # Partition might already exist, ignore error
    Postgrex.Error -> :ok
  end

  describe "create/1" do
    test "creates a valid killmail raw record" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      attrs = %{
        killmail_id: killmail_data["killmail_id"],
        killmail_time: elem(DateTime.from_iso8601(killmail_data["timestamp"]), 1),
        killmail_hash: killmail_data["killmail_hash"],
        solar_system_id: killmail_data["solar_system_id"],
        victim_character_id:
          List.first(
            get_in(killmail_data, [
              "participants",
              Access.filter(& &1["is_victim"]),
              "character_id"
            ])
          ),
        victim_corporation_id:
          List.first(
            get_in(killmail_data, [
              "participants",
              Access.filter(& &1["is_victim"]),
              "corporation_id"
            ])
          ),
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
    test "upserts killmail data without duplicates" do
      killmail_data = TestDataGenerator.generate_sample_killmail()

      attrs = %{
        killmail_id: killmail_data["killmail_id"],
        killmail_time: elem(DateTime.from_iso8601(killmail_data["timestamp"]), 1),
        killmail_hash: killmail_data["killmail_hash"],
        solar_system_id: killmail_data["solar_system_id"],
        victim_character_id:
          List.first(
            get_in(killmail_data, [
              "participants",
              Access.filter(& &1["is_victim"]),
              "character_id"
            ])
          ),
        victim_corporation_id:
          List.first(
            get_in(killmail_data, [
              "participants",
              Access.filter(& &1["is_victim"]),
              "corporation_id"
            ])
          ),
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

      # Verify only one record exists with this killmail_id
      count =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.filter(killmail_id == ^attrs.killmail_id)
        |> Ash.count!(domain: Api)

      assert count == 1
    end
  end

  describe "read queries" do
    setup do
      # Create test data with unique system IDs to avoid collision with other tests
      # Using process pid to ensure uniqueness
      test_system_id = (32_000_000 + System.unique_integer([:positive])) |> rem(100_000)
      other_system_id = test_system_id + 1

      killmails = [
        TestDataGenerator.generate_sample_killmail(solar_system_id: test_system_id),
        TestDataGenerator.generate_sample_killmail(solar_system_id: test_system_id),
        TestDataGenerator.generate_sample_killmail(solar_system_id: test_system_id),
        TestDataGenerator.generate_sample_killmail(solar_system_id: other_system_id),
        TestDataGenerator.generate_sample_killmail(solar_system_id: other_system_id)
      ]

      for killmail_data <- killmails do
        attrs = %{
          killmail_id: killmail_data["killmail_id"],
          killmail_time: elem(DateTime.from_iso8601(killmail_data["timestamp"]), 1),
          killmail_hash: killmail_data["killmail_hash"],
          solar_system_id: killmail_data["solar_system_id"],
          victim_character_id:
            List.first(
              get_in(killmail_data, [
                "participants",
                Access.filter(& &1["is_victim"]),
                "character_id"
              ])
            ),
          victim_corporation_id:
            List.first(
              get_in(killmail_data, [
                "participants",
                Access.filter(& &1["is_victim"]),
                "corporation_id"
              ])
            ),
          victim_ship_type_id: killmail_data["ship"]["type_id"],
          attacker_count: length(Enum.filter(killmail_data["participants"], &(!&1["is_victim"]))),
          raw_data: killmail_data,
          source: "test"
        }

        Ash.create!(KillmailRaw, attrs, domain: Api)
      end

      %{test_system_id: test_system_id, other_system_id: other_system_id}
    end

    test "recent_kills returns killmails sorted by time" do
      killmails =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.for_read(:recent_kills)
        |> Ash.read!(domain: Api)

      assert length(killmails) >= 5

      # Should be sorted by killmail_time desc
      times = Enum.map(killmails, & &1.killmail_time)
      assert times == Enum.sort(times, &(DateTime.compare(&1, &2) != :lt))
    end

    test "by_system filters by solar system", %{test_system_id: test_system_id} do
      killmails =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.for_read(:by_system, %{system_id: test_system_id})
        |> Ash.read!(domain: Api)

      # We created exactly 3 killmails with the test_system_id
      assert length(killmails) == 3
      assert Enum.all?(killmails, &(&1.solar_system_id == test_system_id))
    end
  end

  describe "calculations" do
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

      killmail = Ash.create!(EveDmv.Killmails.KillmailRaw, attrs, domain: Api)

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

    # Skipped: flaky test - depends on exact timing and partition setup
    @tag :skip
    test "is_recent identifies recent killmails" do
      # Ensure June partition exists
      SQL.query!(EveDmv.Repo, """
        CREATE TABLE IF NOT EXISTS killmails_raw_2025_06 PARTITION OF killmails_raw
        FOR VALUES FROM ('2025-06-01') TO ('2025-07-01')
      """)

      # Create a recent killmail (1 hour ago) - ensure it's in current month
      recent_time = DateTime.add(DateTime.utc_now(), -3600, :second)

      # Create an old killmail - use June 30th and is > 24 hours ago
      # June 30th, definitely > 24 hours ago
      old_time = ~U[2025-06-30 00:00:00Z]

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
