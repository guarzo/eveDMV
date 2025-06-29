defmodule EveDmv.Market.PriceServiceTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Api
  alias EveDmv.Market.PriceService

  defp create_test_item(type_id, type_name, base_price, category_id, group_id) do
    {:ok, item} =
      Api.create(EveDmv.Eve.ItemType, %{
        type_id: type_id,
        type_name: type_name,
        base_price: Decimal.new(base_price),
        category_id: category_id,
        group_id: group_id,
        published: true
      })

    item
  end

  describe "get_item_price/2" do
    test "returns base price when no external APIs available" do
      # Create a test item with base price
      _item = create_test_item(587, "Rifter", "500000", 6, 25)

      # Without Janice configured, should fall back to base price
      assert {:ok, price} = PriceService.get_item_price(587)
      # Base price * 0.9 for buy price
      assert price == 450_000.0
    end

    test "returns error when item not found" do
      assert {:error, "No price available"} = PriceService.get_item_price(999_999)
    end
  end

  describe "calculate_killmail_value/1" do
    test "calculates total value from killmail data" do
      # Create test items
      _ship = create_test_item(587, "Rifter", "500000", 6, 25)
      _module = create_test_item(2881, "200mm AutoCannon II", "1000000", 7, 55)

      killmail = %{
        "victim" => %{
          "ship_type_id" => 587,
          "items" => [
            %{
              "item_type_id" => 2881,
              "quantity_destroyed" => 3,
              "quantity_dropped" => 1
            }
          ]
        },
        "attackers" => []
      }

      result = PriceService.calculate_killmail_value(killmail)

      # Ship: 500k * 0.9 = 450k
      # Modules: 1M * 0.9 * 4 = 3.6M
      assert result.ship_value == 450_000.0
      # 3 * 900k
      assert result.destroyed_value == 2_700_000.0
      # 1 * 900k
      assert result.dropped_value == 900_000.0
      # 450k + 3.6M
      assert result.total_value == 4_050_000.0
      assert result.price_source == :base_price
    end
  end
end
