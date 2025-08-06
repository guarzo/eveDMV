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

  alias EveDmv.Contexts.Surveillance.Api, as: SurveillanceApi
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Intelligence.WandererClient
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Search.SearchSuggestionService

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
      |> assign(:preview_killmail_limit, @preview_killmail_limit)
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
    case safe_call(fn -> SurveillanceApi.delete_profile(id) end) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Profile deleted successfully")
          |> load_profiles()

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Failed to delete profile")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_profile", %{"id" => id}, socket) do
    profile = find_profile(socket.assigns.profiles, id)
    enabled = !profile.enabled

    case safe_call(fn ->
           SurveillanceApi.update_profile(id, %{enabled: enabled})
         end) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "Profile #{if enabled, do: "enabled", else: "disabled"}")
          |> load_profiles()

        {:noreply, socket}

      _ ->
        socket = put_flash(socket, :error, "Failed to update profile")
        {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("save_profile", %{"profile" => profile_params}, socket) do
    editing_profile = socket.assigns.editing_profile
    # Prepare profile data with our new criteria format
    profile_data = %{
      name: Map.get(profile_params, "name", ""),
      description: Map.get(profile_params, "description", ""),
      is_active: Map.get(profile_params, "enabled", "true") == "true",
      criteria: editing_profile.criteria,
      user_id: get_current_user_id(socket)
    }

    # Debug logging
    Logger.debug("Attempting to save profile with data: #{inspect(profile_data)}")

    case editing_profile do
      %{id: nil} ->
        # Create new profile
        case safe_call(fn -> EveDmv.Contexts.Surveillance.Api.create_profile(profile_data) end) do
          {:ok, _profile} ->
            socket =
              socket
              |> put_flash(:info, "Profile created successfully")
              |> assign(:editing_profile, nil)
              |> load_profiles()
              |> push_patch(to: ~p"/surveillance-profiles")

            {:noreply, socket}

          _ ->
            socket = put_flash(socket, :error, "Failed to create profile")
            {:noreply, socket}
        end

      %{id: id} ->
        # Update existing profile
        case safe_call(fn -> EveDmv.Contexts.Surveillance.Api.update_profile(id, profile_data) end) do
          {:ok, _profile} ->
            socket =
              socket
              |> put_flash(:info, "Profile updated successfully")
              |> assign(:editing_profile, nil)
              |> load_profiles()
              |> push_patch(to: ~p"/surveillance-profiles")

            {:noreply, socket}

          _ ->
            socket = put_flash(socket, :error, "Failed to update profile")
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
  def handle_event("add_nested_group", %{"parent_index" => parent_index}, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      {index, _} = Integer.parse(parent_index)
      nested_group = create_nested_group()

      updated_criteria =
        add_nested_group_to_criteria(editing_profile.criteria, index, nested_group)

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
  def handle_event("update_range_filter", params, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      index = String.to_integer(params["index"])
      field = params["field"]
      value = params["value"]

      updated_criteria =
        update_range_filter_in_criteria(
          editing_profile.criteria,
          index,
          field,
          value
        )

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
  def handle_event("update_temporal_filter", params, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      index = String.to_integer(params["index"])
      field = params["field"]
      value = params["value"]

      updated_criteria =
        update_temporal_filter_in_criteria(
          editing_profile.criteria,
          index,
          field,
          value
        )

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
  def handle_event("update_filter_field", %{"value" => value} = params, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      index = Map.get(params, "index")
      field = Map.get(params, "field")

      if index && field do
        {index_int, _} = Integer.parse(index)

        updated_criteria =
          update_filter_in_criteria(editing_profile.criteria, index_int, field, value)

        updated_profile = %{editing_profile | criteria: updated_criteria}

        socket =
          socket
          |> assign(:editing_profile, updated_profile)
          |> update_filter_preview(updated_profile)

        {:noreply, socket}
      else
        {:noreply, socket}
      end
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

  @impl Phoenix.LiveView
  def handle_event("update_profile_field", %{"field" => field, "value" => value}, socket) do
    editing_profile = socket.assigns.editing_profile

    if editing_profile do
      updated_profile = Map.put(editing_profile, String.to_existing_atom(field), value)
      socket = assign(socket, :editing_profile, updated_profile)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event(
        "search_autocomplete",
        %{"value" => query, "field" => field, "index" => index},
        socket
      ) do
    if String.length(query) >= 2 do
      suggestions = search_entity_suggestions(field, query)

      socket =
        socket
        |> assign(:autocomplete_suggestions, suggestions)
        |> assign(:autocomplete_field, field)
        |> assign(:autocomplete_index, index)
        |> push_event("show_autocomplete", %{
          input_id: "filter_#{index}_#{field}",
          suggestions: suggestions
        })

      {:noreply, socket}
    else
      socket = push_event(socket, "hide_autocomplete", %{})
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_event(
        "select_suggestion",
        %{"id" => suggestion_id, "field" => field, "index" => index},
        socket
      ) do
    editing_profile = socket.assigns.editing_profile

    Logger.debug(
      "HANDLE EVENT select_suggestion: id=#{suggestion_id}, field=#{field}, index=#{index}"
    )

    if editing_profile do
      {index_int, _} = Integer.parse(index)
      # Get current filter condition
      conditions = Map.get(editing_profile.criteria, :conditions, [])
      Logger.debug("Current conditions: #{inspect(conditions)}")

      if index_int < length(conditions) do
        condition = Enum.at(conditions, index_int)
        current_ids = Map.get(condition, String.to_existing_atom(field), [])
        # Convert current IDs to string for display, add new ID
        current_string = Enum.join(current_ids, ", ")

        new_value =
          if current_string == "",
            do: suggestion_id,
            else: current_string <> ", " <> suggestion_id

        Logger.debug("Current string: '#{current_string}', new value: '#{new_value}'")

        updated_criteria =
          update_filter_in_criteria(editing_profile.criteria, index_int, field, new_value)

        updated_profile = %{editing_profile | criteria: updated_criteria}
        Logger.debug("Updated profile criteria: #{inspect(updated_profile.criteria)}")
        # Don't trigger preview update immediately to avoid re-rendering during click
        socket =
          socket
          |> assign(:editing_profile, updated_profile)
          |> push_event("hide_autocomplete", %{})

        # Schedule preview update after a small delay to let the UI settle
        Process.send_after(self(), {:delayed_preview_update, updated_profile}, 100)
        {:noreply, socket}
      else
        Logger.debug(
          "Index #{index_int} out of bounds for conditions length #{length(conditions)}"
        )

        {:noreply, socket}
      end
    else
      Logger.debug("No editing profile found")
      {:noreply, socket}
    end
  end

  @impl Phoenix.LiveView
  def handle_info({:delayed_preview_update, profile}, socket) do
    socket = update_filter_preview(socket, profile)
    {:noreply, socket}
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

  @impl Phoenix.LiveView
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
    case safe_call(fn -> SurveillanceApi.list_profiles([]) end) do
      {:ok, profiles} ->
        # Profiles should already be in the correct format since we're not doing backwards compatibility
        formatted_profiles = Enum.map(profiles, &format_profile_for_ui/1)
        assign(socket, :profiles, formatted_profiles)

      _ ->
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

    case safe_call(fn -> WandererClient.get_chain_topology(map_slug) end) do
      {:ok, topology} ->
        %{
          connected: true,
          map_slug: map_slug,
          system_count: length(Map.get(topology, "systems", []))
        }

      _ ->
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
        %{type: :character, field: "character_ids", operator: :in, value: []}

      "corporation" ->
        %{type: :corporation, field: "corporation_ids", operator: :in, value: []}

      "system" ->
        %{type: :system, field: "system_ids", operator: :in, value: []}

      "ship_type" ->
        %{type: :ship_type, field: "ship_type_ids", operator: :in, value: []}

      "alliance" ->
        %{type: :alliance, field: "alliance_ids", operator: :in, value: []}

      "chain" ->
        %{
          type: :proximity,
          field: "chain_proximity",
          operator: :within,
          value: %{max_jumps_from_home: 5}
        }

      "isk_range" ->
        %{
          type: :range,
          field: "isk_value",
          operator: :between,
          value: {10_000_000, 1_000_000_000}
        }

      "time_range" ->
        %{type: :temporal, field: "time_of_day", operator: :between, value: {20, 23}}

      "system_distance" ->
        %{
          type: :proximity,
          field: "system_distance",
          operator: :within,
          value: %{systems: [], max_jumps: 3}
        }

      "nested_group" ->
        %{type: :nested, logic_operator: :and, nested_conditions: []}

      "participant_count" ->
        %{type: :range, field: "participant_count", operator: :greater_than, value: 5}

      _ ->
        %{type: :simple, field: "generic", operator: :equals, value: ""}
    end
  end

  defp add_filter_to_criteria(criteria, new_filter) do
    conditions = Map.get(criteria, :conditions, [])
    Map.put(criteria, :conditions, [new_filter | conditions] |> Enum.reverse())
  end

  defp create_nested_group do
    %{
      type: :nested,
      logic_operator: :and,
      nested_conditions: [
        %{type: :simple, field: "character_ids", operator: :in, value: []}
      ]
    }
  end

  defp add_nested_group_to_criteria(criteria, parent_index, nested_group) do
    conditions = Map.get(criteria, :conditions, [])

    if parent_index < length(conditions) do
      parent_condition = Enum.at(conditions, parent_index)

      if parent_condition.type == :nested do
        updated_nested_conditions = [nested_group | parent_condition.nested_conditions]
        updated_parent = %{parent_condition | nested_conditions: updated_nested_conditions}
        updated_conditions = List.replace_at(conditions, parent_index, updated_parent)
        Map.put(criteria, :conditions, updated_conditions)
      else
        criteria
      end
    else
      criteria
    end
  end

  defp update_range_filter_in_criteria(criteria, index, field, value) do
    conditions = Map.get(criteria, :conditions, [])

    if index < length(conditions) do
      condition = Enum.at(conditions, index)

      if condition.type == :range do
        updated_condition =
          case field do
            "min_value" ->
              {_old_min, max} = condition.value
              %{condition | value: {String.to_integer(value), max}}

            "max_value" ->
              {min, _old_max} = condition.value
              %{condition | value: {min, String.to_integer(value)}}

            "operator" ->
              %{condition | operator: String.to_existing_atom(value)}

            "single_value" ->
              %{condition | value: String.to_integer(value)}

            _ ->
              condition
          end

        updated_conditions = List.replace_at(conditions, index, updated_condition)
        Map.put(criteria, :conditions, updated_conditions)
      else
        criteria
      end
    else
      criteria
    end
  end

  defp update_temporal_filter_in_criteria(criteria, index, field, value) do
    conditions = Map.get(criteria, :conditions, [])

    if index < length(conditions) do
      condition = Enum.at(conditions, index)

      if condition.type == :temporal do
        updated_condition =
          case field do
            "start_hour" ->
              {_old_start, end_hour} = condition.value
              %{condition | value: {String.to_integer(value), end_hour}}

            "end_hour" ->
              {start_hour, _old_end} = condition.value
              %{condition | value: {start_hour, String.to_integer(value)}}

            "days_of_week" ->
              days = String.split(value, ",") |> Enum.map(&String.to_integer/1)
              %{condition | value: days}

            "time_unit" ->
              %{condition | operator: String.to_existing_atom(value)}

            "time_value" ->
              %{condition | value: String.to_integer(value)}

            _ ->
              condition
          end

        updated_conditions = List.replace_at(conditions, index, updated_condition)
        Map.put(criteria, :conditions, updated_conditions)
      else
        criteria
      end
    else
      criteria
    end
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

  defp test_profile_against_killmails(profile) do
    # Get recent killmails for testing (simplified - would normally query database)
    test_killmails = get_recent_killmails_for_testing(@preview_killmail_limit)

    # Use the advanced filter engine for enhanced matching
    # alias EveDmv.Contexts.ThreatSurveillance - not currently used

    # Test criteria against killmails
    matches =
      test_killmails
      |> Enum.map(fn killmail ->
        # Convert killmail to format expected by advanced engine
        killmail_data = format_killmail_for_engine(killmail)

        # Try advanced filter engine first if criteria structure supports it
        match_result =
          if has_advanced_criteria?(profile.criteria) do
            case EveDmv.Contexts.Surveillance.Domain.AdvancedFilterEngine.evaluate_complex_criteria(
                   profile.criteria,
                   killmail_data
                 ) do
              %{matches: true} = result -> {:advanced, result}
              %{matches: false} -> {:no_match, nil}
              _ -> {:fallback, nil}
            end
          else
            {:fallback, nil}
          end

        # Use result or fallback to original matching engine
        process_match_result(match_result, profile.criteria, killmail)
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

  defp get_recent_killmails_for_testing(limit) do
    # Query recent killmails from the database for testing
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)

    case Ash.read(query) do
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

  defp format_profile_for_ui(profile) do
    # Simply ensure the profile has the expected UI structure
    %{
      id: profile.id,
      name: profile.name || "",
      description: profile.description || "",
      enabled: profile.is_active || false,
      criteria:
        profile.criteria ||
          %{
            type: :custom_criteria,
            logic_operator: :and,
            conditions: []
          }
    }
  end

  defp get_current_user_id(socket) do
    # Get user ID from socket assigns if available
    case socket.assigns do
      %{current_user: %{id: user_id}} ->
        user_id

      %{user_id: user_id} when is_integer(user_id) ->
        user_id

      _ ->
        # Default to user ID 1 if not authenticated
        # In production, this would redirect to login
        1
    end
  end

  defp search_entity_suggestions(field, query) do
    # Use real database search for entity suggestions
    case field do
      "character_ids" ->
        get_character_suggestions(query)

      "corporation_ids" ->
        get_corporation_suggestions(query)

      "alliance_ids" ->
        get_alliance_suggestions(query)

      "system_ids" ->
        get_system_suggestions(query)

      "ship_type_ids" ->
        get_ship_suggestions(query)

      _ ->
        []
    end
  end

  defp get_character_suggestions(query) do
    case SearchSuggestionService.get_character_suggestions(query, limit: 5) do
      {:ok, suggestions} ->
        Enum.map(suggestions, fn suggestion ->
          %{id: suggestion.id, name: suggestion.name}
        end)

      {:error, _reason} ->
        []
    end
  end

  defp get_corporation_suggestions(query) do
    case SearchSuggestionService.get_corporation_suggestions(query, limit: 5) do
      {:ok, suggestions} ->
        Enum.map(suggestions, fn suggestion ->
          %{id: suggestion.id, name: suggestion.name}
        end)

      {:error, _reason} ->
        []
    end
  end

  defp get_alliance_suggestions(query) do
    case SearchSuggestionService.get_alliance_suggestions(query, limit: 5) do
      {:ok, suggestions} ->
        Enum.map(suggestions, fn suggestion ->
          %{id: suggestion.id, name: suggestion.name}
        end)

      {:error, _reason} ->
        []
    end
  end

  defp get_system_suggestions(query) do
    case SearchSuggestionService.get_system_suggestions(query, limit: 5) do
      {:ok, suggestions} ->
        Enum.map(suggestions, fn suggestion ->
          %{id: suggestion.id, name: suggestion.name}
        end)

      {:error, _reason} ->
        []
    end
  end

  defp get_ship_suggestions(query) do
    case SearchSuggestionService.get_ship_suggestions(query, limit: 5) do
      {:ok, suggestions} ->
        Enum.map(suggestions, fn suggestion ->
          %{id: suggestion.id, name: suggestion.name}
        end)

      {:error, _reason} ->
        []
    end
  end

  # Safe call helper for surveillance and other services
  defp safe_call(fun) when is_function(fun, 0) do
    fun.()
  rescue
    error ->
      Logger.error("Service call failed: #{inspect(error)}")
      {:error, :service_unavailable}
  catch
    :exit, reason ->
      Logger.error("Service process not available: #{inspect(reason)}")
      {:error, :service_unavailable}
  end

  # Helper functions for template rendering
  def format_filter_summary(criteria) when is_map(criteria) do
    conditions = Map.get(criteria, :conditions, [])

    if Enum.empty?(conditions) do
      "No filters configured"
    else
      count = length(conditions)
      "#{count} filter#{if count == 1, do: "", else: "s"} configured"
    end
  end

  def format_filter_summary(_), do: "No filters configured"

  def format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> format_datetime(dt)
      _ -> timestamp
    end
  end

  def format_timestamp(%DateTime{} = dt), do: format_datetime(dt)

  def format_timestamp(%NaiveDateTime{} = ndt) do
    case DateTimeUtils.to_datetime(ndt) do
      nil -> "Unknown"
      dt -> format_datetime(dt)
    end
  end

  def format_timestamp(_), do: "Unknown"

  defp format_datetime(dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_isk(value) when is_number(value) do
    # Format with thousand separators
    formatted =
      value
      |> round()
      |> Integer.to_string()
      |> String.graphemes()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.join(",")
      |> String.reverse()

    formatted
  end

  def format_isk(_), do: "0"

  def render_filter_inputs(assigns) do
    ~H"""
    <%= case @condition.type do %>
      <% type when type in [:character, :corporation, :alliance, :system, :ship_type] -> %>
        <div class="space-y-2">
          <input type="text"
                 phx-change="update_filter_field"
                 phx-value-field="value"
                 phx-value-index={@index}
                 value={format_list_value(@condition.value)}
                 placeholder={get_placeholder_for_field(@condition.field)}
                 class="mt-1 block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
          <div class="text-xs text-gray-400">Enter comma-separated values or names</div>
        </div>

      <% :range -> %>
        <div class="space-y-3">
          <div class="flex items-center space-x-2">
            <label class="text-sm text-gray-300">Operator:</label>
            <select
              phx-change="update_range_filter"
              phx-value-field="operator"
              phx-value-index={@index}
              class="px-2 py-1 bg-gray-700 border-gray-600 rounded text-sm text-gray-100"
            >
              <option value="between" selected={@condition.operator == :between}>Between</option>
              <option value="greater_than" selected={@condition.operator == :greater_than}>Greater Than</option>
              <option value="less_than" selected={@condition.operator == :less_than}>Less Than</option>
              <option value="greater_equal" selected={@condition.operator == :greater_equal}>Greater or Equal</option>
              <option value="less_equal" selected={@condition.operator == :less_equal}>Less or Equal</option>
            </select>
          </div>

          <%= if @condition.operator == :between do %>
            <div class="grid grid-cols-2 gap-2">
              <input type="number"
                     phx-change="update_range_filter"
                     phx-value-field="min_value"
                     phx-value-index={@index}
                     value={get_range_min(@condition.value)}
                     placeholder="Min value"
                     class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
              <input type="number"
                     phx-change="update_range_filter"
                     phx-value-field="max_value"
                     phx-value-index={@index}
                     value={get_range_max(@condition.value)}
                     placeholder="Max value"
                     class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
            </div>
          <% else %>
            <input type="number"
                   phx-change="update_range_filter"
                   phx-value-field="single_value"
                   phx-value-index={@index}
                   value={@condition.value}
                   placeholder="Value"
                   class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
          <% end %>
        </div>

      <% :temporal -> %>
        <div class="space-y-3">
          <%= case @condition.field do %>
            <% "time_of_day" -> %>
              <div class="grid grid-cols-2 gap-2">
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Start Hour (0-23)</label>
                  <input type="number"
                         min="0" max="23"
                         phx-change="update_temporal_filter"
                         phx-value-field="start_hour"
                         phx-value-index={@index}
                         value={get_range_min(@condition.value)}
                         class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
                </div>
                <div>
                  <label class="block text-xs text-gray-400 mb-1">End Hour (0-23)</label>
                  <input type="number"
                         min="0" max="23"
                         phx-change="update_temporal_filter"
                         phx-value-field="end_hour"
                         phx-value-index={@index}
                         value={get_range_max(@condition.value)}
                         class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
                </div>
              </div>

            <% "time_since" -> %>
              <div class="grid grid-cols-2 gap-2">
                <input type="number"
                       phx-change="update_temporal_filter"
                       phx-value-field="time_value"
                       phx-value-index={@index}
                       value={@condition.value}
                       placeholder="Time value"
                       class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
                <select
                  phx-change="update_temporal_filter"
                  phx-value-field="time_unit"
                  phx-value-index={@index}
                  class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                >
                  <option value="within_minutes" selected={@condition.operator == :within_minutes}>Minutes</option>
                  <option value="within_hours" selected={@condition.operator == :within_hours}>Hours</option>
                  <option value="within_days" selected={@condition.operator == :within_days}>Days</option>
                </select>
              </div>
          <% end %>
        </div>

      <% :proximity -> %>
        <div class="space-y-3">
          <%= case @condition.field do %>
            <% "chain_proximity" -> %>
              <div>
                <label class="block text-xs text-gray-400 mb-1">Max jumps from home system</label>
                <input type="number"
                       min="1" max="20"
                       phx-change="update_filter_field"
                       phx-value-field="max_jumps"
                       phx-value-index={@index}
                       value={get_in(@condition.value, [:max_jumps_from_home]) || 5}
                       class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
              </div>

            <% "system_distance" -> %>
              <div class="space-y-2">
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Target systems (comma-separated)</label>
                  <input type="text"
                         phx-change="update_filter_field"
                         phx-value-field="target_systems"
                         phx-value-index={@index}
                         value={format_list_value(get_in(@condition.value, [:systems]) || [])}
                         placeholder="System names or IDs"
                         class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
                </div>
                <div>
                  <label class="block text-xs text-gray-400 mb-1">Max jumps</label>
                  <input type="number"
                         min="1" max="10"
                         phx-change="update_filter_field"
                         phx-value-field="max_jumps"
                         phx-value-index={@index}
                         value={get_in(@condition.value, [:max_jumps]) || 3}
                         class="block w-full rounded-md bg-gray-700 border-gray-600 text-white shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" />
                </div>
              </div>
          <% end %>
        </div>

      <% :nested -> %>
        <div class="space-y-3 border-l-4 border-blue-500 pl-4">
          <div class="flex items-center space-x-2">
            <label class="text-sm text-gray-300">Group Logic:</label>
            <select
              phx-change="update_filter_field"
              phx-value-field="logic_operator"
              phx-value-index={@index}
              class="px-2 py-1 bg-gray-700 border-gray-600 rounded text-sm text-gray-100"
            >
              <option value="and" selected={@condition.logic_operator == :and}>ALL (AND)</option>
              <option value="or" selected={@condition.logic_operator == :or}>ANY (OR)</option>
            </select>
            <button
              type="button"
              phx-click="add_nested_group"
              phx-value-parent_index={@index}
              class="px-2 py-1 bg-green-600 hover:bg-green-700 rounded text-xs text-white"
            >
              + Add Condition
            </button>
          </div>

          <div class="text-sm text-gray-400">
            Nested conditions: <%= length(@condition.nested_conditions || []) %>
          </div>

          <!-- Nested conditions would be rendered recursively here -->
          <div class="ml-4 space-y-2 text-sm text-gray-500">
            <%= for {nested_condition, nested_index} <- Enum.with_index(@condition.nested_conditions || []) do %>
              <div class="p-2 bg-gray-800 rounded border border-gray-600">
                <%= format_filter_type(nested_condition.type) %> - <%= nested_condition.field || "No field" %>
                <button
                  type="button"
                  phx-click="remove_nested_condition"
                  phx-value-parent_index={@index}
                  phx-value-nested_index={nested_index}
                  class="ml-2 text-red-400 hover:text-red-300"
                >
                  ×
                </button>
              </div>
            <% end %>
          </div>
        </div>

      <% _ -> %>
        <div class="text-red-400">
          Unknown filter type: <%= @condition.type %>
          <div class="text-xs text-gray-500 mt-1">
            Field: <%= @condition.field || "N/A" %> | Operator: <%= @condition.operator || "N/A" %>
          </div>
        </div>
    <% end %>
    """
  end

  def format_filter_type(type) do
    case type do
      :simple -> "Simple Filter"
      :range -> "Range Filter"
      :temporal -> "Time-based Filter"
      :proximity -> "Proximity Filter"
      :nested -> "Nested Group"
      :character -> "Character"
      :corporation -> "Corporation"
      :alliance -> "Alliance"
      :system -> "System"
      :ship_type -> "Ship Type"
      :isk_value -> "ISK Value"
      _ -> "Unknown"
    end
  end

  defp format_list_value(value) when is_list(value) do
    Enum.join(value, ", ")
  end

  defp format_list_value(value), do: to_string(value)

  defp get_placeholder_for_field(field) do
    case field do
      "character_ids" -> "Character names or IDs (comma-separated)"
      "corporation_ids" -> "Corporation names or IDs (comma-separated)"
      "alliance_ids" -> "Alliance names or IDs (comma-separated)"
      "system_ids" -> "System names or IDs (comma-separated)"
      "ship_type_ids" -> "Ship type names or IDs (comma-separated)"
      _ -> "Enter values (comma-separated)"
    end
  end

  defp get_range_min(value) when is_tuple(value), do: elem(value, 0)
  defp get_range_min(_), do: ""

  defp get_range_max(value) when is_tuple(value), do: elem(value, 1)
  defp get_range_max(_), do: ""

  defp has_advanced_criteria?(criteria) do
    conditions = Map.get(criteria, :conditions, [])

    Enum.any?(conditions, fn condition ->
      condition.type in [:range, :temporal, :proximity, :nested]
    end)
  end

  defp format_killmail_for_engine(killmail) do
    %{
      "killmail_id" => killmail.killmail_id,
      "solar_system_id" => killmail.solar_system_id,
      "killmail_time" => DateTime.to_iso8601(killmail.killmail_time),
      "total_value" => killmail.zkb_total_value || 0,
      "victim" => %{
        "character_id" => killmail.victim_character_id,
        "corporation_id" => killmail.victim_corporation_id,
        "alliance_id" => killmail.victim_alliance_id,
        "ship_type_id" => killmail.victim_ship_type_id
      },
      # Simplified for preview
      "attackers" => [],
      "zkb" => %{
        "totalValue" => killmail.zkb_total_value || 0,
        "points" => killmail.zkb_points || 0
      }
    }
  end

  defp process_match_result(match_result, criteria, killmail) do
    case match_result do
      {:advanced, _result} ->
        create_killmail_result(killmail, "Advanced")

      {:fallback, _} ->
        process_legacy_match(criteria, killmail)

      {:no_match, _} ->
        nil
    end
  end

  defp create_killmail_result(killmail, filter_type) do
    %{
      killmail_id: killmail.killmail_id,
      victim_name: killmail.victim_character_name,
      victim_ship: killmail.victim_ship_name,
      isk_value: killmail.zkb_total_value,
      timestamp: killmail.killmail_time,
      filter_type: filter_type
    }
  end

  defp process_legacy_match(criteria, killmail) do
    case EveDmv.Contexts.Surveillance.Domain.MatchingEngine.test_criteria(criteria, killmail) do
      {:ok, result} ->
        if result.matches do
          create_killmail_result(killmail, "Legacy")
        else
          nil
        end
    end
  end
end
