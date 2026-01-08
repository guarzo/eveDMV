defmodule EveDmv.Platform.Database.CharacterQueries do
  @moduledoc """
  Optimized queries for character analysis.

  Uses materialized views and efficient indexing to avoid expensive JSONB operations.
  """

  alias EveDmv.Platform.Database.Pagination
  alias EveDmv.Repo
  require Logger

  @doc """
  Get character's recent activity without expensive JSONB operations.
  Supports pagination.
  """
  def get_recent_activity(character_id, opts \\ []) do
    # Optimized: Uses participants table instead of JSONB extraction
    base_query = """
    SELECT
      p.killmail_id,
      p.killmail_time,
      k.solar_system_id,
      CASE WHEN p.is_victim THEN 'loss' ELSE 'kill' END as involvement_type,
      p.ship_type_id,
      COALESCE(k.total_value, 0) as total_value
    FROM participants p
    JOIN killmails_raw k ON k.killmail_id = p.killmail_id
      AND k.killmail_time = p.killmail_time
    WHERE p.character_id = $1
    ORDER BY p.killmail_time DESC
    """

    # Handle both old limit-based and new pagination-based calls
    case opts do
      limit when is_integer(limit) ->
        # Legacy support
        query = base_query <> " LIMIT $2"

        case Repo.query(query, [character_id, limit]) do
          {:ok, %{rows: rows}} ->
            map_activity_rows(rows)

          {:error, error} ->
            Logger.error("Failed to get recent activity: #{inspect(error)}")
            []
        end

      opts when is_list(opts) ->
        # New pagination support
        result =
          Pagination.paginated_query(
            base_query,
            [character_id],
            opts
          )

        %{
          data: map_activity_rows(result.data),
          pagination: result.pagination
        }
    end
  end

  defp map_activity_rows(rows) do
    Enum.map(rows, fn row ->
      case row do
        [km_id, km_time, system_id, involvement, ship_id, value] ->
          %{
            killmail_id: km_id,
            killmail_time: km_time,
            solar_system_id: system_id,
            involvement_type: involvement,
            ship_type_id: ship_id,
            total_value: Decimal.to_float(value || Decimal.new(0))
          }

        [km_id, km_time, system_id, involvement, ship_id] ->
          # Legacy format without value
          %{
            killmail_id: km_id,
            killmail_time: km_time,
            solar_system_id: system_id,
            involvement_type: involvement,
            ship_type_id: ship_id,
            total_value: 0.0
          }
      end
    end)
  end

  @doc """
  Get character name from recent killmails.
  """
  def get_character_name_from_killmails(character_id) do
    # Optimized: Uses participants table instead of JSONB extraction
    query = """
    SELECT p.character_name
    FROM participants p
    WHERE p.character_id = $1
      AND p.character_name IS NOT NULL
    ORDER BY p.killmail_time DESC
    LIMIT 1
    """

    case Repo.query(query, [character_id]) do
      {:ok, %{rows: [[name]]}} when name != nil -> name
      _ -> nil
    end
  end

  @doc """
  Get corporation and alliance info from killmails.
  """
  def get_character_affiliations(character_id) do
    # Optimized: Uses participants table instead of JSONB extraction
    query = """
    SELECT
      p.corporation_name,
      p.corporation_id,
      p.alliance_name,
      p.alliance_id
    FROM participants p
    WHERE p.character_id = $1
      AND p.corporation_id IS NOT NULL
    ORDER BY p.killmail_time DESC
    LIMIT 1
    """

    case Repo.query(query, [character_id]) do
      {:ok, %{rows: [[corp_name, corp_id, alliance_name, alliance_id]]}} ->
        %{
          corporation_name: corp_name,
          corporation_id: corp_id,
          alliance_name: alliance_name,
          alliance_id: alliance_id
        }

      _ ->
        %{
          corporation_name: nil,
          corporation_id: nil,
          alliance_name: nil,
          alliance_id: nil
        }
    end
  end
end
