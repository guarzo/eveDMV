defmodule EveDmv.Config.Api do
  @moduledoc """
  External API configuration management.

  Centralizes base URLs, endpoints, and API-specific settings for all
  external service integrations.
  """

  alias EveDmv.Config

  # Default API configuration
  @default_janice_base_url "https://janice.e-351.com/api"
  @default_mutamarket_base_url "https://mutamarket.com/api/v1"
  @default_esi_base_url "https://esi.evetech.net"
  @default_esi_datasource "tranquility"

  # API endpoints
  @janice_item_endpoint "/v2/prices"
  @janice_appraisal_endpoint "/v2/appraisal"
  @mutamarket_appraisal_endpoint "/appraisal/live"
  @mutamarket_type_stats_endpoint "/modules/type"
  @mutamarket_search_endpoint "/modules/search"

  # EVE-specific constants
  @abyssal_mutated_attribute_id 1692
  @abyssal_depth_attribute_id 2112
  @abyssal_mutaplasmid_type_attribute_id 2113

  @doc """
  Get Janice API base URL.

  Environment: JANICE_BASE_URL (default: https://janice.e-351.com/api)
  """
  @spec janice_base_url() :: String.t()
  def janice_base_url do
    Config.get(:eve_dmv, :janice_base_url, @default_janice_base_url)
  end

  @doc """
  Get Mutamarket API base URL.

  Environment: MUTAMARKET_BASE_URL (default: https://mutamarket.com/api/v1)
  """
  @spec mutamarket_base_url() :: String.t()
  def mutamarket_base_url do
    Config.get(:eve_dmv, :mutamarket_base_url, @default_mutamarket_base_url)
  end

  @doc """
  Get ESI API base URL.

  Environment: ESI_BASE_URL (default: https://esi.evetech.net)
  """
  @spec esi_base_url() :: String.t()
  def esi_base_url do
    Config.get(:eve_dmv, :esi_base_url, @default_esi_base_url)
  end

  @doc """
  Get ESI datasource.

  Environment: ESI_DATASOURCE (default: tranquility)
  """
  @spec esi_datasource() :: String.t()
  def esi_datasource do
    Config.get(:eve_dmv, :esi_datasource, @default_esi_datasource)
  end

  @doc """
  Get Janice API endpoints.
  """
  @spec janice_endpoints() :: keyword()
  def janice_endpoints do
    [
      items: @janice_item_endpoint,
      appraisal: @janice_appraisal_endpoint
    ]
  end

  @doc """
  Get Mutamarket API endpoints.
  """
  @spec mutamarket_endpoints() :: keyword()
  def mutamarket_endpoints do
    [
      appraisal: @mutamarket_appraisal_endpoint,
      type_stats: @mutamarket_type_stats_endpoint,
      search: @mutamarket_search_endpoint
    ]
  end

  @doc """
  Get abyssal module type ID range.

  Environment: EVE_DMV_ABYSSAL_TYPE_ID_MIN and EVE_DMV_ABYSSAL_TYPE_ID_MAX
  """
  @spec abyssal_type_id_range() :: Range.t()
  def abyssal_type_id_range do
    min_id = Config.get(:eve_dmv, :abyssal_type_id_min, 47_800)
    max_id = Config.get(:eve_dmv, :abyssal_type_id_max, 49_000)
    min_id..max_id
  end

  @doc """
  Get abyssal module attribute IDs.
  """
  @spec abyssal_attribute_ids() :: keyword()
  def abyssal_attribute_ids do
    [
      mutated: Config.get(:eve_dmv, :abyssal_mutated_attribute_id, @abyssal_mutated_attribute_id),
      depth: Config.get(:eve_dmv, :abyssal_depth_attribute_id, @abyssal_depth_attribute_id),
      mutaplasmid_type:
        Config.get(
          :eve_dmv,
          :abyssal_mutaplasmid_type_attribute_id,
          @abyssal_mutaplasmid_type_attribute_id
        )
    ]
  end

  @doc """
  Get complete API configuration for a service.
  """
  @spec service_config(atom()) :: keyword()
  def service_config(:janice) do
    [
      base_url: janice_base_url(),
      endpoints: janice_endpoints(),
      timeout: EveDmv.Config.Http.janice_timeout(),
      rate_limit: EveDmv.Config.RateLimit.janice_rate_limit()
    ]
  end

  def service_config(:mutamarket) do
    [
      base_url: mutamarket_base_url(),
      endpoints: mutamarket_endpoints(),
      timeout: EveDmv.Config.Http.mutamarket_timeout(),
      abyssal_type_range: abyssal_type_id_range(),
      abyssal_attributes: abyssal_attribute_ids()
    ]
  end

  def service_config(:esi) do
    [
      base_url: esi_base_url(),
      datasource: esi_datasource(),
      timeout: EveDmv.Config.Http.esi_timeout()
    ]
  end

  def service_config(_service), do: []
end
