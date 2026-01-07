defmodule EveDmvWeb.SurveillanceProfilesLive do
  @moduledoc """
  LiveView for managing surveillance profiles with simplified AshPhoenix.Form integration.

  Features:
  - Create/Edit/Delete surveillance profiles
  - Simplified filter builder using AshPhoenix.Form natively
  - Real-time preview against recent killmails
  - Entity autocomplete for characters, corps, alliances, systems, ships
  """

  use EveDmvWeb, :live_view

  on_mount({EveDmvWeb.AuthLive, :load_from_session_optional})

  alias EveDmv.Ash.Notifiers.PubSubNotifier
  alias EveDmv.Contexts.Surveillance.Api, as: SurveillanceApi
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Search.SearchSuggestionService
  alias EveDmv.Surveillance.Profile
  alias EveDmv.Surveillance.SimpleFilter

  require Logger

  @preview_killmail_limit 1000

  # LiveView lifecycle

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSubNotifier.subscribe_all(:profile)
    end

    socket =
      socket
      |> assign(:page_title, "Surveillance Profiles")
      |> assign(:profiles, [])
      |> assign(:editing, false)
      |> assign(:form, nil)
      |> assign(:profile_id, nil)
      |> assign(:filter_preview, %{matches: [], count: 0, testing: false})
      |> assign(:preview_killmail_limit, @preview_killmail_limit)
      |> assign(:autocomplete_suggestions, [])
      |> assign(:autocomplete_field, nil)
      |> load_profiles()

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _url, socket) do
    case params do
      %{"action" => "new"} ->
        form = create_profile_form(socket)
        {:noreply, assign(socket, editing: true, form: form, profile_id: nil)}

      %{"action" => "edit", "id" => id} ->
        case find_profile(socket.assigns.profiles, id) do
          nil ->
            {:noreply,
             socket
             |> put_flash(:error, "Profile not found")
             |> push_patch(to: ~p"/surveillance-profiles")}

          profile ->
            form = update_profile_form(profile, socket)
            {:noreply, assign(socket, editing: true, form: form, profile_id: id)}
        end

      _ ->
        {:noreply, assign(socket, editing: false, form: nil, profile_id: nil)}
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
  def handle_event("cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing, false)
     |> assign(:form, nil)
     |> push_patch(to: ~p"/surveillance-profiles")}
  end

  @impl Phoenix.LiveView
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    # Update preview when filters change
    socket = maybe_update_preview(socket, form)

    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("save", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: params) do
      {:ok, _profile} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile saved successfully")
         |> assign(:editing, false)
         |> assign(:form, nil)
         |> load_profiles()
         |> push_patch(to: ~p"/surveillance-profiles")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("delete_profile", %{"id" => id}, socket) do
    case safe_call(fn -> SurveillanceApi.delete_profile(id) end) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile deleted")
         |> load_profiles()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to delete profile")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_profile", %{"id" => id}, socket) do
    profile = find_profile(socket.assigns.profiles, id)
    enabled = !profile.is_active

    case safe_call(fn ->
           SurveillanceApi.update_profile(id, %{is_active: enabled})
         end) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile #{if enabled, do: "enabled", else: "disabled"}")
         |> load_profiles()}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update profile")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("add_filter", %{"type" => ""}, socket), do: {:noreply, socket}

  @impl Phoenix.LiveView
  def handle_event("add_filter", %{"type" => filter_type}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.add_form([:filters], params: default_filter_params(filter_type))
      |> to_form()

    socket = maybe_update_preview(socket, form)
    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_filter", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.remove_form([:filters, index])
      |> to_form()

    socket = maybe_update_preview(socket, form)
    {:noreply, assign(socket, :form, form)}
  end

  @impl Phoenix.LiveView
  def handle_event(
        "search_autocomplete",
        %{"value" => query, "filter_type" => filter_type},
        socket
      ) do
    if String.length(query) >= 2 do
      suggestions = search_entity_suggestions(filter_type, query)

      socket =
        socket
        |> assign(:autocomplete_suggestions, suggestions)
        |> assign(:autocomplete_field, filter_type)
        |> push_event("show_autocomplete", %{suggestions: suggestions})

      {:noreply, socket}
    else
      {:noreply, assign(socket, :autocomplete_suggestions, [])}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("add_entity_id", %{"index" => index_str, "id" => id_str}, socket) do
    index = String.to_integer(index_str)
    {id, _} = Integer.parse(id_str)

    # Get current form data
    form_source = socket.assigns.form.source
    current_params = AshPhoenix.Form.params(form_source)

    # Get current filters
    filters = Map.get(current_params, "filters", %{})
    filter_params = Map.get(filters, to_string(index), %{})
    current_ids = Map.get(filter_params, "entity_ids", []) || []

    # Add new ID if not already present
    new_ids =
      if id in current_ids do
        current_ids
      else
        current_ids ++ [id]
      end

    # Update the filter params
    updated_filter = Map.put(filter_params, "entity_ids", new_ids)
    updated_filters = Map.put(filters, to_string(index), updated_filter)
    updated_params = Map.put(current_params, "filters", updated_filters)

    # Validate with new params
    form =
      form_source
      |> AshPhoenix.Form.validate(updated_params)
      |> to_form()

    socket = maybe_update_preview(socket, form)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:autocomplete_suggestions, [])}
  end

  @impl Phoenix.LiveView
  def handle_event("remove_entity_id", %{"index" => index_str, "id" => id_str}, socket) do
    index = String.to_integer(index_str)
    {id, _} = Integer.parse(id_str)

    form_source = socket.assigns.form.source
    current_params = AshPhoenix.Form.params(form_source)

    filters = Map.get(current_params, "filters", %{})
    filter_params = Map.get(filters, to_string(index), %{})
    current_ids = Map.get(filter_params, "entity_ids", []) || []

    new_ids = Enum.reject(current_ids, &(&1 == id))

    updated_filter = Map.put(filter_params, "entity_ids", new_ids)
    updated_filters = Map.put(filters, to_string(index), updated_filter)
    updated_params = Map.put(current_params, "filters", updated_filters)

    form =
      form_source
      |> AshPhoenix.Form.validate(updated_params)
      |> to_form()

    socket = maybe_update_preview(socket, form)
    {:noreply, assign(socket, :form, form)}
  end

  # PubSub handlers

  @impl Phoenix.LiveView
  def handle_info({:resource_event, _action, :profile, _data}, socket) do
    {:noreply, load_profiles(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:resource_event, _action, "profile", _data}, socket) do
    {:noreply, load_profiles(socket)}
  end

  @impl Phoenix.LiveView
  def handle_info({:update_preview, filters}, socket) do
    preview_result = test_filters_against_killmails(filters)
    {:noreply, assign(socket, :filter_preview, preview_result)}
  end

  @impl Phoenix.LiveView
  def handle_info(_message, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp load_profiles(socket) do
    case safe_call(fn -> SurveillanceApi.list_profiles([]) end) do
      {:ok, profiles} ->
        assign(socket, :profiles, profiles)

      _ ->
        socket
        |> put_flash(:error, "Failed to load profiles")
        |> assign(:profiles, [])
    end
  end

  defp find_profile(profiles, id) do
    Enum.find(profiles, &(&1.id == id))
  end

  defp create_profile_form(socket) do
    user_id = get_current_user_id(socket)

    Profile
    |> AshPhoenix.Form.for_create(:create,
      as: "form",
      actor: %{id: user_id},
      forms: [
        filters: [
          type: :list,
          resource: SimpleFilter,
          create_action: :create,
          update_action: :update
        ]
      ],
      prepare_params: fn params, _context ->
        params
        |> Map.put_new("user_id", user_id)
        |> Map.put_new("filters", [])
      end
    )
    |> to_form()
  end

  defp update_profile_form(profile, socket) do
    user_id = get_current_user_id(socket)

    # Convert existing filters to form params
    filter_params = convert_filters_to_params(profile.filters || [])

    AshPhoenix.Form.for_update(profile, :update_profile,
      as: "form",
      actor: %{id: user_id},
      forms: [
        filters: [
          type: :list,
          resource: SimpleFilter,
          create_action: :create,
          update_action: :update,
          data: profile.filters || []
        ]
      ]
    )
    |> AshPhoenix.Form.validate(%{
      "name" => profile.name,
      "description" => profile.description || "",
      "is_active" => profile.is_active,
      "filters" => filter_params
    })
    |> to_form()
  end

  defp convert_filters_to_params(filters) do
    filters
    |> Enum.with_index()
    |> Enum.map(fn {filter, index} ->
      {to_string(index),
       %{
         "filter_type" => to_string(filter.filter_type),
         "entity_ids" => filter.entity_ids || [],
         "match_victim" => filter.match_victim,
         "match_attacker" => filter.match_attacker,
         "min_value" => filter.min_value,
         "max_value" => filter.max_value,
         "hour_start" => filter.hour_start,
         "hour_end" => filter.hour_end
       }}
    end)
    |> Enum.into(%{})
  end

  defp default_filter_params(filter_type) do
    base = %{"filter_type" => filter_type}

    case filter_type do
      type when type in ["character", "corporation", "alliance", "system", "ship"] ->
        Map.merge(base, %{
          "entity_ids" => [],
          "match_victim" => true,
          "match_attacker" => true
        })

      "isk_range" ->
        Map.merge(base, %{
          "min_value" => 10_000_000,
          "max_value" => nil
        })

      "active_hours" ->
        Map.merge(base, %{
          "hour_start" => 18,
          "hour_end" => 23
        })

      _ ->
        base
    end
  end

  defp maybe_update_preview(socket, form) do
    # Extract filters from form and trigger preview
    filters = extract_filters_from_form(form)

    if Enum.any?(filters) do
      send(self(), {:update_preview, filters})
      assign(socket, :filter_preview, %{matches: [], count: 0, testing: true})
    else
      assign(socket, :filter_preview, %{matches: [], count: 0, testing: false})
    end
  end

  defp extract_filters_from_form(form) do
    params = AshPhoenix.Form.params(form.source)
    filter_params = Map.get(params, "filters", %{})

    filter_params
    |> Enum.sort_by(fn {k, _v} -> String.to_integer(k) end)
    |> Enum.map(fn {_k, v} -> params_to_filter_struct(v) end)
    |> Enum.reject(&is_nil/1)
  end

  defp params_to_filter_struct(params) do
    filter_type = Map.get(params, "filter_type")

    if filter_type do
      %SimpleFilter{
        filter_type: String.to_existing_atom(filter_type),
        entity_ids: Map.get(params, "entity_ids", []),
        match_victim: Map.get(params, "match_victim", true),
        match_attacker: Map.get(params, "match_attacker", true),
        min_value: parse_int(Map.get(params, "min_value")),
        max_value: parse_int(Map.get(params, "max_value")),
        hour_start: parse_int(Map.get(params, "hour_start")),
        hour_end: parse_int(Map.get(params, "hour_end"))
      }
    else
      nil
    end
  end

  defp parse_int(nil), do: nil
  defp parse_int(""), do: nil
  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {int, _} -> int
      :error -> nil
    end
  end

  defp test_filters_against_killmails(filters) do
    killmails = get_recent_killmails_for_testing(@preview_killmail_limit)

    matches =
      killmails
      |> Enum.filter(fn killmail ->
        Enum.all?(filters, fn filter ->
          SimpleFilter.matches?(filter, killmail)
        end)
      end)
      |> Enum.take(10)
      |> Enum.map(&format_match_result/1)

    %{
      matches: matches,
      count: length(matches),
      testing: false,
      total_tested: length(killmails)
    }
  rescue
    error ->
      Logger.error("Preview testing failed: #{inspect(error)}")
      %{matches: [], count: 0, testing: false, error: "Testing failed"}
  end

  defp get_recent_killmails_for_testing(limit) do
    query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.limit(limit)
      |> Ash.Query.sort(killmail_time: :desc)

    case Ash.read(query) do
      {:ok, killmails} ->
        Enum.map(killmails, &format_killmail_for_testing/1)

      {:error, _reason} ->
        []
    end
  rescue
    _ -> []
  end

  defp format_killmail_for_testing(killmail) do
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
            ship_type_id: Map.get(attacker, "ship_type_id")
          }
        end),
      zkb: zkb
    }
  end

  defp format_match_result(killmail) do
    %{
      killmail_id: killmail.killmail_id,
      victim_name: killmail.victim_character_name,
      victim_ship: killmail.victim_ship_name,
      isk_value: killmail.zkb_total_value,
      timestamp: killmail.killmail_time
    }
  end

  defp search_entity_suggestions(filter_type, query) do
    case filter_type do
      "character" -> get_character_suggestions(query)
      "corporation" -> get_corporation_suggestions(query)
      "alliance" -> get_alliance_suggestions(query)
      "system" -> get_system_suggestions(query)
      "ship" -> get_ship_suggestions(query)
      _ -> []
    end
  end

  defp get_character_suggestions(query) do
    case SearchSuggestionService.get_character_suggestions(query, limit: 5) do
      {:ok, suggestions} -> Enum.map(suggestions, &%{id: &1.id, name: &1.name})
      {:error, _} -> []
    end
  end

  defp get_corporation_suggestions(query) do
    case SearchSuggestionService.get_corporation_suggestions(query, limit: 5) do
      {:ok, suggestions} -> Enum.map(suggestions, &%{id: &1.id, name: &1.name})
      {:error, _} -> []
    end
  end

  defp get_alliance_suggestions(query) do
    case SearchSuggestionService.get_alliance_suggestions(query, limit: 5) do
      {:ok, suggestions} -> Enum.map(suggestions, &%{id: &1.id, name: &1.name})
      {:error, _} -> []
    end
  end

  defp get_system_suggestions(query) do
    case SearchSuggestionService.get_system_suggestions(query, limit: 5) do
      {:ok, suggestions} -> Enum.map(suggestions, &%{id: &1.id, name: &1.name})
      {:error, _} -> []
    end
  end

  defp get_ship_suggestions(query) do
    case SearchSuggestionService.get_ship_suggestions(query, limit: 5) do
      {:ok, suggestions} -> Enum.map(suggestions, &%{id: &1.id, name: &1.name})
      {:error, _} -> []
    end
  end

  defp get_current_user_id(%{assigns: %{current_user: %{id: user_id}}}), do: user_id
  defp get_current_user_id(_), do: Ecto.UUID.generate()

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

  # Template helpers

  def filter_type_display(type), do: SimpleFilter.filter_type_display(type)

  def format_isk(value) when is_number(value) do
    value
    |> round()
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  def format_isk(_), do: "0"

  def format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")
  end

  def format_timestamp(%NaiveDateTime{} = ndt) do
    case DateTimeUtils.to_datetime(ndt) do
      nil -> "Unknown"
      dt -> format_timestamp(dt)
    end
  end

  def format_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> format_timestamp(dt)
      _ -> timestamp
    end
  end

  def format_timestamp(_), do: "Unknown"

  def filter_summary(filters) when is_list(filters) do
    count = length(filters)

    if count == 0 do
      "No filters"
    else
      types =
        filters
        |> Enum.map(& &1.filter_type)
        |> Enum.uniq()
        |> Enum.map_join(", ", &filter_type_display/1)

      "#{count} filter#{if count == 1, do: "", else: "s"}: #{types}"
    end
  end

  def filter_summary(_), do: "No filters"

  def is_entity_filter?(filter_type) when is_atom(filter_type) do
    filter_type in [:character, :corporation, :alliance, :system, :ship]
  end

  def is_entity_filter?(filter_type) when is_binary(filter_type) do
    filter_type in ["character", "corporation", "alliance", "system", "ship"]
  end
end
