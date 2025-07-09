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
      # :phases, :events, :fleet
      |> assign(:timeline_view, :phases)
      # Manual ship side assignments
      |> assign(:ship_side_assignments, %{})
      # Toggle for edit mode
      |> assign(:editing_fleet_sides, false)
      # Default sides
      |> assign(:custom_sides, ["side_1", "side_2"])
      # Corporation statistics
      |> assign(:corp_summaries, %{})
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
  def handle_event("toggle_fleet_edit_mode", _, socket) do
    {:noreply, assign(socket, :editing_fleet_sides, !socket.assigns.editing_fleet_sides)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "cycle_ship_side",
        %{"ship_id" => pilot_ship_id, "current_side" => current_side},
        socket
      ) do
    # Get all available sides including "unassigned"
    all_sides = socket.assigns.custom_sides ++ ["unassigned"]
    current_index = Enum.find_index(all_sides, &(&1 == current_side)) || 0
    next_index = rem(current_index + 1, length(all_sides))
    next_side = Enum.at(all_sides, next_index)

    ship_side_assignments =
      if next_side == "unassigned" do
        # Remove assignment to go back to automatic
        Map.delete(socket.assigns.ship_side_assignments, pilot_ship_id)
      else
        Map.put(socket.assigns.ship_side_assignments, pilot_ship_id, next_side)
      end

    {:noreply, assign(socket, :ship_side_assignments, ship_side_assignments)}
  end

  @impl Phoenix.LiveView
  def handle_event("add_custom_side", _, socket) do
    new_side_num = length(socket.assigns.custom_sides) + 1
    new_side = "side_#{new_side_num}"
    custom_sides = socket.assigns.custom_sides ++ [new_side]
    {:noreply, assign(socket, :custom_sides, custom_sides)}
  end

  @impl Phoenix.LiveView
  def handle_event("reset_fleet_sides", _, socket) do
    socket =
      socket
      |> assign(:ship_side_assignments, %{})
      |> assign(:custom_sides, ["side_1", "side_2"])
      |> assign(:editing_fleet_sides, false)

    {:noreply, socket}
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
        # Only show significant battles (multiple kills OR lasting > 2 minutes)
        significant_battles =
          battles
          |> Enum.filter(fn b ->
            length(b.killmails) > 1 or
              b.metadata.duration_minutes >= 2
          end)
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
        |> update_battle_sides()

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
      nil ->
        nil

      weapon_id ->
        weapon_name = NameResolver.item_name(weapon_id)
        if String.starts_with?(weapon_name, "Unknown"), do: nil, else: weapon_name
    end
  end

  # Get ship class from type ID (simplified mapping)
  # Format ISK values in short form (1.2B, 850M, etc)
  def format_isk_short(value) when is_number(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{round(value)}"
    end
  end

  def format_isk_short(_), do: "0"

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

  # Get effective ship side (manual assignment or automatic)
  def get_ship_side(pilot, ship_side_assignments) do
    # Use character_id and ship_type_id for unique pilot/ship combo
    pilot_key = "pilot_#{pilot.character_id}_#{pilot.ship_type_id}"

    case Map.get(ship_side_assignments, pilot_key) do
      nil ->
        # Use automatic side detection based on pilot's analyzed side
        pilot[:side] || "unassigned"

      manual_side ->
        manual_side
    end
  end

  # Get ships for a specific side
  def get_ships_for_side(pilots, side, ship_side_assignments) do
    Enum.filter(pilots || [], fn pilot ->
      get_ship_side(pilot, ship_side_assignments) == side
    end)
  end

  # Update battle sides based on detected sides in timeline
  defp update_battle_sides(socket) do
    battle = socket.assigns.current_battle

    if battle && battle.timeline do
      # Get all unique sides from the pilot assignments
      pilot_sides =
        battle.timeline.fleet_composition
        |> Enum.flat_map(fn window ->
          window[:pilot_ships] || []
        end)
        |> Enum.map(& &1[:side])
        |> Enum.filter(&(&1 && &1 != "unassigned"))
        |> Enum.uniq()
        |> Enum.sort()

      # Also get sides from the battle analysis
      battle_sides =
        battle.timeline.fleet_composition
        |> Enum.flat_map(fn window -> window[:sides] || [] end)
        |> Enum.map(& &1.side_id)
        |> Enum.uniq()
        |> Enum.sort()

      # Combine both sources of sides
      all_sides = (pilot_sides ++ battle_sides) |> Enum.uniq() |> Enum.sort()

      # Use detected sides or default to side_1, side_2
      custom_sides = if length(all_sides) > 0, do: all_sides, else: ["side_1", "side_2"]

      # Calculate corporation summaries
      corp_summaries = calculate_corp_summaries(battle)

      socket
      |> assign(:custom_sides, custom_sides)
      |> assign(:corp_summaries, corp_summaries)
    else
      socket
    end
  end

  # Calculate corporation kill/loss/ISK statistics
  defp calculate_corp_summaries(battle) do
    if battle && battle.timeline && battle.timeline.events do
      Enum.reduce(battle.timeline.events, %{}, fn event, acc ->
        # Process victim corporation
        victim_corp = event.victim.corporation_id
        victim_value = event[:isk_value] || 0

        acc =
          if victim_corp do
            Map.update(
              acc,
              victim_corp,
              %{
                kills: 0,
                losses: 1,
                isk_destroyed: 0,
                isk_lost: victim_value,
                name: event.victim.corporation_name
              },
              fn stats ->
                %{stats | losses: stats.losses + 1, isk_lost: stats.isk_lost + victim_value}
              end
            )
          else
            acc
          end

        # Process attacker corporations - accumulate in acc properly
        event.attackers
        |> Enum.filter(& &1.corporation_id)
        |> Enum.reduce(acc, fn attacker, acc2 ->
          # Distribute victim value among all attackers
          attacker_share =
            if length(event.attackers) > 0 do
              victim_value / length(event.attackers)
            else
              0
            end

          Map.update(
            acc2,
            attacker.corporation_id,
            %{
              kills: if(attacker.final_blow, do: 1, else: 0),
              losses: 0,
              isk_destroyed: attacker_share,
              isk_lost: 0,
              name: attacker.corporation_name
            },
            fn stats ->
              %{
                stats
                | kills: stats.kills + if(attacker.final_blow, do: 1, else: 0),
                  isk_destroyed: stats.isk_destroyed + attacker_share
              }
            end
          )
        end)
      end)
    else
      %{}
    end
  end
end
