defmodule EveDmvWeb.SurveillanceLive do
  @moduledoc """
  LiveView for managing surveillance profiles.

  Allows users to create, edit, and manage killmail surveillance profiles
  with real-time notifications when profiles match incoming killmails.
  """

  use EveDmvWeb, :live_view
  alias EveDmv.Api
  alias EveDmv.Surveillance.{MatchingEngine, Profile, ProfileMatch}

  @impl true
  def mount(_params, session, socket) do
    # Subscribe to surveillance matches
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, "surveillance")
    end

    # For now, use a dummy user ID since authentication isn't fully implemented
    user_id = session["user_id"] || "00000000-0000-0000-0000-000000000000"

    # Load user's profiles
    profiles = load_user_profiles(user_id)
    recent_matches = load_recent_matches()
    engine_stats = get_engine_stats()

    socket =
      socket
      |> assign(:user_id, user_id)
      |> assign(:profiles, profiles)
      |> assign(:recent_matches, recent_matches)
      |> assign(:engine_stats, engine_stats)
      |> assign(:show_create_modal, false)
      |> assign(:new_profile_form, %{
        "name" => "",
        "description" => "",
        "filter_tree" => sample_filter_tree()
      })

    {:ok, socket}
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

    case Ash.create(Profile, profile_data, domain: Api) do
      {:ok, profile} ->
        # Reload matching engine profiles
        MatchingEngine.reload_profiles()

        # Reload user profiles
        profiles = load_user_profiles(socket.assigns.user_id)

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
    case Ash.get(Profile, profile_id, domain: Api) do
      {:ok, profile} ->
        case Ash.update(profile, action: :toggle_active, domain: Api) do
          {:ok, _updated_profile} ->
            # Reload matching engine profiles
            MatchingEngine.reload_profiles()

            # Reload user profiles
            profiles = load_user_profiles(socket.assigns.user_id)

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
    case Ash.get(Profile, profile_id, domain: Api) do
      {:ok, profile} ->
        case Ash.destroy(profile, domain: Api) do
          :ok ->
            # Reload matching engine profiles
            MatchingEngine.reload_profiles()

            # Reload user profiles
            profiles = load_user_profiles(socket.assigns.user_id)

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

  # Private helper functions

  defp load_user_profiles(user_id) do
    case Ash.read(Profile, action: :user_profiles, input: %{user_id: user_id}, domain: Api) do
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
end
