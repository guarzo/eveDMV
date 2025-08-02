defmodule EveDmvWeb.LiveHelpers.MountHelpers do
  @moduledoc """
  Standard mount callback patterns and initialization helpers for LiveView modules.

  Provides consistent mount patterns for authenticated and public LiveViews,
  handling common initialization tasks and error scenarios.
  """
  """

  import Phoenix.LiveView
  import Phoenix.Component
  import EveDmvWeb.LiveHelpers.SocketHelpers

  @doc """
  Standard mount pattern for authenticated LiveViews.

  ## Example

      def mount(params, session, socket) do
        mount_authenticated(socket, fn socket, user ->
          socket
          |> assign(:current_user, user)
          |> assign(:page_title, "Dashboard")
          |> load_user_data()
        end)
      end
  """
  def mount_authenticated(socket, callback) do
    case socket.assigns[:current_user] do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "You must be logged in to access this page")
         |> redirect(to: "/auth/login")}

      user ->
        socket = callback.(socket, user)
        {:ok, socket}
    end
  rescue
    error ->
      require Logger
      Logger.error("Mount error: #{inspect(error)}")

      {:ok,
       socket
       |> put_flash(:error, "An error occurred while loading the page")
       |> assign(:error, error)
       |> assign(:loading, false)}
  end

  @doc """
  Standard mount pattern for public LiveViews.

  ## Example

      def mount(params, session, socket) do
        mount_public(socket, fn socket ->
          socket
          |> assign(:page_title, "Welcome")
          |> load_public_data()
        end)
      end
  """
  def mount_public(socket, callback) do
    socket = callback.(socket)
    {:ok, socket}
  rescue
    error ->
      require Logger
      Logger.error("Mount error: #{inspect(error)}")

      {:ok,
       socket
       |> put_flash(:error, "An error occurred while loading the page")
       |> assign(:error, error)
       |> assign(:loading, false)}
  end

  @doc """
  Initialize common assigns with defaults.

  ## Example

      socket |> initialize_common_assigns("Page Title")
  """
  def initialize_common_assigns(socket, page_title \\ "EVE DMV") do
    socket
    |> initialize_assigns(%{
      page_title: page_title,
      loading: false,
      error: nil,
      flash: %{},
      connected?: connected?(socket)
    })
  end

  @doc """
  Initialize PubSub subscriptions when connected.

  ## Example

      socket |> subscribe_when_connected(["user:123", "system:alerts"])
  """
  def subscribe_when_connected(socket, topics) when is_list(topics) do
    if connected?(socket) do
      Enum.each(topics, fn topic ->
        Phoenix.PubSub.subscribe(EveDmv.PubSub, topic)
      end)
    end

    socket
  end

  def subscribe_when_connected(socket, topic) when is_binary(topic) do
    subscribe_when_connected(socket, [topic])
  end

  @doc """
  Handle params in mount with validation.

  ## Example

      socket
      |> handle_mount_params(params, %{
        "id" => :integer,
        "filter" => :string
      })
  """
  def handle_mount_params(socket, params, validators) do
    validated_params =
      Enum.reduce(validators, %{}, fn {key, type}, acc ->
        case validate_param(params[key], type) do
          {:ok, value} -> Map.put(acc, key, value)
          :error -> acc
        end
      end)

    assign(socket, :params, validated_params)
  end

  @doc """
  Safe async data loading pattern.

  ## Example

      socket
      |> async_load_data(:user_stats, fn ->
        UserStats.calculate(user_id)
      end)
  """
  def async_load_data(socket, key, loader_fn) do
    loading_key = String.to_existing_atom("#{key}_loading")

    if connected?(socket) do
      socket
      |> assign(loading_key, true)
      |> assign(key, nil)
      |> start_async(key, fn -> loader_fn.() end)
    else
      # Don't load async data on static render
      socket
      |> assign(loading_key, false)
      |> assign(key, nil)
    end
  end

  @doc """
  Handle async results in handle_async callback.

  ## Example

      def handle_async(task_name, result, socket) do
        handle_async_result(socket, task_name, result)
      end
  """
  def handle_async_result(socket, task_name, {:ok, result}) do
    loading_key = String.to_existing_atom("#{task_name}_loading")

    {:noreply,
     socket
     |> assign(loading_key, false)
     |> assign(task_name, result)}
  end

  def handle_async_result(socket, task_name, {:exit, reason}) do
    require Logger
    Logger.error("Async task #{task_name} failed: #{inspect(reason)}")

    loading_key = String.to_existing_atom("#{task_name}_loading")
    error_key = String.to_existing_atom("#{task_name}_error")

    {:noreply,
     socket
     |> assign(loading_key, false)
     |> assign(error_key, reason)
     |> put_flash(:error, "Failed to load #{humanize(task_name)}")}
  end

  # Private helpers

  defp validate_param(nil, _type), do: :error
  defp validate_param(value, :string) when is_binary(value), do: {:ok, value}
  defp validate_param(value, :integer) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end
  defp validate_param(value, :integer) when is_integer(value), do: {:ok, value}
  defp validate_param(value, :atom) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    _ -> :error
  end
  defp validate_param(value, :atom) when is_atom(value), do: {:ok, value}
  defp validate_param(_, _), do: :error

  defp humanize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp humanize(string) when is_binary(string), do: string
end
