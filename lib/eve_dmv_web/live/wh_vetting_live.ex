# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmvWeb.WHVettingLive do
  @moduledoc """
  LiveView for wormhole corporation vetting system.

  Provides comprehensive vetting analysis for potential recruits including:
  - J-space experience assessment
  - Security risk evaluation
  - Eviction group detection
  - Alt character analysis
  - Small gang competency scoring
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Api
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.Wormhole.Vetting, as: WHVetting
  alias EveDmv.IntelligenceMigrationAdapter

  require Logger

  on_mount({EveDmvWeb.AuthLive, :load_from_session})

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:tab, :dashboard)
      |> assign(:loading, false)
      |> assign(:error, nil)
      |> assign(:vetting_records, [])
      |> assign(:selected_record, nil)
      |> assign(:character_search, "")
      |> assign(:search_results, [])
      |> assign(:analysis_in_progress, false)

    # Load initial vetting records
    send(self(), :load_vetting_records)

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    tab = params["tab"] || "dashboard"

    socket = assign(socket, :tab, String.to_existing_atom(tab))

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/wh-vetting?tab=#{tab}")}
  end

  @impl Phoenix.LiveView
  def handle_event("search_character", %{"search" => %{"query" => query}}, socket) do
    if String.length(query) >= 3 do
      # Search for characters by name
      {:ok, results} = search_characters(query)
      {:noreply, assign(socket, :search_results, results)}
    else
      {:noreply, assign(socket, :search_results, [])}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("start_vetting", %{"character_id" => character_id_str}, socket) do
    case Integer.parse(character_id_str) do
      {character_id, ""} ->
        current_user_id = get_current_user_character_id(socket.assigns.current_user)

        socket = assign(socket, :analysis_in_progress, true)

        # Start vetting analysis asynchronously using Intelligence Engine
        Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
          # Use Intelligence Engine with comprehensive threat analysis for vetting
          analysis_opts = [scope: :full, parallel: true, requested_by_id: current_user_id]

          send(
            self(),
            {:vetting_complete, character_id,
             IntelligenceMigrationAdapter.analyze(:threat, character_id, analysis_opts)}
          )
        end)

        {:noreply, socket}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid character ID")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("view_vetting", %{"id" => vetting_id}, socket) do
    case Ash.get(WHVetting, vetting_id, domain: Api) do
      {:ok, record} ->
        {:noreply, assign(socket, :selected_record, record)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Vetting record not found")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_notes", %{"id" => vetting_id, "notes" => notes}, socket) do
    case Ash.get(WHVetting, vetting_id, domain: Api) do
      {:ok, record} ->
        case WHVetting.add_notes(record, notes) do
          {:ok, updated_record} ->
            socket =
              socket
              |> assign(:selected_record, updated_record)
              |> put_flash(:info, "Notes updated successfully")

            send(self(), :load_vetting_records)
            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update notes")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Vetting record not found")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("close_details", _params, socket) do
    {:noreply, assign(socket, :selected_record, nil)}
  end

  @impl Phoenix.LiveView
  def handle_info(:load_vetting_records, socket) do
    case WHVetting.get_recent(30) do
      {:ok, records} ->
        {:noreply, assign(socket, :vetting_records, records)}

      {:error, reason} ->
        Logger.error("Failed to load vetting records: #{inspect(reason)}")
        {:noreply, assign(socket, :vetting_records, [])}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:vetting_complete, character_id, result}, socket) do
    socket = assign(socket, :analysis_in_progress, false)

    case result do
      {:ok, analysis_result} ->
        # Transform Intelligence Engine result to vetting record if needed
        {:ok, _vetting_record} = transform_analysis_to_vetting_record(character_id, analysis_result)
        socket = put_flash(socket, :info, "Vetting analysis completed successfully")
        send(self(), :load_vetting_records)
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Vetting analysis failed for character #{character_id}: #{inspect(reason)}")
        {:noreply, put_flash(socket, :error, "Vetting analysis failed: #{inspect(reason)}")}
    end
  end

  # Helper functions

  defp transform_analysis_to_vetting_record(character_id, analysis_result) do
    # Extract threat analysis and vulnerability scan data from Intelligence Engine result
    threat_data = get_in(analysis_result, [:analysis, :vulnerability_scan]) || %{}
    character_data = get_in(analysis_result, [:analysis, :combat_stats]) || %{}

    # Transform to vetting record format expected by the UI
    vetting_data = %{
      character_id: character_id,
      risk_score: calculate_risk_score(threat_data),
      j_space_experience: extract_j_space_experience(character_data),
      security_concerns: extract_security_concerns(threat_data),
      recommendation: determine_recommendation(threat_data, character_data),
      analysis_metadata: analysis_result.metadata
    }

    # In a real implementation, you might save this to the database
    # For now, we'll just return success to indicate the transformation worked
    {:ok, vetting_data}
  end

  defp calculate_risk_score(threat_data) do
    # Calculate risk score based on threat analysis
    base_score = 20

    # Add risk factors
    risk_score =
      base_score +
        if(Map.get(threat_data, :eviction_group_member, false), do: 40, else: 0) +
        if(Map.get(threat_data, :known_spy, false), do: 50, else: 0) +
        if Map.get(threat_data, :suspicious_activity, false), do: 20, else: 0

    min(risk_score, 100)
  end

  defp extract_j_space_experience(character_data) do
    # Extract J-space related experience from character analysis
    %{
      total_j_kills: Map.get(character_data, :wormhole_kills, 0),
      total_j_losses: Map.get(character_data, :wormhole_losses, 0),
      j_space_time_percent: Map.get(character_data, :wormhole_activity_percent, 0.0)
    }
  end

  defp extract_security_concerns(threat_data) do
    # Extract security concerns from threat analysis
    initial_concerns = []

    eviction_concerns =
      if Map.get(threat_data, :eviction_group_member),
        do: ["Eviction group member" | initial_concerns],
        else: initial_concerns

    spy_concerns =
      if Map.get(threat_data, :known_spy),
        do: ["Known spy activity" | eviction_concerns],
        else: eviction_concerns

    final_concerns =
      if Map.get(threat_data, :suspicious_activity),
        do: ["Suspicious patterns detected" | spy_concerns],
        else: spy_concerns

    final_concerns
  end

  defp determine_recommendation(threat_data, character_data) do
    risk_score = calculate_risk_score(threat_data)
    experience = get_in(character_data, [:wormhole_activity_percent]) || 0.0

    cond do
      risk_score >= 70 -> "reject"
      risk_score >= 50 -> "conditional"
      experience >= 30 -> "approve"
      experience >= 10 -> "conditional"
      true -> "more_info"
    end
  end

  defp search_characters(query) do
    # Search for characters using ESI search API
    case EsiClient.search_entities(query, [:character]) do
      {:ok, results} ->
        character_ids = Map.get(results, "character", [])
        process_character_search_results(character_ids)

      {:error, reason} ->
        Logger.warning("Character search failed: #{inspect(reason)}")
        {:ok, []}
    end
  end

  defp process_character_search_results([]), do: {:ok, []}

  defp process_character_search_results(character_ids) do
    # Fetch character details for the found IDs
    {:ok, character_details} = EsiClient.get_characters(character_ids)
    formatted_results = format_character_details(character_details)
    {:ok, Enum.take(formatted_results, 10)}
  end

  defp format_character_details(character_details) do
    Enum.map(character_details, fn {char_id, char_data} ->
      %{
        character_id: char_id,
        character_name: char_data["name"] || "Unknown",
        corporation_id: char_data["corporation_id"],
        corporation_name: char_data["corporation_name"],
        alliance_id: char_data["alliance_id"],
        alliance_name: char_data["alliance_name"]
      }
    end)
  end

  defp get_current_user_character_id(user) do
    # Extract character ID from current user
    case user do
      %{"character_id" => character_id} -> character_id
      _ -> nil
    end
  end

  defp format_risk_score(score) when is_integer(score) do
    case score do
      s when s >= 80 -> {"Critical", "text-red-600"}
      s when s >= 65 -> {"High", "text-orange-600"}
      s when s >= 35 -> {"Medium", "text-yellow-600"}
      s when s >= 20 -> {"Low", "text-blue-600"}
      _ -> {"Minimal", "text-green-600"}
    end
  end

  defp format_risk_score(_), do: {"Unknown", "text-gray-600"}

  defp format_experience_score(score) when is_integer(score) do
    case score do
      s when s >= 80 -> {"Expert", "text-purple-600"}
      s when s >= 60 -> {"Experienced", "text-blue-600"}
      s when s >= 40 -> {"Competent", "text-green-600"}
      s when s >= 20 -> {"Novice", "text-yellow-600"}
      _ -> {"Unknown", "text-gray-600"}
    end
  end

  defp format_experience_score(_), do: {"Unknown", "text-gray-600"}

  defp format_recommendation(recommendation) do
    case recommendation do
      "approve" -> {"Approve", "bg-green-100 text-green-800"}
      "conditional" -> {"Conditional", "bg-yellow-100 text-yellow-800"}
      "reject" -> {"Reject", "bg-red-100 text-red-800"}
      "more_info" -> {"More Info Needed", "bg-blue-100 text-blue-800"}
      _ -> {"Pending", "bg-gray-100 text-gray-800"}
    end
  end

  defp format_date(nil), do: "N/A"

  defp format_date(datetime) do
    case DateTime.from_naive(datetime, "Etc/UTC") do
      {:ok, dt} -> Calendar.strftime(dt, "%Y-%m-%d %H:%M")
      _ -> "Invalid date"
    end
  end

  defp j_space_summary(j_space_activity) when is_map(j_space_activity) do
    kills = j_space_activity["total_j_kills"] || 0
    losses = j_space_activity["total_j_losses"] || 0
    percent = j_space_activity["j_space_time_percent"] || 0.0

    "#{kills}K/#{losses}L (#{percent}% J-space)"
  end

  defp j_space_summary(_), do: "No data"

  defp competency_summary(competency_metrics) when is_map(competency_metrics) do
    small_gang = competency_metrics["small_gang_performance"] || %{}
    avg_size = small_gang["avg_gang_size"] || 1.0
    preferred = small_gang["preferred_size"] || "solo"

    "Avg gang: #{Float.round(avg_size, 1)}, Prefers: #{preferred}"
  end

  defp competency_summary(_), do: "No data"
end
