defmodule EveDmv.Workers.GenericTaskSupervisorTest do
  use ExUnit.Case, async: true

  alias EveDmv.Workers.{UITaskSupervisor, BackgroundTaskSupervisor, RealtimeTaskSupervisor}

  describe "UITaskSupervisor" do
    test "has correct configuration" do
      config = UITaskSupervisor.config()

      assert config[:max_duration] == 30_000
      assert config[:warning_time] == 10_000
      assert config[:max_concurrent] == 100
      assert config[:max_per_user] == 20
      assert config[:telemetry_prefix] == [:eve_dmv, :ui_task]
    end

    test "can start and supervise tasks" do
      # Start the supervisor
      {:ok, _pid} = UITaskSupervisor.start_link([])

      # Start a simple task
      {:ok, task_pid} =
        UITaskSupervisor.start_task(fn ->
          :timer.sleep(100)
          :ok
        end)

      assert is_pid(task_pid)

      # Check stats
      stats = UITaskSupervisor.get_stats()
      assert stats.running_tasks >= 0
      assert stats.max_concurrent == 100
      assert is_float(stats.capacity_utilization)
    end
  end

  describe "BackgroundTaskSupervisor" do
    test "can start and get stats" do
      # Start the BackgroundTaskSupervisor for this test
      {:ok, _pid} = BackgroundTaskSupervisor.start_link([])

      # Now we can get stats
      stats = BackgroundTaskSupervisor.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_tasks)
      assert Map.has_key?(stats, :max_concurrent)
      assert stats.max_concurrent == 5
    end
  end

  describe "RealtimeTaskSupervisor" do
    test "has correct configuration" do
      config = RealtimeTaskSupervisor.config()

      # 5 seconds
      assert config[:max_duration] == 5_000
      # 2 seconds
      assert config[:warning_time] == 2_000
      assert config[:max_concurrent] == 50
      assert config[:max_per_user] == nil
      assert config[:telemetry_prefix] == [:eve_dmv, :realtime_task]
    end
  end
end
