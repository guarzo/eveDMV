defmodule EveDmvWeb.BattleAnalysisLive do
  @moduledoc """
  LiveView for battle analysis and tactical intelligence.

  Provides real-time battle analysis, fleet composition breakdowns,
  tactical recommendations, and historical battle comparisons.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser
  alias EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer
  alias CombatLog
  alias ShipFitting
  alias EveDmv.Contexts.BattleSharing
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Performance.BatchNameResolver

  require Logger

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

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
      |> assign(:battle_intelligence, nil)
      # Battle sharing
      |> assign(:show_share_modal, false)
      |> assign(:share_form, %{
        title: "",
        description: "",
        video_url: "",
        visibility: "public"
      })
      |> assign(:battle_reports, [])
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

  def handle_event("select_battle", %{"battle_id" => battle_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/battle/#{battle_id}")}
  end

  def handle_event("select_phase", %{"phase_index" => phase_index}, socket) do
    phase_idx = String.to_integer(phase_index)
    phase = Enum.at(socket.assigns.current_battle.timeline.phases, phase_idx)

    {:noreply, assign(socket, :selected_phase, phase)}
  end

  def handle_event("change_main_view", %{"view" => view}, socket) do
    view_atom = String.to_existing_atom(view)
    {:noreply, assign(socket, :main_view, view_atom)}
  end

  def handle_event("change_timeline_view", %{"view" => view}, socket) do
    view_atom = String.to_existing_atom(view)
    {:noreply, assign(socket, :timeline_view, view_atom)}
  end

  def handle_event("toggle_fleet_edit_mode", _, socket) do
    {:noreply, assign(socket, :editing_fleet_sides, !socket.assigns.editing_fleet_sides)}
  end

  def handle_event(
        "cycle_ship_side",
        %{"ship_id" => pilot_ship_id, "current_side" => current_side},
        socket
      ) do
    # Get all available sides including "unassigned"
    all_sides = Enum.reverse(["unassigned" | socket.assigns.custom_sides])
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

  def handle_event("add_custom_side", _, socket) do
    new_side_num = length(socket.assigns.custom_sides) + 1
    new_side = "side_#{new_side_num}"
    custom_sides = Enum.reverse([new_side | socket.assigns.custom_sides])
    {:noreply, assign(socket, :custom_sides, custom_sides)}
  end

  def handle_event("reset_fleet_sides", _, socket) do
    socket =
      socket
      |> assign(:ship_side_assignments, %{})
      |> assign(:custom_sides, ["side_1", "side_2"])
      |> assign(:editing_fleet_sides, false)

    {:noreply, socket}
  end

  def handle_event("toggle_log_upload", _, socket) do
    socket =
      socket
      |> assign(:show_log_upload, !socket.assigns.show_log_upload)
      # Clear pilot name when toggling
      |> assign(:pilot_name, "")

    {:noreply, socket}
  end

  def handle_event("validate_log", %{"pilot_name" => pilot_name} = _params, socket) do
    # Store pilot name so it doesn't get cleared
    {:noreply, assign(socket, :pilot_name, pilot_name)}
  end

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

  def handle_event("select_pilot_suggestion", %{"pilot_name" => pilot_name}, socket) do
    socket =
      socket
      |> assign(:pilot_name, pilot_name)
      |> assign(:show_pilot_suggestions, false)
      |> assign(:pilot_suggestions, [])

    {:noreply, socket}
  end

  def handle_event("upload_log", %{"pilot_name" => pilot_name}, socket) do
    consume_uploaded_entries(socket, :combat_log, fn %{path: path}, entry ->
      # Create the upload record
      file_upload = %{
        path: path,
        filename: entry.client_name
      }

      battle_id =
        if socket.assigns.current_battle, do: socket.assigns.current_battle.battle_id, else: nil

      case Ash.create(
             CombatLog,
             %{
               file_upload: file_upload,
               pilot_name: pilot_name,
               battle_id: battle_id
             },
             action: :upload
           ) do
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
              case EnhancedCombatLogParser.parse_combat_log(
                     content,
                     pilot_name: combat_log.pilot_name
                   ) do
                {:ok,
                 %{
                   events: events,
                   summary: summary,
                   metadata: metadata,
                   tactical_analysis: tactical_analysis,
                   recommendations: recommendations
                 }} ->
                  # Update the log with parsed data including tactical analysis
                  {:ok, updated_log} =
                    Ash.update(combat_log, %{
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
                  {:ok, _} =
                    Ash.update(combat_log, %{
                      parse_status: :failed,
                      parse_error: inspect(reason)
                    })
              end
            rescue
              error ->
                # Update with error status
                {:ok, _} =
                  Ash.update(combat_log, %{
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
      # Clear pilot name after successful upload
      |> assign(:pilot_name, "")
      |> load_combat_logs()

    {:noreply, socket}
  end

  def handle_event("delete_log", %{"log_id" => log_id}, socket) do
    case Ash.get(CombatLog, log_id) do
      {:ok, log} ->
        case Ash.destroy(log) do
          :ok -> {:noreply, load_combat_logs(socket)}
          _ -> {:noreply, socket}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(
        "analyze_ship_performance",
        %{"character_id" => char_id, "ship_type_id" => ship_id},
        socket
      ) do
    character_id = String.to_integer(char_id)
    ship_type_id = String.to_integer(ship_id)

    # Find pilot data from fleet composition to get character name
    pilot_data =
      if socket.assigns.current_battle && socket.assigns.current_battle.timeline do
        socket.assigns.current_battle.timeline.fleet_composition
        |> Enum.flat_map(&(&1[:pilot_ships] || []))
        |> Enum.find(fn p -> p.character_id == character_id && p.ship_type_id == ship_type_id end)
      end

    # Run performance analysis
    ship_data = %{
      character_id: character_id,
      ship_type_id: ship_type_id,
      character_name: pilot_data && pilot_data[:character_name],
      # Will be populated if fitting exists
      fitting_data: nil
    }

    # CRITICAL: Use ETS + database hybrid cache to preserve fittings
    ship_key = {character_id, ship_type_id}

    existing_fitting =
      if :ets.lookup(:battle_fitting_cache, ship_key) != [] do
        # First check ETS cache
        [{^ship_key, fitting}] = :ets.lookup(:battle_fitting_cache, ship_key)
        fitting
      else
        # Then check database and cache the result
        case Ash.read(ShipFitting,
               filter: [character_id: character_id, ship_type_id: ship_type_id],
               sort: [updated_at: :desc],
               limit: 1
             ) do
          {:ok, [fitting | _]} ->
            # Cache the fitting in ETS for future use
            :ets.insert(:battle_fitting_cache, {ship_key, fitting.parsed_fitting})
            fitting.parsed_fitting

          _ ->
            nil
        end
      end

    # Always include fitting data in ship_data
    # Fetch combat log analysis for this pilot if available
    combat_log_analysis =
      get_combat_log_analysis_for_pilot(pilot_data && pilot_data[:character_name])

    ship_data =
      ship_data
      |> Map.put(:fitting_data, existing_fitting)
      |> Map.put(:combat_log_analysis, combat_log_analysis)

    case ShipPerformanceAnalyzer.analyze_ship_performance(
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

  def handle_event("toggle_fitting_import", _, socket) do
    {:noreply, assign(socket, :show_fitting_import, !socket.assigns.show_fitting_import)}
  end

  def handle_event("import_eft_fitting", %{"eft_text" => eft_text}, socket) do
    if socket.assigns.selected_ship do
      case Ash.create(
             ShipFitting,
             %{
               eft_text: eft_text,
               character_id: socket.assigns.selected_ship.character_id
             },
             action: :import_eft
           ) do
        {:ok, fitting} ->
          # Cache the new fitting in ETS immediately
          ship_key =
            {socket.assigns.selected_ship.character_id, socket.assigns.selected_ship.ship_type_id}

          :ets.insert(:battle_fitting_cache, {ship_key, fitting.parsed_fitting})

          # Update selected ship with new fitting
          updated_ship =
            Map.put(socket.assigns.selected_ship, :fitting_data, fitting.parsed_fitting)

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

  def handle_event("toggle_share_modal", _, socket) do
    {:noreply, assign(socket, :show_share_modal, !socket.assigns.show_share_modal)}
  end

  def handle_event("update_share_form", %{"share_form" => params}, socket) do
    form = Map.merge(socket.assigns.share_form, params)
    {:noreply, assign(socket, :share_form, form)}
  end

  def handle_event("create_battle_report", %{"share_form" => params}, socket) do
    if socket.assigns.current_battle do
      # In production, get character_id from session
      # Mock character ID
      creator_id = 12_345

      options = [
        title: params["title"],
        description: params["description"],
        video_urls: if(params["video_url"] != "", do: [params["video_url"]], else: []),
        visibility: String.to_existing_atom(params["visibility"])
      ]

      case BattleSharing.create_battle_report_from_data(
             socket.assigns.current_battle,
             creator_id,
             options
           ) do
        {:ok, _report} ->
          {:noreply,
           socket
           |> put_flash(:info, "Battle report created successfully!")
           |> assign(:show_share_modal, false)
           |> assign(:share_form, %{
             title: "",
             description: "",
             video_url: "",
             visibility: "public"
           })
           |> load_battle_reports()}

        {:error, :battle_not_found} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Battle not found. This may be due to battle ID changes. Try refreshing the page."
           )
           |> assign(:show_share_modal, false)}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to create battle report: #{inspect(reason)}")
           |> assign(:show_share_modal, false)}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("rate_battle_report", %{"report_id" => report_id, "rating" => rating}, socket) do
    # In production, get character_id from session
    # Mock character ID
    rater_id = 12_345
    rating_value = String.to_integer(rating)

    case BattleSharing.rate_battle_report(report_id, rater_id, rating_value) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rating submitted!")
         |> load_battle_reports()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to submit rating")}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:combat_log_parsed, _combat_log}, socket) do
    socket = load_combat_logs(socket)
    {:noreply, socket}
  end

  def handle_info({:import_complete, result}, socket) do
    socket =
      socket
      |> assign(:importing, false)
      |> assign(:import_url, "")
      |> then(fn socket ->
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
      end)

    {:noreply, socket}
  end

  def handle_info({:reanalyze_with_fitting, fitting}, socket) do
    if socket.assigns.selected_ship do
      # Update ship data with new fitting
      ship_data = Map.put(socket.assigns.selected_ship, :fitting_data, fitting.parsed_fitting)

      case ShipPerformanceAnalyzer.analyze_ship_performance(
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
    # First check if this battle is already in our recent battles list
    existing_battle =
      Enum.find(socket.assigns.recent_battles, fn b ->
        b.battle_id == battle_id
      end)

    if existing_battle do
      # Use the battle from our list directly but ensure it has timeline
      Logger.info("Using cached battle data for #{battle_id}")

      # Reconstruct timeline if missing
      battle_with_timeline =
        if Map.has_key?(existing_battle, :timeline) do
          existing_battle
        else
          timeline = BattleAnalysis.reconstruct_battle_timeline(existing_battle)
          Map.put(existing_battle, :timeline, timeline)
        end

      # Preload all names to prevent N+1 queries
      BatchNameResolver.preload_battle_names(battle_with_timeline)

      # Track this battle as recently viewed
      track_recently_viewed_battle(battle_with_timeline)

      # Load intelligence analysis
      intelligence =
        case BattleAnalysis.analyze_battle_with_intelligence(battle_with_timeline) do
          {:ok, intel} -> intel
          _ -> nil
        end

      socket
      |> assign(:current_battle, battle_with_timeline)
      |> assign(:battle_intelligence, intelligence)
      |> assign(:selected_phase, nil)
      |> assign(:error_message, nil)
      |> assign(:recently_viewed_battles, load_recently_viewed_battles())
      |> update_battle_sides()
      |> load_combat_logs()
      |> load_battle_metrics()
      |> load_battle_reports()
    else
      # Try to load from backend
      case BattleAnalysis.get_battle_with_timeline(battle_id) do
        {:ok, battle} ->
          # Preload all names to prevent N+1 queries
          BatchNameResolver.preload_battle_names(battle)

          # Track this battle as recently viewed
          track_recently_viewed_battle(battle)

          # Load intelligence analysis
          intelligence =
            case BattleAnalysis.analyze_battle_with_intelligence(battle) do
              {:ok, intel} -> intel
              _ -> nil
            end

          socket
          |> assign(:current_battle, battle)
          |> assign(:battle_intelligence, intelligence)
          |> assign(:selected_phase, nil)
          |> assign(:error_message, nil)
          |> assign(:recently_viewed_battles, load_recently_viewed_battles())
          |> update_battle_sides()
          |> load_combat_logs()
          |> load_battle_metrics()
          |> load_battle_reports()

        {:error, :battle_not_found} ->
          Logger.warning("Battle #{battle_id} not found in backend, showing error")

          assign(
            socket,
            :error_message,
            "Battle not found. It may have been re-detected with a different ID."
          )

        _ ->
          assign(socket, :error_message, "Failed to load battle")
      end
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

  def format_distance(distance) when is_number(distance) do
    cond do
      distance < 1000 -> "#{round(distance)}m"
      distance < 10_000 -> "#{Float.round(distance / 1000, 1)}km"
      true -> "#{round(distance / 1000)}km"
    end
  end

  def format_distance(_), do: "0m"

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
      type_id in 11_567..12_034 -> "Tech 3 Cruiser"
      type_id in 29_984..29_990 -> "Tech 3 Destroyer"
      type_id in 35_779..35_781 -> "Triglavian"
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
    logs =
      if socket.assigns.current_battle do
        case Ash.read(CombatLog,
               filter: [battle_id: socket.assigns.current_battle.battle_id],
               sort: [uploaded_at: :desc]
             ) do
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

  defp load_battle_reports(socket) do
    if socket.assigns.current_battle do
      case BattleSharing.get_reports_for_battle(socket.assigns.current_battle.battle_id) do
        {:ok, reports} ->
          assign(socket, :battle_reports, reports)

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

    current_viewed =
      case :ets.lookup(:battle_fitting_cache, viewed_key) do
        [{^viewed_key, battles}] -> battles
        [] -> []
      end

    # Add this battle to the front, remove duplicates, limit to 10
    # Get system_id from metadata or first killmail
    system_id =
      battle.metadata[:primary_system] ||
        (List.first(battle.killmails) && List.first(battle.killmails).solar_system_id) ||
        0

    battle_entry = %{
      battle_id: battle.battle_id,
      system_name: resolve_system_name(system_id),
      participant_count: battle.metadata[:unique_participants] || length(battle.killmails),
      isk_destroyed: battle.killmails |> Enum.map(&get_killmail_isk_value/1) |> Enum.sum(),
      start_time: battle.metadata[:start_time] || battle.start_time,
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
    case Ash.read(CombatLog) do
      {:ok, all_logs} ->
        # Filter for this pilot and completed status, sort by upload time descending
        pilot_logs =
          all_logs
          |> Enum.filter(fn log ->
            log.pilot_name == pilot_name && log.parse_status == :completed
          end)
          |> Enum.sort_by(& &1.uploaded_at, {:desc, DateTime})

        # Find the first log with tactical analysis, or fall back to any log with events
        combat_log =
          Enum.find(pilot_logs, fn log ->
            parsed_data = log.parsed_data || %{}

            Map.has_key?(parsed_data, "tactical_analysis") ||
              Map.has_key?(parsed_data, :tactical_analysis)
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
      all_pilots =
        battle.timeline.fleet_composition
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
          corporation_name:
            pilot[:corporation_name] || resolve_corporation_name(pilot.corporation_id)
        }
      end)
      # Limit to 8 suggestions to keep UI manageable
      |> Enum.take(8)
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
  defp get_all_pilots_from_battle(battle) when is_map(battle) do
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

          _ ->
            []
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

  defp has_combat_log?(pilot_name, combat_logs)
       when is_binary(pilot_name) and is_list(combat_logs) do
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

  defp has_fitting?(character_id, ship_type_id)
       when is_integer(character_id) and is_integer(ship_type_id) do
    # Convert character_id to character name and check fitting cache
    character_name = resolve_character_name(character_id)
    has_fitting?(character_name)
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
      damage_received_events =
        Enum.filter(events, fn event ->
          event["type"] == "damage_received" || event[:type] == :damage_received
        end)

      total_damage_received =
        damage_received_events
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

  # Helper function to format phase descriptions
  def format_phase_description(phase_type) do
    case phase_type do
      # Small battle phase types
      :gank -> "Single target elimination"
      :skirmish -> "Small scale engagement (2-3 kills)"
      :small_engagement -> "Limited engagement (4-5 kills)"
      # Standard fleet battle phases
      :opening_engagement -> "Initial fleet contact and positioning"
      :escalation -> "Reinforcements arrive, battle intensity increases"
      :peak_combat -> "Maximum engagement with heavy losses"
      :deescalation -> "One side withdraws or gains decisive advantage"
      :cleanup -> "Remaining forces eliminate stragglers"
      :repositioning -> "Fleets maneuver for tactical advantage"
      :standoff -> "Limited engagement, probing for weaknesses"
      :setup -> "Initial positioning and EWAR deployment"
      :engagement -> "Main combat phase"
      :resolution -> "Battle conclusion"
      _ -> "Tactical activity phase"
    end
  end
end
