defmodule EveDmv.Monitoring.MissingDataTracker do
  @moduledoc """
  Tracks missing data in the system, particularly ship types that are not in our database.
  
  This module collects statistics about missing ship types and provides
  reporting capabilities for the monitoring dashboard.
  """
  
  use GenServer
  require Logger
  
  @table_name :missing_data_ets
  @cleanup_interval :timer.hours(24)
  @max_entries 10_000 # Prevent unbounded growth
  
  defmodule MissingShipType do
    @moduledoc false
    defstruct [
      :ship_type_id,
      :first_seen,
      :last_seen,
      :occurrence_count,
      :example_killmail_ids,
      :example_character_names
    ]
  end
  
  # Client API
  
  @doc """
  Start the missing data tracker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Track a missing ship type occurrence.
  """
  def track_missing_ship_type(ship_type_id, metadata) do
    GenServer.cast(__MODULE__, {:track_missing_ship_type, ship_type_id, metadata})
  end
  
  @doc """
  Get statistics for all missing ship types.
  """
  def get_missing_ship_types do
    GenServer.call(__MODULE__, :get_missing_ship_types)
  end
  
  @doc """
  Get count of unique missing ship types.
  """
  def get_missing_ship_types_count do
    GenServer.call(__MODULE__, :get_missing_ship_types_count)
  end
  
  @doc """
  Get top missing ship types by occurrence count.
  """
  def get_top_missing_ship_types(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_top_missing_ship_types, limit})
  end
  
  @doc """
  Clear all tracked data (for testing).
  """
  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end
  
  # Server callbacks
  
  @impl true
  def init(_opts) do
    # Create ETS table for fast concurrent reads
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    # Attach telemetry handlers
    attach_telemetry_handlers()
    
    state = %{
      total_occurrences: 0,
      unique_missing_types: 0
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_cast({:track_missing_ship_type, ship_type_id, metadata}, state) do
    now = DateTime.utc_now()
    
    case :ets.lookup(@table_name, ship_type_id) do
      [{^ship_type_id, existing}] ->
        # Update existing entry
        updated = %{existing |
          last_seen: now,
          occurrence_count: existing.occurrence_count + 1,
          example_killmail_ids: add_to_limited_list(
            existing.example_killmail_ids,
            metadata[:killmail_id],
            5
          ),
          example_character_names: add_to_limited_list(
            existing.example_character_names,
            metadata[:character_name],
            5
          )
        }
        :ets.insert(@table_name, {ship_type_id, updated})
        
      [] ->
        # Create new entry
        new_entry = %MissingShipType{
          ship_type_id: ship_type_id,
          first_seen: now,
          last_seen: now,
          occurrence_count: 1,
          example_killmail_ids: [metadata[:killmail_id]] |> Enum.reject(&is_nil/1),
          example_character_names: [metadata[:character_name]] |> Enum.reject(&is_nil/1)
        }
        :ets.insert(@table_name, {ship_type_id, new_entry})
    end
    
    # Update state counters
    unique_count = :ets.info(@table_name, :size)
    new_state = %{state |
      total_occurrences: state.total_occurrences + 1,
      unique_missing_types: unique_count
    }
    
    # Log warning if we see a spike
    if rem(new_state.total_occurrences, 100) == 0 do
      Logger.warning("Missing ship types: #{new_state.unique_missing_types} unique types, #{new_state.total_occurrences} total occurrences")
    end
    
    {:noreply, new_state}
  end
  
  @impl true
  def handle_call(:get_missing_ship_types, _from, state) do
    missing_types = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, data} -> data end)
    |> Enum.sort_by(& &1.occurrence_count, :desc)
    
    {:reply, missing_types, state}
  end
  
  @impl true
  def handle_call(:get_missing_ship_types_count, _from, state) do
    {:reply, state.unique_missing_types, state}
  end
  
  @impl true
  def handle_call({:get_top_missing_ship_types, limit}, _from, state) do
    top_types = :ets.tab2list(@table_name)
    |> Enum.map(fn {_id, data} -> data end)
    |> Enum.sort_by(& &1.occurrence_count, :desc)
    |> Enum.take(limit)
    
    {:reply, top_types, state}
  end
  
  @impl true
  def handle_call(:clear_all, _from, _state) do
    :ets.delete_all_objects(@table_name)
    
    new_state = %{
      total_occurrences: 0,
      unique_missing_types: 0
    }
    
    {:reply, :ok, new_state}
  end
  
  @impl true
  def handle_info(:cleanup, state) do
    # Limit table size to prevent unbounded growth
    size = :ets.info(@table_name, :size)
    
    if size > @max_entries do
      # Remove least frequent entries
      entries = :ets.tab2list(@table_name)
      |> Enum.map(fn {id, data} -> {id, data} end)
      |> Enum.sort_by(fn {_id, data} -> data.occurrence_count end)
      
      to_remove = Enum.take(entries, size - @max_entries)
      
      Enum.each(to_remove, fn {id, _data} ->
        :ets.delete(@table_name, id)
      end)
      
      Logger.info("Missing data tracker: Cleaned up #{length(to_remove)} entries")
    end
    
    schedule_cleanup()
    {:noreply, state}
  end
  
  # Private functions
  
  defp add_to_limited_list(list, nil, _limit), do: list
  defp add_to_limited_list(list, item, limit) do
    if item in list do
      list
    else
      [item | list] |> Enum.take(limit)
    end
  end
  
  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, @cleanup_interval)
  end
  
  defp attach_telemetry_handlers do
    :telemetry.attach(
      "missing-data-tracker-handler",
      [:eve_dmv, :killmails, :missing_ship_type],
      &__MODULE__.handle_missing_ship_type_telemetry/4,
      nil
    )
  end
  
  @doc false
  def handle_missing_ship_type_telemetry(_event_name, _measurements, metadata, _config) do
    if metadata[:ship_type_id] do
      track_missing_ship_type(metadata[:ship_type_id], metadata)
    end
  end
end