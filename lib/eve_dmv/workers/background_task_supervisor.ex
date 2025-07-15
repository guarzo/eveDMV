defmodule EveDmv.Workers.BackgroundTaskSupervisor do
  @moduledoc """
  Task supervisor for long-running background operations.

  This supervisor handles batch processing, data imports, and other
  resource-intensive operations that can run for extended periods.

  ## Task Categories
  - Data imports and migrations
  - Batch processing of killmails
  - Static data updates
  - Complex analytics computations

  ## Configuration
  - **Max Task Duration**: 30 minutes (with warnings at 10 minutes)
  - **Max Concurrent Tasks**: 5 tasks
  - **Per-User Limit**: None (system-wide tasks)
  - **Restart Strategy**: temporary (failed tasks don't restart)
  """

  use EveDmv.Workers.GenericTaskSupervisor

  @impl true
  def config() do
    [
      name: __MODULE__,
      # 30 minutes
      max_duration: 1_800_000,
      # 10 minutes
      warning_time: 600_000,
      # System-wide limit
      max_concurrent: 5,
      # No per-user limit
      max_per_user: nil,
      telemetry_prefix: [:eve_dmv, :background_task]
    ]
  end
end
