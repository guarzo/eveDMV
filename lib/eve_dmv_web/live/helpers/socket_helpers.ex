defmodule EveDmvWeb.LiveHelpers.SocketHelpers do
  @moduledoc """
  Common socket assignment patterns and helpers for LiveView modules.

  Provides standardized functions for assigning values to socket,
  handling nil values, and updating nested assigns safely.
  """

  import Phoenix.Component

  @doc """
  Safely assigns multiple values to socket at once.

  ## Example

      socket
      |> assign_many(%{
        loading: false,
        data: result,
        error: nil
      })
  """
  def assign_many(socket, assigns) when is_map(assigns) do
    Enum.reduce(assigns, socket, fn {key, value}, acc ->
      assign(acc, key, value)
    end)
  end

  @doc """
  Conditionally assigns a value only if it's not nil.

  ## Example

      socket
      |> assign_if_not_nil(:user, maybe_user)
      |> assign_if_not_nil(:data, maybe_data)
  """
  def assign_if_not_nil(socket, _key, nil), do: socket
  def assign_if_not_nil(socket, key, value) do
    assign(socket, key, value)
  end

  @doc """
  Assigns a value with a default if nil.

  ## Example

      socket
      |> assign_with_default(:items, maybe_items, [])
      |> assign_with_default(:count, maybe_count, 0)
  """
  def assign_with_default(socket, key, nil, default) do
    assign(socket, key, default)
  end
  def assign_with_default(socket, key, value, _default) do
    assign(socket, key, value)
  end

  @doc """
  Updates a nested map assign safely.

  ## Example

      socket
      |> update_nested_assign([:filters, :status], "active")
      |> update_nested_assign([:settings, :theme], "dark")
  """
  def update_nested_assign(socket, path, value) when is_list(path) do
    current = get_nested_assign(socket, path) || %{}
    updated = put_in_path(current, path, value)

    # Update the top-level key
    [top_key | _] = path
    assign(socket, top_key, updated)
  end

  @doc """
  Gets a nested assign value safely.

  ## Example

      value = get_nested_assign(socket, [:filters, :status])
  """
  def get_nested_assign(socket, path) when is_list(path) do
    get_in(socket.assigns, path)
  end

  @doc """
  Merges new values into an existing map assign.

  ## Example

      socket
      |> merge_assign(:filters, %{status: "active", type: "all"})
  """
  def merge_assign(socket, key, new_values) when is_map(new_values) do
    current = Map.get(socket.assigns, key, %{})
    merged = Map.merge(current, new_values)
    assign(socket, key, merged)
  end

  @doc """
  Initializes multiple assigns with default values.

  ## Example

      socket
      |> initialize_assigns(%{
        loading: false,
        error: nil,
        data: [],
        filters: %{},
        page: 1
      })
  """
  def initialize_assigns(socket, defaults) when is_map(defaults) do
    Enum.reduce(defaults, socket, fn {key, default_value}, acc ->
      if Map.has_key?(acc.assigns, key) do
        acc
      else
        assign(acc, key, default_value)
      end
    end)
  end

  @doc """
  Resets multiple assigns to their default values.

  ## Example

      socket
      |> reset_assigns([:error, :loading], %{error: nil, loading: false})
  """
  def reset_assigns(socket, keys, defaults) when is_list(keys) and is_map(defaults) do
    Enum.reduce(keys, socket, fn key, acc ->
      default = Map.get(defaults, key)
      assign(acc, key, default)
    end)
  end

  @doc """
  Toggles a boolean assign.

  ## Example

      socket |> toggle_assign(:show_modal)
  """
  def toggle_assign(socket, key) do
    current = Map.get(socket.assigns, key, false)
    assign(socket, key, not current)
  end

  @doc """
  Increments a numeric assign.

  ## Example

      socket |> increment_assign(:counter, 1)
  """
  def increment_assign(socket, key, amount \\ 1) do
    current = Map.get(socket.assigns, key, 0)
    assign(socket, key, current + amount)
  end

  @doc """
  Appends an item to a list assign.

  ## Example

      socket |> append_to_assign(:messages, new_message)
  """
  def append_to_assign(socket, key, item) do
    current = Map.get(socket.assigns, key, [])
    assign(socket, key, current ++ [item])
  end

  @doc """
  Prepends an item to a list assign.

  ## Example

      socket |> prepend_to_assign(:notifications, new_notification)
  """
  def prepend_to_assign(socket, key, item) do
    current = Map.get(socket.assigns, key, [])
    assign(socket, key, [item | current])
  end

  @doc """
  Updates an item in a list assign by a predicate function.

  ## Example

      socket
      |> update_in_list_assign(:items,
        fn item -> item.id == item_id end,
        fn item -> %{item | status: "completed"} end
      )
  """
  def update_in_list_assign(socket, key, predicate, update_fn) do
    current = Map.get(socket.assigns, key, [])
    updated = Enum.map(current, fn item ->
      if predicate.(item), do: update_fn.(item), else: item
    end)
    assign(socket, key, updated)
  end

  @doc """
  Removes items from a list assign by a predicate.

  ## Example

      socket
      |> remove_from_list_assign(:notifications, fn n -> n.read end)
  """
  def remove_from_list_assign(socket, key, predicate) do
    current = Map.get(socket.assigns, key, [])
    filtered = Enum.reject(current, predicate)
    assign(socket, key, filtered)
  end

  # Private helpers

  defp put_in_path(data, [key], value) do
    Map.put(data, key, value)
  end

  defp put_in_path(data, [key | rest], value) do
    sub_data = Map.get(data, key, %{})
    Map.put(data, key, put_in_path(sub_data, rest, value))
  end
end
