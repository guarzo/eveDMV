defmodule EveDmvWeb.Admin.UsersLive do
  @moduledoc """
  Admin interface for managing users and their access levels.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Users.User

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "User Management")
     |> assign(:users, list_users())
     |> assign(:sort_by, :last_active)
     |> assign(:sort_order, :desc)
     |> assign(:filter, :all)}
  end

  @impl Phoenix.LiveView
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    sort_order =
      if socket.assigns.sort_by == field do
        if socket.assigns.sort_order == :asc, do: :desc, else: :asc
      else
        :asc
      end

    users = sort_users(socket.assigns.users, field, sort_order)

    {:noreply,
     socket
     |> assign(:sort_by, field)
     |> assign(:sort_order, sort_order)
     |> assign(:users, users)}
  end

  @impl Phoenix.LiveView
  def handle_event("filter", %{"status" => status}, socket) do
    filter = String.to_existing_atom(status)
    users = list_users() |> filter_users(filter)

    {:noreply,
     socket
     |> assign(:filter, filter)
     |> assign(:users, users)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_admin", %{"user-id" => user_id}, socket) do
    with {:ok, user} <- Ash.get(User, user_id, domain: EveDmv.Api),
         {:ok, _updated} <- Ash.update(user, %{is_admin: !user.is_admin}, domain: EveDmv.Api) do
      users = list_users() |> filter_users(socket.assigns.filter)

      {:noreply,
       socket
       |> assign(:users, users)
       |> put_flash(:info, "User admin status updated")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update user")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("revoke_access", %{"user-id" => user_id}, socket) do
    with {:ok, user} <- Ash.get(User, user_id, domain: EveDmv.Api),
         {:ok, _updated} <- Ash.update(user, %{active: false}, domain: EveDmv.Api) do
      users = list_users() |> filter_users(socket.assigns.filter)

      {:noreply,
       socket
       |> assign(:users, users)
       |> put_flash(:info, "User access revoked")}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to revoke access")}
    end
  end

  defp list_users do
    case Ash.read(User, domain: EveDmv.Api) do
      {:ok, users} -> users
      _ -> []
    end
  end

  defp filter_users(users, :all), do: users
  defp filter_users(users, :active), do: Enum.filter(users, & &1.active)
  defp filter_users(users, :admin), do: Enum.filter(users, & &1.is_admin)
  defp filter_users(users, :inactive), do: Enum.filter(users, &(not &1.active))

  defp sort_users(users, field, order) do
    Enum.sort_by(users, &Map.get(&1, field), order)
  end

  def format_last_active(nil), do: "Never"

  def format_last_active(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 3600 ->
        "#{div(seconds, 60)} minutes ago"

      seconds when seconds < 86_400 ->
        "#{div(seconds, 3600)} hours ago"

      seconds when seconds < 2_592_000 ->
        "#{div(seconds, 86_400)} days ago"

      _ ->
        "#{datetime.year}-#{String.pad_leading(to_string(datetime.month), 2, "0")}-#{String.pad_leading(to_string(datetime.day), 2, "0")}"
    end
  end
end
