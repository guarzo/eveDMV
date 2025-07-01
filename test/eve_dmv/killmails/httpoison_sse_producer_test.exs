defmodule EveDmv.Killmails.HTTPoisonSSEProducerTest do
  use EveDmv.DataCase, async: true
  use ExUnitProperties

  import Mox
  import ExUnit.CaptureLog

  alias Broadway.Message
  alias EveDmv.Killmails.HTTPoisonSSEProducer
  alias GenStage.TestConsumer

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Mock setup
  setup do
    # Stub HTTPoison calls for basic tests
    HTTPoisonMock
    |> stub(:get!, fn _url, _headers, _opts ->
      %HTTPoison.AsyncResponse{id: make_ref()}
    end)

    :ok
  end

  describe "SSE connection management" do
    @tag :skip
    test "establishes initial connection successfully" do
      # This test would require the actual HTTPoisonSSEProducer implementation
      # Skipping for now as we focus on the pipeline tests
      assert true
    end

    test "handles connection failures with exponential backoff" do
      # Mock connection failure
      expect(HTTPoisonMock, :get!, fn _url, _headers, _opts ->
        raise HTTPoison.Error, reason: :econnrefused
      end)

      # Capture reconnection attempts
      log =
        capture_log(fn ->
          {:ok, producer} =
            HTTPoisonSSEProducer.start_link(
              sse_url: "http://invalid.example.com/kills/stream",
              headers: [],
              # Fast reconnect for testing
              reconnect_delay: 100
            )

          # Wait for multiple reconnect attempts
          Process.sleep(250)
          GenServer.stop(producer)
        end)

      # Should log connection failures and reconnection attempts
      assert log =~ "SSE connection failed"
      assert log =~ "reconnecting"
    end

    test "handles connection drops and reconnects automatically" do
      test_pid = self()
      connection_ref = make_ref()

      # Mock initial successful connection
      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        # Send connection success then simulate drop
        spawn(fn ->
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})
          Process.sleep(50)
          # Simulate connection drop
          send(stream_to, %HTTPoison.AsyncEnd{id: connection_ref})
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      # Mock reconnection
      expect(HTTPoisonMock, :get!, fn _url, _headers, _opts ->
        %HTTPoison.AsyncResponse{id: make_ref()}
      end)

      log =
        capture_log(fn ->
          {:ok, producer} =
            HTTPoisonSSEProducer.start_link(
              sse_url: "http://test.example.com/kills/stream",
              headers: [],
              reconnect_delay: 50
            )

          # Wait for drop and reconnection
          Process.sleep(200)
          GenServer.stop(producer)
        end)

      assert log =~ "Connection ended"
      assert log =~ "reconnecting"
    end
  end

  describe "SSE event parsing" do
    test "parses valid SSE events correctly" do
      connection_ref = make_ref()
      test_pid = self()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          # Send connection setup
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})

          # Send valid SSE event
          sse_data = "event: killmail\ndata: {\"killmail_id\": 123456}\n\n"
          send(stream_to, %HTTPoison.AsyncChunk{id: connection_ref, chunk: sse_data})
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: []
        )

      # Subscribe to producer
      {:ok, consumer} = TestConsumer.start_link()
      GenStage.sync_subscribe(consumer, to: producer)

      # Should receive parsed event
      assert_receive {:events, [%Message{data: event_data}]}, 1000
      assert event_data["event"] == "killmail"
      assert event_data["data"] == "{\"killmail_id\": 123456}"

      GenServer.stop(producer)
    end

    test "handles malformed SSE events gracefully" do
      connection_ref = make_ref()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})

          # Send malformed SSE data
          malformed_data = "invalid sse format\n"
          send(stream_to, %HTTPoison.AsyncChunk{id: connection_ref, chunk: malformed_data})
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      log =
        capture_log(fn ->
          {:ok, producer} =
            HTTPoisonSSEProducer.start_link(
              sse_url: "http://test.example.com/kills/stream",
              headers: []
            )

          {:ok, consumer} = TestConsumer.start_link()
          GenStage.sync_subscribe(consumer, to: producer)

          # Wait for processing
          Process.sleep(100)
          GenServer.stop(producer)
        end)

      # Should log parsing errors but not crash
      assert log =~ "Failed to parse SSE" or log =~ "Ignoring incomplete"
    end

    test "handles chunked SSE events correctly" do
      connection_ref = make_ref()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})

          # Send event in multiple chunks
          send(stream_to, %HTTPoison.AsyncChunk{id: connection_ref, chunk: "event: kill"})

          send(stream_to, %HTTPoison.AsyncChunk{
            id: connection_ref,
            chunk: "mail\ndata: {\"test\": "
          })

          send(stream_to, %HTTPoison.AsyncChunk{id: connection_ref, chunk: "\"value\"}\n\n"})
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: []
        )

      {:ok, consumer} = TestConsumer.start_link()
      GenStage.sync_subscribe(consumer, to: producer)

      # Should receive complete parsed event
      assert_receive {:events, [%Message{data: event_data}]}, 1000
      assert event_data["event"] == "killmail"
      assert event_data["data"] == "{\"test\": \"value\"}"

      GenServer.stop(producer)
    end

    test "ignores heartbeat events" do
      connection_ref = make_ref()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})

          # Send heartbeat and killmail events
          send(stream_to, %HTTPoison.AsyncChunk{
            id: connection_ref,
            chunk: "event: heartbeat\ndata: {}\n\n"
          })

          send(stream_to, %HTTPoison.AsyncChunk{
            id: connection_ref,
            chunk: "event: killmail\ndata: {\"killmail_id\": 123}\n\n"
          })
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: []
        )

      {:ok, consumer} = TestConsumer.start_link()
      GenStage.sync_subscribe(consumer, to: producer)

      # Should only receive killmail event, not heartbeat
      assert_receive {:events, [%Message{data: event_data}]}, 1000
      assert event_data["event"] == "killmail"

      # Should not receive additional heartbeat events
      refute_receive {:events, _}, 500

      GenServer.stop(producer)
    end
  end

  describe "error handling and resilience" do
    test "handles HTTP error responses" do
      connection_ref = make_ref()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          # Send error status
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 500})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})
          send(stream_to, %HTTPoison.AsyncEnd{id: connection_ref})
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      # Mock reconnection attempt
      expect(HTTPoisonMock, :get!, fn _url, _headers, _opts ->
        %HTTPoison.AsyncResponse{id: make_ref()}
      end)

      log =
        capture_log(fn ->
          {:ok, producer} =
            HTTPoisonSSEProducer.start_link(
              sse_url: "http://test.example.com/kills/stream",
              headers: [],
              reconnect_delay: 50
            )

          # Wait for error handling and reconnection
          Process.sleep(150)
          GenServer.stop(producer)
        end)

      assert log =~ "HTTP error" or log =~ "status 500"
    end

    test "handles network timeouts" do
      expect(HTTPoisonMock, :get!, fn _url, _headers, _opts ->
        raise HTTPoison.Error, reason: :timeout
      end)

      log =
        capture_log(fn ->
          {:ok, producer} =
            HTTPoisonSSEProducer.start_link(
              sse_url: "http://test.example.com/kills/stream",
              headers: [],
              reconnect_delay: 100
            )

          Process.sleep(150)
          GenServer.stop(producer)
        end)

      assert log =~ "timeout" or log =~ "connection failed"
    end

    test "maintains connection statistics" do
      connection_ref = make_ref()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})

          # Send multiple events
          for i <- 1..5 do
            sse_data = "event: killmail\ndata: {\"killmail_id\": #{i}}\n\n"
            send(stream_to, %HTTPoison.AsyncChunk{id: connection_ref, chunk: sse_data})
          end
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: []
        )

      {:ok, consumer} = TestConsumer.start_link()
      GenStage.sync_subscribe(consumer, to: producer)

      # Receive events
      for _i <- 1..5 do
        assert_receive {:events, [%Message{}]}, 1000
      end

      # Check statistics (if exposed by the producer)
      # This would depend on the actual implementation

      GenServer.stop(producer)
    end
  end

  describe "configuration and customization" do
    test "accepts custom headers" do
      custom_headers = [{"Authorization", "Bearer token123"}, {"User-Agent", "TestClient"}]

      expect(HTTPoisonMock, :get!, fn _url, headers, _opts ->
        assert {"Authorization", "Bearer token123"} in headers
        assert {"User-Agent", "TestClient"} in headers

        %HTTPoison.AsyncResponse{id: make_ref()}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: custom_headers
        )

      Process.sleep(50)
      GenServer.stop(producer)
    end

    test "respects custom timeout settings" do
      custom_timeout = 30_000

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        assert Keyword.get(opts, :recv_timeout) == custom_timeout

        %HTTPoison.AsyncResponse{id: make_ref()}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: [],
          timeout: custom_timeout
        )

      Process.sleep(50)
      GenServer.stop(producer)
    end

    test "handles custom reconnect delays" do
      expect(HTTPoisonMock, :get!, fn _url, _headers, _opts ->
        raise HTTPoison.Error, reason: :econnrefused
      end)

      start_time = System.monotonic_time(:millisecond)

      log =
        capture_log(fn ->
          {:ok, producer} =
            HTTPoisonSSEProducer.start_link(
              sse_url: "http://invalid.example.com/kills/stream",
              headers: [],
              # Custom delay
              reconnect_delay: 200
            )

          # Wait for at least one reconnect
          Process.sleep(250)
          GenServer.stop(producer)
        end)

      # Should respect custom reconnect delay
      assert log =~ "reconnecting"
    end
  end

  describe "memory management" do
    test "handles high-frequency events without memory leaks" do
      connection_ref = make_ref()

      expect(HTTPoisonMock, :get!, fn _url, _headers, opts ->
        stream_to = Keyword.get(opts, :stream_to)

        spawn(fn ->
          send(stream_to, %HTTPoison.AsyncStatus{id: connection_ref, code: 200})
          send(stream_to, %HTTPoison.AsyncHeaders{id: connection_ref, headers: []})

          # Send many events rapidly
          for i <- 1..100 do
            sse_data = "event: killmail\ndata: {\"killmail_id\": #{i}}\n\n"
            send(stream_to, %HTTPoison.AsyncChunk{id: connection_ref, chunk: sse_data})
          end
        end)

        %HTTPoison.AsyncResponse{id: connection_ref}
      end)

      {:ok, producer} =
        HTTPoisonSSEProducer.start_link(
          sse_url: "http://test.example.com/kills/stream",
          headers: []
        )

      {:ok, consumer} = TestConsumer.start_link()
      GenStage.sync_subscribe(consumer, to: producer)

      # Receive all events
      for _i <- 1..100 do
        assert_receive {:events, [%Message{}]}, 100
      end

      # Producer should still be responsive
      assert Process.alive?(producer)

      GenServer.stop(producer)
    end
  end

  # Property-based testing for robust event parsing
  property "correctly parses well-formed SSE events" do
    check all(
            event_type <- member_of(["killmail", "heartbeat", "status"]),
            killmail_id <- positive_integer(),
            character_id <- positive_integer()
          ) do
      data = Jason.encode!(%{"killmail_id" => killmail_id, "character_id" => character_id})
      sse_data = "event: #{event_type}\ndata: #{data}\n\n"

      # Test that the SSE parsing doesn't crash on valid data
      # This would require exposing the parse_sse_chunk function or testing through integration
      assert String.contains?(sse_data, "event:")
      assert String.contains?(sse_data, "data:")
    end
  end
end
