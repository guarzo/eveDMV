defmodule EveDmv.Core.Utils.NaiveDateTimeUtils do
  @moduledoc """
  Utility functions specifically for NaiveDateTime operations.
  Provides compatibility layer for code expecting this separate module.
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  @doc """
  Compares two NaiveDateTime values.
  Returns :lt, :eq, or :gt
  """
  @spec compare(NaiveDateTime.t() | nil, NaiveDateTime.t() | nil) :: :lt | :eq | :gt | nil
  def compare(nil, nil), do: :eq
  def compare(nil, _), do: nil
  def compare(_, nil), do: nil
  def compare(%NaiveDateTime{} = ndt1, %NaiveDateTime{} = ndt2) do
    NaiveDateTime.compare(ndt1, ndt2)
  end

  @doc """
  Calculates the difference between two NaiveDateTime values.
  """
  @spec diff(NaiveDateTime.t(), NaiveDateTime.t(), System.time_unit()) :: integer()
  def diff(%NaiveDateTime{} = ndt1, %NaiveDateTime{} = ndt2, unit \\ :second) do
    DateTimeUtils.diff(ndt1, ndt2, unit)
  end

  @doc """
  Adds time to a NaiveDateTime value.
  """
  @spec add(NaiveDateTime.t(), integer(), System.time_unit()) :: NaiveDateTime.t()
  def add(%NaiveDateTime{} = ndt, amount, unit \\ :second) do
    DateTimeUtils.add(ndt, amount, unit)
  end

  @doc """
  Returns the current UTC naive datetime.
  """
  @spec utc_now() :: NaiveDateTime.t()
  def utc_now, do: NaiveDateTime.utc_now()

  @doc """
  Truncates a NaiveDateTime to the specified precision.
  """
  @spec truncate(NaiveDateTime.t(), atom()) :: NaiveDateTime.t()
  def truncate(%NaiveDateTime{} = ndt, precision) do
    NaiveDateTime.truncate(ndt, precision)
  end

  @doc """
  Converts a string to NaiveDateTime.
  """
  @spec from_iso8601(String.t()) :: {:ok, NaiveDateTime.t()} | {:error, atom()}
  def from_iso8601(string) when is_binary(string) do
    NaiveDateTime.from_iso8601(string)
  end

  @doc """
  Converts NaiveDateTime to ISO8601 string.
  """
  @spec to_iso8601(NaiveDateTime.t()) :: String.t()
  def to_iso8601(%NaiveDateTime{} = ndt) do
    NaiveDateTime.to_iso8601(ndt)
  end

  @doc """
  Returns the earlier of two NaiveDateTime values.
  """
  @spec min(NaiveDateTime.t() | nil, NaiveDateTime.t() | nil) :: NaiveDateTime.t() | nil
  def min(nil, ndt), do: ndt
  def min(ndt, nil), do: ndt
  def min(%NaiveDateTime{} = ndt1, %NaiveDateTime{} = ndt2) do
    case compare(ndt1, ndt2) do
      :lt -> ndt1
      _ -> ndt2
    end
  end

  @doc """
  Returns the later of two NaiveDateTime values.
  """
  @spec max(NaiveDateTime.t() | nil, NaiveDateTime.t() | nil) :: NaiveDateTime.t() | nil
  def max(nil, ndt), do: ndt
  def max(ndt, nil), do: ndt
  def max(%NaiveDateTime{} = ndt1, %NaiveDateTime{} = ndt2) do
    case compare(ndt1, ndt2) do
      :gt -> ndt1
      _ -> ndt2
    end
  end

  @doc """
  Checks if a NaiveDateTime is in the past (compared to UTC now).
  """
  @spec past?(NaiveDateTime.t() | nil) :: boolean()
  def past?(nil), do: false
  def past?(%NaiveDateTime{} = ndt) do
    case compare(ndt, utc_now()) do
      :lt -> true
      _ -> false
    end
  end

  @doc """
  Checks if a NaiveDateTime is in the future (compared to UTC now).
  """
  @spec future?(NaiveDateTime.t() | nil) :: boolean()
  def future?(nil), do: false
  def future?(%NaiveDateTime{} = ndt) do
    case compare(ndt, utc_now()) do
      :gt -> true
      _ -> false
    end
  end

  @doc """
  Converts NaiveDateTime to DateTime with UTC timezone.
  Delegates to DateTimeUtils for consistency.
  """
  @spec to_datetime(NaiveDateTime.t()) :: DateTime.t()
  def to_datetime(%NaiveDateTime{} = ndt) do
    DateTimeUtils.to_datetime(ndt)
  end

  @doc """
  Creates a NaiveDateTime from date and time components.

  ## Options
    * `:year` - the year component
    * `:month` - the month component
    * `:day` - the day component
    * `:hour` - the hour component (default: 0)
    * `:minute` - the minute component (default: 0)
    * `:second` - the second component (default: 0)
    * `:microsecond` - the microsecond component (default: {0, 0})
  """
  @spec new(keyword()) :: {:ok, NaiveDateTime.t()} | {:error, atom()}
  def new(opts) when is_list(opts) do
    year = Keyword.fetch!(opts, :year)
    month = Keyword.fetch!(opts, :month)
    day = Keyword.fetch!(opts, :day)
    hour = Keyword.get(opts, :hour, 0)
    minute = Keyword.get(opts, :minute, 0)
    second = Keyword.get(opts, :second, 0)
    microsecond = Keyword.get(opts, :microsecond, {0, 0})

    NaiveDateTime.new(year, month, day, hour, minute, second, microsecond)
  end

  @doc """
  Creates a NaiveDateTime from date and time components, raising on error.

  ## Options
    * `:year` - the year component
    * `:month` - the month component
    * `:day` - the day component
    * `:hour` - the hour component (default: 0)
    * `:minute` - the minute component (default: 0)
    * `:second` - the second component (default: 0)
    * `:microsecond` - the microsecond component (default: {0, 0})
  """
  @spec new!(keyword()) :: NaiveDateTime.t()
  def new!(opts) when is_list(opts) do
    year = Keyword.fetch!(opts, :year)
    month = Keyword.fetch!(opts, :month)
    day = Keyword.fetch!(opts, :day)
    hour = Keyword.get(opts, :hour, 0)
    minute = Keyword.get(opts, :minute, 0)
    second = Keyword.get(opts, :second, 0)
    microsecond = Keyword.get(opts, :microsecond, {0, 0})

    NaiveDateTime.new!(year, month, day, hour, minute, second, microsecond)
  end
end
