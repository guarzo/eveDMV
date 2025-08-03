defmodule EveDmv.Contexts.Intelligence.Services.CharacterService do
  @moduledoc """
  Application service for character intelligence operations.
  Handles CRUD operations, caching, and real-time updates.
  """

  alias EveDmv.Api
  alias EveDmv.Contexts.Intelligence.Core.CharacterAnalyzer
  alias EveDmv.Contexts.Intelligence.Resources.CharacterProfile
  alias EveDmv.Intelligence.Cache.IntelligenceCache

  require Logger
  require Ash.Query

  @pubsub_topic "character_intelligence"

  @doc """
  Create a new character profile from raw character data.
  """
  @spec create_character_profile(map()) :: {:ok, any()} | {:error, atom()}
  def create_character_profile(character_data) do
    with {:ok, profile} <- Ash.create(CharacterProfile, character_data, domain: Api) do
      # Broadcast creation event
      Phoenix.PubSub.broadcast(
        EveDmv.PubSub,
        @pubsub_topic,
        {:character_profile_created, profile}
      )

      {:ok, profile}
    end
  end

  @doc """
  Update character statistics.
  """
  @spec update_character_stats(integer(), map()) :: {:ok, any()} | {:error, atom()}
  def update_character_stats(character_id, stats) do
    case get_character(character_id) do
      {:ok, character} ->
        case Ash.update(character, stats, domain: Api) do
          {:ok, updated} ->
            # Clear related caches
            clear_character_cache(character_id)

            # Broadcast update event
            Phoenix.PubSub.broadcast(
              EveDmv.PubSub,
              @pubsub_topic,
              {:character_stats_updated, updated}
            )

            {:ok, updated}

          error ->
            error
        end

      error ->
        error
    end
  end

  @doc """
  Get character profile by ID.
  """
  @spec get_character(integer()) :: {:ok, any()} | {:error, atom()}
  def get_character(character_id) do
    case Ash.get(CharacterProfile, character_id, domain: Api) do
      {:ok, character} -> {:ok, character}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :not_found}
      error -> error
    end
  end

  @doc """
  Search characters by various parameters.
  """
  @spec search_characters(map() | keyword()) :: {:ok, [any()]} | {:error, atom()}
  def search_characters(search_params) do
    query =
      CharacterProfile
      |> build_search_filters(search_params)
      |> Ash.Query.limit(search_params[:limit] || 50)
      |> Ash.Query.sort(search_params[:sort] || [character_name: :asc])

    case Ash.read(query, domain: Api) do
      {:ok, characters} -> {:ok, characters}
      error -> error
    end
  end

  @doc """
  Refresh character cache by re-analyzing.
  """
  @spec refresh_character_cache(integer()) :: {:ok, map()} | {:error, atom()}
  def refresh_character_cache(character_id) do
    # Clear existing cache
    clear_character_cache(character_id)

    # Trigger fresh analysis
    case CharacterAnalyzer.analyze_character(character_id) do
      {:ok, analysis} ->
        Logger.info("Refreshed cache for character #{character_id}")
        {:ok, analysis}

      error ->
        Logger.error("Failed to refresh cache for character #{character_id}: #{inspect(error)}")
        error
    end
  end

  @doc """
  Clear all cached data for a character.
  """
  @spec clear_character_cache(integer()) :: :ok
  def clear_character_cache(character_id) do
    # Clear various cache keys
    cache_keys = [
      {:character_analysis, character_id, []},
      {:character_stats, character_id},
      {:combat_stats, character_id, []},
      {:ship_preferences, character_id},
      {:behavioral_patterns, character_id},
      {:performance_metrics, character_id, []},
      {:threat_assessment, character_id, []}
    ]

    Enum.each(cache_keys, fn key ->
      IntelligenceCache.delete(key)
    end)

    Logger.debug("Cleared cache for character #{character_id}")
    :ok
  end

  @doc """
  Subscribe to character updates.
  """
  @spec subscribe_to_character_updates(integer()) :: :ok | {:error, any()}
  def subscribe_to_character_updates(character_id) do
    Phoenix.PubSub.subscribe(
      EveDmv.PubSub,
      "#{@pubsub_topic}:#{character_id}"
    )
  end

  @doc """
  Unsubscribe from character updates.
  """
  @spec unsubscribe_from_character_updates(integer()) :: :ok
  def unsubscribe_from_character_updates(character_id) do
    Phoenix.PubSub.unsubscribe(
      EveDmv.PubSub,
      "#{@pubsub_topic}:#{character_id}"
    )
  end

  @doc """
  Bulk update character stats from killmail processing.
  """
  @spec bulk_update_from_killmails([{integer(), map()}]) :: {:ok, {[any()], [any()]}}
  def bulk_update_from_killmails(character_stats_list) do
    results =
      character_stats_list
      |> Task.async_stream(
        fn {character_id, stats} ->
          {character_id, update_character_stats(character_id, stats)}
        end,
        max_concurrency: 10,
        timeout: 30_000
      )
      |> Enum.reduce({[], []}, fn
        {:ok, {char_id, {:ok, profile}}}, {successes, failures} ->
          {[{char_id, profile} | successes], failures}

        {:ok, {char_id, {:error, reason}}}, {successes, failures} ->
          {successes, [{char_id, reason} | failures]}

        {:exit, reason}, {successes, failures} ->
          Logger.error("Bulk update task failed: #{inspect(reason)}")
          {successes, failures}
      end)

    Logger.info(
      "Bulk updated #{length(elem(results, 0))} characters, #{length(elem(results, 1))} failures"
    )

    {:ok, results}
  end

  # Private Functions

  defp build_search_filters(query, search_params) do
    Enum.reduce(search_params, query, fn
      {:name, name}, q when is_binary(name) ->
        Ash.Query.filter(q, contains(character_name, ^name))

      {:corporation_id, corp_id}, q when is_integer(corp_id) ->
        Ash.Query.filter(q, corporation_id == ^corp_id)

      {:alliance_id, alliance_id}, q when is_integer(alliance_id) ->
        Ash.Query.filter(q, alliance_id == ^alliance_id)

      {:min_threat_score, min_score}, q when is_number(min_score) ->
        Ash.Query.filter(q, threat_score >= ^min_score)

      {:max_threat_score, max_score}, q when is_number(max_score) ->
        Ash.Query.filter(q, threat_score <= ^max_score)

      {:active_since, date}, q ->
        Ash.Query.filter(q, last_seen >= ^date)

      {:security_status, sec_status}, q
      when sec_status in [:criminal, :suspect, :neutral, :positive] ->
        Ash.Query.filter(q, security_status == ^sec_status)

      # Ignore unknown parameters
      {_, _}, q ->
        q
    end)
  end
end
