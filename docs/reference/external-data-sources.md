# External Data Integration

## 1. Static EVE Data Import

We need a local table of all in-game item types so we can resolve `type_id` → `type_name` (and other metadata) without hitting ESI on every request.

### 1.1 Source

Download the latest ESI Static Data Export (SDE) JSON or CSV from CCP:
- https://esi.evetech.net/ui/#/Universe/get_universe_types
- Alternatively, grab a nightly dump from https://eve-offline.net/?a=displayDownloads

### 1.2 Schema

```sql
-- This table is already created by migrations
-- See: priv/repo/migrations/01_static_data_schema.exs
CREATE TABLE eve_item_types (
  type_id        bigint    PRIMARY KEY,
  type_name      text      NOT NULL,
  group_id       integer   NOT NULL,
  category_id    integer   NOT NULL,
  mass           numeric,
  volume         numeric,
  portion_size   integer,
  published      boolean,
  base_price     numeric,
  capacity       numeric,
  market_group_id integer,
  inserted_at    timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);
```

### 1.3 Import Process

Use the provided mix tasks:

```bash
# Load static data from SDE files
mix eve.load_static_data

# Update to latest SDE version
mix eve.update_sde

# Check statistics
mix eve.stats
```

The tasks handle:
1. Downloading latest SDE from CCP
2. Streaming import with progress tracking
3. Automatic conflict resolution
4. Loading both item types and solar systems

## 2. Janice API Integration

Janice provides up-to-date market prices per region/type. We'll wrap it in a service module, cache responses, and expose a simple lookup.

### 2.1 Janice Endpoint

According to the docs:

```bash
GET https://janice.e-351.com/api/markets/{region_id}/types/{type_id}/history
```

or

```bash
GET https://janice.e-351.com/api/markets/{region_id}/types/{type_id}/prices
```

(with query params for date ranges).

### 2.2 Elixir Client

```elixir
defmodule EveDmv.Prices.JaniceClient do
  @base_url "https://janice.e-351.com/api"
  @default_region 10000002  # The Forge (Jita)

  @doc """
  Fetch the median price for a type in a region.
  Caches per (region_id, type_id) for 1h.
  """
  def get_price(type_id, region_id \\ @default_region) do
    cache_key = {:janice_price, region_id, type_id}

    Cachex.fetch(:price_cache, cache_key, fn ->
      url = "#{@base_url}/markets/#{region_id}/types/#{type_id}/history"
      case HTTPoison.get(url) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          data = Jason.decode!(body)
          # Assume data is a list of {date, avg, high, low}
          latest = Enum.max_by(data, & &1["date"])
          {:commit, Decimal.new(latest["avg"])}
        _error ->
          {:ignore, :error}
      end
    end)
  end
end
```

- **Cache:** using Cachex with TTL = 3600s
- **Fallback:** if Janice 429s or fails, return `{:error, :janice_unavailable}` and fall back to Mutamarket or static average from SDE metadata (if available)

## 3. Mutamarket (Abyssal) Price Lookup

Mutamarket provides price guides for Abyssal modules/ships, which ESI/Janice don't cover.

### 3.1 Mutamarket Endpoint

From their OpenAPI spec, e.g.:

```bash
GET https://mutamarket.com/api/v1/types/{type_id}/prices
```

or with region:

```bash
GET https://mutamarket.com/api/v1/markets/{region_id}/types/{type_id}
```

### 3.2 Elixir Client

```elixir
defmodule EveDmv.Prices.MutaMarketClient do
  @base_url "https://mutamarket.com/api/rest"
  @default_region 10000002

  @doc """
  Fetches abyssal market price for a type.
  Caches per (region, type) for 6h.
  """
  def get_abyssal_price(type_id, region_id \\ @default_region) do
    cache_key = {:mutamarket_price, region_id, type_id}

    Cachex.fetch(:price_cache, cache_key, ttl: :timer.hours(6), fn ->
      url = "#{@base_url}/markets/#{region_id}/types/#{type_id}/orders"
      case HTTPoison.get(url, [], recv_timeout: 5_000) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          data = Jason.decode!(body)
          # Suppose data["sell"] is a list of {price, volume}
          if orders = data["sell"], do: 
            median = compute_median_price(orders)
            {:commit, Decimal.new(median)}, else:
            {:ignore, :no_data}
        _ ->
          {:ignore, :error}
      end
    end)
  end

  defp compute_median_price(orders) do
    prices = Enum.map(orders, & &1["price"])
    Enum.sort(prices) |> median()
  end

  defp median(list) do
    len = length(list)
    mid = div(len, 2)
    if rem(len, 2) == 1, do: Enum.at(list, mid), else: 
      (Enum.at(list, mid - 1) + Enum.at(list, mid)) / 2
  end
end
```

- **Longer TTL (6h)** since abyssal prices change less frequently
- **Fallback:** if no data or error, return `{:error, :no_abyssal_data}`

## 4. Unified Price Service

Finally, wrap both clients in a single API:

```elixir
defmodule EveDmv.Prices do
  @doc """
  Returns the best available price for a given type:
    1. Janice (official market)
    2. Mutamarket (abyssal)
    3. Static fallback (if present in SDE metadata)
  """
  def lookup(type_id) do
    with {:ok, price} <- JaniceClient.get_price(type_id) do
      {:ok, price}
    else
      _ -> 
        case MutaMarketClient.get_abyssal_price(type_id) do
          {:ok, price} -> {:ok, price}
          _ -> fallback_static_price(type_id)
        end
    end
  end

  defp fallback_static_price(type_id) do
    # e.g., use avg(price_min, price_max) stored in eve_item_types
    query = from i in "eve_item_types",
            where: i.type_id == ^type_id,
            select: {(i.volume * i.mass) * 0.1}  # some heuristic
    case Repo.one(query) do
      nil -> {:error, :no_price}
      val -> {:ok, Decimal.from_float(val)}
    end
  end
end
```

## Caching & Performance

- **Cachex table `:price_cache`** with per-key TTLs
- Separate namespaces for `:janice_price` vs `:mutamarket_price`
- **Prewarm cache** for frequently used items
- **Background jobs** using `EveDmv.Workers` infrastructure
- **Query optimization** with database indexes on type_id

## Current Implementation Status

⚠️ **Note**: Market price integration is currently deferred (Sprint 20+). The stub client returns `{:ok, %{price: 0.0}}` for all requests. This is a known placeholder that needs implementation when external API keys are available.

With these pieces in place, your enrichment pipeline can call:

```elixir
price = EveDmv.Prices.lookup(type_id)
```

and you'll reliably get up-to-date market or abyssal prices, falling back to a static heuristic if needed.