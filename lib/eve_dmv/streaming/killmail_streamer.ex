defmodule EveDmv.Streaming.KillmailStreamer do
  @moduledoc """
  Memory-efficient streaming module for processing large killmail datasets.

  Provides streaming interfaces for processing killmails without loading
  entire datasets into memory. Supports batch processing, filtering, and
  aggregation operations on streams.
  """

  import Ecto.Query

  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Platform.Cache.MultiLayerCache
  alias EveDmv.Repo
  require Logger

  @default_batch_size 100
  @max_batch_size 1000

  @doc """
  Stream killmails for a time range with automatic batching.

  Options:
  - batch_size: Number of records per batch (default: 100)
  - preload: Associations to preload
  - filter: Additional filter function
  - order_by: Sort order (default: killmail_time)
  """
  def stream_killmails(start_time, end_time, options \\ []) do
    batch_size =
      min(
        Keyword.get(options, :batch_size, @default_batch_size),
        @max_batch_size
      )

    preload = Keyword.get(options, :preload, [])
    filter_fn = Keyword.get(options, :filter, fn _ -> true end)
    order_by = Keyword.get(options, :order_by, asc: :killmail_time)

    base_query =
      from(k in KillmailRaw,
        where: k.killmail_time >= ^start_time and k.killmail_time <= ^end_time,
        order_by: ^order_by
      )

    # Add preloads if specified
    query =
      if preload != [] do
        from(k in base_query, preload: ^preload)
      else
        base_query
      end

    # Create stream with batching
    query
    |> Repo.stream(max_rows: batch_size)
    |> Stream.filter(filter_fn)
    |> Stream.chunk_every(batch_size)
  end

  @doc """
  Stream killmails by character with memory-efficient processing.
  """
  def stream_by_character(character_id, options \\ []) do
    batch_size = Keyword.get(options, :batch_size, @default_batch_size)
    include_attackers = Keyword.get(options, :include_attackers, false)

    if include_attackers do
      stream_with_attacker_participation(character_id, batch_size)
    else
      stream_victim_killmails(character_id, batch_size)
    end
  end

  @doc """
  Process killmails in parallel batches for improved performance.
  """
  def parallel_process(start_time, end_time, process_fn, options \\ []) do
    batch_size = Keyword.get(options, :batch_size, @default_batch_size)
    parallelism = Keyword.get(options, :parallelism, System.schedulers_online())

    stream_killmails(start_time, end_time, batch_size: batch_size)
    |> Task.async_stream(
      process_fn,
      max_concurrency: parallelism,
      timeout: 30_000,
      on_timeout: :kill_task
    )
    |> Stream.map(fn
      {:ok, result} ->
        result

      {:exit, reason} ->
        Logger.error("Task failed: #{inspect(reason)}")
        nil
    end)
    |> Stream.filter(& &1)
  end

  @doc """
  Aggregate killmail statistics with streaming to avoid memory issues.
  """
  def stream_aggregate(start_time, end_time, aggregation_fn, options \\ []) do
    initial_acc = Keyword.get(options, :initial, %{})

    stream_killmails(start_time, end_time, options)
    |> Stream.map(&process_batch_for_aggregation/1)
    |> Enum.reduce(initial_acc, aggregation_fn)
  end

  @doc """
  Stream high-value killmails with caching.
  """
  def stream_high_value_killmails(min_value, options \\ []) do
    cache_key = {:high_value_stream, min_value, options}

    # Check if we have cached results
    case MultiLayerCache.get(cache_key) do
      {:ok, cached_ids} ->
        # Stream from cached IDs
        stream_from_ids(cached_ids, options)

      :miss ->
        # Stream and cache the IDs
        query =
          from(k in KillmailRaw,
            where: k.total_value >= ^min_value,
            order_by: [desc: :total_value],
            select: k.killmail_id
          )

        killmail_ids = Repo.all(query)

        # Cache the IDs for 5 minutes
        MultiLayerCache.put(cache_key, killmail_ids, ttl_ms: 300_000)

        stream_from_ids(killmail_ids, options)
    end
  end

  @doc """
  Export killmails to CSV with streaming.
  """
  def export_to_csv(start_time, end_time, output_path, options \\ []) do
    file = File.open!(output_path, [:write, :utf8])

    try do
      # Write header
      IO.write(file, csv_header())

      # Stream and write data
      stream_killmails(start_time, end_time, options)
      |> Stream.each(fn batch ->
        csv_data = Enum.map_join(batch, "", &to_csv_row/1)
        IO.write(file, csv_data)
      end)
      |> Stream.run()

      Logger.info("Export complete: #{output_path}")
      {:ok, output_path}
    after
      File.close(file)
    end
  end

  @doc """
  Create a lazy stream that yields statistics periodically.
  """
  def stats_stream(start_time, end_time, interval_seconds \\ 60) do
    Stream.resource(
      # Init function
      fn ->
        {start_time,
         %{
           total_kills: 0,
           total_value: 0,
           unique_characters: MapSet.new(),
           unique_systems: MapSet.new()
         }}
      end,

      # Next function
      fn {current_time, stats} = acc ->
        if DateTime.compare(current_time, end_time) == :lt do
          interval_end = DateTime.add(current_time, interval_seconds, :second)

          # Process interval
          new_stats = process_interval(current_time, min(interval_end, end_time), stats)

          # Emit stats and continue
          {[new_stats], {interval_end, new_stats}}
        else
          # End of stream
          {:halt, acc}
        end
      end,

      # Cleanup function
      fn _acc -> :ok end
    )
  end

  # Private functions

  defp stream_victim_killmails(character_id, batch_size) do
    from(k in KillmailRaw,
      where: k.victim_character_id == ^character_id,
      order_by: [desc: :killmail_time]
    )
    |> Repo.stream(max_rows: batch_size)
    |> Stream.chunk_every(batch_size)
  end

  defp stream_with_attacker_participation(character_id, batch_size) do
    # This would require parsing the JSON data field for attackers
    # For performance, we'd want to use a materialized view or separate table
    from(k in KillmailRaw,
      where:
        k.victim_character_id == ^character_id or
          fragment("? @> ?", k.data, ^%{"attackers" => [%{"character_id" => character_id}]}),
      order_by: [desc: :killmail_time]
    )
    |> Repo.stream(max_rows: batch_size)
    |> Stream.chunk_every(batch_size)
  end

  defp stream_from_ids(killmail_ids, options) do
    batch_size = Keyword.get(options, :batch_size, @default_batch_size)

    killmail_ids
    |> Enum.chunk_every(batch_size)
    |> Stream.map(fn id_batch ->
      from(k in KillmailRaw,
        where: k.killmail_id in ^id_batch,
        preload: [:solar_system, :victim_character]
      )
      |> Repo.all()
    end)
  end

  defp process_batch_for_aggregation(batch) do
    %{
      count: length(batch),
      total_value: Enum.sum(Enum.map(batch, & &1.total_value)),
      systems: Enum.map(batch, & &1.solar_system_id) |> Enum.uniq(),
      characters: extract_all_characters(batch)
    }
  end

  defp extract_all_characters(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      victim = [km.victim_character_id]

      attackers =
        case km.data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.map(attackers, & &1["character_id"])

          _ ->
            []
        end

      victim ++ attackers
    end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
  end

  defp csv_header do
    "killmail_id,killmail_time,solar_system_id,victim_character_id,victim_ship_type_id,total_value\\n"
  end

  defp to_csv_row(killmail) do
    [
      killmail.killmail_id,
      killmail.killmail_time,
      killmail.solar_system_id,
      killmail.victim_character_id,
      killmail.victim_ship_type_id,
      killmail.total_value
    ]
    |> Enum.join(",")
    |> Kernel.<>("\\n")
  end

  defp process_interval(start_time, end_time, prev_stats) do
    # Process killmails in the interval
    batch_stats =
      stream_killmails(start_time, end_time, batch_size: 500)
      |> Enum.reduce(
        %{kills: 0, value: 0, characters: MapSet.new(), systems: MapSet.new()},
        fn batch, acc ->
          %{
            kills: acc.kills + length(batch),
            value: acc.value + Enum.sum(Enum.map(batch, & &1.total_value)),
            characters: MapSet.union(acc.characters, MapSet.new(extract_all_characters(batch))),
            systems: MapSet.union(acc.systems, MapSet.new(Enum.map(batch, & &1.solar_system_id)))
          }
        end
      )

    # Merge with previous stats
    %{
      interval: {start_time, end_time},
      interval_kills: batch_stats.kills,
      interval_value: batch_stats.value,
      total_kills: prev_stats.total_kills + batch_stats.kills,
      total_value: prev_stats.total_value + batch_stats.value,
      unique_characters: MapSet.union(prev_stats.unique_characters, batch_stats.characters),
      unique_systems: MapSet.union(prev_stats.unique_systems, batch_stats.systems)
    }
  end
end
