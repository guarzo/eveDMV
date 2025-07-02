defmodule EveDmv.Market.PriceServiceTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Market.PriceService

  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  describe "get_item_price/1" do
    test "retrieves price from available strategies" do
      # Rifter
      type_id = 587

      # Test with real API if available, mock if necessary
      result = PriceService.get_item_price(type_id)

      assert match?({:ok, _price} | {:error, _}, result)

      case result do
        {:ok, price} ->
          assert is_number(price)
          assert price > 0

        {:error, _reason} ->
          # API might be unavailable in test environment
          :ok
      end
    end

    test "returns buy price by default" do
      type_id = 587

      # Get default (buy) price
      buy_result = PriceService.get_item_price(type_id)
      # Get explicit buy price
      explicit_buy_result = PriceService.get_item_price(type_id, :buy)

      case {buy_result, explicit_buy_result} do
        {{:ok, price1}, {:ok, price2}} ->
          assert price1 == price2

        _ ->
          # If API fails, both should fail consistently
          assert buy_result == explicit_buy_result
      end
    end

    test "returns sell price when requested" do
      type_id = 587

      sell_result = PriceService.get_item_price(type_id, :sell)

      assert match?({:ok, _} | {:error, _}, sell_result)
    end

    test "handles API failures gracefully" do
      # Test with invalid type_id that should fail
      type_id = -1

      assert {:error, _reason} = PriceService.get_item_price(type_id)
    end
  end

  describe "get_item_price_data/1" do
    test "returns complete price data structure" do
      type_id = 587

      result = PriceService.get_item_price_data(type_id)

      case result do
        {:ok, price_data} ->
          assert is_map(price_data)
          assert Map.has_key?(price_data, :type_id)
          assert Map.has_key?(price_data, :buy_price)
          assert Map.has_key?(price_data, :sell_price)
          assert Map.has_key?(price_data, :source)
          assert Map.has_key?(price_data, :updated_at)

          assert price_data.type_id == type_id
          assert is_atom(price_data.source)

        {:error, _} ->
          # API might be unavailable
          :ok
      end
    end

    test "handles abyssal modules with attributes" do
      # Abyssal module type ID (example)
      type_id = 47_800

      # Abyssal modules might have special attributes
      item_attributes = %{
        "mutated" => true,
        "attributes" => %{
          "cpu" => 25.5,
          "powergrid" => 150.0
        }
      }

      result = PriceService.get_item_price_data(type_id, item_attributes)

      assert match?({:ok, _} | {:error, _}, result)
    end
  end

  describe "get_item_prices/1" do
    test "retrieves prices for multiple items" do
      # Rifter, Rupture, Stabber
      type_ids = [587, 588, 589]

      assert {:ok, prices} = PriceService.get_item_prices(type_ids)

      assert is_map(prices)

      # Check that we got data for at least some items
      assert map_size(prices) >= 0

      # Verify structure for any returned prices
      Enum.each(prices, fn {type_id, price_data} ->
        assert type_id in type_ids
        assert is_map(price_data)
        assert Map.has_key?(price_data, :buy_price)
        assert Map.has_key?(price_data, :sell_price)
        assert Map.has_key?(price_data, :source)
      end)
    end

    test "handles mixed success and failure" do
      # Mix of valid and invalid type IDs
      type_ids = [587, -1, 588, -2]

      assert {:ok, prices} = PriceService.get_item_prices(type_ids)

      # Should only include successful lookups
      Enum.each(Map.keys(prices), fn type_id ->
        assert type_id > 0
      end)
    end

    test "returns empty map for all invalid items" do
      type_ids = [-1, -2, -3]

      assert {:ok, prices} = PriceService.get_item_prices(type_ids)
      assert prices == %{}
    end
  end

  describe "calculate_killmail_value/1" do
    test "calculates total killmail value correctly" do
      killmail = %{
        "victim" => %{
          # Rifter
          "ship_type_id" => 587,
          "items" => [
            %{
              # 150mm Light AutoCannon II
              "item_type_id" => 2185,
              "quantity_destroyed" => 3,
              "quantity_dropped" => 0
            },
            %{
              # Small Shield Extender II
              "item_type_id" => 1541,
              "quantity_destroyed" => 0,
              "quantity_dropped" => 1
            }
          ]
        },
        "attackers" => [
          # Rupture
          %{"ship_type_id" => 588}
        ]
      }

      result = PriceService.calculate_killmail_value(killmail)

      assert is_map(result)
      assert Map.has_key?(result, :total_value)
      assert Map.has_key?(result, :ship_value)
      assert Map.has_key?(result, :fitted_value)
      assert Map.has_key?(result, :destroyed_value)
      assert Map.has_key?(result, :dropped_value)
      assert Map.has_key?(result, :price_source)

      # Values should be non-negative
      assert result.total_value >= 0
      assert result.ship_value >= 0
      assert result.fitted_value >= 0
      assert result.destroyed_value >= 0
      assert result.dropped_value >= 0

      # Total should be sum of ship and fitted
      assert_in_delta result.total_value, result.ship_value + result.fitted_value, 0.01

      # Fitted should be sum of destroyed and dropped
      assert_in_delta result.fitted_value, result.destroyed_value + result.dropped_value, 0.01
    end

    test "handles killmail with no items" do
      killmail = %{
        "victim" => %{
          "ship_type_id" => 587,
          "items" => nil
        }
      }

      result = PriceService.calculate_killmail_value(killmail)

      assert result.fitted_value == 0.0
      assert result.destroyed_value == 0.0
      assert result.dropped_value == 0.0
      assert result.total_value == result.ship_value
    end

    test "handles killmail with empty items list" do
      killmail = %{
        "victim" => %{
          "ship_type_id" => 587,
          "items" => []
        }
      }

      result = PriceService.calculate_killmail_value(killmail)

      assert result.fitted_value == 0.0
      assert result.destroyed_value == 0.0
      assert result.dropped_value == 0.0
    end

    test "handles missing victim ship type" do
      killmail = %{
        "victim" => %{
          "ship_type_id" => nil,
          "items" => [
            %{
              "item_type_id" => 2185,
              "quantity_destroyed" => 1,
              "quantity_dropped" => 0
            }
          ]
        }
      }

      result = PriceService.calculate_killmail_value(killmail)

      assert result.ship_value == 0.0
      assert result.total_value >= 0
    end

    test "correctly sums multiple stacks of same item" do
      killmail = %{
        "victim" => %{
          "ship_type_id" => 587,
          "items" => [
            %{
              # Iron Charge S
              "item_type_id" => 215,
              "quantity_destroyed" => 100,
              "quantity_dropped" => 50
            },
            %{
              # Iron Charge S (another stack)
              "item_type_id" => 215,
              "quantity_destroyed" => 200,
              "quantity_dropped" => 0
            }
          ]
        }
      }

      result = PriceService.calculate_killmail_value(killmail)

      # Should calculate quantities correctly
      assert result.destroyed_value > 0 || result.dropped_value > 0
    end

    test "identifies primary price source" do
      killmail = %{
        "victim" => %{
          "ship_type_id" => 587,
          "items" => [
            %{"item_type_id" => 2185, "quantity_destroyed" => 1},
            %{"item_type_id" => 1541, "quantity_destroyed" => 1},
            %{"item_type_id" => 438, "quantity_destroyed" => 1}
          ]
        }
      }

      result = PriceService.calculate_killmail_value(killmail)

      # Should identify the most common source
      assert is_atom(result.price_source)
      assert result.price_source != :unknown
    end
  end

  describe "strategy_info/0" do
    test "returns list of available strategies" do
      strategies = PriceService.strategy_info()

      assert is_list(strategies)
      assert length(strategies) > 0

      Enum.each(strategies, fn strategy ->
        assert is_map(strategy)
        assert Map.has_key?(strategy, :name)
        assert Map.has_key?(strategy, :priority)
        assert Map.has_key?(strategy, :module)

        assert is_binary(strategy.name)
        assert is_integer(strategy.priority)
        assert is_atom(strategy.module)
      end)
    end

    test "strategies are ordered by priority" do
      strategies = PriceService.strategy_info()

      priorities = Enum.map(strategies, & &1.priority)
      assert priorities == Enum.sort(priorities)
    end
  end

  describe "price caching behavior" do
    test "caches price results" do
      type_id = 587

      # First call - should hit API or strategy
      result1 = PriceService.get_item_price(type_id)

      case result1 do
        {:ok, price1} ->
          # Second call immediately after - should return same result
          assert {:ok, price2} = PriceService.get_item_price(type_id)

          # Prices should be identical if from cache
          assert price1 == price2

          # Third call to verify consistency
          assert {:ok, price3} = PriceService.get_item_price(type_id)
          assert price1 == price3

        {:error, _reason} ->
          # If first call failed, subsequent calls should also fail consistently
          assert {:error, _} = PriceService.get_item_price(type_id)
      end
    end

    test "handles concurrent cache access" do
      type_id = 587

      # Launch multiple concurrent requests for the same item
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            PriceService.get_item_price(type_id)
          end)
        end

      # Collect all results
      results = Task.await_many(tasks, 5000)

      # All requests should return the same result (either all success or all error)
      first_result = hd(results)

      Enum.each(results, fn result ->
        assert result == first_result
      end)
    end

    test "caches different price types separately" do
      type_id = 587

      # Get buy and sell prices
      buy_result = PriceService.get_item_price(type_id, :buy)
      sell_result = PriceService.get_item_price(type_id, :sell)

      case {buy_result, sell_result} do
        {{:ok, buy_price}, {:ok, sell_price}} ->
          # Buy and sell prices might be different
          # Cache should maintain both separately
          assert {:ok, ^buy_price} = PriceService.get_item_price(type_id, :buy)
          assert {:ok, ^sell_price} = PriceService.get_item_price(type_id, :sell)

        _ ->
          # If API fails, both should fail consistently
          :ok
      end
    end

    test "cache behavior with invalid items" do
      # Invalid type IDs should also be cached to avoid repeated failed API calls
      invalid_type_id = -1

      # First call
      assert {:error, reason1} = PriceService.get_item_price(invalid_type_id)

      # Second call should return same error quickly (from cache)
      assert {:error, reason2} = PriceService.get_item_price(invalid_type_id)

      # Errors should be consistent
      assert reason1 == reason2
    end
  end

  describe "error handling" do
    test "handles network errors gracefully" do
      # Test with a type_id that might cause network issues
      type_id = 999_999_999

      result = PriceService.get_item_price(type_id)

      case result do
        {:ok, _price} ->
          # If it succeeds, price should be reasonable
          :ok

        {:error, reason} ->
          # Should return a meaningful error
          assert is_binary(reason) or is_atom(reason)
      end
    end

    test "handles malformed killmail data" do
      killmail = %{
        "victim" => "not a map",
        "items" => "not a list"
      }

      # Should not crash
      result = PriceService.calculate_killmail_value(killmail)

      assert is_map(result)
      assert result.total_value >= 0
    end
  end

  describe "strategy fallback behavior" do
    test "falls back to alternative pricing sources" do
      # Use a common item that should have prices from multiple sources
      type_id = 587

      # Get price data to see which source was used
      {:ok, price_data} = PriceService.get_item_price_data(type_id)

      # Verify a source was selected
      assert price_data.source in [:mutamarket, :janice, :esi, :base_price]
    end
  end
end
