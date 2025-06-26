# Performance Optimization Notes

## 1. Kill Feed Pagination & Live Scrolling

### Page Size Limit
Decide on a sensible "window" of recent events, e.g. 100 kills. Anything older is quietly dropped from the UI.

### Temporary Assigns
Use LiveView's `temporary_assigns` on the kill list assign:

```elixir
def mount(_params, _session, socket) do
  socket =
    socket
    |> assign(:kills, [])
    |> temporary_assign(:kills, [])
  {:ok, socket}
end
```

Each time you push a new kill with `push_event` or `push_patch`, you prepend to `:kills` and truncate to 100 items. Because `:kills` is temporary, LiveView automatically prunes old entries after rendering, keeping the process state small.

### "Load More" Pagination
If users want deeper history, provide a "Load More" button under the feed that issues a regular HTTP request to `/api/kill_feed?before_id=XYZ&limit=50`, appending to the list outside of the real-time assign.

## 2. Preventing Memory Leaks

### Temporary Assigns Everywhere
Only store in the socket assigns what you render. Any large lists (kills, charts data) should be declared as `temporary_assigns`.

### PubSub Subscriptions on Mount/Unmount
In your LiveView's `mount/3`, subscribe to `"kill_feed"`, and in `terminate/2` (or via `on_disconnect`), ensure you unsubscribe if you've manually tracked subscriptions. Phoenix.LiveView handles this automatically, but if you spawn Processes for streaming or presence, link them to the socket or use `:telemetry.detach` on detach.

### Avoid Growing State
Don't accumulate logs, error lists, or old filter selections in the socket; instead, store long-lived data in ETS or the database and fetch on demand.

## 3. WebSocket Message Throttling

Even with a partitioned pipeline, kills can spike in bursts. We need to ensure the client – and the network – aren't overwhelmed.

### Client-Side Debounce
In your LiveView template, wrap the feed in a container with a `phx-update="stream"` and use `phx-debounce` on any input. For the feed itself, you can batch updates every 100 ms:

```elixir
def handle_info({:new_kill, kill}, socket) do
  Process.send_after(self(), {:flush_kills}, 100)
  {:noreply, update(socket, :pending_kills, &[kill | &1])}
end

def handle_info(:flush_kills, %{assigns: %{pending_kills: pk}} = socket) do
  new_list = (pk ++ socket.assigns.kills) |> Enum.take(100)
  {:noreply, socket |> assign(:kills, new_list) |> assign(:pending_kills, [])}
end
```

### Server-Side Throttle
Use Phoenix.PubSub with `fastlane: :kill_feed` and let each LiveView decide how often to pull:

```elixir
socket = socket |> assign(:last_push, System.monotonic_time()) 
# in handle_info:
if System.monotonic_time() - socket.assigns.last_push > @throttle_interval do
  push_event(socket, "kills", new_kills)
  assign(socket, :last_push, System.monotonic_time())
end
```

### Heartbeat & Backpressure
Rely on LiveView's built-in heartbeat. If the client can't keep up (slow ACKs), Phoenix will slow message delivery. You can monitor `phx_reply` latencies in Telemetry and dynamically reduce your throttle interval.

## Summary

- **Temporary assigns** + fixed window (e.g. 100 items) keep each LiveView process memory-bounded
- **Explicit pagination** for historical data avoids unbounded state
- **Debounce + batching** on both client and server sides smooth out bursts
- **Telemetry‐backed heartbeats** and LiveView's flow control ensure the socket never gets saturated

With these strategies, our real-time dashboards will remain responsive, efficient, and leak-free—even if thousands of players erupt in kills all at once.