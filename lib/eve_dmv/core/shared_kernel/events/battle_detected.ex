defmodule EveDmv.Core.SharedKernel.Events.BattleDetected do
  @moduledoc """
  Domain event published when a battle has been detected and analyzed.

  This event is published by the battle detection engine and consumed
  by various contexts for further analysis and notification.
  """

  alias EveDmv.Core.SharedKernel.ValueObjects.IskAmount
  alias EveDmv.Core.SharedKernel.ValueObjects.SystemId
  alias EveDmv.Core.Utils.DateTimeUtils

  defstruct [
    :event_id,
    :occurred_at,
    :battle_id,
    :system_id,
    :battle_start_time,
    :battle_end_time,
    :duration_seconds,
    :participant_count,
    :corporation_count,
    :alliance_count,
    :total_kills,
    :total_value_destroyed,
    :is_major_battle,
    :battle_type,
    :primary_ship_classes,
    :metadata
  ]

  @type battle_type ::
          :skirmish | :fleet_fight | :capital_engagement | :structure_bash | :roam | :unknown

  @type t :: %__MODULE__{
          event_id: String.t(),
          occurred_at: DateTime.t(),
          battle_id: String.t(),
          system_id: SystemId.t(),
          battle_start_time: DateTime.t(),
          battle_end_time: DateTime.t() | nil,
          duration_seconds: integer(),
          participant_count: integer(),
          corporation_count: integer(),
          alliance_count: integer(),
          total_kills: integer(),
          total_value_destroyed: IskAmount.t(),
          is_major_battle: boolean(),
          battle_type: battle_type(),
          primary_ship_classes: [String.t()],
          metadata: map()
        }

  @doc """
  Create a new BattleDetected event.
  """
  @spec new(map()) :: t()
  def new(data) when is_map(data) do
    %__MODULE__{
      event_id: generate_event_id(),
      occurred_at: DateTime.utc_now(),
      battle_id: Map.fetch!(data, :battle_id),
      system_id: Map.fetch!(data, :system_id),
      battle_start_time: Map.fetch!(data, :battle_start_time),
      battle_end_time: Map.get(data, :battle_end_time),
      duration_seconds: Map.get(data, :duration_seconds, 0),
      participant_count: Map.get(data, :participant_count, 0),
      corporation_count: Map.get(data, :corporation_count, 0),
      alliance_count: Map.get(data, :alliance_count, 0),
      total_kills: Map.get(data, :total_kills, 0),
      total_value_destroyed: Map.get(data, :total_value_destroyed, IskAmount.zero()),
      is_major_battle: Map.get(data, :is_major_battle, false),
      battle_type: Map.get(data, :battle_type, :unknown),
      primary_ship_classes: Map.get(data, :primary_ship_classes, []),
      metadata: Map.get(data, :metadata, %{})
    }
  end

  @doc """
  Check if the battle is still ongoing.
  """
  @spec ongoing?(t()) :: boolean()
  def ongoing?(%__MODULE__{battle_end_time: nil}), do: true
  def ongoing?(%__MODULE__{}), do: false

  @doc """
  Check if the battle occurred in a specific system.
  """
  @spec occurred_in_system?(t(), SystemId.t()) :: boolean()
  def occurred_in_system?(%__MODULE__{system_id: system_id}, target_system) do
    SystemId.equal?(system_id, target_system)
  end

  @doc """
  Check if the battle is a major engagement.
  """
  @spec major_battle?(t()) :: boolean()
  def major_battle?(%__MODULE__{is_major_battle: is_major}), do: is_major

  @doc """
  Check if the battle is high-value.
  """
  @spec high_value_battle?(t(), IskAmount.t()) :: boolean()
  def high_value_battle?(%__MODULE__{total_value_destroyed: total_value}, threshold) do
    IskAmount.compare(total_value, threshold) != :lt
  end

  @doc """
  Get the battle's security classification.
  """
  @spec security_class(t()) :: atom()
  def security_class(%__MODULE__{system_id: system_id}) do
    SystemId.security_class(system_id)
  end

  @doc """
  Check if the battle occurred in known space.
  """
  @spec known_space?(t()) :: boolean()
  def known_space?(%__MODULE__{system_id: system_id}) do
    SystemId.known_space?(system_id)
  end

  @doc """
  Check if the battle occurred in wormhole space.
  """
  @spec wormhole_space?(t()) :: boolean()
  def wormhole_space?(%__MODULE__{system_id: system_id}) do
    SystemId.wormhole_space?(system_id)
  end

  @doc """
  Get formatted total value destroyed.
  """
  @spec formatted_value(t()) :: String.t()
  def formatted_value(%__MODULE__{total_value_destroyed: total_value}) do
    IskAmount.format(total_value)
  end

  @doc """
  Get formatted duration.
  """
  @spec formatted_duration(t()) :: String.t()
  def formatted_duration(%__MODULE__{duration_seconds: seconds}) do
    cond do
      seconds >= 3600 ->
        hours = div(seconds, 3600)
        minutes = div(rem(seconds, 3600), 60)
        "#{hours}h #{minutes}m"

      seconds >= 60 ->
        minutes = div(seconds, 60)
        secs = rem(seconds, 60)
        "#{minutes}m #{secs}s"

      true ->
        "#{seconds}s"
    end
  end

  @doc """
  Get average value per kill.
  """
  @spec average_kill_value(t()) :: IskAmount.t()
  def average_kill_value(%__MODULE__{total_kills: 0}), do: IskAmount.zero()

  def average_kill_value(%__MODULE__{total_value_destroyed: total_value, total_kills: kills}) do
    IskAmount.divide(total_value, kills)
  end

  @doc """
  Get kill rate (kills per minute).
  """
  @spec kill_rate(t()) :: float()
  def kill_rate(%__MODULE__{duration_seconds: 0}), do: 0.0

  def kill_rate(%__MODULE__{total_kills: kills, duration_seconds: seconds}) do
    kills / (seconds / 60.0)
  end

  @doc """
  Check if the battle involves capitals.
  """
  @spec involves_capitals?(t()) :: boolean()
  def involves_capitals?(%__MODULE__{primary_ship_classes: ship_classes}) do
    capital_classes = ["Dreadnought", "Carrier", "Supercarrier", "Titan", "Force Auxiliary"]
    Enum.any?(ship_classes, &(&1 in capital_classes))
  end

  @doc """
  Check if the battle involves supercapitals.
  """
  @spec involves_supercapitals?(t()) :: boolean()
  def involves_supercapitals?(%__MODULE__{primary_ship_classes: ship_classes}) do
    super_classes = ["Supercarrier", "Titan"]
    Enum.any?(ship_classes, &(&1 in super_classes))
  end

  @doc """
  Get battle intensity score (0.0 - 1.0).
  """
  @spec intensity_score(t()) :: float()
  def intensity_score(%__MODULE__{} = battle) do
    # Base score from participant count (0.0 - 0.4)
    participant_score = min(battle.participant_count / 500.0, 0.4)

    # Value score (0.0 - 0.3)
    value_score = min(IskAmount.to_float(battle.total_value_destroyed) / 50_000_000_000.0, 0.3)

    # Duration penalty (longer battles are less intense)
    duration_penalty = if battle.duration_seconds > 7200, do: 0.1, else: 0.0

    # Capital bonus (0.0 - 0.2)
    capital_bonus =
      cond do
        involves_supercapitals?(battle) -> 0.2
        involves_capitals?(battle) -> 0.1
        true -> 0.0
      end

    # Major battle bonus
    major_bonus = if battle.is_major_battle, do: 0.1, else: 0.0

    max(
      0.0,
      min(1.0, participant_score + value_score + capital_bonus + major_bonus - duration_penalty)
    )
  end

  @doc """
  Get event age in seconds.
  """
  @spec age_seconds(t()) :: integer()
  def age_seconds(%__MODULE__{occurred_at: occurred_at}) do
    DateTimeUtils.diff(DateTime.utc_now(), occurred_at, :second)
  end

  @doc """
  Convert event to a map for serialization.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = event) do
    %{
      event_type: :battle_detected,
      event_id: event.event_id,
      occurred_at: event.occurred_at,
      battle_id: event.battle_id,
      system_id: SystemId.to_integer(event.system_id),
      battle_start_time: event.battle_start_time,
      battle_end_time: event.battle_end_time,
      duration_seconds: event.duration_seconds,
      participant_count: event.participant_count,
      corporation_count: event.corporation_count,
      alliance_count: event.alliance_count,
      total_kills: event.total_kills,
      total_value_destroyed: IskAmount.to_float(event.total_value_destroyed),
      is_major_battle: event.is_major_battle,
      battle_type: event.battle_type,
      primary_ship_classes: event.primary_ship_classes,
      metadata: event.metadata
    }
  end

  # Private functions

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
