defmodule EveDmvWeb.KillmailLive do
  @moduledoc """
  LiveView for displaying individual killmail details.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Market.PriceService

  import Ash.Query
  require Logger

  @impl true
  def mount(%{"killmail_id" => killmail_id_str}, _session, socket) do
    case Integer.parse(killmail_id_str) do
      {killmail_id, ""} ->
        socket =
          socket
          |> assign(:killmail_id, killmail_id)
          |> assign(:killmail, nil)
          |> assign(:loading, true)
          |> assign(:error, nil)
          |> assign(:export_format, "json")
          |> load_killmail(killmail_id)

        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(:error, "Invalid killmail ID")
          |> assign(:loading, false)

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("export_killmail", %{"format" => format}, socket) do
    case socket.assigns.killmail do
      nil ->
        {:noreply, put_flash(socket, :error, "No killmail data to export")}

      killmail ->
        case generate_export_data(killmail, format) do
          {:ok, {filename, content, content_type}} ->
            socket =
              socket
              |> push_event("download_file", %{
                filename: filename,
                content: content,
                content_type: content_type
              })
              |> put_flash(:info, "Export generated successfully")

            {:noreply, socket}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
        end
    end
  end

  @impl true
  def handle_event("change_export_format", %{"format" => format}, socket) do
    {:noreply, assign(socket, :export_format, format)}
  end

  @impl true
  def handle_event("copy_zkb_link", _params, socket) do
    case socket.assigns.killmail do
      nil ->
        {:noreply, put_flash(socket, :error, "No killmail to copy")}

      killmail ->
        zkb_url = "https://zkillboard.com/kill/#{killmail.killmail_id}/"

        socket =
          socket
          |> push_event("copy_to_clipboard", %{text: zkb_url})
          |> put_flash(:info, "zKillboard URL copied to clipboard")

        {:noreply, socket}
    end
  end

  # Private functions

  defp load_killmail(socket, killmail_id) do
    task = Task.async(fn -> fetch_killmail_details(killmail_id) end)

    socket
    |> assign(:loading_task, task)
    |> assign(:loading, true)
  end

  @impl true
  def handle_info({ref, result}, socket) when socket.assigns.loading_task.ref == ref do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, killmail} ->
        socket
        |> assign(:killmail, killmail)
        |> assign(:loading, false)
        |> assign(:loading_task, nil)

      {:error, reason} ->
        socket
        |> assign(:error, reason)
        |> assign(:loading, false)
        |> assign(:loading_task, nil)
    end
    |> then(&{:noreply, &1})
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Handle task crash
    socket =
      socket
      |> assign(:error, "Failed to load killmail")
      |> assign(:loading, false)
      |> assign(:loading_task, nil)

    {:noreply, socket}
  end

  defp fetch_killmail_details(killmail_id) do
    try do
      query =
        KillmailRaw
        |> new()
        |> filter(killmail_id: killmail_id)
        |> limit(1)

      case Ash.read(query, domain: Api) do
        {:ok, [killmail]} ->
          # Enrich killmail with additional data
          enriched_killmail = enrich_killmail_data(killmail)
          {:ok, enriched_killmail}

        {:ok, []} ->
          {:error, "Killmail not found"}

        {:error, error} ->
          Logger.error("Failed to fetch killmail #{killmail_id}: #{inspect(error)}")
          {:error, "Database error"}
      end
    rescue
      error ->
        Logger.error("Exception fetching killmail #{killmail_id}: #{inspect(error)}")
        {:error, "Failed to load killmail"}
    end
  end

  defp enrich_killmail_data(killmail) do
    # Calculate killmail value
    killmail_value =
      case PriceService.calculate_killmail_value(killmail) do
        {:ok, %{total_value: value}} -> value
        _ -> extract_zkb_value(killmail)
      end

    # Parse victim data
    victim_data = parse_victim_data(killmail)

    # Parse attackers data  
    attackers_data = parse_attackers_data(killmail)

    # Parse fitted items
    fitted_items = parse_fitted_items(killmail)

    killmail
    |> Map.put(:calculated_value, killmail_value)
    |> Map.put(:victim_details, victim_data)
    |> Map.put(:attackers_details, attackers_data)
    |> Map.put(:fitted_items, fitted_items)
    |> Map.put(:damage_stats, calculate_damage_stats(attackers_data))
  end

  defp extract_zkb_value(killmail) do
    case killmail.raw_data do
      %{"zkb" => %{"totalValue" => value}} when is_number(value) -> value
      _ -> 0
    end
  end

  defp parse_victim_data(killmail) do
    victim = killmail.raw_data["victim"] || %{}

    %{
      character_id: killmail.victim_character_id,
      character_name: victim["character_name"] || "Unknown",
      corporation_id: killmail.victim_corporation_id,
      corporation_name: victim["corporation_name"] || "Unknown Corp",
      alliance_id: killmail.victim_alliance_id,
      alliance_name: victim["alliance_name"],
      ship_type_id: killmail.victim_ship_type_id,
      ship_name: victim["ship_type_name"] || "Unknown Ship",
      damage_taken: victim["damage_taken"] || 0,
      position: victim["position"]
    }
  end

  defp parse_attackers_data(killmail) do
    attackers = killmail.raw_data["attackers"] || []

    attackers
    |> Enum.map(fn attacker ->
      %{
        character_id: attacker["character_id"],
        character_name: attacker["character_name"] || "Unknown",
        corporation_id: attacker["corporation_id"],
        corporation_name: attacker["corporation_name"] || "Unknown Corp",
        alliance_id: attacker["alliance_id"],
        alliance_name: attacker["alliance_name"],
        ship_type_id: attacker["ship_type_id"],
        ship_name: attacker["ship_type_name"] || "Unknown Ship",
        weapon_type_id: attacker["weapon_type_id"],
        weapon_name: attacker["weapon_type_name"] || "Unknown Weapon",
        damage_done: attacker["damage_done"] || 0,
        final_blow: attacker["final_blow"] || false,
        security_status: attacker["security_status"] || 0.0
      }
    end)
    |> Enum.sort_by(& &1.damage_done, :desc)
  end

  defp parse_fitted_items(killmail) do
    victim = killmail.raw_data["victim"] || %{}
    items = victim["items"] || []

    items
    |> Enum.map(fn item ->
      %{
        type_id: item["typeID"],
        type_name: item["typeName"] || "Unknown Item",
        quantity_destroyed: item["quantityDestroyed"] || 0,
        quantity_dropped: item["quantityDropped"] || 0,
        flag: item["flag"] || 0,
        singleton: item["singleton"] || 0
      }
    end)
    |> Enum.group_by(fn item ->
      case item.flag do
        # High, Mid, Low slots
        f when f >= 11 and f <= 34 -> :fitted
        # Rig slots
        f when f >= 92 and f <= 99 -> :fitted
        # Subsystem slots
        f when f >= 125 and f <= 132 -> :fitted
        # Cargo bay
        5 -> :cargo
        _ -> :other
      end
    end)
  end

  defp calculate_damage_stats(attackers) do
    total_damage = Enum.sum(Enum.map(attackers, & &1.damage_done))
    final_blow_attacker = Enum.find(attackers, & &1.final_blow)

    %{
      total_damage: total_damage,
      attacker_count: length(attackers),
      final_blow_attacker: final_blow_attacker,
      # Already sorted by damage
      top_damage_dealer: List.first(attackers)
    }
  end

  defp generate_export_data(killmail, format) do
    case format do
      "json" ->
        content = Jason.encode!(killmail, pretty: true)
        filename = "killmail_#{killmail.killmail_id}.json"
        {:ok, {filename, content, "application/json"}}

      "csv" ->
        case generate_csv_export(killmail) do
          {:ok, content} ->
            filename = "killmail_#{killmail.killmail_id}.csv"
            {:ok, {filename, content, "text/csv"}}

          error ->
            error
        end

      _ ->
        {:error, "Unsupported format"}
    end
  end

  defp generate_csv_export(killmail) do
    try do
      # Create CSV with killmail summary and attackers
      headers = [
        "killmail_id",
        "killmail_time",
        "system_id",
        "victim_name",
        "victim_corp",
        "victim_ship",
        "attacker_name",
        "attacker_corp",
        "attacker_ship",
        "damage_done",
        "final_blow",
        "total_value"
      ]

      base_data = [
        killmail.killmail_id,
        killmail.killmail_time,
        killmail.solar_system_id,
        killmail.victim_details.character_name,
        killmail.victim_details.corporation_name,
        killmail.victim_details.ship_name,
        "",
        "",
        "",
        "",
        "",
        killmail.calculated_value
      ]

      attacker_rows =
        killmail.attackers_details
        |> Enum.map(fn attacker ->
          [
            killmail.killmail_id,
            killmail.killmail_time,
            killmail.solar_system_id,
            killmail.victim_details.character_name,
            killmail.victim_details.corporation_name,
            killmail.victim_details.ship_name,
            attacker.character_name,
            attacker.corporation_name,
            attacker.ship_name,
            attacker.damage_done,
            attacker.final_blow,
            killmail.calculated_value
          ]
        end)

      all_rows = [headers] ++ if Enum.empty?(attacker_rows), do: [base_data], else: attacker_rows

      content =
        all_rows
        |> Enum.map(fn row ->
          row
          |> Enum.map(&to_string/1)
          |> Enum.map(&escape_csv_field/1)
          |> Enum.join(",")
        end)
        |> Enum.join("\n")

      {:ok, content}
    rescue
      error ->
        Logger.error("CSV export failed: #{inspect(error)}")
        {:error, "CSV generation failed"}
    end
  end

  defp escape_csv_field(field) do
    if String.contains?(field, [",", "\"", "\n"]) do
      "\"#{String.replace(field, "\"", "\"\"")}\""
    else
      field
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div id="file-download-hook" phx-hook="FileDownload" style="display: none;"></div>
      <div id="clipboard-hook" phx-hook="Clipboard" style="display: none;"></div>
      <div class="mb-6">
        <.link navigate={~p"/dashboard"} class="inline-flex items-center text-blue-400 hover:text-blue-300 transition-colors">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
          </svg>
          Back to Dashboard
        </.link>
      </div>

      <%= if @loading do %>
        <div class="bg-gray-800 rounded-lg p-8 text-center">
          <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-400 mx-auto mb-4"></div>
          <p class="text-gray-300">Loading killmail details...</p>
        </div>
      <% end %>

      <%= if @error do %>
        <div class="bg-red-900 border border-red-700 rounded-lg p-6">
          <h2 class="text-xl font-bold text-red-200 mb-2">Error</h2>
          <p class="text-red-300"><%= @error %></p>
        </div>
      <% end %>

      <%= if @killmail do %>
        <div class="space-y-6">
          <!-- Killmail Header -->
          <div class="bg-gray-800 rounded-lg p-6">
            <div class="flex justify-between items-start mb-4">
              <div>
                <h1 class="text-2xl font-bold text-white mb-2">
                  Killmail #<%= @killmail.killmail_id %>
                </h1>
                <p class="text-gray-400">
                  <%= Calendar.strftime(@killmail.killmail_time, "%Y-%m-%d %H:%M:%S UTC") %>
                  • System: <%= @killmail.solar_system_id %>
                </p>
              </div>
              <div class="flex space-x-2">
                <button 
                  phx-click="copy_zkb_link"
                  class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded transition-colors"
                  title="Copy zKillboard URL"
                >
                  📋 zKB Link
                </button>
              </div>
            </div>
            
            <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div class="bg-gray-700 rounded p-4">
                <h3 class="text-sm font-medium text-gray-400 mb-1">Total Value</h3>
                <p class="text-lg font-bold text-green-400">
                  <%= format_isk(@killmail.calculated_value) %> ISK
                </p>
              </div>
              <div class="bg-gray-700 rounded p-4">
                <h3 class="text-sm font-medium text-gray-400 mb-1">Attackers</h3>
                <p class="text-lg font-bold text-orange-400">
                  <%= length(@killmail.attackers_details) %>
                </p>
              </div>
              <div class="bg-gray-700 rounded p-4">
                <h3 class="text-sm font-medium text-gray-400 mb-1">Total Damage</h3>
                <p class="text-lg font-bold text-red-400">
                  <%= number_to_delimited(@killmail.damage_stats.total_damage) %>
                </p>
              </div>
            </div>
          </div>

          <!-- Victim Information -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-bold text-white mb-4">Victim</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <h3 class="text-lg font-medium text-red-400 mb-2">
                  <%= @killmail.victim_details.character_name %>
                </h3>
                <p class="text-gray-300 mb-1">
                  <span class="text-gray-400">Corporation:</span> 
                  <%= @killmail.victim_details.corporation_name %>
                </p>
                <%= if @killmail.victim_details.alliance_name do %>
                  <p class="text-gray-300 mb-1">
                    <span class="text-gray-400">Alliance:</span> 
                    <%= @killmail.victim_details.alliance_name %>
                  </p>
                <% end %>
                <p class="text-gray-300">
                  <span class="text-gray-400">Ship:</span> 
                  <%= @killmail.victim_details.ship_name %>
                </p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-400 mb-2">Damage Taken</h4>
                <p class="text-lg text-red-400">
                  <%= number_to_delimited(@killmail.victim_details.damage_taken) %>
                </p>
              </div>
            </div>
          </div>

          <!-- Attackers List -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-bold text-white mb-4">
              Attackers (<%= length(@killmail.attackers_details) %>)
            </h2>
            <div class="overflow-x-auto">
              <table class="min-w-full text-sm">
                <thead>
                  <tr class="border-b border-gray-700">
                    <th class="text-left py-2 text-gray-400">Character</th>
                    <th class="text-left py-2 text-gray-400">Corporation</th>
                    <th class="text-left py-2 text-gray-400">Ship</th>
                    <th class="text-left py-2 text-gray-400">Weapon</th>
                    <th class="text-right py-2 text-gray-400">Damage</th>
                    <th class="text-center py-2 text-gray-400">Final Blow</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for attacker <- @killmail.attackers_details do %>
                    <tr class="border-b border-gray-700/50">
                      <td class="py-2 text-white">
                        <%= attacker.character_name %>
                      </td>
                      <td class="py-2 text-gray-300">
                        <%= attacker.corporation_name %>
                      </td>
                      <td class="py-2 text-gray-300">
                        <%= attacker.ship_name %>
                      </td>
                      <td class="py-2 text-gray-300">
                        <%= attacker.weapon_name %>
                      </td>
                      <td class="py-2 text-right text-orange-400">
                        <%= number_to_delimited(attacker.damage_done) %>
                      </td>
                      <td class="py-2 text-center">
                        <%= if attacker.final_blow do %>
                          <span class="text-green-400">✓</span>
                        <% else %>
                          <span class="text-gray-600">—</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          </div>

          <!-- Fitted Items -->
          <%= if @killmail.fitted_items do %>
            <div class="bg-gray-800 rounded-lg p-6">
              <h2 class="text-xl font-bold text-white mb-4">Fitted Items</h2>
              
              <%= for {category, items} <- @killmail.fitted_items do %>
                <%= if not Enum.empty?(items) do %>
                  <div class="mb-4">
                    <h3 class="text-lg font-medium text-blue-400 mb-2 capitalize">
                      <%= category %> (<%= length(items) %>)
                    </h3>
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-2">
                      <%= for item <- items do %>
                        <div class="bg-gray-700 rounded p-3">
                          <p class="text-white font-medium"><%= item.type_name %></p>
                          <%= if item.quantity_destroyed > 0 or item.quantity_dropped > 0 do %>
                            <p class="text-sm text-gray-400">
                              <%= if item.quantity_destroyed > 0 do %>
                                Destroyed: <%= item.quantity_destroyed %>
                              <% end %>
                              <%= if item.quantity_dropped > 0 do %>
                                Dropped: <%= item.quantity_dropped %>
                              <% end %>
                            </p>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>

          <!-- Export Section -->
          <div class="bg-gray-800 rounded-lg p-6">
            <h2 class="text-xl font-bold text-white mb-4">Export Killmail Data</h2>
            <div class="flex items-center space-x-4">
              <select 
                phx-change="change_export_format" 
                name="format" 
                value={@export_format}
                class="bg-gray-700 border border-gray-600 text-white rounded px-3 py-2"
              >
                <option value="json">JSON</option>
                <option value="csv">CSV</option>
              </select>
              <button 
                phx-click="export_killmail" 
                phx-value-format={@export_format}
                class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded transition-colors"
              >
                Download <%= String.upcase(@export_format) %>
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper function for ISK formatting
  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000_000 -> "#{Float.round(value / 1_000_000_000_000, 1)}T"
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> number_to_delimited(round(value))
    end
  end

  defp format_isk(_), do: "0"

  # Helper function to replace Number.Delimit.number_to_delimited
  defp number_to_delimited(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/\d{3}(?=\d)/, "\\0,")
    |> String.reverse()
  end

  defp number_to_delimited(number) when is_float(number) do
    number
    |> round()
    |> number_to_delimited()
  end

  defp number_to_delimited(_), do: "0"
end
