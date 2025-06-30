# Elixir Client Integration Guide for Wanderer SSE API

This guide shows how to integrate with Wanderer's Server-Sent Events (SSE) API from Elixir applications.

## Overview

Wanderer's SSE API provides real-time event streaming for map changes, character updates, and system events. This guide covers multiple approaches for consuming SSE events in Elixir applications.

## Authentication

All SSE connections require a valid map API key:

```elixir
# Get your API key from map settings in Wanderer
api_key = "your_map_api_key_here"
map_id = "your_map_id_or_slug"
```

## Method 1: Using Finch (Recommended)

This is the most robust approach using Elixir's modern HTTP client.

### Setup

Add Finch to your `mix.exs`:

```elixir
defp deps do
  [
    {:finch, "~> 0.18"},
    {:jason, "~> 1.4"}
  ]
end
```

### SSE Client Module

```elixir
defmodule WandererSSEClient do
  @moduledoc """
  Server-Sent Events client for Wanderer real-time events.
  """
  
  use GenServer
  require Logger
  
  defstruct [
    :map_id,
    :api_key,
    :event_filter,
    :include_state,
    :since,
    :callback_module,
    :finch_name,
    :request_ref,
    :buffer
  ]
  
  @base_url "https://wanderer.ltd"
  @reconnect_delay 5_000
  @keepalive_timeout 60_000
  
  ## Public API
  
  @doc """
  Starts an SSE client for a Wanderer map.
  
  ## Options
  
  - `:map_id` - Map ID or slug (required)
  - `:api_key` - Map API key (required) 
  - `:event_filter` - List of event types or "*" for all (optional)
  - `:include_state` - Include current state on connection (optional, default: false)
  - `:since` - ULID to receive events after (optional)
  - `:callback_module` - Module to handle events (required)
  - `:finch_name` - Finch process name (optional, default: WandererSSE.Finch)
  
  ## Example
  
      {:ok, pid} = WandererSSEClient.start_link(
        map_id: "my-map",
        api_key: "api_key_here",
        event_filter: ["character_location_changed", "add_system"],
        include_state: true,
        callback_module: MyApp.EventHandler
      )
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end
  
  ## GenServer Callbacks
  
  def init(opts) do
    # Validate required options
    with {:ok, map_id} <- fetch_required(opts, :map_id),
         {:ok, api_key} <- fetch_required(opts, :api_key),
         {:ok, callback_module} <- fetch_required(opts, :callback_module) do
      
      state = %__MODULE__{
        map_id: map_id,
        api_key: api_key,
        event_filter: opts[:event_filter],
        include_state: opts[:include_state] || false,
        since: opts[:since],
        callback_module: callback_module,
        finch_name: opts[:finch_name] || WandererSSE.Finch,
        buffer: ""
      }
      
      # Start connection immediately
      send(self(), :connect)
      
      {:ok, state}
    else
      {:error, reason} -> {:stop, reason}
    end
  end
  
  def handle_info(:connect, state) do
    Logger.info("Connecting to Wanderer SSE for map #{state.map_id}")
    
    case start_sse_stream(state) do
      {:ok, request_ref} ->
        {:noreply, %{state | request_ref: request_ref}}
      {:error, reason} ->
        Logger.error("Failed to connect to SSE: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, state}
    end
  end
  
  def handle_info(:reconnect, state) do
    Logger.info("Reconnecting to Wanderer SSE")
    send(self(), :connect)
    {:noreply, %{state | request_ref: nil}}
  end
  
  def handle_info({:finch_response, request_ref, response}, %{request_ref: request_ref} = state) do
    case response do
      {:status, status} when status in 200..299 ->
        Logger.info("SSE connection established")
        {:noreply, state}
        
      {:status, status} ->
        Logger.error("SSE connection failed with status #{status}")
        schedule_reconnect()
        {:noreply, %{state | request_ref: nil}}
        
      {:headers, _headers} ->
        {:noreply, state}
        
      {:data, data} ->
        new_state = process_sse_data(state, data)
        {:noreply, new_state}
        
      :done ->
        Logger.info("SSE connection closed")
        schedule_reconnect()
        {:noreply, %{state | request_ref: nil}}
        
      {:error, reason} ->
        Logger.error("SSE connection error: #{inspect(reason)}")
        schedule_reconnect()
        {:noreply, %{state | request_ref: nil}}
    end
  end
  
  def handle_info({:finch_response, _other_ref, _response}, state) do
    # Ignore responses from old requests
    {:noreply, state}
  end
  
  def handle_info(msg, state) do
    Logger.warning("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  ## Private Functions
  
  defp fetch_required(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when not is_nil(value) -> {:ok, value}
      _ -> {:error, "Missing required option: #{key}"}
    end
  end
  
  defp start_sse_stream(state) do
    url = build_sse_url(state)
    headers = [{"accept", "text/event-stream"}]
    
    request = Finch.build(:get, url, headers)
    
    Finch.stream(request, state.finch_name, self(), :all)
  end
  
  defp build_sse_url(state) do
    base = "#{@base_url}/api/maps/#{state.map_id}/events/stream"
    
    params = 
      []
      |> maybe_add_param("token", state.api_key)
      |> maybe_add_param("events", format_event_filter(state.event_filter))
      |> maybe_add_param("include_state", state.include_state && "true")
      |> maybe_add_param("since", state.since)
      |> Enum.filter(fn {_k, v} -> v end)
    
    if params == [] do
      "#{base}?token=#{state.api_key}"
    else
      query_string = URI.encode_query(params)
      "#{base}?#{query_string}"
    end
  end
  
  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, _key, false), do: params
  defp maybe_add_param(params, key, value), do: [{key, value} | params]
  
  defp format_event_filter(nil), do: nil
  defp format_event_filter(events) when is_list(events), do: Enum.join(events, ",")
  defp format_event_filter(events), do: events
  
  defp process_sse_data(state, data) do
    # Append new data to buffer
    buffer = state.buffer <> data
    
    # Split by double newlines to separate events
    {events, remaining} = extract_events(buffer)
    
    # Process each complete event
    Enum.each(events, fn event ->
      process_sse_event(state, event)
    end)
    
    %{state | buffer: remaining}
  end
  
  defp extract_events(buffer) do
    # Split by double newline (event separator)
    parts = String.split(buffer, "\n\n")
    
    case parts do
      [incomplete] ->
        # No complete events yet
        {[], incomplete}
      [_|_] ->
        # Last part might be incomplete
        {complete_events, [remaining]} = Enum.split(parts, -1)
        {complete_events, remaining}
    end
  end
  
  defp process_sse_event(state, event_text) do
    case parse_sse_event(event_text) do
      {:ok, event} ->
        try do
          state.callback_module.handle_wanderer_event(event)
        rescue
          error ->
            Logger.error("Error in event callback: #{inspect(error)}")
        end
      {:error, reason} ->
        Logger.warning("Failed to parse SSE event: #{reason}")
    end
  end
  
  defp parse_sse_event(event_text) do
    lines = String.split(event_text, "\n")
    
    # Parse SSE format: "field: value"
    event_data = 
      Enum.reduce(lines, %{}, fn line, acc ->
        case String.split(line, ": ", parts: 2) do
          [field, value] -> Map.put(acc, field, value)
          _ -> acc
        end
      end)
    
    case Map.fetch(event_data, "data") do
      {:ok, json_data} ->
        case Jason.decode(json_data) do
          {:ok, decoded} -> {:ok, decoded}
          {:error, _} -> {:error, "Invalid JSON in event data"}
        end
      :error ->
        {:error, "No data field in SSE event"}
    end
  end
  
  defp schedule_reconnect do
    Process.send_after(self(), :reconnect, @reconnect_delay)
  end
end
```

### Event Handler Behaviour

```elixir
defmodule WandererSSEClient.EventHandler do
  @moduledoc """
  Behaviour for handling Wanderer SSE events.
  """
  
  @callback handle_wanderer_event(event :: map()) :: any()
end
```

### Example Event Handler

```elixir
defmodule MyApp.WandererEventHandler do
  @behaviour WandererSSEClient.EventHandler
  
  require Logger
  
  @impl true
  def handle_wanderer_event(event) do
    case event["type"] do
      "add_system" ->
        handle_system_added(event)
      "character_location_changed" ->
        handle_character_moved(event)
      "character_ship_changed" ->
        handle_ship_changed(event)
      "character_online_status_changed" ->
        handle_online_status_changed(event)
      "character_ready_status_changed" ->
        handle_ready_status_changed(event)
      "map_kill" ->
        handle_kill_event(event)
      _other ->
        Logger.debug("Received unknown event type: #{event["type"]}")
    end
  end
  
  defp handle_system_added(event) do
    %{
      "payload" => %{
        "solar_system_id" => system_id,
        "name" => name
      },
      "initial_state" => initial?
    } = event
    
    if initial? do
      Logger.info("Initial system: #{name} (#{system_id})")
    else
      Logger.info("New system added: #{name} (#{system_id})")
      # Send notification, update UI, etc.
    end
  end
  
  defp handle_character_moved(event) do
    %{
      "payload" => %{
        "character_name" => name,
        "current_location" => %{"solar_system_name" => system_name}
      }
    } = event
    
    Logger.info("#{name} moved to #{system_name}")
    # Update character tracking, send alerts, etc.
  end
  
  defp handle_ship_changed(event) do
    %{
      "payload" => %{
        "character_name" => name,
        "current_ship" => %{"ship" => ship_name}
      }
    } = event
    
    Logger.info("#{name} switched to #{ship_name}")
  end
  
  defp handle_online_status_changed(event) do
    %{
      "payload" => %{
        "character_name" => name,
        "current_online" => online?
      }
    } = event
    
    status = if online?, do: "online", else: "offline"
    Logger.info("#{name} went #{status}")
  end
  
  defp handle_ready_status_changed(event) do
    %{
      "payload" => %{
        "character_name" => name,
        "ready" => ready?
      }
    } = event
    
    status = if ready?, do: "ready", else: "not ready"
    Logger.info("#{name} is now #{status}")
  end
  
  defp handle_kill_event(event) do
    %{
      "payload" => %{
        "victim" => %{"name" => victim_name, "ship" => ship},
        "system_name" => system
      }
    } = event
    
    Logger.warn("KILL: #{victim_name} (#{ship}) destroyed in #{system}")
    # Send urgent notifications, update kill board, etc.
  end
end
```

### Application Integration

```elixir
defmodule MyApp.Application do
  use Application
  
  def start(_type, _args) do
    children = [
      # Start Finch for HTTP requests
      {Finch, name: WandererSSE.Finch},
      
      # Start your Wanderer SSE client
      {WandererSSEClient, 
       map_id: Application.get_env(:my_app, :wanderer_map_id),
       api_key: Application.get_env(:my_app, :wanderer_api_key),
       event_filter: ["character_location_changed", "add_system", "map_kill"],
       include_state: true,
       callback_module: MyApp.WandererEventHandler,
       finch_name: WandererSSE.Finch}
    ]
    
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Method 2: Using HTTPoison with Streaming

For applications already using HTTPoison:

```elixir
defmodule WandererSSEStream do
  use GenServer
  require Logger
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    map_id = Keyword.fetch!(opts, :map_id)
    api_key = Keyword.fetch!(opts, :api_key)
    callback = Keyword.fetch!(opts, :callback)
    
    url = "https://wanderer.ltd/api/maps/#{map_id}/events/stream?token=#{api_key}&include_state=true"
    
    # Start streaming request
    Task.start_link(fn -> stream_events(url, callback) end)
    
    {:ok, %{}}
  end
  
  defp stream_events(url, callback) do
    HTTPoison.get!(url, [{"Accept", "text/event-stream"}], stream_to: self(), timeout: :infinity)
    
    receive_events("", callback)
  end
  
  defp receive_events(buffer, callback) do
    receive do
      %HTTPoison.AsyncStatus{code: 200} ->
        Logger.info("Connected to Wanderer SSE")
        receive_events(buffer, callback)
        
      %HTTPoison.AsyncHeaders{} ->
        receive_events(buffer, callback)
        
      %HTTPoison.AsyncChunk{chunk: chunk} ->
        new_buffer = buffer <> chunk
        {events, remaining} = extract_complete_events(new_buffer)
        
        Enum.each(events, fn event ->
          process_event(event, callback)
        end)
        
        receive_events(remaining, callback)
        
      %HTTPoison.AsyncEnd{} ->
        Logger.info("SSE stream ended")
        # Reconnect logic here
        
    after
      60_000 ->
        Logger.info("SSE keepalive timeout")
        receive_events(buffer, callback)
    end
  end
  
  defp extract_complete_events(buffer) do
    parts = String.split(buffer, "\n\n")
    case parts do
      [incomplete] -> {[], incomplete}
      [_|_] -> 
        {events, [remaining]} = Enum.split(parts, -1)
        {events, remaining}
    end
  end
  
  defp process_event(event_text, callback) do
    case parse_event_data(event_text) do
      {:ok, event} -> callback.(event)
      {:error, _} -> :ok
    end
  end
  
  defp parse_event_data(event_text) do
    lines = String.split(event_text, "\n")
    
    data_line = Enum.find(lines, fn line ->
      String.starts_with?(line, "data: ")
    end)
    
    case data_line do
      "data: " <> json_data ->
        Jason.decode(json_data)
      _ ->
        {:error, :no_data}
    end
  end
end
```

## Method 3: Simple Req-based Client

For quick prototyping:

```elixir
defmodule SimpleWandererSSE do
  require Logger
  
  def stream_events(map_id, api_key, callback) do
    url = "https://wanderer.ltd/api/maps/#{map_id}/events/stream"
    
    Req.get!(url,
      params: [token: api_key, include_state: "true"],
      headers: [accept: "text/event-stream"],
      into: fn
        {:data, data}, acc ->
          process_chunk(data, acc, callback)
        _, acc ->
          acc
      end
    )
  end
  
  defp process_chunk(chunk, buffer, callback) do
    new_buffer = buffer <> chunk
    
    case String.split(new_buffer, "\n\n") do
      [incomplete] ->
        incomplete
      parts ->
        {events, [remaining]} = Enum.split(parts, -1)
        
        Enum.each(events, fn event ->
          case parse_sse_event(event) do
            {:ok, data} -> callback.(data)
            _ -> :ok
          end
        end)
        
        remaining
    end
  end
  
  defp parse_sse_event(event_text) do
    case Regex.run(~r/^data: (.+)$/m, event_text) do
      [_, json_data] -> Jason.decode(json_data)
      _ -> {:error, :no_data}
    end
  end
end

# Usage
SimpleWandererSSE.stream_events("my-map", "api_key", fn event ->
  IO.puts("Received: #{event["type"]}")
end)
```

## Configuration

### Environment Variables

```elixir
# config/runtime.exs
config :my_app,
  wanderer_api_key: System.get_env("WANDERER_API_KEY"),
  wanderer_map_id: System.get_env("WANDERER_MAP_ID")
```

### Production Considerations

```elixir
defmodule MyApp.WandererSSE.Supervisor do
  use Supervisor
  
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end
  
  def init(_init_arg) do
    children = [
      # HTTP client pool
      {Finch, 
       name: WandererSSE.Finch,
       pools: %{
         "https://wanderer.ltd" => [
           size: 5,
           conn_opts: [
             transport_opts: [
               timeout: 30_000
             ]
           ]
         ]
       }},
      
      # Multiple SSE clients for different maps
      {WandererSSEClient, build_client_opts("map-1")},
      {WandererSSEClient, build_client_opts("map-2")},
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
  
  defp build_client_opts(map_id) do
    [
      map_id: map_id,
      api_key: get_api_key_for_map(map_id),
      event_filter: ["character_location_changed", "add_system"],
      include_state: true,
      callback_module: MyApp.WandererEventHandler,
      finch_name: WandererSSE.Finch
    ]
  end
  
  defp get_api_key_for_map(map_id) do
    # Get from config, environment, or secret management
    Application.get_env(:my_app, :api_keys)[map_id]
  end
end
```

## Advanced Usage

### Event Filtering and Processing

```elixir
defmodule WandererEventProcessor do
  @moduledoc """
  Advanced event processing with filtering and routing.
  """
  
  def handle_wanderer_event(event) do
    event
    |> filter_event()
    |> route_event()
  end
  
  defp filter_event(event) do
    # Skip initial state events if not needed
    case event do
      %{"initial_state" => true} = event ->
        if process_initial_state?(), do: event, else: nil
      event ->
        event
    end
  end
  
  defp route_event(nil), do: :ok
  defp route_event(event) do
    case event["type"] do
      "character_" <> _ -> 
        CharacterEventHandler.handle(event)
      "add_system" -> 
        SystemEventHandler.handle(event)
      "map_kill" -> 
        KillEventHandler.handle(event)
      _ -> 
        :ok
    end
  end
  
  defp process_initial_state? do
    # Check if we need initial state (e.g., after restart)
    not Application.get_env(:my_app, :initial_state_loaded, false)
  end
end
```

### Metrics and Monitoring

```elixir
defmodule WandererSSE.Telemetry do
  def handle_wanderer_event(event) do
    # Emit telemetry events
    :telemetry.execute(
      [:wanderer_sse, :event_received],
      %{count: 1},
      %{event_type: event["type"], map_id: event["map_id"]}
    )
    
    # Process the event
    MyApp.WandererEventHandler.handle_wanderer_event(event)
  end
end

# In your telemetry setup
:telemetry.attach_many(
  "wanderer-sse-metrics",
  [
    [:wanderer_sse, :event_received]
  ],
  &handle_telemetry_event/4,
  nil
)

defp handle_telemetry_event([:wanderer_sse, :event_received], measurements, metadata, _config) do
  # Send to your metrics system
  MyApp.Metrics.increment("wanderer.events.received", 
    tags: [event_type: metadata.event_type, map_id: metadata.map_id])
end
```

## Testing

### Testing Event Handlers

```elixir
defmodule MyApp.WandererEventHandlerTest do
  use ExUnit.Case
  
  test "handles character location change" do
    event = %{
      "type" => "character_location_changed",
      "map_id" => "test-map",
      "payload" => %{
        "character_name" => "Test Pilot",
        "current_location" => %{
          "solar_system_name" => "Jita"
        }
      }
    }
    
    # Test your handler
    assert :ok = MyApp.WandererEventHandler.handle_wanderer_event(event)
  end
end
```

### Mocking SSE for Tests

```elixir
defmodule MockWandererSSE do
  def simulate_event(callback, event) do
    callback.(event)
  end
  
  def simulate_character_move(callback, character_name, system_name) do
    event = %{
      "type" => "character_location_changed",
      "payload" => %{
        "character_name" => character_name,
        "current_location" => %{"solar_system_name" => system_name}
      }
    }
    
    simulate_event(callback, event)
  end
end
```

## Error Handling and Resilience

```elixir
defmodule ResilientWandererSSE do
  use GenServer
  
  @max_retries 5
  @base_backoff 1_000
  
  defstruct [
    :opts,
    :retry_count,
    :last_event_id
  ]
  
  def init(opts) do
    state = %__MODULE__{
      opts: opts,
      retry_count: 0,
      last_event_id: nil
    }
    
    send(self(), :connect)
    {:ok, state}
  end
  
  def handle_info(:connect, state) do
    case connect_with_backoff(state) do
      {:ok, _ref} ->
        {:noreply, %{state | retry_count: 0}}
      {:error, _reason} when state.retry_count < @max_retries ->
        backoff = calculate_backoff(state.retry_count)
        Process.send_after(self(), :connect, backoff)
        {:noreply, %{state | retry_count: state.retry_count + 1}}
      {:error, reason} ->
        Logger.error("Failed to connect after #{@max_retries} retries: #{inspect(reason)}")
        {:stop, :connection_failed, state}
    end
  end
  
  defp connect_with_backoff(state) do
    opts = maybe_add_since_param(state.opts, state.last_event_id)
    WandererSSEClient.connect(opts)
  end
  
  defp calculate_backoff(retry_count) do
    @base_backoff * :math.pow(2, retry_count) |> round()
  end
  
  defp maybe_add_since_param(opts, nil), do: opts
  defp maybe_add_since_param(opts, last_id) do
    Keyword.put(opts, :since, last_id)
  end
end
```

This comprehensive guide provides multiple approaches for integrating with Wanderer's SSE API from Elixir applications, from simple one-off scripts to production-ready, resilient streaming clients.