defmodule EveDmvWeb.CharacterIntelligenceLive do
  @moduledoc """
  Advanced character intelligence analysis LiveView with real-time updates.

  Provides comprehensive character analysis with correlation insights,
  threat assessment, and real-time data updates.
  """

  use EveDmvWeb, :live_view

  require Logger

  alias EveDmv.Intelligence.{
    IntelligenceCoordinator,
    WHVettingAnalyzer
  }

  alias EveDmv.Eve.EsiClient

  on_mount {EveDmvWeb.AuthLive, :load_from_session}

  @impl true
  def mount(params, _session, socket) do
    character_id = params["character_id"]

    if connected?(socket) do
      # Subscribe to real-time updates for this character
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "character:#{character_id}")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:updates")
    end

    socket =
      socket
      |> assign(:character_id, character_id)
      |> assign(:tab, :overview)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:character_analysis, nil)
      |> assign(:comprehensive_analysis, nil)
      |> assign(:correlation_data, nil)
      |> assign(:real_time_enabled, true)
      |> assign(:auto_refresh, false)
      # seconds
      |> assign(:refresh_interval, 60)
      |> assign(:analysis_history, [])
      |> assign(:comparison_characters, [])
      |> assign(:search_query, "")
      |> assign(:search_results, [])

    if character_id do
      case Integer.parse(character_id) do
        {char_id, ""} when char_id > 0 ->
          send(self(), :load_character_analysis)
          {:ok, assign(socket, :character_id, char_id)}

        _ ->
          {:ok, assign(socket, :error, "Invalid character ID")}
      end
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    character_id = params["character_id"]
    tab = params["tab"] || "overview"

    socket =
      socket
      |> assign(:tab, String.to_atom(tab))

    # If character ID changed, reload analysis
    if character_id != to_string(socket.assigns.character_id) do
      case Integer.parse(character_id || "0") do
        {char_id, ""} when char_id > 0 ->
          socket =
            socket
            |> assign(:character_id, char_id)
            |> assign(:loading, true)
            |> assign(:character_analysis, nil)
            |> assign(:comprehensive_analysis, nil)

          send(self(), :load_character_analysis)
          {:noreply, socket}

        _ ->
          {:noreply, assign(socket, :error, "Invalid character ID")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/character-intelligence/#{socket.assigns.character_id}?tab=#{tab}")}
  end

  @impl true
  def handle_event("toggle_real_time", _params, socket) do
    new_state = not socket.assigns.real_time_enabled

    socket =
      socket
      |> assign(:real_time_enabled, new_state)
      |> put_flash(
        :info,
        if(new_state, do: "Real-time updates enabled", else: "Real-time updates disabled")
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_auto_refresh", _params, socket) do
    new_state = not socket.assigns.auto_refresh

    if new_state do
      :timer.send_interval(socket.assigns.refresh_interval * 1000, :auto_refresh)
    end

    socket =
      socket
      |> assign(:auto_refresh, new_state)
      |> put_flash(
        :info,
        if(new_state, do: "Auto-refresh enabled", else: "Auto-refresh disabled")
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_analysis", _params, socket) do
    # Invalidate cache and reload
    IntelligenceCoordinator.invalidate_character_intelligence(
      socket.assigns.character_id,
      "manual_refresh"
    )

    send(self(), :load_character_analysis)
    {:noreply, assign(socket, :loading, true)}
  end

  @impl true
  def handle_event("search_character", %{"search" => %{"query" => query}}, socket) do
    if String.length(query) >= 3 do
      case search_characters(query) do
        {:ok, results} ->
          {:noreply, assign(socket, :search_results, results)}

        {:error, _} ->
          {:noreply, assign(socket, :search_results, [])}
      end
    else
      {:noreply, assign(socket, :search_results, [])}
    end
  end

  @impl true
  def handle_event("add_comparison", %{"character_id" => char_id_str}, socket) do
    case Integer.parse(char_id_str) do
      {char_id, ""} ->
        if char_id not in socket.assigns.comparison_characters and
             char_id != socket.assigns.character_id do
          updated_comparisons = [char_id | socket.assigns.comparison_characters] |> Enum.take(3)

          # Start loading comparison data
          send(self(), {:load_comparison_data, char_id})

          socket =
            socket
            |> assign(:comparison_characters, updated_comparisons)
            |> assign(:search_results, [])
            |> put_flash(:info, "Added character to comparison")

          {:noreply, socket}
        else
          {:noreply,
           put_flash(socket, :error, "Character already in comparison or is the same character")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid character ID")}
    end
  end

  @impl true
  def handle_event("remove_comparison", %{"character_id" => char_id_str}, socket) do
    case Integer.parse(char_id_str) do
      {char_id, ""} ->
        updated_comparisons = List.delete(socket.assigns.comparison_characters, char_id)
        {:noreply, assign(socket, :comparison_characters, updated_comparisons)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_vetting", _params, socket) do
    character_id = socket.assigns.character_id
    current_user_id = get_current_user_character_id(socket.assigns.current_user)

    # Start vetting analysis asynchronously
    Task.start(fn ->
      case WHVettingAnalyzer.analyze_character(character_id, current_user_id) do
        {:ok, vetting_record} ->
          # Broadcast update
          Phoenix.PubSub.broadcast(
            EveDmv.PubSub,
            "character:#{character_id}",
            {:vetting_complete, vetting_record}
          )

        {:error, reason} ->
          Logger.error(
            "Vetting analysis failed for character #{character_id}: #{inspect(reason)}"
          )
      end
    end)

    {:noreply, put_flash(socket, :info, "Vetting analysis started")}
  end

  @impl true
  def handle_info(:load_character_analysis, socket) do
    character_id = socket.assigns.character_id

    case IntelligenceCoordinator.analyze_character_comprehensive(character_id) do
      {:ok, comprehensive_analysis} ->
        # Add to analysis history
        history_entry = %{
          timestamp: DateTime.utc_now(),
          analysis: comprehensive_analysis,
          trigger: "manual_load"
        }

        updated_history = [history_entry | socket.assigns.analysis_history] |> Enum.take(10)

        socket =
          socket
          |> assign(:comprehensive_analysis, comprehensive_analysis)
          |> assign(:character_analysis, comprehensive_analysis.basic_analysis)
          |> assign(:correlation_data, comprehensive_analysis.correlations)
          |> assign(:analysis_history, updated_history)
          |> assign(:loading, false)
          |> assign(:error, nil)

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to load character analysis for #{character_id}: #{inspect(reason)}")

        socket =
          socket
          |> assign(:loading, false)
          |> assign(:error, "Failed to load character analysis: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:auto_refresh, socket) do
    if socket.assigns.auto_refresh do
      send(self(), :load_character_analysis)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:character_update, character_id, update_type}, socket) do
    if socket.assigns.real_time_enabled and character_id == socket.assigns.character_id do
      # Real-time character data update
      case update_type do
        :new_killmail ->
          # Invalidate cache and reload analysis
          IntelligenceCoordinator.invalidate_character_intelligence(character_id, "new_killmail")
          send(self(), :load_character_analysis)

          socket = put_flash(socket, :info, "New killmail data received - analysis updated")
          {:noreply, socket}

        :corp_change ->
          # Corporation change detected
          IntelligenceCoordinator.invalidate_character_intelligence(character_id, "corp_change")
          send(self(), :load_character_analysis)

          socket = put_flash(socket, :warning, "Corporation change detected - analysis updated")
          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:vetting_complete, _vetting_record}, socket) do
    # Vetting analysis completed
    socket =
      socket
      |> put_flash(:info, "Vetting analysis completed")

    # Reload comprehensive analysis to include new vetting data
    send(self(), :load_character_analysis)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:load_comparison_data, character_id}, socket) do
    # Load comparison character data (simplified for now)
    # In a full implementation, this would load and store comparison analysis
    Logger.info("Loading comparison data for character #{character_id}")
    {:noreply, socket}
  end

  # Helper functions

  defp search_characters(query) do
    case EsiClient.search_entities(query, [:character]) do
      {:ok, results} ->
        character_ids = Map.get(results, "character", [])
        fetch_character_details(character_ids)

      {:error, reason} ->
        Logger.warning("Character search failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_character_details([]), do: {:ok, []}

  defp fetch_character_details(character_ids) do
    {:ok, character_details} = EsiClient.get_characters(character_ids)
    formatted_results = format_search_results(character_details)
    {:ok, Enum.take(formatted_results, 5)}
  end

  defp format_search_results(character_details) when is_map(character_details) do
    Enum.map(character_details, fn {char_id, char_data} ->
      %{
        character_id: char_id,
        character_name: char_data["name"] || "Unknown",
        corporation_id: char_data["corporation_id"],
        corporation_name: char_data["corporation_name"]
      }
    end)
  end

  defp get_current_user_character_id(user) do
    case user do
      %{"character_id" => character_id} -> character_id
      _ -> nil
    end
  end
end
