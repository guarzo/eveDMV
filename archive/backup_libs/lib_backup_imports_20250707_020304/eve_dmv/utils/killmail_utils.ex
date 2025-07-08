defmodule EveDmv.Utils.KillmailUtils do
  @moduledoc """
  Utility functions for safe access to killmail data structures.

  This module provides safe accessor functions to prevent KeyError exceptions
  when accessing potentially missing keys in killmail maps.
  """

  @doc """
  Safely get victim character ID from killmail data.

  Handles various killmail data formats and returns nil if not found.
  """
  @spec safe_victim_character_id(map() | nil) :: integer() | nil
  def safe_victim_character_id(nil), do: nil

  def safe_victim_character_id(killmail) when is_map(killmail) do
    get_in(killmail, ["victim", "character_id"]) ||
      Map.get(killmail, "victim_character_id") ||
      Map.get(killmail, :victim_character_id)
  end

  @doc """
  Safely get victim corporation ID from killmail data.
  """
  @spec safe_victim_corporation_id(map() | nil) :: integer() | nil
  def safe_victim_corporation_id(nil), do: nil

  def safe_victim_corporation_id(killmail) when is_map(killmail) do
    get_in(killmail, ["victim", "corporation_id"]) ||
      Map.get(killmail, "victim_corporation_id") ||
      Map.get(killmail, :victim_corporation_id)
  end

  @doc """
  Safely get victim alliance ID from killmail data.
  """
  @spec safe_victim_alliance_id(map() | nil) :: integer() | nil
  def safe_victim_alliance_id(nil), do: nil

  def safe_victim_alliance_id(killmail) when is_map(killmail) do
    get_in(killmail, ["victim", "alliance_id"]) ||
      Map.get(killmail, "victim_alliance_id") ||
      Map.get(killmail, :victim_alliance_id)
  end

  @doc """
  Safely check if a participant is a victim.

  Returns false if the key doesn't exist or if participant is nil.
  """
  @spec victim?(map() | nil) :: boolean()
  def victim?(nil), do: false

  def victim?(participant) when is_map(participant) do
    Map.get(participant, "is_victim", false) || Map.get(participant, :is_victim, false)
  end

  @doc """
  Safely check if a character is the victim in a killmail.

  Returns false if data is missing or malformed.
  """
  @spec victim_is_character?(map() | nil, integer()) :: boolean()
  def victim_is_character?(nil, _character_id), do: false

  def victim_is_character?(killmail, character_id)
      when is_map(killmail) and is_integer(character_id) do
    victim_char_id = safe_victim_character_id(killmail)
    victim_char_id == character_id
  end

  def victim_is_character?(_, _), do: false

  @doc """
  Find the victim participant in a killmail safely.

  Returns nil if no victim found or if participants list is malformed.
  """
  @spec find_victim_participant(list() | nil) :: map() | nil
  def find_victim_participant(nil), do: nil

  def find_victim_participant(participants) when is_list(participants) do
    Enum.find(participants, &victim?/1)
  end

  def find_victim_participant(_), do: nil

  @doc """
  Safely get character ID from participant data.
  """
  @spec safe_character_id(map() | nil) :: integer() | nil
  def safe_character_id(nil), do: nil

  def safe_character_id(participant) when is_map(participant) do
    Map.get(participant, "character_id") || Map.get(participant, :character_id)
  end

  @doc """
  Safely get character name from participant data.
  """
  @spec safe_character_name(map() | nil) :: String.t() | nil
  def safe_character_name(nil), do: nil

  def safe_character_name(participant) when is_map(participant) do
    Map.get(participant, "character_name") || Map.get(participant, :character_name)
  end

  @doc """
  Safely get ship type ID from participant data.
  """
  @spec safe_ship_type_id(map() | nil) :: integer() | nil
  def safe_ship_type_id(nil), do: nil

  def safe_ship_type_id(participant) when is_map(participant) do
    Map.get(participant, "ship_type_id") || Map.get(participant, :ship_type_id)
  end

  @doc """
  Safely get damage done from participant data.
  """
  @spec safe_damage_done(map() | nil) :: number() | nil
  def safe_damage_done(nil), do: nil

  def safe_damage_done(participant) when is_map(participant) do
    Map.get(participant, "damage_done") ||
      Map.get(participant, :damage_done) ||
      Map.get(participant, "damage_dealt") ||
      Map.get(participant, :damage_dealt)
  end
end
