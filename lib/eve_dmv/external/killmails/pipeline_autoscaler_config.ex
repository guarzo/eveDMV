defmodule EveDmv.Killmails.PipelineAutoscalerConfig do
  @moduledoc """
  Configuration constants for pipeline autoscaling calculations.

  All values are documented with rationale based on Broadway pipeline
  performance characteristics and EVE Online killmail ingestion patterns.

  ## Scaling Thresholds

  The autoscaler monitors pipeline utilization and recommends concurrency
  adjustments based on these thresholds:

  - `scale_up_threshold` (0.8 / 80%): When utilization exceeds 80%, the pipeline
    is approaching capacity and additional processors are recommended.
  - `scale_down_threshold` (0.3 / 30%): When utilization drops below 30%, the
    pipeline has excess capacity and can reduce processors to save resources.

  ## Concurrency Limits

  - `min_concurrency` (4): Minimum processors to maintain responsiveness even
    during low traffic periods.
  - `max_concurrency` (16): Maximum processors to prevent resource exhaustion
    and diminishing returns from over-parallelization.
  - `default_concurrency` (8): Starting point that balances throughput with
    resource usage for typical killmail ingestion rates.

  ## Batch Configuration

  - `batch_timeout_ms` (30,000ms / 30 seconds): Maximum time to wait for a
    batch to fill before processing. Used in utilization calculations.

  ## Check Interval

  - `check_interval_ms` (30,000ms / 30 seconds): How often the autoscaler
    evaluates pipeline metrics and updates recommendations.
  """

  # =============================================================================
  # Scaling Thresholds
  # =============================================================================

  # When utilization exceeds 80%, the pipeline is approaching capacity.
  # Additional processors are recommended to maintain throughput.
  # Based on queueing theory, utilization above 80% leads to exponentially
  # increasing queue times, making this a good trigger point.
  @scale_up_threshold 0.8

  # When utilization drops below 30%, the pipeline has significant excess
  # capacity. Reducing processors saves resources without impacting throughput.
  # This threshold provides hysteresis to prevent rapid scaling oscillation.
  @scale_down_threshold 0.3

  # =============================================================================
  # Concurrency Limits
  # =============================================================================

  # Minimum 4 processors maintains responsiveness during low traffic periods.
  # This ensures the pipeline can quickly handle sudden bursts of killmail
  # activity (e.g., large fleet fights) without startup delay.
  @min_concurrency 4

  # Maximum 16 processors prevents resource exhaustion and accounts for
  # diminishing returns from over-parallelization. Beyond this point,
  # context switching overhead often exceeds throughput gains.
  @max_concurrency 16

  # Default 8 processors provides a balanced starting point for typical
  # killmail ingestion rates. This handles normal EVE Online activity
  # patterns while leaving headroom for spikes.
  @default_concurrency 8

  # =============================================================================
  # Batch Configuration
  # =============================================================================

  # 30 second batch timeout allows sufficient time to accumulate killmails
  # during normal activity while ensuring timely processing during quiet
  # periods. Used as the denominator in utilization calculations.
  @batch_timeout_ms 30_000

  # =============================================================================
  # Check Interval
  # =============================================================================

  # 30 second check interval balances responsiveness with overhead.
  # Shorter intervals would detect changes faster but add unnecessary
  # polling load during stable operation.
  @check_interval_ms 30_000

  # =============================================================================
  # Public API - Scaling Thresholds
  # =============================================================================

  @doc """
  Returns the utilization threshold for scaling up (80%).

  When pipeline utilization exceeds this threshold, additional processors
  are recommended to maintain throughput and prevent queue buildup.
  """
  @spec scale_up_threshold() :: float()
  def scale_up_threshold, do: @scale_up_threshold

  @doc """
  Returns the utilization threshold for scaling down (30%).

  When pipeline utilization drops below this threshold, processors can
  be reduced to save resources without impacting throughput.
  """
  @spec scale_down_threshold() :: float()
  def scale_down_threshold, do: @scale_down_threshold

  # =============================================================================
  # Public API - Concurrency Limits
  # =============================================================================

  @doc """
  Returns the minimum concurrency limit (4 processors).

  This maintains responsiveness during low traffic periods and ensures
  the pipeline can quickly handle sudden activity bursts.
  """
  @spec min_concurrency() :: pos_integer()
  def min_concurrency, do: @min_concurrency

  @doc """
  Returns the maximum concurrency limit (16 processors).

  This prevents resource exhaustion and accounts for diminishing returns
  from over-parallelization.
  """
  @spec max_concurrency() :: pos_integer()
  def max_concurrency, do: @max_concurrency

  @doc """
  Returns the default concurrency setting (8 processors).

  This is the starting point that balances throughput with resource usage
  for typical killmail ingestion rates.
  """
  @spec default_concurrency() :: pos_integer()
  def default_concurrency, do: @default_concurrency

  # =============================================================================
  # Public API - Batch Configuration
  # =============================================================================

  @doc """
  Returns the batch timeout in milliseconds (30,000ms / 30 seconds).

  Maximum time to wait for a batch to fill before processing. This value
  is used in utilization calculations.
  """
  @spec batch_timeout_ms() :: pos_integer()
  def batch_timeout_ms, do: @batch_timeout_ms

  # =============================================================================
  # Public API - Check Interval
  # =============================================================================

  @doc """
  Returns the scaling check interval in milliseconds (30,000ms / 30 seconds).

  How often the autoscaler evaluates pipeline metrics and updates its
  scaling recommendations.
  """
  @spec check_interval_ms() :: pos_integer()
  def check_interval_ms, do: @check_interval_ms
end
