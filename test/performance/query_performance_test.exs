defmodule EveDmv.Performance.QueryPerformanceTest do
  @moduledoc """
  Performance regression tests for database queries.

  These tests ensure that our query optimizations remain effective
  and don't regress over time.
  """

  use EveDmv.DataCase, async: false

  @moduletag :skip

  alias EveDmv.Database.{CharacterQueries, CorporationQueries}
  alias EveDmv.Factories, as: Factory

  # milliseconds
  @max_character_query_time 100
  # milliseconds
  @max_corp_query_time 200
  # number of test killmails to create
  @test_data_size 1000

  setup do
    # Ensure QueryCache is available
    case Process.whereis(EveDmv.Cache.QueryCache) do
      nil ->
        # Start QueryCache if not running
        {:ok, _} = EveDmv.Cache.QueryCache.start_link([])

      _pid ->
        # Clear the cache if already running
        EveDmv.Cache.QueryCache.clear_all()
    end

    # Create test data
    {:ok, _} = create_test_killmails(@test_data_size)
    :ok
  end

  describe "character query performance" do
    test "get_character_stats completes within threshold" do
      character_id = Factory.character_id()
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)

      {time_us, result} =
        :timer.tc(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      time_ms = time_us / 1000

      assert is_map(result)
      assert Map.has_key?(result, :kills)
      assert Map.has_key?(result, :deaths)
      assert Map.has_key?(result, :kd_ratio)

      assert time_ms < @max_character_query_time,
             "Character stats query took #{time_ms}ms, exceeding #{@max_character_query_time}ms threshold"
    end

    test "get_recent_activity with pagination completes within threshold" do
      character_id = Factory.character_id()

      {time_us, result} =
        :timer.tc(fn ->
          CharacterQueries.get_recent_activity(character_id, page: 1, page_size: 20)
        end)

      time_ms = time_us / 1000

      assert is_map(result)
      assert Map.has_key?(result, :data)
      assert Map.has_key?(result, :pagination)

      assert time_ms < @max_character_query_time,
             "Recent activity query took #{time_ms}ms, exceeding #{@max_character_query_time}ms threshold"
    end

    test "get_character_affiliations completes quickly" do
      character_id = Factory.character_id()

      {time_us, result} =
        :timer.tc(fn ->
          CharacterQueries.get_character_affiliations(character_id)
        end)

      time_ms = time_us / 1000

      assert is_map(result)
      assert time_ms < 50, "Affiliation query took #{time_ms}ms, should be under 50ms"
    end
  end

  describe "corporation query performance" do
    test "get_corporation_stats completes within threshold" do
      corporation_id = Factory.corporation_id()
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)

      {time_us, result} =
        :timer.tc(fn ->
          CorporationQueries.get_corporation_stats(corporation_id, since_date)
        end)

      time_ms = time_us / 1000

      assert is_map(result)
      assert Map.has_key?(result, :kills)
      assert Map.has_key?(result, :losses)
      assert Map.has_key?(result, :efficiency)

      assert time_ms < @max_corp_query_time,
             "Corporation stats query took #{time_ms}ms, exceeding #{@max_corp_query_time}ms threshold"
    end

    test "get_top_active_members completes within threshold" do
      corporation_id = Factory.corporation_id()
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)

      {time_us, result} =
        :timer.tc(fn ->
          CorporationQueries.get_top_active_members(corporation_id, 20, since_date)
        end)

      time_ms = time_us / 1000

      assert is_list(result)

      assert time_ms < @max_corp_query_time,
             "Top members query took #{time_ms}ms, exceeding #{@max_corp_query_time}ms threshold"
    end

    test "get_timezone_activity completes within threshold" do
      corporation_id = Factory.corporation_id()
      since_date = DateTime.add(DateTime.utc_now(), -7, :day)

      {time_us, result} =
        :timer.tc(fn ->
          CorporationQueries.get_timezone_activity(corporation_id, since_date)
        end)

      time_ms = time_us / 1000

      assert is_list(result)
      # All hours represented
      assert length(result) == 24

      assert time_ms < @max_corp_query_time,
             "Timezone activity query took #{time_ms}ms, exceeding #{@max_corp_query_time}ms threshold"
    end
  end

  describe "concurrent query performance" do
    test "handles concurrent character queries efficiently" do
      character_ids = Enum.map(1..10, fn _ -> Factory.character_id() end)
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)

      {time_us, results} =
        :timer.tc(fn ->
          character_ids
          |> Enum.map(fn char_id ->
            Task.async(fn ->
              CharacterQueries.get_character_stats(char_id, since_date)
            end)
          end)
          |> Enum.map(&Task.await(&1, 5000))
        end)

      time_ms = time_us / 1000
      avg_time = time_ms / 10

      assert length(results) == 10
      assert Enum.all?(results, &is_map/1)

      assert avg_time < @max_character_query_time,
             "Average concurrent query time #{avg_time}ms exceeds threshold"
    end
  end

  describe "cache effectiveness" do
    test "cached queries are significantly faster" do
      character_id = Factory.character_id()
      since_date = DateTime.add(DateTime.utc_now(), -30, :day)

      # First query (cache miss)
      {time_miss_us, _} =
        :timer.tc(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      # Second query (cache hit)
      {time_hit_us, _} =
        :timer.tc(fn ->
          CharacterQueries.get_character_stats(character_id, since_date)
        end)

      time_miss_ms = time_miss_us / 1000
      time_hit_ms = time_hit_us / 1000

      # Cache hit should be at least 10x faster
      assert time_hit_ms < time_miss_ms / 10,
             "Cache hit (#{time_hit_ms}ms) not significantly faster than miss (#{time_miss_ms}ms)"
    end
  end

  # Helper functions

  defp create_test_killmails(count) do
    # Create a mix of kills and losses for several characters/corps
    character_ids = Enum.map(1..10, fn _ -> Factory.character_id() end)
    corporation_ids = Enum.map(1..5, fn _ -> Factory.corporation_id() end)

    killmails =
      Enum.map(1..count, fn i ->
        character_id = Enum.random(character_ids)
        corporation_id = Enum.random(corporation_ids)

        %{
          killmail_id: 100_000_000 + i,
          killmail_hash: "test_hash_#{i}",
          killmail_time: DateTime.add(DateTime.utc_now(), -rem(i, 90), :day),
          solar_system_id: 30_000_142,
          victim_character_id: if(rem(i, 2) == 0, do: character_id, else: nil),
          victim_corporation_id: corporation_id,
          victim_alliance_id: if(rem(i, 3) == 0, do: 99_000_000 + rem(i, 10), else: nil),
          victim_ship_type_id: 587 + rem(i, 10),
          attacker_count: rem(i, 20) + 1,
          raw_data: build_raw_killmail_data(i, character_ids, corporation_ids),
          source: "test",
          inserted_at: DateTime.utc_now()
        }
      end)

    # Bulk insert for efficiency
    {count, _} = EveDmv.Repo.insert_all("killmails_raw", killmails)
    {:ok, count}
  end

  defp build_raw_killmail_data(index, character_ids, corporation_ids) do
    # Build realistic killmail JSON structure
    victim_char_id = if rem(index, 2) == 0, do: Enum.random(character_ids), else: nil

    %{
      "killmail_id" => 100_000_000 + index,
      "killmail_time" =>
        DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -rem(index, 90), :day)),
      "solar_system_id" => 30_000_142,
      "victim" => %{
        "character_id" => victim_char_id,
        "character_name" => if(victim_char_id, do: "Test Pilot #{victim_char_id}", else: nil),
        "corporation_id" => Enum.random(corporation_ids),
        "corporation_name" => "Test Corp",
        "ship_type_id" => 587 + rem(index, 10)
      },
      "attackers" => build_attackers(index, character_ids, corporation_ids),
      "total_value" => :rand.uniform(1_000_000_000)
    }
  end

  defp build_attackers(index, character_ids, corporation_ids) do
    # Create 1-20 attackers
    attacker_count = rem(index, 20) + 1

    Enum.map(1..attacker_count, fn i ->
      char_id = Enum.random(character_ids)
      corp_id = Enum.random(corporation_ids)

      %{
        "character_id" => to_string(char_id),
        "character_name" => "Attacker #{char_id}",
        "corporation_id" => corp_id,
        "corporation_name" => "Corp #{corp_id}",
        "ship_type_id" => 587 + rem(i, 10),
        "weapon_type_id" => if(rem(i, 2) == 0, do: 2456, else: nil),
        "damage_done" => :rand.uniform(10000)
      }
    end)
  end
end
