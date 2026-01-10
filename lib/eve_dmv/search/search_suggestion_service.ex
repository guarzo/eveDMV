defmodule EveDmv.Search.SearchSuggestionService do
  @moduledoc """
  Service for providing search suggestions and autocomplete functionality.

  Provides intelligent search suggestions for characters, corporations, alliances,
  and systems based on database queries with optimized performance.
  """

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
  Uses database-level filtering for performance.
  """
  def get_corporation_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        # Use direct SQL with ILIKE for efficient database-level filtering
        search_query = """
        SELECT DISTINCT ON (corporation_id)
          corporation_id,
          corporation_name
        FROM participants
        WHERE corporation_name IS NOT NULL
          AND corporation_name != ''
          AND LOWER(corporation_name) LIKE $1 ESCAPE '\\'
        ORDER BY corporation_id, killmail_time DESC
        LIMIT $2
        """

        search_pattern = "%#{escape_like_pattern(String.downcase(query))}%"

        case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern, limit]) do
          {:ok, %{rows: rows}} ->
            suggestions =
              Enum.map(rows, fn [corp_id, corp_name] ->
                %{
                  id: corp_id,
                  name: corp_name,
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
  Uses database-level filtering for performance.
  """
  def get_alliance_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        # Use direct SQL with ILIKE for efficient database-level filtering
        search_query = """
        SELECT DISTINCT ON (alliance_id)
          alliance_id,
          alliance_name
        FROM participants
        WHERE alliance_id IS NOT NULL
          AND alliance_name IS NOT NULL
          AND alliance_name != ''
          AND LOWER(alliance_name) LIKE $1 ESCAPE '\\'
        ORDER BY alliance_id, killmail_time DESC
        LIMIT $2
        """

        search_pattern = "%#{escape_like_pattern(String.downcase(query))}%"

        case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern, limit]) do
          {:ok, %{rows: rows}} ->
            suggestions =
              Enum.map(rows, fn [alliance_id, alliance_name] ->
                %{
                  id: alliance_id,
                  name: alliance_name,
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
  Uses database-level filtering for performance.
  """
  def get_system_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        # Use direct SQL with ILIKE for efficient database-level filtering
        search_query = """
        SELECT
          system_id,
          system_name,
          region_name,
          security_status,
          security_class
        FROM eve_solar_systems
        WHERE system_name IS NOT NULL
          AND LOWER(system_name) LIKE $1 ESCAPE '\\'
        ORDER BY system_name
        LIMIT $2
        """

        search_pattern = "%#{escape_like_pattern(String.downcase(query))}%"

        case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern, limit]) do
          {:ok, %{rows: rows}} ->
            suggestions =
              Enum.map(rows, fn [
                                  system_id,
                                  system_name,
                                  region_name,
                                  security_status,
                                  security_class
                                ] ->
                sec_display = format_security_status(security_class, security_status)

                %{
                  id: system_id,
                  name: system_name,
                  type: :system,
                  subtitle: "#{region_name || "Unknown"} (#{sec_display})"
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
  Uses database-level filtering for performance.
  """
  def get_ship_suggestions(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 10)
    min_length = Keyword.get(opts, :min_length, 2)

    if String.length(query) < min_length do
      {:ok, []}
    else
      try do
        # Use direct SQL with ILIKE for efficient database-level filtering
        search_query = """
        SELECT
          type_id,
          type_name,
          group_name,
          category_name
        FROM eve_item_types
        WHERE is_ship = true
          AND published = true
          AND type_name IS NOT NULL
          AND LOWER(type_name) LIKE $1 ESCAPE '\\'
        ORDER BY type_name
        LIMIT $2
        """

        search_pattern = "%#{escape_like_pattern(String.downcase(query))}%"

        case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern, limit]) do
          {:ok, %{rows: rows}} ->
            suggestions =
              Enum.map(rows, fn [type_id, type_name, group_name, category_name] ->
                %{
                  id: type_id,
                  name: type_name,
                  type: :ship,
                  subtitle: "#{group_name || "Ship"} (#{category_name || "Ship"})"
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

  # Escapes special LIKE pattern characters (%, _, \) so they are treated as literals.
  # Backslashes are escaped first to avoid double-escaping.
  defp escape_like_pattern(query) do
    query
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end

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
      AND LOWER(character_name) LIKE $1 ESCAPE '\\'
    ORDER BY total_kills DESC, total_losses ASC
    LIMIT $2
    """

    search_pattern = "%#{escape_like_pattern(String.downcase(query))}%"

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
      AND LOWER(p.character_name) LIKE $1 ESCAPE '\\'
      AND p.character_id IS NOT NULL
    GROUP BY p.character_id
    ORDER BY total_killmails DESC, last_seen DESC
    LIMIT $2
    """

    search_pattern = "%#{escape_like_pattern(String.downcase(query))}%"

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
