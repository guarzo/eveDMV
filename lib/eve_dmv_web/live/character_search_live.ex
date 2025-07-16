defmodule EveDmvWeb.CharacterSearchLive do
  @moduledoc """
  LiveView for searching EVE Online characters and accessing their intelligence reports.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Eve.NameResolver

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Character Search")
      |> assign(:search_query, "")
      |> assign(:search_results, [])
      |> assign(:searching, false)
      |> assign(:error_message, nil)
      |> assign(:recent_searches, load_recent_searches())

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"search" => %{"query" => query}}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign(:searching, true)
      |> assign(:error_message, nil)
      |> perform_search(query)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_event("view_character", %{"character_id" => character_id}, socket) do
    # Save to recent searches
    save_recent_search(character_id)

    {:noreply, push_navigate(socket, to: ~p"/character/#{character_id}/intelligence")}
  end

  defp perform_search(socket, query) when byte_size(query) < 3 do
    socket
    |> assign(:searching, false)
    |> assign(:search_results, [])
    |> assign(:error_message, "Please enter at least 3 characters")
  end

  defp perform_search(socket, query) do
    case search_characters(query) do
      {:ok, results} ->
        socket
        |> assign(:searching, false)
        |> assign(:search_results, results)
        |> assign(:error_message, nil)

      {:error, _reason} ->
        socket
        |> assign(:searching, false)
        |> assign(:search_results, [])
        |> assign(:error_message, "Search failed. Please try again.")
    end
  end

  defp search_characters(query) do
    case Integer.parse(query) do
      {character_id, ""} ->
        # Direct character ID lookup
        search_by_character_id(character_id)

      _ ->
        # Text search - implement character name search
        search_by_character_name(query)
    end
  end

  defp search_by_character_id(character_id) do
    character_name = NameResolver.character_name(character_id)

    if character_name != "Unknown Character" and not String.contains?(character_name, "Unknown Character") do
      # Get additional character info
      character_info = get_character_additional_info(character_id)
      
      {:ok, [
        %{
          character_id: character_id,
          name: character_name,
          portrait_url: character_portrait(character_id),
          corporation_name: character_info.corporation_name,
          alliance_name: character_info.alliance_name,
          security_status: character_info.security_status,
          killmails_count: character_info.killmails_count,
          last_seen: character_info.last_seen
        }
      ]}
    else
      {:ok, []}
    end
  end

  defp search_by_character_name(query) do
    # Enhanced character name search using database
    sanitized_query = String.trim(query) |> String.downcase()
    
    if String.length(sanitized_query) < 3 do
      {:error, :query_too_short}
    else
      # Search in killmail data for character names
      case search_characters_in_database(sanitized_query) do
        {:ok, results} ->
          # Enhance results with additional info
          enhanced_results = 
            results
            |> Enum.map(&enhance_character_result/1)
            |> Enum.sort_by(&(&1.killmails_count), :desc)
            |> Enum.take(20)  # Limit to top 20 results
          
          {:ok, enhanced_results}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp load_recent_searches do
    # Load recent searches from cache or user session
    # For now, load from killmail data to show active characters
    load_recent_active_characters()
  end

  defp load_recent_active_characters do
    query = """
    SELECT DISTINCT 
      km.victim_character_id as character_id,
      COUNT(*) as activity_count,
      MAX(km.killmail_time) as last_seen
    FROM killmails_raw km
    WHERE km.victim_character_id IS NOT NULL 
      AND km.killmail_time >= NOW() - INTERVAL '30 days'
    GROUP BY km.victim_character_id
    ORDER BY activity_count DESC, last_seen DESC
    LIMIT 10
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, []) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [character_id, activity_count, last_seen] ->
          %{
            character_id: character_id,
            name: NameResolver.character_name(character_id),
            portrait_url: character_portrait(character_id),
            activity_count: activity_count,
            last_seen: last_seen
          }
        end)
        |> Enum.filter(&(&1.name != "Unknown Character"))

      {:error, _} ->
        []
    end
  end

  defp save_recent_search(character_id) do
    # Save to user session or cache
    # For now, just log the search
    Logger.info("Character search: #{character_id}")
    :ok
  end

  defp get_character_additional_info(character_id) do
    # Get comprehensive character information from killmail data
    query = """
    SELECT 
      COUNT(*) as total_killmails,
      COUNT(CASE WHEN km.victim_character_id = $1 THEN 1 END) as deaths,
      COUNT(CASE WHEN km.victim_character_id != $1 THEN 1 END) as kills,
      MAX(km.killmail_time) as last_seen,
      MAX(km.victim_corporation_id) as corporation_id,
      MAX(km.victim_alliance_id) as alliance_id
    FROM killmails_raw km
    WHERE km.victim_character_id = $1 
       OR EXISTS (
         SELECT 1 FROM jsonb_array_elements(km.raw_data->'attackers') as attacker
         WHERE (attacker->>'character_id')::bigint = $1
       )
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [character_id]) do
      {:ok, %{rows: [[total, deaths, kills, last_seen, corp_id, alliance_id]]}} ->
        %{
          killmails_count: total,
          deaths: deaths,
          kills: kills,
          last_seen: last_seen,
          corporation_name: if(corp_id, do: NameResolver.corporation_name(corp_id), else: nil),
          alliance_name: if(alliance_id, do: NameResolver.alliance_name(alliance_id), else: nil),
          security_status: estimate_security_status(kills, deaths)
        }

      {:error, _} ->
        %{
          killmails_count: 0,
          deaths: 0,
          kills: 0,
          last_seen: nil,
          corporation_name: nil,
          alliance_name: nil,
          security_status: 0.0
        }
    end
  end

  defp search_characters_in_database(query) do
    # Search for characters in killmail data using name patterns
    search_query = """
    WITH character_activity AS (
      SELECT 
        victim_character_id as character_id,
        victim_character_name as character_name,
        COUNT(*) as killmail_count,
        MAX(killmail_time) as last_activity
      FROM killmails_raw
      WHERE victim_character_name IS NOT NULL
        AND LOWER(victim_character_name) LIKE $1
      GROUP BY victim_character_id, victim_character_name
      
      UNION
      
      SELECT DISTINCT
        (attacker->>'character_id')::bigint as character_id,
        attacker->>'character_name' as character_name,
        COUNT(*) as killmail_count,
        MAX(killmail_time) as last_activity
      FROM killmails_raw km,
           jsonb_array_elements(km.raw_data->'attackers') as attacker
      WHERE attacker->>'character_name' IS NOT NULL
        AND LOWER(attacker->>'character_name') LIKE $1
        AND (attacker->>'character_id')::bigint IS NOT NULL
      GROUP BY (attacker->>'character_id')::bigint, attacker->>'character_name'
    )
    SELECT 
      character_id,
      character_name,
      SUM(killmail_count) as total_killmails,
      MAX(last_activity) as last_seen
    FROM character_activity
    WHERE character_id IS NOT NULL
    GROUP BY character_id, character_name
    ORDER BY total_killmails DESC, last_seen DESC
    LIMIT 50
    """

    search_pattern = "%#{query}%"

    case Ecto.Adapters.SQL.query(EveDmv.Repo, search_query, [search_pattern]) do
      {:ok, %{rows: rows}} ->
        results = 
          rows
          |> Enum.map(fn [character_id, character_name, killmail_count, last_seen] ->
            %{
              character_id: character_id,
              name: character_name || NameResolver.character_name(character_id),
              killmails_count: killmail_count,
              last_seen: last_seen
            }
          end)
          |> Enum.filter(&(&1.character_id != nil))
          |> Enum.uniq_by(&(&1.character_id))

        {:ok, results}

      {:error, reason} ->
        Logger.error("Character search failed: #{inspect(reason)}")
        {:error, :search_failed}
    end
  end

  defp enhance_character_result(result) do
    # Enhance search result with additional information
    character_info = get_character_additional_info(result.character_id)
    
    result
    |> Map.put(:portrait_url, character_portrait(result.character_id))
    |> Map.put(:corporation_name, character_info.corporation_name)
    |> Map.put(:alliance_name, character_info.alliance_name)
    |> Map.put(:security_status, character_info.security_status)
    |> Map.put(:kills, character_info.kills)
    |> Map.put(:deaths, character_info.deaths)
    |> Map.put(:efficiency, calculate_efficiency(character_info.kills, character_info.deaths))
  end

  defp estimate_security_status(kills, deaths) do
    # Estimate security status based on PvP activity
    # This is a simplified calculation
    if kills + deaths == 0 do
      5.0
    else
      # Start with neutral (0.0) and adjust based on activity
      base_status = 0.0
      kill_bonus = min(2.0, kills * 0.1)
      death_penalty = min(1.0, deaths * 0.05)
      
      Float.round(base_status + kill_bonus - death_penalty, 1)
    end
  end

  defp calculate_efficiency(kills, deaths) do
    if kills + deaths == 0 do
      0.0
    else
      Float.round(kills / (kills + deaths) * 100, 1)
    end
  end

  def character_portrait(character_id, size \\ 64) do
    "https://images.evetech.net/characters/#{character_id}/portrait?size=#{size}"
  end
end
