defmodule EveDmvWeb.SurveillanceLive do
  @moduledoc """
  LiveView for managing surveillance profiles.

  Allows users to create, edit, and manage killmail surveillance profiles
  with real-time notifications when profiles match incoming killmails.
  """

  use EveDmvWeb, :live_view
  alias EveDmv.Surveillance.MatchingEngine

  alias EveDmvWeb.SurveillanceLive.{
    BatchOperations,
    DataLoader,
    ImportExport,
    NotificationManager,
    ProfileManager,
    ViewHelpers
  }

  # Load current user from session on mount
  on_mount({EveDmvWeb.AuthLive, :load_from_session})

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
      profiles = ProfileManager.load_user_profiles(user_id, current_user)
      recent_matches = DataLoader.load_recent_matches()
      engine_stats = DataLoader.get_engine_stats()
      notifications = NotificationManager.load_user_notifications(user_id)
      unread_count = NotificationManager.get_unread_count(user_id)

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
          "filter_tree" => DataLoader.sample_filter_tree()
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
    unread_count = NotificationManager.get_unread_count(socket.assigns.user_id)

    socket =
      socket
      |> assign(:notifications, updated_notifications)
      |> assign(:unread_count, unread_count)
      |> put_flash(:info, "📬 New notification: #{payload.notification.title}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:toggle_profile_selection, profile_id}, socket) do
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
  def handle_info({:toggle_profile, profile_id}, socket) do
    handle_event("toggle_profile", %{"profile_id" => profile_id}, socket)
  end

  @impl true
  def handle_info({:delete_profile, profile_id}, socket) do
    handle_event("delete_profile", %{"profile_id" => profile_id}, socket)
  end

  @impl true
  def handle_info({:show_create_modal}, socket) do
    handle_event("show_create_modal", %{}, socket)
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
    case ProfileManager.create_profile(
           profile_params,
           socket.assigns.user_id,
           socket.assigns.current_user
         ) do
      {:ok, profile, has_json_error} ->
        # Reload user profiles
        profiles =
          ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

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

      {:error, error_message} ->
        socket = put_flash(socket, :error, error_message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_profile", %{"profile_id" => profile_id}, socket) do
    case ProfileManager.toggle_profile(profile_id, socket.assigns.current_user) do
      {:ok, _updated_profile} ->
        # Reload user profiles
        profiles =
          ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

        socket =
          socket
          |> assign(:profiles, profiles)
          |> put_flash(:info, "Profile status updated")

        {:noreply, socket}

      {:error, error_message} ->
        socket = put_flash(socket, :error, error_message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_profile", %{"profile_id" => profile_id}, socket) do
    case ProfileManager.delete_profile(profile_id, socket.assigns.current_user) do
      :ok ->
        # Reload user profiles
        profiles =
          ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

        socket =
          socket
          |> assign(:profiles, profiles)
          |> put_flash(:info, "Profile deleted")

        {:noreply, socket}

      {:error, error_message} ->
        socket = put_flash(socket, :error, error_message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh_stats", _params, socket) do
    engine_stats = DataLoader.get_engine_stats()
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

    results = BatchOperations.batch_delete_profiles(selected_ids, socket.assigns.current_user)

    # Reload user profiles
    profiles =
      ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

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

    results = BatchOperations.batch_enable_profiles(selected_ids, socket.assigns.current_user)

    # Reload user profiles
    profiles =
      ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

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

    results = BatchOperations.batch_disable_profiles(selected_ids, socket.assigns.current_user)

    # Reload user profiles
    profiles =
      ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

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

    export_data = ImportExport.export_profiles_json(selected_ids, socket.assigns.current_user)
    download_event = ImportExport.prepare_download_event(export_data)

    socket =
      socket
      |> push_event("download", download_event)
      |> put_flash(:info, "Exported #{length(export_data["profiles"])} profiles")

    {:noreply, socket}
  end

  @impl true
  def handle_event("import_profiles", %{"profiles_json" => json_data}, socket) do
    case ImportExport.import_profiles_from_json(
           json_data,
           socket.assigns.user_id,
           socket.assigns.current_user
         ) do
      {:ok, count} ->
        # Reload matching engine profiles
        MatchingEngine.reload_profiles()

        # Reload user profiles
        profiles =
          ProfileManager.load_user_profiles(socket.assigns.user_id, socket.assigns.current_user)

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
    case NotificationManager.mark_notification_read(notification_id) do
      :ok ->
        # Reload notifications and update count
        notifications = NotificationManager.load_user_notifications(socket.assigns.user_id)
        unread_count = NotificationManager.get_unread_count(socket.assigns.user_id)

        socket =
          socket
          |> assign(:notifications, notifications)
          |> assign(:unread_count, unread_count)

        {:noreply, socket}

      {:error, error_message} ->
        socket = put_flash(socket, :error, error_message)
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("mark_all_read", _params, socket) do
    case NotificationManager.mark_all_notifications_read(
           socket.assigns.user_id,
           socket.assigns.current_user
         ) do
      {:ok, results} ->
        # Reload notifications and update count
        notifications = NotificationManager.load_user_notifications(socket.assigns.user_id)
        unread_count = NotificationManager.get_unread_count(socket.assigns.user_id)

        flash_message = NotificationManager.format_mark_all_message(results)

        socket =
          socket
          |> assign(:notifications, notifications)
          |> assign(:unread_count, unread_count)
          |> put_flash(:info, flash_message)

        {:noreply, socket}

      {:error, error_message} ->
        socket = put_flash(socket, :error, error_message)
        {:noreply, socket}
    end
  end

  # Template helper functions - delegate to ViewHelpers module

  defdelegate format_filter_tree(filter_tree), to: ViewHelpers
  defdelegate format_datetime(datetime), to: ViewHelpers
  defdelegate profile_status_badge(is_active), to: ViewHelpers
end
