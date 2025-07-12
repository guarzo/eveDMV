# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Enrichment.RealTimePriceUpdater do
  @moduledoc """
  Real-time price update service that monitors for significant price changes
  and broadcasts updates to connected clients via Phoenix PubSub.

  This service works alongside the ReEnrichmentWorker to provide instant
  notifications when killmail values change significantly.
  """

  use GenServer

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Market.PriceService
  alias Phoenix.PubSub

  require Logger

  @pubsub EveDmv.PubSub
  @price_update_topic "price_updates"
  # 5% change threshold
  @significant_change_threshold 0.05

  # Public API

  @doc """
  Start the real-time price updater.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Subscribe to price updates for a specific killmail.
  """
  def subscribe_to_killmail(killmail_id) do
    PubSub.subscribe(@pubsub, "#{@price_update_topic}:#{killmail_id}")
  end

  @doc """
  Subscribe to all price updates.
  """
  def subscribe_to_all_updates do
    PubSub.subscribe(@pubsub, @price_update_topic)
  end

  @doc """
  Manually trigger a price check for specific killmails.
  """
  def check_killmail_prices(killmail_ids) when is_list(killmail_ids) do
    GenServer.cast(__MODULE__, {:check_prices, killmail_ids})
  end

  def check_killmail_prices(killmail_id) do
    check_killmail_prices([killmail_id])
  end

  @doc """
  Update prices for a batch of killmails and broadcast changes.
  """
  def update_batch_with_broadcast(killmails) do
    GenServer.call(__MODULE__, {:update_batch, killmails}, :timer.seconds(30))
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting real-time price updater")

    # Schedule periodic price checks for recent killmails
    schedule_recent_check()

    state = %{
      last_check: DateTime.utc_now(),
      updates_broadcast: 0,
      errors: 0
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:check_prices, killmail_ids}, state) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      check_and_broadcast_prices(killmail_ids)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:update_batch, killmails}, _from, state) do
    results = process_batch_updates(killmails)

    new_state = %{
      state
      | updates_broadcast: state.updates_broadcast + results.broadcast_count,
        last_check: DateTime.utc_now()
    }

    {:reply, results, new_state}
  end

  @impl GenServer
  def handle_info(:check_recent, state) do
    # Check prices for killmails from the last hour
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      check_recent_killmails()
    end)

    # Schedule next check
    schedule_recent_check()

    {:noreply, %{state | last_check: DateTime.utc_now()}}
  end

  # Private functions

  defp schedule_recent_check do
    # Check every 5 minutes for recent killmail price changes
    Process.send_after(self(), :check_recent, :timer.minutes(5))
  end

  defp check_recent_killmails do
    Logger.debug("Checking recent killmails for price updates")

    # Get killmails from the last hour
    one_hour_ago = DateTime.add(DateTime.utc_now(), -3600, :second)

    case get_recent_enriched_killmails(one_hour_ago, 100) do
      {:ok, killmails} ->
        process_batch_updates(killmails)

      {:error, error} ->
        Logger.error("Failed to get recent killmails: #{inspect(error)}")
    end
  end

  defp check_and_broadcast_prices(killmail_ids) do
    Logger.debug("Checking prices for #{length(killmail_ids)} killmails")

    # Load the enriched killmails
    case load_enriched_killmails(killmail_ids) do
      {:ok, killmails} ->
        process_batch_updates(killmails)

      {:error, error} ->
        Logger.error("Failed to load killmails: #{inspect(error)}")
    end
  end

  defp process_batch_updates(killmails) do
    Logger.debug("Processing price updates for #{length(killmails)} killmails")

    results = %{
      processed: 0,
      updated: 0,
      broadcast_count: 0,
      errors: 0
    }

    Enum.reduce(killmails, results, fn killmail, acc ->
      case update_and_broadcast_if_changed(killmail) do
        {:ok, :updated} ->
          %{
            acc
            | processed: acc.processed + 1,
              updated: acc.updated + 1,
              broadcast_count: acc.broadcast_count + 1
          }

        {:ok, :no_change} ->
          %{acc | processed: acc.processed + 1}

        {:error, _reason} ->
          %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
      end
    end)
  end

  defp update_and_broadcast_if_changed(killmail) do
    with {:ok, raw_data} <- get_raw_killmail_data(killmail),
         {:ok, new_prices} <- calculate_new_prices(raw_data),
         {:ok, :changed} <- check_price_change(killmail, new_prices),
         {:ok, updated_killmail} <- update_killmail_prices(killmail, new_prices) do
      broadcast_price_update(updated_killmail, new_prices)
      {:ok, :updated}
    else
      {:ok, :no_change} -> {:ok, :no_change}
      error -> error
    end
  end

  defp get_raw_killmail_data(killmail) do
    case Ash.get(
           EveDmv.Killmails.KillmailRaw,
           [killmail.killmail_id, killmail.killmail_time],
           domain: Api
         ) do
      {:ok, raw_killmail} ->
        {:ok, raw_killmail.raw_data}

      _ ->
        {:error, :raw_data_not_found}
    end
  end

  defp calculate_new_prices(raw_data) do
    price_result = PriceService.calculate_killmail_value(raw_data)
    {:ok, price_result}
  rescue
    error ->
      Logger.error("Error calculating prices: #{inspect(error)}")
      {:error, :calculation_failed}
  end

  defp check_price_change(killmail, new_prices) do
    old_value = Decimal.to_float(killmail.total_value || Decimal.new(0))
    new_value = new_prices.total_value

    change_ratio =
      if old_value > 0 do
        abs(new_value - old_value) / old_value
      else
        # Always update if old value was 0
        1.0
      end

    if change_ratio >= @significant_change_threshold do
      {:ok, :changed}
    else
      {:ok, :no_change}
    end
  end

  defp update_killmail_prices(killmail, new_prices) do
    update_data = %{
      total_value: new_prices.total_value,
      ship_value: new_prices.ship_value,
      fitted_value: new_prices.fitted_value,
      price_data_source: Atom.to_string(new_prices.price_source)
    }

    Ash.update(killmail, update_data, domain: Api)
  end

  defp broadcast_price_update(killmail, new_prices) do
    update_message = %{
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      old_value: killmail.total_value,
      new_value: new_prices.total_value,
      ship_value: new_prices.ship_value,
      fitted_value: new_prices.fitted_value,
      price_source: new_prices.price_source,
      change_percentage:
        calculate_change_percentage(killmail.total_value, new_prices.total_value),
      updated_at: DateTime.utc_now()
    }

    # Broadcast to killmail-specific topic
    PubSub.broadcast(
      @pubsub,
      "#{@price_update_topic}:#{killmail.killmail_id}",
      {:price_updated, update_message}
    )

    # Broadcast to general price updates topic
    PubSub.broadcast(
      @pubsub,
      @price_update_topic,
      {:price_updated, update_message}
    )

    Logger.info(
      "Broadcast price update for killmail #{killmail.killmail_id}: " <>
        "#{format_isk(killmail.total_value)} -> #{format_isk(new_prices.total_value)} " <>
        "(#{update_message.change_percentage}% change)"
    )
  end

  defp calculate_change_percentage(old_value, new_value) do
    old = Decimal.to_float(old_value || Decimal.new(0))

    if old > 0 do
      percentage = (new_value - old) / old * 100
      Float.round(percentage, 2)
    else
      0.0
    end
  end

  defp format_isk(value) when is_float(value) do
    "#{Float.round(value / 1_000_000, 2)}M ISK"
  end

  defp format_isk(%Decimal{} = value) do
    format_isk(Decimal.to_float(value))
  end

  defp format_isk(_), do: "0M ISK"

  defp get_recent_enriched_killmails(_since_datetime, limit) do
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(limit)

    Ash.read(query, domain: Api)
  end

  defp load_enriched_killmails(_killmail_ids) do
    query =
      Ash.Query.new(KillmailRaw)

    Ash.read(query, domain: Api)
  end
end
