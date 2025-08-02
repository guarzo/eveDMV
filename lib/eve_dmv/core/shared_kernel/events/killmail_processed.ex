defmodule EveDmv.Core.SharedKernel.Events.KillmailProcessed do
  @moduledoc """
  Domain event published when a killmail has been processed and is available
  for analysis by other bounded contexts.

  This event is published by the killmail ingestion pipeline and consumed
  by various analysis engines across the system.
  """
  """

  alias EveDmv.Core.SharedKernel.Entities.Killmail
  alias EveDmv.Core.SharedKernel.ValueObjects.CharacterId
  alias EveDmv.Core.SharedKernel.ValueObjects.IskAmount
  alias EveDmv.Core.SharedKernel.ValueObjects.SystemId
  alias EveDmv.Core.Utils.DateTimeUtils

  defstruct [
    :event_id,
    :occurred_at,
    :killmail_id,
    :killmail_time,
    :system_id,
    :victim_character_id,
    :victim_corporation_id,
    :victim_alliance_id,
    :victim_ship_type_id,
    :attacker_count,
    :final_blow_character_id,
    :final_blow_corporation_id,
    :total_value,
    :is_solo_kill,
    :security_class,
    :metadata
  ]

  @type t :: %__MODULE__{
          event_id: String.t(),
          occurred_at: DateTime.t(),
          killmail_id: integer(),
          killmail_time: DateTime.t(),
          system_id: SystemId.t(),
          victim_character_id: CharacterId.t() | nil,
          victim_corporation_id: integer(),
          victim_alliance_id: integer() | nil,
          victim_ship_type_id: integer(),
          attacker_count: integer(),
          final_blow_character_id: CharacterId.t() | nil,
          final_blow_corporation_id: integer() | nil,
          total_value: IskAmount.t(),
          is_solo_kill: boolean(),
          security_class: atom(),
          metadata: map()
        }

  @doc """
  Create a new KillmailProcessed event from killmail data.
  """
  @spec new(map()) :: t()
  def new(data) when is_map(data) do
    %__MODULE__{
      event_id: generate_event_id(),
      occurred_at: DateTimeUtils.utc_now(),
      killmail_id: Map.fetch!(data, :killmail_id),
      killmail_time: Map.fetch!(data, :killmail_time),
      system_id: Map.fetch!(data, :system_id),
      victim_character_id: Map.get(data, :victim_character_id),
      victim_corporation_id: Map.fetch!(data, :victim_corporation_id),
      victim_alliance_id: Map.get(data, :victim_alliance_id),
      victim_ship_type_id: Map.fetch!(data, :victim_ship_type_id),
      attacker_count: Map.fetch!(data, :attacker_count),
      final_blow_character_id: Map.get(data, :final_blow_character_id),
      final_blow_corporation_id: Map.get(data, :final_blow_corporation_id),
      total_value: Map.get(data, :total_value, IskAmount.zero()),
      is_solo_kill: Map.get(data, :is_solo_kill, false),
      security_class: Map.get(data, :security_class, :unknown),
      metadata: Map.get(data, :metadata, %{})
    }
  end

  @doc """
  Create event from a killmail entity.
  """
  @spec from_killmail(Killmail.t()) :: t()
  def from_killmail(killmail) do
    final_blow = Killmail.final_blow_attacker(killmail)

    %__MODULE__{
      event_id: generate_event_id(),
      occurred_at: DateTimeUtils.utc_now(),
      killmail_id: killmail.killmail_id,
      killmail_time: killmail.killmail_time,
      system_id: killmail.system_id,
      victim_character_id: killmail.victim.character_id,
      victim_corporation_id: killmail.victim.corporation_id,
      victim_alliance_id: killmail.victim.alliance_id,
      victim_ship_type_id: killmail.victim.ship_type_id,
      attacker_count: Killmail.attacker_count(killmail),
      final_blow_character_id: final_blow && final_blow.character_id,
      final_blow_corporation_id: final_blow && final_blow.corporation_id,
      total_value: killmail.total_value,
      is_solo_kill: Killmail.solo_kill?(killmail),
      security_class: Killmail.security_class(killmail),
      metadata: killmail.metadata
    }
  end

  @doc """
  Check if the killmail is a high-value kill.
  """
  @spec high_value_kill?(t(), IskAmount.t()) :: boolean()
  def high_value_kill?(%__MODULE__{total_value: total_value}, threshold) do
    IskAmount.compare(total_value, threshold) != :lt
  end

  @doc """
  Check if the killmail occurred in a specific system.
  """
  @spec occurred_in_system?(t(), SystemId.t()) :: boolean()
  def occurred_in_system?(%__MODULE__{system_id: system_id}, target_system) do
    SystemId.equal?(system_id, target_system)
  end

  @doc """
  Check if the killmail occurred in known space.
  """
  @spec known_space?(t()) :: boolean()
  def known_space?(%__MODULE__{security_class: security_class}) do
    security_class in [:highsec, :lowsec, :nullsec]
  end

  @doc """
  Check if the killmail occurred in wormhole space.
  """
  @spec wormhole_space?(t()) :: boolean()
  def wormhole_space?(%__MODULE__{security_class: security_class}) do
    security_class == :wormhole
  end

  @doc """
  Check if a character was involved in the killmail.
  """
  @spec character_involved?(t(), CharacterId.t()) :: boolean()
  def character_involved?(%__MODULE__{} = event, character_id) do
    CharacterId.equal?(event.victim_character_id, character_id) or
      CharacterId.equal?(event.final_blow_character_id, character_id)
  end

  @doc """
  Check if a corporation was involved in the killmail.
  """
  @spec corporation_involved?(t(), integer()) :: boolean()
  def corporation_involved?(%__MODULE__{} = event, corporation_id) do
    event.victim_corporation_id == corporation_id or
      event.final_blow_corporation_id == corporation_id
  end

  @doc """
  Check if an alliance was involved in the killmail.
  """
  @spec alliance_involved?(t(), integer()) :: boolean()
  def alliance_involved?(%__MODULE__{} = event, alliance_id) do
    event.victim_alliance_id == alliance_id
  end

  @doc """
  Get formatted ISK value.
  """
  @spec formatted_value(t()) :: String.t()
  def formatted_value(%__MODULE__{total_value: total_value}) do
    IskAmount.format(total_value)
  end

  @doc """
  Get event age in seconds.
  """
  @spec age_seconds(t()) :: integer()
  def age_seconds(%__MODULE__{occurred_at: occurred_at}) do
    DateTimeUtils.diff(DateTimeUtils.utc_now(), occurred_at, :second)
  end

  @doc """
  Convert event to a map for serialization.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = event) do
    %{
      event_type: :killmail_processed,
      event_id: event.event_id,
      occurred_at: event.occurred_at,
      killmail_id: event.killmail_id,
      killmail_time: event.killmail_time,
      system_id: SystemId.to_integer(event.system_id),
      victim_character_id:
        event.victim_character_id && CharacterId.to_integer(event.victim_character_id),
      victim_corporation_id: event.victim_corporation_id,
      victim_alliance_id: event.victim_alliance_id,
      victim_ship_type_id: event.victim_ship_type_id,
      attacker_count: event.attacker_count,
      final_blow_character_id:
        event.final_blow_character_id && CharacterId.to_integer(event.final_blow_character_id),
      final_blow_corporation_id: event.final_blow_corporation_id,
      total_value: IskAmount.to_float(event.total_value),
      is_solo_kill: event.is_solo_kill,
      security_class: event.security_class,
      metadata: event.metadata
    }
  end

  # Private functions

  defp generate_event_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
