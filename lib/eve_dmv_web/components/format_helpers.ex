defmodule EveDmvWeb.FormatHelpers do
  @moduledoc """
  Shared formatting utility functions for EVE DMV components.

  Provides consistent formatting for numbers, ISK values, percentages,
  ratios, and other common data types across the application.
  """

  @doc """
  Formats numbers with proper comma separators and unit suffixes.
  """
  def format_number(nil), do: "0"

  def format_number(number) when is_binary(number) do
    # Handle string inputs by parsing them
    case Integer.parse(number) do
      {int_value, ""} ->
        format_number(int_value)

      _ ->
        case Float.parse(number) do
          {float_value, ""} -> format_number(float_value)
          # Return as-is if not parseable
          _ -> number
        end
    end
  end

  def format_number(number) when is_integer(number) do
    add_commas(Integer.to_string(number))
  end

  def format_number(%Decimal{} = number), do: number |> Decimal.to_float() |> format_number()

  def format_number(number) when is_float(number) do
    cond do
      number >= 1_000_000_000 ->
        "#{Float.round(number / 1_000_000_000, 1)}B"

      number >= 1_000_000 ->
        "#{Float.round(number / 1_000_000, 1)}M"

      number >= 1_000 ->
        "#{Float.round(number / 1_000, 1)}K"

      true ->
        number
        |> Float.round(2)
        |> Float.to_string()
        |> add_commas()
    end
  end

  @doc """
  Formats ISK amounts with proper unit labels.
  """
  def format_isk(nil), do: "0 ISK"
  def format_isk(amount), do: "#{format_number(amount)} ISK"

  @doc """
  Formats percentages with appropriate precision.
  """
  def format_percentage(nil), do: "0%"

  def format_percentage(%Decimal{} = decimal) do
    "#{decimal |> Decimal.to_float() |> Float.round(1)}%"
  end

  def format_percentage(percentage) do
    "#{Float.round(percentage, 1)}%"
  end

  @doc """
  Formats kill/death ratios with proper handling of edge cases.
  """
  def format_ratio(kills, losses) do
    case {kills, losses} do
      {0, 0} ->
        "0.00"

      {k, 0} ->
        "#{k}.00"

      {k, l} ->
        (k / l)
        |> Float.round(2)
        |> Float.to_string()
        |> add_commas()
    end
  end

  @doc """
  Formats net ISK with appropriate sign and styling.
  """
  def format_net_isk(destroyed, lost) do
    if both_are_decimals?(destroyed, lost) do
      net_isk = Decimal.sub(destroyed, lost)
      format_isk(net_isk)
    else
      net = (destroyed || 0) - (lost || 0)
      format_isk(net)
    end
  end

  @doc """
  Returns CSS class for net ISK based on positive/negative value.
  """
  def net_isk_class(destroyed, lost) do
    if both_are_decimals?(destroyed, lost) do
      net_isk = Decimal.sub(destroyed, lost)
      if Decimal.positive?(net_isk), do: "text-green-400", else: "text-red-400"
    else
      net = (destroyed || 0) - (lost || 0)
      if net >= 0, do: "text-green-400", else: "text-red-400"
    end
  end

  @doc """
  Formats security status with consistent decimal places.
  """
  def safe_security_status(nil), do: "0.00"

  def safe_security_status(status) when is_number(status),
    do: :erlang.float_to_binary(status, decimals: 2)

  def safe_security_status(_), do: "0.00"

  @doc """
  Formats character age from birthday into human-readable format.
  """
  def safe_character_age(nil), do: "Unknown"

  def safe_character_age(birthday) do
    case Date.from_iso8601(birthday) do
      {:ok, birth_date} ->
        days_old = Date.diff(Date.utc_today(), birth_date)
        years = div(days_old, 365)
        remaining_days = rem(days_old, 365)

        cond do
          years > 0 and remaining_days > 30 ->
            months = div(remaining_days, 30)
            "#{years} years, #{months} months"

          years > 0 ->
            "#{years} years"

          days_old > 30 ->
            months = div(days_old, 30)
            "#{months} months"

          true ->
            "#{days_old} days"
        end

      _ ->
        "Unknown"
    end
  end

  @doc """
  Formats average gang size with proper decimal handling.
  """
  def format_avg_gang_size(nil), do: "1.0"
  def format_avg_gang_size(size), do: format_number(size)

  @doc """
  Formats underscore-separated strings into title case.
  """
  def format_title_case(nil), do: ""

  def format_title_case(text) do
    text
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  # Private helper for adding commas to number strings
  defp add_commas(number_string) do
    number_string
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  defp both_are_decimals?(value1, value2) do
    value1 && value2 && is_struct(value1, Decimal) && is_struct(value2, Decimal)
  end

  @doc """
  Common CSS classes for small gray text elements.
  """
  def small_gray_text_class, do: "text-sm text-gray-400"

  @doc """
  Common CSS classes for muted secondary text.
  """
  def muted_text_class, do: "text-sm text-gray-500"

  @doc """
  Formats error messages consistently across the application.
  """
  def format_error_message(operation, reason) do
    "#{operation} failed: #{inspect(reason)}"
  end

  @doc """
  Formats error messages for user display (without inspect).
  """
  def format_user_error_message(operation, reason) when is_binary(reason) do
    "#{operation} failed: #{reason}"
  end

  def format_user_error_message(operation, _reason) do
    "#{operation} failed. Please try again."
  end
end
