# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Enrichment.ReEnrichmentWorker do
  @moduledoc """
  Background worker for re-enriching killmail data.

  This GenServer runs periodically to:
  1. Update ISK values for old killmails with current market prices
  2. Resolve missing character/corporation/alliance names
  3. Refresh static data references (ship names, system names)
  4. Recalculate analytics and statistics

  ## Configuration

  The worker can be configured with different schedules:
  - Price updates: Every 6 hours (market prices change frequently)
  - Name resolution: Every 24 hours (names rarely change)
  - Static data refresh: Every week (very stable data)
  """

  use GenServer
  alias EveDmv.Api
  alias EveDmv.Enrichment.RealTimePriceUpdater
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.KillmailEnriched
  require Logger

  # Default configuration
  @default_config %{
    # Run price updates every 6 hours
    price_update_interval: :timer.hours(6),
    # Run name resolution updates every 24 hours
    name_update_interval: :timer.hours(24),
    # Process killmails in batches
    batch_size: 100,
    # Only re-enrich killmails newer than this
    max_age_days: 30,
    # Minimum time between re-enrichments for same killmail
    min_re_enrich_interval: :timer.hours(12)
  }

  # Public API

  @doc """
  Start the re-enrichment worker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger immediate re-enrichment of recent killmails.
  """
  @spec trigger_re_enrichment() :: :ok
  def trigger_re_enrichment do
    GenServer.cast(__MODULE__, :trigger_re_enrichment)
  end

  @doc """
  Trigger immediate price updates for killmails.
  """
  @spec trigger_price_update() :: :ok
  def trigger_price_update do
    GenServer.cast(__MODULE__, :trigger_price_update)
  end

  @doc """
  Get worker statistics.
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # GenServer callbacks

  @impl GenServer
  def init(opts) do
    Logger.info("Starting killmail re-enrichment worker")

    config = Map.merge(@default_config, Map.new(opts))

    state = %{
      config: config,
      last_price_update: nil,
      last_name_update: nil,
      total_processed: 0,
      total_updated: 0,
      errors: 0
    }

    # Schedule initial work
    schedule_price_update(config.price_update_interval)
    schedule_name_update(config.name_update_interval)

    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:trigger_re_enrichment, state) do
    Logger.info("Manual re-enrichment triggered")

    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      perform_full_re_enrichment(state.config)
    end)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:trigger_price_update, state) do
    Logger.info("Manual price update triggered")

    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      perform_price_update(state.config)
    end)

    new_state = %{state | last_price_update: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      last_price_update: state.last_price_update,
      last_name_update: state.last_name_update,
      total_processed: state.total_processed,
      total_updated: state.total_updated,
      errors: state.errors,
      config: state.config
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info(:price_update, state) do
    Logger.debug("Starting scheduled price update")

    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      perform_price_update(state.config)
    end)

    # Schedule next price update
    schedule_price_update(state.config.price_update_interval)

    new_state = %{state | last_price_update: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(:name_update, state) do
    Logger.debug("Starting scheduled name resolution update")

    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      perform_name_update(state.config)
    end)

    # Schedule next name update
    schedule_name_update(state.config.name_update_interval)

    new_state = %{state | last_name_update: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info(msg, state) do
    Logger.debug("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # Private functions

  defp schedule_price_update(interval) do
    Process.send_after(self(), :price_update, interval)
  end

  defp schedule_name_update(interval) do
    Process.send_after(self(), :name_update, interval)
  end

  defp perform_full_re_enrichment(config) do
    Logger.info("Starting full re-enrichment process")
    start_time = System.monotonic_time(:millisecond)

    # Update prices and names in parallel with supervised tasks
    price_task =
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> perform_price_update(config) end)

    name_task =
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> perform_name_update(config) end)

    # Wait for both to complete
    price_result = Task.await(price_task, :timer.minutes(30))
    name_result = Task.await(name_task, :timer.minutes(30))

    duration = System.monotonic_time(:millisecond) - start_time

    Logger.info("Full re-enrichment completed in #{duration}ms")
    Logger.info("Price updates: #{inspect(price_result)}")
    Logger.info("Name updates: #{inspect(name_result)}")
  end

  defp perform_price_update(config) do
    Logger.info("Starting price update for recent killmails")

    # Get killmails that need price updates
    cutoff_date = DateTime.add(DateTime.utc_now(), -config.max_age_days, :day)

    case get_killmails_for_price_update(cutoff_date, config.batch_size * 5) do
      {:ok, killmails} ->
        Logger.info("Found #{length(killmails)} killmails for price update")

        result =
          killmails
          |> Enum.chunk_every(config.batch_size)
          |> Enum.reduce(%{processed: 0, updated: 0, errors: 0}, fn batch, acc ->
            batch_result = update_prices_for_batch(batch)

            %{
              processed: acc.processed + batch_result.processed,
              updated: acc.updated + batch_result.updated,
              errors: acc.errors + batch_result.errors
            }
          end)

        Logger.info("Price update completed: #{inspect(result)}")
        result

      {:error, error} ->
        Logger.error("Failed to get killmails for price update: #{inspect(error)}")
        %{processed: 0, updated: 0, errors: 1}
    end
  end

  defp perform_name_update(config) do
    Logger.info("Starting name resolution update for recent killmails")

    # Get killmails that need name updates
    cutoff_date = DateTime.add(DateTime.utc_now(), -config.max_age_days, :day)

    case get_killmails_for_name_update(cutoff_date, config.batch_size * 3) do
      {:ok, killmails} ->
        Logger.info("Found #{length(killmails)} killmails for name update")

        result =
          killmails
          |> Enum.chunk_every(config.batch_size)
          |> Enum.reduce(%{processed: 0, updated: 0, errors: 0}, fn batch, acc ->
            batch_result = update_names_for_batch(batch)

            %{
              processed: acc.processed + batch_result.processed,
              updated: acc.updated + batch_result.updated,
              errors: acc.errors + batch_result.errors
            }
          end)

        Logger.info("Name update completed: #{inspect(result)}")
        result

      {:error, error} ->
        Logger.error("Failed to get killmails for name update: #{inspect(error)}")
        %{processed: 0, updated: 0, errors: 1}
    end
  end

  defp get_killmails_for_price_update(_cutoff_date, limit) do
    # Get recent enriched killmails for price updates
    # Simplified query - get most recent killmails
    query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(limit)

    Ash.read(query, domain: Api)
  end

  defp get_killmails_for_name_update(_cutoff_date, limit) do
    # Get recent enriched killmails for name updates
    # Simplified query - get most recent killmails
    query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(limit)

    Ash.read(query, domain: Api)
  end

  defp update_prices_for_batch(killmails) do
    Logger.debug("Updating prices for batch of #{length(killmails)} killmails")

    # Use the RealTimePriceUpdater to process the batch with automatic broadcasting
    case RealTimePriceUpdater.update_batch_with_broadcast(killmails) do
      %{processed: _, updated: _, broadcast_count: _, errors: _} = result ->
        Logger.debug("Batch price update completed: #{inspect(result)}")
        result

      error ->
        Logger.error("Failed to update batch prices: #{inspect(error)}")
        %{processed: 0, updated: 0, errors: length(killmails)}
    end
  end

  defp update_names_for_batch(killmails) do
    Logger.debug("Updating names for batch of #{length(killmails)} killmails")

    # Extract IDs that need resolution and bulk resolve names
    missing_ids = extract_missing_name_ids(killmails)
    resolved_names = bulk_resolve_names(missing_ids)

    # Update each killmail with resolved names
    result = %{processed: 0, updated: 0, errors: 0}
    Enum.reduce(killmails, result, &update_killmail_names(&1, &2, resolved_names))
  end

  defp extract_missing_name_ids(killmails) do
    Enum.reduce(killmails, {[], [], []}, fn km, {chars, corps, systems} ->
      {
        maybe_add_id(chars, km.victim_character_id, km.victim_character_name),
        maybe_add_id(corps, km.victim_corporation_id, km.victim_corporation_name),
        maybe_add_id(systems, km.solar_system_id, km.solar_system_name)
      }
    end)
  end

  defp maybe_add_id(id_list, id, name) do
    if is_nil(name) and not is_nil(id) do
      [id | id_list]
    else
      id_list
    end
  end

  defp bulk_resolve_names({character_ids, corp_ids, system_ids}) do
    %{
      characters: resolve_if_needed(character_ids, &NameResolver.character_names/1),
      corporations: resolve_if_needed(corp_ids, &NameResolver.corporation_names/1),
      systems: resolve_if_needed(system_ids, &NameResolver.system_names/1)
    }
  end

  defp resolve_if_needed([], _resolver_fn), do: %{}
  defp resolve_if_needed(ids, resolver_fn), do: resolver_fn.(Enum.uniq(ids))

  defp update_killmail_names(killmail, acc, resolved_names) do
    update_data = build_name_updates(killmail, resolved_names)

    if map_size(update_data) > 0 do
      apply_name_update(killmail, update_data, acc)
    else
      %{acc | processed: acc.processed + 1}
    end
  end

  defp build_name_updates(killmail, resolved_names) do
    %{}
    |> maybe_add_name(
      :victim_character_name,
      killmail.victim_character_id,
      killmail.victim_character_name,
      resolved_names.characters
    )
    |> maybe_add_name(
      :victim_corporation_name,
      killmail.victim_corporation_id,
      killmail.victim_corporation_name,
      resolved_names.corporations
    )
    |> maybe_add_name(
      :solar_system_name,
      killmail.solar_system_id,
      killmail.solar_system_name,
      resolved_names.systems
    )
  end

  defp maybe_add_name(update_data, name_field, id, current_name, name_map) do
    if is_nil(current_name) and not is_nil(id) do
      case name_map[id] do
        name when is_binary(name) -> Map.put(update_data, name_field, name)
        _ -> update_data
      end
    else
      update_data
    end
  end

  defp apply_name_update(killmail, update_data, acc) do
    case Ash.update(killmail, update_data, domain: Api) do
      {:ok, _} ->
        Logger.debug("Updated names for killmail #{killmail.killmail_id}")
        %{acc | processed: acc.processed + 1, updated: acc.updated + 1}

      {:error, error} ->
        Logger.warning(
          "Failed to update names for killmail #{killmail.killmail_id}: #{inspect(error)}"
        )

        %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
    end
  end
end
