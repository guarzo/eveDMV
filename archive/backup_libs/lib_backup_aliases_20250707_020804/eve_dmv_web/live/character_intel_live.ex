# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.CharacterIntelLive do
  @moduledoc """
  Consolidated character intelligence LiveView.

  Combines hunter-focused tactical intelligence with advanced analysis features
  including real-time updates, threat assessment, and comparison capabilities.
  """

  use EveDmvWeb, :live_view

  require Logger

  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.IntelligenceMigrationAdapter
  alias EveDmv.Killmails.HistoricalKillmailFetcher

  # Import reusable components
  import EveDmvWeb.Components.PageHeaderComponent
  import EveDmvWeb.Components.StatsGridComponent
  import EveDmvWeb.Components.LoadingStateComponent
  import EveDmvWeb.Components.ErrorStateComponent
  import EveDmvWeb.Components.TabNavigationComponent

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        if connected?(socket) do
          # Subscribe to real-time updates for this character
          Phoenix.PubSub.subscribe(EveDmv.PubSub, "character:#{character_id}")
          Phoenix.PubSub.subscribe(EveDmv.PubSub, "intelligence:updates")
        end

        socket =
          socket
          |> assign(:character_id, character_id)
          |> assign(:character_info, nil)
          |> assign(:killmail_count, 0)
          |> assign(:stats_loading, true)
          |> assign(:analysis_loading, true)
          |> assign(:current_tab, "overview")
          |> assign(:real_time_enabled, true)
          |> assign(:auto_refresh, false)
          |> assign(:refresh_interval, 30)
          |> assign(:comparison_characters, [])
          |> assign(:vetting_available, false)
          |> assign(:error_message, nil)

        # Start loading character data
        send(self(), {:load_character, character_id})

        {:ok, socket}

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid character ID")
         |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "overview"
    search_query = params["search"]

    socket =
      socket
      |> assign(:current_tab, tab)
      |> assign(:search_query, search_query)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:load_character, character_id}, socket) do
    # Start async character loading
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case EsiClient.get_character(character_id) do
        {:ok, character_info} ->
          # Get killmail count
          killmail_count = HistoricalKillmailFetcher.get_cached_killmail_count(character_id)
          send(self(), {:character_data_loaded, character_info, killmail_count})

        {:error, reason} ->
          send(self(), {:character_load_failed, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:character_data_loaded, character_info, killmail_count}, socket) do
    character_id = socket.assigns.character_id

    socket =
      socket
      |> assign(:character_info, character_info)
      |> assign(:killmail_count, killmail_count)
      |> assign(:stats_loading, false)

    # Load character analysis in background
    start_background_analysis(character_id)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:character_load_failed, reason}, socket) do
    Logger.error("Character load failed: #{inspect(reason)}")

    {:noreply,
     socket
     |> assign(:stats_loading, false)
     |> assign(:error_message, "Failed to load character data")
     |> put_flash(:error, "Character not found or ESI error")}
  end

  @impl Phoenix.LiveView
  def handle_info({:analysis_complete, analysis_data}, socket) do
    socket =
      socket
      |> assign(:analysis_data, analysis_data)
      |> assign(:analysis_loading, false)
      |> assign(:vetting_available, true)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info({:vetting_complete, vetting_data}, socket) do
    {:noreply, assign(socket, :vetting_data, vetting_data)}
  end

  @impl Phoenix.LiveView
  def handle_info(:auto_refresh, socket) do
    if socket.assigns.auto_refresh do
      character_id = socket.assigns.character_id
      start_background_analysis(character_id)
    end

    {:noreply, socket}
  end

  # Handle real-time PubSub updates
  @impl Phoenix.LiveView
  def handle_info({:character_update, character_id, update_data}, socket) do
    if socket.assigns.character_id == character_id and socket.assigns.real_time_enabled do
      # Update character data in real-time
      {:noreply, handle_real_time_update(socket, update_data)}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("refresh", _params, socket) do
    character_id = socket.assigns.character_id

    socket =
      socket
      |> assign(:analysis_loading, true)
      |> put_flash(:info, "Refreshing character analysis...")

    start_background_analysis(character_id)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/intel/#{socket.assigns.character_id}?tab=#{tab}")}
  end

  @impl Phoenix.LiveView
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

  @impl Phoenix.LiveView
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

  @impl Phoenix.LiveView
  def handle_event("search_character", %{"search" => %{"query" => query}}, socket) do
    if String.length(query) >= 3 do
      # Redirect to search results or update current view
      {:noreply,
       push_patch(socket, to: ~p"/intel/#{socket.assigns.character_id}?search=#{query}")}
    else
      {:noreply, put_flash(socket, :error, "Search query must be at least 3 characters")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("add_comparison", %{"character_id" => char_id_str}, socket) do
    case Integer.parse(char_id_str) do
      {char_id, ""} ->
        current_comparisons = socket.assigns.comparison_characters

        if char_id not in current_comparisons and length(current_comparisons) < 3 do
          socket =
            socket
            |> assign(:comparison_characters, [char_id | current_comparisons])
            |> put_flash(:info, "Character added to comparison")

          {:noreply, socket}
        else
          {:noreply, put_flash(socket, :error, "Maximum 3 characters can be compared")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid character ID")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("remove_comparison", %{"character_id" => char_id_str}, socket) do
    case Integer.parse(char_id_str) do
      {char_id, ""} ->
        socket =
          socket
          |> assign(
            :comparison_characters,
            List.delete(socket.assigns.comparison_characters, char_id)
          )
          |> put_flash(:info, "Character removed from comparison")

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("start_vetting", _params, socket) do
    character_id = socket.assigns.character_id

    socket = put_flash(socket, :info, "Starting vetting analysis...")

    # Start vetting analysis in background using Intelligence Engine
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case IntelligenceMigrationAdapter.analyze(:threat, character_id, scope: :full) do
        {:ok, vetting_data} ->
          send(self(), {:vetting_complete, vetting_data})

        {:error, reason} ->
          Logger.error("Vetting analysis failed: #{inspect(reason)}")
      end
    end)

    {:noreply, socket}
  end

  # Private helper functions

  defp start_background_analysis(character_id) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case load_or_analyze_character(character_id) do
        {:ok, analysis_data} ->
          send(self(), {:analysis_complete, analysis_data})

        {:error, reason} ->
          Logger.error("Analysis failed: #{inspect(reason)}")
      end
    end)
  end

  defp load_or_analyze_character(character_id) do
    # Check if we have recent stats
    case CharacterStats.get_by_character(character_id) do
      {:ok, stats} when stats != nil ->
        if stale_stats?(stats, 24) do
          # Stats are stale, trigger new analysis using Intelligence Engine
          IntelligenceMigrationAdapter.analyze(:character, character_id, scope: :standard)
        else
          # Use cached stats but transform to Intelligence Engine format
          {:ok, transform_legacy_stats_to_analysis(stats)}
        end

      {:ok, nil} ->
        # No stats available, run analysis using Intelligence Engine
        IntelligenceEngine.analyze(:character, character_id, scope: :standard)

      {:error, _reason} ->
        # Error loading stats, run analysis using Intelligence Engine
        IntelligenceEngine.analyze(:character, character_id, scope: :standard)
    end
  end

  defp stale_stats?(stats, threshold_hours) do
    if stats.updated_at do
      threshold = DateTime.add(DateTime.utc_now(), -threshold_hours, :hour)
      DateTime.compare(stats.updated_at, threshold) == :lt
    else
      true
    end
  end

  defp transform_legacy_stats_to_analysis(stats) do
    # Transform legacy CharacterStats format to Intelligence Engine analysis format
    %{
      domain: :character,
      entity_id: stats.character_id,
      scope: :standard,
      analysis: %{
        combat_stats: %{
          total_kills: stats.total_kills || 0,
          total_losses: stats.total_losses || 0,
          kill_death_ratio: calculate_kdr(stats.total_kills, stats.total_losses),
          isk_destroyed: stats.total_isk_destroyed || 0,
          isk_lost: stats.total_isk_lost || 0,
          isk_efficiency:
            calculate_isk_efficiency(stats.total_isk_destroyed, stats.total_isk_lost),
          most_used_ship: stats.most_used_ship,
          favorite_regions: stats.favorite_regions || []
        },
        behavioral_patterns: %{
          activity_pattern: "legacy_data",
          timezone_preference: "unknown",
          engagement_style: determine_engagement_style(stats)
        }
      },
      metadata: %{
        plugins_executed: [:legacy_transformation],
        plugins_successful: [:legacy_transformation],
        plugins_failed: [],
        analysis_duration_ms: 0,
        generated_at: stats.updated_at || DateTime.utc_now()
      }
    }
  end

  defp calculate_kdr(kills, losses) when is_number(kills) and is_number(losses) and losses > 0 do
    Float.round(kills / losses, 2)
  end

  defp calculate_kdr(kills, _losses) when is_number(kills), do: kills
  defp calculate_kdr(_kills, _losses), do: 0

  defp calculate_isk_efficiency(destroyed, lost)
       when is_number(destroyed) and is_number(lost) and destroyed + lost > 0 do
    Float.round(destroyed / (destroyed + lost) * 100, 1)
  end

  defp calculate_isk_efficiency(_destroyed, _lost), do: 0

  defp determine_engagement_style(stats) do
    cond do
      stats.avg_gang_size && stats.avg_gang_size <= 2 -> "solo"
      stats.avg_gang_size && stats.avg_gang_size <= 8 -> "small_gang"
      true -> "fleet"
    end
  end

  defp handle_real_time_update(socket, update_data) do
    # Handle different types of real-time updates
    case update_data.type do
      :killmail ->
        # Update killmail count and recent activity
        socket
        |> update(:killmail_count, &(&1 + 1))
        |> put_flash(:info, "New killmail detected")

      :analysis_update ->
        # Refresh analysis data
        assign(socket, :analysis_data, update_data.data)

      _ ->
        socket
    end
  end

  # Template rendering helpers

  def format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000_000 -> "#{Float.round(value / 1_000_000_000_000, 1)}T"
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{value}"
    end
  end

  def format_isk(_), do: "0"

  def threat_level_class(level) do
    case level do
      level when level >= 80 -> "text-red-600 font-bold"
      level when level >= 60 -> "text-orange-500 font-semibold"
      level when level >= 40 -> "text-yellow-500"
      _ -> "text-green-600"
    end
  end

  def tab_active_class(current_tab, tab) do
    if current_tab == tab do
      "border-blue-500 text-blue-600 font-medium"
    else
      "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end

  # Additional template helper functions for backward compatibility

  def danger_color(rating) when rating >= 4, do: "text-red-500"
  def danger_color(rating) when rating >= 3, do: "text-yellow-500"
  def danger_color(_), do: "text-green-500"

  def ship_success_color(rate) when rate >= 0.8, do: "text-green-400"
  def ship_success_color(rate) when rate >= 0.6, do: "text-yellow-400"
  def ship_success_color(_), do: "text-red-400"

  def gang_size_label(size) when size <= 1.5, do: {"Solo", "text-purple-400"}
  def gang_size_label(size) when size <= 5, do: {"Small Gang", "text-blue-400"}
  def gang_size_label(size) when size <= 15, do: {"Mid Gang", "text-yellow-400"}
  def gang_size_label(_), do: {"Fleet", "text-red-400"}

  def security_color("highsec"), do: "text-green-400"
  def security_color("lowsec"), do: "text-yellow-400"
  def security_color("nullsec"), do: "text-red-400"
  def security_color("wormhole"), do: "text-purple-400"
  def security_color(_), do: "text-gray-400"

  def weakness_icon("predictable_schedule"), do: "🕐"
  def weakness_icon("overconfident"), do: "💀"
  def weakness_icon("weak_to_neuts"), do: "⚡"
  def weakness_icon(_), do: "⚠️"

  def weakness_label("predictable_schedule"), do: "Predictable Schedule"
  def weakness_label("overconfident"), do: "Takes Bad Fights"
  def weakness_label("weak_to_neuts"), do: "Vulnerable to Neuts"
  def weakness_label(weakness), do: Phoenix.Naming.humanize(weakness)
end
