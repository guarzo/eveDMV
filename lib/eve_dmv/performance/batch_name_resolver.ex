defmodule EveDmv.Performance.BatchNameResolver do
  @moduledoc """
  Batch name resolution service to eliminate N+1 queries.

  This module provides efficient batch loading of names for various entities
  to prevent individual lookups during rendering.
  """

  alias EveDmv.Eve.NameResolver
  require Logger

  @doc """
  Preloads all names for a list of killmails.
  This should be called before rendering killmail lists to prevent N+1 queries.
  """
  def preload_killmail_names(killmails) when is_list(killmails) do
    # Extract all unique IDs
    {character_ids, corp_ids, alliance_ids, ship_ids, system_ids} =
      extract_killmail_ids(killmails)

    # Batch load all names
    batch_load_names(character_ids, corp_ids, alliance_ids, ship_ids, system_ids)

    # Return original killmails (names are now cached)
    killmails
  end

  @doc """
  Preloads names for battle participants.
  """
  def preload_battle_names(battle) when is_map(battle) do
    # Extract all unique IDs from battle timeline
    {character_ids, corp_ids, alliance_ids, ship_ids, system_ids} =
      extract_battle_ids(battle)

    # Batch load all names
    batch_load_names(character_ids, corp_ids, alliance_ids, ship_ids, system_ids)

    # Return original battle (names are now cached)
    battle
  end

  @doc """
  Preloads names for a list of participants.
  """
  def preload_participant_names(participants) when is_list(participants) do
    # Extract unique IDs
    character_ids =
      participants |> Enum.map(& &1.character_id) |> Enum.filter(& &1) |> Enum.uniq()

    corp_ids = participants |> Enum.map(& &1.corporation_id) |> Enum.filter(& &1) |> Enum.uniq()
    alliance_ids = participants |> Enum.map(& &1.alliance_id) |> Enum.filter(& &1) |> Enum.uniq()
    ship_ids = participants |> Enum.map(& &1.ship_type_id) |> Enum.filter(& &1) |> Enum.uniq()

    # Batch load names
    batch_load_names(character_ids, corp_ids, alliance_ids, ship_ids, [])

    participants
  end

  @doc """
  Preloads names for surveillance profiles.
  """
  def preload_profile_names(profiles) when is_list(profiles) do
    # Extract unique IDs based on profile types
    {character_ids, corp_ids, alliance_ids, ship_ids, system_ids} =
      extract_profile_ids(profiles)

    # Batch load names
    batch_load_names(character_ids, corp_ids, alliance_ids, ship_ids, system_ids)

    profiles
  end

  # Private functions

  defp extract_killmail_ids(killmails) do
    Enum.reduce(killmails, {[], [], [], [], []}, fn killmail,
                                                    {chars, corps, alliances, ships, systems} ->
      # Extract from victim
      victim = Map.get(killmail, :victim, %{})
      char_ids = if victim[:character_id], do: [victim.character_id | chars], else: chars
      corp_ids = if victim[:corporation_id], do: [victim.corporation_id | corps], else: corps

      alliance_ids =
        if victim[:alliance_id], do: [victim.alliance_id | alliances], else: alliances

      ship_ids = if victim[:ship_type_id], do: [victim.ship_type_id | ships], else: ships

      # Extract from attackers
      attackers = Map.get(killmail, :attackers, [])

      {attacker_chars, attacker_corps, attacker_alliances, attacker_ships} =
        extract_attacker_ids(attackers)

      # Add system ID
      system_ids =
        if killmail[:solar_system_id], do: [killmail.solar_system_id | systems], else: systems

      {
        char_ids ++ attacker_chars,
        corp_ids ++ attacker_corps,
        alliance_ids ++ attacker_alliances,
        ship_ids ++ attacker_ships,
        system_ids
      }
    end)
    |> then(fn {chars, corps, alliances, ships, systems} ->
      {Enum.uniq(chars), Enum.uniq(corps), Enum.uniq(alliances), Enum.uniq(ships),
       Enum.uniq(systems)}
    end)
  end

  defp extract_attacker_ids(attackers) do
    Enum.reduce(attackers, {[], [], [], []}, fn attacker, {chars, corps, alliances, ships} ->
      char_ids = if attacker[:character_id], do: [attacker.character_id | chars], else: chars
      corp_ids = if attacker[:corporation_id], do: [attacker.corporation_id | corps], else: corps

      alliance_ids =
        if attacker[:alliance_id], do: [attacker.alliance_id | alliances], else: alliances

      ship_ids = if attacker[:ship_type_id], do: [attacker.ship_type_id | ships], else: ships

      {char_ids, corp_ids, alliance_ids, ship_ids}
    end)
  end

  defp extract_battle_ids(battle) do
    events = get_in(battle, [:timeline, :events]) || []

    Enum.reduce(events, {[], [], [], [], []}, fn event,
                                                 {chars, corps, alliances, ships, systems} ->
      # Extract from victim
      victim = Map.get(event, :victim, %{})
      char_ids = if victim[:character_id], do: [victim.character_id | chars], else: chars
      corp_ids = if victim[:corporation_id], do: [victim.corporation_id | corps], else: corps

      alliance_ids =
        if victim[:alliance_id], do: [victim.alliance_id | alliances], else: alliances

      ship_ids = if victim[:ship_type_id], do: [victim.ship_type_id | ships], else: ships

      # Extract from attackers
      attackers = Map.get(event, :attackers, [])

      {attacker_chars, attacker_corps, attacker_alliances, attacker_ships} =
        extract_attacker_ids(attackers)

      # Add system ID
      system_ids =
        if event[:solar_system_id], do: [event.solar_system_id | systems], else: systems

      {
        char_ids ++ attacker_chars,
        corp_ids ++ attacker_corps,
        alliance_ids ++ attacker_alliances,
        ship_ids ++ attacker_ships,
        system_ids
      }
    end)
    |> then(fn {chars, corps, alliances, ships, systems} ->
      {Enum.uniq(chars), Enum.uniq(corps), Enum.uniq(alliances), Enum.uniq(ships),
       Enum.uniq(systems)}
    end)
  end

  defp extract_profile_ids(profiles) do
    Enum.reduce(profiles, {[], [], [], [], []}, fn profile,
                                                   {chars, corps, alliances, ships, systems} ->
      case profile.type do
        :character ->
          {[profile.entity_id | chars], corps, alliances, ships, systems}

        :corporation ->
          {chars, [profile.entity_id | corps], alliances, ships, systems}

        :alliance ->
          {chars, corps, [profile.entity_id | alliances], ships, systems}

        :ship ->
          {chars, corps, alliances, [profile.entity_id | ships], systems}

        :solar_system ->
          {chars, corps, alliances, ships, [profile.entity_id | systems]}

        _ ->
          {chars, corps, alliances, ships, systems}
      end
    end)
    |> then(fn {chars, corps, alliances, ships, systems} ->
      {Enum.uniq(chars), Enum.uniq(corps), Enum.uniq(alliances), Enum.uniq(ships),
       Enum.uniq(systems)}
    end)
  end

  defp batch_load_names(character_ids, corp_ids, alliance_ids, ship_ids, system_ids) do
    # Use NameResolver's batch methods to load all names at once
    # These will be cached for subsequent individual lookups

    start_time = System.monotonic_time(:millisecond)

    tasks =
      [
        if(length(character_ids) > 0,
          do: Task.async(fn -> NameResolver.character_names(character_ids) end)
        ),
        if(length(corp_ids) > 0,
          do: Task.async(fn -> NameResolver.corporation_names(corp_ids) end)
        ),
        if(length(alliance_ids) > 0,
          do: Task.async(fn -> NameResolver.alliance_names(alliance_ids) end)
        ),
        if(length(ship_ids) > 0, do: Task.async(fn -> NameResolver.ship_names(ship_ids) end)),
        if(length(system_ids) > 0,
          do: Task.async(fn -> NameResolver.system_names(system_ids) end)
        )
      ]
      |> Enum.filter(& &1)

    # Await all tasks
    Task.await_many(tasks, 30_000)

    elapsed = System.monotonic_time(:millisecond) - start_time

    Logger.debug("""
    Batch loaded names in #{elapsed}ms:
    - Characters: #{length(character_ids)}
    - Corporations: #{length(corp_ids)}
    - Alliances: #{length(alliance_ids)}
    - Ships: #{length(ship_ids)}
    - Systems: #{length(system_ids)}
    """)

    :ok
  end
end
