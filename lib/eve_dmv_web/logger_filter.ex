defmodule EveDmvWeb.LoggerFilter do
  @moduledoc """
  Logger filters to reduce noise from database connection pool messages.
  """

  def filter_db_connection_noise(event, _config) do
    case event do
      # Check for message field in event map
      %{msg: {:string, content}} ->
        string =
          case content do
            s when is_binary(s) -> s
            l when is_list(l) -> List.to_string(l)
            _ -> ""
          end

        if String.contains?(string, "Supervisor received unexpected message") and
             String.contains?(string, "db_connection") do
          :ignore
        else
          event
        end

      # Check for formatted message
      %{msg: {:report, %{label: label}}} when is_binary(label) ->
        if String.contains?(label, "Supervisor received unexpected message") do
          :ignore
        else
          event
        end

      # Check the level and message content for error logs
      %{level: :error, msg: msg} ->
        case msg do
          {:string, content} ->
            string =
              case content do
                s when is_binary(s) -> s
                l when is_list(l) -> List.to_string(l)
                _ -> ""
              end

            if String.contains?(string, "Supervisor received unexpected message") do
              :ignore
            else
              event
            end

          _ ->
            event
        end

      # Allow all other messages through
      _ ->
        event
    end
  end
end
