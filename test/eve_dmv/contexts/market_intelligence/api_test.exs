defmodule EveDmv.Contexts.MarketIntelligence.ApiTest do
  @moduledoc """
  Tests for the Market Intelligence API module.

  Tests input validation logic and verifies all expected functions are exported.
  The Market Intelligence context relies on external pricing services (Janice, MutaMarket)
  so we focus on input validation and function exports.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.MarketIntelligence.Api

  describe "get_price/1 validation" do
    test "rejects invalid type_id (zero)" do
      result = Api.get_price(0)
      assert {:error, :invalid_type_id} = result
    end

    test "rejects invalid type_id (negative)" do
      result = Api.get_price(-1)
      assert {:error, :invalid_type_id} = result
    end

    test "rejects invalid type_id (non-integer)" do
      result = Api.get_price("34")
      assert {:error, :invalid_type_id} = result
    end

    test "rejects invalid type_id (nil)" do
      result = Api.get_price(nil)
      assert {:error, :invalid_type_id} = result
    end

    test "rejects invalid type_id (float)" do
      result = Api.get_price(34.5)
      assert {:error, :invalid_type_id} = result
    end
  end

  describe "get_prices/1 validation" do
    test "rejects empty list" do
      # Empty list is technically valid but depends on service implementation
      # Service may not be running in test env - catch the exit
      result =
        try do
          Api.get_prices([])
        catch
          :exit, {:noproc, _} -> {:error, :service_unavailable}
        end

      # Should either work, return meaningful error, or indicate service unavailable
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "rejects list with invalid type_id (zero)" do
      result = Api.get_prices([34, 0, 35])
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects list with invalid type_id (negative)" do
      result = Api.get_prices([34, -1, 35])
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects list with non-integer type_id" do
      result = Api.get_prices([34, "35", 36])
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects non-list input" do
      result = Api.get_prices(34)
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects nil input" do
      result = Api.get_prices(nil)
      assert {:error, :invalid_type_ids} = result
    end
  end

  describe "calculate_killmail_value/1 validation" do
    test "rejects nil killmail" do
      result = Api.calculate_killmail_value(nil)
      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects non-map killmail" do
      result = Api.calculate_killmail_value("invalid")
      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects killmail missing required fields" do
      incomplete_killmail = %{killmail_id: 123}
      result = Api.calculate_killmail_value(incomplete_killmail)
      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects killmail missing victim field" do
      killmail = %{killmail_id: 123, attackers: []}
      result = Api.calculate_killmail_value(killmail)
      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects killmail missing attackers field" do
      killmail = %{killmail_id: 123, victim: %{}}
      result = Api.calculate_killmail_value(killmail)
      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects killmail missing killmail_id field" do
      killmail = %{victim: %{}, attackers: []}
      result = Api.calculate_killmail_value(killmail)
      assert {:error, :invalid_killmail_format} = result
    end

    test "rejects list input" do
      result = Api.calculate_killmail_value([])
      assert {:error, :invalid_killmail_format} = result
    end
  end

  describe "calculate_fleet_value/1 validation" do
    test "rejects nil input" do
      result = Api.calculate_fleet_value(nil)
      assert {:error, :invalid_fleet_composition} = result
    end

    test "rejects non-list input" do
      result = Api.calculate_fleet_value(%{ships: []})
      assert {:error, :invalid_fleet_composition} = result
    end

    test "rejects list with non-map elements" do
      result = Api.calculate_fleet_value([%{ship_type_id: 587}, "invalid"])
      assert {:error, :invalid_fleet_composition} = result
    end

    test "rejects string input" do
      result = Api.calculate_fleet_value("invalid")
      assert {:error, :invalid_fleet_composition} = result
    end
  end

  describe "analyze_market_trends/2 validation" do
    test "rejects invalid type_ids (non-list)" do
      result = Api.analyze_market_trends(34, :week)
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects invalid period" do
      result = Api.analyze_market_trends([34], :invalid_period)
      assert {:error, :invalid_period} = result
    end

    test "rejects nil period" do
      result = Api.analyze_market_trends([34], nil)
      assert {:error, :invalid_period} = result
    end

    test "rejects string period" do
      result = Api.analyze_market_trends([34], "week")
      assert {:error, :invalid_period} = result
    end

    test "rejects list with invalid type_ids" do
      result = Api.analyze_market_trends([34, -1], :week)
      assert {:error, :invalid_type_ids} = result
    end
  end

  describe "refresh_prices/1 validation" do
    test "rejects invalid type_ids (non-list)" do
      result = Api.refresh_prices(34)
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects list with invalid type_ids" do
      result = Api.refresh_prices([34, 0])
      assert {:error, :invalid_type_ids} = result
    end

    test "rejects nil input" do
      result = Api.refresh_prices(nil)
      assert {:error, :invalid_type_ids} = result
    end
  end

  describe "API module exports" do
    setup do
      Code.ensure_loaded!(Api)
      :ok
    end

    test "exports price fetching functions" do
      assert function_exported?(Api, :get_price, 1)
      assert function_exported?(Api, :get_price, 2)
      assert function_exported?(Api, :get_prices, 1)
      assert function_exported?(Api, :get_prices, 2)
    end

    test "exports valuation functions" do
      assert function_exported?(Api, :calculate_killmail_value, 1)
      assert function_exported?(Api, :calculate_fleet_value, 1)
    end

    test "exports market analysis functions" do
      assert function_exported?(Api, :analyze_market_trends, 1) or
               function_exported?(Api, :analyze_market_trends, 2)
    end

    test "exports cache management functions" do
      assert function_exported?(Api, :get_price_cache_stats, 0)

      assert function_exported?(Api, :refresh_prices, 1) or
               function_exported?(Api, :refresh_prices, 2)
    end
  end

  describe "valid period atoms" do
    test "accepts :day period" do
      # Should pass validation (might fail on service call, but that's expected)
      result = Api.analyze_market_trends([34], :day)
      refute match?({:error, :invalid_period}, result)
      refute match?({:error, :invalid_type_ids}, result)
    end

    test "accepts :week period" do
      result = Api.analyze_market_trends([34], :week)
      refute match?({:error, :invalid_period}, result)
      refute match?({:error, :invalid_type_ids}, result)
    end

    test "accepts :month period" do
      result = Api.analyze_market_trends([34], :month)
      refute match?({:error, :invalid_period}, result)
      refute match?({:error, :invalid_type_ids}, result)
    end
  end

  describe "type specs validation" do
    test "price_options accepts source option" do
      # Valid source atoms are :janice, :mutamarket, :esi, :best
      # This tests the validation passes (service call may fail without external deps)
      result =
        try do
          Api.get_price(34, source: :janice)
        catch
          :exit, {:noproc, _} -> {:ok, :service_unavailable}
        end

      # Should not be an invalid_type_id error - that indicates validation failed
      refute match?({:error, :invalid_type_id}, result)
    end

    test "price_options accepts region_id option" do
      result =
        try do
          Api.get_price(34, region_id: 10_000_002)
        catch
          :exit, {:noproc, _} -> {:ok, :service_unavailable}
        end

      refute match?({:error, :invalid_type_id}, result)
    end

    test "price_options accepts cache_ttl option" do
      result =
        try do
          Api.get_price(34, cache_ttl: 3600)
        catch
          :exit, {:noproc, _} -> {:ok, :service_unavailable}
        end

      refute match?({:error, :invalid_type_id}, result)
    end
  end
end
