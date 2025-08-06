# Web Layer Best Practices for EVE DMV

This guide documents best practices and patterns for the web layer (LiveView, Controllers, Components) to prevent Dialyzer errors and maintain code quality.

## Table of Contents
1. [LiveView Pattern Matching](#liveview-pattern-matching)
2. [Socket Assignment Patterns](#socket-assignment-patterns)
3. [Mount Callback Patterns](#mount-callback-patterns)
4. [Error Handling](#error-handling)
5. [Component Best Practices](#component-best-practices)
6. [Controller Patterns](#controller-patterns)

## LiveView Pattern Matching

### Common Issues and Solutions

#### 1. API Return Value Mismatches

**Problem**: Expecting error tuples from functions that only return success tuples.

```elixir
# BAD - Function spec says it only returns {:ok, map()}
case SomeApi.get_data(id) do
  {:ok, data} -> data
  {:error, _} -> nil  # This will never match!
end

# GOOD - Check the function's @spec first
{:ok, data} = SomeApi.get_data(id)  # If spec guarantees {:ok, _}
data
```

#### 2. Exhaustive Pattern Matching

**Problem**: Unreachable clauses in case/cond expressions.

```elixir
# BAD - :error case is unreachable
case Integer.parse(string) do
  {num, ""} -> {:ok, num}
  {num, rest} -> {:error, :partial_parse}
  :error -> {:error, :invalid}  # Unreachable!
end

# GOOD - Correct pattern for Integer.parse
case Integer.parse(string) do
  {num, ""} -> {:ok, num}
  {_num, _rest} -> {:error, :partial_parse}
  :error -> {:error, :invalid}
end
```

### Using the Pattern Template

Import the LiveView pattern template for consistent error handling:

```elixir
import EveDmvWeb.LiveHelpers.LiveViewPatternTemplate

def handle_event("action", params, socket) do
  safe_api_call(socket, 
    fn -> MyApi.perform_action(params) end,
    fn socket, result -> 
      assign(socket, :result, result)
    end
  )
end
```

## Socket Assignment Patterns

### Use Socket Helpers

Import standardized socket helpers for consistent patterns:

```elixir
import EveDmvWeb.LiveHelpers.SocketHelpers

# Assign multiple values at once
socket
|> assign_many(%{
  loading: false,
  data: result,
  error: nil
})

# Conditional assignment
socket
|> assign_if_not_nil(:user, maybe_user)
|> assign_with_default(:items, maybe_items, [])

# Safe nested updates
socket
|> update_nested_assign([:filters, :status], "active")
```

### Common Socket Patterns

#### 1. Loading States

```elixir
defp load_data(socket) do
  socket
  |> assign(:loading, true)
  |> assign(:error, nil)
end

defp handle_data_loaded(socket, {:ok, data}) do
  socket
  |> assign(:loading, false)
  |> assign(:data, data)
end

defp handle_data_loaded(socket, {:error, reason}) do
  socket
  |> assign(:loading, false)
  |> assign(:error, reason)
  |> put_flash(:error, "Failed to load data")
end
```

#### 2. Toggle States

```elixir
def handle_event("toggle_modal", _, socket) do
  {:noreply, toggle_assign(socket, :show_modal)}
end
```

## Mount Callback Patterns

### Use Mount Helpers

Import standardized mount helpers:

```elixir
import EveDmvWeb.LiveHelpers.MountHelpers

# For authenticated LiveViews
def mount(params, session, socket) do
  mount_authenticated(socket, fn socket, user ->
    socket
    |> assign(:current_user, user)
    |> initialize_common_assigns("Page Title")
    |> subscribe_when_connected("user:#{user.id}")
    |> load_user_data()
  end)
end

# For public LiveViews
def mount(params, session, socket) do
  mount_public(socket, fn socket ->
    socket
    |> initialize_common_assigns("Welcome")
    |> load_public_data()
  end)
end
```

### Async Data Loading

```elixir
def mount(params, session, socket) do
  socket =
    socket
    |> initialize_common_assigns()
    |> async_load_data(:stats, fn -> calculate_stats() end)
  
  {:ok, socket}
end

def handle_async(:stats, result, socket) do
  handle_async_result(socket, :stats, result)
end
```

## Error Handling

### Comprehensive Error Handling

Always handle all possible error cases:

```elixir
case operation() do
  {:ok, result} ->
    handle_success(socket, result)
    
  {:error, :not_found} ->
    socket
    |> put_flash(:error, "Resource not found")
    |> redirect(to: "/")
    
  {:error, :unauthorized} ->
    socket
    |> put_flash(:error, "You don't have permission")
    |> redirect(to: "/")
    
  {:error, reason} ->
    socket
    |> put_flash(:error, format_error(reason))
    |> assign(:error, reason)
end
```

### API Error Handling

Use the centralized error handler:

```elixir
import EveDmvWeb.Components.ApiErrorHandler

case api_call() do
  {:ok, result} -> 
    {:ok, result}
    
  {:error, reason} -> 
    handle_api_error(socket, reason, "Failed to load data")
end
```

## Component Best Practices

### Function Component Patterns

```elixir
defmodule MyAppWeb.Components.Card do
  use Phoenix.Component
  
  attr :title, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true
  
  def card(assigns) do
    ~H"""
    <div class={"card #{@class}"}>
      <h3><%= @title %></h3>
      <div class="card-body">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end
end
```

### Component Error Boundaries

```elixir
def safe_component(assigns) do
  try do
    unsafe_component(assigns)
  rescue
    error ->
      ~H"""
      <div class="error-boundary">
        <p>Component error: Unable to render</p>
      </div>
      """
  end
end
```

## Controller Patterns

### Action Error Handling

```elixir
def show(conn, %{"id" => id}) do
  case Context.get_resource(id) do
    {:ok, resource} ->
      render(conn, :show, resource: resource)
      
    {:error, :not_found} ->
      conn
      |> put_status(:not_found)
      |> put_view(html: ErrorHTML)
      |> render(:"404")
      
    {:error, _reason} ->
      conn
      |> put_status(:internal_server_error)
      |> put_view(html: ErrorHTML)
      |> render(:"500")
  end
end
```

### API Controller Patterns

```elixir
def create(conn, params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, resource} <- Context.create_resource(validated) do
    conn
    |> put_status(:created)
    |> json(%{data: resource})
  else
    {:error, :validation, errors} ->
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{errors: errors})
      
    {:error, reason} ->
      conn
      |> put_status(:internal_server_error)
      |> json(%{error: %{message: "Internal error"}})
  end
end
```

## Dialyzer-Specific Tips

### 1. Check Function Specs

Always verify the @spec of functions you're calling:

```elixir
# If the spec is:
@spec get_data(integer()) :: {:ok, map()}

# Then don't pattern match on {:error, _}
{:ok, data} = Module.get_data(id)
```

### 2. Avoid Overlapping Patterns

```elixir
# BAD - Overlapping patterns
case value do
  %{type: "user"} -> handle_user(value)
  %{type: _} -> handle_other(value)
  %{} -> handle_map(value)  # Unreachable!
end

# GOOD - Non-overlapping patterns
case value do
  %{type: "user"} -> handle_user(value)
  %{type: other} -> handle_other(value, other)
end
```

### 3. Handle All Cases

```elixir
# BAD - Incomplete pattern matching
case Enum.find(list, predicate) do
  %{id: id} -> id
end

# GOOD - Handle nil case
case Enum.find(list, predicate) do
  %{id: id} -> id
  nil -> nil
end
```

## Summary

By following these patterns and using the provided helper modules, you can:

1. Avoid common Dialyzer pattern matching errors
2. Write more maintainable LiveView code
3. Handle errors consistently across the application
4. Reduce boilerplate with standardized helpers

Remember to always:
- Check function specs before pattern matching
- Handle all possible return values
- Use helper modules for common patterns
- Test error paths as thoroughly as success paths