defmodule EveDmv.Contexts.MarketIntelligence do
  use EveDmv.Contexts.BoundedContext, name: :market_intelligence
  use Supervisor

    alias EveDmv.Contexts.MarketIntelligence.Api
  alias EveDmv.Contexts.MarketIntelligence.Domain
  alias EveDmv.Contexts.MarketIntelligence.Infrastructure
  alias EveDmv.DomainEvents.StaticDataUpdated
  @moduledoc """
  Market Intelligence bounded context.

  Responsible for:
  - Item price discovery and caching
  - Market trend analysis
  - Value calculations for killmails and fleets
  - Integration with external pricing services (Janice, Mutamarket)

  This context serves as a pilot implementation of the DDD approach.
  """



  # Supervisor implementation

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Domain services
      Domain.PriceService,
      Domain.MarketAnalyzer,

      # Infrastructure
      Infrastructure.PriceCache,
      Infrastructure.ExternalPriceClient
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Event subscriptions

  @impl true
  def event_subscriptions do
    [
      {:static_data_updated, &handle_static_data_updated/1}
    ]
  end

  # Event handlers

  def handle_static_data_updated(%StaticDataUpdated{categories_updated: categories}) do
    if :item_types in categories do
      # Invalidate price cache for updated items
      Infrastructure.PriceCache.invalidate_all()

      # Trigger price refresh for commonly used items
      Domain.PriceService.refresh_common_items()
    end
  end

  # Public API delegation

  defdelegate get_price(type_id), to: Api
  defdelegate get_price(type_id, options), to: Api
  defdelegate get_prices(type_ids), to: Api
  defdelegate calculate_killmail_value(killmail), to: Api
  defdelegate calculate_fleet_value(ships), to: Api
  defdelegate analyze_market_trends(type_ids, period), to: Api
end
