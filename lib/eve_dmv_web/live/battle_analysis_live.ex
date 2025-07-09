defmodule EveDmvWeb.BattleAnalysisLive do
  @moduledoc """
  LiveView for battle analysis and tactical intelligence.

  Provides real-time battle analysis, fleet composition breakdowns,
  tactical recommendations, and historical battle comparisons.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Eve.NameResolver

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Battle Analysis")
      |> assign(:import_url, "")
      |> assign(:importing, false)
      |> assign(:current_battle, nil)
      |> assign(:recent_battles, [])
      |> assign(:error_message, nil)
      |> assign(:selected_phase, nil)
      |> assign(:timeline_view, :phases)  # :phases, :events, :fleet
      |> load_recent_battles()
    
    {:ok, socket}
  end
  
  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    socket = 
      case params do
        %{"battle_id" => battle_id} ->
          load_battle(socket, battle_id)
        _ ->
          socket
      end
    
    {:noreply, socket}
  end
  
  @impl Phoenix.LiveView
  def handle_event("import_zkillboard", %{"url" => url}, socket) do
    socket =
      socket
      |> assign(:importing, true)
      |> assign(:error_message, nil)
    
    # Run import in background
    self = self()
    Task.start(fn ->
      result = BattleAnalysis.import_from_zkillboard(url)
      send(self, {:import_complete, result})
    end)
    
    {:noreply, socket}
  end
  
  @impl Phoenix.LiveView
  def handle_event("select_battle", %{"battle_id" => battle_id}, socket) do
    {:noreply, load_battle(socket, battle_id)}
  end
  
  @impl Phoenix.LiveView
  def handle_event("select_phase", %{"phase_index" => phase_index}, socket) do
    phase_idx = String.to_integer(phase_index)
    phase = Enum.at(socket.assigns.current_battle.timeline.phases, phase_idx)
    
    {:noreply, assign(socket, :selected_phase, phase)}
  end
  
  @impl Phoenix.LiveView
  def handle_event("change_timeline_view", %{"view" => view}, socket) do
    view_atom = String.to_existing_atom(view)
    {:noreply, assign(socket, :timeline_view, view_atom)}
  end
  
  @impl Phoenix.LiveView
  def handle_info({:import_complete, result}, socket) do
    socket =
      socket
      |> assign(:importing, false)
      |> assign(:import_url, "")
    
    socket =
      case result do
        {:ok, %{battle_id: _} = battle} ->
          socket
          |> assign(:current_battle, battle)
          |> push_patch(to: ~p"/battle/#{battle.battle_id}")
          |> load_recent_battles()
        
        {:ok, %{battles: battles}} ->
          # Multiple battles imported
          first_battle = List.first(battles)
          socket
          |> assign(:current_battle, first_battle)
          |> push_patch(to: ~p"/battle/#{first_battle.battle_id}")
          |> load_recent_battles()
        
        {:error, reason} ->
          error_msg = format_error(reason)
          assign(socket, :error_message, error_msg)
      end
    
    {:noreply, socket}
  end
  
  # Private functions
  
  defp load_recent_battles(socket) do
    case BattleAnalysis.detect_recent_battles(48, min_participants: 2) do
      {:ok, battles} ->
        # Only show battles with multiple kills
        significant_battles = 
          battles
          |> Enum.filter(fn b -> length(b.killmails) > 1 end)
          |> Enum.take(20)
        
        assign(socket, :recent_battles, significant_battles)
      
      _ ->
        socket
    end
  end
  
  defp load_battle(socket, battle_id) do
    case BattleAnalysis.get_battle_with_timeline(battle_id) do
      {:ok, battle} ->
        socket
        |> assign(:current_battle, battle)
        |> assign(:selected_phase, nil)
        |> assign(:error_message, nil)
      
      {:error, :battle_not_found} ->
        assign(socket, :error_message, "Battle not found")
      
      _ ->
        assign(socket, :error_message, "Failed to load battle")
    end
  end
  
  defp format_error(:invalid_zkillboard_url), do: "Invalid zkillboard URL"
  defp format_error(:unsupported_url_format), do: "Unsupported zkillboard URL format"
  defp format_error({:http_error, _}), do: "Failed to connect to zkillboard"
  defp format_error({:api_error, status}), do: "zkillboard API error (#{status})"
  defp format_error(_), do: "Import failed"
  
  # View helpers (these should be in the template but included here for completeness)
  
  def format_timestamp(nil), do: ""
  def format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%H:%M:%S")
  end
  
  def format_duration(minutes) when is_number(minutes) do
    total_mins = round(minutes)
    hours = div(total_mins, 60)
    mins = rem(total_mins, 60)
    
    cond do
      total_mins <= 0 -> "<1m"
      hours > 0 -> "#{hours}h #{mins}m"
      mins > 0 -> "#{mins}m"
      true -> "<1m"
    end
  end
  def format_duration(_), do: "0m"
  
  def format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
  def format_number(number) when is_float(number) do
    number |> round() |> format_number()
  end
  def format_number(_), do: "0"
  
  def phase_class(phase_type) do
    case phase_type do
      :initial_engagement -> "bg-red-900"
      :escalation -> "bg-orange-900"
      :cleanup -> "bg-gray-800"
      _ -> "bg-gray-900"
    end
  end
  
  def format_phase_type(phase_type) do
    phase_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
  
  # Name resolution helpers
  def resolve_system_name(system_id) when is_integer(system_id) do
    NameResolver.system_name(system_id)
  end
  def resolve_system_name(_), do: "Unknown System"
  
  def resolve_character_name(character_id) when is_integer(character_id) do
    NameResolver.character_name(character_id)
  end
  def resolve_character_name(_), do: "Unknown"
  
  def resolve_ship_name(type_id) when is_integer(type_id) do
    NameResolver.ship_name(type_id)
  end
  def resolve_ship_name(_), do: "Unknown Ship"
  
  def resolve_corporation_name(corp_id) when is_integer(corp_id) do
    NameResolver.corporation_name(corp_id)
  end
  def resolve_corporation_name(_), do: "Unknown Corp"
  
  def resolve_alliance_name(alliance_id) when is_integer(alliance_id) do
    NameResolver.alliance_name(alliance_id)
  end
  def resolve_alliance_name(_), do: nil
  
  # Portrait/icon URLs
  def character_portrait(character_id, size \\ 64) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end
  
  def corporation_logo(corp_id, size \\ 64) do
    "https://images.evetech.net/corporations/#{corp_id}/logo?size=#{size}"
  end
  
  def alliance_logo(alliance_id, size \\ 64) do
    "https://images.evetech.net/alliances/#{alliance_id}/logo?size=#{size}"
  end
  
  def ship_render(type_id, size \\ 64) do
    "https://images.evetech.net/types/#{type_id}/render?size=#{size}"
  end
  
  # Get weapon name from attacker data
  def get_weapon_name(attacker) do
    case attacker[:weapon_type_id] do
      nil -> nil
      weapon_id -> 
        weapon_name = NameResolver.item_name(weapon_id)
        if String.starts_with?(weapon_name, "Unknown"), do: nil, else: weapon_name
    end
  end
  
  # Get ship class from type ID (simplified mapping)
  def ship_class_from_id(type_id) when is_integer(type_id) do
    # This is a simplified mapping - in production would use SDE data
    cond do
      type_id in 582..650 -> "Frigate"
      type_id in 324..380 -> "Destroyer"
      type_id in 620..634 -> "Cruiser"
      type_id in 1201..1310 -> "Battlecruiser"
      type_id in 638..645 -> "Battleship"
      type_id in 547..554 -> "Carrier"
      type_id in 671..671 -> "Dreadnought"
      type_id in 3514..3518 -> "Titan"
      type_id in 11567..12034 -> "Tech 3 Cruiser"
      type_id in 29984..29990 -> "Tech 3 Destroyer"
      type_id in 35779..35781 -> "Triglavian"
      true -> "Ship"
    end
  end
  def ship_class_from_id(_), do: "Unknown"
end