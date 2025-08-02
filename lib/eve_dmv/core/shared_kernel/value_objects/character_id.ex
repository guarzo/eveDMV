defmodule EveDmv.Core.SharedKernel.ValueObjects.CharacterId do
  @moduledoc """
  Value object representing an EVE Online character ID.

  Character IDs are immutable identifiers for EVE characters, with specific
  validation rules and formatting requirements.
  """
  """

  defstruct [:value]

  # Character IDs must be greater than 90,000,000
  @min_character_id 90_000_000

  @type t :: %__MODULE__{value: integer()}

  @doc """
  Create a new CharacterId from an integer.
  """
  @spec new(integer()) :: {:ok, t()} | {:error, String.t()}
  def new(id) when is_integer(id) and id > @min_character_id do
    {:ok, %__MODULE__{value: id}}
  end

  def new(id) when is_integer(id) do
    {:error, "Character ID must be greater than #{@min_character_id}"}
  end

  def new(_) do
    {:error, "Character ID must be an integer"}
  end

  @doc """
  Create a new CharacterId from a string.
  """
  @spec from_string(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_string(str) when is_binary(str) do
    case Integer.parse(str) do
      {id, ""} -> new(id)
      _ -> {:error, "Invalid character ID format"}
    end
  end

  def from_string(_) do
    {:error, "Character ID must be a string"}
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
  Check if two character IDs are equal.
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{value: v1}, %__MODULE__{value: v2}), do: v1 == v2

  @doc """
  Validate a raw character ID value.
  """
  @spec valid?(integer()) :: boolean()
  def valid?(id) when is_integer(id), do: id > @min_character_id
  def valid?(_), do: false

  # Implement String.Chars protocol for easy conversion
  defimpl String.Chars do
    def to_string(%EveDmv.Core.SharedKernel.ValueObjects.CharacterId{value: value}) do
      Integer.to_string(value)
    end
  end

  # Implement Inspect protocol for debugging
  defimpl Inspect do
    def inspect(%EveDmv.Core.SharedKernel.ValueObjects.CharacterId{value: value}, _opts) do
      "#CharacterId<#{value}>"
    end
  end
end
