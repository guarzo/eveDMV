defmodule EveDmv.Contexts.KillmailProcessing.ApiTest do
  @moduledoc """
  Tests for the Killmail Processing API module.

  Tests validation logic and error handling paths.
  Note: Some API functions reference KillmailEnriched which is not a registered
  resource, so we focus on testing input validation and error paths.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.KillmailProcessing.Api
  alias EveDmv.SharedKernel.ValueObjects.TimeRange

  # Helper to build valid raw killmail data
  defp valid_killmail_data(overrides \\ %{}) do
    Map.merge(
      %{
        killmail_id: System.unique_integer([:positive]),
        killmail_time: DateTime.utc_now(),
        solar_system_id: 30_000_142,
        victim: %{
          character_id: character_id(),
          corporation_id: corporation_id(),
          ship_type_id: 587,
          damage_taken: 1000
        },
        attackers: [
          %{
            character_id: character_id(),
            corporation_id: corporation_id(),
            ship_type_id: 588,
            damage_done: 1000,
            final_blow: true
          }
        ]
      },
      overrides
    )
  end

  describe "ingest_killmail/1 validation" do
    test "rejects killmail without killmail_id" do
      raw_killmail =
        valid_killmail_data()
        |> Map.delete(:killmail_id)

      result = Api.ingest_killmail(raw_killmail)

      assert {:error, {:missing_field, :killmail_id}} = result
    end

    test "rejects killmail without killmail_time" do
      raw_killmail =
        valid_killmail_data()
        |> Map.delete(:killmail_time)

      result = Api.ingest_killmail(raw_killmail)

      assert {:error, {:missing_field, :killmail_time}} = result
    end

    test "rejects killmail without victim" do
      raw_killmail =
        valid_killmail_data()
        |> Map.delete(:victim)

      result = Api.ingest_killmail(raw_killmail)

      assert {:error, {:missing_field, :victim}} = result
    end

    test "rejects killmail without attackers" do
      raw_killmail =
        valid_killmail_data()
        |> Map.delete(:attackers)

      result = Api.ingest_killmail(raw_killmail)

      assert {:error, {:missing_field, :attackers}} = result
    end

    test "rejects non-map killmail" do
      result = Api.ingest_killmail("invalid")

      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects list as killmail" do
      result = Api.ingest_killmail([1, 2, 3])

      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects nil as killmail" do
      result = Api.ingest_killmail(nil)

      assert {:error, :invalid_killmail_format} = result
    end
  end

  describe "get_killmail_by_id/1 validation" do
    test "rejects non-positive killmail_id" do
      result = Api.get_killmail_by_id(0)

      assert {:error, :invalid_killmail_id} = result
    end

    test "rejects negative killmail_id" do
      result = Api.get_killmail_by_id(-1)

      assert {:error, :invalid_killmail_id} = result
    end

    test "rejects non-integer killmail_id" do
      result = Api.get_killmail_by_id("abc123")

      assert {:error, :invalid_killmail_id} = result
    end

    test "rejects nil killmail_id" do
      result = Api.get_killmail_by_id(nil)

      assert {:error, :invalid_killmail_id} = result
    end

    test "rejects float killmail_id" do
      result = Api.get_killmail_by_id(123.45)

      assert {:error, :invalid_killmail_id} = result
    end
  end

  describe "option validation" do
    test "rejects invalid limit (zero)" do
      result = Api.get_recent_killmails(limit: 0)

      assert {:error, :invalid_limit} = result
    end

    test "rejects invalid limit (negative)" do
      result = Api.get_recent_killmails(limit: -1)

      assert {:error, :invalid_limit} = result
    end

    test "rejects limit exceeding maximum (500)" do
      result = Api.get_recent_killmails(limit: 501)

      assert {:error, :invalid_limit} = result
    end

    test "rejects negative offset" do
      result = Api.get_recent_killmails(offset: -1)

      assert {:error, :invalid_offset} = result
    end

    test "rejects non-list options" do
      result = Api.get_recent_killmails("invalid")

      assert {:error, :invalid_options_format} = result
    end

    test "rejects inverted min/max value range" do
      result = Api.get_recent_killmails(min_value: 1000, max_value: 100)

      assert {:error, :invalid_value_range} = result
    end

    test "rejects negative min_value" do
      result = Api.get_recent_killmails(min_value: -100)

      assert {:error, :invalid_value_range} = result
    end

    test "rejects invalid time_range" do
      result = Api.get_recent_killmails(time_range: "last week")

      assert {:error, :invalid_time_range} = result
    end
  end

  describe "fetch_historical_killmails/2 validation" do
    test "accepts empty character list (starts with 0 characters)" do
      result = Api.fetch_historical_killmails([])

      # The API accepts an empty list and returns a task
      assert {:ok, %{character_count: 0}} = result
    end

    test "rejects non-list input" do
      result = Api.fetch_historical_killmails(123)

      assert {:error, :invalid_character_ids_format} = result
    end

    test "rejects list with invalid character IDs (negative)" do
      result = Api.fetch_historical_killmails([123, -1, 456])

      assert {:error, :invalid_character_ids} = result
    end

    test "rejects list with non-integer values" do
      result = Api.fetch_historical_killmails([123, "456", 789])

      assert {:error, :invalid_character_ids} = result
    end

    test "rejects list with zero" do
      result = Api.fetch_historical_killmails([0, 123, 456])

      assert {:error, :invalid_character_ids} = result
    end

    test "rejects list with nil" do
      result = Api.fetch_historical_killmails([nil, 123, 456])

      assert {:error, :invalid_character_ids} = result
    end
  end

  describe "get_system_statistics/2 validation" do
    test "rejects invalid system_id (negative)" do
      time_range = TimeRange.last_days(7)

      result = Api.get_system_statistics(-1, time_range)

      assert {:error, _reason} = result
    end

    test "rejects invalid system_id (zero)" do
      time_range = TimeRange.last_days(7)

      result = Api.get_system_statistics(0, time_range)

      assert {:error, _reason} = result
    end
  end

  # Note: get_pipeline_metrics/0 requires KillmailOrchestrator GenServer to be running,
  # which is not available in the test environment. The function export is verified
  # in the "API module exports" tests.

  describe "API module exports" do
    setup do
      # Ensure the module is loaded before testing exports
      Code.ensure_loaded!(Api)
      :ok
    end

    test "exports ingest_killmail/1" do
      assert function_exported?(Api, :ingest_killmail, 1)
    end

    test "exports get_recent_killmails/0 and /1" do
      assert function_exported?(Api, :get_recent_killmails, 0) or
               function_exported?(Api, :get_recent_killmails, 1)
    end

    test "exports get_killmail_by_id/1" do
      assert function_exported?(Api, :get_killmail_by_id, 1)
    end

    test "exports get_killmails_by_system/1 and /2" do
      assert function_exported?(Api, :get_killmails_by_system, 1) or
               function_exported?(Api, :get_killmails_by_system, 2)
    end

    test "exports get_killmails_by_character/1 and /2" do
      assert function_exported?(Api, :get_killmails_by_character, 1) or
               function_exported?(Api, :get_killmails_by_character, 2)
    end

    test "exports get_high_value_killmails/0 and /1" do
      assert function_exported?(Api, :get_high_value_killmails, 0) or
               function_exported?(Api, :get_high_value_killmails, 1)
    end

    test "exports fetch_historical_killmails/1 and /2" do
      assert function_exported?(Api, :fetch_historical_killmails, 1) or
               function_exported?(Api, :fetch_historical_killmails, 2)
    end

    test "exports get_system_statistics/2" do
      assert function_exported?(Api, :get_system_statistics, 2)
    end

    test "exports get_pipeline_metrics/0" do
      assert function_exported?(Api, :get_pipeline_metrics, 0)
    end

    test "exports get_display_data/0 and /1" do
      assert function_exported?(Api, :get_display_data, 0) or
               function_exported?(Api, :get_display_data, 1)
    end
  end
end
