defmodule EveDmv.Search.SearchSuggestionService do
  @moduledoc """
  Service for providing search suggestions and autocomplete functionality.

  Provides intelligent search suggestions for characters, corporations, alliances,
  and systems based on database queries with optimized performance.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.Participant
  alias EveDmv.Static.EveSolarSystem
  alias EveDmv.Static.EveItemType

  import Ash.Query
  require Logger

  @doc """
  Get character search suggestions based on partial name match.

  Returns up to `limit` character suggestions ordered by relevance.
  """
  def get_character_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        # First try to get from analytics/stats table for better data
        case get_character_suggestions_from_stats(query, limit) do
          {:ok, [_ | _] = suggestions} ->
            {:ok, suggestions}

          _ ->
            # Fallback to participants table
            get_character_suggestions_from_participants(query, limit)
        end
      rescue
        error ->
          Logger.warning("Character search failed: #{inspect(error)}")
          {:error, :search_failed}
      end
    end
  end

  @doc """
  Get corporation search suggestions based on partial name match.
  """
  def get_corporation_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        # Query unique corporations from participants
        query_pattern = "%#{String.downcase(query)}%"

        corporation_query =
          Participant
          |> new()
          |> filter(not is_nil(corporation_name))
          |> filter(fragment("LOWER(?) LIKE ?", corporation_name, ^query_pattern))
          |> select([:corporation_id, :corporation_name])
          |> distinct([:corporation_id])
          |> limit(limit)

        case Ash.read(corporation_query, domain: Api) do
          {:ok, corporations} ->
            suggestions =
              Enum.map(corporations, fn corp ->
                %{
                  id: corp.corporation_id,
                  name: corp.corporation_name,
                  type: :corporation,
                  subtitle: "Corporation"
                }
              end)

            {:ok, suggestions}

          {:error, reason} ->
            Logger.warning("Corporation search failed: #{inspect(reason)}")
            {:ok, []}
        end
      rescue
        error ->
          Logger.warning("Corporation search failed: #{inspect(error)}")
          {:error, :search_failed}
      end
    end
  end

  @doc """
  Get alliance search suggestions based on partial name match.
  """
  def get_alliance_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        query_pattern = "%#{String.downcase(query)}%"

        alliance_query =
          Participant
          |> new()
          |> filter(not is_nil(alliance_name))
          |> filter(fragment("LOWER(?) LIKE ?", alliance_name, ^query_pattern))
          |> select([:alliance_id, :alliance_name])
          |> distinct([:alliance_id])
          |> limit(limit)

        case Ash.read(alliance_query, domain: Api) do
          {:ok, alliances} ->
            suggestions =
              Enum.map(alliances, fn alliance ->
                %{
                  id: alliance.alliance_id,
                  name: alliance.alliance_name,
                  type: :alliance,
                  subtitle: "Alliance"
                }
              end)

            {:ok, suggestions}

          {:error, reason} ->
            Logger.warning("Alliance search failed: #{inspect(reason)}")
            {:ok, []}
        end
      rescue
        error ->
          Logger.warning("Alliance search failed: #{inspect(error)}")
          {:error, :search_failed}
      end
    end
  end

  @doc """
  Get system search suggestions based on partial name match.
  """
  def get_system_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        query_pattern = "%#{String.downcase(query)}%"

        system_query =
          EveSolarSystem
          |> new()
          |> filter(fragment("LOWER(?) LIKE ?", system_name, ^query_pattern))
          |> select([:system_id, :system_name, :region_name, :security_status])
          |> limit(limit)

        case Ash.read(system_query, domain: Api) do
          {:ok, systems} ->
            suggestions =
              Enum.map(systems, fn system ->
                security_class = format_security_status(system.security_status)

                %{
                  id: system.system_id,
                  name: system.system_name,
                  type: :system,
                  subtitle: "#{system.region_name} (#{security_class})"
                }
              end)

            {:ok, suggestions}

          {:error, reason} ->
            Logger.warning("System search failed: #{inspect(reason)}")
            {:ok, []}
        end
      rescue
        error ->
          Logger.warning("System search failed: #{inspect(error)}")
          {:error, :search_failed}
      end
    end
  end

  @doc """
  Get ship type search suggestions based on partial name match.
  """
  def get_ship_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        query_pattern = "%#{String.downcase(query)}%"

        ship_query =
          EveItemType
          |> new()
          |> filter(is_ship: true)
          |> filter(published: true)
          |> filter(fragment("LOWER(?) LIKE ?", type_name, ^query_pattern))
          |> select([:type_id, :type_name, :group_name, :category_name])
          |> limit(limit)

        case Ash.read(ship_query, domain: Api) do
          {:ok, ships} ->
            suggestions =
              Enum.map(ships, fn ship ->
                %{
                  id: ship.type_id,
                  name: ship.type_name,
                  type: :ship,
                  subtitle: "#{ship.group_name} (#{ship.category_name})"
                }
              end)

            {:ok, suggestions}

          {:error, reason} ->
            Logger.warning("Ship search failed: #{inspect(reason)}")
            {:ok, []}
        end
      rescue
        error ->
          Logger.warning("Ship search failed: #{inspect(error)}")
          {:error, :search_failed}
      end
    end
  end

  @doc """
  Get mixed search suggestions across all types (characters, corps, alliances, systems).

  Returns a combined list of suggestions with type indicators.
  """
  def get_mixed_suggestions(query, opts \\ []) do
    total_limit = Keyword.get(opts, :limit, 10)

    # Distribute limit across different types
    per_type_limit = max(2, div(total_limit, 4))

    # Run searches in parallel for better performance
    tasks = [
      Task.async(fn -> get_character_suggestions(query, limit: per_type_limit) end),
      Task.async(fn -> get_corporation_suggestions(query, limit: per_type_limit) end),
      Task.async(fn -> get_alliance_suggestions(query, limit: per_type_limit) end),
      Task.async(fn -> get_system_suggestions(query, limit: per_type_limit) end)
    ]

    results = Task.await_many(tasks, 5000)

    # Combine results
    all_suggestions =
      results
      |> Enum.map(fn
        {:ok, suggestions} -> suggestions
        _ -> []
      end)
      |> List.flatten()
      |> Enum.take(total_limit)

    {:ok, all_suggestions}
  end

  # Private helper functions

  defp get_character_suggestions_from_stats(query, limit) do
    # Try direct SQL query on player_stats table if it exists and has data
    search_query = """
    SELECT 
      character_id,
      character_name,
      corporation_name,
      total_kills,
      total_losses
    FROM player_stats
    WHERE character_name IS NOT NULL
      AND LOWER(character_name) LIKE $1
    ORDER BY total_kills DESC, total_losses ASC
    LIMIT $2
    """

    search_pattern = "%#{String.downcase(query)}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern, limit]) do
      {:ok, %{rows: [_ | _] = rows}} ->
        suggestions =
          rows
          |> Enum.map(fn [
                           character_id,
                           character_name,
                           corporation_name,
                           total_kills,
                           total_losses
                         ] ->
            subtitle =
              if corporation_name do
                "#{corporation_name} (#{total_kills}K/#{total_losses}L)"
              else
                "#{total_kills} Kills / #{total_losses} Losses"
              end

            %{
              id: character_id,
              name: character_name,
              type: :character,
              subtitle: subtitle
            }
          end)

        {:ok, suggestions}

      {:ok, %{rows: []}} ->
        # No results from player_stats, fallback will be used
        Logger.debug("No results from stats table, will try participants")
        {:error, :no_stats_data}

      {:error, %{postgres: %{code: :undefined_table}}} ->
        # Table doesn't exist, fallback will be used
        Logger.debug("Player stats table not available, using fallback search")
        {:error, :table_not_found}

      {:error, reason} ->
        Logger.debug("Stats search failed, will try participants: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_character_suggestions_from_participants(query, limit) do
    # Use direct SQL query for better reliability (based on working character_search_live.ex implementation)
    search_query = """
    WITH character_activity AS (
      SELECT 
        victim_character_id as character_id,
        victim_character_name as character_name,
        victim_corporation_name as corporation_name,
        COUNT(*) as killmail_count,
        MAX(killmail_time) as last_activity
      FROM killmails_raw
      WHERE victim_character_name IS NOT NULL
        AND LOWER(victim_character_name) LIKE $1
      GROUP BY victim_character_id, victim_character_name, victim_corporation_name
      
      UNION
      
      SELECT DISTINCT
        (attacker->>'character_id')::bigint as character_id,
        attacker->>'character_name' as character_name,
        attacker->>'corporation_name' as corporation_name,
        COUNT(*) as killmail_count,
        MAX(killmail_time) as last_activity
      FROM killmails_raw km,
           jsonb_array_elements(km.raw_data->'attackers') as attacker
      WHERE attacker->>'character_name' IS NOT NULL
        AND LOWER(attacker->>'character_name') LIKE $1
        AND (attacker->>'character_id')::bigint IS NOT NULL
      GROUP BY (attacker->>'character_id')::bigint, attacker->>'character_name', attacker->>'corporation_name'
    )
    SELECT 
      character_id,
      character_name,
      corporation_name,
      SUM(killmail_count) as total_killmails,
      MAX(last_activity) as last_seen
    FROM character_activity
    WHERE character_id IS NOT NULL
    GROUP BY character_id, character_name, corporation_name
    ORDER BY total_killmails DESC, last_seen DESC
    LIMIT $2
    """

    search_pattern = "%#{String.downcase(query)}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern, limit]) do
      {:ok, %{rows: rows}} ->
        suggestions =
          rows
          |> Enum.map(fn [
                           character_id,
                           character_name,
                           corporation_name,
                           total_killmails,
                           _last_seen
                         ] ->
            subtitle =
              if corporation_name do
                "#{corporation_name} (#{total_killmails} killmails)"
              else
                "#{total_killmails} killmails"
              end

            %{
              id: character_id,
              name: character_name,
              type: :character,
              subtitle: subtitle
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        Logger.warning("Character search SQL query failed: #{inspect(reason)}")
        {:ok, []}
    end
  end

  defp format_security_status(security_status) when is_number(security_status) do
    cond do
      security_status >= 0.5 -> "High Sec"
      security_status > 0.0 -> "Low Sec"
      security_status <= 0.0 -> "Null Sec"
      true -> "Unknown"
    end
  end

  defp format_security_status(_), do: "Unknown"
end
