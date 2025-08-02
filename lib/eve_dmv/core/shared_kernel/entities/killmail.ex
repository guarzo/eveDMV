defmodule EveDmv.Core.SharedKernel.Entities.Killmail do
  @moduledoc """
  Shared entity representing a killmail across all bounded contexts.

  This entity provides a consistent interface for killmail data while
  allowing different contexts to extend it with their specific needs.
  """
  """

  alias EveDmv.Core.SharedKernel.ValueObjects.CharacterId
  alias EveDmv.Core.SharedKernel.ValueObjects.IskAmount
  alias EveDmv.Core.SharedKernel.ValueObjects.SystemId

  defstruct [
    :killmail_id,
    :killmail_time,
    :system_id,
    :victim,
    :attackers,
    :total_value,
    :metadata
  ]

  @type victim :: %{
          character_id: CharacterId.t() | nil,
          corporation_id: integer(),
          alliance_id: integer() | nil,
          ship_type_id: integer(),
          damage_taken: integer(),
          position: %{x: float(), y: float(), z: float()} | nil
        }

  @type attacker :: %{
          character_id: CharacterId.t() | nil,
          corporation_id: integer(),
          alliance_id: integer() | nil,
          ship_type_id: integer() | nil,
          weapon_type_id: integer() | nil,
          damage_done: integer(),
          final_blow: boolean(),
          security_status: float()
        }

  @type t :: %__MODULE__{
          killmail_id: integer(),
          killmail_time: DateTime.t(),
          system_id: SystemId.t(),
          victim: victim(),
          attackers: [attacker()],
          total_value: IskAmount.t(),
          metadata: map()
        }

  @doc """
  Create a new killmail entity from raw data.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(data) when is_map(data) do
    with {:ok, killmail_id} <- validate_killmail_id(data),
         {:ok, killmail_time} <- validate_killmail_time(data),
         {:ok, system_id} <- validate_system_id(data),
         {:ok, victim} <- validate_victim(data),
         {:ok, attackers} <- validate_attackers(data),
         {:ok, total_value} <- validate_total_value(data) do
      killmail = %__MODULE__{
        killmail_id: killmail_id,
        killmail_time: killmail_time,
        system_id: system_id,
        victim: victim,
        attackers: attackers,
        total_value: total_value,
        metadata: Map.get(data, :metadata, %{})
      }

      {:ok, killmail}
    end
  end

  def new(_), do: {:error, "Killmail data must be a map"}

  @doc """
  Get the final blow attacker.
  """
  @spec final_blow_attacker(t()) :: attacker() | nil
  def final_blow_attacker(%__MODULE__{attackers: attackers}) do
    Enum.find(attackers, & &1.final_blow)
  end

  @doc """
  Get all involved character IDs.
  """
  @spec involved_character_ids(t()) :: [CharacterId.t()]
  def involved_character_ids(%__MODULE__{victim: victim, attackers: attackers}) do
    victim_chars = if victim.character_id, do: [victim.character_id], else: []

    attacker_chars =
      attackers
      |> Enum.map(& &1.character_id)
      |> Enum.reject(&is_nil/1)

    (victim_chars ++ attacker_chars) |> Enum.uniq()
  end

  @doc """
  Get all involved corporation IDs.
  """
  @spec involved_corporation_ids(t()) :: [integer()]
  def involved_corporation_ids(%__MODULE__{victim: victim, attackers: attackers}) do
    victim_corps = [victim.corporation_id]
    attacker_corps = Enum.map(attackers, & &1.corporation_id)

    (victim_corps ++ attacker_corps) |> Enum.uniq()
  end

  @doc """
  Get all involved alliance IDs.
  """
  @spec involved_alliance_ids(t()) :: [integer()]
  def involved_alliance_ids(%__MODULE__{victim: victim, attackers: attackers}) do
    victim_alliances = if victim.alliance_id, do: [victim.alliance_id], else: []

    attacker_alliances =
      attackers
      |> Enum.map(& &1.alliance_id)
      |> Enum.reject(&is_nil/1)

    (victim_alliances ++ attacker_alliances) |> Enum.uniq()
  end

  @doc """
  Check if killmail is a solo kill.
  """
  @spec solo_kill?(t()) :: boolean()
  def solo_kill?(%__MODULE__{attackers: [_single_attacker]}), do: true
  def solo_kill?(%__MODULE__{}), do: false

  @doc """
  Check if killmail represents a high-value kill.
  """
  @spec high_value_kill?(t(), IskAmount.t()) :: boolean()
  def high_value_kill?(%__MODULE__{total_value: total_value}, threshold) do
    IskAmount.compare(total_value, threshold) != :lt
  end

  @doc """
  Get total damage dealt.
  """
  @spec total_damage(t()) :: integer()
  def total_damage(%__MODULE__{victim: victim}) do
    victim.damage_taken
  end

  @doc """
  Get attacker count.
  """
  @spec attacker_count(t()) :: integer()
  def attacker_count(%__MODULE__{attackers: attackers}) do
    length(attackers)
  end

  @doc """
  Check if killmail occurred in a specific system.
  """
  @spec occurred_in_system?(t(), SystemId.t()) :: boolean()
  def occurred_in_system?(%__MODULE__{system_id: system_id}, target_system) do
    SystemId.equal?(system_id, target_system)
  end

  @doc """
  Check if killmail occurred in known space.
  """
  @spec known_space?(t()) :: boolean()
  def known_space?(%__MODULE__{system_id: system_id}) do
    SystemId.known_space?(system_id)
  end

  @doc """
  Check if killmail occurred in wormhole space.
  """
  @spec wormhole_space?(t()) :: boolean()
  def wormhole_space?(%__MODULE__{system_id: system_id}) do
    SystemId.wormhole_space?(system_id)
  end

  @doc """
  Get security classification of the killmail location.
  """
  @spec security_class(t()) :: atom()
  def security_class(%__MODULE__{system_id: system_id}) do
    SystemId.security_class(system_id)
  end

  # Private validation functions

  defp validate_killmail_id(%{killmail_id: id}) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  defp validate_killmail_id(_), do: {:error, "Invalid killmail ID"}

  defp validate_killmail_time(%{killmail_time: %DateTime{} = time}) do
    {:ok, time}
  end

  defp validate_killmail_time(%{killmail_time: time_str}) when is_binary(time_str) do
    case DateTime.from_iso8601(time_str) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> {:error, "Invalid killmail time format"}
    end
  end

  defp validate_killmail_time(_), do: {:error, "Missing or invalid killmail time"}

  defp validate_system_id(%{system_id: system_id}) when is_integer(system_id) do
    SystemId.new(system_id)
  end

  defp validate_system_id(_), do: {:error, "Invalid system ID"}

  defp validate_victim(%{victim: victim}) when is_map(victim) do
    with {:ok, character_id} <- validate_optional_character_id(victim),
         {:ok, corporation_id} <- validate_corporation_id(victim),
         {:ok, alliance_id} <- validate_optional_alliance_id(victim),
         {:ok, ship_type_id} <- validate_ship_type_id(victim),
         {:ok, damage_taken} <- validate_damage_taken(victim) do
      victim_entity = %{
        character_id: character_id,
        corporation_id: corporation_id,
        alliance_id: alliance_id,
        ship_type_id: ship_type_id,
        damage_taken: damage_taken,
        position: Map.get(victim, :position)
      }

      {:ok, victim_entity}
    end
  end

  defp validate_victim(_), do: {:error, "Invalid victim data"}

  defp validate_attackers(%{attackers: attackers}) when is_list(attackers) do
    validated_attackers =
      Enum.map(attackers, fn attacker ->
        with {:ok, character_id} <- validate_optional_character_id(attacker),
             {:ok, corporation_id} <- validate_corporation_id(attacker),
             {:ok, alliance_id} <- validate_optional_alliance_id(attacker) do
          %{
            character_id: character_id,
            corporation_id: corporation_id,
            alliance_id: alliance_id,
            ship_type_id: Map.get(attacker, :ship_type_id),
            weapon_type_id: Map.get(attacker, :weapon_type_id),
            damage_done: Map.get(attacker, :damage_done, 0),
            final_blow: Map.get(attacker, :final_blow, false),
            security_status: Map.get(attacker, :security_status, 0.0)
          }
        else
          _ -> nil
        end
      end)

    if Enum.any?(validated_attackers, &is_nil/1) do
      {:error, "Invalid attacker data"}
    else
      {:ok, validated_attackers}
    end
  end

  defp validate_attackers(_), do: {:error, "Invalid attackers data"}

  defp validate_total_value(%{total_value: value}) when is_number(value) do
    IskAmount.new(value)
  end

  defp validate_total_value(_) do
    {:ok, IskAmount.zero()}
  end

  defp validate_optional_character_id(%{character_id: nil}), do: {:ok, nil}

  defp validate_optional_character_id(%{character_id: id}) when is_integer(id) do
    case CharacterId.new(id) do
      {:ok, char_id} -> {:ok, char_id}
      # Allow invalid character IDs to be nil
      _ -> {:ok, nil}
    end
  end

  defp validate_optional_character_id(_), do: {:ok, nil}

  defp validate_corporation_id(%{corporation_id: id}) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  defp validate_corporation_id(_), do: {:error, "Invalid corporation ID"}

  defp validate_optional_alliance_id(%{alliance_id: nil}), do: {:ok, nil}

  defp validate_optional_alliance_id(%{alliance_id: id}) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  defp validate_optional_alliance_id(_), do: {:ok, nil}

  defp validate_ship_type_id(%{ship_type_id: id}) when is_integer(id) and id > 0 do
    {:ok, id}
  end

  defp validate_ship_type_id(_), do: {:error, "Invalid ship type ID"}

  defp validate_damage_taken(%{damage_taken: damage}) when is_integer(damage) and damage >= 0 do
    {:ok, damage}
  end

  defp validate_damage_taken(_), do: {:error, "Invalid damage taken"}
end
