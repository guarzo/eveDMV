defmodule EveDmv.Performance.BatchNameResolver do
  @moduledoc """
  Batch name resolution service to eliminate N+1 queries.

  This module provides efficient batch loading of names for various entities
  to prevent individual lookups during rendering.
  """

  alias EveDmv.Eve.NameResolver
  alias EveDmv.Eve.NameResolver.CacheManager
  require Logger

  @doc """
  Preloads all names for a list of killmails.
  This should be called before rendering killmail lists to prevent N+1 queries.
  """
  def preload_killmail_names(killmails) when is_list(killmails) do
    # Extract all names and IDs
    {existing_names, missing_ids} = extract_killmail_data(killmails)

    # Pre-populate cache with existing names
    cache_existing_names(existing_names)

    # Only fetch truly missing names
    batch_load_missing_names(missing_ids)

    # Return original killmails (names are now cached)
    killmails
  end

  @doc """
  Preloads names for battle participants.
  """
  def preload_battle_names(battle) when is_map(battle) do
    # Extract all names and IDs from battle
    {existing_names, missing_ids} = extract_battle_data(battle)

    # Pre-populate cache with existing names
    cache_existing_names(existing_names)

    # Only fetch truly missing names
    batch_load_missing_names(missing_ids)

    # Return original battle (names are now cached)
    battle
  end

  @doc """
  Preloads names for a list of participants.
  """
  def preload_participant_names(participants) when is_list(participants) do
    # For participants, we typically don't have names embedded
    # Extract unique IDs
    character_ids =
      participants |> Enum.map(& &1.character_id) |> Enum.filter(& &1) |> Enum.uniq()

    corp_ids =
      participants |> Enum.map(& &1.corporation_id) |> Enum.filter(& &1) |> Enum.uniq()

    alliance_ids =
      participants |> Enum.map(& &1.alliance_id) |> Enum.filter(& &1) |> Enum.uniq()

    ship_ids =
      participants |> Enum.map(& &1.ship_type_id) |> Enum.filter(& &1) |> Enum.uniq()

    # Batch load all names
    batch_load_missing_names(%{
      character_ids: character_ids,
      corp_ids: corp_ids,
      alliance_ids: alliance_ids,
      ship_ids: ship_ids,
      system_ids: []
    })

    participants
  end

  @doc """
  Preloads names for intelligence profiles.
  """
  def preload_profile_names(profiles) when is_list(profiles) do
    {character_ids, corp_ids, alliance_ids, ship_ids, system_ids} = extract_profile_ids(profiles)

    batch_load_missing_names(%{
      character_ids: character_ids,
      corp_ids: corp_ids,
      alliance_ids: alliance_ids,
      ship_ids: ship_ids,
      system_ids: system_ids
    })

    profiles
  end

  # Private functions

  # Helper function to ensure ID is an integer
  defp ensure_integer_id(id) when is_integer(id), do: id

  defp ensure_integer_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} ->
        int_id

      _ ->
        Logger.warning("Failed to parse ID as integer: #{inspect(id)}")
        # Return a default that won't match any real ID
        0
    end
  end

  defp ensure_integer_id(id) do
    Logger.warning("Unexpected ID type: #{inspect(id)}")
    # Return a default that won't match any real ID
    0
  end

  defp extract_killmail_data(killmails) do
    initial_state = {
      %{characters: %{}, corporations: %{}, alliances: %{}},
      %{character_ids: [], corp_ids: [], alliance_ids: [], ship_ids: [], system_ids: []}
    }

    killmails
    |> Enum.reduce(initial_state, fn killmail, {names, ids} ->
      # Process raw_data which contains the actual names
      raw_data = Map.get(killmail, :raw_data, %{})

      # Extract victim data
      {names, ids} = extract_victim_data(raw_data, names, ids)

      # Extract attacker data
      {names, ids} = extract_attackers_data(raw_data, names, ids)

      # Add ship and system IDs (these don't have names in killmail data)
      ids = add_ship_and_system_ids(killmail, raw_data, ids)

      {names, ids}
    end)
    |> then(fn {names, ids} ->
      # Deduplicate IDs
      deduped_ids = %{
        character_ids: Enum.uniq(ids.character_ids),
        corp_ids: Enum.uniq(ids.corp_ids),
        alliance_ids: Enum.uniq(ids.alliance_ids),
        ship_ids: Enum.uniq(ids.ship_ids),
        system_ids: Enum.uniq(ids.system_ids)
      }

      {names, deduped_ids}
    end)
  end

  defp extract_victim_data(raw_data, names, ids) do
    victim = Map.get(raw_data, "victim", %{})

    # Extract character name if present
    names =
      if victim["character_id"] && victim["character_name"] do
        int_id = ensure_integer_id(victim["character_id"])
        put_in(names, [:characters, int_id], victim["character_name"])
      else
        names
      end

    # Extract corporation name if present
    names =
      if victim["corporation_id"] && victim["corporation_name"] do
        int_id = ensure_integer_id(victim["corporation_id"])
        put_in(names, [:corporations, int_id], victim["corporation_name"])
      else
        names
      end

    # Extract alliance name if present
    names =
      if victim["alliance_id"] && victim["alliance_name"] do
        int_id = ensure_integer_id(victim["alliance_id"])
        put_in(names, [:alliances, int_id], victim["alliance_name"])
      else
        names
      end

    # Add IDs for missing names - ensure they are integers
    ids = %{
      ids
      | character_ids:
          if(victim["character_id"] && !victim["character_name"],
            do: [ensure_integer_id(victim["character_id"]) | ids.character_ids],
            else: ids.character_ids
          ),
        corp_ids:
          if(victim["corporation_id"] && !victim["corporation_name"],
            do: [ensure_integer_id(victim["corporation_id"]) | ids.corp_ids],
            else: ids.corp_ids
          ),
        alliance_ids:
          if(victim["alliance_id"] && !victim["alliance_name"],
            do: [ensure_integer_id(victim["alliance_id"]) | ids.alliance_ids],
            else: ids.alliance_ids
          )
    }

    {names, ids}
  end

  defp extract_attackers_data(raw_data, names, ids) do
    attackers = Map.get(raw_data, "attackers", [])

    Enum.reduce(attackers, {names, ids}, fn attacker, {names_acc, ids_acc} ->
      # Extract character name if present
      names_acc =
        if attacker["character_id"] && attacker["character_name"] do
          int_id = ensure_integer_id(attacker["character_id"])
          put_in(names_acc, [:characters, int_id], attacker["character_name"])
        else
          names_acc
        end

      # Extract corporation name if present
      names_acc =
        if attacker["corporation_id"] && attacker["corporation_name"] do
          int_id = ensure_integer_id(attacker["corporation_id"])
          put_in(names_acc, [:corporations, int_id], attacker["corporation_name"])
        else
          names_acc
        end

      # Extract alliance name if present
      names_acc =
        if attacker["alliance_id"] && attacker["alliance_name"] do
          int_id = ensure_integer_id(attacker["alliance_id"])
          put_in(names_acc, [:alliances, int_id], attacker["alliance_name"])
        else
          names_acc
        end

      # Add IDs for missing names - ensure they are integers
      ids_acc = %{
        ids_acc
        | character_ids:
            if(attacker["character_id"] && !attacker["character_name"],
              do: [ensure_integer_id(attacker["character_id"]) | ids_acc.character_ids],
              else: ids_acc.character_ids
            ),
          corp_ids:
            if(attacker["corporation_id"] && !attacker["corporation_name"],
              do: [ensure_integer_id(attacker["corporation_id"]) | ids_acc.corp_ids],
              else: ids_acc.corp_ids
            ),
          alliance_ids:
            if(attacker["alliance_id"] && !attacker["alliance_name"],
              do: [ensure_integer_id(attacker["alliance_id"]) | ids_acc.alliance_ids],
              else: ids_acc.alliance_ids
            ),
          ship_ids:
            if(attacker["ship_type_id"],
              do: [ensure_integer_id(attacker["ship_type_id"]) | ids_acc.ship_ids],
              else: ids_acc.ship_ids
            )
      }

      {names_acc, ids_acc}
    end)
  end

  defp add_ship_and_system_ids(killmail, raw_data, ids) do
    victim = Map.get(raw_data, "victim", %{})

    %{
      ids
      | ship_ids:
          if(victim["ship_type_id"],
            do: [ensure_integer_id(victim["ship_type_id"]) | ids.ship_ids],
            else: ids.ship_ids
          ),
        system_ids:
          if(killmail[:solar_system_id],
            do: [killmail.solar_system_id | ids.system_ids],
            else: ids.system_ids
          )
    }
  end

  defp extract_battle_data(battle) do
    # For battles, we need to extract from timeline events
    events = get_in(battle, [:timeline, :events]) || []

    initial_state = {
      %{characters: %{}, corporations: %{}, alliances: %{}},
      %{character_ids: [], corp_ids: [], alliance_ids: [], ship_ids: [], system_ids: []}
    }

    Enum.reduce(events, initial_state, fn event, {names, ids} ->
      # Extract from victim
      {names, ids} = extract_event_victim_data(event, names, ids)

      # Extract from attackers
      {names, ids} = extract_event_attackers_data(event, names, ids)

      # Add system ID
      ids =
        if event[:location][:solar_system_id] do
          %{ids | system_ids: [event.location.solar_system_id | ids.system_ids]}
        else
          ids
        end

      {names, ids}
    end)
    |> then(fn {names, ids} ->
      # Deduplicate IDs
      deduped_ids = %{
        character_ids: Enum.uniq(ids.character_ids),
        corp_ids: Enum.uniq(ids.corp_ids),
        alliance_ids: Enum.uniq(ids.alliance_ids),
        ship_ids: Enum.uniq(ids.ship_ids),
        system_ids: Enum.uniq(ids.system_ids)
      }

      {names, deduped_ids}
    end)
  end

  defp extract_event_victim_data(event, names, ids) do
    victim = Map.get(event, :victim, %{})

    # For timeline events, names should already be present
    names =
      if victim[:character_id] && victim[:character_name] do
        put_in(names, [:characters, victim.character_id], victim.character_name)
      else
        names
      end

    names =
      if victim[:corporation_id] && victim[:corporation_name] do
        put_in(names, [:corporations, victim.corporation_id], victim.corporation_name)
      else
        names
      end

    names =
      if victim[:alliance_id] && victim[:alliance_name] do
        put_in(names, [:alliances, victim.alliance_id], victim.alliance_name)
      else
        names
      end

    # Add IDs for any missing names
    ids = %{
      ids
      | character_ids:
          if(victim[:character_id] && !victim[:character_name],
            do: [victim.character_id | ids.character_ids],
            else: ids.character_ids
          ),
        corp_ids:
          if(victim[:corporation_id] && !victim[:corporation_name],
            do: [victim.corporation_id | ids.corp_ids],
            else: ids.corp_ids
          ),
        alliance_ids:
          if(victim[:alliance_id] && !victim[:alliance_name],
            do: [victim.alliance_id | ids.alliance_ids],
            else: ids.alliance_ids
          ),
        ship_ids:
          if(victim[:ship_type_id],
            do: [victim.ship_type_id | ids.ship_ids],
            else: ids.ship_ids
          )
    }

    {names, ids}
  end

  defp extract_event_attackers_data(event, names, ids) do
    attackers = Map.get(event, :attackers, [])

    Enum.reduce(attackers, {names, ids}, fn attacker, {names_acc, ids_acc} ->
      # Extract names if present
      names_acc =
        if attacker[:character_id] && attacker[:character_name] do
          put_in(names_acc, [:characters, attacker.character_id], attacker.character_name)
        else
          names_acc
        end

      names_acc =
        if attacker[:corporation_id] && attacker[:corporation_name] do
          put_in(names_acc, [:corporations, attacker.corporation_id], attacker.corporation_name)
        else
          names_acc
        end

      names_acc =
        if attacker[:alliance_id] && attacker[:alliance_name] do
          put_in(names_acc, [:alliances, attacker.alliance_id], attacker.alliance_name)
        else
          names_acc
        end

      # Add IDs for missing names
      ids_acc = %{
        ids_acc
        | character_ids:
            if(attacker[:character_id] && !attacker[:character_name],
              do: [attacker.character_id | ids_acc.character_ids],
              else: ids_acc.character_ids
            ),
          corp_ids:
            if(attacker[:corporation_id] && !attacker[:corporation_name],
              do: [attacker.corporation_id | ids_acc.corp_ids],
              else: ids_acc.corp_ids
            ),
          alliance_ids:
            if(attacker[:alliance_id] && !attacker[:alliance_name],
              do: [attacker.alliance_id | ids_acc.alliance_ids],
              else: ids_acc.alliance_ids
            ),
          ship_ids:
            if(attacker[:ship_type_id],
              do: [attacker.ship_type_id | ids_acc.ship_ids],
              else: ids_acc.ship_ids
            )
      }

      {names_acc, ids_acc}
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

  defp cache_existing_names(%{characters: chars, corporations: corps, alliances: alliances}) do
    # Cache all existing character names - ensure IDs are integers
    Enum.each(chars, fn {id, name} ->
      int_id = ensure_integer_id(id)
      Logger.debug("Caching character: ID=#{inspect(id)} -> #{inspect(int_id)}, name=#{name}")
      CacheManager.cache_result(:character, int_id, name)
    end)

    # Cache all existing corporation names - ensure IDs are integers
    Enum.each(corps, fn {id, name} ->
      int_id = ensure_integer_id(id)
      Logger.debug("Caching corporation: ID=#{inspect(id)} -> #{inspect(int_id)}, name=#{name}")
      CacheManager.cache_result(:corporation, int_id, name)
    end)

    # Cache all existing alliance names - ensure IDs are integers
    Enum.each(alliances, fn {id, name} ->
      int_id = ensure_integer_id(id)
      Logger.debug("Caching alliance: ID=#{inspect(id)} -> #{inspect(int_id)}, name=#{name}")
      CacheManager.cache_result(:alliance, int_id, name)
    end)

    Logger.debug("""
    Pre-cached existing names from killmail data:
    - Characters: #{map_size(chars)}
    - Corporations: #{map_size(corps)}
    - Alliances: #{map_size(alliances)}
    """)
  end

  defp batch_load_missing_names(%{
         character_ids: character_ids,
         corp_ids: corp_ids,
         alliance_ids: alliance_ids,
         ship_ids: ship_ids,
         system_ids: system_ids
       }) do
    start_time = System.monotonic_time(:millisecond)

    # Only load static data (ships and systems) from database
    # Character/corp/alliance names should already be cached from killmail data
    tasks =
      [
        if(length(ship_ids) > 0, do: Task.async(fn -> NameResolver.ship_names(ship_ids) end)),
        if(length(system_ids) > 0,
          do: Task.async(fn -> NameResolver.system_names(system_ids) end)
        )
      ]
      |> Enum.filter(& &1)

    # Await all tasks
    if length(tasks) > 0 do
      Task.await_many(tasks, 30_000)
    end

    elapsed = System.monotonic_time(:millisecond) - start_time

    Logger.debug("""
    Batch loaded missing names in #{elapsed}ms:
    - Characters to load: #{length(character_ids)} (should be 0 - names from killmail)
    - Corporations to load: #{length(corp_ids)} (should be 0 - names from killmail)
    - Alliances to load: #{length(alliance_ids)} (should be 0 - names from killmail)
    - Ships loaded: #{length(ship_ids)}
    - Systems loaded: #{length(system_ids)}
    """)

    :ok
  end
end
