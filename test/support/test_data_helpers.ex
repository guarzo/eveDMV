defmodule EveDmv.TestDataHelpers do
  @moduledoc """
  Helper functions to create test data for common ships and items.
  """

  alias EveDmv.Api
  alias EveDmv.Eve.ItemType

  @common_ships [
    %{
      type_id: 11987,
      type_name: "Guardian",
      group_id: 832,
      is_ship: true,
      mass: Decimal.new("11200000")
    },
    %{
      type_id: 11174,
      type_name: "Keres",
      group_id: 893,
      is_ship: true,
      mass: Decimal.new("1000000")
    },
    %{
      type_id: 641,
      type_name: "Stabber",
      group_id: 26,
      is_ship: true,
      mass: Decimal.new("10650000")
    },
    %{
      type_id: 22456,
      type_name: "Damnation",
      group_id: 419,
      is_ship: true,
      mass: Decimal.new("15500000")
    },
    %{
      type_id: 29990,
      type_name: "Loki",
      group_id: 963,
      is_ship: true,
      mass: Decimal.new("12500000")
    },
    %{
      type_id: 29984,
      type_name: "Tengu",
      group_id: 963,
      is_ship: true,
      mass: Decimal.new("14300000")
    },
    %{
      type_id: 29986,
      type_name: "Legion",
      group_id: 963,
      is_ship: true,
      mass: Decimal.new("13000000")
    },
    %{
      type_id: 29988,
      type_name: "Proteus",
      group_id: 963,
      is_ship: true,
      mass: Decimal.new("13250000")
    },
    %{
      type_id: 11_989,
      type_name: "Oneiros",
      group_id: 832,
      is_ship: true,
      mass: Decimal.new("11700000")
    },
    %{
      type_id: 11_985,
      type_name: "Basilisk",
      group_id: 832,
      is_ship: true,
      mass: Decimal.new("11230000")
    },
    %{
      type_id: 11_987,
      type_name: "Scimitar",
      group_id: 832,
      is_ship: true,
      mass: Decimal.new("11500000")
    },
    %{
      type_id: 587,
      type_name: "Rifter",
      group_id: 25,
      is_ship: true,
      mass: Decimal.new("1067000")
    },
    %{
      type_id: 582,
      type_name: "Bantam",
      group_id: 25,
      is_ship: true,
      mass: Decimal.new("1100000")
    },
    %{
      type_id: 583,
      type_name: "Condor",
      group_id: 25,
      is_ship: true,
      mass: Decimal.new("1010000")
    },
    %{
      type_id: 585,
      type_name: "Slasher",
      group_id: 25,
      is_ship: true,
      mass: Decimal.new("1050000")
    },
    %{
      type_id: 2834,
      type_name: "Crucifier",
      group_id: 893,
      is_ship: true,
      mass: Decimal.new("1160000")
    },
    %{
      type_id: 11202,
      type_name: "Ares",
      group_id: 831,
      is_ship: true,
      mass: Decimal.new("1000000")
    }
  ]

  @doc """
  Seeds the database with common ship data for tests.
  """
  def seed_test_ships do
    Enum.each(@common_ships, fn ship_data ->
      case Ash.create(ItemType, ship_data,
             domain: Api,
             upsert?: true,
             upsert_identity: :unique_type_id
           ) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          IO.warn("Failed to create test ship #{ship_data.type_name}: #{inspect(error)}")
      end
    end)
  end

  @doc """
  Seeds a specific ship by name and type_id.
  """
  def seed_ship(type_id, type_name, opts \\ []) do
    defaults = %{
      type_id: type_id,
      type_name: type_name,
      # Default to frigate
      group_id: opts[:group_id] || 25,
      is_ship: true,
      mass: opts[:mass] || Decimal.new("1000000"),
      volume: opts[:volume] || Decimal.new("2500"),
      base_price: opts[:base_price] || Decimal.new("100000")
    }

    ship_data = Map.merge(defaults, Map.new(opts))

    Ash.create(ItemType, ship_data, domain: Api, upsert?: true, upsert_identity: :unique_type_id)
  end
end
