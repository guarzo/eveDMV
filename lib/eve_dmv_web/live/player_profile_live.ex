defmodule EveDmvWeb.PlayerProfileLive do
  @moduledoc """
  LiveView for displaying player PvP statistics and performance analytics.

  Shows comprehensive player statistics including K/D ratios, ISK efficiency,
  ship preferences, activity patterns, and historical performance.
  """

  use EveDmvWeb, :live_view

  require Logger

  alias EveDmv.Api
  alias EveDmv.Analytics.{AnalyticsEngine, PlayerStats}
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.PlayerProfile.{DataLoader, StatsGenerator}
  alias EveDmvWeb.{CharacterInfoComponent, NoDataComponent, PlayerStatsComponent}

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl true
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        socket =
          socket
          |> assign(:character_id, character_id)
          |> assign(:player_stats, nil)
          |> assign(:character_intel, nil)
          |> assign(:character_info, nil)
          |> assign(:loading, true)
          |> assign(:error, nil)
          |> assign(:no_data, false)

        # Load data asynchronously
        send(self(), {:load_character_data, character_id})

        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid character ID")
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  @impl true
  def handle_info({:load_character_data, character_id}, socket) do
    # Try to load from our database first
    player_stats = load_player_stats(character_id)
    character_intel = load_character_intel(character_id)

    if player_stats || character_intel do
      # We have some data in our database
      {:noreply,
       socket
       |> assign(:player_stats, player_stats)
       |> assign(:character_intel, character_intel)
       |> assign(:loading, false)}
    else
      # No data found, fetch from ESI and historical killmails
      DataLoader.load_character_data(character_id, self())
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:character_esi_loaded, character_info, killmail_count}, socket) do
    character_id = socket.assigns.character_id

    if killmail_count > 0 do
      # We have killmail data, try to analyze
      case StatsGenerator.create_player_stats(character_id) do
        {:ok, player_stats} ->
          character_intel = load_character_intel(character_id)

          {:noreply,
           socket
           |> assign(:player_stats, player_stats)
           |> assign(:character_intel, character_intel)
           |> assign(:character_info, character_info)
           |> assign(:loading, false)}

        {:error, _} ->
          # Show basic info only
          {:noreply,
           socket
           |> assign(:character_info, character_info)
           |> assign(:no_data, true)
           |> assign(:loading, false)}
      end
    else
      # No killmail data available
      {:noreply,
       socket
       |> assign(:character_info, character_info)
       |> assign(:no_data, true)
       |> assign(:loading, false)}
    end
  end

  @impl true
  def handle_info({:character_load_failed, reason}, socket) do
    error_msg =
      case reason do
        :character_not_found -> "Character not found in EVE"
        :esi_unavailable -> "Unable to fetch character information from EVE servers"
        :esi_timeout -> "Request timed out while fetching character information"
        _ -> "Failed to load character data"
      end

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, error_msg)}
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    character_id = socket.assigns.character_id

    # Trigger analytics calculation for this character
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      AnalyticsEngine.calculate_player_stats(days: 90, batch_size: 1)
    end)

    # Reload the statistics
    player_stats = load_player_stats(character_id)
    character_intel = load_character_intel(character_id)

    socket =
      socket
      |> assign(:player_stats, player_stats)
      |> assign(:character_intel, character_intel)
      |> put_flash(:info, "Statistics refreshed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("generate_stats", _params, socket) do
    character_id = socket.assigns.character_id

    # Generate statistics if they don't exist
    case StatsGenerator.create_player_stats(character_id) do
      {:ok, _stats} ->
        player_stats = load_player_stats(character_id)

        socket =
          socket
          |> assign(:player_stats, player_stats)
          |> put_flash(:info, "Player statistics generated successfully")

        {:noreply, socket}

      {:error, error} ->
        socket = put_flash(socket, :error, "Failed to generate statistics: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  # Private helper functions

  defp load_player_stats(character_id) do
    case Ash.get(PlayerStats, character_id: character_id, domain: Api) do
      {:ok, stats} -> stats
      {:error, _} -> nil
    end
  end

  defp load_character_intel(character_id) do
    case Ash.get(CharacterStats, character_id: character_id, domain: Api) do
      {:ok, intel} -> intel
      {:error, _} -> nil
    end
  end

  # Template helper functions

  def generate_stats_button_html(nil, assigns) do
    ~H"""
    <button
      phx-click="generate_stats"
      class="bg-green-600 hover:bg-green-700 text-white px-3 py-1 rounded text-sm font-medium transition-colors"
    >
      📊 Generate Stats
    </button>
    """
  end

  def generate_stats_button_html(_, assigns), do: ~H""
end
