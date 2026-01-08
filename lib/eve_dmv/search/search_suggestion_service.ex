defmodule EveDmv.Search.SearchSuggestionService do
  @moduledoc """
  Service for providing search suggestions and autocomplete functionality.

  Provides intelligent search suggestions for characters, corporations, alliances,
  and systems based on database queries with optimized performance.
  """

  alias EveDmv.Killmails.Participant
  alias EveDmv.Static.EveItemType
  alias EveDmv.Static.EveSolarSystem

  require Ash.Query
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

        corporation_query =
          Participant
          |> Ash.Query.new()
          |> Ash.Query.select([:corporation_id, :corporation_name])
          |> Ash.Query.distinct([:corporation_id])
          |> Ash.Query.limit(100)

        case Ash.read(corporation_query, domain: EveDmv.Api) do
          {:ok, corporations} ->
            # Filter in Elixir
            filtered_corps =
              corporations
              |> Enum.filter(fn corp ->
                corp.corporation_name &&
                  String.contains?(String.downcase(corp.corporation_name), String.downcase(query))
              end)
              |> Enum.take(limit)

            suggestions =
              Enum.map(filtered_corps, fn corp ->
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
        alliance_query =
          Participant
          |> Ash.Query.new()
          |> Ash.Query.select([:alliance_id, :alliance_name])
          |> Ash.Query.distinct([:alliance_id])
          |> Ash.Query.limit(100)

        case Ash.read(alliance_query, domain: EveDmv.Api) do
          {:ok, alliances} ->
            # Filter in Elixir
            filtered_alliances =
              alliances
              |> Enum.filter(fn alliance ->
                alliance.alliance_name &&
                  String.contains?(
                    String.downcase(alliance.alliance_name),
                    String.downcase(query)
                  )
              end)
              |> Enum.take(limit)

            suggestions =
              Enum.map(filtered_alliances, fn alliance ->
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
        system_query =
          EveSolarSystem
          |> Ash.Query.new()
          |> Ash.Query.select([
            :system_id,
            :system_name,
            :region_name,
            :security_status,
            :security_class
          ])
          |> Ash.Query.limit(500)

        case Ash.read(system_query, domain: EveDmv.Api) do
          {:ok, systems} ->
            # Filter in Elixir
            filtered_systems =
              systems
              |> Enum.filter(fn system ->
                String.contains?(String.downcase(system.system_name), String.downcase(query))
              end)
              |> Enum.take(limit)

            suggestions =
              Enum.map(filtered_systems, fn system ->
                sec_display =
                  format_security_status(system.security_class, system.security_status)

                %{
                  id: system.system_id,
                  name: system.system_name,
                  type: :system,
                  subtitle: "#{system.region_name} (#{sec_display})"
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
        ship_query =
          EveItemType
          |> Ash.Query.new()
          |> Ash.Query.filter(is_ship: true)
          |> Ash.Query.filter(published: true)
          |> Ash.Query.select([:type_id, :type_name, :group_name, :category_name])
          |> Ash.Query.limit(500)

        case Ash.read(ship_query, domain: EveDmv.Api) do
          {:ok, ships} ->
            # Filter in Elixir
            filtered_ships =
              ships
              |> Enum.filter(fn ship ->
                String.contains?(String.downcase(ship.type_name), String.downcase(query))
              end)
              |> Enum.take(limit)

            suggestions =
              Enum.map(filtered_ships, fn ship ->
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
    # Optimized: Uses participants table instead of JSONB extraction
    # Groups by character_id only to avoid duplicates when a character changed corporations
    # Uses a subquery to get the most recent corporation name
    search_query = """
    SELECT
      p.character_id,
      MAX(p.character_name) as character_name,
      (SELECT p2.corporation_name
       FROM participants p2
       WHERE p2.character_id = p.character_id
         AND p2.corporation_name IS NOT NULL
       ORDER BY p2.killmail_time DESC
       LIMIT 1) as corporation_name,
      COUNT(*) as total_killmails,
      MAX(p.killmail_time) as last_seen
    FROM participants p
    WHERE p.character_name IS NOT NULL
      AND LOWER(p.character_name) LIKE $1
      AND p.character_id IS NOT NULL
    GROUP BY p.character_id
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

  # Use security_class from SDE as authoritative source, with security_status as fallback
  defp format_security_status(security_class, _security_status) when is_binary(security_class) do
    case security_class do
      "highsec" -> "High Sec"
      "lowsec" -> "Low Sec"
      "nullsec" -> "Null Sec"
      "wormhole" -> "Wormhole"
      _ -> "Unknown"
    end
  end

  defp format_security_status(nil, security_status) when is_number(security_status) do
    cond do
      security_status >= 0.5 -> "High Sec"
      security_status > 0.0 -> "Low Sec"
      true -> "Null Sec"
    end
  end

  defp format_security_status(_, _), do: "Unknown"
end
