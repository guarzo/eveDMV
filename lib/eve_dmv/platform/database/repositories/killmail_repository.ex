defmodule EveDmv.Platform.Database.Repositories.KillmailRepository do
  @moduledoc """
  Repository for killmail data access using Ash Framework.
  Replaces direct Ecto queries with Ash patterns.
  """

  use EveDmv.Core.Contracts.RepositoryBehaviour, resource: EveDmv.Killmails.KillmailRaw

  import Ash.Query

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  require Logger

  @doc """
  Get killmails for a specific battle
  """
  def get_battle_killmails(killmail_ids) when is_list(killmail_ids) do
    KillmailRaw
    |> new()
    |> filter(killmail_id in ^killmail_ids)
    |> sort(killmail_time: :asc)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Get recent killmails for a character
  """
  def get_character_killmails(character_id, opts \\ []) do
    days_back = Keyword.get(opts, :days_back, 30)
    limit_count = Keyword.get(opts, :limit, 100)

    cutoff_date = DateTime.add(DateTime.utc_now(), -(days_back * 24 * 60 * 60), :second)

    KillmailRaw
    |> new()
    |> filter(victim_character_id == ^character_id and killmail_time >= ^cutoff_date)
    |> sort(killmail_time: :desc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Get killmails in a system within a time range
  """
  def get_system_killmails(system_id, start_time, end_time, opts \\ []) do
    limit_count = Keyword.get(opts, :limit, 500)

    KillmailRaw
    |> new()
    |> filter(
      solar_system_id == ^system_id and
        killmail_time >= ^start_time and
        killmail_time <= ^end_time
    )
    |> sort(killmail_time: :asc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Get killmails for a corporation
  """
  def get_corporation_killmails(corp_id, opts \\ []) do
    days_back = Keyword.get(opts, :days_back, 30)
    limit_count = Keyword.get(opts, :limit, 100)

    cutoff_date = DateTime.add(DateTime.utc_now(), -(days_back * 24 * 60 * 60), :second)

    KillmailRaw
    |> new()
    |> filter(victim_corporation_id == ^corp_id and killmail_time >= ^cutoff_date)
    |> sort(killmail_time: :desc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Count killmails in a time range
  """
  def count_killmails_in_range(start_time, end_time, opts \\ []) do
    query =
      KillmailRaw
      |> new()
      |> filter(killmail_time >= ^start_time and killmail_time <= ^end_time)

    query_with_system =
      case Keyword.get(opts, :system_id) do
        nil -> query
        system_id -> filter(query, solar_system_id == ^system_id)
      end

    final_query =
      case Keyword.get(opts, :character_id) do
        nil -> query_with_system
        char_id -> filter(query_with_system, victim_character_id == ^char_id)
      end

    Ash.count(final_query, domain: EveDmv.Api)
  end

  @doc """
  Get high-value killmails
  """
  def get_high_value_killmails(min_value, opts \\ []) do
    limit_count = Keyword.get(opts, :limit, 100)
    days_back = Keyword.get(opts, :days_back, 7)

    cutoff_date = DateTime.add(DateTime.utc_now(), -(days_back * 24 * 60 * 60), :second)

    KillmailRaw
    |> new()
    |> filter(total_value >= ^min_value and killmail_time >= ^cutoff_date)
    |> sort(total_value: :desc, killmail_time: :desc)
    |> limit(limit_count)
    |> Ash.read(domain: EveDmv.Api)
  end

  @doc """
  Stream killmails for batch processing
  """
  def stream_killmails(opts \\ []) do
    batch_size = Keyword.get(opts, :batch_size, 1000)

    base_query = KillmailRaw |> new()

    query_with_start =
      case Keyword.get(opts, :start_date) do
        nil -> base_query
        date -> filter(base_query, killmail_time >= ^date)
      end

    final_query =
      case Keyword.get(opts, :end_date) do
        nil -> query_with_start
        date -> filter(query_with_start, killmail_time <= ^date)
      end

    # Since Api.stream! doesn't exist, we'll read and chunk manually
    final_query
    |> Ash.read!(domain: EveDmv.Api)
    |> Stream.chunk_every(batch_size)
  end

  @doc """
  Bulk insert killmails using Ash bulk operations
  """
  def bulk_insert_killmails(killmail_data) when is_list(killmail_data) do
    case Ash.bulk_create(killmail_data, KillmailRaw, :create,
           upsert?: true,
           upsert_identity: :unique_killmail_id,
           return_errors?: true,
           batch_size: 500,
           domain: Api
         ) do
      %Ash.BulkResult{status: :success} = result ->
        # Use length of records if available, otherwise count errors to infer success count
        count = if result.records, do: length(result.records), else: "batch of"
        Logger.info("Successfully inserted #{count} killmails")
        {:ok, result}

      %Ash.BulkResult{status: :partial_success} = result ->
        Logger.warning("Partially inserted killmails. Errors: #{inspect(result.errors)}")
        {:partial, result}

      %Ash.BulkResult{errors: errors} = result ->
        Logger.error("Failed to insert killmails: #{inspect(errors)}")
        {:error, result}
    end
  end

  # Override the default filter application for more complex queries
  defp apply_filters(query, filters) when is_list(filters) do
    Enum.reduce(filters, query, fn
      {:victim_character_id, char_id}, q ->
        filter(q, victim_character_id == ^char_id)

      {:victim_corporation_id, corp_id}, q ->
        filter(q, victim_corporation_id == ^corp_id)

      {:victim_alliance_id, alliance_id}, q ->
        filter(q, victim_alliance_id == ^alliance_id)

      {:solar_system_id, system_id}, q ->
        filter(q, solar_system_id == ^system_id)

      {:min_value, value}, q ->
        filter(q, total_value >= ^value)

      {:max_value, value}, q ->
        filter(q, total_value <= ^value)

      {:time_range, {start_time, end_time}}, q ->
        filter(q, killmail_time >= ^start_time and killmail_time <= ^end_time)

      {_field, _value}, q ->
        # Generic field/value filter - not yet implemented
        q
    end)
  end
end
