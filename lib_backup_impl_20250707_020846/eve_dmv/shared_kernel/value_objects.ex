defmodule EveDmv.SharedKernel.ValueObjects do
  @moduledoc """
  Shared value objects used across multiple bounded contexts.

  Value objects are immutable objects that are defined by their attributes
  rather than their identity. They are shared across contexts to ensure
  consistency in domain modeling.
  """

  defmodule CharacterId do
    @moduledoc """
    Represents an EVE Online character ID.
    """
    defstruct [:value]

    @type t :: %__MODULE__{value: integer()}

    def new(value) when is_integer(value) and value > 0 do
      {:ok, %__MODULE__{value: value}}
    end

    def new(_), do: {:error, :invalid_character_id}

    def to_integer(%__MODULE__{value: value}), do: value
  end

  defmodule CorporationId do
    @moduledoc """
    Represents an EVE Online corporation ID.
    """
    defstruct [:value]

    @type t :: %__MODULE__{value: integer()}

    def new(value) when is_integer(value) and value > 0 do
      {:ok, %__MODULE__{value: value}}
    end

    def new(_), do: {:error, :invalid_corporation_id}

    def to_integer(%__MODULE__{value: value}), do: value
  end

  defmodule TypeId do
    @moduledoc """
    Represents an EVE Online item type ID.
    """
    defstruct [:value]

    @type t :: %__MODULE__{value: integer()}

    def new(value) when is_integer(value) and value > 0 do
      {:ok, %__MODULE__{value: value}}
    end

    def new(_), do: {:error, :invalid_type_id}

    def to_integer(%__MODULE__{value: value}), do: value
  end

  defmodule SolarSystemId do
    @moduledoc """
    Represents an EVE Online solar system ID.
    """
    defstruct [:value]

    @type t :: %__MODULE__{value: integer()}

    def new(value) when is_integer(value) and value > 0 do
      {:ok, %__MODULE__{value: value}}
    end

    def new(_), do: {:error, :invalid_solar_system_id}

    def to_integer(%__MODULE__{value: value}), do: value
  end

  defmodule ISKAmount do
    @moduledoc """
    Represents an ISK (EVE currency) amount with proper decimal handling.
    """
    defstruct [:value]

    @type t :: %__MODULE__{value: Decimal.t()}

    def new(value) when is_number(value) and value >= 0 do
      {:ok, %__MODULE__{value: Decimal.new(value)}}
    end

    def new(%Decimal{} = value) do
      if Decimal.compare(value, 0) in [:eq, :gt] do
        {:ok, %__MODULE__{value: value}}
      else
        {:error, :negative_isk_amount}
      end
    end

    def new(_), do: {:error, :invalid_isk_amount}

    def add(%__MODULE__{value: a}, %__MODULE__{value: b}) do
      %__MODULE__{value: Decimal.add(a, b)}
    end

    def subtract(%__MODULE__{value: a}, %__MODULE__{value: b}) do
      result = Decimal.sub(a, b)

      if Decimal.compare(result, 0) == :lt do
        {:error, :negative_result}
      else
        {:ok, %__MODULE__{value: result}}
      end
    end

    def multiply(%__MODULE__{value: a}, multiplier) when is_number(multiplier) do
      %__MODULE__{value: Decimal.mult(a, Decimal.new(multiplier))}
    end

    def to_float(%__MODULE__{value: value}) do
      Decimal.to_float(value)
    end

    def zero, do: %__MODULE__{value: Decimal.new(0)}
  end

  defmodule ThreatLevel do
    @moduledoc """
    Represents a standardized threat level across contexts.
    """
    defstruct [:level, :score]

    @type level :: :minimal | :low | :medium | :high | :critical
    @type t :: %__MODULE__{level: level(), score: float()}

    def new(score) when is_number(score) and score >= 0 and score <= 1 do
      level = score_to_level(score)
      {:ok, %__MODULE__{level: level, score: score}}
    end

    def new(_), do: {:error, :invalid_threat_score}

    defp score_to_level(score) when score >= 0.8, do: :critical
    defp score_to_level(score) when score >= 0.6, do: :high
    defp score_to_level(score) when score >= 0.4, do: :medium
    defp score_to_level(score) when score >= 0.2, do: :low
    defp score_to_level(_), do: :minimal

    def compare(%__MODULE__{score: a}, %__MODULE__{score: b}) do
      cond do
        a > b -> :gt
        a < b -> :lt
        true -> :eq
      end
    end
  end

  defmodule TimeRange do
    @moduledoc """
    Represents a time range for analysis periods.
    """
    defstruct [:start_time, :end_time]

    @type t :: %__MODULE__{start_time: DateTime.t(), end_time: DateTime.t()}

    def new(start_time, end_time) do
      if DateTime.compare(start_time, end_time) == :lt do
        {:ok, %__MODULE__{start_time: start_time, end_time: end_time}}
      else
        {:error, :invalid_time_range}
      end
    end

    def duration(%__MODULE__{start_time: start_time, end_time: end_time}, unit \\ :second) do
      DateTime.diff(end_time, start_time, unit)
    end

    def contains?(%__MODULE__{start_time: start_time, end_time: end_time}, datetime) do
      DateTime.compare(datetime, start_time) != :lt and
        DateTime.compare(datetime, end_time) != :gt
    end

    def last_days(days) when is_integer(days) and days > 0 do
      end_time = DateTime.utc_now()
      start_time = DateTime.add(end_time, -days * 24 * 3600, :second)
      new(start_time, end_time)
    end

    def last_hours(hours) when is_integer(hours) and hours > 0 do
      end_time = DateTime.utc_now()
      start_time = DateTime.add(end_time, -hours * 3600, :second)
      new(start_time, end_time)
    end
  end

  defmodule Coordinates do
    @moduledoc """
    Represents 3D coordinates in EVE Online space.
    """
    defstruct [:x, :y, :z]

    @type t :: %__MODULE__{x: float(), y: float(), z: float()}

    def new(x, y, z) when is_number(x) and is_number(y) and is_number(z) do
      {:ok, %__MODULE__{x: x * 1.0, y: y * 1.0, z: z * 1.0}}
    end

    def new(_, _, _), do: {:error, :invalid_coordinates}

    def distance(%__MODULE__{x: x1, y: y1, z: z1}, %__MODULE__{x: x2, y: y2, z: z2}) do
      dx = x2 - x1
      dy = y2 - y1
      dz = z2 - z1
      :math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    def origin, do: %__MODULE__{x: 0.0, y: 0.0, z: 0.0}
  end
end
