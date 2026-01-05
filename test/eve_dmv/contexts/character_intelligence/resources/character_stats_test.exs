defmodule EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStatsTest do
  @moduledoc """
  Tests for the CharacterStats virtual Ash resource.

  CharacterStats calculates character statistics (kills, deaths, K/D ratio)
  from the Participant resource without persisting to the database.
  """

  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.CharacterIntelligence.Resources.CharacterStats

  describe "calculate_for_character/2" do
    test "returns zero counts for character with no activity" do
      character_id = 999_999_999

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.character_id == character_id
      assert stats.kills == 0
      assert stats.deaths == 0
      assert stats.period_days >= 89
      assert stats.period_days <= 91
    end

    test "correctly counts kills for a character" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 3 kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..3 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 3
      assert stats.deaths == 0
    end

    test "correctly counts deaths for a character" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 2 deaths (each needs a separate killmail due to unique constraint)
      for _ <- 1..2 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          ship_type_id: 587
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 0
      assert stats.deaths == 2
    end

    test "correctly counts both kills and deaths" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 5 kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..5 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      # Create 2 deaths (each needs a separate killmail due to unique constraint)
      for _ <- 1..2 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          ship_type_id: 587
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 5
      assert stats.deaths == 2
    end

    test "respects date filter for since_date" do
      character_id = Enum.random(90_000_000..99_999_999)
      recent_time = DateTime.utc_now()

      # Create kills within range (each needs a separate killmail due to unique constraint)
      for _ <- 1..3 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: recent_time,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      # Query only recent data (last 7 days)
      since_date = DateTime.add(DateTime.utc_now(), -7, :day)
      {:ok, stats} = CharacterStats.calculate_for_character(character_id, since_date)

      assert stats.kills == 3
      assert stats.period_days >= 6
      assert stats.period_days <= 8
    end

    test "uses default 90-day window when since_date is nil" do
      character_id = Enum.random(90_000_000..99_999_999)

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      # Period should be approximately 90 days
      assert stats.period_days >= 89
      assert stats.period_days <= 91
    end

    test "character_id is required" do
      # Ash validates nil character_id and returns an error tuple
      assert {:error, _} = CharacterStats.calculate_for_character(nil, nil)
    end
  end

  describe "kd_ratio calculation" do
    test "calculates K/D ratio correctly when deaths > 0" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 10 kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..10 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      # Create 2 deaths (each needs a separate killmail due to unique constraint)
      for _ <- 1..2 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: true,
          ship_type_id: 587
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)
      kd_ratio = Ash.load!(stats, :kd_ratio, domain: EveDmv.Api).kd_ratio

      assert kd_ratio == 5.0
    end

    test "K/D ratio equals kills when deaths is 0" do
      character_id = Enum.random(90_000_000..99_999_999)
      now = DateTime.utc_now()

      # Create 7 kills (each needs a separate killmail due to unique constraint)
      for _ <- 1..7 do
        {killmail, _} = create_killmail_with_participants!(%{}, attacker_count: 0)

        insert_participant!(%{
          character_id: character_id,
          killmail_id: killmail.killmail_id,
          killmail_time: now,
          solar_system_id: killmail.solar_system_id,
          is_victim: false,
          ship_type_id: 587
        })
      end

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)
      kd_ratio = Ash.load!(stats, :kd_ratio, domain: EveDmv.Api).kd_ratio

      assert kd_ratio == 7.0
    end

    test "K/D ratio is 0.0 when both kills and deaths are 0" do
      character_id = 999_999_998

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)
      kd_ratio = Ash.load!(stats, :kd_ratio, domain: EveDmv.Api).kd_ratio

      assert kd_ratio == 0.0
    end
  end

  describe "isk_efficiency calculation" do
    test "returns 0.0 when no ISK data is available" do
      character_id = 999_999_997

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)
      isk_efficiency = Ash.load!(stats, :isk_efficiency, domain: EveDmv.Api).isk_efficiency

      assert isk_efficiency == 0.0
    end
  end

  describe "net_isk calculation" do
    test "calculates net ISK as destroyed minus lost" do
      character_id = 999_999_996

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)
      net_isk = Ash.load!(stats, :net_isk, domain: EveDmv.Api).net_isk

      # With default values (both 0), net should be 0
      assert Decimal.compare(net_isk, Decimal.new("0")) == :eq
    end
  end

  describe "default attribute values" do
    test "has correct default values" do
      character_id = 999_999_995

      {:ok, stats} = CharacterStats.calculate_for_character(character_id, nil)

      assert stats.kills == 0
      assert stats.deaths == 0
      assert Decimal.compare(stats.isk_destroyed, Decimal.new("0")) == :eq
      assert Decimal.compare(stats.isk_lost, Decimal.new("0")) == :eq
    end
  end

  describe "parallel execution" do
    test "handles multiple concurrent requests" do
      character_ids = for _ <- 1..5, do: Enum.random(90_000_000..99_999_999)

      tasks =
        Enum.map(character_ids, fn char_id ->
          Task.async(fn ->
            CharacterStats.calculate_for_character(char_id, nil)
          end)
        end)

      results = Task.await_many(tasks, 5000)

      assert length(results) == 5
      assert Enum.all?(results, &match?({:ok, _}, &1))
    end
  end
end
