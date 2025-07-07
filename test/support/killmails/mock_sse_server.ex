defmodule EveDmv.Killmails.MockSSEServer do
  @moduledoc """
  Mock SSE server for development and testing.
  Simulates the wanderer-kills SSE feed by generating fake killmail events.
  """

  use GenServer

  alias EveDmv.Killmails.TestDataGenerator

  require Logger

  @default_port 8080
  # Send an event every 5 seconds
  @default_interval 5000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.stop(__MODULE__)
  end

  def init(opts) do
    port = Keyword.get(opts, :port, @default_port)
    interval = Keyword.get(opts, :interval, @default_interval)

    state = %{
      port: port,
      interval: interval,
      server_ref: nil,
      clients: []
    }

    # Start the HTTP server
    case start_server(port) do
      {:ok, server_ref} ->
        Logger.info("Mock SSE server started on port #{port}")
        schedule_next_event(interval)
        {:ok, %{state | server_ref: server_ref}}

      {:error, reason} ->
        Logger.error("Failed to start mock SSE server: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  def handle_info(:send_event, state) do
    # Generate and send a killmail event to all connected clients
    event = TestDataGenerator.generate_sample_sse_event()
    broadcast_event(state.clients, event)

    # Schedule the next event
    schedule_next_event(state.interval)

    {:noreply, state}
  end

  def handle_info({:new_client, client_pid}, state) do
    Logger.debug("New SSE client connected")
    {:noreply, %{state | clients: [client_pid | state.clients]}}
  end

  def handle_info({:client_disconnected, client_pid}, state) do
    Logger.debug("SSE client disconnected")
    new_clients = List.delete(state.clients, client_pid)
    {:noreply, %{state | clients: new_clients}}
  end

  def handle_info(msg, state) do
    Logger.debug("Unexpected message in mock SSE server: #{inspect(msg)}")
    {:noreply, state}
  end

  def terminate(_reason, %{server_ref: server_ref}) when server_ref != nil do
    :ranch.stop_listener(server_ref)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  # Private functions

  defp start_server(port) do
    dispatch =
      :cowboy_router.compile([
        {:_,
         [
           {"/sse", __MODULE__.SSEHandler, []},
           {:_, __MODULE__.DefaultHandler, []}
         ]}
      ])

    try do
      case :cowboy.start_clear(
             :mock_sse_server,
             [{:port, port}],
             %{env: %{dispatch: dispatch}}
           ) do
        {:ok, _} -> {:ok, :mock_sse_server}
        {:error, reason} -> {:error, reason}
      end
    rescue
      error ->
        {:error, error}
    end
  end

  defp schedule_next_event(interval) do
    Process.send_after(self(), :send_event, interval)
  end

  defp broadcast_event(clients, event) do
    sse_data = format_sse_event(event)

    Enum.each(clients, fn client_pid ->
      send(client_pid, {:sse_data, sse_data})
    end)
  end

  defp format_sse_event(%{event: event, data: data, id: id}) do
    initial_parts = []

    parts_with_id = if id != nil, do: ["id: #{id}" | initial_parts], else: initial_parts

    parts_with_event =
      if event != nil, do: ["event: #{event}" | parts_with_id], else: parts_with_id

    parts_with_data = ["data: #{data}" | parts_with_event]

    Enum.join(parts_with_data, "\n") <> "\n\n"
  end
end

defmodule EveDmv.Killmails.MockSSEServer.SSEHandler do
  @moduledoc """
  Cowboy handler for SSE requests.
  """

  alias EveDmv.Killmails.TestDataGenerator

  require Logger

  def init(req, state) do
    # Set proper SSE headers and start streaming response
    req =
      :cowboy_req.stream_reply(
        200,
        %{
          "content-type" => "text/event-stream",
          "cache-control" => "no-cache",
          "connection" => "keep-alive",
          "access-control-allow-origin" => "*"
        },
        req
      )

    # Send initial SSE event
    initial_event = """
    event: connected
    data: SSE stream connected

    """

    :cowboy_req.stream_body(initial_event, :nofin, req)

    # Start streaming events periodically
    spawn_link(fn ->
      stream_killmail_events(req)
    end)

    {:ok, req, state}
  end

  defp stream_killmail_events(req) do
    # Generate a killmail event every 10 seconds
    sample_data = TestDataGenerator.generate_sample_killmail()

    sse_event = """
    event: killmail
    data: #{Jason.encode!(sample_data)}

    """

    :ok = :cowboy_req.stream_body(sse_event, :nofin, req)
    Logger.debug("Sent SSE killmail event: #{sample_data["killmail_id"]}")
    # Wait 10 seconds
    :timer.sleep(10_000)
    stream_killmail_events(req)
  end
end

defmodule EveDmv.Killmails.MockSSEServer.DefaultHandler do
  @moduledoc """
  Default handler for non-SSE requests.
  """

  def init(req, state) do
    body = """
    Mock SSE Server for EVE DMV

    Available endpoints:
    - GET /sse - Server-Sent Events stream for killmail data

    The SSE endpoint will send fake killmail events every 5 seconds.
    """

    req =
      :cowboy_req.reply(
        200,
        %{"content-type" => "text/plain"},
        body,
        req
      )

    {:ok, req, state}
  end
end
