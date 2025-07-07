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
        number |> Float.round(2) |> Float.to_string() |> add_commas()
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
      {0, 0} -> "0.00"
      {k, 0} -> "#{k}.00"
      {k, l} -> (k / l) |> Float.round(2) |> Float.to_string() |> add_commas()
    end
  end

  @doc """
  Formats net ISK with appropriate sign and styling.
  """
  def format_net_isk(destroyed, lost) do
    if destroyed && lost && is_struct(destroyed, Decimal) && is_struct(lost, Decimal) do
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
    if destroyed && lost && is_struct(destroyed, Decimal) && is_struct(lost, Decimal) do
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

  # Private helper for adding commas to number strings
  defp add_commas(number_string) do
    number_string
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end
end
