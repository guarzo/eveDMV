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
      # Recently viewed battles (from ETS cache)
      |> assign(:recently_viewed_battles, load_recently_viewed_battles())
      # Pilot suggestions for autocomplete
      |> assign(:pilot_suggestions, [])
      |> assign(:show_pilot_suggestions, false)
      |> assign(:error_message, nil)
      |> assign(:selected_phase, nil)
      # Main tabs: :metrics, :ship_performance, :timeline, :fleet
      |> assign(:main_view, :metrics)
      # Timeline subtabs: :phases, :events, :fleet
      |> assign(:timeline_view, :phases)
      # Manual ship side assignments
      |> assign(:ship_side_assignments, %{})
      # Toggle for edit mode
      |> assign(:editing_fleet_sides, false)
      # Default sides
      |> assign(:custom_sides, ["side_1", "side_2"])
      # Corporation statistics
      |> assign(:corp_summaries, %{})
      # Combat logs for current battle
      |> assign(:combat_logs, [])
      # Toggle for upload form
      |> assign(:show_log_upload, false)
      # Upload errors
      |> assign(:log_upload_errors, [])
      # Pilot name for upload
      |> assign(:pilot_name, "")
      # Ship performance analysis
      |> assign(:selected_ship, nil)
      |> assign(:ship_performance, nil)
      |> assign(:show_fitting_import, false)
      # Fitting cache now uses ETS table :battle_fitting_cache
      # Battle metrics
      |> assign(:battle_metrics, nil)
      |> assign(:show_metrics_dashboard, true)
      |> allow_upload(:combat_log,
        accept: ~w(.txt),
        max_entries: 1,
        # 10MB limit
        max_file_size: 10_000_000
      )
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
  def handle_event("change_main_view", %{"view" => view}, socket) do
    view_atom = String.to_existing_atom(view)
    {:noreply, assign(socket, :main_view, view_atom)}
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
  def handle_event("toggle_log_upload", _, socket) do
    socket = 
      socket
      |> assign(:show_log_upload, !socket.assigns.show_log_upload)
      |> assign(:pilot_name, "")  # Clear pilot name when toggling
    
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("validate_log", %{"pilot_name" => pilot_name} = _params, socket) do
    # Store pilot name so it doesn't get cleared
    {:noreply, assign(socket, :pilot_name, pilot_name)}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_pilot_suggestions", %{"value" => search_term}, socket) do
    if String.length(search_term) >= 1 do
      suggestions = get_pilot_suggestions(socket.assigns.current_battle, search_term)
      socket = 
        socket
        |> assign(:pilot_suggestions, suggestions)
        |> assign(:show_pilot_suggestions, length(suggestions) > 0)
        |> assign(:pilot_name, search_term)
      {:noreply, socket}
    else
      socket = 
        socket
        |> assign(:pilot_suggestions, [])
        |> assign(:show_pilot_suggestions, false)
        |> assign(:pilot_name, search_term)
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("select_pilot_suggestion", %{"pilot_name" => pilot_name}, socket) do
    socket = 
      socket
      |> assign(:pilot_name, pilot_name)
      |> assign(:show_pilot_suggestions, false)
      |> assign(:pilot_suggestions, [])
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("upload_log", %{"pilot_name" => pilot_name}, socket) do
    consume_uploaded_entries(socket, :combat_log, fn %{path: path}, entry ->
      # Create the upload record
      file_upload = %{
        path: path,
        filename: entry.client_name
      }
      
      battle_id = if socket.assigns.current_battle, do: socket.assigns.current_battle.battle_id, else: nil
      
      case Ash.create(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog, %{
        file_upload: file_upload,
        pilot_name: pilot_name,
        battle_id: battle_id
      }, action: :upload) do
        {:ok, combat_log} ->
          # Start background parsing
          self = self()
          Task.start(fn ->
            # Parse the combat log manually since the action uses a function change
            try do
              # Get the raw content
              compressed = Base.decode64!(combat_log.raw_content)
              content = :zlib.uncompress(compressed)
              
              # Parse the log with ENHANCED parser
              case EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.parse_combat_log(content, pilot_name: combat_log.pilot_name) do
                {:ok, %{events: events, summary: summary, metadata: metadata, tactical_analysis: tactical_analysis, recommendations: recommendations}} ->
                  # Update the log with parsed data including tactical analysis
                  {:ok, updated_log} = Ash.update(combat_log, %{
                    parsed_data: %{
                      events: events,
                      tactical_analysis: tactical_analysis,
                      recommendations: recommendations
                    },
                    summary: summary,
                    event_count: length(events),
                    start_time: metadata[:start_time],
                    end_time: metadata[:end_time],
                    parse_status: :completed
                  })
                  
                  send(self, {:combat_log_parsed, updated_log})
                  
                {:error, reason} ->
                  # Update with error status
                  {:ok, _} = Ash.update(combat_log, %{
                    parse_status: :failed,
                    parse_error: inspect(reason)
                  })
              end
            rescue
              error ->
                # Update with error status
                {:ok, _} = Ash.update(combat_log, %{
                  parse_status: :failed,
                  parse_error: inspect(error)
                })
            end
          end)
          
          {:ok, combat_log}
          
        {:error, error} ->
          {:postpone, inspect(error)}
      end
    end)
    
    socket =
      socket
      |> assign(:show_log_upload, false)
      |> assign(:pilot_name, "")  # Clear pilot name after successful upload
      |> load_combat_logs()
    
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("delete_log", %{"log_id" => log_id}, socket) do
    case Ash.get(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog, log_id) do
      {:ok, log} ->
        case Ash.destroy(log) do
          :ok -> {:noreply, load_combat_logs(socket)}
          _ -> {:noreply, socket}
        end
      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("analyze_ship_performance", %{"character_id" => char_id, "ship_type_id" => ship_id}, socket) do
    character_id = String.to_integer(char_id)
    ship_type_id = String.to_integer(ship_id)
    
    # Find pilot data from fleet composition to get character name
    pilot_data = if socket.assigns.current_battle && socket.assigns.current_battle.timeline do
      socket.assigns.current_battle.timeline.fleet_composition
      |> Enum.flat_map(& &1[:pilot_ships] || [])
      |> Enum.find(fn p -> p.character_id == character_id && p.ship_type_id == ship_type_id end)
    end
    
    # Run performance analysis
    ship_data = %{
      character_id: character_id,
      ship_type_id: ship_type_id,
      character_name: pilot_data && pilot_data[:character_name],
      fitting_data: nil  # Will be populated if fitting exists
    }
    
    # CRITICAL: Use ETS + database hybrid cache to preserve fittings
    ship_key = {character_id, ship_type_id}
    
    existing_fitting = cond do
      # First check ETS cache
      :ets.lookup(:battle_fitting_cache, ship_key) != [] ->
        [{^ship_key, fitting}] = :ets.lookup(:battle_fitting_cache, ship_key)
        fitting
      
      # Then check database and cache the result
      true ->
        case Ash.read(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting, 
                      filter: [character_id: character_id, ship_type_id: ship_type_id],
                      sort: [updated_at: :desc],
                      limit: 1) do
          {:ok, [fitting | _]} -> 
            # Cache the fitting in ETS for future use
            :ets.insert(:battle_fitting_cache, {ship_key, fitting.parsed_fitting})
            fitting.parsed_fitting
          _ -> nil
        end
    end
    
    # Always include fitting data in ship_data
    ship_data = Map.put(ship_data, :fitting_data, existing_fitting)
    
    # Fetch combat log analysis for this pilot if available
    combat_log_analysis = get_combat_log_analysis_for_pilot(pilot_data && pilot_data[:character_name])
    ship_data = Map.put(ship_data, :combat_log_analysis, combat_log_analysis)
    
    case EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer.analyze_ship_performance(
      ship_data,
      socket.assigns.current_battle
    ) do
      {:ok, performance} ->
        # Update ETS cache with current fitting
        if existing_fitting do
          :ets.insert(:battle_fitting_cache, {ship_key, existing_fitting})
        end
        
        socket =
          socket
          |> assign(:selected_ship, ship_data)
          |> assign(:ship_performance, performance)
        
        {:noreply, socket}
        
      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_fitting_import", _, socket) do
    {:noreply, assign(socket, :show_fitting_import, !socket.assigns.show_fitting_import)}
  end

  @impl Phoenix.LiveView
  def handle_event("import_eft_fitting", %{"eft_text" => eft_text}, socket) do
    if socket.assigns.selected_ship do
      case Ash.create(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting, %{
        eft_text: eft_text,
        character_id: socket.assigns.selected_ship.character_id
      }, action: :import_eft) do
        {:ok, fitting} ->
          # Cache the new fitting in ETS immediately
          ship_key = {socket.assigns.selected_ship.character_id, socket.assigns.selected_ship.ship_type_id}
          :ets.insert(:battle_fitting_cache, {ship_key, fitting.parsed_fitting})
          
          # Update selected ship with new fitting
          updated_ship = Map.put(socket.assigns.selected_ship, :fitting_data, fitting.parsed_fitting)
          
          socket =
            socket
            |> assign(:selected_ship, updated_ship)
            |> assign(:show_fitting_import, false)
            |> put_flash(:info, "Fitting imported successfully")
          
          # Re-run analysis with new fitting
          send(self(), {:reanalyze_with_fitting, fitting})
          
          {:noreply, socket}
          
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to import fitting")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:combat_log_parsed, _combat_log}, socket) do
    socket = load_combat_logs(socket)
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

  @impl Phoenix.LiveView
  def handle_info({:reanalyze_with_fitting, fitting}, socket) do
    if socket.assigns.selected_ship do
      # Update ship data with new fitting
      ship_data = Map.put(socket.assigns.selected_ship, :fitting_data, fitting.parsed_fitting)
      
      case EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer.analyze_ship_performance(
        ship_data,
        socket.assigns.current_battle
      ) do
        {:ok, performance} ->
          socket =
            socket
            |> assign(:selected_ship, ship_data)
            |> assign(:ship_performance, performance)
          
          {:noreply, socket}
          
        {:error, _reason} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
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
        # Track this battle as recently viewed
        track_recently_viewed_battle(battle)
        
        socket
        |> assign(:current_battle, battle)
        |> assign(:selected_phase, nil)
        |> assign(:error_message, nil)
        |> assign(:recently_viewed_battles, load_recently_viewed_battles())
        |> update_battle_sides()
        |> load_combat_logs()
        |> load_battle_metrics()

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

  # Humanize upload errors
  def humanize_upload_error(:too_large), do: "File too large (max 10MB)"
  def humanize_upload_error(:not_accepted), do: "Invalid file type (only .txt or .log allowed)"
  def humanize_upload_error(error), do: "Upload error: #{inspect(error)}"

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

  defp load_combat_logs(socket) do
    logs = if socket.assigns.current_battle do
      case Ash.read(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog, 
                    filter: [battle_id: socket.assigns.current_battle.battle_id],
                    sort: [uploaded_at: :desc]) do
        {:ok, logs} -> logs
        _ -> []
      end
    else
      []
    end
    
    assign(socket, :combat_logs, logs)
  end

  defp load_battle_metrics(socket) do
    if socket.assigns.current_battle do
      case EveDmv.Contexts.BattleAnalysis.Domain.BattleMetricsCalculator.calculate_battle_metrics(
        socket.assigns.current_battle
      ) do
        {:ok, metrics} ->
          assign(socket, :battle_metrics, metrics)
        _ ->
          socket
      end
    else
      socket
    end
  end
  
  # Recently viewed battles tracking
  
  defp track_recently_viewed_battle(battle) do
    # Use ETS table to track recently viewed battles
    # Store up to 10 recently viewed battles with timestamp
    viewed_key = :recently_viewed_battles
    
    current_viewed = case :ets.lookup(:battle_fitting_cache, viewed_key) do
      [{^viewed_key, battles}] -> battles
      [] -> []
    end
    
    # Add this battle to the front, remove duplicates, limit to 10
    battle_entry = %{
      battle_id: battle.battle_id,
      system_name: resolve_system_name(battle.system_id),
      participant_count: length(battle.killmails),
      isk_destroyed: battle.killmails |> Enum.map(&get_killmail_isk_value/1) |> Enum.sum(),
      start_time: battle.metadata.start_time,
      viewed_at: DateTime.utc_now()
    }
    
    updated_viewed = 
      [battle_entry | current_viewed]
      |> Enum.uniq_by(& &1.battle_id)
      |> Enum.take(10)
    
    :ets.insert(:battle_fitting_cache, {viewed_key, updated_viewed})
  end
  
  defp load_recently_viewed_battles do
    case :ets.lookup(:battle_fitting_cache, :recently_viewed_battles) do
      [{:recently_viewed_battles, battles}] -> battles
      [] -> []
    end
  end
  
  # Helper function to extract ISK value from killmail data
  defp get_killmail_isk_value(killmail) do
    case killmail do
      %{raw_data: %{"zkb" => %{"totalValue" => value}}} when is_number(value) -> value
      %{isk_value: value} when is_number(value) -> value
      _ -> 0
    end
  end
  
  # Helper function to get combat log analysis for a specific pilot
  defp get_combat_log_analysis_for_pilot(nil), do: nil
  defp get_combat_log_analysis_for_pilot(pilot_name) when is_binary(pilot_name) do
    # Find all combat logs for this pilot and use the most recent one with tactical analysis
    case Ash.read(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog) do
      {:ok, all_logs} ->
        # Filter for this pilot and completed status, sort by upload time descending
        pilot_logs = all_logs
        |> Enum.filter(fn log -> 
          log.pilot_name == pilot_name && log.parse_status == :completed
        end)
        |> Enum.sort_by(& &1.uploaded_at, {:desc, DateTime})
        
        # Find the first log with tactical analysis, or fall back to any log with events
        combat_log = Enum.find(pilot_logs, fn log ->
          parsed_data = log.parsed_data || %{}
          Map.has_key?(parsed_data, "tactical_analysis") || Map.has_key?(parsed_data, :tactical_analysis)
        end) || List.first(pilot_logs)
        
        if combat_log && combat_log.parsed_data do
          extract_tactical_analysis(combat_log)
        else
          nil
        end
        
      _ ->
        nil
    end
  end
  
  # Get pilot suggestions for autocomplete based on current battle participants
  defp get_pilot_suggestions(nil, _search_term), do: []
  defp get_pilot_suggestions(battle, search_term) when is_binary(search_term) do
    if battle.timeline && battle.timeline.fleet_composition do
      # Get all unique pilots from the battle
      all_pilots = battle.timeline.fleet_composition
      |> Enum.flat_map(fn window ->
        window[:pilot_ships] || []
      end)
      |> Enum.uniq_by(& &1.character_id)
      
      # Filter pilots by search term (case insensitive)
      search_lower = String.downcase(search_term)
      
      all_pilots
      |> Enum.filter(fn pilot ->
        character_name = pilot[:character_name] || resolve_character_name(pilot.character_id)
        character_name && String.contains?(String.downcase(character_name), search_lower)
      end)
      |> Enum.map(fn pilot ->
        %{
          character_id: pilot.character_id,
          character_name: pilot[:character_name] || resolve_character_name(pilot.character_id),
          ship_name: pilot[:ship_name] || resolve_ship_name(pilot.ship_type_id),
          corporation_name: pilot[:corporation_name] || resolve_corporation_name(pilot.corporation_id)
        }
      end)
      |> Enum.take(8)  # Limit to 8 suggestions to keep UI manageable
    else
      []
    end
  end
  
  # Check if a target from combat log actually died in this battle
  defp target_died?(target_name, battle) when is_binary(target_name) and not is_nil(battle) do
    if battle.killmails do
      Enum.any?(battle.killmails, fn killmail ->
        victim_name = get_in(killmail.raw_data, ["victim", "character_name"])
        victim_name == target_name
      end)
    else
      false
    end
  end
  defp target_died?(_, _), do: false
  
  # Helper functions for ship status indicators
  defp get_all_pilots_from_battle(battle) when not is_nil(battle) do
    battle.killmails
    |> Enum.flat_map(fn killmail ->
      # Get attackers with full data
      attackers = 
        case get_in(killmail.raw_data, ["attackers"]) do
          attackers when is_list(attackers) ->
            Enum.map(attackers, fn attacker ->
              %{
                character_id: get_in(attacker, ["character_id"]),
                character_name: get_in(attacker, ["character_name"]),
                corporation_id: get_in(attacker, ["corporation_id"]),
                corporation_name: get_in(attacker, ["corporation_name"]),
                ship_type_id: get_in(attacker, ["ship_type_id"]),
                ship_name: get_in(attacker, ["ship_name"]),
                alliance_id: get_in(attacker, ["alliance_id"])
              }
            end)
          _ -> []
        end
      
      # Get victim with full data
      victim = %{
        character_id: get_in(killmail.raw_data, ["victim", "character_id"]),
        character_name: get_in(killmail.raw_data, ["victim", "character_name"]),
        corporation_id: get_in(killmail.raw_data, ["victim", "corporation_id"]),
        corporation_name: get_in(killmail.raw_data, ["victim", "corporation_name"]),
        ship_type_id: get_in(killmail.raw_data, ["victim", "ship_type_id"]),
        ship_name: get_in(killmail.raw_data, ["victim", "ship_name"]),
        alliance_id: get_in(killmail.raw_data, ["victim", "alliance_id"])
      }
      
      [victim | attackers]
    end)
    # Filter out entries without character_id (NPC corporations, etc.)
    |> Enum.filter(&(&1.character_id && &1.character_name))
    # Remove duplicates based on character_id and ship_type_id
    |> Enum.uniq_by(&{&1.character_id, &1.ship_type_id})
    |> Enum.sort_by(&(&1.character_name || ""))
  end
  
  defp get_all_pilots_from_battle(_), do: []
  
  defp has_combat_log?(pilot_name, combat_logs) when is_binary(pilot_name) and is_list(combat_logs) do
    Enum.any?(combat_logs, fn log ->
      case log do
        %{pilot_name: ^pilot_name} -> true
        %{"pilot_name" => ^pilot_name} -> true
        _ -> false
      end
    end)
  end
  
  defp has_combat_log?(_, _), do: false
  
  defp has_fitting?(pilot_name) when is_binary(pilot_name) do
    # Check ETS fitting cache
    fitting_key = {"battle_fitting", pilot_name}
    case :ets.lookup(:battle_fitting_cache, fitting_key) do
      [{^fitting_key, _fitting_data}] -> true
      [] -> false
    end
  rescue
    _ -> false
  end
  
  defp has_fitting?(_), do: false
  
  defp has_fitting?(character_id, ship_type_id) when is_integer(character_id) and is_integer(ship_type_id) do
    # Convert character_id to character name and check fitting cache
    character_name = resolve_character_name(character_id)
    if character_name, do: has_fitting?(character_name), else: false
  end
  
  defp has_fitting?(_, _), do: false
  
  # Extract tactical analysis from a combat log
  defp extract_tactical_analysis(combat_log) do
    parsed_data = combat_log.parsed_data || %{}
    
    # Handle both string and atom keys
    tactical_analysis = parsed_data["tactical_analysis"] || parsed_data[:tactical_analysis]
    recommendations = parsed_data["recommendations"] || parsed_data[:recommendations] || []
    events = parsed_data["events"] || parsed_data[:events] || []
    
    if tactical_analysis do
      # We have full tactical analysis
      Map.merge(tactical_analysis, %{
        recommendations: recommendations,
        summary: combat_log.summary || %{}
      })
    else
      # Create basic analysis from events
      damage_received_events = Enum.filter(events, fn event ->
        (event["type"] == "damage_received" || event[:type] == :damage_received)
      end)
      
      total_damage_received = damage_received_events
      |> Enum.map(fn event -> event["damage"] || event[:damage] || 0 end)
      |> Enum.sum()
      
      %{
        damage_application: %{total_shots: 0, average_application: 0, quality_breakdown: %{}},
        defensive_reactions: %{defensive_activations: 0, average_reaction_time: 0},
        summary: %{total_damage_received: total_damage_received},
        recommendations: recommendations
      }
    end
  end
end
