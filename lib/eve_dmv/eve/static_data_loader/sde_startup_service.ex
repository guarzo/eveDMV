defmodule EveDmv.Eve.StaticDataLoader.SdeStartupService do
  @moduledoc """
  GenServer that automatically checks for SDE updates on application startup.
  
  This service runs once during startup and checks if new SDE data is available.
  If updates are found, it automatically downloads and processes the new data.
  """
  
  use GenServer
  
  alias EveDmv.Eve.StaticDataLoader.SdeVersionManager
  
  require Logger
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    # Check if SDE updates are enabled
    enabled = Application.get_env(:eve_dmv, :sde_auto_update, true)
    
    if enabled do
      # Schedule the update check to run after startup
      Process.send_after(self(), :check_sde_updates, 5_000)
    else
      Logger.info("SDE auto-update disabled in configuration")
    end
    
    {:ok, %{enabled: enabled, last_check: nil}}
  end
  
  def handle_info(:check_sde_updates, state) do
    Logger.info("Starting SDE update check on startup...")
    
    case SdeVersionManager.check_for_updates() do
      {:ok, :up_to_date} ->
        Logger.info("SDE data is up to date")
        
      {:ok, results} ->
        Logger.info("SDE update completed successfully: #{inspect(results)}")
        
      {:error, reason} ->
        Logger.error("SDE update failed: #{inspect(reason)}")
    end
    
    {:noreply, %{state | last_check: DateTime.utc_now()}}
  end
  
  def handle_call(:force_update, _from, state) do
    Logger.info("Forcing SDE update check...")
    
    result = SdeVersionManager.check_for_updates()
    
    {:reply, result, %{state | last_check: DateTime.utc_now()}}
  end
  
  def handle_call(:get_status, _from, state) do
    status = %{
      enabled: state.enabled,
      last_check: state.last_check,
      service_running: true
    }
    
    {:reply, status, state}
  end
  
  # Public API
  
  def force_update do
    GenServer.call(__MODULE__, :force_update, 30_000)
  end
  
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
end