defmodule EveDmv.Search.SearchSuggestionService do
  @moduledoc """
  Service for providing search suggestions and autocomplete functionality.

  Provides intelligent search suggestions for characters, corporations, alliances,
  and systems based on database queries with optimized performance.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.Participant
  alias EveDmv.Analytics.PlayerStats
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
    query_pattern = "%#{String.downcase(query)}%"

    stats_query =
      PlayerStats
      |> new()
      |> filter(not is_nil(character_name))
      |> filter(fragment("LOWER(?) LIKE ?", character_name, ^query_pattern))
      |> select([:character_id, :character_name, :corporation_name, :total_kills, :total_losses])
      # Order by activity level
      |> sort(total_kills: :desc)
      |> limit(limit)

    case Ash.read(stats_query, domain: Api) do
      {:ok, characters} ->
        suggestions =
          Enum.map(characters, fn char ->
            subtitle =
              if char.corporation_name do
                "#{char.corporation_name} (#{char.total_kills}K/#{char.total_losses}L)"
              else
                "#{char.total_kills} Kills / #{char.total_losses} Losses"
              end

            %{
              id: char.character_id,
              name: char.character_name,
              type: :character,
              subtitle: subtitle
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        Logger.debug("Stats search failed, will try participants: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_character_suggestions_from_participants(query, limit) do
    query_pattern = "%#{String.downcase(query)}%"

    participant_query =
      Participant
      |> new()
      |> filter(not is_nil(character_name))
      |> filter(fragment("LOWER(?) LIKE ?", character_name, ^query_pattern))
      |> select([:character_id, :character_name, :corporation_name])
      |> distinct([:character_id])
      |> limit(limit)

    case Ash.read(participant_query, domain: Api) do
      {:ok, characters} ->
        suggestions =
          Enum.map(characters, fn char ->
            subtitle = char.corporation_name || "Character"

            %{
              id: char.character_id,
              name: char.character_name,
              type: :character,
              subtitle: subtitle
            }
          end)

        {:ok, suggestions}

      {:error, reason} ->
        Logger.warning("Participant search failed: #{inspect(reason)}")
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
