defmodule EveDmv.Config.Api do
  @moduledoc """
  External API configuration management.

  Centralizes base URLs, endpoints, and API-specific settings for all
  external service integrations.

  This module now uses the unified configuration system for consistent
  configuration access and environment variable handling.
  """

  alias EveDmv.Config.Http
  alias EveDmv.Config.RateLimit
  alias EveDmv.Config.UnifiedConfig

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

  Environment: JANICE_BASE_URL or EVE_DMV_API_JANICE_BASE_URL
  """
  @spec janice_base_url() :: String.t()
  def janice_base_url do
    UnifiedConfig.env("JANICE_BASE_URL", [:api, :janice, :base_url])
  end

  @doc """
  Get Mutamarket API base URL.

  Environment: MUTAMARKET_BASE_URL or EVE_DMV_API_MUTAMARKET_BASE_URL
  """
  @spec mutamarket_base_url() :: String.t()
  def mutamarket_base_url do
    UnifiedConfig.env("MUTAMARKET_BASE_URL", [:api, :mutamarket, :base_url])
  end

  @doc """
  Get ESI API base URL.

  Environment: ESI_BASE_URL or EVE_DMV_API_ESI_BASE_URL
  """
  @spec esi_base_url() :: String.t()
  def esi_base_url do
    UnifiedConfig.get([:api, :esi, :base_url])
  end

  @doc """
  Get ESI datasource.

  Environment: ESI_DATASOURCE or EVE_DMV_API_ESI_DATASOURCE
  """
  @spec esi_datasource() :: String.t()
  def esi_datasource do
    UnifiedConfig.get([:api, :esi, :datasource])
  end

  @doc """
  Get Wanderer API base URL.

  Environment: WANDERER_KILLS_BASE_URL
  """
  @spec wanderer_base_url() :: String.t()
  def wanderer_base_url do
    UnifiedConfig.env("WANDERER_KILLS_BASE_URL", [:api, :wanderer, :base_url])
  end

  @doc """
  Get Wanderer SSE URL.

  Environment: WANDERER_KILLS_SSE_URL
  """
  @spec wanderer_sse_url() :: String.t()
  def wanderer_sse_url do
    UnifiedConfig.env("WANDERER_KILLS_SSE_URL", [:api, :wanderer, :sse_url])
  end

  @doc """
  Get Wanderer WebSocket URL.

  Environment: WANDERER_KILLS_WS_URL
  """
  @spec wanderer_ws_url() :: String.t()
  def wanderer_ws_url do
    UnifiedConfig.env("WANDERER_KILLS_WS_URL", [:api, :wanderer, :ws_url])
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
    min_id = UnifiedConfig.get([:api, :mutamarket, :abyssal_type_id_min], 47_800)
    max_id = UnifiedConfig.get([:api, :mutamarket, :abyssal_type_id_max], 49_000)
    min_id..max_id
  end

  @doc """
  Get abyssal module attribute IDs.
  """
  @spec abyssal_attribute_ids() :: keyword()
  def abyssal_attribute_ids do
    [
      mutated:
        UnifiedConfig.get(
          [:api, :mutamarket, :abyssal_mutated_attribute_id],
          @abyssal_mutated_attribute_id
        ),
      depth:
        UnifiedConfig.get(
          [:api, :mutamarket, :abyssal_depth_attribute_id],
          @abyssal_depth_attribute_id
        ),
      mutaplasmid_type:
        UnifiedConfig.get(
          [:api, :mutamarket, :abyssal_mutaplasmid_type_attribute_id],
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
      timeout: Http.janice_timeout(),
      rate_limit: RateLimit.janice_rate_limit()
    ]
  end

  def service_config(:mutamarket) do
    [
      base_url: mutamarket_base_url(),
      endpoints: mutamarket_endpoints(),
      timeout: Http.mutamarket_timeout(),
      abyssal_type_range: abyssal_type_id_range(),
      abyssal_attributes: abyssal_attribute_ids()
    ]
  end

  def service_config(:esi) do
    [
      base_url: esi_base_url(),
      datasource: esi_datasource(),
      timeout: Http.esi_timeout()
    ]
  end

  def service_config(_service), do: []
end
