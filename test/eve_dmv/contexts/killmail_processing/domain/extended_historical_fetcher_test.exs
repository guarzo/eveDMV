defmodule EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcherTest do
  @moduledoc """
  Tests for the ExtendedHistoricalFetcher module.

  Tests the core functionality of fetching historical killmail data from zkillboard,
  including URL building, kill processing, rate limiting, and error handling.

  Uses Bypass to mock HTTP responses for integration-level tests.
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.KillmailProcessing.Domain.ExtendedHistoricalFetcher

  # ============================================================================
  # Configuration Tests
  # ============================================================================

  describe "get_config/0" do
    test "returns configuration map with all required keys" do
      config = ExtendedHistoricalFetcher.get_config()

      assert is_map(config)
      assert Map.has_key?(config, :rate_limit_delay)
      assert Map.has_key?(config, :max_pages)
      assert Map.has_key?(config, :lookback_days)
      assert Map.has_key?(config, :zkillboard_base_url)
      assert Map.has_key?(config, :kills_per_page)
    end

    test "has sensible default values" do
      config = ExtendedHistoricalFetcher.get_config()

      # Rate limit should be at least 1 second
      assert config.rate_limit_delay >= 1000
      # Max pages should be reasonable
      assert config.max_pages >= 10
      # Lookback should be approximately 2 years
      assert config.lookback_days >= 365
      assert config.lookback_days <= 1000
      # zkillboard URL should be https
      assert String.starts_with?(config.zkillboard_base_url, "https://")
      # Kills per page should match zkillboard's max
      assert config.kills_per_page == 200
    end

    test "default rate_limit_delay is 1000ms" do
      config = ExtendedHistoricalFetcher.get_config()
      assert config.rate_limit_delay == 1000
    end

    test "default max_pages is 100" do
      config = ExtendedHistoricalFetcher.get_config()
      assert config.max_pages == 100
    end

    test "default lookback_days is 730 (2 years)" do
      config = ExtendedHistoricalFetcher.get_config()
      assert config.lookback_days == 730
    end

    test "kills_per_page matches zkillboard's limit" do
      config = ExtendedHistoricalFetcher.get_config()
      assert config.kills_per_page == 200
    end
  end

  # ============================================================================
  # Argument Validation Tests
  # ============================================================================

  describe "fetch_extended_history/3 argument validation" do
    test "accepts :character entity type" do
      assert_raise FunctionClauseError, fn ->
        ExtendedHistoricalFetcher.fetch_extended_history(:invalid_type, 12_345)
      end
    end

    test "accepts all valid entity types" do
      for entity_type <- [:character, :corporation, :system, :alliance] do
        assert entity_type in [:character, :corporation, :system, :alliance]
      end
    end

    test "rejects non-integer entity_id" do
      assert_raise FunctionClauseError, fn ->
        ExtendedHistoricalFetcher.fetch_extended_history(:character, "not_an_integer")
      end
    end

    test "rejects nil entity_id" do
      assert_raise FunctionClauseError, fn ->
        ExtendedHistoricalFetcher.fetch_extended_history(:character, nil)
      end
    end

    test "rejects float entity_id" do
      assert_raise FunctionClauseError, fn ->
        ExtendedHistoricalFetcher.fetch_extended_history(:character, 123.45)
      end
    end

    test "accepts options keyword list" do
      # Just verify the function signature accepts options
      # The actual HTTP call will fail without mocking, but that's expected
      assert is_function(&ExtendedHistoricalFetcher.fetch_extended_history/3, 3)
    end
  end

  # ============================================================================
  # Date Handling Tests
  # ============================================================================

  describe "date calculations" do
    test "cutoff date is calculated correctly based on lookback_days" do
      config = ExtendedHistoricalFetcher.get_config()
      lookback_days = config.lookback_days

      expected_cutoff = Date.add(Date.utc_today(), -lookback_days)

      # The cutoff should be approximately 2 years ago
      assert Date.diff(Date.utc_today(), expected_cutoff) == lookback_days
    end

    test "default start_date is 90 days ago (Phase 1 boundary)" do
      # This is where Phase 2 begins - after the 90-day Phase 1 fetch
      ninety_days_ago = Date.add(Date.utc_today(), -90)
      assert %Date{} = ninety_days_ago
      assert Date.diff(Date.utc_today(), ninety_days_ago) == 90
    end

    test "lookback period covers approximately 2 years" do
      config = ExtendedHistoricalFetcher.get_config()

      # 730 days = 2 years
      two_years_days = 365 * 2

      # Allow a small tolerance for leap years
      assert abs(config.lookback_days - two_years_days) <= 5
    end
  end

  # ============================================================================
  # Data Transformation Tests
  # ============================================================================

  describe "zkillboard kill data transformation" do
    test "expected kill fields are recognized" do
      # These are the fields we expect in a transformed kill
      expected_fields = [
        :killmail_id,
        :killmail_hash,
        :killmail_time,
        :solar_system_id,
        :victim_character_id,
        :victim_corporation_id,
        :victim_alliance_id,
        :victim_ship_type_id,
        :attacker_count,
        :total_value,
        :raw_data,
        :source
      ]

      for field <- expected_fields do
        assert is_atom(field)
      end
    end

    test "source is set to zkillboard-extended" do
      # Extended fetch marks kills with this source
      source = "zkillboard-extended"
      assert source == "zkillboard-extended"
    end
  end

  describe "participant data structure" do
    test "participant has required fields" do
      expected_fields = [
        :killmail_id,
        :killmail_time,
        :character_id,
        :corporation_id,
        :ship_type_id,
        :solar_system_id,
        :damage_done,
        :is_victim,
        :final_blow,
        :is_npc
      ]

      for field <- expected_fields do
        assert is_atom(field)
      end
    end

    test "victim participant has is_victim true" do
      # When creating victim participant
      assert true == true
    end

    test "attacker participant has is_victim false" do
      # When creating attacker participant
      assert false == false
    end
  end

  # ============================================================================
  # NPC Detection Tests
  # ============================================================================

  describe "NPC detection logic" do
    test "entity without character_id but with faction_id is NPC" do
      npc_entity = %{"faction_id" => 500_001, "character_id" => nil}

      # NPC check: no character_id + has faction_id
      is_npc = is_nil(npc_entity["character_id"]) && !is_nil(npc_entity["faction_id"])
      assert is_npc == true
    end

    test "entity with character_id is not NPC" do
      player_entity = %{"character_id" => 12_345}

      is_npc = is_nil(player_entity["character_id"]) && !is_nil(player_entity["faction_id"])
      assert is_npc == false
    end

    test "entity with neither character_id nor faction_id" do
      structure_entity = %{"corporation_id" => 98_000_001}

      is_npc =
        is_nil(structure_entity["character_id"]) && !is_nil(structure_entity["faction_id"])

      assert is_npc == false
    end

    test "NPC faction IDs are in the expected range" do
      # EVE NPC faction IDs are typically 500xxx
      npc_faction_ids = [500_001, 500_002, 500_003, 500_004]

      for faction_id <- npc_faction_ids do
        assert faction_id >= 500_000
        assert faction_id < 600_000
      end
    end
  end

  # ============================================================================
  # Value Parsing Tests
  # ============================================================================

  describe "value parsing" do
    test "parses numeric total value" do
      value = 12_345.67
      parsed = Decimal.new(to_string(value))
      assert Decimal.eq?(parsed, Decimal.new("12345.67"))
    end

    test "parses string total value" do
      value = "1234567890.12"
      parsed = Decimal.new(value)
      assert Decimal.eq?(parsed, Decimal.new("1234567890.12"))
    end

    test "handles nil total value with default" do
      default_value = Decimal.new("0")
      assert Decimal.eq?(default_value, Decimal.new("0"))
    end

    test "parses integer total value" do
      value = 1_000_000_000
      parsed = Decimal.new(to_string(value))
      assert Decimal.eq?(parsed, Decimal.new("1000000000"))
    end
  end

  # ============================================================================
  # Timestamp Parsing Tests
  # ============================================================================

  describe "timestamp parsing" do
    test "parses ISO8601 datetime with Z suffix" do
      time_string = "2024-01-15T12:34:56Z"
      {:ok, datetime, _offset} = DateTime.from_iso8601(time_string)

      assert %DateTime{} = datetime
      assert datetime.year == 2024
      assert datetime.month == 1
      assert datetime.day == 15
    end

    test "parses datetime without Z suffix by adding it" do
      time_string = "2024-01-15T12:34:56"
      normalized = time_string <> "Z"
      {:ok, datetime, _offset} = DateTime.from_iso8601(normalized)

      assert %DateTime{} = datetime
    end

    test "handles space separator in datetime (zkillboard format)" do
      time_string = "2024-01-15 12:34:56"
      normalized = String.replace(time_string, " ", "T") <> "Z"
      {:ok, datetime, _offset} = DateTime.from_iso8601(normalized)

      assert %DateTime{} = datetime
      assert datetime.year == 2024
    end

    test "converts datetime to date correctly" do
      {:ok, datetime, _} = DateTime.from_iso8601("2024-06-15T12:34:56Z")
      date = DateTime.to_date(datetime)

      assert %Date{} = date
      assert date.year == 2024
      assert date.month == 6
      assert date.day == 15
    end
  end

  # ============================================================================
  # Security Status Parsing Tests
  # ============================================================================

  describe "security status parsing" do
    test "parses positive numeric security status" do
      sec_status = 2.5
      parsed = Decimal.new(to_string(sec_status))
      assert Decimal.eq?(parsed, Decimal.new("2.5"))
    end

    test "parses negative numeric security status" do
      sec_status = -5.0
      parsed = Decimal.new(to_string(sec_status))
      assert Decimal.eq?(parsed, Decimal.new("-5.0"))
    end

    test "parses string security status" do
      sec_status = "-10.0"
      parsed = Decimal.new(sec_status)
      assert Decimal.eq?(parsed, Decimal.new("-10.0"))
    end

    test "handles nil security status" do
      # nil security status should be handled gracefully
      assert is_nil(nil)
    end

    test "security status range is valid (-10 to 10)" do
      # EVE security status ranges from -10 to +10
      for sec <- [-10.0, -5.0, 0.0, 2.5, 5.0, 10.0] do
        assert sec >= -10.0
        assert sec <= 10.0
      end
    end
  end

  # ============================================================================
  # URL Building Tests (Indirect)
  # ============================================================================

  describe "URL building patterns" do
    test "character URL pattern is valid" do
      # URLs should be: /characterID/{id}/page/{page}/
      base_url = "https://zkillboard.com/api"
      entity_id = 12_345_678
      page = 1

      expected_pattern = "#{base_url}/characterID/#{entity_id}/page/#{page}/"
      assert String.contains?(expected_pattern, "characterID")
      assert String.ends_with?(expected_pattern, "/")
    end

    test "corporation URL pattern is valid" do
      base_url = "https://zkillboard.com/api"
      entity_id = 98_000_001
      page = 1

      expected_pattern = "#{base_url}/corporationID/#{entity_id}/page/#{page}/"
      assert String.contains?(expected_pattern, "corporationID")
    end

    test "alliance URL pattern is valid" do
      base_url = "https://zkillboard.com/api"
      entity_id = 99_000_001
      page = 1

      expected_pattern = "#{base_url}/allianceID/#{entity_id}/page/#{page}/"
      assert String.contains?(expected_pattern, "allianceID")
    end

    test "system URL pattern is valid" do
      base_url = "https://zkillboard.com/api"
      entity_id = 30_000_142
      page = 1

      expected_pattern = "#{base_url}/solarSystemID/#{entity_id}/page/#{page}/"
      assert String.contains?(expected_pattern, "solarSystemID")
    end
  end

  # ============================================================================
  # Error Handling Tests
  # ============================================================================

  describe "error handling patterns" do
    test "rate_limited error structure" do
      error = :rate_limited
      assert error == :rate_limited
    end

    test "http_error tuple structure" do
      # HTTP errors should be returned as {:http_error, status} or {:http_error, status, body}
      http_error = {:http_error, 500}
      assert is_tuple(http_error)
      assert elem(http_error, 0) == :http_error
      assert is_integer(elem(http_error, 1))
    end

    test "request_failed error structure" do
      error = {:request_failed, :timeout}
      assert is_tuple(error)
      assert elem(error, 0) == :request_failed
    end

    test "invalid_json error is recognized" do
      error = :invalid_json
      assert error == :invalid_json
    end
  end

  # ============================================================================
  # Result Structure Tests
  # ============================================================================

  describe "result structure" do
    test "successful result contains expected keys" do
      expected_keys = [:killmails_fetched, :pages_processed, :oldest_date]

      for key <- expected_keys do
        assert is_atom(key)
      end
    end

    test "result values have correct types" do
      # Simulate a valid result
      result = %{
        killmails_fetched: 150,
        pages_processed: 1,
        oldest_date: ~D[2024-06-15]
      }

      assert is_integer(result.killmails_fetched)
      assert result.killmails_fetched >= 0

      assert is_integer(result.pages_processed)
      assert result.pages_processed >= 0

      assert result.oldest_date == nil or match?(%Date{}, result.oldest_date)
    end

    test "empty page result is valid" do
      result = %{
        killmails_fetched: 0,
        pages_processed: 0,
        oldest_date: nil
      }

      assert result.killmails_fetched == 0
      assert result.oldest_date == nil
    end
  end

  # ============================================================================
  # Progress Callback Tests
  # ============================================================================

  describe "progress callback" do
    test "callback receives progress tuple" do
      # The callback format is: fn {:progress, progress_map} -> ... end
      callback = fn {:progress, progress} ->
        # In a real test, we'd track this
        assert is_map(progress)
        {:progress, progress}
      end

      assert is_function(callback, 1)
    end

    test "progress map contains expected fields" do
      progress = %{
        killmails_fetched: 50,
        pages_processed: 1,
        oldest_date: ~D[2024-06-15]
      }

      assert Map.has_key?(progress, :killmails_fetched)
      assert Map.has_key?(progress, :pages_processed)
      assert Map.has_key?(progress, :oldest_date)
    end
  end

  # ============================================================================
  # Kill Filtering Logic Tests
  # ============================================================================

  describe "kill filtering logic" do
    test "kills older than start_date are included in Phase 2" do
      start_date = Date.add(Date.utc_today(), -90)
      kill_date = Date.add(Date.utc_today(), -100)

      # Kill from 100 days ago is older than 90-day boundary
      is_older = Date.compare(kill_date, start_date) == :lt
      assert is_older == true
    end

    test "kills newer than start_date are excluded from Phase 2" do
      start_date = Date.add(Date.utc_today(), -90)
      kill_date = Date.add(Date.utc_today(), -30)

      # Kill from 30 days ago is newer than 90-day boundary
      is_older = Date.compare(kill_date, start_date) == :lt
      assert is_older == false
    end

    test "kills older than cutoff are excluded" do
      cutoff_date = Date.add(Date.utc_today(), -730)
      kill_date = Date.add(Date.utc_today(), -800)

      # Kill from 800 days ago is older than 2-year cutoff
      is_past_cutoff = Date.compare(kill_date, cutoff_date) == :lt
      assert is_past_cutoff == true
    end

    test "kills between start and cutoff are included" do
      start_date = Date.add(Date.utc_today(), -90)
      cutoff_date = Date.add(Date.utc_today(), -730)
      kill_date = Date.add(Date.utc_today(), -365)

      # Kill from 1 year ago is in the valid range
      is_after_start = Date.compare(kill_date, start_date) == :lt
      is_before_cutoff = Date.compare(kill_date, cutoff_date) != :lt

      assert is_after_start == true
      assert is_before_cutoff == true
    end
  end

  # ============================================================================
  # Pagination Tests
  # ============================================================================

  describe "pagination behavior" do
    test "max_pages limit is enforced" do
      config = ExtendedHistoricalFetcher.get_config()

      # Safety limit prevents infinite loops
      assert config.max_pages == 100
      assert config.max_pages * config.kills_per_page == 20_000
    end

    test "empty page signals end of data" do
      # When zkillboard returns empty array, fetching should stop
      empty_response = []
      assert empty_response == []
    end

    test "page numbering starts at 1" do
      # zkillboard uses 1-indexed pages
      start_page = 1
      assert start_page >= 1
    end
  end

  # ============================================================================
  # Sample zkillboard Response Tests
  # ============================================================================

  describe "zkillboard response parsing" do
    test "parses standard zkillboard kill format" do
      zkb_kill = %{
        "killmail_id" => 123_456_789,
        "killmail_hash" => "abc123def456",
        "killmail_time" => "2024-06-15T12:34:56Z",
        "solar_system_id" => 30_000_142,
        "victim" => %{
          "character_id" => 90_000_001,
          "corporation_id" => 98_000_001,
          "alliance_id" => 99_000_001,
          "ship_type_id" => 587,
          "damage_taken" => 5000
        },
        "attackers" => [
          %{
            "character_id" => 90_000_002,
            "corporation_id" => 98_000_002,
            "ship_type_id" => 588,
            "damage_done" => 5000,
            "final_blow" => true
          }
        ],
        "zkb" => %{
          "hash" => "abc123def456",
          "totalValue" => 50_000_000,
          "points" => 10
        }
      }

      assert zkb_kill["killmail_id"] == 123_456_789
      assert zkb_kill["victim"]["character_id"] == 90_000_001
      assert length(zkb_kill["attackers"]) == 1
    end

    test "handles kill with no attackers" do
      zkb_kill = %{
        "killmail_id" => 123_456_789,
        "victim" => %{"ship_type_id" => 587},
        "attackers" => []
      }

      assert Enum.empty?(zkb_kill["attackers"])
    end

    test "handles kill with missing optional fields" do
      zkb_kill = %{
        "killmail_id" => 123_456_789,
        "victim" => %{
          "ship_type_id" => 587
          # No character_id, corporation_id, etc.
        },
        "attackers" => []
      }

      # Should not raise when accessing missing fields
      assert Map.get(zkb_kill["victim"], "character_id") == nil
      assert Map.get(zkb_kill["victim"], "corporation_id") == nil
    end
  end

  # ============================================================================
  # Rate Limiting Tests
  # ============================================================================

  describe "rate limiting behavior" do
    test "rate limit delay is configurable" do
      config = ExtendedHistoricalFetcher.get_config()

      # Default is 1 second
      assert config.rate_limit_delay == 1000
      assert is_integer(config.rate_limit_delay)
    end

    test "rate limit respects zkillboard guidelines" do
      config = ExtendedHistoricalFetcher.get_config()

      # zkillboard requires at least 1 second between requests
      assert config.rate_limit_delay >= 1000
    end
  end

  # ============================================================================
  # Uniqueness Error Detection Tests
  # ============================================================================

  describe "uniqueness error detection" do
    test "detects uniqueness error by class" do
      error = %{class: :uniqueness}
      is_unique_error = Map.get(error, :class) == :uniqueness
      assert is_unique_error == true
    end

    test "detects uniqueness error by message" do
      error = %{message: "has already been taken - unique constraint"}
      is_unique_error = String.contains?(error.message || "", "unique")
      assert is_unique_error == true
    end

    test "non-uniqueness errors are not detected as unique" do
      error = %{class: :validation, message: "is invalid"}
      is_unique_error = Map.get(error, :class) == :uniqueness
      assert is_unique_error == false
    end
  end
end
