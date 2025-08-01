defmodule EveDmv.Core.SharedKernel.ValueObjects.IskAmount do
  @moduledoc """
  Value object representing an ISK (Interstellar Kredits) amount in EVE Online.

  ISK amounts are immutable monetary values with formatting and calculation utilities.
  """

  defstruct [:value]

  @type t :: %__MODULE__{value: float()}

  @doc """
  Create a new IskAmount from a numeric value.
  """
  @spec new(number()) :: {:ok, t()} | {:error, String.t()}
  def new(amount) when is_number(amount) and amount >= 0 do
    {:ok, %__MODULE__{value: amount * 1.0}}
  end

  def new(amount) when is_number(amount) do
    {:error, "ISK amount cannot be negative"}
  end

  def new(_) do
    {:error, "ISK amount must be a number"}
  end

  @doc """
  Create a new IskAmount from a string.
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string(str) when is_binary(str) do
    case Float.parse(str) do
      {amount, ""} -> new(amount)
      _ -> {:error, "Invalid ISK amount format"}
    end
  end

  def from_string(_) do
    {:error, "ISK amount must be a string"}
  end

  @doc """
  Get the raw float value.
  """
  @spec to_float(t()) :: float()
  def to_float(%__MODULE__{value: value}), do: value

  @doc """
  Convert to integer (truncated).
  """
  @spec to_integer(t()) :: integer()
  def to_integer(%__MODULE__{value: value}), do: trunc(value)

  @doc """
  Add two ISK amounts.
  """
  @spec add(t(), t()) :: t()
  def add(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    %__MODULE__{value: v1 + v2}
  end

  @doc """
  Subtract one ISK amount from another.
  """
  @spec subtract(t(), t()) :: t()
  def subtract(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    %__MODULE__{value: max(0.0, v1 - v2)}
  end

  @doc """
  Multiply ISK amount by a factor.
  """
  @spec multiply(t(), number()) :: t()
  def multiply(%__MODULE__{value: value}, factor) when is_number(factor) do
    %__MODULE__{value: value * factor}
  end

  @doc """
  Divide ISK amount by a divisor.
  """
  @spec divide(t(), number()) :: t()
  def divide(%__MODULE__{value: _value}, 0), do: %__MODULE__{value: 0.0}
  def divide(%__MODULE__{value: _value}, +0.0), do: %__MODULE__{value: 0.0}
  def divide(%__MODULE__{value: _value}, -0.0), do: %__MODULE__{value: 0.0}

  def divide(%__MODULE__{value: value}, divisor) when is_number(divisor) do
    %__MODULE__{value: value / divisor}
  end

  @doc """
  Check if two ISK amounts are equal.
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    # Account for floating point precision
    abs(v1 - v2) < 0.01
  end

  @doc """
  Compare two ISK amounts.
  """
  @spec compare(t(), t()) :: :gt | :eq | :lt
  def compare(%__MODULE__{value: v1}, %__MODULE__{value: v2}) do
    cond do
      v1 > v2 -> :gt
      abs(v1 - v2) < 0.01 -> :eq
      true -> :lt
    end
  end

  @doc """
  Check if ISK amount is zero.
  """
  @spec zero?(t()) :: boolean()
  def zero?(%__MODULE__{value: value}), do: abs(value) < 0.01

  @doc """
  Check if ISK amount is positive.
  """
  @spec positive?(t()) :: boolean()
  def positive?(%__MODULE__{value: value}), do: value > 0.01

  @doc """
  Format ISK amount with appropriate suffixes (K, M, B, T).
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{value: isk}) do
    cond do
      isk >= 1_000_000_000_000 -> "#{Float.round(isk / 1_000_000_000_000, 2)}T ISK"
      isk >= 1_000_000_000 -> "#{Float.round(isk / 1_000_000_000, 2)}B ISK"
      isk >= 1_000_000 -> "#{Float.round(isk / 1_000_000, 2)}M ISK"
      isk >= 1_000 -> "#{Float.round(isk / 1_000, 2)}K ISK"
      true -> "#{Float.round(isk, 2)} ISK"
    end
  end

  @doc """
  Format ISK amount with comma separators.
  """
  @spec format_detailed(t()) :: String.t()
  def format_detailed(%__MODULE__{value: isk}) do
    isk
    |> trunc()
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> Kernel.<>(" ISK")
  end

  @doc """
  Calculate efficiency ratio between destroyed and lost ISK.
  """
  @spec efficiency_ratio(t(), t()) :: float()
  def efficiency_ratio(%__MODULE__{value: destroyed}, %__MODULE__{value: lost}) do
    if destroyed + lost > 0 do
      destroyed / (destroyed + lost)
    else
      1.0
    end
  end

  @doc """
  Get zero ISK amount.
  """
  @spec zero() :: t()
  def zero, do: %__MODULE__{value: 0.0}

  # Implement String.Chars protocol for easy conversion
  defimpl String.Chars do
    def to_string(%EveDmv.Core.SharedKernel.ValueObjects.IskAmount{} = isk_amount) do
      EveDmv.Core.SharedKernel.ValueObjects.IskAmount.format(isk_amount)
    end
  end

  # Implement Inspect protocol for debugging
  defimpl Inspect do
    def inspect(%EveDmv.Core.SharedKernel.ValueObjects.IskAmount{value: value}, _opts) do
      "#IskAmount<#{Float.round(value, 2)}>"
    end
  end
end
