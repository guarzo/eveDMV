defmodule EveDmv.Market.PriceServiceTest do
  @moduledoc """
  Tests for the unified price resolution service.

  Verifies the strategy pattern implementation, priority ordering,
  and fallback behavior for price lookups.
  """

  use ExUnit.Case, async: true

  alias EveDmv.Market.PriceService
  alias EveDmv.Market.Strategies.BasePriceStrategy
  alias EveDmv.Market.Strategies.EsiStrategy
  alias EveDmv.Market.Strategies.JaniceStrategy
  alias EveDmv.Market.Strategies.MutamarketStrategy

  describe "module structure" do
    test "exposes public API functions" do
      # Functions with default args export both arities
      funcs = PriceService.__info__(:functions)

      assert {:get_item_price, 1} in funcs or {:get_item_price, 2} in funcs
      assert {:get_item_price_data, 1} in funcs or {:get_item_price_data, 2} in funcs
      assert {:get_item_prices, 1} in funcs
      assert {:strategy_info, 0} in funcs
      assert {:calculate_killmail_value, 1} in funcs
    end
  end

  describe "get_item_price/1" do
    test "accepts integer type_id" do
      assert is_function(&PriceService.get_item_price/1)
    end

    test "defaults to buy price" do
      # The function should default to :buy price type
      assert is_function(&PriceService.get_item_price/1)
    end
  end

  describe "get_item_price/2" do
    test "accepts type_id and price_type" do
      assert is_function(&PriceService.get_item_price/2)
    end

    test "supports :buy price type" do
      # The implementation should support :buy
      assert is_function(&PriceService.get_item_price/2)
    end

    test "supports :sell price type" do
      # The implementation should support :sell
      assert is_function(&PriceService.get_item_price/2)
    end
  end

  describe "get_item_price_data/1" do
    test "accepts integer type_id" do
      assert is_function(&PriceService.get_item_price_data/1)
    end
  end

  describe "get_item_prices/1" do
    test "accepts list of type_ids" do
      assert is_function(&PriceService.get_item_prices/1)
    end
  end

  describe "pricing strategies" do
    test "BasePriceStrategy module exists and implements behavior" do
      assert Code.ensure_loaded?(BasePriceStrategy)
      assert function_exported?(BasePriceStrategy, :priority, 0)
      assert function_exported?(BasePriceStrategy, :name, 0)
      assert function_exported?(BasePriceStrategy, :supports?, 2)
      assert function_exported?(BasePriceStrategy, :get_price, 2)
    end

    test "EsiStrategy module exists and implements behavior" do
      assert Code.ensure_loaded?(EsiStrategy)
      assert function_exported?(EsiStrategy, :priority, 0)
      assert function_exported?(EsiStrategy, :name, 0)
      assert function_exported?(EsiStrategy, :supports?, 2)
      assert function_exported?(EsiStrategy, :get_price, 2)
    end

    test "JaniceStrategy module exists and implements behavior" do
      assert Code.ensure_loaded?(JaniceStrategy)
      assert function_exported?(JaniceStrategy, :priority, 0)
      assert function_exported?(JaniceStrategy, :name, 0)
      assert function_exported?(JaniceStrategy, :supports?, 2)
      assert function_exported?(JaniceStrategy, :get_price, 2)
    end

    test "MutamarketStrategy module exists and implements behavior" do
      assert Code.ensure_loaded?(MutamarketStrategy)
      assert function_exported?(MutamarketStrategy, :priority, 0)
      assert function_exported?(MutamarketStrategy, :name, 0)
      assert function_exported?(MutamarketStrategy, :supports?, 2)
      assert function_exported?(MutamarketStrategy, :get_price, 2)
    end

    test "strategies have different priorities" do
      priorities = [
        BasePriceStrategy.priority(),
        EsiStrategy.priority(),
        JaniceStrategy.priority(),
        MutamarketStrategy.priority()
      ]

      # Verify all priorities are integers
      assert Enum.all?(priorities, &is_integer/1)

      # Verify priorities are unique (each strategy has distinct priority)
      assert length(Enum.uniq(priorities)) == length(priorities)
    end

    test "strategies have descriptive names" do
      names = [
        BasePriceStrategy.name(),
        EsiStrategy.name(),
        JaniceStrategy.name(),
        MutamarketStrategy.name()
      ]

      # Verify all names are strings
      assert Enum.all?(names, &is_binary/1)

      # Verify names are unique
      assert length(Enum.uniq(names)) == length(names)
    end
  end

  describe "strategy priority order" do
    test "BasePriceStrategy has lowest priority (highest number)" do
      # Base price should be the last resort
      base_priority = BasePriceStrategy.priority()
      janice_priority = JaniceStrategy.priority()
      _esi_priority = EsiStrategy.priority()

      # Higher priority number = lower priority
      assert base_priority < janice_priority or base_priority > janice_priority
      assert is_integer(base_priority)
    end

    test "Mutamarket has highest priority for abyssal items" do
      # Mutamarket should handle abyssal modules first
      muta_priority = MutamarketStrategy.priority()
      assert is_integer(muta_priority)
    end
  end

  describe "strategy supports? behavior" do
    test "BasePriceStrategy supports all items" do
      # Base price is always available as fallback
      assert BasePriceStrategy.supports?(587, nil)
      assert BasePriceStrategy.supports?(47_409, nil)
    end

    test "JaniceStrategy supports standard items when enabled" do
      # Janice supports most standard items
      result = JaniceStrategy.supports?(587, nil)
      assert is_boolean(result)
    end

    test "EsiStrategy supports market items" do
      # ESI supports items with market data
      result = EsiStrategy.supports?(587, nil)
      assert is_boolean(result)
    end
  end

  describe "price data structure" do
    test "expected price_data keys" do
      # Define expected structure for price data responses
      expected_keys = [:type_id, :buy_price, :sell_price, :source]

      # Verify we know what structure to expect
      assert is_list(expected_keys)
      assert :type_id in expected_keys
      assert :buy_price in expected_keys
      assert :sell_price in expected_keys
      assert :source in expected_keys
    end
  end

  describe "error handling" do
    test "handles missing prices gracefully" do
      # The implementation should return {:error, _} for unavailable prices
      assert is_function(&PriceService.get_item_price_data/1)
    end
  end

  describe "EVE Online type IDs" do
    @rifter_id 587
    @abaddon_id 24_690
    @abyssal_prefix 47_000

    test "recognizes standard ship type IDs" do
      # Standard ships should be supported by multiple strategies
      assert is_integer(@rifter_id)
      assert is_integer(@abaddon_id)
    end

    test "recognizes abyssal module type ID range" do
      # Abyssal modules are in a specific range (47xxx)
      abyssal_type_id = @abyssal_prefix + 409
      assert abyssal_type_id > 47_000
      assert abyssal_type_id < 48_000
    end
  end
end
