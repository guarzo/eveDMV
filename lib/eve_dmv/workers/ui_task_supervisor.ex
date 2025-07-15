defmodule EveDmv.Workers.UITaskSupervisor do
  @moduledoc """
  Task supervisor optimized for UI-triggered operations.

  This supervisor handles short-lived tasks that are triggered by user interactions
  in LiveViews and should complete quickly to maintain good user experience.

  ## Task Categories
  - Character lookups and analysis (< 10 seconds)
  - Price calculations for individual items
  - Real-time data fetches for UI components
  - Simple API calls and ESI requests

  ## Configuration
  - **Max Task Duration**: 30 seconds (with warnings at 10 seconds)
  - **Max Concurrent Tasks**: 20 per user session
  - **Global Concurrent Limit**: 100 tasks
  - **Restart Strategy**: temporary (failed tasks don't restart)
  """

  use EveDmv.Workers.GenericTaskSupervisor

  @impl true
  def config() do
    [
      name: __MODULE__,
      # 30 seconds
      max_duration: 30_000,
      # 10 seconds
      warning_time: 10_000,
      # Global limit
      max_concurrent: 100,
      # Per user limit
      max_per_user: 20,
      telemetry_prefix: [:eve_dmv, :ui_task]
    ]
  end
end
