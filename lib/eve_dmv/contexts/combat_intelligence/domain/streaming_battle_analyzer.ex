defmodule EveDmv.Contexts.CombatIntelligence.Domain.StreamingBattleAnalyzer do
  @moduledoc """
  Streaming battle analysis optimized for large dataset processing.

  This module provides streaming implementations for battle analysis operations
  that need to process large amounts of killmail data efficiently without
  loading everything into memory at once.

  Key optimizations:
  - Cursor-based pagination for large killmail datasets
  - Stream-based processing to reduce memory footprint
  - Chunked batch operations for database efficiency
  - Async processing for CPU-intensive analysis
  """

  use GenServer
  require Logger

  alias EveDmv.Repo

  # Configuration constants
  @default_batch_size 1000
  @default_chunk_size 500
  @stream_timeout 30_000
  @max_concurrent_streams 4

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Stream large battle analysis with cursor-based pagination.

  Processes battle data in manageable chunks to avoid memory issues
  when analyzing very large battles or long time periods.

  ## Options
  - `:batch_size` - Number of killmails to process per batch (default: 1000)
  - `:chunk_size` - Size of processing chunks (default: 500)
  - `:analysis_types` - List of analysis types to perform
  - `:progress_callback` - Function to call with progress updates

  ## Examples

      {:ok, stream} = StreamingBattleAnalyzer.stream_battle_analysis(
        system_id: 30000142,
        start_time: ~U[2024-01-01 00:00:00Z],
        end_time: ~U[2024-01-02 00:00:00Z],
        batch_size: 1000
      )
      
      results = Enum.to_list(stream)
  """
  def stream_battle_analysis(params, opts \\ []) do
    GenServer.call(__MODULE__, {:stream_analysis, params, opts}, @stream_timeout)
  end

  @doc """
  Stream killmail processing with optimized memory usage.

  Uses cursor-based pagination to process large killmail datasets
  without loading all data into memory at once.
  """
  def stream_killmail_processing(query_params, processor_fn, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:stream_killmails, query_params, processor_fn, opts},
      @stream_timeout
    )
  end

  @doc """
  Stream timeline analysis for very large battles.

  Processes timeline events in streaming fashion to handle
  battles with thousands of killmails efficiently.
  """
  def stream_timeline_analysis(battle_params, opts \\ []) do
    GenServer.call(__MODULE__, {:stream_timeline, battle_params, opts}, @stream_timeout)
  end

  @doc """
  Stream multi-battle comparative analysis.

  Processes multiple battles in parallel streams for
  comparative analysis without memory limitations.
  """
  def stream_comparative_analysis(battle_ids, analysis_functions, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:stream_comparative, battle_ids, analysis_functions, opts},
      @stream_timeout
    )
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      active_streams: %{},
      stream_counter: 0,
      metrics: %{
        streams_created: 0,
        total_records_processed: 0,
        average_processing_time: 0
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:stream_analysis, params, opts}, from, state) do
    stream_id = generate_stream_id(state)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    Logger.info("Starting streaming battle analysis #{stream_id} with batch_size=#{batch_size}")

    # Create the stream using Task.Supervisor for concurrent processing
    stream =
      Task.Supervisor.async_stream_nolink(
        EveDmv.TaskSupervisor,
        create_killmail_cursor_stream(params, batch_size),
        fn batch -> process_killmail_batch(batch, opts) end,
        max_concurrency: @max_concurrent_streams,
        timeout: @stream_timeout,
        on_timeout: :kill_task
      )

    updated_state = %{
      state
      | stream_counter: state.stream_counter + 1,
        active_streams:
          Map.put(state.active_streams, stream_id, %{
            started_at: DateTime.utc_now(),
            params: params,
            opts: opts,
            from: from
          }),
        metrics: %{
          state.metrics
          | streams_created: state.metrics.streams_created + 1
        }
    }

    {:reply, {:ok, stream}, updated_state}
  end

  @impl GenServer
  def handle_call({:stream_killmails, query_params, processor_fn, opts}, _from, state) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    stream =
      create_killmail_cursor_stream(query_params, batch_size)
      |> Stream.map(processor_fn)
      |> Stream.chunk_every(Keyword.get(opts, :chunk_size, @default_chunk_size))

    {:reply, {:ok, stream}, state}
  end

  @impl GenServer
  def handle_call({:stream_timeline, battle_params, opts}, _from, state) do
    stream = stream_timeline_events(battle_params, opts)
    {:reply, {:ok, stream}, state}
  end

  @impl GenServer
  def handle_call({:stream_comparative, battle_ids, analysis_functions, opts}, _from, state) do
    # Create parallel streams for each battle
    streams =
      battle_ids
      |> Enum.map(fn battle_id ->
        Task.Supervisor.async_stream_nolink(
          EveDmv.TaskSupervisor,
          analysis_functions,
          fn analysis_fn -> analysis_fn.(battle_id, opts) end,
          max_concurrency: 2,
          timeout: @stream_timeout
        )
      end)

    combined_stream = Stream.concat(streams)

    {:reply, {:ok, combined_stream}, state}
  end

  # Private functions for streaming implementation

  defp generate_stream_id(state) do
    "stream_#{state.stream_counter + 1}_#{:erlang.unique_integer([:positive])}"
  end

  defp create_killmail_cursor_stream(params, batch_size) do
    Stream.resource(
      # Start function - initialize cursor
      fn ->
        initial_cursor = %{
          last_killmail_id: 0,
          last_killmail_time: params[:start_time],
          batch_size: batch_size,
          total_processed: 0
        }

        {initial_cursor, false}
      end,

      # Next function - fetch next batch
      fn {cursor, done} ->
        if done do
          {:halt, cursor}
        else
          case fetch_killmail_batch(cursor, params) do
            {:ok, []} ->
              # No more data
              {:halt, cursor}

            {:ok, killmails} when length(killmails) < batch_size ->
              # Last batch
              updated_cursor = update_cursor(cursor, killmails)
              {[killmails], {updated_cursor, true}}

            {:ok, killmails} ->
              # More data available
              updated_cursor = update_cursor(cursor, killmails)
              {[killmails], {updated_cursor, false}}

            {:error, reason} ->
              Logger.error("Error fetching killmail batch: #{inspect(reason)}")
              {:halt, cursor}
          end
        end
      end,

      # Stop function - cleanup
      fn cursor ->
        Logger.debug("Streaming completed. Total processed: #{cursor.total_processed}")
        cursor
      end
    )
  end

  defp fetch_killmail_batch(cursor, params) do
    # Build optimized query with cursor pagination
    base_query = """
    SELECT 
      killmail_id,
      killmail_time,
      killmail_hash,
      solar_system_id,
      victim_character_id,
      victim_corporation_id,
      victim_alliance_id,
      victim_ship_type_id,
      attacker_count,
      raw_data,
      source
    FROM killmails_raw
    WHERE 1=1
    """

    {query, query_params} = build_cursor_query(base_query, cursor, params)

    case Ecto.Adapters.SQL.query(Repo, query, query_params) do
      {:ok, %{rows: rows}} ->
        killmails =
          rows
          |> Enum.map(&map_killmail_row/1)
          |> Enum.sort_by(& &1.killmail_time, DateTime)

        {:ok, killmails}

      {:error, error} ->
        {:error, error}
    end
  rescue
    error ->
      Logger.error("Exception in fetch_killmail_batch: #{inspect(error)}")
      {:error, :fetch_failed}
  end

  defp build_cursor_query(base_query, cursor, params) do
    conditions = []
    query_params = []
    param_count = 0

    # Add cursor conditions for pagination
    {conditions, query_params, param_count} =
      if cursor.last_killmail_id > 0 do
        condition =
          "(killmail_time > $#{param_count + 1} OR (killmail_time = $#{param_count + 2} AND killmail_id > $#{param_count + 3}))"

        {[condition | conditions],
         query_params ++
           [cursor.last_killmail_time, cursor.last_killmail_time, cursor.last_killmail_id],
         param_count + 3}
      else
        {conditions, query_params, param_count}
      end

    # Add filter conditions
    {conditions, query_params, param_count} =
      case params[:system_id] do
        nil ->
          {conditions, query_params, param_count}

        system_id ->
          condition = "solar_system_id = $#{param_count + 1}"
          {[condition | conditions], query_params ++ [system_id], param_count + 1}
      end

    {conditions, query_params, param_count} =
      case params[:start_time] do
        nil ->
          {conditions, query_params, param_count}

        start_time ->
          condition = "killmail_time >= $#{param_count + 1}"
          {[condition | conditions], query_params ++ [start_time], param_count + 1}
      end

    {conditions, query_params, _param_count} =
      case params[:end_time] do
        nil ->
          {conditions, query_params, param_count}

        end_time ->
          condition = "killmail_time <= $#{param_count + 1}"
          {[condition | conditions], query_params ++ [end_time], param_count + 1}
      end

    # Build final query
    where_clause =
      if Enum.empty?(conditions), do: "", else: " AND " <> Enum.join(conditions, " AND ")

    order_clause = " ORDER BY killmail_time ASC, killmail_id ASC"
    limit_clause = " LIMIT #{cursor.batch_size}"

    final_query = base_query <> where_clause <> order_clause <> limit_clause

    {final_query, query_params}
  end

  defp map_killmail_row([
         killmail_id,
         killmail_time,
         killmail_hash,
         solar_system_id,
         victim_character_id,
         victim_corporation_id,
         victim_alliance_id,
         victim_ship_type_id,
         attacker_count,
         raw_data,
         source
       ]) do
    %{
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      killmail_hash: killmail_hash,
      solar_system_id: solar_system_id,
      victim_character_id: victim_character_id,
      victim_corporation_id: victim_corporation_id,
      victim_alliance_id: victim_alliance_id,
      victim_ship_type_id: victim_ship_type_id,
      attacker_count: attacker_count,
      raw_data: raw_data,
      source: source,
      # Extract derived fields
      total_value: get_in(raw_data, ["zkb", "totalValue"]) || 0,
      attackers: raw_data["attackers"] || [],
      victim: raw_data["victim"] || %{}
    }
  end

  defp update_cursor(cursor, killmails) do
    if Enum.empty?(killmails) do
      cursor
    else
      last_killmail = List.last(killmails)

      %{
        cursor
        | last_killmail_id: last_killmail.killmail_id,
          last_killmail_time: last_killmail.killmail_time,
          total_processed: cursor.total_processed + length(killmails)
      }
    end
  end

  defp process_killmail_batch(killmails, opts) do
    analysis_types = Keyword.get(opts, :analysis_types, [:basic_metrics])

    results = %{}

    # Process different analysis types
    results =
      if :basic_metrics in analysis_types do
        Map.put(results, :basic_metrics, calculate_basic_metrics(killmails))
      else
        results
      end

    results =
      if :timeline_analysis in analysis_types do
        Map.put(results, :timeline_analysis, analyze_timeline_chunk(killmails))
      else
        results
      end

    results =
      if :participant_analysis in analysis_types do
        Map.put(results, :participant_analysis, analyze_participants_chunk(killmails))
      else
        results
      end

    # Add batch metadata
    Map.put(results, :batch_info, %{
      killmail_count: length(killmails),
      time_span: calculate_time_span(killmails),
      processed_at: DateTime.utc_now()
    })
  end

  defp stream_timeline_events(battle_params, opts) do
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    create_killmail_cursor_stream(battle_params, batch_size)
    |> Stream.flat_map(fn killmails ->
      # Convert each killmail to timeline events
      Enum.flat_map(killmails, &extract_timeline_events/1)
    end)
    |> Stream.chunk_every(Keyword.get(opts, :chunk_size, @default_chunk_size))
    |> Stream.map(&analyze_timeline_chunk/1)
  end

  defp extract_timeline_events(killmail) do
    [
      %{
        type: :killmail,
        timestamp: killmail.killmail_time,
        killmail_id: killmail.killmail_id,
        system_id: killmail.solar_system_id,
        victim_ship_type: killmail.victim_ship_type_id,
        attacker_count: killmail.attacker_count,
        total_value: killmail.total_value
      }
    ]
  end

  defp analyze_timeline_chunk(events) when is_list(events) do
    %{
      event_count: length(events),
      time_span: calculate_event_time_span(events),
      peak_activity: calculate_peak_activity(events),
      average_engagement_size: calculate_average_engagement_size(events)
    }
  end

  defp calculate_basic_metrics(killmails) do
    total_value = killmails |> Enum.map(& &1.total_value) |> Enum.sum()

    unique_attackers =
      killmails
      |> Enum.flat_map(& &1.attackers)
      |> Enum.map(&get_in(&1, ["character_id"]))
      |> Enum.filter(& &1)
      |> Enum.uniq()
      |> length()

    %{
      total_killmails: length(killmails),
      total_isk_destroyed: total_value,
      unique_attackers: unique_attackers,
      average_value: if(length(killmails) > 0, do: div(total_value, length(killmails)), else: 0),
      time_span: calculate_time_span(killmails)
    }
  end

  defp analyze_participants_chunk(killmails) do
    all_participants =
      killmails
      |> Enum.flat_map(fn km ->
        attackers =
          Enum.map(km.attackers, fn attacker ->
            %{
              character_id: get_in(attacker, ["character_id"]),
              corporation_id: get_in(attacker, ["corporation_id"]),
              alliance_id: get_in(attacker, ["alliance_id"]),
              ship_type_id: get_in(attacker, ["ship_type_id"]),
              role: :attacker
            }
          end)

        victim = [
          %{
            character_id: km.victim_character_id,
            corporation_id: km.victim_corporation_id,
            alliance_id: km.victim_alliance_id,
            ship_type_id: km.victim_ship_type_id,
            role: :victim
          }
        ]

        attackers ++ victim
      end)
      |> Enum.filter(fn p -> not is_nil(p.character_id) end)

    %{
      total_participants: length(all_participants),
      unique_characters:
        all_participants |> Enum.map(& &1.character_id) |> Enum.uniq() |> length(),
      unique_corporations:
        all_participants |> Enum.map(& &1.corporation_id) |> Enum.uniq() |> length(),
      unique_alliances:
        all_participants
        |> Enum.map(& &1.alliance_id)
        |> Enum.filter(& &1)
        |> Enum.uniq()
        |> length(),
      ship_type_distribution: calculate_ship_distribution(all_participants)
    }
  end

  defp calculate_ship_distribution(participants) do
    participants
    |> Enum.group_by(& &1.ship_type_id)
    |> Enum.map(fn {ship_type_id, group} -> {ship_type_id, length(group)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    # Top 10 most used ships
    |> Enum.take(10)
  end

  defp calculate_time_span(killmails) when length(killmails) > 0 do
    times = Enum.map(killmails, & &1.killmail_time)
    min_time = Enum.min(times, DateTime)
    max_time = Enum.max(times, DateTime)
    DateTime.diff(max_time, min_time, :second)
  end

  defp calculate_time_span(_), do: 0

  defp calculate_event_time_span(events) when length(events) > 0 do
    timestamps = Enum.map(events, & &1.timestamp)
    min_time = Enum.min(timestamps, DateTime)
    max_time = Enum.max(timestamps, DateTime)
    DateTime.diff(max_time, min_time, :second)
  end

  defp calculate_event_time_span(_), do: 0

  defp calculate_peak_activity(events) do
    # Group events into 1-minute windows and find peak
    events
    |> Enum.group_by(fn event ->
      event.timestamp
      |> DateTime.to_unix()
      # 1-minute windows
      |> div(60)
    end)
    |> Enum.map(fn {_window, window_events} -> length(window_events) end)
    |> Enum.max(fn -> 0 end)
  end

  defp calculate_average_engagement_size(events) do
    total_participants = events |> Enum.map(& &1.attacker_count) |> Enum.sum()
    if length(events) > 0, do: div(total_participants, length(events)), else: 0
  end
end
