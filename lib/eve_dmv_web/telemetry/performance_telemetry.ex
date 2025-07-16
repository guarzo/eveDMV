defmodule EveDmvWeb.Telemetry.PerformanceTelemetry do
  @moduledoc """
  Telemetry handlers for automatic performance tracking.
  Integrates with Phoenix, Ecto, and custom events to track performance metrics.
  """

  alias EveDmv.Monitoring.PerformanceTracker
  require Logger

  def attach_handlers do
    # Attach Ecto query handlers
    :telemetry.attach(
      "eve-dmv-ecto-query-handler",
      [:eve_dmv, :repo, :query],
      &handle_ecto_query/4,
      nil
    )

    # Attach Phoenix LiveView handlers
    :telemetry.attach_many(
      "eve-dmv-liveview-handlers",
      [
        [:phoenix, :live_view, :mount, :stop],
        [:phoenix, :live_view, :handle_event, :stop],
        [:phoenix, :live_view, :handle_info, :stop]
      ],
      &handle_liveview_event/4,
      nil
    )

    # Attach Phoenix controller handlers
    :telemetry.attach(
      "eve-dmv-controller-handler",
      [:phoenix, :endpoint, :stop],
      &handle_endpoint_stop/4,
      nil
    )

    # Attach custom application events
    :telemetry.attach_many(
      "eve-dmv-custom-handlers",
      [
        [:eve_dmv, :api, :call, :stop],
        [:eve_dmv, :cache, :lookup, :stop],
        [:eve_dmv, :analysis, :stop]
      ],
      &handle_custom_event/4,
      nil
    )

    Logger.info("Performance telemetry handlers attached")
  end

  # Ecto query handler
  defp handle_ecto_query(_event_name, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.total_time, :native, :millisecond)

    # Extract query info
    query_string = metadata.query
    source = metadata.source

    # Create a simplified query name
    query_name = extract_query_name(query_string, source)

    # Track the query
    PerformanceTracker.track_query(query_name, duration_ms,
      metadata: %{
        source: source,
        query: String.slice(query_string, 0, 200),
        params_count: length(metadata.params || [])
      }
    )
  end

  # LiveView event handlers
  defp handle_liveview_event(event_name, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    view_module = inspect(metadata.socket.view)
    action = extract_action_from_event(event_name)

    # Add extra metadata for specific actions
    extra_metadata =
      case event_name do
        [:phoenix, :live_view, :handle_event, :stop] ->
          %{event: metadata.event}

        [:phoenix, :live_view, :handle_info, :stop] ->
          %{message: inspect(metadata.msg) |> String.slice(0, 50)}

        _ ->
          %{}
      end

    PerformanceTracker.track_liveview(view_module, action, duration_ms, metadata: extra_metadata)
  end

  # Phoenix endpoint handler
  defp handle_endpoint_stop(_event_name, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    # Only track if it's an API or LiveView request
    if metadata.conn.path_info != [] do
      path = "/" <> Enum.join(metadata.conn.path_info, "/")
      method = metadata.conn.method

      PerformanceTracker.track_api_call("phoenix", "#{method} #{path}", duration_ms,
        metadata: %{
          status: metadata.conn.status,
          remote_ip: to_string(:inet.ntoa(metadata.conn.remote_ip))
        }
      )
    end
  end

  # Custom application event handlers
  defp handle_custom_event(event_name, measurements, metadata, _config) do
    duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)

    case event_name do
      [:eve_dmv, :api, :call, :stop] ->
        PerformanceTracker.track_api_call(
          "internal",
          "#{metadata.domain}.#{metadata.action}",
          duration_ms,
          metadata: Map.take(metadata, [:resource, :domain])
        )

      [:eve_dmv, :cache, :lookup, :stop] ->
        cache_key = metadata.key |> to_string() |> String.slice(0, 50)
        hit_miss = if metadata.hit, do: "hit", else: "miss"

        PerformanceTracker.track_query(
          "cache:#{hit_miss}:#{cache_key}",
          duration_ms,
          metadata: %{hit: metadata.hit}
        )

      [:eve_dmv, :analysis, :stop] ->
        PerformanceTracker.track_query(
          "analysis:#{metadata.type}",
          duration_ms,
          metadata: Map.take(metadata, [:character_id, :corporation_id, :alliance_id])
        )

      _ ->
        nil
    end
  end

  # Helper functions

  defp extract_query_name(query_string, source) do
    # Try to extract the main operation from the query
    cond do
      String.contains?(query_string, "SELECT") ->
        table = extract_table_name(query_string, "FROM")
        "SELECT:#{source || table}"

      String.contains?(query_string, "INSERT") ->
        table = extract_table_name(query_string, "INTO")
        "INSERT:#{source || table}"

      String.contains?(query_string, "UPDATE") ->
        "UPDATE:#{source || "unknown"}"

      String.contains?(query_string, "DELETE") ->
        table = extract_table_name(query_string, "FROM")
        "DELETE:#{source || table}"

      true ->
        "QUERY:#{source || "unknown"}"
    end
  end

  defp extract_table_name(query_string, keyword) do
    case Regex.run(~r/#{keyword}\s+([^\s,]+)/i, query_string) do
      [_, table] ->
        table
        |> String.replace("\"", "")
        |> String.split(".")
        |> List.last()

      _ ->
        "unknown"
    end
  end

  defp extract_action_from_event(event_name) do
    case event_name do
      [:phoenix, :live_view, :mount, :stop] -> "mount"
      [:phoenix, :live_view, :handle_event, :stop] -> "handle_event"
      [:phoenix, :live_view, :handle_info, :stop] -> "handle_info"
      _ -> "unknown"
    end
  end

  @doc """
  Emit custom telemetry event for analysis operations.

  Usage:
    :telemetry.span(
      [:eve_dmv, :analysis],
      %{type: "character_stats"},
      fn ->
        result = do_expensive_analysis()
        {result, %{character_id: char_id}}
      end
    )
  """
  def span_analysis(type, metadata, fun) do
    :telemetry.span(
      [:eve_dmv, :analysis],
      Map.put(metadata, :type, type),
      fun
    )
  end
end
