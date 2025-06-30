defmodule EveDmvWeb.SurveillanceLive do
  @moduledoc """
  LiveView for managing surveillance profiles.

  Allows users to create, edit, and manage killmail surveillance profiles
  with real-time notifications when profiles match incoming killmails.
  """

  use EveDmvWeb, :live_view
  alias EveDmv.Api

  alias EveDmv.Surveillance.{
    MatchingEngine,
    Notification,
    NotificationService,
    Profile,
    ProfileMatch
  }

  # Load current user from session on mount
  on_mount {EveDmvWeb.AuthLive, :load_from_session}

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns[:current_user]

    if current_user do
      # Subscribe to surveillance matches and personal notifications
      if connected?(socket) do
        Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance")
        Phoenix.PubSub.subscribe(EveDmv.PubSub, "user:#{current_user.id}")
      end

      user_id = current_user.id

      # Load user's profiles and notifications
      profiles = load_user_profiles(user_id, current_user)
      recent_matches = load_recent_matches()
      engine_stats = get_engine_stats()
      notifications = load_user_notifications(user_id)
      unread_count = NotificationService.get_unread_count(user_id)

      socket =
        socket
        |> assign(:user_id, user_id)
        |> assign(:profiles, profiles)
        |> assign(:recent_matches, recent_matches)
        |> assign(:engine_stats, engine_stats)
        |> assign(:notifications, notifications)
        |> assign(:unread_count, unread_count)
        |> assign(:show_create_modal, false)
        |> assign(:show_notifications, false)
        |> assign(:show_batch_modal, false)
        |> assign(:selected_profiles, MapSet.new())
        |> assign(:batch_mode, false)
        |> assign(:new_profile_form, %{
          "name" => "",
          "description" => "",
          "filter_tree" => sample_filter_tree()
        })

      {:ok, socket}
    else
      # Redirect to login if not authenticated
      {:ok, redirect(socket, to: ~p"/login")}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "surveillance",
          event: "profile_match",
          payload: payload
        },
        socket
      ) do
    # New profile match - add to recent matches and show notification
    new_match = %{
      killmail: payload.killmail,
      profile_ids: payload.profile_ids,
      matched_at: DateTime.utc_now()
    }

    updated_matches = [new_match | socket.assigns.recent_matches] |> Enum.take(50)

    # Show temporary notification
    socket =
      socket
      |> assign(:recent_matches, updated_matches)
      |> put_flash(:info, "🎯 #{length(payload.profile_ids)} surveillance profiles matched!")

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "user:" <> _user_id,
          event: "new_notification",
          payload: payload
        },
        socket
      ) do
    # New persistent notification - update notifications list and count
    updated_notifications = [payload.notification | socket.assigns.notifications] |> Enum.take(50)
    unread_count = NotificationService.get_unread_count(socket.assigns.user_id)

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_count, unread_count)
      |> put_flash(:info, "📬 New notification: #{payload.notification.title}")

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    socket = assign(socket, :show_create_modal, true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    socket = assign(socket, :show_create_modal, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_profile", %{"profile" => profile_params}, socket) do
    # Parse JSON filter tree
    {filter_tree, has_json_error} =
      case Jason.decode(profile_params["filter_tree"] || "{}") do
        {:ok, parsed} ->
          {parsed, false}

        {:error, error} ->
          require Logger
          Logger.warning("Invalid JSON in filter tree: #{inspect(error)}")
          {sample_filter_tree(), true}
      end

    profile_data = %{
      name: profile_params["name"],
      description: profile_params["description"],
      user_id: socket.assigns.user_id,
      filter_tree: filter_tree,
      is_active: true
    }

    case Ash.create(Profile, profile_data, domain: Api, actor: socket.assigns.current_user) do
      {:ok, profile} ->
        require Logger
        Logger.info("Created surveillance profile: #{profile.name} (ID: #{profile.id})")

        # Reload matching engine profiles
        try do
          MatchingEngine.reload_profiles()
          Logger.info("Reloaded matching engine profiles")
        rescue
          error ->
            Logger.error("Failed to reload matching engine: #{inspect(error)}")
        end

        # Reload user profiles
        profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

        socket =
          socket
          |> assign(:profiles, profiles)
          |> assign(:show_create_modal, false)
          |> put_flash(:info, "Surveillance profile '#{profile.name}' created successfully!")
          |> then(fn socket ->
            if has_json_error do
              put_flash(
                socket,
                :warning,
                "Note: Invalid JSON in filter tree was replaced with default template."
              )
            else
              socket
            end
          end)

        {:noreply, socket}

      {:error, error} ->
        error_message = format_error_message(error)
        socket = put_flash(socket, :error, error_message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_profile", %{"profile_id" => profile_id}, socket) do
    case Ash.get(Profile, profile_id, domain: Api, actor: socket.assigns.current_user) do
      {:ok, profile} ->
        case Ash.update(profile,
               action: :toggle_active,
               domain: Api,
               actor: socket.assigns.current_user
             ) do
          {:ok, _updated_profile} ->
            # Reload matching engine profiles
            MatchingEngine.reload_profiles()

            # Reload user profiles
            profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

            socket =
              socket
              |> assign(:profiles, profiles)
              |> put_flash(:info, "Profile status updated")

            {:noreply, socket}

          {:error, error} ->
            socket = put_flash(socket, :error, "Failed to update profile: #{inspect(error)}")
            {:noreply, socket}
        end

      {:error, _} ->
        socket = put_flash(socket, :error, "Profile not found")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_profile", %{"profile_id" => profile_id}, socket) do
    case Ash.get(Profile, profile_id, domain: Api, actor: socket.assigns.current_user) do
      {:ok, profile} ->
        case Ash.destroy(profile, domain: Api, actor: socket.assigns.current_user) do
          :ok ->
            # Reload matching engine profiles
            MatchingEngine.reload_profiles()

            # Reload user profiles
            profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

            socket =
              socket
              |> assign(:profiles, profiles)
              |> put_flash(:info, "Profile deleted")

            {:noreply, socket}

          {:error, error} ->
            socket = put_flash(socket, :error, "Failed to delete profile: #{inspect(error)}")
            {:noreply, socket}
        end

      {:error, _} ->
        socket = put_flash(socket, :error, "Profile not found")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    engine_stats = get_engine_stats()
    socket = assign(socket, :engine_stats, engine_stats)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_batch_mode", _params, socket) do
    batch_mode = not socket.assigns.batch_mode

    socket =
      socket
      |> assign(:batch_mode, batch_mode)
      |> assign(:selected_profiles, MapSet.new())
      |> put_flash(:info, if(batch_mode, do: "Batch mode enabled", else: "Batch mode disabled"))

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_profile_selection", %{"profile_id" => profile_id}, socket) do
    selected = socket.assigns.selected_profiles

    updated_selected =
      if MapSet.member?(selected, profile_id) do
        MapSet.delete(selected, profile_id)
      else
        MapSet.put(selected, profile_id)
      end

    socket = assign(socket, :selected_profiles, updated_selected)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_all_profiles", _params, socket) do
    all_profile_ids =
      socket.assigns.profiles
      |> Enum.map(& &1.id)
      |> MapSet.new()

    socket = assign(socket, :selected_profiles, all_profile_ids)
    {:noreply, socket}
  end

  @impl true
  def handle_event("deselect_all_profiles", _params, socket) do
    socket = assign(socket, :selected_profiles, MapSet.new())
    {:noreply, socket}
  end

  @impl true
  def handle_event("show_batch_modal", _params, socket) do
    if MapSet.size(socket.assigns.selected_profiles) > 0 do
      socket = assign(socket, :show_batch_modal, true)
      {:noreply, socket}
    else
      socket = put_flash(socket, :warning, "Please select at least one profile")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("hide_batch_modal", _params, socket) do
    socket = assign(socket, :show_batch_modal, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("batch_delete", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_profiles)

    results = batch_delete_profiles(selected_ids, socket.assigns.current_user)

    # Reload matching engine profiles
    MatchingEngine.reload_profiles()

    # Reload user profiles
    profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:profiles, profiles)
      |> assign(:selected_profiles, MapSet.new())
      |> assign(:batch_mode, false)
      |> assign(:show_batch_modal, false)
      |> put_flash(:info, "Deleted #{results.success} profiles, #{results.failed} failed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("batch_enable", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_profiles)

    results = batch_update_profiles(selected_ids, true, socket.assigns.current_user)

    # Reload matching engine profiles
    MatchingEngine.reload_profiles()

    # Reload user profiles
    profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:profiles, profiles)
      |> assign(:selected_profiles, MapSet.new())
      |> assign(:batch_mode, false)
      |> assign(:show_batch_modal, false)
      |> put_flash(:info, "Enabled #{results.success} profiles, #{results.failed} failed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("batch_disable", _params, socket) do
    selected_ids = MapSet.to_list(socket.assigns.selected_profiles)

    results = batch_update_profiles(selected_ids, false, socket.assigns.current_user)

    # Reload matching engine profiles
    MatchingEngine.reload_profiles()

    # Reload user profiles
    profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

    socket =
      socket
      |> assign(:profiles, profiles)
      |> assign(:selected_profiles, MapSet.new())
      |> assign(:batch_mode, false)
      |> assign(:show_batch_modal, false)
      |> put_flash(:info, "Disabled #{results.success} profiles, #{results.failed} failed")

    {:noreply, socket}
  end

  @impl true
  def handle_event("export_profiles", _params, socket) do
    selected_ids =
      if MapSet.size(socket.assigns.selected_profiles) > 0 do
        MapSet.to_list(socket.assigns.selected_profiles)
      else
        Enum.map(socket.assigns.profiles, & &1.id)
      end

    export_data = export_profiles_json(selected_ids, socket.assigns.current_user)

    socket =
      socket
      |> push_event("download", %{
        filename: "surveillance_profiles_#{Date.utc_today()}.json",
        content: Jason.encode!(export_data, pretty: true),
        mimetype: "application/json"
      })
      |> put_flash(:info, "Exported #{length(export_data["profiles"])} profiles")

    {:noreply, socket}
  end

  @impl true
  def handle_event("import_profiles", %{"profiles_json" => json_data}, socket) do
    case import_profiles_from_json(json_data, socket.assigns.user_id, socket.assigns.current_user) do
      {:ok, count} ->
        # Reload matching engine profiles
        MatchingEngine.reload_profiles()

        # Reload user profiles
        profiles = load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

        socket =
          socket
          |> assign(:profiles, profiles)
          |> put_flash(:info, "Successfully imported #{count} profiles")

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Import failed: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_notifications", _params, socket) do
    socket = assign(socket, :show_notifications, true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_notifications", _params, socket) do
    socket = assign(socket, :show_notifications, false)
    {:noreply, socket}
  end

  @impl true
  def handle_event("mark_notification_read", %{"notification_id" => notification_id}, socket) do
    case NotificationService.mark_notification_read(notification_id) do
      :ok ->
        # Reload notifications and update count
        notifications = load_user_notifications(socket.assigns.user_id)
        unread_count = NotificationService.get_unread_count(socket.assigns.user_id)

        socket =
          socket
          |> assign(:notifications, notifications)
          |> assign(:unread_count, unread_count)

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to mark notification as read")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    # Get all unread notifications for the user
    case Ash.read(Notification,
           action: :unread_for_user,
           input: %{user_id: socket.assigns.user_id},
           domain: Api
         ) do
      {:ok, unread_notifications} ->
        # Bulk update them to read
        Enum.each(unread_notifications, fn notification ->
          Ash.update(notification,
            action: :mark_read,
            domain: Api,
            actor: socket.assigns.current_user
          )
        end)

        # Reload notifications and update count
        notifications = load_user_notifications(socket.assigns.user_id)
        unread_count = 0

        socket =
          socket
          |> assign(:notifications, notifications)
          |> assign(:unread_count, unread_count)
          |> put_flash(:info, "All notifications marked as read")

        {:noreply, socket}

      {:error, _} ->
        socket = put_flash(socket, :error, "Failed to mark all notifications as read")
        {:noreply, socket}
    end
  end

  # Private helper functions

  defp load_user_profiles(user_id, current_user) do
    case Ash.read(Profile,
           action: :user_profiles,
           input: %{user_id: user_id},
           domain: Api,
           actor: current_user
         ) do
      {:ok, profiles} -> profiles
      {:error, _} -> []
    end
  end

  defp load_recent_matches do
    case Ash.read(ProfileMatch, action: :recent_matches, input: %{hours: 24}, domain: Api) do
      {:ok, matches} -> Enum.take(matches, 20)
      {:error, _} -> []
    end
  end

  defp get_engine_stats do
    MatchingEngine.get_stats()
  rescue
    _ -> %{profiles_loaded: 0, matches_processed: 0}
  end

  defp load_user_notifications(user_id) do
    NotificationService.get_recent_notifications(user_id, 24)
  end

  defp sample_filter_tree do
    %{
      "condition" => "and",
      "rules" => [
        %{
          "field" => "total_value",
          "operator" => "gt",
          "value" => 100_000_000
        },
        %{
          "field" => "solar_system_id",
          "operator" => "in",
          # Jita, Amarr
          "value" => [30_000_142, 30_002_187]
        }
      ]
    }
  end

  # Template helper functions

  def format_filter_tree(filter_tree) do
    Jason.encode!(filter_tree, pretty: true)
  end

  def format_datetime(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
      _ -> "Unknown"
    end
  end

  def profile_status_badge(is_active) do
    if is_active do
      "🟢 Active"
    else
      "🔴 Inactive"
    end
  end

  # Helper function to format error messages and reduce nesting
  defp format_error_message(error) do
    case error do
      %Ash.Error.Invalid{errors: errors} ->
        errors
        |> Enum.map_join(", ", &format_validation_error/1)

      _ ->
        "Failed to create profile: #{inspect(error)}"
    end
  end

  defp format_validation_error(err) do
    case err do
      %{message: msg} -> msg
      %{field: field} -> "#{field} is invalid"
      _ -> inspect(err)
    end
  end

  # Batch operation helpers

  defp batch_delete_profiles(profile_ids, actor) do
    results = %{success: 0, failed: 0}

    Enum.reduce(profile_ids, results, fn profile_id, acc ->
      case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
        {:ok, profile} ->
          case Ash.destroy(profile, domain: Api, actor: actor) do
            :ok ->
              %{acc | success: acc.success + 1}

            {:error, _} ->
              %{acc | failed: acc.failed + 1}
          end

        {:error, _} ->
          %{acc | failed: acc.failed + 1}
      end
    end)
  end

  defp batch_update_profiles(profile_ids, is_active, actor) do
    results = %{success: 0, failed: 0}

    Enum.reduce(profile_ids, results, fn profile_id, acc ->
      case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
        {:ok, profile} ->
          case Ash.update(profile, %{is_active: is_active}, domain: Api, actor: actor) do
            {:ok, _} ->
              %{acc | success: acc.success + 1}

            {:error, _} ->
              %{acc | failed: acc.failed + 1}
          end

        {:error, _} ->
          %{acc | failed: acc.failed + 1}
      end
    end)
  end

  defp export_profiles_json(profile_ids, actor) do
    profiles =
      Enum.reduce(profile_ids, [], fn profile_id, acc ->
        case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
          {:ok, profile} ->
            exported = %{
              "name" => profile.name,
              "description" => profile.description,
              "filter_tree" => profile.filter_tree,
              "is_active" => profile.is_active,
              "notification_settings" => profile.notification_settings
            }

            [exported | acc]

          {:error, _} ->
            acc
        end
      end)
      |> Enum.reverse()

    %{
      "version" => "1.0",
      "exported_at" => DateTime.utc_now(),
      "profiles" => profiles
    }
  end

  defp import_profiles_from_json(json_data, user_id, actor) do
    case Jason.decode(json_data) do
      {:ok, %{"profiles" => profiles}} when is_list(profiles) ->
        imported_count =
          Enum.reduce(profiles, 0, fn profile_data, count ->
            profile_attrs = %{
              name: profile_data["name"] || "Imported Profile",
              description: profile_data["description"] || "",
              filter_tree: profile_data["filter_tree"] || sample_filter_tree(),
              is_active: profile_data["is_active"] || false,
              notification_settings: profile_data["notification_settings"] || %{},
              user_id: user_id
            }

            case Ash.create(Profile, profile_attrs, domain: Api, actor: actor) do
              {:ok, _} -> count + 1
              {:error, _} -> count
            end
          end)

        {:ok, imported_count}

      {:ok, _} ->
        {:error, "Invalid format: missing profiles array"}

      {:error, _} ->
        {:error, "Invalid JSON data"}
    end
  end
end
