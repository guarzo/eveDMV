defmodule EveDmvWeb.SurveillanceProfilesLive do
  @moduledoc """
  LiveView for managing surveillance profiles.

  Features:
  - Create/Edit/Delete surveillance profiles
  - Hybrid filter builder (dropdowns + visual representation)
  - Real-time preview against last 1000 killmails
  - Chain filter validation with live Wanderer data
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Contexts.Surveillance
  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine
  alias EveDmv.Intelligence.WandererClient
  alias EveDmvWeb.SurveillanceProfilesLive.Helpers

  import Helpers

  require Logger

  @preview_killmail_limit 1000

  # LiveView lifecycle

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to real-time updates
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance:profiles")
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "wanderer:chain_updates")
    end

    socket =
      socket
      |> assign(:page_title, "Surveillance Profiles")
      |> assign(:profiles, [])
      |> assign(:editing_profile, nil)
      |> assign(:filter_preview, %{matches: [], count: 0, testing: false})
      |> assign(:chain_status, check_chain_status())
      |> load_profiles()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    case params do
      %{"action" => "new"} ->
        {:noreply, assign(socket, :editing_profile, new_profile())}

      %{"action" => "edit", "id" => id} ->
        profile = find_profile(socket.assigns.profiles, id)
        {:noreply, assign(socket, :editing_profile, profile)}

      _ ->
        {:noreply, assign(socket, :editing_profile, nil)}
    end
  end

  # Event handlers

  @impl Phoenix.LiveView
  def handle_event("new_profile", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/surveillance-profiles?action=new")}
  end

  @impl Phoenix.LiveView
  def handle_event("edit_profile", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/surveillance-profiles?action=edit&id=#{id}")}
  end

  @impl Phoenix.LiveView
  def handle_event("delete_profile", %{"id" => id}, socket) do
    case Surveillance.delete_profile(id) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Profile deleted successfully")
          |> load_profiles()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to delete profile: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_profile", %{"id" => id}, socket) do
    profile = find_profile(socket.assigns.profiles, id)
    enabled = !profile.enabled

    case Surveillance.update_profile(id, %{enabled: enabled}) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Profile #{if enabled, do: "enabled", else: "disabled"}")
          |> load_profiles()

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to update profile: #{inspect(reason)}")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save_profile", %{"profile" => profile_params}, socket) do
    case socket.assigns.editing_profile do
      %{id: nil} ->
        # Create new profile
        case Surveillance.create_profile(profile_params) do
          {:ok, _profile} ->
            socket =
              socket
              |> put_flash(:info, "Profile created successfully")
              |> assign(:editing_profile, nil)
              |> load_profiles()
              |> push_patch(to: ~p"/surveillance-profiles")

            {:noreply, socket}

          {:error, reason} ->
            socket = put_flash(socket, :error, "Failed to create profile: #{inspect(reason)}")
            {:noreply, socket}
        end

      %{id: id} ->
        # Update existing profile
        case Surveillance.update_profile(id, profile_params) do
          {:ok, _profile} ->
            socket =
              socket
              |> put_flash(:info, "Profile updated successfully")
              |> assign(:editing_profile, nil)
              |> load_profiles()
              |> push_patch(to: ~p"/surveillance-profiles")

            {:noreply, socket}

          {:error, reason} ->
            socket = put_flash(socket, :error, "Failed to update profile: #{inspect(reason)}")
            {:noreply, socket}
        end
    end
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_profile, nil)
     |> push_patch(to: ~p"/surveillance-profiles")}
  end

  @impl Phoenix.LiveView
  def handle_event("add_filter", %{"type" => filter_type}, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      new_filter = create_default_filter(filter_type)
      updated_criteria = add_filter_to_criteria(editing_profile.criteria, new_filter)
      updated_profile = %{editing_profile | criteria: updated_criteria}

      socket =
        socket
        |> assign(:editing_profile, updated_profile)
        |> update_filter_preview(updated_profile)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("remove_filter", %{"index" => index}, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      {index, _} = Integer.parse(index)
      updated_criteria = remove_filter_from_criteria(editing_profile.criteria, index)
      updated_profile = %{editing_profile | criteria: updated_criteria}

      socket =
        socket
        |> assign(:editing_profile, updated_profile)
        |> update_filter_preview(updated_profile)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event(
        "update_filter",
        %{"index" => index, "field" => field, "value" => value},
        socket
      ) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      {index, _} = Integer.parse(index)
      updated_criteria = update_filter_in_criteria(editing_profile.criteria, index, field, value)
      updated_profile = %{editing_profile | criteria: updated_criteria}

      socket =
        socket
        |> assign(:editing_profile, updated_profile)
        |> update_filter_preview(updated_profile)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("update_logic_operator", %{"operator" => operator}, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      operator_atom = String.to_existing_atom(operator)
      updated_criteria = Map.put(editing_profile.criteria, :logic_operator, operator_atom)
      updated_profile = %{editing_profile | criteria: updated_criteria}

      socket =
        socket
        |> assign(:editing_profile, updated_profile)
        |> update_filter_preview(updated_profile)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # PubSub handlers

  @impl Phoenix.LiveView
  def handle_info({:profile_updated, _profile}, socket) do
    {:noreply, load_profiles(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:chain_topology_update, _map_id, _data}, socket) do
    # Chain topology changed, update chain status
    socket = assign(socket, :chain_status, check_chain_status())
    {:noreply, socket}
  end

  def handle_info({:update_preview, profile}, socket) do
    # Get last 1000 killmails for testing
    preview_result = test_profile_against_killmails(profile)

    socket = assign(socket, :filter_preview, preview_result)
    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_profiles(socket) do
    case Surveillance.list_profiles(%{}) do
      {:ok, profiles} ->
        assign(socket, :profiles, profiles)

      {:error, reason} ->
        Logger.error("Failed to load profiles: #{inspect(reason)}")

        socket
        |> put_flash(:error, "Failed to load profiles")
        |> assign(:profiles, [])
    end
  end

  defp find_profile(profiles, id) do
    Enum.find(profiles, &(&1.id == id))
  end

  defp new_profile do
    %{
      id: nil,
      name: "",
      description: "",
      enabled: true,
      criteria: %{
        type: :custom_criteria,
        logic_operator: :and,
        conditions: []
      }
    }
  end

  defp check_chain_status do
    map_slug = get_default_map_slug()

    case WandererClient.get_chain_topology(map_slug) do
      {:ok, topology} ->
        %{
          connected: true,
          map_slug: map_slug,
          system_count: length(Map.get(topology, "systems", []))
        }

      {:error, _reason} ->
        %{
          connected: false,
          map_slug: map_slug,
          system_count: 0
        }
    end
  end

  defp get_default_map_slug do
    System.get_env("WANDERER_DEFAULT_MAP_SLUG", "default")
  end

  defp create_default_filter(filter_type) do
    case filter_type do
      "character" ->
        %{type: :character_watch, character_ids: []}

      "corporation" ->
        %{type: :corporation_watch, corporation_ids: []}

      "system" ->
        %{type: :system_watch, system_ids: []}

      "ship_type" ->
        %{type: :ship_type_watch, ship_type_ids: []}

      "alliance" ->
        %{type: :alliance_watch, alliance_ids: []}

      "chain" ->
        %{
          type: :chain_watch,
          map_id: get_default_map_slug(),
          chain_filter_type: :in_chain
        }

      "isk_value" ->
        %{type: :isk_value, operator: :greater_than, value: 1_000_000_000}

      "participant_count" ->
        %{type: :participant_count, operator: :greater_than, value: 5}

      _ ->
        %{type: :character_watch, character_ids: []}
    end
  end

  defp add_filter_to_criteria(criteria, new_filter) do
    conditions = Map.get(criteria, :conditions, [])
    Map.put(criteria, :conditions, conditions ++ [new_filter])
  end

  defp remove_filter_from_criteria(criteria, index) do
    conditions = Map.get(criteria, :conditions, [])
    updated_conditions = List.delete_at(conditions, index)
    Map.put(criteria, :conditions, updated_conditions)
  end

  defp update_filter_in_criteria(criteria, index, field, value) do
    conditions = Map.get(criteria, :conditions, [])

    if index < length(conditions) do
      condition = Enum.at(conditions, index)
      updated_condition = update_filter_field(condition, field, value)
      updated_conditions = List.replace_at(conditions, index, updated_condition)
      Map.put(criteria, :conditions, updated_conditions)
    else
      criteria
    end
  end

  defp update_filter_field(condition, field, value) do
    field_atom = String.to_existing_atom(field)

    case field_atom do
      :character_ids ->
        ids = parse_id_list(value)
        Map.put(condition, :character_ids, ids)

      :corporation_ids ->
        ids = parse_id_list(value)
        Map.put(condition, :corporation_ids, ids)

      :system_ids ->
        ids = parse_id_list(value)
        Map.put(condition, :system_ids, ids)

      :ship_type_ids ->
        ids = parse_id_list(value)
        Map.put(condition, :ship_type_ids, ids)

      :alliance_ids ->
        ids = parse_id_list(value)
        Map.put(condition, :alliance_ids, ids)

      :value ->
        {parsed_value, _} = Integer.parse(value)
        Map.put(condition, :value, parsed_value)

      :operator ->
        operator_atom = String.to_existing_atom(value)
        Map.put(condition, :operator, operator_atom)

      :chain_filter_type ->
        filter_type_atom = String.to_existing_atom(value)
        Map.put(condition, :chain_filter_type, filter_type_atom)

      :max_jumps ->
        {parsed_value, _} = Integer.parse(value)
        Map.put(condition, :max_jumps, parsed_value)

      _ ->
        condition
    end
  end

  defp parse_id_list(value) when is_binary(value) do
    value
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn id_str ->
      case Integer.parse(id_str) do
        {id, _} -> id
        :error -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_id_list(_), do: []

  defp update_filter_preview(socket, profile) do
    if profile.criteria && Map.get(profile.criteria, :conditions, []) != [] do
      # Start async preview update
      send(self(), {:update_preview, profile})
      assign(socket, :filter_preview, %{matches: [], count: 0, testing: true})
    else
      assign(socket, :filter_preview, %{matches: [], count: 0, testing: false})
    end
  end

  def handle_info({:update_preview, profile}, socket) do
    # Get last 1000 killmails for testing
    preview_result = test_profile_against_killmails(profile)

    socket = assign(socket, :filter_preview, preview_result)
    {:noreply, socket}
  end

  defp test_profile_against_killmails(profile) do
    try do
      # Get recent killmails for testing (simplified - would normally query database)
      test_killmails = get_recent_killmails_for_testing(@preview_killmail_limit)

      # Test criteria against killmails
      matches =
        test_killmails
        |> Enum.map(fn killmail ->
          case MatchingEngine.test_criteria(profile.criteria, killmail) do
            {:ok, result} ->
              if result.matches do
                %{
                  killmail_id: killmail.killmail_id,
                  victim_name: killmail.victim_character_name,
                  victim_ship: killmail.victim_ship_name,
                  isk_value: killmail.zkb_total_value,
                  timestamp: killmail.killmail_time
                }
              else
                nil
              end

            {:error, _} ->
              nil
          end
        end)
        |> Enum.reject(&is_nil/1)
        # Show top 10 matches
        |> Enum.take(10)

      %{
        matches: matches,
        count: length(matches),
        testing: false,
        total_tested: length(test_killmails)
      }
    rescue
      error ->
        Logger.error("Preview testing failed: #{inspect(error)}")
        %{matches: [], count: 0, testing: false, error: "Testing failed"}
    end
  end

  defp get_recent_killmails_for_testing(limit) do
    # Query recent killmails from the database for testing
    try do
      case Ash.read(EveDmv.Killmails.KillmailEnriched, limit: limit, sort: [killmail_time: :desc]) do
        {:ok, killmails} ->
          # Convert to format expected by matching engine
          Enum.map(killmails, &format_killmail_for_testing/1)

        {:error, reason} ->
          Logger.warning("Failed to fetch test killmails: #{inspect(reason)}")
          []
      end
    rescue
      error ->
        Logger.error("Error fetching test killmails: #{inspect(error)}")
        []
    end
  end

  defp format_killmail_for_testing(killmail) do
    # Convert killmail to the format expected by the matching engine
    raw_data = killmail.raw_data || %{}
    victim = Map.get(raw_data, "victim", %{})
    attackers = Map.get(raw_data, "attackers", [])
    zkb = Map.get(raw_data, "zkb", %{})

    %{
      killmail_id: killmail.killmail_id,
      solar_system_id: killmail.solar_system_id,
      killmail_time: killmail.killmail_time,
      zkb_total_value: Map.get(zkb, "totalValue", 0),
      victim: %{
        character_id: Map.get(victim, "character_id"),
        character_name: Map.get(victim, "character_name", "Unknown"),
        corporation_id: Map.get(victim, "corporation_id"),
        alliance_id: Map.get(victim, "alliance_id"),
        ship_type_id: Map.get(victim, "ship_type_id")
      },
      victim_character_name: Map.get(victim, "character_name", "Unknown"),
      victim_ship_name: Map.get(victim, "ship_name", "Unknown Ship"),
      attackers:
        Enum.map(attackers, fn attacker ->
          %{
            character_id: Map.get(attacker, "character_id"),
            corporation_id: Map.get(attacker, "corporation_id"),
            alliance_id: Map.get(attacker, "alliance_id"),
            ship_type_id: Map.get(attacker, "ship_type_id"),
            final_blow: Map.get(attacker, "final_blow", false)
          }
        end),
      raw_data: raw_data
    }
  end
end
