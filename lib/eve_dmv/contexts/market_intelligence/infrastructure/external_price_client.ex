defmodule EveDmv.Contexts.MarketIntelligence.Infrastructure.ExternalPriceClient do
  @moduledoc """
  Client for fetching price data from external sources.

  Routes price requests to appropriate external APIs based on source preference.
  Supports Janice API as primary source with fallback to cached killmail values.
  """

  alias EveDmv.Contexts.MarketIntelligence.Infrastructure.JaniceClient
  require Logger

  # Type definitions
  @type external_price_info :: %{
          sell_price: float() | nil,
          buy_price: float() | nil,
          volume: non_neg_integer() | nil,
          source: atom(),
          confidence: float(),
          updated_at: DateTime.t()
        }

  @type bulk_price_response :: %{integer() => external_price_info()}

  @doc """
  Get price for a single type ID from external source.

  Sources:
  - :best - Try Janice API first, fallback to killmail analysis
  - :janice - Use Janice API only
  - :killmail - Use killmail-derived prices only
  """
  @spec get_price(integer(), atom()) :: {:ok, external_price_info()} | {:error, atom()}
  def get_price(type_id, source \\ :best) when is_integer(type_id) do
    case source do
      :best ->
        # Try Janice first, fallback to killmail analysis
        case JaniceClient.get_item_price(type_id) do
          {:ok, price_info} ->
            {:ok, format_price_info(price_info)}

          {:error, _} ->
            get_killmail_derived_price(type_id)
        end

      :janice ->
        # Janice API only
        case JaniceClient.get_item_price(type_id) do
          {:ok, price_info} ->
            {:ok, format_price_info(price_info)}

          {:error, reason} ->
            Logger.warning("Janice API failed for type #{type_id}: #{inspect(reason)}")
            {:error, reason}
        end

      :killmail ->
        # Killmail analysis only
        get_killmail_derived_price(type_id)

      _ ->
        {:error, :invalid_source}
    end
  end

  @doc """
  Get prices for multiple type IDs from external source.
  """
  @spec get_prices([integer()], atom()) :: {:ok, bulk_price_response()} | {:error, atom()}
  def get_prices(type_ids, source \\ :best) when is_list(type_ids) do
    case source do
      :best ->
        # Try bulk Janice lookup first
        case JaniceClient.bulk_price_lookup(type_ids) do
          {:ok, prices} ->
            # Format all successful prices
            formatted =
              Map.new(prices, fn {type_id, price_info} ->
                {type_id, format_price_info(price_info)}
              end)

            # Find missing prices
            missing = Enum.filter(type_ids, &(not Map.has_key?(formatted, &1)))

            if Enum.empty?(missing) do
              {:ok, formatted}
            else
              # Get killmail prices for missing items
              killmail_prices = get_bulk_killmail_prices(missing)
              {:ok, Map.merge(formatted, killmail_prices)}
            end

          {:error, _} ->
            # Fallback to killmail prices for all
            prices = get_bulk_killmail_prices(type_ids)
            {:ok, prices}
        end

      :janice ->
        # Janice only - no fallback
        case JaniceClient.bulk_price_lookup(type_ids) do
          {:ok, prices} ->
            formatted =
              Map.new(prices, fn {type_id, price_info} ->
                {type_id, format_price_info(price_info)}
              end)

            {:ok, formatted}

          {:error, reason} ->
            {:error, reason}
        end

      :killmail ->
        # Killmail analysis only
        prices = get_bulk_killmail_prices(type_ids)
        {:ok, prices}

      _ ->
        {:error, :invalid_source}
    end
  end

  # Private functions

  defp format_price_info(price_info) do
    %{
      price: price_info.sell_price || 0.0,
      buy_price: price_info.buy_price || 0.0,
      volume: price_info.sell_volume || 0,
      last_updated: price_info.updated_at || DateTime.utc_now()
    }
  end

  defp get_killmail_derived_price(type_id) do
    # Query recent killmails containing this item type
    # This would analyze destroyed/dropped items to derive market value
    # For now, use ValuationService's fallback estimates

    estimated_value = estimate_value_from_type(type_id)

    {:ok,
     %{
       price: estimated_value,
       # Assume 10% spread
       buy_price: estimated_value * 0.9,
       # No volume data from killmails
       volume: 0,
       last_updated: DateTime.utc_now(),
       source: :killmail_estimate
     }}
  end

  defp get_bulk_killmail_prices(type_ids) do
    type_ids
    |> Enum.map(fn type_id ->
      case get_killmail_derived_price(type_id) do
        {:ok, price_data} ->
          {type_id, price_data}

        _ ->
          # Use SDE-based estimation instead of returning 0.0
          estimated_price = estimate_price_from_sde(type_id)

          {type_id,
           %{
             price: estimated_price,
             buy_price: estimated_price * 0.9,
             volume: 0,
             last_updated: DateTime.utc_now(),
             source: :sde_estimate
           }}
      end
    end)
    |> Map.new()
  end

  defp estimate_price_from_sde(type_id) do
    # Try to get ship data first for better estimates
    case get_ship_based_estimate(type_id) do
      {:ok, price} -> price
      :error -> estimate_value_from_type(type_id)
    end
  end

  defp get_ship_based_estimate(type_id) do
    case EveDmv.Repo.query(
           """
             SELECT sa.size_class, sa.role_classification, eit.group_name, eit.base_price
             FROM ship_attributes sa
             JOIN eve_item_types eit ON sa.type_id = eit.type_id
             WHERE sa.type_id = $1
           """,
           [type_id]
         ) do
      {:ok, %{rows: [[size_class, role, group_name, base_price]]}} ->
        # Use size class and role for better pricing
        estimated_price = calculate_ship_price(size_class, role, group_name, base_price)
        {:ok, estimated_price}

      _ ->
        # Try basic item type lookup
        case EveDmv.Repo.query(
               """
                 SELECT group_name, category_name, base_price
                 FROM eve_item_types
                 WHERE type_id = $1
               """,
               [type_id]
             ) do
          {:ok, %{rows: [[group_name, category_name, base_price]]}} ->
            estimated_price = calculate_item_price(group_name, category_name, base_price)
            {:ok, estimated_price}

          _ ->
            :error
        end
    end
  end

  defp calculate_ship_price(size_class, role, _group_name, base_price) do
    # Base price multipliers by ship class
    base_multiplier =
      case size_class do
        "frigate" -> 1.0
        "destroyer" -> 3.0
        "cruiser" -> 8.0
        "battlecruiser" -> 25.0
        "battleship" -> 80.0
        "capital" -> 600.0
        "supercapital" -> 15_000.0
        _ -> 5.0
      end

    # Role multipliers
    role_multiplier =
      case role do
        "logistics" -> 1.5
        "ewar" -> 1.3
        "tackle" -> 1.1
        "dps" -> 1.0
        "support" -> 1.4
        _ -> 1.0
      end

    # Use base price if available, otherwise use size-based estimate
    if base_price && base_price > 0 do
      base_price * role_multiplier
    else
      # Fallback estimates in ISK
      base_estimate =
        case size_class do
          "frigate" -> 2_000_000
          "destroyer" -> 10_000_000
          "cruiser" -> 25_000_000
          "battlecruiser" -> 80_000_000
          "battleship" -> 250_000_000
          "capital" -> 2_000_000_000
          "supercapital" -> 50_000_000_000
          _ -> 10_000_000
        end

      Float.round(base_estimate * base_multiplier * role_multiplier, 2)
    end
  end

  defp calculate_item_price(group_name, category_name, base_price) do
    # Use base price when available
    if base_price && base_price > 0 do
      base_price
    else
      # Category-based estimates
      case category_name do
        "Ship" -> estimate_ship_price_by_group(group_name)
        "Module" -> 5_000_000.0
        "Charge" -> 1_000.0
        "Commodity" -> 50_000.0
        "Implant" -> 100_000_000.0
        "Drone" -> 10_000_000.0
        _ -> 100_000.0
      end
    end
  end

  defp estimate_ship_price_by_group(group_name) do
    cond do
      String.contains?(group_name, ["Frigate", "Stealth Bomber"]) -> 5_000_000.0
      String.contains?(group_name, ["Destroyer"]) -> 15_000_000.0
      String.contains?(group_name, ["Cruiser"]) -> 35_000_000.0
      String.contains?(group_name, ["Battlecruiser"]) -> 120_000_000.0
      String.contains?(group_name, ["Battleship", "Marauder"]) -> 400_000_000.0
      String.contains?(group_name, ["Carrier", "Dreadnought"]) -> 3_000_000_000.0
      String.contains?(group_name, ["Supercarrier", "Titan"]) -> 75_000_000_000.0
      true -> 25_000_000.0
    end
  end

  defp estimate_value_from_type(type_id) do
    # Legacy type-ID based estimation - used as final fallback
    cond do
      # Ships (broad type ID ranges)
      type_id in 500..40_000 -> 25_000_000.0
      # Modules
      type_id in 40_000..50_000 -> 5_000_000.0
      # Charges/Ammo
      type_id in 50_000..60_000 -> 1_000.0
      # Default
      true -> 100_000.0
    end
  end
end
