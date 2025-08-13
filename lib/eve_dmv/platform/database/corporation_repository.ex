defmodule EveDmv.Platform.Database.CorporationRepository do
  @moduledoc """
  Corporation data repository for database queries.

  Provides centralized access to corporation-related data
  from the database with optimized queries.
  """

  alias EveDmv.Api
  alias EveDmv.Contexts.Corporation.Resources.ActivityMetric
  alias EveDmv.Contexts.Corporation.Resources.Corporation
  alias EveDmv.Contexts.Corporation.Resources.CorporationMember
  alias EveDmv.Repo

  require Logger
  require Ash.Query

  @doc """
  Get all members of a corporation.

  Returns a list of corporation members with their basic information based on killmail data.
  """
  def get_corporation_members(corporation_id) when is_integer(corporation_id) do
    # Use raw SQL to handle JSONB array elements properly
    query = """
    WITH victim_members AS (
      SELECT DISTINCT
        victim_character_id as character_id,
        victim_character_name as character_name,
        victim_corporation_id as corporation_id,
        victim_corporation_name as corporation_name,
        victim_alliance_id as alliance_id,
        victim_alliance_name as alliance_name,
        MAX(killmail_time) as last_seen
      FROM killmails_raw
      WHERE victim_corporation_id = $1
        AND victim_character_id IS NOT NULL
      GROUP BY victim_character_id, victim_character_name, victim_corporation_id,
               victim_corporation_name, victim_alliance_id, victim_alliance_name
    ),
    attacker_members AS (
      SELECT DISTINCT
        (attacker->>'character_id')::bigint as character_id,
        attacker->>'character_name' as character_name,
        (attacker->>'corporation_id')::bigint as corporation_id,
        attacker->>'corporation_name' as corporation_name,
        (attacker->>'alliance_id')::bigint as alliance_id,
        attacker->>'alliance_name' as alliance_name,
        MAX(killmail_time) as last_seen
      FROM killmails_raw, jsonb_array_elements(attackers) as attacker
      WHERE (attacker->>'corporation_id')::bigint = $1
        AND attacker->>'character_id' IS NOT NULL
      GROUP BY (attacker->>'character_id')::bigint, attacker->>'character_name',
               (attacker->>'corporation_id')::bigint, attacker->>'corporation_name',
               (attacker->>'alliance_id')::bigint, attacker->>'alliance_name'
    ),
    all_members AS (
      SELECT * FROM victim_members
      UNION
      SELECT * FROM attacker_members
    )
    SELECT
      character_id,
      character_name,
      corporation_id,
      corporation_name,
      alliance_id,
      alliance_name,
      MAX(last_seen) as last_seen
    FROM all_members
    WHERE character_id IS NOT NULL
    GROUP BY character_id, character_name, corporation_id, corporation_name, alliance_id, alliance_name
    ORDER BY last_seen DESC
    """

    case Repo.query(query, [corporation_id]) do
      {:ok, %{rows: rows}} ->
        members =
          Enum.map(rows, fn [
                              char_id,
                              char_name,
                              corp_id,
                              corp_name,
                              alliance_id,
                              alliance_name,
                              last_seen
                            ] ->
            %{
              character_id: char_id,
              character_name: char_name,
              corporation_id: corp_id,
              corporation_name: corp_name,
              alliance_id: alliance_id,
              alliance_name: alliance_name,
              last_seen: last_seen
            }
          end)

        {:ok, members}

      {:error, error} ->
        Logger.error("Failed to get corporation members for #{corporation_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to get corporation members for #{corporation_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def get_corporation_members(_), do: {:error, :invalid_corporation_id}

  @doc """
  Get corporation basic information.
  """
  def get_corporation_info(corporation_id) when is_integer(corporation_id) do
    # Use raw SQL to get corporation info
    query = """
    WITH corp_from_victims AS (
      SELECT DISTINCT
        victim_corporation_id as corporation_id,
        victim_corporation_name as corporation_name,
        victim_alliance_id as alliance_id,
        victim_alliance_name as alliance_name
      FROM killmails_raw
      WHERE victim_corporation_id = $1
        AND victim_corporation_name IS NOT NULL
      LIMIT 1
    ),
    corp_from_attackers AS (
      SELECT DISTINCT
        (attacker->>'corporation_id')::bigint as corporation_id,
        attacker->>'corporation_name' as corporation_name,
        (attacker->>'alliance_id')::bigint as alliance_id,
        attacker->>'alliance_name' as alliance_name
      FROM killmails_raw, jsonb_array_elements(attackers) as attacker
      WHERE (attacker->>'corporation_id')::bigint = $1
        AND attacker->>'corporation_name' IS NOT NULL
      LIMIT 1
    )
    SELECT corporation_id, corporation_name, alliance_id, alliance_name
    FROM corp_from_victims
    UNION ALL
    SELECT corporation_id, corporation_name, alliance_id, alliance_name
    FROM corp_from_attackers
    LIMIT 1
    """

    case Repo.query(query, [corporation_id]) do
      {:ok, %{rows: [[corp_id, corp_name, alliance_id, alliance_name]]}} ->
        # Get member count
        {:ok, members} = get_corporation_members(corporation_id)

        {:ok,
         %{
           corporation_id: corp_id,
           name: corp_name || "Unknown Corporation",
           member_count: length(members),
           alliance_id: alliance_id,
           alliance_name: alliance_name,
           # We don't have ticker data in killmails
           ticker: "CORP"
         }}

      {:ok, %{rows: []}} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to get corporation info for #{corporation_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to get corporation info for #{corporation_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def get_corporation_info(_), do: {:error, :invalid_corporation_id}

  @doc """
  Get corporation activity statistics.
  """
  def get_corporation_activity_stats(corporation_id, start_date \\ nil) do
    start_date = start_date || Date.add(Date.utc_today(), -30)

    case ActivityMetric
         |> Ash.Query.filter(corporation_id == ^corporation_id and metric_date >= ^start_date)
         |> Ash.Query.sort(desc: :metric_date)
         |> Ash.read(domain: EveDmv.Api) do
      {:ok, metrics} when metrics != [] ->
        latest_metric = List.first(metrics)

        total_stats =
          Enum.reduce(
            metrics,
            %{kills: 0, losses: 0, isk_destroyed: 0.0, isk_lost: 0.0},
            fn metric, acc ->
              %{
                kills: acc.kills + (metric.total_kills || 0),
                losses: acc.losses + (metric.total_losses || 0),
                isk_destroyed: acc.isk_destroyed + (metric.isk_destroyed || 0.0),
                isk_lost: acc.isk_lost + (metric.isk_lost || 0.0)
              }
            end
          )

        isk_efficiency =
          if total_stats.isk_lost > 0 do
            total_stats.isk_destroyed / (total_stats.isk_destroyed + total_stats.isk_lost)
          else
            1.0
          end

        {:ok,
         %{
           total_kills: total_stats.kills,
           total_losses: total_stats.losses,
           isk_efficiency: isk_efficiency,
           active_members: latest_metric.active_members || 0,
           last_activity: latest_metric.metric_date
         }}

      {:ok, []} ->
        # No metrics found, return empty stats
        {:ok,
         %{
           total_kills: 0,
           total_losses: 0,
           isk_efficiency: 0.0,
           active_members: 0,
           last_activity: start_date
         }}

      {:error, error} ->
        Logger.error(
          "Failed to get corporation activity stats for #{corporation_id}: #{inspect(error)}"
        )

        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error(
        "Failed to get corporation activity stats for #{corporation_id}: #{inspect(error)}"
      )

      {:error, :query_failed}
  end

  @doc """
  Get corporation statistics including member count and activity.
  """
  def get_corporation_stats(corporation_id) when is_integer(corporation_id) do
    with {:ok, corp_info} <- get_corporation_analytics(corporation_id),
         {:ok, activity_stats} <- get_corporation_activity_stats(corporation_id) do
      member_count =
        case corp_info.member_count do
          nil -> 0
          count -> count
        end

      {:ok,
       %{
         corporation_id: corporation_id,
         member_count: member_count,
         active_members_30d: activity_stats.active_members,
         total_kills_30d: activity_stats.total_kills,
         total_losses_30d: activity_stats.total_losses,
         isk_efficiency_30d: activity_stats.isk_efficiency
       }}
    else
      {:error, reason} ->
        Logger.error("Failed to get corporation stats for #{corporation_id}: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Failed to get corporation stats for #{corporation_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def get_corporation_stats(_), do: {:error, :invalid_corporation_id}

  @doc """
  Get a specific corporation member.
  """
  def get_corporation_member(member_id) when is_integer(member_id) do
    case CorporationMember
         |> Ash.Query.filter(character_id == ^member_id)
         |> Ash.read_one(domain: Api) do
      {:ok, member} when not is_nil(member) ->
        {:ok,
         %{
           character_id: member.character_id,
           character_name: member.character_name,
           corporation_id: member.corporation_id,
           join_date: member.join_date,
           last_seen: member.last_seen,
           status: member.status,
           roles: member.roles,
           title: member.title,
           recent_activity_score: member.recent_activity_score,
           total_kills: member.total_kills,
           total_losses: member.total_losses,
           isk_destroyed: member.isk_destroyed,
           isk_lost: member.isk_lost,
           flight_risk_score: member.flight_risk_score,
           integration_score: member.integration_score,
           retention_risk: member.retention_risk
         }}

      {:ok, nil} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to get corporation member #{member_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to get corporation member #{member_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def get_corporation_member(_), do: {:error, :invalid_member_id}

  @doc """
  Update corporation member information.
  """
  def update_corporation_member(member_id, attrs) when is_integer(member_id) and is_map(attrs) do
    case CorporationMember
         |> Ash.Query.filter(character_id == ^member_id)
         |> Ash.read_one(domain: Api) do
      {:ok, member} when not is_nil(member) ->
        case Ash.update(member, attrs, domain: EveDmv.Api) do
          {:ok, updated_member} ->
            {:ok,
             %{
               character_id: updated_member.character_id,
               character_name: updated_member.character_name,
               corporation_id: updated_member.corporation_id,
               status: updated_member.status,
               roles: updated_member.roles,
               title: updated_member.title,
               recent_activity_score: updated_member.recent_activity_score,
               updated_at: updated_member.updated_at
             }}

          {:error, error} ->
            Logger.error("Failed to update corporation member #{member_id}: #{inspect(error)}")
            {:error, :update_failed}
        end

      {:ok, nil} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to find corporation member #{member_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to update corporation member #{member_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def update_corporation_member(_, _), do: {:error, :invalid_parameters}

  @doc """
  Add a new corporation member.
  """
  def add_corporation_member(corporation_id, character_id)
      when is_integer(corporation_id) and is_integer(character_id) do
    # First check if corporation exists
    case Corporation
         |> Ash.Query.filter(corporation_id == ^corporation_id)
         |> Ash.read_one(domain: Api) do
      {:ok, corp} when not is_nil(corp) ->
        # Create new member
        member_attrs = %{
          corporation_id: corporation_id,
          character_id: character_id,
          # Placeholder - should be fetched from ESI
          character_name: "Character #{character_id}",
          join_date: DateTime.utc_now(),
          status: :active
        }

        case Ash.create(CorporationMember, member_attrs, domain: EveDmv.Api) do
          {:ok, member} ->
            {:ok,
             %{
               character_id: member.character_id,
               character_name: member.character_name,
               corporation_id: member.corporation_id,
               join_date: member.join_date,
               status: member.status
             }}

          {:error, error} ->
            Logger.error(
              "Failed to add corporation member to #{corporation_id}: #{inspect(error)}"
            )

            {:error, :create_failed}
        end

      {:ok, nil} ->
        {:error, :corporation_not_found}

      {:error, error} ->
        Logger.error("Failed to find corporation #{corporation_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to add corporation member to #{corporation_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def add_corporation_member(_, _), do: {:error, :invalid_parameters}

  @doc """
  Remove a corporation member.
  """
  def remove_corporation_member(member_id) when is_integer(member_id) do
    case CorporationMember
         |> Ash.Query.filter(character_id == ^member_id)
         |> Ash.read_one(domain: Api) do
      {:ok, member} when not is_nil(member) ->
        case Ash.destroy(member, domain: EveDmv.Api) do
          :ok ->
            {:ok, %{character_id: member_id, removed: true}}

          {:error, error} ->
            Logger.error("Failed to remove corporation member #{member_id}: #{inspect(error)}")
            {:error, :delete_failed}
        end

      {:ok, nil} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to find corporation member #{member_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to remove corporation member #{member_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def remove_corporation_member(_), do: {:error, :invalid_member_id}

  @doc """
  Create a new corporation record.
  """
  def create_corporation(attrs) when is_map(attrs) do
    case Ash.create(Corporation, attrs, domain: EveDmv.Api) do
      {:ok, corp} ->
        {:ok,
         %{
           id: corp.id,
           corporation_id: corp.corporation_id,
           corporation_name: corp.corporation_name,
           ticker: corp.ticker,
           alliance_id: corp.alliance_id,
           alliance_name: corp.alliance_name,
           member_count: corp.member_count,
           recruitment_status: corp.recruitment_status,
           created_at: corp.created_at
         }}

      {:error, error} ->
        Logger.error("Failed to create corporation: #{inspect(error)}")
        {:error, :create_failed}
    end
  rescue
    error ->
      Logger.error("Failed to create corporation: #{inspect(error)}")
      {:error, :query_failed}
  end

  def create_corporation(_), do: {:error, :invalid_attributes}

  @doc """
  Update corporation information.
  """
  def update_corporation(corporation_id, attrs)
      when is_integer(corporation_id) and is_map(attrs) do
    case Corporation
         |> Ash.Query.filter(corporation_id == ^corporation_id)
         |> Ash.read_one(domain: Api) do
      {:ok, corp} when not is_nil(corp) ->
        case Ash.update(corp, attrs, domain: EveDmv.Api) do
          {:ok, updated_corp} ->
            {:ok,
             %{
               corporation_id: updated_corp.corporation_id,
               corporation_name: updated_corp.corporation_name,
               ticker: updated_corp.ticker,
               alliance_id: updated_corp.alliance_id,
               alliance_name: updated_corp.alliance_name,
               member_count: updated_corp.member_count,
               recruitment_status: updated_corp.recruitment_status,
               updated_at: updated_corp.updated_at
             }}

          {:error, error} ->
            Logger.error("Failed to update corporation #{corporation_id}: #{inspect(error)}")
            {:error, :update_failed}
        end

      {:ok, nil} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error("Failed to find corporation #{corporation_id}: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to update corporation #{corporation_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def update_corporation(_, _), do: {:error, :invalid_parameters}

  @doc """
  Search corporations by various criteria.
  """
  def search_corporations(params) when is_map(params) do
    query = Corporation |> Ash.Query.new()

    # Apply filters based on search params
    query =
      case Map.get(params, :name) do
        nil ->
          query

        name when is_binary(name) ->
          Ash.Query.filter(query, contains(corporation_name, ^name))
      end

    query =
      case Map.get(params, :ticker) do
        nil ->
          query

        ticker when is_binary(ticker) ->
          Ash.Query.filter(query, ticker == ^ticker)
      end

    query =
      case Map.get(params, :alliance_id) do
        nil ->
          query

        alliance_id when is_integer(alliance_id) ->
          Ash.Query.filter(query, alliance_id == ^alliance_id)
      end

    query =
      case Map.get(params, :recruitment_status) do
        nil ->
          query

        status when status in [:open, :selective, :closed] ->
          Ash.Query.filter(query, recruitment_status == ^status)
      end

    query =
      case Map.get(params, :min_members) do
        nil ->
          query

        min_members when is_integer(min_members) ->
          Ash.Query.filter(query, member_count >= ^min_members)
      end

    # Apply sorting
    query =
      case Map.get(params, :sort_by, :corporation_name) do
        :corporation_name -> Ash.Query.sort(query, [:corporation_name])
        :member_count -> Ash.Query.sort(query, desc: :member_count)
        :activity_score -> Ash.Query.sort(query, desc: :avg_activity_score)
        _ -> Ash.Query.sort(query, [:corporation_name])
      end

    # Apply limit
    limit = Map.get(params, :limit, 50)
    query = Ash.Query.limit(query, limit)

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, corporations} ->
        results =
          Enum.map(corporations, fn corp ->
            %{
              corporation_id: corp.corporation_id,
              corporation_name: corp.corporation_name,
              ticker: corp.ticker,
              alliance_id: corp.alliance_id,
              alliance_name: corp.alliance_name,
              member_count: corp.member_count,
              recruitment_status: corp.recruitment_status,
              avg_activity_score: corp.avg_activity_score
            }
          end)

        {:ok, results}

      {:error, error} ->
        Logger.error("Failed to search corporations: #{inspect(error)}")
        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to search corporations: #{inspect(error)}")
      {:error, :query_failed}
  end

  def search_corporations(_), do: {:error, :invalid_search_params}

  @doc """
  Get corporation by ID.
  """
  def get_corporation(corporation_id) when is_integer(corporation_id) do
    get_corporation_info(corporation_id)
  end

  def get_corporation(_), do: {:error, :invalid_corporation_id}

  @doc """
  Get corporation analytics data with member information.
  """
  def get_corporation_analytics(corporation_id) when is_integer(corporation_id) do
    case Corporation
         |> Ash.Query.filter(corporation_id == ^corporation_id)
         |> Ash.Query.load([:members, :activity_metrics])
         |> Ash.read_one(domain: Api) do
      {:ok, corp} when not is_nil(corp) ->
        # Calculate analytics from loaded data
        members = corp.members || []

        analytics = %{
          corporation_id: corp.corporation_id,
          corporation_name: corp.corporation_name,
          ticker: corp.ticker,
          alliance_id: corp.alliance_id,
          alliance_name: corp.alliance_name,
          member_count: length(members),
          active_members: Enum.count(members, fn m -> m.status == :active end),
          avg_activity_score: corp.avg_activity_score || 0.0,
          last_activity_update: corp.last_activity_update,
          recruitment_status: corp.recruitment_status,
          cached_analytics: corp.cached_analytics || %{},
          analytics_updated_at: corp.analytics_updated_at
        }

        {:ok, analytics}

      {:ok, nil} ->
        {:error, :not_found}

      {:error, error} ->
        Logger.error(
          "Failed to get corporation analytics for #{corporation_id}: #{inspect(error)}"
        )

        {:error, :query_failed}
    end
  rescue
    error ->
      Logger.error("Failed to get corporation analytics for #{corporation_id}: #{inspect(error)}")
      {:error, :query_failed}
  end

  def get_corporation_analytics(_), do: {:error, :invalid_corporation_id}
end
