defmodule EveDmv.Core.SharedKernel.ValueObjects.SystemId do
  @moduledoc """
  Value object representing an EVE Online solar system ID.

  System IDs are immutable identifiers for EVE solar systems, with specific
  validation rules based on the EVE static data export.
  """

  # Solar system IDs are between 30,000,000 and 32,000,000
  @min_system_id 30_000_000
  @max_system_id 32_000_000

  @type t :: %__MODULE__{value: integer()}

  defstruct [:value]

  @doc """
  Create a new SystemId from an integer.
  """
  @spec new(integer()) :: {:ok, t()} | {:error, String.t()}
  def new(id) when is_integer(id) and id >= @min_system_id and id <= @max_system_id do
    {:ok, %__MODULE__{value: id}}
  end

  def new(id) when is_integer(id) do
    {:error, "System ID must be between #{@min_system_id} and #{@max_system_id}"}
  end

  def new(_) do
    {:error, "System ID must be an integer"}
  end

  @doc """
  Create a new SystemId from a string.
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string(str) when is_binary(str) do
    case Integer.parse(str) do
      {id, ""} -> new(id)
      _ -> {:error, "Invalid system ID format"}
    end
  end

  def from_string(_) do
    {:error, "System ID must be a string"}
  end

  @doc """
  Get the raw integer value.
  """
  @spec to_integer(t()) :: integer()
  def to_integer(%__MODULE__{value: value}), do: value

  @doc """
  Convert to string representation.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{value: value}), do: Integer.to_string(value)

  @doc """
  Check if two system IDs are equal.
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{value: v1}, %__MODULE__{value: v2}), do: v1 == v2

  @doc """
  Validate a raw system ID value.
  """
  @spec valid?(integer()) :: boolean()
  def valid?(id) when is_integer(id), do: id >= @min_system_id and id <= @max_system_id
  def valid?(_), do: false

  @doc """
  Check if system is in known space (K-space).
  """
  @spec known_space?(t()) :: boolean()
  def known_space?(%__MODULE__{value: id}) do
    # High-sec: 30,000,000 - 30,004,999
    # Low-sec: 30,005,000 - 30,099,999
    # Null-sec: 30,100,000 - 30,999,999
    id >= 30_000_000 and id <= 30_999_999
  end

  @doc """
  Check if system is in wormhole space (J-space).
  """
  @spec wormhole_space?(t()) :: boolean()
  def wormhole_space?(%__MODULE__{value: id}) do
    # Wormhole systems: 31,000,000 - 31,999,999
    id >= 31_000_000 and id <= 31_999_999
  end

  @doc """
  Check if system is in Abyssal space.
  """
  @spec abyssal_space?(t()) :: boolean()
  def abyssal_space?(%__MODULE__{value: id}) do
    # Abyssal systems: 32,000,000+
    id >= 32_000_000
  end

  @doc """
  Get the security classification of the system.
  """
  @spec security_class(t()) :: :highsec | :lowsec | :nullsec | :wormhole | :abyssal | :unknown
  def security_class(%__MODULE__{value: id}) do
    cond do
      id >= 30_000_000 and id <= 30_004_999 -> :highsec
      id >= 30_005_000 and id <= 30_099_999 -> :lowsec
      id >= 30_100_000 and id <= 30_999_999 -> :nullsec
      id >= 31_000_000 and id <= 31_999_999 -> :wormhole
      id >= 32_000_000 -> :abyssal
      true -> :unknown
    end
  end

  # Implement String.Chars protocol for easy conversion
  defimpl String.Chars do
    def to_string(%EveDmv.Core.SharedKernel.ValueObjects.SystemId{value: value}) do
      Integer.to_string(value)
    end
  end

  # Implement Inspect protocol for debugging
  defimpl Inspect do
    def inspect(%EveDmv.Core.SharedKernel.ValueObjects.SystemId{value: value}, _opts) do
      "#SystemId<#{value}>"
    end
  end
end
