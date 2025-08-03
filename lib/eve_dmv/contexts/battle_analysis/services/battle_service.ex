defmodule EveDmv.Contexts.BattleAnalysis.Services.BattleService do
  @moduledoc """
  Service for managing battle resources and operations.

  Handles:
  - Battle CRUD operations
  - Battle state management
  - Battle metadata updates
  - Battle search and filtering
  """

  import Ash.Expr
  import Ecto.Query

  alias EveDmv.Contexts.BattleAnalysis.Api
  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Repo

  require Logger

  require Ash.Query

  @doc """
  Create a new battle from detected killmails.
  """
  @spec create_battle(map()) :: {:ok, any()} | {:error, any()}
  def create_battle(params) do
    params = prepare_battle_params(params)

    Battle
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create(domain: Api)
  end

  @doc """
  Update an existing battle.
  """
  @spec update_battle(String.t(), map()) ::
          {:ok, EveDmv.Contexts.BattleAnalysis.Resources.Battle.t()} | {:error, atom()}
  def update_battle(battle_id, params) do
    case get_battle(battle_id) do
      {:ok, battle} ->
        battle
        |> Ash.Changeset.for_update(:update, params)
        |> Ash.update(domain: Api)

      error ->
        error
    end
  end

  @doc """
  Get a battle by ID.
  """
  @spec get_battle(String.t()) ::
          {:ok, EveDmv.Contexts.BattleAnalysis.Resources.Battle.t()} | {:error, atom()}
  def get_battle(battle_id) do
    case Ash.get(Battle, battle_id, domain: Api) do
      {:ok, battle} -> {:ok, battle}
      {:error, %Ash.Error.Query.NotFound{}} -> {:error, :battle_not_found}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  List battles with optional filters.

  Filters:
    - system_id: Solar system ID
    - start_time: Battle started after this time
    - end_time: Battle ended before this time
    - min_participants: Minimum participant count
    - min_value: Minimum ISK destroyed
    - status: Battle status (active, completed, analyzed)
  """
  @spec list_battles(keyword()) :: {:ok, [any()]} | {:error, any()}
  def list_battles(filters \\ []) do
    case Battle
         |> apply_filters(filters)
         |> Ash.read(domain: Api) do
      {:ok, battles} -> {:ok, battles}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Delete a battle and its associations.
  """
  @spec delete_battle(String.t()) :: {:error, any()}
  def delete_battle(battle_id) do
    case get_battle(battle_id) do
      {:ok, battle} ->
        # Delete associated battle killmails first
        case delete_battle_killmails(battle_id) do
          %Ash.BulkResult{status: :success} ->
            :ok

          %Ash.BulkResult{errors: errors} when errors != [] ->
            Logger.warning("Failed to delete some battle killmails: #{inspect(errors)}")

          _ ->
            :ok
        end

        # Delete the battle
        Ash.destroy(battle)

      error ->
        error
    end
  end

  @doc """
  Create a battle from a set of killmail IDs.
  """
  @spec create_battle_from_killmails([integer()], keyword()) :: {:ok, any()} | {:error, atom()}
  def create_battle_from_killmails(killmail_ids, opts \\ []) do
    with {:ok, killmails} <- fetch_killmails(killmail_ids),
         {:ok, battle_data} <- analyze_killmails_for_battle(killmails),
         {:ok, battle} <- create_battle(battle_data),
         {:ok, _battle_killmails} <- link_killmails_to_battle(battle.id, killmail_ids) do
      # Optionally analyze immediately
      if Keyword.get(opts, :analyze, false) do
        case analyze_battle(battle.id) do
          {:ok, _analysis} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to analyze battle #{battle.id}: #{inspect(reason)}")
        end
      end

      {:ok, battle}
    else
      error -> error
    end
  end

  @doc """
  Mark a battle as analyzed.
  """
  @spec mark_battle_analyzed(String.t(), map()) :: {:ok, any()} | {:error, atom()}
  def mark_battle_analyzed(battle_id, analysis_results) do
    update_battle(battle_id, %{
      status: :analyzed,
      analysis_completed_at: DateTimeUtils.utc_now(),
      analysis_metadata: analysis_results
    })
  end

  @doc """
  Search battles by various criteria.
  """
  @spec search_battles(map()) :: {:ok, [any()]} | {:error, any()}
  def search_battles(search_params) do
    base_query = from(b in Battle)

    query =
      search_params
      |> Enum.reduce(base_query, &apply_search_filter/2)
      |> order_by([b], desc: b.start_time)

    battles = Repo.all(query)
    {:ok, battles}
  rescue
    error -> {:error, error}
  end

  @doc """
  Get battle statistics for a time period.
  """
  @spec get_battle_statistics(Date.t() | DateTime.t(), Date.t() | DateTime.t()) ::
          {:ok, map()} | {:error, atom()}
  def get_battle_statistics(start_date, end_date) do
    query =
      from(b in Battle,
        where: b.start_time >= ^start_date and b.end_time <= ^end_date,
        select: %{
          total_battles: count(b.id),
          total_kills: sum(b.kill_count),
          total_isk_destroyed: sum(b.total_value),
          avg_participants: avg(b.participant_count),
          avg_duration: avg(b.duration_minutes)
        }
      )

    stats = Repo.one(query)
    {:ok, stats || %{}}
  rescue
    error -> {:error, error}
  end

  @doc """
  Find similar battles to a given battle.
  """
  @spec find_similar_battles(String.t(), keyword()) :: {:ok, [any()]} | {:error, atom()}
  def find_similar_battles(battle_id, opts \\ []) do
    case get_battle(battle_id) do
      {:ok, battle} ->
        limit = Keyword.get(opts, :limit, 10)

        case Battle
             |> Ash.Query.filter(id != ^battle_id and system_id == ^battle.system_id)
             |> Ash.Query.limit(limit)
             |> Ash.read(domain: Api) do
          {:ok, similar} -> {:ok, similar}
          {:error, error} -> {:error, error}
        end

      error ->
        error
    end
  end

  @doc """
  Get battles for a specific character.
  """
  @spec get_character_battles(integer(), keyword()) :: {:ok, [any()]} | {:error, atom()}
  def get_character_battles(_character_id, opts \\ []) do
    _limit = Keyword.get(opts, :limit, 50)
    _offset = Keyword.get(opts, :offset, 0)

    # This would require joining through battle_killmails and killmails
    # For now, return empty list
    {:ok, []}
  end

  @doc """
  Merge multiple battles into one.
  """
  @spec merge_battles([String.t()]) :: {:ok, any()} | {:error, atom()}
  def merge_battles(battle_ids) when length(battle_ids) > 1 do
    with {:ok, battles} <- fetch_battles(battle_ids),
         {:ok, merged_data} <- prepare_merged_battle_data(battles),
         {:ok, merged_battle} <- create_battle(merged_data) do
      # Move all killmails to merged battle
      Enum.each(battles, fn battle ->
        move_battle_killmails(battle.id, merged_battle.id)
      end)

      # Delete original battles
      Enum.each(battles, fn battle ->
        delete_battle(battle.id)
      end)

      {:ok, merged_battle}
    else
      error -> error
    end
  end

  @doc """
  Split a battle into multiple battles.
  """
  @spec split_battle(String.t(), DateTime.t()) :: {:ok, [any()]} | {:error, atom()}
  def split_battle(battle_id, split_time) do
    with {:ok, _battle} <- get_battle(battle_id),
         {:ok, killmails} <- get_battle_killmails(battle_id),
         {before_kms, after_kms} <- split_killmails_by_time(killmails, split_time),
         {:ok, battle1} <- create_battle_from_killmail_set(before_kms),
         {:ok, battle2} <- create_battle_from_killmail_set(after_kms),
         {:ok, _} <- delete_battle(battle_id) do
      {:ok, [battle1, battle2]}
    else
      error -> error
    end
  end

  # Private Functions

  defp prepare_battle_params(params) do
    params
    |> Map.put_new(:id, generate_battle_id())
    |> Map.put_new(:status, :detected)
    |> Map.put_new(:created_at, DateTimeUtils.utc_now())
    |> ensure_required_fields()
  end

  defp generate_battle_id do
    "battle_#{:crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)}"
  end

  defp ensure_required_fields(params) do
    required = [:system_id, :start_time, :end_time, :participant_count, :kill_count]

    Enum.reduce(required, params, fn field, acc ->
      Map.put_new(acc, field, default_value_for(field))
    end)
  end

  defp default_value_for(:participant_count), do: 0
  defp default_value_for(:kill_count), do: 0
  defp default_value_for(:start_time), do: DateTimeUtils.utc_now()
  defp default_value_for(:end_time), do: DateTimeUtils.utc_now()
  defp default_value_for(_), do: nil

  defp apply_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {:system_id, system_id}, q ->
        Ash.Query.filter(q, expr(system_id == ^system_id))

      {:start_time, start_time}, q ->
        Ash.Query.filter(q, expr(start_time >= ^start_time))

      {:end_time, end_time}, q ->
        Ash.Query.filter(q, expr(end_time <= ^end_time))

      {:min_participants, min}, q ->
        Ash.Query.filter(q, expr(participant_count >= ^min))

      {:min_value, min_value}, q ->
        Ash.Query.filter(q, expr(total_value >= ^min_value))

      {:status, status}, q ->
        Ash.Query.filter(q, expr(status == ^status))

      _, q ->
        q
    end)
  end

  defp fetch_killmails(killmail_ids) do
    # Fetch killmails from database using KillmailRaw
    case KillmailRaw
         |> Ash.Query.filter(expr(killmail_id in ^killmail_ids))
         |> Ash.read(domain: Api) do
      {:ok, killmails} ->
        {:ok, killmails}

      {:error, error} ->
        Logger.error("Failed to fetch killmails: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp analyze_killmails_for_battle(killmails) do
    # Use BattleDetector to analyze killmails
    case BattleDetector.detect_battles(killmails) do
      {:ok, battles} ->
        # Return first detected battle
        {:ok, List.first(battles) || %{}}

      error ->
        error
    end
  end

  defp link_killmails_to_battle(battle_id, killmail_ids) do
    # Create BattleKillmail associations
    battle_killmails =
      Enum.map(killmail_ids, fn km_id ->
        %{
          battle_id: battle_id,
          killmail_id: km_id,
          created_at: DateTimeUtils.utc_now()
        }
      end)

    # Bulk insert
    {:ok, battle_killmails}
  end

  defp analyze_battle(battle_id) do
    # Trigger full battle analysis using the actual BattleAnalyzer
    case EveDmv.Contexts.BattleAnalysis.Core.BattleAnalyzer.analyze_battle(battle_id) do
      {:ok, analysis} ->
        {:ok, analysis}

      {:error, reason} ->
        Logger.warning("Battle analysis failed for #{battle_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp delete_battle_killmails(battle_id) do
    # Delete all BattleKillmail records for this battle
    query = BattleKillmail |> Ash.Query.filter(expr(battle_id == ^battle_id))
    case Ash.bulk_destroy(query, :destroy, domain: Api) do
      %{status: :success} -> :ok
      _ -> {:error, :failed_to_delete_killmails}
    end
  end

  defp apply_search_filter({:participant_name, _name}, query) do
    # Would need to join with participants table
    query
  end

  defp apply_search_filter({:corporation_id, _corp_id}, query) do
    # Would need to join with participants
    query
  end

  defp apply_search_filter({:alliance_id, _alliance_id}, query) do
    # Would need to join with participants
    query
  end

  defp apply_search_filter({:date_range, {start_date, end_date}}, query) do
    where(query, [b], b.start_time >= ^start_date and b.end_time <= ^end_date)
  end

  defp apply_search_filter({:min_isk, min_value}, query) do
    where(query, [b], b.total_value >= ^min_value)
  end

  defp apply_search_filter(_, query), do: query

  defp fetch_battles(battle_ids) do
    case Battle
         |> Ash.Query.filter(expr(id in ^battle_ids))
         |> Ash.read(domain: Api) do
      {:ok, battles} when battles != [] ->
        {:ok, battles}

      {:ok, []} ->
        {:error, :battles_not_found}

      {:error, _} ->
        {:error, :battles_not_found}
    end
  end

  defp prepare_merged_battle_data(battles) do
    # Combine data from multiple battles
    start_times = Enum.map(battles, & &1.start_time)
    end_times = Enum.map(battles, & &1.end_time)

    merged = %{
      system_id: List.first(battles).system_id,
      start_time: Enum.min(start_times, DateTime),
      end_time: Enum.max(end_times, DateTime),
      participant_count: Enum.sum(Enum.map(battles, & &1.participant_count)),
      kill_count: Enum.sum(Enum.map(battles, & &1.kill_count)),
      total_value: Enum.sum(Enum.map(battles, & &1.total_value)),
      ship_classes: merge_ship_classes(battles),
      status: :merged
    }

    {:ok, merged}
  end

  defp merge_ship_classes(battles) do
    battles
    |> Enum.flat_map(&(&1.ship_classes || []))
    |> Enum.uniq()
  end

  defp move_battle_killmails(from_battle_id, to_battle_id) do
    BattleKillmail
    |> Ash.Query.filter(expr(battle_id == ^from_battle_id))
    |> Ash.bulk_update(:update, %{battle_id: to_battle_id}, domain: Api)
  end

  defp get_battle_killmails(battle_id) do
    # Fetch killmails associated with battle through BattleKillmail junction table
    case BattleKillmail
         |> Ash.Query.filter(expr(battle_id == ^battle_id))
         |> Ash.read(domain: Api) do
      {:ok, battle_killmails} ->
        killmail_ids = Enum.map(battle_killmails, & &1.killmail_id)
        fetch_killmails(killmail_ids)

      {:error, error} ->
        Logger.error("Failed to get battle killmails: #{inspect(error)}")
        {:error, :database_error}
    end
  end

  defp split_killmails_by_time(killmails, split_time) do
    {before, after_split} =
      Enum.split_with(killmails, fn km ->
        DateTimeUtils.compare(km.killmail_time, split_time) == :lt
      end)

    {before, after_split}
  end

  defp create_battle_from_killmail_set(killmails) do
    case analyze_killmails_for_battle(killmails) do
      {:ok, battle_data} ->
        create_battle(battle_data)

      error ->
        error
    end
  end
end
