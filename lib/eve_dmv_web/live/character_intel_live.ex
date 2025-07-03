defmodule EveDmvWeb.CharacterIntelLive do
  @moduledoc """
  LiveView for displaying hunter-focused character intelligence.

  Shows tactical information about a character including:
  - Ship preferences and typical fits
  - Gang composition and frequent associates
  - Geographic patterns and active zones
  - Target preferences and engagement patterns
  - Identified weaknesses and behavioral patterns
  """

  use EveDmvWeb, :live_view

  require Logger

  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.{CharacterAnalyzer, CharacterStats}
  alias EveDmv.Killmails.HistoricalKillmailFetcher

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl true
  def mount(%{"character_id" => character_id_str}, _session, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        socket =
          socket
          |> assign(:character_id, character_id)
          |> assign(:loading, true)
          |> assign(:error, nil)
          |> assign(:stats, nil)
          |> assign(:tab, :overview)

        # Load character stats asynchronously
        send(self(), {:load_character, character_id})

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
  def handle_params(params, _url, socket) do
    tab =
      case params["tab"] do
        "ships" -> :ships
        "associates" -> :associates
        "geography" -> :geography
        "weaknesses" -> :weaknesses
        _ -> :overview
      end

    {:noreply, assign(socket, :tab, tab)}
  end

  @impl true
  def handle_info({:load_character, character_id}, socket) do
    case load_or_analyze_character(character_id) do
      {:ok, stats} ->
        # Enrich associates data with corporation names and logistics flags
        enriched_stats = enrich_associates_data(stats)

        {:noreply,
         socket
         |> assign(:stats, enriched_stats)
         |> assign(:loading, false)
         |> assign(:error, nil)}

      {:error, :character_not_found} ->
        # Character not in our database, fetch from ESI and historical data
        handle_unknown_character(character_id, socket)

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error, format_error(reason))}
    end
  end

  @impl true
  def handle_info({:character_data_loaded, character_info, killmail_count}, socket) do
    # Re-analyze now that we have data
    character_id = socket.assigns.character_id

    if killmail_count > 0 do
      # We have killmail data, run analysis
      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, stats} ->
          enriched_stats = enrich_associates_data(stats)

          {:noreply,
           socket
           |> assign(:stats, enriched_stats)
           |> assign(:loading, false)
           |> assign(:error, nil)}

        {:error, _reason} ->
          # Show basic info even if analysis fails
          basic_stats = build_basic_stats(character_info)

          {:noreply,
           socket
           |> assign(:stats, basic_stats)
           |> assign(:loading, false)
           |> assign(:error, nil)}
      end
    else
      # No killmail data available
      basic_stats = build_basic_stats(character_info)

      {:noreply,
       socket
       |> assign(:stats, basic_stats)
       |> assign(:loading, false)
       |> assign(:error, nil)}
    end
  end

  @impl true
  def handle_info({:character_load_failed, reason}, socket) do
    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:error, format_error(reason))}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    character_id = socket.assigns.character_id

    socket =
      socket
      |> assign(:loading, true)
      |> assign(:error, nil)

    # Force re-analysis
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, _stats} ->
          send(self(), {:load_character, character_id})

        {:error, reason} ->
          require Logger
          Logger.warning("Character re-analysis failed for #{character_id}: #{inspect(reason)}")
          :ok
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:tab, String.to_atom(tab))
     |> push_patch(to: ~p"/intel/#{socket.assigns.character_id}?tab=#{tab}")}
  end

  # Private functions

  defp load_or_analyze_character(character_id) do
    # Try to load existing stats first
    case CharacterStats
         |> Ash.Query.for_read(:get_by_character_id, %{character_id: character_id})
         |> Ash.read_one(domain: EveDmv.Api) do
      {:ok, nil} ->
        # No stats exist, analyze the character
        CharacterAnalyzer.analyze_character(character_id)

      {:ok, stats} ->
        # Check if stats are stale (>24 hours old)
        staleness_threshold = Application.get_env(:eve_dmv, :character_stats_staleness_hours, 24)

        if stale_stats?(stats, staleness_threshold) do
          start_background_analysis(character_id)
        end

        {:ok, stats}

      {:error, error} ->
        {:error, error}
    end
  end

  defp stale_stats?(stats, threshold_hours) do
    case stats.last_calculated_at do
      nil ->
        true

      last_calc ->
        hours_old = DateTime.diff(DateTime.utc_now(), last_calc, :hour)
        hours_old > threshold_hours
    end
  end

  defp start_background_analysis(character_id) do
    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          require Logger

          Logger.warning(
            "Background character analysis failed for #{character_id}: #{inspect(reason)}"
          )

          :ok
      end
    end)
  end

  # Enrich associates data with corporation names and logistics detection
  defp enrich_associates_data(stats) do
    enriched_associates =
      stats.frequent_associates
      |> then(fn associates ->
        # Collect all unique corporation IDs first to avoid N+1 queries
        corp_ids =
          associates
          |> Enum.map(fn {_, associate} -> associate["corp_id"] end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        # Bulk load corporation names in single operation
        corp_names = EveDmv.Eve.NameResolver.corporation_names(corp_ids)

        # Now enrich each associate with cached data
        associates
        |> Enum.map(fn {char_id, associate} ->
          corp_name = corp_names[associate["corp_id"]] || "Unknown Corporation"

          # Detect logistics ships
          is_logistics = logistics_pilot?(associate["name"], associate["ships_flown"] || [])

          enriched_associate =
            associate
            |> Map.put("corp_name", corp_name)
            |> Map.put("is_logistics", is_logistics)

          {char_id, enriched_associate}
        end)
        |> Map.new()
      end)

    # Update the stats with enriched associates
    Map.put(stats, :frequent_associates, enriched_associates)
  end

  # Detect logistics pilots based on name and ships flown
  defp logistics_pilot?(name, ships_flown) do
    # Check pilot name for logistics indicators
    name_indicates_logi =
      name && String.contains?(String.downcase(name), ["logi", "guardian", "deacon", "scimi"])

    # Check ships flown for logistics ship types
    ships_indicate_logi =
      Enum.any?(ships_flown, fn ship ->
        String.contains?(String.downcase(ship), [
          "guardian",
          "basilisk",
          "oneiros",
          "scimitar",
          "deacon",
          "thalia",
          "minokawa",
          "apostle",
          "fax",
          "nestor"
        ])
      end)

    name_indicates_logi || ships_indicate_logi
  end

  defp format_error(:insufficient_activity),
    do: "Not enough activity to analyze (minimum 10 kills/losses required)"

  defp format_error(:character_not_found), do: "Character not found in killmail database"

  defp format_error(:esi_unavailable),
    do: "Unable to fetch character information from EVE servers"

  defp format_error(_), do: "Failed to load character intelligence"

  defp handle_unknown_character(character_id, socket) do
    parent_pid = self()

    Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
      # Fetch character info from ESI
      with {:ok, character_info} <- EsiClient.get_character(character_id),
           {:ok, corp_info} <- fetch_corporation_info(character_info.corporation_id),
           {:ok, alliance_info} <- fetch_alliance_info(character_info.alliance_id) do
        # Enrich character info
        enriched_info =
          character_info
          |> Map.put(:corporation_name, corp_info.name)
          |> Map.put(:corporation_ticker, corp_info.ticker)
          |> Map.put(:alliance_name, alliance_info[:name])
          |> Map.put(:alliance_ticker, alliance_info[:ticker])

        # Fetch historical killmails
        Logger.info("Fetching historical killmails for character #{character_id}")

        case HistoricalKillmailFetcher.fetch_character_history(character_id) do
          {:ok, killmail_count} ->
            Logger.info(
              "Fetched #{killmail_count} historical killmails for character #{character_id}"
            )

            send(parent_pid, {:character_data_loaded, enriched_info, killmail_count})

          {:error, reason} ->
            Logger.warning("Failed to fetch historical killmails: #{inspect(reason)}")
            # Still show character info even if killmail fetch fails
            send(parent_pid, {:character_data_loaded, enriched_info, 0})
        end
      else
        {:error, :not_found} ->
          send(parent_pid, {:character_load_failed, :character_not_found})

        {:error, _reason} ->
          send(parent_pid, {:character_load_failed, :esi_unavailable})
      end
    end)

    # Keep loading state
    {:noreply, socket}
  end

  defp fetch_corporation_info(nil), do: {:ok, %{name: nil, ticker: nil}}

  defp fetch_corporation_info(corp_id) do
    case EsiClient.get_corporation(corp_id) do
      {:ok, corp} -> {:ok, corp}
      _ -> {:ok, %{name: "Unknown Corporation", ticker: "???"}}
    end
  end

  defp fetch_alliance_info(nil), do: {:ok, %{name: nil, ticker: nil}}

  defp fetch_alliance_info(alliance_id) do
    case EsiClient.get_alliance(alliance_id) do
      {:ok, alliance} -> {:ok, alliance}
      _ -> {:ok, %{name: "Unknown Alliance", ticker: "???"}}
    end
  end

  defp build_basic_stats(character_info) do
    %{
      character_id: character_info.character_id,
      character_name: character_info.name,
      corporation_id: character_info.corporation_id,
      corporation_name: character_info[:corporation_name] || "Unknown Corporation",
      alliance_id: character_info.alliance_id,
      alliance_name: character_info[:alliance_name],
      security_status: character_info.security_status || 0.0,
      birthday: character_info.birthday,
      # Basic stats with no data
      total_kills: 0,
      total_losses: 0,
      solo_kills: 0,
      solo_losses: 0,
      isk_destroyed: 0.0,
      isk_lost: 0.0,
      isk_efficiency: 50.0,
      kill_death_ratio: 0.0,
      dangerous_rating: 1,
      data_completeness: 0,
      ship_usage: %{},
      frequent_associates: %{},
      active_systems: %{},
      target_profile: %{},
      identified_weaknesses: %{"behavioral" => [], "technical" => [], "loss_patterns" => []},
      prime_timezone: "Unknown",
      home_system_id: nil,
      home_system_name: nil,
      avg_gang_size: 0.0,
      aggression_index: 0.0,
      no_killmail_data: true
    }
  end

  # View helpers

  defp danger_color(rating) when rating >= 4, do: "text-red-500"
  defp danger_color(rating) when rating >= 3, do: "text-yellow-500"
  defp danger_color(_), do: "text-green-500"

  defp format_isk(value) when is_float(value) do
    cond do
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{round(value)}"
    end
  end

  defp format_isk(_), do: "0"

  defp ship_success_color(rate) when rate >= 0.8, do: "text-green-400"
  defp ship_success_color(rate) when rate >= 0.6, do: "text-yellow-400"
  defp ship_success_color(_), do: "text-red-400"

  defp gang_size_label(size) when size <= 1.5, do: {"Solo", "text-purple-400"}
  defp gang_size_label(size) when size <= 5, do: {"Small Gang", "text-blue-400"}
  defp gang_size_label(size) when size <= 15, do: {"Mid Gang", "text-yellow-400"}
  defp gang_size_label(_), do: {"Fleet", "text-red-400"}

  defp security_color("highsec"), do: "text-green-400"
  defp security_color("lowsec"), do: "text-yellow-400"
  defp security_color("nullsec"), do: "text-red-400"
  defp security_color("wormhole"), do: "text-purple-400"
  defp security_color(_), do: "text-gray-400"

  defp weakness_icon("predictable_schedule"), do: "🕐"
  defp weakness_icon("overconfident"), do: "💀"
  defp weakness_icon("weak_to_neuts"), do: "⚡"
  defp weakness_icon(_), do: "⚠️"

  defp weakness_label("predictable_schedule"), do: "Predictable Schedule"
  defp weakness_label("overconfident"), do: "Takes Bad Fights"
  defp weakness_label("weak_to_neuts"), do: "Vulnerable to Neuts"
  defp weakness_label(weakness), do: Phoenix.Naming.humanize(weakness)
end
