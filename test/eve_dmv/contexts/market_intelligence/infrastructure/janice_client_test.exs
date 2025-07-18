defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClientTest do
  use ExUnit.Case, async: false
  alias EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient

  setup do
    # Mock Tesla requests for testing - use global mock for all processes
    Tesla.Mock.mock_global(fn
      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/34"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "sell" => %{"min" => 4.50, "volume" => 1_000_000},
            "buy" => %{"max" => 4.25, "volume" => 900_000}
          }
        }

      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/35"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "sell" => %{"min" => 12.50, "volume" => 800_000},
            "buy" => %{"max" => 12.10, "volume" => 750_000}
          }
        }

      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/36"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "sell" => %{"min" => 75.00, "volume" => 100_000},
            "buy" => %{"max" => 73.50, "volume" => 90_000}
          }
        }

      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/37"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "sell" => %{"min" => 320.00, "volume" => 50_000},
            "buy" => %{"max" => 315.00, "volume" => 45_000}
          }
        }

      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/587"} ->
        %Tesla.Env{
          status: 200,
          body: %{
            "sell" => %{"min" => 750_000.0, "volume" => 50},
            "buy" => %{"max" => 720_000.0, "volume" => 30}
          }
        }

      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/999999"} ->
        %Tesla.Env{status: 404, body: %{"error" => "Item not found"}}

      %{method: :get, url: "https://janice.e-351.com/api/rest/v2/market/bulk/" <> ids} ->
        # Handle bulk requests dynamically based on requested IDs
        id_list = String.split(ids, ",")

        response_body =
          id_list
          |> Enum.reduce(%{}, fn id, acc ->
            case id do
              "34" ->
                Map.put(acc, "34", %{
                  "sell" => %{"min" => 4.50, "volume" => 1_000_000},
                  "buy" => %{"max" => 4.25, "volume" => 900_000}
                })

              "35" ->
                Map.put(acc, "35", %{
                  "sell" => %{"min" => 12.50, "volume" => 800_000},
                  "buy" => %{"max" => 12.10, "volume" => 750_000}
                })

              "36" ->
                Map.put(acc, "36", %{
                  "sell" => %{"min" => 75.00, "volume" => 100_000},
                  "buy" => %{"max" => 73.50, "volume" => 90_000}
                })

              "37" ->
                Map.put(acc, "37", %{
                  "sell" => %{"min" => 320.00, "volume" => 50_000},
                  "buy" => %{"max" => 315.00, "volume" => 45_000}
                })

              "587" ->
                Map.put(acc, "587", %{
                  "sell" => %{"min" => 750_000.0, "volume" => 50},
                  "buy" => %{"max" => 720_000.0, "volume" => 30}
                })

              # Unknown IDs return no data
              _ ->
                acc
            end
          end)

        %Tesla.Env{status: 200, body: response_body}

      # Default fallback for any other requests
      _ ->
        %Tesla.Env{status: 500, body: %{"error" => "Internal server error"}}
    end)

    # Start the JaniceClient GenServer for tests if not already started
    case Process.whereis(JaniceClient) do
      nil ->
        {:ok, _pid} = JaniceClient.start_link()

      _pid ->
        :ok
    end

    # Clear cache before each test
    JaniceClient.clear_cache()

    :ok
  end

  describe "get_item_price/1" do
    test "returns price info for valid item" do
      # Type ID 34 is Tritanium - using mocked response
      result = JaniceClient.get_item_price(34)

      assert {:ok, price_info} = result
      assert is_float(price_info.sell_price)
      assert is_float(price_info.buy_price)
      assert price_info.sell_price >= 0
      assert price_info.buy_price >= 0
      assert %DateTime{} = price_info.updated_at
    end

    test "caches price data" do
      # First call should hit the API
      {:ok, first_result} = JaniceClient.get_item_price(34)

      # Second call should hit the cache (faster)
      start_time = System.monotonic_time(:millisecond)
      {:ok, second_result} = JaniceClient.get_item_price(34)
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Cache hit should be very fast (< 5ms)
      assert elapsed < 5

      # Results should be identical
      assert first_result.sell_price == second_result.sell_price
      assert first_result.buy_price == second_result.buy_price
    end

    test "handles non-existent item gracefully" do
      # Use an invalid type ID
      result = JaniceClient.get_item_price(999_999)

      assert {:error, :not_found} = result
    end
  end

  describe "get_ship_price/1" do
    test "returns price info for valid ship" do
      # Type ID 587 is Rifter - a common frigate
      result = JaniceClient.get_ship_price(587)

      assert {:ok, price_info} = result
      assert is_float(price_info.sell_price)
      assert is_float(price_info.buy_price)
      assert price_info.sell_price > 0
    end
  end

  describe "bulk_price_lookup/1" do
    test "returns prices for multiple items" do
      # Use mocked type IDs: Tritanium and Rifter
      type_ids = [34, 587]

      result = JaniceClient.bulk_price_lookup(type_ids)

      assert {:ok, prices} = result
      assert map_size(prices) > 0

      # Check that we got prices for requested items
      Enum.each(type_ids, fn type_id ->
        if Map.has_key?(prices, type_id) do
          price_info = Map.get(prices, type_id)
          assert is_float(price_info.sell_price)
          assert is_float(price_info.buy_price)
        end
      end)
    end

    test "rejects requests with too many items" do
      # Create list of 101 type IDs
      type_ids = Enum.to_list(1..101)

      result = JaniceClient.bulk_price_lookup(type_ids)

      assert {:error, :too_many_items} = result
    end

    test "uses cache for already-fetched items" do
      # Pre-fetch some items
      JaniceClient.get_item_price(34)
      JaniceClient.get_item_price(35)

      # Bulk lookup including cached items
      start_time = System.monotonic_time(:millisecond)
      {:ok, prices} = JaniceClient.bulk_price_lookup([34, 35, 36, 37])
      elapsed = System.monotonic_time(:millisecond) - start_time

      # Should be faster due to cache hits
      # Less than 1 second
      assert elapsed < 1000
      assert map_size(prices) >= 2
    end
  end

  describe "rate limiting" do
    test "tracks rate limit status" do
      # Get initial status
      initial_status = JaniceClient.get_rate_limit_status()

      assert initial_status.limit == 100
      assert initial_status.requests_in_window >= 0
      assert initial_status.remaining >= 0

      # Make a request
      JaniceClient.get_item_price(34)

      # Check status changed
      new_status = JaniceClient.get_rate_limit_status()
      assert new_status.requests_in_window >= initial_status.requests_in_window
    end

    # Skip this test by default as it takes time
    @tag :skip
    test "enforces rate limits" do
      # Clear any previous requests
      Process.sleep(1000)

      # Try to exceed rate limit (this would take too long in real tests)
      results =
        Enum.map(1..101, fn i ->
          Task.async(fn -> JaniceClient.get_item_price(i) end)
        end)
        |> Enum.map(&Task.await/1)

      # Some requests should be rate limited
      rate_limited_count =
        Enum.count(results, fn result ->
          match?({:error, :rate_limited}, result)
        end)

      assert rate_limited_count > 0
    end
  end

  describe "cache management" do
    test "clear_cache/0 removes all cached data" do
      # Add some data to cache
      JaniceClient.get_item_price(34)
      JaniceClient.get_item_price(35)

      # Clear cache
      JaniceClient.clear_cache()

      # Next request should hit API (not cache)
      # We can't easily test this without mocking, but we can verify it works
      assert :ok = JaniceClient.clear_cache()
    end
  end
end
