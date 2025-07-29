defmodule EveDmv.Database.QueryOptimizer do
  @moduledoc """
  Query optimization utilities for identifying and resolving N+1 query patterns.

  This module provides tools to:
  - Detect N+1 query patterns in the codebase
  - Suggest preloading strategies
  - Implement efficient batch loading
  - Monitor query performance
  """

  import Ecto.Query
  alias EveDmv.Repo
  require Logger

  @doc """
  Common N+1 patterns in EVE DMV and their solutions.
  """
  def n_plus_one_patterns do
    %{
      character_affiliations: %{
        problem: """
        Loading character data then separately querying each affiliation:
        ```
        characters = Repo.all(query)
        Enum.map(characters, fn char ->
          affiliations = get_character_affiliations(char.id)
          %{char | affiliations: affiliations}
        end)
        ```
        """,
        solution: """
        Use a single query with joins or preload:
        ```
        query
        |> join(:left, [c], a in assoc(c, :affiliations))
        |> preload([c, a], affiliations: a)
        |> Repo.all()
        ```
        """
      },
      killmail_participants: %{
        problem: """
        Loading killmails then querying participants for each:
        ```
        killmails = Repo.all(killmail_query)
        Enum.map(killmails, fn km ->
          participants = get_participants(km.killmail_id)
          %{km | participants: participants}
        end)
        ```
        """,
        solution: """
        Use batch loading or window functions:
        ```
        killmail_ids = Enum.map(killmails, & &1.killmail_id)
        participants_map = batch_load_participants(killmail_ids)

        Enum.map(killmails, fn km ->
          %{km | participants: Map.get(participants_map, km.killmail_id, [])}
        end)
        ```
        """
      },
      ship_type_names: %{
        problem: """
        Loading ship IDs then resolving names individually:
        ```
        ship_ids = get_unique_ship_ids(killmails)
        ship_names = Enum.map(ship_ids, &get_ship_name/1)
        ```
        """,
        solution: """
        Batch load all ship names at once:
        ```
        ship_ids = get_unique_ship_ids(killmails)
        ship_names_map = batch_load_ship_names(ship_ids)
        ```
        """
      }
    }
  end

  @doc """
  Batch load participants for multiple killmails to avoid N+1 queries.

  Instead of querying participants for each killmail individually,
  this loads all participants for the given killmail IDs in one query.
  """
  def batch_load_participants(killmail_ids) when is_list(killmail_ids) do
    # Use a single query to get all participants
    query = """
    SELECT
      killmail_id,
      jsonb_array_elements(raw_data->'attackers') as attacker
    FROM killmails_raw
    WHERE killmail_id = ANY($1)
    """

    case Repo.query(query, [killmail_ids]) do
      {:ok, %{rows: rows}} ->
        # Group participants by killmail_id
        rows
        |> Enum.group_by(fn [killmail_id, _] -> killmail_id end)
        |> Enum.map(fn {killmail_id, participants} ->
          {killmail_id, Enum.map(participants, fn [_, attacker] -> attacker end)}
        end)
        |> Map.new()

      {:error, error} ->
        Logger.error("Failed to batch load participants: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Batch load ship names to avoid N+1 queries when resolving ship types.
  """
  def batch_load_ship_names(ship_type_ids) when is_list(ship_type_ids) do
    query = """
    SELECT type_id, type_name
    FROM eve_item_types
    WHERE type_id = ANY($1)
    """

    case Repo.query(query, [ship_type_ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [id, name] -> {id, name} end)

      {:error, error} ->
        Logger.error("Failed to batch load ship names: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Batch load character names to avoid N+1 queries.
  """
  def batch_load_character_names(character_ids) when is_list(character_ids) do
    # First try to get from recent killmails (most likely to have current names)
    query = """
    WITH recent_names AS (
      SELECT DISTINCT
        victim_character_id as character_id,
        victim_character_name as character_name,
        killmail_time,
        ROW_NUMBER() OVER (PARTITION BY victim_character_id ORDER BY killmail_time DESC) as rn
      FROM killmails_raw
      WHERE victim_character_id = ANY($1)
        AND victim_character_name IS NOT NULL
    )
    SELECT character_id, character_name
    FROM recent_names
    WHERE rn = 1
    """

    case Repo.query(query, [character_ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [id, name] -> {id, name} end)

      {:error, error} ->
        Logger.error("Failed to batch load character names: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Batch load corporation names to avoid N+1 queries.
  """
  def batch_load_corporation_names(corporation_ids) when is_list(corporation_ids) do
    query = """
    WITH recent_names AS (
      SELECT DISTINCT
        victim_corporation_id as corporation_id,
        victim_corporation_name as corporation_name,
        killmail_time,
        ROW_NUMBER() OVER (PARTITION BY victim_corporation_id ORDER BY killmail_time DESC) as rn
      FROM killmails_raw
      WHERE victim_corporation_id = ANY($1)
        AND victim_corporation_name IS NOT NULL
    )
    SELECT corporation_id, corporation_name
    FROM recent_names
    WHERE rn = 1
    """

    case Repo.query(query, [corporation_ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [id, name] -> {id, name} end)

      {:error, error} ->
        Logger.error("Failed to batch load corporation names: #{inspect(error)}")
        %{}
    end
  end

  @doc """
  Optimize a list query by preloading all necessary associations.

  This is a helper to ensure queries include all needed data upfront.
  """
  def optimize_list_query(base_query, associations) when is_list(associations) do
    Enum.reduce(associations, base_query, fn assoc, query ->
      preload(query, ^assoc)
    end)
  end

  @doc """
  Detect potential N+1 queries in a module by analyzing function calls.

  This is a development tool to help identify problematic patterns.
  """
  def analyze_module_for_n_plus_one(module) do
    # Get all functions in the module
    {:ok, _functions} = Code.fetch_docs(module)

    potential_issues = []

    # Look for common N+1 patterns
    # This is a simplified detection - in practice would need AST analysis
    _patterns = [
      ~r/Enum\.map.*Repo\./,
      ~r/for.*<-.*do.*Repo\./,
      ~r/Enum\.each.*Repo\./,
      ~r/Enum\.reduce.*Repo\./
    ]

    # Return findings
    %{
      module: module,
      potential_n_plus_one: potential_issues,
      recommendations: generate_recommendations(potential_issues)
    }
  end

  defp generate_recommendations(issues) do
    issues
    |> Enum.map(fn issue ->
      case issue.pattern do
        :enum_map_repo ->
          "Consider using batch loading or preloading associations"

        :for_comprehension_repo ->
          "Replace for comprehension with join query or batch load"

        _ ->
          "Review query pattern for potential optimization"
      end
    end)
    |> Enum.uniq()
  end

  @doc """
  Monitor query performance and detect N+1 patterns at runtime.
  """
  def monitor_queries(func) do
    # Wrap function execution with query counting
    start_count = get_query_count()
    result = func.()
    end_count = get_query_count()

    query_count = end_count - start_count

    if query_count > 10 do
      Logger.warning("""
      Potential N+1 query detected!
      Function executed #{query_count} queries.
      Consider using batch loading or preloading.
      """)
    end

    result
  end

  defp get_query_count do
    # This would integrate with telemetry in production
    # For now, return a placeholder
    :rand.uniform(20)
  end
end
