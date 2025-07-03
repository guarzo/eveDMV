defmodule EveDmv.Eve.EsiClient do
  @moduledoc """
  Main facade for EVE Online's ESI (EVE Swagger Interface) API.

  This module provides a unified interface to all ESI functionality by
  delegating to specialized client modules for different API areas.

  ## Configuration

  The client uses the same OAuth2 credentials as EVE SSO:

      config :eve_dmv, :esi,
        client_id: "your-client-id",
        base_url: "https://esi.evetech.net"

  ## Usage

      # Character operations
      {:ok, character} = EsiClient.get_character(95465499)
      {:ok, characters} = EsiClient.get_characters([95465499, 90267367])
      
      # Corporation operations  
      {:ok, corp} = EsiClient.get_corporation(98388312)
      
      # Universe operations
      {:ok, system} = EsiClient.get_solar_system(30002187)
      {:ok, alliance} = EsiClient.get_alliance(99000001)
      
      # Market operations
      {:ok, orders} = EsiClient.get_market_orders(34, 10000002)
  """

  alias EveDmv.Eve.{EsiCharacterClient, EsiCorporationClient, EsiMarketClient, EsiUniverseClient}

  # Character Operations

  @doc """
  Get character information by ID.
  """
  @spec get_character(integer()) :: {:ok, map()} | {:error, term()}
  defdelegate get_character(character_id), to: EsiCharacterClient

  @doc """
  Get multiple characters efficiently using parallel requests.
  """
  @spec get_characters([integer()]) :: {:ok, map()}
  defdelegate get_characters(character_ids), to: EsiCharacterClient

  @doc """
  Get character employment history.
  """
  @spec get_character_employment_history(integer()) ::
          {:error, :invalid_response | :service_unavailable}
  defdelegate get_character_employment_history(character_id), to: EsiCharacterClient

  @doc """
  Get character skills (requires authentication).
  """
  @spec get_character_skills(integer(), String.t()) ::
          {:ok, %{skills: [any()], total_sp: any(), unallocated_sp: any()}}
          | {:error, :service_unavailable}
  defdelegate get_character_skills(character_id, auth_token), to: EsiCharacterClient

  @doc """
  Get character assets (requires authentication).
  """
  @spec get_character_assets(integer(), binary()) ::
          {:ok, [map()]} | {:error, :service_unavailable}
  defdelegate get_character_assets(character_id, auth_token), to: EsiCharacterClient

  # Corporation Operations

  @doc """
  Get corporation information by ID.
  """
  @spec get_corporation(integer()) :: {:error, :service_unavailable} | {:ok, map()}
  defdelegate get_corporation(corporation_id), to: EsiCorporationClient

  @doc """
  Get corporation members (requires authentication).
  """
  @spec get_corporation_members(integer(), String.t()) :: {:error, :service_unavailable}
  defdelegate get_corporation_members(corporation_id, auth_token), to: EsiCorporationClient

  @doc """
  Get corporation assets (requires authentication).
  """
  @spec get_corporation_assets(integer(), binary()) ::
          {:ok, [map()]} | {:error, :service_unavailable}
  defdelegate get_corporation_assets(corporation_id, auth_token), to: EsiCorporationClient

  # Universe Operations

  @doc """
  Get alliance information by ID.
  """
  @spec get_alliance(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  defdelegate get_alliance(alliance_id), to: EsiUniverseClient

  @doc """
  Get solar system information by ID.
  """
  @spec get_solar_system(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  defdelegate get_solar_system(system_id), to: EsiUniverseClient

  @doc """
  Search for entities in EVE universe.
  """
  @spec search(String.t(), [String.t()]) ::
          {:ok, map()} | {:error, :search_too_short | :service_unavailable}
  defdelegate search(search_string, categories), to: EsiUniverseClient

  @doc """
  Search for entities - alias for search/2 for consistency.
  """
  @spec search_entities(String.t(), [atom()]) ::
          {:ok, map()} | {:error, :search_too_short | :service_unavailable}
  def search_entities(search_string, categories) when is_list(categories) do
    # Convert atom categories to strings
    string_categories = Enum.map(categories, &Atom.to_string/1)
    search(search_string, string_categories)
  end

  @doc """
  Get type information by ID.
  """
  @spec get_type(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  defdelegate get_type(type_id), to: EsiUniverseClient

  @doc """
  Get group information by ID.
  """
  @spec get_group(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  defdelegate get_group(group_id), to: EsiUniverseClient

  @doc """
  Get category information by ID.
  """
  @spec get_category(integer()) :: {:ok, map()} | {:error, :service_unavailable}
  defdelegate get_category(category_id), to: EsiUniverseClient

  # Market Operations

  @doc """
  Get market orders for a specific type in a region.
  """
  @spec get_market_orders(integer(), integer(), atom()) :: {:error, :service_unavailable}
  defdelegate get_market_orders(type_id, region_id \\ 10_000_002, order_type \\ :all),
    to: EsiMarketClient

  @doc """
  Get market history for a specific type in a region.
  """
  @spec get_market_history(integer(), integer()) :: {:error, :service_unavailable}
  defdelegate get_market_history(type_id, region_id \\ 10_000_002), to: EsiMarketClient

  @doc """
  Get market prices for multiple types efficiently.
  """
  @spec get_market_prices([integer()], integer()) :: {:ok, map()}
  defdelegate get_market_prices(type_ids, region_id \\ 10_000_002), to: EsiMarketClient
end
