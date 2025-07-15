defmodule EveDmv.Workers.RealtimeTaskSupervisor do
  @moduledoc """
  Task supervisor for real-time event processing.

  This supervisor handles tasks that process streaming data and
  real-time events, with very strict timing requirements.

  ## Task Categories
  - Killmail processing from SSE streams
  - Real-time price updates
  - Event stream processing
  - Live data enrichment

  ## Configuration
  - **Max Task Duration**: 5 seconds (with warnings at 2 seconds)
  - **Max Concurrent Tasks**: 50 tasks
  - **Per-User Limit**: None (system events)
  - **Restart Strategy**: temporary (failed tasks don't restart)
  """

  use EveDmv.Workers.GenericTaskSupervisor

  @impl true
  def config() do
    [
      name: __MODULE__,
      # 5 seconds
      max_duration: 5_000,
      # 2 seconds
      warning_time: 2_000,
      # High concurrency for streaming
      max_concurrent: 50,
      # No per-user limit
      max_per_user: nil,
      telemetry_prefix: [:eve_dmv, :realtime_task]
    ]
  end
end
