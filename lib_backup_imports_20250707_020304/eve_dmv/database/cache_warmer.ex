# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Database.CacheWarmer do
  use GenServer

    alias EveDmv.Eve.ItemType
  alias EveDmv.Api
  alias EveDmv.Database.QueryCache
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.IntelligenceMigrationAdapter
  alias EveDmv.Killmails.KillmailEnriched

  require Ash.Query
  require Logger
  @moduledoc """
  Intelligent cache warming for frequently accessed data.

  Pre-populates caches with commonly requested data to improve response times
  and reduce database load during peak usage.
  """



  @warming_interval :timer.minutes(30)
  @batch_size 100

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def warm_cache do
    GenServer.cast(__MODULE__, :warm_cache)
  end

  def warm_specific(cache_type, ids) when is_list(ids) do
    GenServer.cast(__MODULE__, {:warm_specific, cache_type, ids})
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server callbacks

  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      stats: %{
        total_warmed: 0,
        last_warm_at: nil,
        warm_duration_ms: 0,
        items_warmed: %{}
      }
    }

    if state.enabled do
      schedule_warming()
      # Initial warming after startup
      Process.send_after(self(), :warm_cache, :timer.seconds(10))
    end

    {:ok, state}
  end

  def handle_cast(:warm_cache, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn -> perform_warming(self()) end)
    end

    {:noreply, state}
  end

  def handle_cast({:warm_specific, cache_type, ids}, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn ->
        warm_specific_items(cache_type, ids)
      end)
    end

    {:noreply, state}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  def handle_info(:scheduled_warm, state) do
    if state.enabled do
      Task.Supervisor.start_child(EveDmv.TaskSupervisor, fn -> perform_warming(self()) end)
      schedule_warming()
    end

    {:noreply, state}
  end

  def handle_info({:warming_complete, stats}, state) do
    new_stats = %{
      total_warmed: state.stats.total_warmed + stats.total_items,
      last_warm_at: DateTime.utc_now(),
      warm_duration_ms: stats.duration_ms,
      items_warmed: Map.merge(state.stats.items_warmed, stats.items_by_type)
    }

    {:noreply, %{state | stats: new_stats}}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_warming do
    Process.send_after(self(), :scheduled_warm, @warming_interval)
  end

  defp perform_warming(parent_pid) do
    start_time = System.monotonic_time(:millisecond)
    Logger.info("Starting intelligent cache warming")

    # Warm different cache types concurrently with supervised tasks
    tasks = [
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_hot_characters() end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_active_systems() end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_recent_killmails() end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_frequent_items() end),
      Task.Supervisor.async(EveDmv.TaskSupervisor, fn -> warm_alliance_stats() end)
    ]

    results = Task.await_many(tasks, :timer.minutes(5))

    total_items = Enum.sum(results)
    duration_ms = System.monotonic_time(:millisecond) - start_time

    stats = %{
      total_items: total_items,
      duration_ms: duration_ms,
      items_by_type: %{
        characters: Enum.at(results, 0),
        systems: Enum.at(results, 1),
        killmails: Enum.at(results, 2),
        items: Enum.at(results, 3),
        alliances: Enum.at(results, 4)
      }
    }

    Logger.info("Cache warming complete: #{total_items} items in #{duration_ms}ms")
    send(parent_pid, {:warming_complete, stats})
  end

  defp warm_hot_characters do
    # Get recently active characters - just get the most recent ones
    case CharacterStats
         |> Ash.Query.sort(last_calculated_at: :desc)
         |> Ash.Query.limit(@batch_size)
         |> Ash.read(domain: Api) do
      {:ok, characters} ->
        # Warm character intelligence data
        Enum.map(characters, & &1.character_id)
        |> Enum.chunk_every(10)
        |> Enum.each(&warm_character_batch/1)

        length(characters)

      {:error, _} ->
        0
    end
  end

  defp warm_active_systems do
    # Get recent killmails and extract systems
    case KillmailEnriched
         |> Ash.Query.sort(killmail_time: :desc)
         |> Ash.Query.limit(@batch_size * 10)
         |> Ash.read(domain: Api) do
      {:ok, killmails} ->
        system_ids = Enum.map(killmails, & &1.solar_system_id)

        # Warm system information
        system_ids
        |> Enum.uniq()
        |> Enum.take(@batch_size)
        |> Enum.each(&warm_system_info/1)

        length(system_ids)

      {:error, _} ->
        0
    end
  end

  defp warm_recent_killmails do
    # Get recent high-value killmails
    case KillmailEnriched
         |> Ash.Query.sort(total_value: :desc)
         |> Ash.Query.limit(@batch_size)
         |> Ash.Query.load(:participants)
         |> Ash.read(domain: Api) do
      {:ok, killmails} ->
        # Cache enriched killmail data
        Enum.each(killmails, fn killmail ->
          cache_key = "killmail_enriched_#{killmail.killmail_id}"

          # Cache is handled by QueryCache internally, just touch it to warm
          QueryCache.get_or_compute(cache_key, fn -> killmail end, :timer.hours(2))
        end)

        length(killmails)

      {:error, _} ->
        0
    end
  end

  defp warm_frequent_items do
    # Get frequently used ship types
    popular_ship_ids = [
      # Capsule
      670,
      # Tengu
      29_984,
      # Loki
      29_990,
      # Legion
      29_986,
      # Proteus
      29_988,
      # Sabre
      22_456,
      # Cerberus
      11_993,
      # Muninn
      12_023,
      # Caracal
      11_969,
      # Drake
      24_698,
      # Ferox
      16_227,
      # Kestrel
      24_702,
      # Myrmidon
      32_209,
      # Cyclone
      24_700,
      # Hurricane
      626,
      # Raven
      638,
      # Dominix
      32_305,
      # Megathron
      643,
      # Jita 4-4
      11_202,
      # Jita system
      60_003_760
    ]

    # Warm item type data
    Enum.chunk_every(popular_ship_ids, 10)
    |> Enum.each(&warm_item_type_batch/1)

    length(popular_ship_ids)
  end

  defp warm_alliance_stats do
    # Get participants with alliances
    case EveDmv.Killmails.Participant
         |> Ash.Query.filter(not is_nil(alliance_id))
         |> Ash.Query.sort(updated_at: :desc)
         |> Ash.Query.limit(@batch_size * 10)
         |> Ash.read(domain: Api) do
      {:ok, results} ->
        alliance_ids =
          Enum.map(results, & &1.alliance_id)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> Enum.take(@batch_size)

        # Warm alliance statistics
        Enum.each(alliance_ids, fn alliance_id ->
          cache_key = "alliance_stats_#{alliance_id}"

          QueryCache.get_or_compute(
            cache_key,
            fn ->
              compute_alliance_stats(alliance_id)
            end,
            :timer.hours(6)
          )
        end)

        length(alliance_ids)

      {:error, _} ->
        0
    end
  end

  defp warm_specific_items("character", character_ids) do
    Enum.each(character_ids, fn character_id ->
      cache_key = "character_intel_#{character_id}"

      QueryCache.get_or_compute(
        cache_key,
        fn ->
          case IntelligenceMigrationAdapter.analyze(:character, character_id, scope: :basic) do
            {:ok, analysis} -> analysis
            _ -> nil
          end
        end,
        :timer.hours(1)
      )
    end)
  end

  defp warm_specific_items("killmail", killmail_ids) do
    Enum.each(killmail_ids, fn killmail_id ->
      cache_key = "killmail_enriched_#{killmail_id}"

      QueryCache.get_or_compute(
        cache_key,
        fn ->
          KillmailEnriched
          |> Ash.Query.filter(killmail_id == ^killmail_id)
          |> Ash.Query.load(:participants)
          |> Ash.read_one(domain: Api)
          |> case do
            {:ok, killmail} -> killmail
            _ -> nil
          end
        end,
        :timer.hours(2)
      )
    end)
  end

  defp warm_specific_items(_, _), do: :ok

  defp warm_character_batch(character_ids) do
    Enum.each(character_ids, fn character_id ->
      cache_key = "character_intel_#{character_id}"

      # Pre-compute and cache character analysis
      QueryCache.get_or_compute(
        cache_key,
        fn ->
          case IntelligenceMigrationAdapter.analyze(:character, character_id, scope: :basic) do
            {:ok, analysis} -> analysis
            _ -> nil
          end
        end,
        :timer.hours(1)
      )
    end)
  end

  defp warm_system_info(system_id) do
    cache_key = "system_info_#{system_id}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        case Ash.get(SolarSystem, system_id, domain: Api) do
          {:ok, system} -> system
          _ -> nil
        end
      end,
      :timer.hours(24)
    )
  end

  defp warm_item_type_batch(type_ids) do
    Enum.each(type_ids, fn type_id ->
      cache_key = "item_type_#{type_id}"

      QueryCache.get_or_compute(
        cache_key,
        fn ->
          case Ash.get(ItemType, type_id, domain: Api) do
            {:ok, item} -> item
            _ -> nil
          end
        end,
        :timer.hours(48)
      )
    end)
  end

  defp compute_alliance_stats(alliance_id) do
    # Get kill/loss stats for alliance
    case EveDmv.Killmails.Participant
         |> Ash.Query.filter(alliance_id == ^alliance_id)
         |> Ash.Query.sort(updated_at: :desc)
         |> Ash.Query.limit(1000)
         |> Ash.Query.load(:killmail_enriched)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        kills = Enum.filter(participants, &(not &1.is_victim))
        losses = Enum.filter(participants, & &1.is_victim)

        %{
          alliance_id: alliance_id,
          kill_count: length(kills),
          loss_count: length(losses),
          active_members: participants |> Enum.map(& &1.character_id) |> Enum.uniq() |> length(),
          last_activity: participants |> Enum.map(& &1.updated_at) |> Enum.max(fn -> nil end)
        }

      _ ->
        nil
    end
  end
end
