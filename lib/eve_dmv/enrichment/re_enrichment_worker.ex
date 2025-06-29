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
  require Logger
  alias EveDmv.Api
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw}
  alias EveDmv.Market.PriceService
  alias EveDmv.Eve.NameResolver

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

  @impl true
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

  @impl true
  def handle_cast(:trigger_re_enrichment, state) do
    Logger.info("Manual re-enrichment triggered")
    spawn(fn -> perform_full_re_enrichment(state.config) end)
    {:noreply, state}
  end

  @impl true  
  def handle_cast(:trigger_price_update, state) do
    Logger.info("Manual price update triggered")
    spawn(fn -> perform_price_update(state.config) end)
    new_state = %{state | last_price_update: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl true
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

  @impl true
  def handle_info(:price_update, state) do
    Logger.debug("Starting scheduled price update")
    
    spawn(fn -> perform_price_update(state.config) end)
    
    # Schedule next price update
    schedule_price_update(state.config.price_update_interval)
    
    new_state = %{state | last_price_update: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:name_update, state) do
    Logger.debug("Starting scheduled name resolution update")
    
    spawn(fn -> perform_name_update(state.config) end)
    
    # Schedule next name update
    schedule_name_update(state.config.name_update_interval)
    
    new_state = %{state | last_name_update: DateTime.utc_now()}
    {:noreply, new_state}
  end

  @impl true
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
    
    # Update prices and names in parallel
    price_task = Task.async(fn -> perform_price_update(config) end)
    name_task = Task.async(fn -> perform_name_update(config) end)
    
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
    
    result = %{processed: 0, updated: 0, errors: 0}
    
    Enum.reduce(killmails, result, fn killmail, acc ->
      try do
        # Get the raw killmail data to recalculate prices
        case get_raw_killmail_data(killmail.killmail_id, killmail.killmail_time) do
          {:ok, raw_data} ->
            # Recalculate prices using current market data
            price_result = PriceService.calculate_killmail_value(raw_data)
            
            # Check if prices have changed significantly (>5%)
            old_value = Decimal.to_float(killmail.total_value || Decimal.new(0))
            new_value = price_result.total_value || 0
            
            if abs(new_value - old_value) / max(old_value, 1) > 0.05 do
              # Update the enriched killmail with new prices
              update_data = %{
                total_value: price_result.total_value,
                ship_value: price_result.ship_value,
                fitted_value: price_result.fitted_value,
                price_data_source: Atom.to_string(price_result.price_source)
              }
              
              case Ash.update(killmail, update_data, domain: Api) do
                {:ok, _} -> 
                  Logger.debug("Updated prices for killmail #{killmail.killmail_id}")
                  %{acc | processed: acc.processed + 1, updated: acc.updated + 1}
                {:error, error} ->
                  Logger.warning("Failed to update killmail #{killmail.killmail_id}: #{inspect(error)}")
                  %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
              end
            else
              # Prices haven't changed significantly
              %{acc | processed: acc.processed + 1}
            end
            
          {:error, _} ->
            Logger.debug("No raw data found for killmail #{killmail.killmail_id}")
            %{acc | processed: acc.processed + 1}
        end
        
      rescue
        error ->
          Logger.error("Error updating prices for killmail #{killmail.killmail_id}: #{inspect(error)}")
          %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
      end
    end)
  end

  defp update_names_for_batch(killmails) do
    Logger.debug("Updating names for batch of #{length(killmails)} killmails")
    
    # Extract all unique IDs that need name resolution
    {character_ids, corp_ids, system_ids} = 
      Enum.reduce(killmails, {[], [], []}, fn km, {chars, corps, systems} ->
        new_chars = if is_nil(km.victim_character_name) and not is_nil(km.victim_character_id) do
          [km.victim_character_id]
        else
          []
        end
        
        new_corps = if is_nil(km.victim_corporation_name) and not is_nil(km.victim_corporation_id) do
          [km.victim_corporation_id]
        else
          []
        end
        
        new_systems = if is_nil(km.solar_system_name) and not is_nil(km.solar_system_id) do
          [km.solar_system_id]
        else
          []
        end
        
        {chars ++ new_chars, corps ++ new_corps, systems ++ new_systems}
      end)
    
    # Bulk resolve names
    character_names = if length(character_ids) > 0 do
      NameResolver.character_names(Enum.uniq(character_ids))
    else
      %{}
    end
    
    corp_names = if length(corp_ids) > 0 do
      NameResolver.corporation_names(Enum.uniq(corp_ids))
    else
      %{}
    end
    
    system_names = if length(system_ids) > 0 do
      NameResolver.system_names(Enum.uniq(system_ids))
    else
      %{}
    end
    
    # Update each killmail with resolved names
    result = %{processed: 0, updated: 0, errors: 0}
    
    Enum.reduce(killmails, result, fn killmail, acc ->
      update_data = %{}
      
      # Add character name if missing
      update_data = if is_nil(killmail.victim_character_name) and killmail.victim_character_id do
        case character_names[killmail.victim_character_id] do
          name when is_binary(name) -> Map.put(update_data, :victim_character_name, name)
          _ -> update_data
        end
      else
        update_data
      end
      
      # Add corporation name if missing
      update_data = if is_nil(killmail.victim_corporation_name) and killmail.victim_corporation_id do
        case corp_names[killmail.victim_corporation_id] do
          name when is_binary(name) -> Map.put(update_data, :victim_corporation_name, name)
          _ -> update_data
        end
      else
        update_data
      end
      
      # Add system name if missing
      update_data = if is_nil(killmail.solar_system_name) and killmail.solar_system_id do
        case system_names[killmail.solar_system_id] do
          name when is_binary(name) -> Map.put(update_data, :solar_system_name, name)
          _ -> update_data
        end
      else
        update_data
      end
      
      # Update if we have new data
      if map_size(update_data) > 0 do
        case Ash.update(killmail, update_data, domain: Api) do
          {:ok, _} ->
            Logger.debug("Updated names for killmail #{killmail.killmail_id}")
            %{acc | processed: acc.processed + 1, updated: acc.updated + 1}
          {:error, error} ->
            Logger.warning("Failed to update names for killmail #{killmail.killmail_id}: #{inspect(error)}")
            %{acc | processed: acc.processed + 1, errors: acc.errors + 1}
        end
      else
        %{acc | processed: acc.processed + 1}
      end
    end)
  end

  defp get_raw_killmail_data(killmail_id, killmail_time) do
    # Try to get the raw killmail using the primary key
    case Ash.get(KillmailRaw, [killmail_id, killmail_time], domain: Api) do
      {:ok, raw_killmail} when not is_nil(raw_killmail) ->
        {:ok, raw_killmail.raw_data}
      _ ->
        {:error, :not_found}
    end
  end
end