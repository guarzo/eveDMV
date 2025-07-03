defmodule EveDmv.Database.QueryUtils do
  @moduledoc """
  Common Ash query patterns and utilities used across intelligence modules.

  This module consolidates repeated database query patterns to provide
  consistent querying interfaces and reduce code duplication.
  """

  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterAnalysis.CharacterStats
  alias EveDmv.Killmails.{KillmailEnriched, Participant}

  @doc """
  Query killmails by corporation within a date range.

  ## Options

  * `:load` - List of associations to preload (default: `[:participants]`)
  * `:limit` - Maximum number of results (default: no limit)
  * `:order_by` - Field to order by (default: `:killmail_time`)

  ## Examples

      iex> query_killmails_by_corporation(12345, ~D[2024-01-01], ~D[2024-01-31])
      {:ok, [%KillmailEnriched{}, ...]}
  """
  def query_killmails_by_corporation(corporation_id, start_date, end_date, opts \\ []) do
    load_assocs = Keyword.get(opts, :load, [:participants])
    limit = Keyword.get(opts, :limit)
    order_by = Keyword.get(opts, :order_by, :killmail_time)

    query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.load(load_assocs)
      |> Ash.Query.filter(killmail_time >= ^start_date)
      |> Ash.Query.filter(killmail_time <= ^end_date)
      |> Ash.Query.filter(exists(participants, corporation_id == ^corporation_id))
      |> Ash.Query.sort([{order_by, :desc}])

    query =
      if limit do
        Ash.Query.limit(query, limit)
      else
        query
      end

    Ash.read(query, domain: Api)
  end

  @doc """
  Query killmails by character within a date range.

  ## Options

  * `:load` - List of associations to preload (default: `[:participants]`)
  * `:limit` - Maximum number of results (default: no limit)
  * `:order_by` - Field to order by (default: `:killmail_time`)

  ## Examples

      iex> query_killmails_by_character(98765, ~D[2024-01-01], ~D[2024-01-31])
      {:ok, [%KillmailEnriched{}, ...]}
  """
  def query_killmails_by_character(character_id, start_date, end_date, opts \\ []) do
    load_assocs = Keyword.get(opts, :load, [:participants])
    limit = Keyword.get(opts, :limit)
    order_by = Keyword.get(opts, :order_by, :killmail_time)

    query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.load(load_assocs)
      |> Ash.Query.filter(killmail_time >= ^start_date)
      |> Ash.Query.filter(killmail_time <= ^end_date)
      |> Ash.Query.filter(exists(participants, character_id == ^character_id))
      |> Ash.Query.sort([{order_by, :desc}])

    query =
      if limit do
        Ash.Query.limit(query, limit)
      else
        query
      end

    Ash.read(query, domain: Api)
  end

  @doc """
  Query participants by character within a date range.

  Returns participant records with optional killmail data loaded.

  ## Options

  * `:load` - List of associations to preload (default: `[:killmail_enriched]`)
  * `:limit` - Maximum number of results (default: no limit)

  ## Examples

      iex> query_participants_by_character(98765, ~D[2024-01-01], ~D[2024-01-31])
      {:ok, [%Participant{}, ...]}
  """
  def query_participants_by_character(character_id, start_date, end_date, opts \\ []) do
    load_assocs = Keyword.get(opts, :load, [:killmail_enriched])
    limit = Keyword.get(opts, :limit)

    query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^start_date)
      |> Ash.Query.filter(updated_at <= ^end_date)
      |> Ash.Query.load(load_assocs)
      |> Ash.Query.sort([{:updated_at, :desc}])

    query =
      if limit do
        Ash.Query.limit(query, limit)
      else
        query
      end

    Ash.read(query, domain: Api)
  end

  @doc """
  Query participants for specific killmails.

  ## Options

  * `:exclude_character` - Character ID to exclude from results
  * `:load` - List of associations to preload (default: `[]`)

  ## Examples

      iex> query_killmail_participants([123, 456, 789])
      {:ok, [%Participant{}, ...]}
      
      iex> query_killmail_participants([123], exclude_character: 98765)
      {:ok, [%Participant{}, ...]}
  """
  def query_killmail_participants(killmail_ids, opts \\ []) when is_list(killmail_ids) do
    exclude_character = Keyword.get(opts, :exclude_character)
    load_assocs = Keyword.get(opts, :load, [])

    query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(killmail_id in ^killmail_ids)
      |> Ash.Query.load(load_assocs)

    query =
      if exclude_character do
        Ash.Query.filter(query, character_id != ^exclude_character)
      else
        query
      end

    Ash.read(query, domain: Api)
  end

  @doc """
  Query corporation members (character stats).

  ## Options

  * `:load` - List of associations to preload (default: `[]`)
  * `:active_only` - Filter to only active members (default: `false`)

  ## Examples

      iex> query_corporation_members(12345)
      {:ok, [%CharacterStats{}, ...]}
  """
  def query_corporation_members(corporation_id, opts \\ []) do
    load_assocs = Keyword.get(opts, :load, [])
    active_only = Keyword.get(opts, :active_only, false)

    query =
      CharacterStats
      |> Ash.Query.new()
      |> Ash.Query.filter(corporation_id == ^corporation_id)
      |> Ash.Query.load(load_assocs)

    query =
      if active_only do
        # Add filter for active members (example: last seen within 30 days)
        cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)
        Ash.Query.filter(query, last_seen >= ^cutoff_date)
      else
        query
      end

    Ash.read(query, domain: Api)
  end

  @doc """
  Calculate a safe percentage avoiding division by zero.

  ## Examples

      iex> safe_percentage(75, 100)
      75.0
      
      iex> safe_percentage(1, 3, 2)
      33.33
      
      iex> safe_percentage(5, 0)
      0.0
  """
  def safe_percentage(numerator, denominator, precision \\ 1)
  def safe_percentage(_numerator, 0, _precision), do: 0.0

  def safe_percentage(numerator, denominator, precision) when denominator > 0 do
    Float.round(numerator / denominator * 100, precision)
  end

  @doc """
  Calculate date range from current time going back specified days.

  ## Examples

      iex> calculate_date_range(30)
      {~U[2024-06-01 12:00:00Z], ~U[2024-07-01 12:00:00Z]}
  """
  def calculate_date_range(days_back) when is_integer(days_back) do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_back, :day)
    {start_date, end_date}
  end

  @doc """
  Calculate date range from current time going back specified days in seconds.

  Used for more precise time calculations that need hour/minute precision.

  ## Examples

      iex> calculate_precise_date_range(90)
      {~U[2024-04-01 12:00:00Z], ~U[2024-07-01 12:00:00Z]}
  """
  def calculate_precise_date_range(days_back) when is_integer(days_back) do
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -days_back * 24 * 60 * 60, :second)
    {start_date, end_date}
  end

  @doc """
  Check if a solar system ID represents a wormhole (J-space) system.

  ## Examples

      iex> wormhole_system?(31000001)
      true
      
      iex> wormhole_system?(30000142)
      false
  """
  def wormhole_system?(system_id) when is_integer(system_id) do
    system_id >= 31_000_000
  end

  @doc """
  Group killmails by time periods.

  ## Examples

      iex> group_killmails_by_timeframe(killmails, :day)
      %{"2024-07-01" => [%KillmailEnriched{}, ...], ...}
      
      iex> group_killmails_by_timeframe(killmails, :hour)
      %{0 => [%KillmailEnriched{}, ...], 12 => [...], ...}
  """
  def group_killmails_by_timeframe(killmails, timeframe) when is_list(killmails) do
    case timeframe do
      :day ->
        Enum.group_by(killmails, fn km ->
          Date.to_string(DateTime.to_date(km.killmail_time))
        end)

      :hour ->
        Enum.group_by(killmails, fn km ->
          km.killmail_time.hour
        end)

      :month ->
        Enum.group_by(killmails, fn km ->
          date = DateTime.to_date(km.killmail_time)
          "#{date.year}-#{String.pad_leading(to_string(date.month), 2, "0")}"
        end)

      :system ->
        Enum.group_by(killmails, fn km ->
          km.solar_system_id
        end)

      _ ->
        %{}
    end
  end

  @doc """
  Filter killmails to wormhole systems only.

  ## Examples

      iex> filter_wormhole_killmails(killmails)
      [%KillmailEnriched{solar_system_id: 31000001}, ...]
  """
  def filter_wormhole_killmails(killmails) when is_list(killmails) do
    Enum.filter(killmails, fn km -> wormhole_system?(km.solar_system_id) end)
  end

  @doc """
  Calculate days between two DateTime structs.

  ## Examples

      iex> days_between(~U[2024-06-01 12:00:00Z], ~U[2024-07-01 12:00:00Z])
      30
  """
  def days_between(start_datetime, end_datetime)
      when is_struct(start_datetime, DateTime) and is_struct(end_datetime, DateTime) do
    DateTime.diff(end_datetime, start_datetime, :day)
  end

  @doc """
  Calculate days since a given DateTime.

  ## Examples

      iex> days_since(~U[2024-06-01 12:00:00Z])
      30
  """
  def days_since(datetime) when is_struct(datetime, DateTime) do
    days_between(datetime, DateTime.utc_now())
  end

  @doc """
  Calculate hours between two DateTime structs.

  ## Examples

      iex> hours_between(~U[2024-07-01 12:00:00Z], ~U[2024-07-01 15:00:00Z])
      3
  """
  def hours_between(start_datetime, end_datetime)
      when is_struct(start_datetime, DateTime) and is_struct(end_datetime, DateTime) do
    DateTime.diff(end_datetime, start_datetime, :hour)
  end
end
