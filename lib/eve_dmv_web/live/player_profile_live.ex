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
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.{CharacterAnalyzer, CharacterStats}
  alias EveDmv.Killmails.HistoricalKillmailFetcher

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
      handle_unknown_character(character_id, socket)
    end
  end

  @impl true
  def handle_info({:character_esi_loaded, character_info, killmail_count}, socket) do
    character_id = socket.assigns.character_id

    if killmail_count > 0 do
      # We have killmail data, try to analyze
      case CharacterAnalyzer.analyze_character(character_id) do
        {:ok, analysis} ->
          # Create player stats from analysis
          case create_player_stats_from_analysis(character_id, analysis) do
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

        {:error, _} ->
          # Analysis failed but we have ESI info
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
    case create_player_stats(character_id) do
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

  defp create_player_stats(character_id) do
    # Analyze the character and create player stats
    case CharacterAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        create_player_stats_from_analysis(character_id, analysis)

      error ->
        error
    end
  end

  defp create_player_stats_from_analysis(character_id, analysis) do
    # Convert intelligence data to player stats format
    player_data = convert_intel_to_stats(character_id, analysis)
    Ash.create(PlayerStats, player_data, domain: Api)
  end

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

            send(parent_pid, {:character_esi_loaded, enriched_info, killmail_count})

          {:error, reason} ->
            Logger.warning("Failed to fetch historical killmails: #{inspect(reason)}")
            # Still show character info even if killmail fetch fails
            send(parent_pid, {:character_esi_loaded, enriched_info, 0})
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

  defp convert_intel_to_stats(character_id, intel) do
    %{
      character_id: character_id,
      character_name: intel.character_name || "Unknown",
      total_kills: intel.total_kills || 0,
      total_losses: intel.total_losses || 0,
      solo_kills: intel.solo_kills || 0,
      solo_losses: intel.solo_losses || 0,
      gang_kills: calculate_gang_kills(intel),
      gang_losses: calculate_gang_losses(intel),
      total_isk_destroyed: intel.total_isk_destroyed || Decimal.new(0),
      total_isk_lost: intel.total_isk_lost || Decimal.new(0),
      danger_rating: intel.danger_rating || 1,
      ship_types_used: get_ship_types_count(intel),
      avg_gang_size: intel.avg_gang_size || Decimal.new(1),
      preferred_gang_size: determine_gang_preference(intel.avg_gang_size),
      primary_activity: classify_activity(intel),
      last_updated: DateTime.utc_now()
    }
  end

  defp calculate_gang_kills(intel), do: (intel.total_kills || 0) - (intel.solo_kills || 0)
  defp calculate_gang_losses(intel), do: (intel.total_losses || 0) - (intel.solo_losses || 0)
  defp get_ship_types_count(intel), do: intel.ship_usage |> Map.keys() |> length()

  defp determine_gang_preference(avg_gang_size) when is_nil(avg_gang_size), do: "solo"

  defp determine_gang_preference(avg_gang_size) do
    size = Decimal.to_float(avg_gang_size)

    cond do
      size <= 1.2 -> "solo"
      size <= 5.0 -> "small_gang"
      size <= 15.0 -> "medium_gang"
      true -> "fleet"
    end
  end

  defp classify_activity(intel) do
    solo_ratio =
      if (intel.total_kills || 0) > 0 do
        (intel.solo_kills || 0) / (intel.total_kills || 1)
      else
        0
      end

    cond do
      solo_ratio > 0.7 -> "solo_pvp"
      solo_ratio > 0.3 -> "small_gang"
      true -> "fleet_pvp"
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

  def format_avg_gang_size(nil), do: "1.0"
  def format_avg_gang_size(size), do: format_number(size)

  def safe_security_status(nil), do: "0.00"

  def safe_security_status(status) when is_number(status),
    do: Float.round(status, 2) |> to_string()

  def safe_security_status(_), do: "0.00"

  def safe_character_age(nil), do: "Unknown"

  def safe_character_age(birthday) do
    days = DateTime.diff(DateTime.utc_now(), birthday, :day)

    if days >= 0 do
      years = (days / 365) |> trunc()
      "#{years} years"
    else
      "Unknown"
    end
  rescue
    _ -> "Unknown"
  end

  def format_net_isk(destroyed, lost) do
    net_isk = Decimal.sub(destroyed, lost)
    format_isk(net_isk)
  end

  def net_isk_class(destroyed, lost) do
    net_isk = Decimal.sub(destroyed, lost)
    if Decimal.positive?(net_isk), do: "text-green-400", else: "text-red-400"
  end

  def format_number(nil), do: "0"

  def format_number(number) when is_integer(number) do
    number |> Integer.to_string() |> add_commas()
  end

  def format_number(%Decimal{} = number), do: number |> Decimal.to_float() |> format_number()

  def format_number(number) when is_float(number) do
    cond do
      number >= 1_000_000_000 ->
        "#{Float.round(number / 1_000_000_000, 1)}B"

      number >= 1_000_000 ->
        "#{Float.round(number / 1_000_000, 1)}M"

      number >= 1_000 ->
        "#{Float.round(number / 1_000, 1)}K"

      true ->
        number |> Float.round(2) |> Float.to_string() |> add_commas()
    end
  end

  defp add_commas(number_string) do
    number_string
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_isk(nil), do: "0 ISK"
  def format_isk(amount), do: "#{format_number(amount)} ISK"

  def format_percentage(nil), do: "0%"

  def format_percentage(%Decimal{} = decimal) do
    decimal |> Decimal.to_float() |> format_percentage()
  end

  def format_percentage(percentage) do
    "#{Float.round(percentage, 1)}%"
  end

  def format_ratio(kills, losses) do
    if losses > 0 do
      ratio = kills / losses
      Float.round(ratio, 2)
    else
      kills
    end
  end

  def danger_badge(rating) do
    stars = String.duplicate("⭐", rating)

    class =
      case rating do
        5 -> "bg-red-600 text-white"
        4 -> "bg-red-500 text-white"
        3 -> "bg-yellow-500 text-black"
        2 -> "bg-blue-500 text-white"
        _ -> "bg-gray-500 text-white"
      end

    {stars, class}
  end

  def activity_badge(activity) do
    case activity do
      "solo_pvp" -> {"🎯 Solo PvP", "bg-purple-600 text-white"}
      "small_gang" -> {"👥 Small Gang", "bg-blue-600 text-white"}
      "fleet_pvp" -> {"🚢 Fleet PvP", "bg-green-600 text-white"}
      _ -> {"❓ Unknown", "bg-gray-600 text-white"}
    end
  end

  def gang_size_badge(size) do
    case size do
      "solo" -> {"🎯 Solo", "bg-purple-600 text-white"}
      "small_gang" -> {"👥 Small Gang", "bg-blue-600 text-white"}
      "medium_gang" -> {"👥 Medium Gang", "bg-yellow-600 text-black"}
      "fleet" -> {"🚢 Fleet", "bg-green-600 text-white"}
      _ -> {"❓ Unknown", "bg-gray-600 text-white"}
    end
  end

  # Template component functions

  def player_stats_section(assigns) do
    ~H"""
    <!-- Player Statistics -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
      <!-- Basic Stats Card -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-blue-400">Basic Statistics</h3>

        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">Character:</span>
            <span class="font-medium">{@player_stats.character_name}</span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Total Kills:</span>
            <span class="font-medium text-green-400">
              {format_number(@player_stats.total_kills)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Total Losses:</span>
            <span class="font-medium text-red-400">
              {format_number(@player_stats.total_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">K/D Ratio:</span>
            <span class="font-medium">
              {format_ratio(@player_stats.total_kills, @player_stats.total_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">ISK Efficiency:</span>
            <span class="font-medium">
              {format_percentage(@player_stats.isk_efficiency_percent)}
            </span>
          </div>
        </div>
      </div>
      
    <!-- Solo vs Gang Stats -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-purple-400">Solo vs Gang Performance</h3>

        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">Solo Kills:</span>
            <span class="font-medium text-purple-400">
              {format_number(@player_stats.solo_kills)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Solo Losses:</span>
            <span class="font-medium text-purple-300">
              {format_number(@player_stats.solo_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Gang Kills:</span>
            <span class="font-medium text-blue-400">
              {format_number(@player_stats.gang_kills)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Gang Losses:</span>
            <span class="font-medium text-blue-300">
              {format_number(@player_stats.gang_losses)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Solo K/D:</span>
            <span class="font-medium">
              {format_ratio(@player_stats.solo_kills, @player_stats.solo_losses)}
            </span>
          </div>
        </div>
      </div>
      
    <!-- ISK Statistics -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-yellow-400">ISK Performance</h3>

        <div class="space-y-3">
          <div class="flex justify-between">
            <span class="text-gray-400">ISK Destroyed:</span>
            <span class="font-medium text-green-400">
              {format_isk(@player_stats.total_isk_destroyed)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">ISK Lost:</span>
            <span class="font-medium text-red-400">
              {format_isk(@player_stats.total_isk_lost)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Net ISK:</span>
            <span class={"font-medium #{net_isk_class(@player_stats.total_isk_destroyed, @player_stats.total_isk_lost)}"}>
              > {format_net_isk(@player_stats.total_isk_destroyed, @player_stats.total_isk_lost)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Efficiency:</span>
            <span class="font-medium">
              {format_percentage(@player_stats.isk_efficiency_percent)}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- Additional Information -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      <!-- Activity & Behavior -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-cyan-400">Activity & Behavior</h3>

        <div class="space-y-4">
          <div class="flex justify-between items-center">
            <span class="text-gray-400">Danger Rating:</span>
            <div>
              <% {stars, badge_class} = danger_badge(@player_stats.danger_rating) %>
              <span class={"px-2 py-1 rounded text-sm font-medium #{badge_class}"}>> {stars}</span>
            </div>
          </div>

          <div class="flex justify-between items-center">
            <span class="text-gray-400">Primary Activity:</span>
            <div>
              <% {activity_text, activity_class} =
                activity_badge(@player_stats.primary_activity) %>
              <span class={"px-2 py-1 rounded text-sm font-medium #{activity_class}"}>
                > {activity_text}
              </span>
            </div>
          </div>

          <div class="flex justify-between items-center">
            <span class="text-gray-400">Gang Preference:</span>
            <div>
              <% {gang_text, gang_class} = gang_size_badge(@player_stats.preferred_gang_size) %>
              <span class={"px-2 py-1 rounded text-sm font-medium #{gang_class}"}>> {gang_text}</span>
            </div>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Avg Gang Size:</span>
            <span class="font-medium">
              {format_avg_gang_size(@player_stats.avg_gang_size)}
            </span>
          </div>

          <div class="flex justify-between">
            <span class="text-gray-400">Ship Types Used:</span>
            <span class="font-medium">{@player_stats.ship_types_used}</span>
          </div>
        </div>
      </div>
      
    <!-- Ship Information -->
      <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
        <h3 class="text-lg font-bold mb-4 text-orange-400">Ship Usage</h3>

        <div class="space-y-3">
          <%= if @player_stats.favorite_ship_name do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Favorite Ship:</span>
              <span class="font-medium text-orange-400">
                {@player_stats.favorite_ship_name}
              </span>
            </div>
          <% end %>

          <div class="flex justify-between">
            <span class="text-gray-400">Ship Diversity:</span>
            <span class="font-medium">
              {@player_stats.ship_types_used} different ships
            </span>
          </div>

          <%= if @player_stats.active_regions && @player_stats.active_regions > 0 do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Active Regions:</span>
              <span class="font-medium">{@player_stats.active_regions}</span>
            </div>
          <% end %>

          <%= if @player_stats.home_region_name do %>
            <div class="flex justify-between">
              <span class="text-gray-400">Home Region:</span>
              <span class="font-medium">{@player_stats.home_region_name}</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Time Information -->
    <%= if @player_stats.last_updated do %>
      <div class="bg-gray-800 rounded-lg p-4 border border-gray-700">
        <div class="flex justify-between items-center text-sm text-gray-400">
          <span>
            Statistics last updated: {Calendar.strftime(
              @player_stats.last_updated,
              "%Y-%m-%d %H:%M:%S UTC"
            )}
          </span>
          <%= if @player_stats.stats_period_start && @player_stats.stats_period_end do %>
            <span>
              Period: {Date.to_string(@player_stats.stats_period_start)} to {Date.to_string(
                @player_stats.stats_period_end
              )}
            </span>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  def character_info_section(assigns) do
    ~H"""
    <!-- Character Info Only (ESI Data) -->
    <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
      <h2 class="text-2xl font-bold mb-4">{@character_info.name}</h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <span class="text-gray-400">Corporation:</span>
          <span class="text-white ml-2">
            {@character_info[:corporation_name] || "Unknown"}
          </span>
        </div>

        <%= if @character_info[:alliance_name] do %>
          <div>
            <span class="text-gray-400">Alliance:</span>
            <span class="text-white ml-2">{@character_info[:alliance_name]}</span>
          </div>
        <% end %>

        <div>
          <span class="text-gray-400">Security Status:</span>
          <span class="text-white ml-2">
            {safe_security_status(@character_info.security_status)}
          </span>
        </div>

        <%= if @character_info.birthday do %>
          <div>
            <span class="text-gray-400">Character Age:</span>
            <span class="text-white ml-2">
              {safe_character_age(@character_info.birthday)}
            </span>
          </div>
        <% end %>
      </div>

      <div class="mt-6 pt-6 border-t border-gray-700">
        <p class="text-gray-400 text-sm">
          This character has no killmail activity recorded. The information above is retrieved from EVE Online's ESI API.
        </p>
      </div>
    </div>
    """
  end

  def no_data_section(assigns) do
    ~H"""
    <!-- No Statistics Available -->
    <div class="bg-gray-800 rounded-lg p-8 border border-gray-700 text-center">
      <div class="text-gray-400 mb-4">
        <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
          >
          </path>
        </svg>
      </div>

      <h2 class="text-xl font-bold mb-2">No Statistics Available</h2>
      <p class="text-gray-400 mb-6">
        Player statistics have not been generated for this character yet.
      </p>

      <button
        phx-click="generate_stats"
        class="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded font-medium transition-colors"
      >
        📊 Generate Player Statistics
      </button>

      <%= if @character_intel do %>
        <div class="mt-6 pt-6 border-t border-gray-700">
          <p class="text-sm text-gray-400 mb-2">
            Character intelligence data is available:
          </p>
          <div class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <span class="text-gray-400">Kills:</span>
              <span class="text-green-400 ml-2">{@character_intel.total_kills || 0}</span>
            </div>
            <div>
              <span class="text-gray-400">Losses:</span>
              <span class="text-red-400 ml-2">{@character_intel.total_losses || 0}</span>
            </div>
          </div>
          <div class="mt-2">
            <a
              href={~p"/intel/#{@character_id}"}
              class="text-blue-400 hover:text-blue-300 underline text-sm"
            >
              View Character Intelligence →
            </a>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
