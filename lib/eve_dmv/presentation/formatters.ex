defmodule EveDmv.Presentation.Formatters do
  @moduledoc """
  Formatting utilities for UI presentation
  """

  alias EveDmv.Constants.Isk

  def format_isk(decimal_value) when is_struct(decimal_value, Decimal) do
    # Delegate to the centralized ISK formatting utility
    Isk.format_isk(decimal_value)
  end

  def format_isk(value) when is_number(value) do
    # Delegate to the centralized ISK formatting utility
    Isk.format_isk(value)
  end

  def format_isk(_), do: "0 ISK"

  def format_time_ago(minutes) when is_integer(minutes) do
    # Move time formatting logic here
    cond do
      minutes < 1 -> "Just now"
      minutes < 60 -> "#{minutes}m ago"
      minutes < 1440 -> "#{div(minutes, 60)}h ago"
      true -> "#{div(minutes, 1440)}d ago"
    end
  end

  def format_time_ago(_), do: "Unknown"

  def format_percentage(value) when is_number(value) do
    "#{Float.round(value, 1)}%"
  end

  def format_percentage(_), do: "0.0%"

  def format_number(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.split("", trim: true)
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.join(",")
  end

  def format_number(value) when is_float(value) do
    truncated_value = trunc(value)
    format_number(truncated_value)
  end

  def format_number(_), do: "0"

  def format_datetime(datetime, format \\ :short)

  def format_datetime(%DateTime{} = datetime, :short) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  def format_datetime(%DateTime{} = datetime, :long) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S UTC")
  end

  def format_datetime(%DateTime{} = datetime, :date_only) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end

  def format_datetime(%DateTime{} = datetime, :time_only) do
    Calendar.strftime(datetime, "%H:%M:%S")
  end

  def format_datetime(_, _), do: "Unknown"

  def format_ship_class(ship_type_id) when is_integer(ship_type_id) do
    # Format ship class based on type ID ranges
    cond do
      ship_type_id in 25..40 -> "Frigate"
      ship_type_id in 419..420 -> "Destroyer"
      ship_type_id in 620..660 -> "Cruiser"
      ship_type_id in 1200..1300 -> "Battlecruiser"
      ship_type_id in 630..650 -> "Battleship"
      true -> "Unknown Class"
    end
  end

  def format_ship_class(_), do: "Unknown Class"

  def format_security_status(status) when is_float(status) do
    cond do
      status >= 0.5 -> "High Sec"
      status > 0.0 -> "Low Sec"
      status == 0.0 -> "Null Sec"
      status < 0.0 -> "Wormhole"
      true -> "Unknown"
    end
  end

  def format_security_status(_), do: "Unknown"

  def format_duration(seconds) when is_integer(seconds) do
    hours = div(seconds, 3600)
    minutes = div(rem(seconds, 3600), 60)
    seconds = rem(seconds, 60)

    parts =
      []
      |> add_duration_part(hours, "h")
      |> add_duration_part(minutes, "m")
      |> add_duration_part(seconds, "s")

    case parts do
      [] -> "0s"
      parts -> Enum.join(parts, " ")
    end
  end

  def format_duration(_), do: "Unknown"

  defp add_duration_part(parts, 0, _unit), do: parts
  defp add_duration_part(parts, value, unit), do: ["#{value}#{unit}" | parts]

  def format_distance(au) when is_number(au) do
    cond do
      au < 1 -> "#{Float.round(au * 149_597_870.7, 1)} km"
      au < 100 -> "#{Float.round(au, 2)} AU"
      true -> "#{Float.round(au, 0)} AU"
    end
  end

  def format_distance(_), do: "Unknown"

  def format_standing(standing) when is_number(standing) do
    cond do
      standing >= 5.0 -> "+#{standing} (Excellent)"
      standing >= 0.0 -> "+#{standing} (Good)"
      standing >= -5.0 -> "#{standing} (Neutral)"
      standing >= -10.0 -> "#{standing} (Bad)"
      true -> "#{standing} (Terrible)"
    end
  end

  def format_standing(_), do: "0.0 (Neutral)"

  def pluralize(count, singular, plural \\ nil) do
    plural = plural || "#{singular}s"

    if count == 1 do
      "#{count} #{singular}"
    else
      "#{count} #{plural}"
    end
  end

  def format_killmail_id(killmail_id) when is_integer(killmail_id) do
    "KM-#{killmail_id}"
  end

  def format_killmail_id(_), do: "KM-Unknown"

  def format_list(items, separator \\ ", ", last_separator \\ " and ")

  def format_list([], _, _), do: ""
  def format_list([item], _, _), do: to_string(item)
  def format_list([first, second], _, last_separator), do: "#{first}#{last_separator}#{second}"

  def format_list(items, separator, last_separator) when is_list(items) do
    {last, rest} = List.pop_at(items, -1)
    "#{Enum.join(rest, separator)}#{last_separator}#{last}"
  end

  def format_list(_, _, _), do: ""
end
