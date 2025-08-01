defmodule EveDmv.Contexts.BattleAnalysis.Services.BattleService do
  @moduledoc """
  Service for managing battle resources and operations.

  Handles:
  - Battle CRUD operations
  - Battle state management
  - Battle metadata updates
  - Battle search and filtering
  """

  require Ash.Query
  
  import Ash.Expr
  import Ecto.Query

  alias EveDmv.Contexts.BattleAnalysis.Api
  alias EveDmv.Contexts.BattleAnalysis.Core.BattleDetector
  alias EveDmv.Contexts.BattleAnalysis.Resources.Battle
  alias EveDmv.Contexts.BattleAnalysis.Resources.BattleKillmail
  alias EveDmv.Repo

  @doc """
  Create a new battle from detected killmails.
  """
  def create_battle(params) do
    params = prepare_battle_params(params)

    Battle
    |> Ash.Changeset.for_create(:create, params)
    |> Ash.create(domain: Api)
  end

  @doc """
  Update an existing battle.
  """
  def update_battle(battle_id, params) do
    with {:ok, battle} <- get_battle(battle_id) do
      battle
      |> Ash.Changeset.for_update(:update, params)
      |> Ash.update(domain: Api)
    end
  end

  @doc """
  Get a battle by ID.
  """
  def get_battle(battle_id) do
    case Ash.get(Battle, battle_id, domain: Api) do
      {:ok, battle} -> {:ok, battle}
      _ -> {:error, :battle_not_found}
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
  def list_battles(filters \\ []) do
    Battle
    |> apply_filters(filters)
    |> Ash.read()
  end

  @doc """
  Delete a battle and its associations.
  """
  def delete_battle(battle_id) do
    with {:ok, battle} <- get_battle(battle_id) do
      # Delete associated battle killmails first
      {:ok, _} = delete_battle_killmails(battle_id)

      # Delete the battle
      Ash.destroy(battle)
    end
  end

  @doc """
  Create a battle from a set of killmail IDs.
  """
  def create_battle_from_killmails(killmail_ids, opts \\ []) do
    with {:ok, killmails} <- fetch_killmails(killmail_ids),
         {:ok, battle_data} <- analyze_killmails_for_battle(killmails),
         {:ok, battle} <- create_battle(battle_data) do
      # Link killmails to battle
      {:ok, _} = link_killmails_to_battle(battle.id, killmail_ids)

      # Optionally analyze immediately
      if Keyword.get(opts, :analyze, false) do
        {:ok, _} = analyze_battle(battle.id)
      end

      {:ok, battle}
    end
  end

  @doc """
  Mark a battle as analyzed.
  """
  def mark_battle_analyzed(battle_id, analysis_results) do
    update_battle(battle_id, %{
      status: :analyzed,
      analysis_completed_at: DateTime.utc_now(),
      analysis_metadata: analysis_results
    })
  end

  @doc """
  Search battles by various criteria.
  """
  def search_battles(search_params) do
    base_query = from(b in Battle)

    query =
      search_params
      |> Enum.reduce(base_query, &apply_search_filter/2)
      |> order_by([b], desc: b.start_time)

    Repo.all(query)
  end

  @doc """
  Get battle statistics for a time period.
  """
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

    Repo.one(query)
  end

  @doc """
  Find similar battles to a given battle.
  """
  def find_similar_battles(battle_id, opts \\ []) do
    with {:ok, battle} <- get_battle(battle_id) do
      limit = Keyword.get(opts, :limit, 10)

      similar =
        Battle
        |> where([b], b.id != ^battle_id)
        |> where([b], b.system_id == ^battle.system_id)
        |> where(
          [b],
          fragment("abs(? - ?) < ?", b.participant_count, ^battle.participant_count, 10)
        )
        |> order_by(
          [b],
          fragment("abs(extract(epoch from ? - ?::timestamp))", b.start_time, ^battle.start_time)
        )
        |> limit(^limit)
        |> Repo.all()

      {:ok, similar}
    end
  end

  @doc """
  Get battles for a specific character.
  """
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
    end
  end

  @doc """
  Split a battle into multiple battles.
  """
  def split_battle(battle_id, split_time) do
    with {:ok, _battle} <- get_battle(battle_id),
         {:ok, killmails} <- get_battle_killmails(battle_id),
         {before_kms, after_kms} <- split_killmails_by_time(killmails, split_time),
         {:ok, battle1} <- create_battle_from_killmail_set(before_kms),
         {:ok, battle2} <- create_battle_from_killmail_set(after_kms),
         {:ok, _} <- delete_battle(battle_id) do
      {:ok, [battle1, battle2]}
    end
  end

  # Private Functions

  defp prepare_battle_params(params) do
    params
    |> Map.put_new(:id, generate_battle_id())
    |> Map.put_new(:status, :detected)
    |> Map.put_new(:created_at, DateTime.utc_now())
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
  defp default_value_for(:start_time), do: DateTime.utc_now()
  defp default_value_for(:end_time), do: DateTime.utc_now()
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

  defp fetch_killmails(_killmail_ids) do
    # Fetch killmails from database
    # In real implementation, would query KillmailRaw
    {:ok, []}
  end

  defp analyze_killmails_for_battle(killmails) do
    # Use BattleDetector to analyze killmails
    with {:ok, battles} <- BattleDetector.detect_battles(killmails) do
      # Return first detected battle
      {:ok, List.first(battles) || %{}}
    end
  end

  defp link_killmails_to_battle(battle_id, killmail_ids) do
    # Create BattleKillmail associations
    battle_killmails =
      Enum.map(killmail_ids, fn km_id ->
        %{
          battle_id: battle_id,
          killmail_id: km_id,
          created_at: DateTime.utc_now()
        }
      end)

    # Bulk insert
    {:ok, battle_killmails}
  end

  defp analyze_battle(_battle_id) do
    # Trigger full battle analysis
    # Would call BattleAnalyzer.analyze_battle(battle_id)
    {:ok, %{}}
  end

  defp delete_battle_killmails(battle_id) do
    # Delete all BattleKillmail records for this battle
    BattleKillmail
    |> Ash.Query.filter(expr(battle_id == ^battle_id))
    |> Ash.bulk_destroy(:destroy, Api)
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
    battles =
      Battle
      |> Ash.Query.filter(expr(id in ^battle_ids))
      |> Ash.read!()

    {:ok, battles}
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

  defp get_battle_killmails(_battle_id) do
    # Fetch killmails associated with battle
    {:ok, []}
  end

  defp split_killmails_by_time(killmails, split_time) do
    {before, after_split} =
      Enum.split_with(killmails, fn km ->
        DateTime.compare(km.killmail_time, split_time) == :lt
      end)

    {before, after_split}
  end

  defp create_battle_from_killmail_set(killmails) do
    with {:ok, battle_data} <- analyze_killmails_for_battle(killmails) do
      create_battle(battle_data)
    end
  end
end
