defmodule EveDmv.Core.Utils.DateTimeUtils do
  @moduledoc """
  Utility functions for handling DateTime and NaiveDateTime conversions.
  """
  """

  @doc """
  Safely converts any datetime type to DateTime with UTC timezone.
  """
  @spec to_datetime(DateTime.t() | NaiveDateTime.t() | nil) :: DateTime.t() | nil
  def to_datetime(nil), do: nil
  def to_datetime(%DateTime{} = dt), do: dt
  def to_datetime(%NaiveDateTime{} = ndt), do: DateTime.from_naive!(ndt, "Etc/UTC")

  @doc """
  Safely converts any datetime type to NaiveDateTime.
  """
  @spec to_naive_datetime(DateTime.t() | NaiveDateTime.t() | nil) :: NaiveDateTime.t() | nil
  def to_naive_datetime(nil), do: nil
  def to_naive_datetime(%NaiveDateTime{} = ndt), do: ndt
  def to_naive_datetime(%DateTime{} = dt), do: DateTime.to_naive(dt)

  @doc """
  Safely truncates a datetime to the specified precision.
  Handles both DateTime and NaiveDateTime types.
  """
  @spec truncate(DateTime.t() | NaiveDateTime.t() | nil, atom()) :: DateTime.t() | NaiveDateTime.t() | nil
  def truncate(nil, _precision), do: nil
  def truncate(%DateTime{} = dt, precision), do: DateTime.truncate(dt, precision)
  def truncate(%NaiveDateTime{} = ndt, precision), do: NaiveDateTime.truncate(ndt, precision)

  @doc """
  Safely calculates the difference between two datetimes in the specified unit.
  Handles mixed DateTime/NaiveDateTime types.
  """
  @spec diff(DateTime.t() | NaiveDateTime.t(), DateTime.t() | NaiveDateTime.t(), atom()) :: integer()
  def diff(dt1, dt2, unit \\ :second) do
    case {normalize_to_type(dt1), normalize_to_type(dt2)} do
      {%DateTime{} = d1, %DateTime{} = d2} -> DateTime.diff(d1, d2, unit)
      {%NaiveDateTime{} = n1, %NaiveDateTime{} = n2} -> NaiveDateTime.diff(n1, n2, unit)
      {d1, d2} ->
        # Convert both to DateTime for mixed types
        DateTime.diff(to_datetime(d1), to_datetime(d2), unit)
    end
  end

  # Normalize to the most common type between two values
  defp normalize_to_type(%DateTime{} = dt), do: dt
  defp normalize_to_type(%NaiveDateTime{} = ndt), do: ndt
  defp normalize_to_type(_), do: nil

  @doc """
  Safely converts a string to DateTime.
  Handles ISO8601 formats and common datetime string patterns.
  """
  @spec from_string(String.t() | nil) :: {:ok, DateTime.t()} | {:error, any()} | nil
  def from_string(nil), do: nil
  def from_string(string) when is_binary(string) do
    case DateTime.from_iso8601(string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _} = error -> error
    end
  end

  @doc """
  Converts Unix timestamp (seconds or milliseconds) to DateTime.
  """
  @spec from_unix(integer() | nil, :second | :millisecond) :: DateTime.t() | nil
  def from_unix(timestamp, unit \\ :second)
  def from_unix(nil, _unit), do: nil
  def from_unix(timestamp, unit) when is_integer(timestamp) do
    case DateTime.from_unix(timestamp, unit) do
      {:ok, datetime} -> datetime
      {:error, _} -> nil
    end
  end

  @doc """
  Converts DateTime to Unix timestamp.
  """
  @spec to_unix(DateTime.t() | NaiveDateTime.t() | nil, :second | :millisecond) :: integer() | nil
  def to_unix(datetime, unit \\ :second)
  def to_unix(nil, _unit), do: nil
  def to_unix(%DateTime{} = dt, unit), do: DateTime.to_unix(dt, unit)
  def to_unix(%NaiveDateTime{} = ndt, unit) do
    ndt
    |> to_datetime()
    |> DateTime.to_unix(unit)
  end

  @doc """
  Compares two datetime values safely.
  Returns :lt, :eq, or :gt
  """
  @spec compare(DateTime.t() | NaiveDateTime.t() | nil, DateTime.t() | NaiveDateTime.t() | nil) :: :lt | :eq | :gt | nil
  def compare(nil, nil), do: :eq
  def compare(nil, _), do: nil
  def compare(_, nil), do: nil
  def compare(dt1, dt2) do
    case {normalize_to_type(dt1), normalize_to_type(dt2)} do
      {%DateTime{} = d1, %DateTime{} = d2} -> DateTime.compare(d1, d2)
      {%NaiveDateTime{} = n1, %NaiveDateTime{} = n2} -> NaiveDateTime.compare(n1, n2)
      {d1, d2} ->
        # Convert both to DateTime for mixed types
        DateTime.compare(to_datetime(d1), to_datetime(d2))
    end
  end

  @doc """
  Adds time to a datetime value.
  """
  @spec add(DateTime.t() | NaiveDateTime.t() | nil, integer(), System.time_unit()) ::
          DateTime.t() | NaiveDateTime.t() | nil
  def add(nil, _amount, _unit), do: nil
  def add(%DateTime{} = dt, amount, unit), do: DateTime.add(dt, amount, unit)
  def add(%NaiveDateTime{} = ndt, amount, unit), do: NaiveDateTime.add(ndt, amount, unit)

  @doc """
  Returns the current UTC datetime.
  """
  @spec utc_now() :: DateTime.t()
  def utc_now, do: DateTime.utc_now()

  @doc """
  Returns the current UTC naive datetime.
  """
  @spec utc_now_naive() :: NaiveDateTime.t()
  def utc_now_naive, do: NaiveDateTime.utc_now()

  @doc """
  Checks if a datetime is in the past.
  """
  @spec past?(DateTime.t() | NaiveDateTime.t() | nil) :: boolean()
  def past?(nil), do: false
  def past?(datetime) do
    case compare(datetime, utc_now()) do
      :lt -> true
      _ -> false
    end
  end

  @doc """
  Checks if a datetime is in the future.
  """
  @spec future?(DateTime.t() | NaiveDateTime.t() | nil) :: boolean()
  def future?(nil), do: false
  def future?(datetime) do
    case compare(datetime, utc_now()) do
      :gt -> true
      _ -> false
    end
  end

  @doc """
  Formats a datetime to ISO8601 string.
  """
  @spec to_iso8601(DateTime.t() | NaiveDateTime.t() | nil) :: String.t() | nil
  def to_iso8601(nil), do: nil
  def to_iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def to_iso8601(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_iso8601(ndt)

  @doc """
  Returns the earlier of two datetimes.
  """
  @spec min(DateTime.t() | NaiveDateTime.t() | nil, DateTime.t() | NaiveDateTime.t() | nil) ::
          DateTime.t() | NaiveDateTime.t() | nil
  def min(nil, dt), do: dt
  def min(dt, nil), do: dt
  def min(dt1, dt2) do
    case compare(dt1, dt2) do
      :lt -> dt1
      _ -> dt2
    end
  end

  @doc """
  Returns the later of two datetimes.
  """
  @spec max(DateTime.t() | NaiveDateTime.t() | nil, DateTime.t() | NaiveDateTime.t() | nil) ::
          DateTime.t() | NaiveDateTime.t() | nil
  def max(nil, dt), do: dt
  def max(dt, nil), do: dt
  def max(dt1, dt2) do
    case compare(dt1, dt2) do
      :gt -> dt1
      _ -> dt2
    end
  end
end
