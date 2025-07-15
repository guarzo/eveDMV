defmodule EveDmv.Logging.StructuredFormatter do
  @moduledoc """
  Structured JSON formatter for EVE DMV application logging.

  Provides consistent structured logging format for observability,
  monitoring, and log aggregation systems.
  """

  @behaviour :logger_formatter

  @impl :logger_formatter
  def format(%{level: level, msg: message, time: timestamp, meta: metadata}, _opts) do
    log_entry =
      %{
        "@timestamp": format_timestamp(timestamp),
        level: level,
        message: format_message(message),
        service: "eve_dmv",
        environment: Application.get_env(:eve_dmv, :environment, :prod)
      }
      |> add_metadata(metadata)
      |> add_context_fields(metadata)
      |> Jason.encode!()

    [log_entry, "\n"]
  end

  @impl :logger_formatter
  def check_config(_config) do
    # Formatter configuration is valid
    :ok
  end

  # Private functions

  defp format_timestamp(timestamp) do
    # Convert erlang timestamp to ISO8601 format
    case timestamp do
      {_, _, _} = _erl_timestamp ->
        # Legacy erlang timestamp format
        :calendar.system_time_to_rfc3339(
          :erlang.convert_time_unit(:erlang.timestamp(), :microsecond, :second),
          [{:unit, :second}]
        )

      timestamp when is_integer(timestamp) ->
        # Modern system timestamp
        :calendar.system_time_to_rfc3339(timestamp, [{:unit, :microsecond}])

      _ ->
        # Fallback to current time
        DateTime.utc_now() |> DateTime.to_iso8601()
    end
  end

  defp format_message(message) when is_binary(message), do: message
  defp format_message(message) when is_list(message), do: IO.iodata_to_binary(message)
  defp format_message(message), do: inspect(message)

  defp add_metadata(log_entry, metadata) do
    # Add standard metadata fields
    standard_fields = [
      :request_id,
      :user_id,
      :character_id,
      :corporation_id,
      :task_id,
      :supervisor,
      :duration_ms,
      :entity_type,
      :entity_id,
      :threat_level,
      :plugin
    ]

    metadata
    |> Enum.filter(fn {key, _value} -> key in standard_fields end)
    |> Enum.reduce(log_entry, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp add_context_fields(log_entry, metadata) do
    log_entry
    |> maybe_add_error_context(metadata)
    |> maybe_add_performance_context(metadata)
    |> maybe_add_security_context(metadata)
    |> maybe_add_business_context(metadata)
  end

  defp maybe_add_error_context(log_entry, metadata) do
    case {metadata[:error], metadata[:exception], metadata[:reason]} do
      {nil, nil, nil} ->
        log_entry

      {error, exception, reason} ->
        error_context =
          %{
            error: format_error(error),
            exception: format_exception(exception),
            reason: format_reason(reason)
          }
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)
          |> Map.new()

        Map.put(log_entry, :error_context, error_context)
    end
  end

  defp maybe_add_performance_context(log_entry, metadata) do
    performance_fields = [:duration_ms, :query_time, :response_time, :memory_usage]

    performance_data =
      metadata
      |> Enum.filter(fn {key, _value} -> key in performance_fields end)
      |> Map.new()

    case performance_data do
      empty when map_size(empty) == 0 -> log_entry
      data -> Map.put(log_entry, :performance, data)
    end
  end

  defp maybe_add_security_context(log_entry, metadata) do
    security_fields = [:user_id, :character_id, :corporation_id, :threat_level, :security_event]

    security_data =
      metadata
      |> Enum.filter(fn {key, _value} -> key in security_fields end)
      |> Map.new()

    case security_data do
      empty when map_size(empty) == 0 -> log_entry
      data -> Map.put(log_entry, :security, data)
    end
  end

  defp maybe_add_business_context(log_entry, metadata) do
    business_fields = [:entity_type, :entity_id, :operation, :killmail_id, :battle_id]

    business_data =
      metadata
      |> Enum.filter(fn {key, _value} -> key in business_fields end)
      |> Map.new()

    case business_data do
      empty when map_size(empty) == 0 -> log_entry
      data -> Map.put(log_entry, :business, data)
    end
  end

  defp format_error(nil), do: nil
  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp format_exception(nil), do: nil
  defp format_exception(exception), do: Exception.format(:error, exception)

  defp format_reason(nil), do: nil
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
