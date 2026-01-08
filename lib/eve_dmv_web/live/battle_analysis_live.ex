defmodule EveDmvWeb.BattleAnalysisLive do
  @moduledoc """
  LiveView for battle analysis and tactical intelligence.

  Provides real-time battle analysis, fleet composition breakdowns,
  tactical recommendations, and historical battle comparisons.
  """

  use EveDmvWeb, :live_view
  import EveDmvWeb.BattleAnalysisLive.Helpers

  alias EveDmv.Contexts.BattleAnalysis
  alias EveDmv.Contexts.BattleSharing
  alias EveDmv.Performance.BatchNameResolver
  alias EveDmvWeb.BattleAnalysisLive.Helpers

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @visible_pilots_per_side 50

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> initialize_battle_state()
      |> initialize_ui_state()
      |> initialize_upload_state()
      |> initialize_share_state()
      |> load_recent_battles()

    # Use temporary_assigns to clear large list-based data from process memory after render
    # These lists are rendered once and don't need to persist in full between renders
    {:ok, socket,
     temporary_assigns: [
       recent_battles: [],
       combat_logs: [],
       battle_reports: [],
       pilot_suggestions: [],
       recently_viewed_battles: []
     ]}
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

  # Toggle expansion of a fleet side to show all pilots
  def handle_event(
        "toggle_side_expansion",
        %{"side" => side, "window_index" => window_index},
        socket
      ) do
    side_key = "#{window_index}_#{side}"
    expanded_sides = socket.assigns.expanded_sides

    new_expanded_sides =
      if MapSet.member?(expanded_sides, side_key) do
        MapSet.delete(expanded_sides, side_key)
      else
        MapSet.put(expanded_sides, side_key)
      end

    {:noreply, assign(socket, :expanded_sides, new_expanded_sides)}
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
        |> assign(:show_pilot_suggestions, not Enum.empty?(suggestions))
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
              {:ok,
               %{
                 events: events,
                 summary: summary,
                 metadata: metadata,
                 tactical_analysis: tactical_analysis,
                 recommendations: recommendations
               }} =
                EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser.parse_combat_log(
                  content,
                  pilot_name: combat_log.pilot_name
                )

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

    enhanced_ship_data =
      ship_data
      |> Map.put(:fitting_data, existing_fitting)
      |> Map.put(:combat_log_analysis, combat_log_analysis)

    {:ok, performance} =
      EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer.analyze_ship_performance(
        enhanced_ship_data,
        socket.assigns.current_battle
      )

    # Update ETS cache with current fitting
    if existing_fitting do
      :ets.insert(:battle_fitting_cache, {ship_key, existing_fitting})
    end

    socket =
      socket
      |> assign(:selected_ship, ship_data)
      |> assign(:ship_performance, performance)

    {:noreply, socket}
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

      {:ok, _report} =
        BattleSharing.create_battle_report_from_data(
          socket.assigns.current_battle,
          creator_id,
          options
        )

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

      {:error, reason} ->
        error_message = format_error_reason(reason)
        {:noreply, put_flash(socket, :error, error_message)}
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

  # Handle dropdown hide messages from search component (ignore)
  def handle_info({:hide_dropdown, _component_id}, socket) do
    {:noreply, socket}
  end

  def handle_info({:reanalyze_with_fitting, fitting}, socket) do
    if socket.assigns.selected_ship do
      # Update ship data with new fitting
      ship_data = Map.put(socket.assigns.selected_ship, :fitting_data, fitting.parsed_fitting)

      {:ok, performance} =
        EveDmv.Contexts.BattleAnalysis.Domain.ShipPerformanceAnalyzer.analyze_ship_performance(
          ship_data,
          socket.assigns.current_battle
        )

      socket =
        socket
        |> assign(:selected_ship, ship_data)
        |> assign(:ship_performance, performance)

      {:noreply, socket}
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
      require Logger
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
      # Note: get_battle_with_timeline currently always returns error tuples
      case BattleAnalysis.get_battle_with_timeline(battle_id) do
        {:error, reason}
        when reason in [:battle_not_found, :database_error, :timeline_reconstruction_failed] ->
          require Logger
          Logger.warning("Battle #{battle_id} error: #{reason}")

          error_message =
            case reason do
              :battle_not_found ->
                "Battle not found. It may have been re-detected with a different ID."

              :database_error ->
                "Database error occurred while loading battle"

              :timeline_reconstruction_failed ->
                "Failed to reconstruct battle timeline"

              # Dialyzer says :max_iterations_reached is not a possible value
              _ ->
                "Failed to load battle"
            end

          assign(socket, :error_message, error_message)

        {:error, _reason} ->
          assign(socket, :error_message, "Failed to load battle")
      end
    end
  end

  defp format_error(:invalid_zkillboard_url), do: "Invalid zkillboard URL"
  defp format_error(:unsupported_url_format), do: "Unsupported zkillboard URL format"
  defp format_error({:http_error, _error}), do: "Failed to connect to zkillboard"
  defp format_error({:api_error, status}), do: "zkillboard API error (#{status})"
  defp format_error(_error), do: "Import failed"

  # Handle known atom error reasons with specific messages
  defp format_error_reason(:curator_unavailable),
    do: "Battle curator service is temporarily unavailable"

  defp format_error_reason(:report_not_found), do: "Battle report not found"

  defp format_error_reason(:permission_denied),
    do: "You don't have permission to perform this action"

  defp format_error_reason(:rating_must_be_number),
    do: "Rating must be a number"

  defp format_error_reason(:categories_must_be_map),
    do: "Categories must be a map"

  # Handle tuple error reasons (e.g., {:invalid_rating, :out_of_range})
  defp format_error_reason({:invalid_rating, :out_of_range}),
    do: "Rating must be between 1 and 10"

  # Handle tuple error reasons with atom components
  defp format_error_reason({error_type, detail}) when is_atom(error_type) and is_atom(detail) do
    "#{error_type |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()}: #{detail |> Atom.to_string() |> String.replace("_", " ")}"
  end

  # Handle tuple error reasons with any second component
  defp format_error_reason({error_type, detail}) when is_atom(error_type) do
    "#{error_type |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()}: #{inspect(detail)}"
  end

  # Handle other atom error reasons
  defp format_error_reason(reason) when is_atom(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  # Handle binary error reasons (fallback for any string errors)
  defp format_error_reason(reason) when is_binary(reason) do
    reason
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  # Catch-all for any other type
  defp format_error_reason(other), do: inspect(other)

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
    EveDmv.Eve.NameResolver.StaticDataResolver.system_name(system_id)
  end

  def resolve_system_name(_), do: "Unknown System"

  def resolve_character_name(character_id) when is_integer(character_id) do
    EveDmv.Eve.NameResolver.EsiEntityResolver.character_name(character_id)
  end

  def resolve_character_name(_), do: "Unknown"

  # Get ships for a specific side
  def get_ships_for_side(pilots, side, ship_side_assignments) do
    Enum.filter(pilots || [], fn pilot ->
      Helpers.get_ship_side(pilot, ship_side_assignments) == side
    end)
  end

  # Get visible ships for a side with pagination support
  def get_visible_ships_for_side(
        pilots,
        side,
        ship_side_assignments,
        window_index,
        expanded_sides,
        visible_limit
      ) do
    all_pilots = get_ships_for_side(pilots, side, ship_side_assignments)
    total = length(all_pilots)
    side_key = "#{window_index}_#{side}"

    if MapSet.member?(expanded_sides, side_key) or total <= visible_limit do
      {all_pilots, total, false}
    else
      {Enum.take(all_pilots, visible_limit), total, true}
    end
  end

  # Check if a side is expanded
  def side_expanded?(window_index, side, expanded_sides) do
    side_key = "#{window_index}_#{side}"
    MapSet.member?(expanded_sides, side_key)
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
      custom_sides = if Enum.empty?(all_sides), do: ["side_1", "side_2"], else: all_sides

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
      battle.timeline.events
      |> Enum.reduce(%{}, &process_event_for_corp_stats/2)
    else
      %{}
    end
  end

  defp process_event_for_corp_stats(event, acc) do
    acc = process_victim_corporation(event, acc)
    process_attacker_corporations(event, acc)
  end

  defp process_victim_corporation(event, acc) do
    victim_corp = event.victim.corporation_id
    victim_value = event[:isk_value] || 0

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
  end

  defp process_attacker_corporations(event, acc) do
    victim_value = event[:isk_value] || 0

    event.attackers
    |> Enum.filter(& &1.corporation_id)
    |> Enum.reduce(acc, fn attacker, acc2 ->
      attacker_share = calculate_attacker_share(event.attackers, victim_value)

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
          update_attacker_stats(stats, attacker, attacker_share)
        end
      )
    end)
  end

  defp calculate_attacker_share(attackers, victim_value) do
    if Enum.empty?(attackers) do
      0
    else
      victim_value / length(attackers)
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
      {:ok, metrics} =
        EveDmv.Contexts.BattleAnalysis.Domain.BattleMetricsCalculator.calculate_battle_metrics(
          socket.assigns.current_battle
        )

      assign(socket, :battle_metrics, metrics)
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
  # No battle data available for suggestions

  defp get_pilot_suggestions(battle, search_term) when is_binary(search_term) do
    # First try to get pilots from the current battle if available
    battle_pilots =
      if battle && battle.timeline && battle.timeline.fleet_composition do
        battle.timeline.fleet_composition
        |> Enum.flat_map(fn window ->
          window[:pilot_ships] || []
        end)
        |> Enum.uniq_by(& &1.character_id)
        |> Enum.filter(fn pilot ->
          character_name = pilot[:character_name] || resolve_character_name(pilot.character_id)

          character_name &&
            String.contains?(String.downcase(character_name), String.downcase(search_term))
        end)
        |> Enum.map(fn pilot ->
          %{
            character_id: pilot.character_id,
            character_name: pilot[:character_name] || resolve_character_name(pilot.character_id),
            ship_name: pilot[:ship_name] || Helpers.resolve_ship_name(pilot.ship_type_id),
            corporation_name:
              pilot[:corporation_name] || Helpers.resolve_corporation_name(pilot.corporation_id)
          }
        end)
      else
        []
      end

    # If we have battle pilots, return them, otherwise search the database
    if Enum.empty?(battle_pilots) do
      # Search the database for character suggestions
      case EveDmv.Search.SearchSuggestionService.get_character_suggestions(search_term, limit: 8) do
        {:ok, suggestions} ->
          Enum.map(suggestions, fn suggestion ->
            %{
              character_id: suggestion.id,
              character_name: suggestion.name,
              # Ship info not available from general search
              ship_name: nil,
              corporation_name: suggestion.subtitle
            }
          end)

        {:error, _reason} ->
          []
      end
    else
      battle_pilots
      |> Enum.take(8)
    end
  end

  # Check if a target from combat log actually died in this battle
  defp target_died?(target_name, battle) when is_binary(target_name) and is_map(battle) do
    if battle.killmails do
      battle.killmails
      |> Enum.any?(fn killmail ->
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
    |> Enum.filter(&has_valid_character_data?/1)
    # Remove duplicates based on character_id and ship_type_id
    |> Enum.uniq_by(&{&1.character_id, &1.ship_type_id})
    |> Enum.sort_by(&(&1.character_name || ""))
  end

  defp get_all_pilots_from_battle(_), do: []
  # Battle data structure not available

  defp has_combat_log?(pilot_name, combat_logs)
       when is_binary(pilot_name) and is_list(combat_logs) do
    combat_logs
    |> Enum.any?(fn log ->
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

  # Private helper functions for mount initialization

  defp initialize_battle_state(socket) do
    socket
    |> assign(:page_title, "Battle Analysis")
    |> assign(:current_battle, nil)
    |> assign(:recent_battles, [])
    |> assign(:recently_viewed_battles, load_recently_viewed_battles())
    |> assign(:corp_summaries, %{})
    |> assign(:battle_metrics, nil)
    |> assign(:battle_intelligence, nil)
    |> assign(:battle_reports, [])
  end

  defp initialize_ui_state(socket) do
    socket
    |> assign(:main_view, :metrics)
    |> assign(:timeline_view, :phases)
    |> assign(:selected_phase, nil)
    |> assign(:show_metrics_dashboard, true)
    |> assign(:error_message, nil)
    |> assign(:pilot_suggestions, [])
    |> assign(:show_pilot_suggestions, false)
    |> assign(:editing_fleet_sides, false)
    |> assign(:custom_sides, ["side_1", "side_2"])
    |> assign(:ship_side_assignments, %{})
    |> assign(:selected_ship, nil)
    |> assign(:ship_performance, nil)
    |> assign(:show_fitting_import, false)
    |> assign(:expanded_sides, MapSet.new())
    |> assign(:visible_pilots_per_side, @visible_pilots_per_side)
  end

  defp initialize_upload_state(socket) do
    socket
    |> assign(:import_url, "")
    |> assign(:importing, false)
    |> assign(:combat_logs, [])
    |> assign(:show_log_upload, false)
    |> assign(:log_upload_errors, [])
    |> assign(:pilot_name, "")
    |> allow_upload(:combat_log,
      accept: ~w(.txt),
      max_entries: 1,
      max_file_size: 10_000_000
    )
  end

  defp initialize_share_state(socket) do
    socket
    |> assign(:show_share_modal, false)
    |> assign(:share_form, %{
      title: "",
      description: "",
      video_url: "",
      visibility: "public"
    })
  end

  defp has_valid_character_data?(participant) do
    participant.character_id && participant.character_name
  end

  defp update_attacker_stats(stats, attacker, attacker_share) do
    %{
      stats
      | kills: stats.kills + if(attacker.final_blow, do: 1, else: 0),
        isk_destroyed: stats.isk_destroyed + attacker_share
    }
  end
end
