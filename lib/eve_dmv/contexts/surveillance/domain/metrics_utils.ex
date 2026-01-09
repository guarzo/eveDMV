defmodule EveDmv.Contexts.Surveillance.Domain.MetricsUtils do
  @moduledoc """
  Shared utility functions for surveillance metrics handling.

  ## Metrics Naming Convention

  When batching metrics updates, the merge behavior depends on the metric name:

  - **Counter metrics**: Metrics with names starting with `count_` or ending with `_count`
    are treated as counters and their values are **summed** during batching.
    Examples: `count_kills`, `alert_count`, `match_count`

  - **Gauge metrics**: All other metrics are treated as gauges and only the **latest value**
    is kept during batching.
    Examples: `last_seen_timestamp`, `current_threat_level`, `active_profiles`

  This convention ensures that counter values accumulate correctly across batch intervals
  while point-in-time values reflect the most recent state.

  ## Usage

      # Merge metrics with counter/gauge awareness
      MetricsUtils.merge_metrics_update(existing_metrics, new_metrics)

      # Check if a metric is a counter
      MetricsUtils.counter_metric?(:alert_count)  # => true
      MetricsUtils.counter_metric?(:count_kills)  # => true
      MetricsUtils.counter_metric?(:last_seen)    # => false

      # Simple counter merge (always sums numeric values)
      MetricsUtils.merge_counters(existing_counters, new_counters)
  """

  @doc """
  Merges metrics updates, applying different strategies based on metric type.

  - Counter metrics (named with "count_" prefix or "_count" suffix) are summed
  - Gauge metrics (all others) use the latest value

  See "Metrics Naming Convention" in module docs for naming requirements.

  ## Examples

      iex> existing = %{count_kills: 5, last_seen: ~U[2026-01-08 10:00:00Z]}
      iex> new = %{count_kills: 3, last_seen: ~U[2026-01-08 11:00:00Z]}
      iex> MetricsUtils.merge_metrics_update(existing, new)
      %{count_kills: 8, last_seen: ~U[2026-01-08 11:00:00Z]}

  """
  @spec merge_metrics_update(map(), map()) :: map()
  def merge_metrics_update(existing, new_update) do
    Map.merge(existing, new_update, fn key, v1, v2 ->
      # Counter metrics (prefixed with count_ or _count suffix) should sum
      if is_number(v1) and is_number(v2) and counter_metric?(key) do
        v1 + v2
      else
        # All other values (gauges) take the latest
        v2
      end
    end)
  end

  @doc """
  Determines if a metric key represents a counter based on naming convention.

  ## Counter Naming Convention

  Counter metrics MUST be named with either:
  - Prefix: "count_" (e.g., :count_kills, :count_matches, :count_alerts)
  - Suffix: "_count" (e.g., :alert_count, :kill_count, :match_count)

  This naming convention is REQUIRED for metrics to be summed during batching.
  Metrics without these naming patterns will be treated as gauges, where only
  the latest value is kept (replacing previous values).

  ## Examples

      iex> MetricsUtils.counter_metric?(:count_kills)
      true

      iex> MetricsUtils.counter_metric?(:alert_count)
      true

      iex> MetricsUtils.counter_metric?(:total_damage)
      false

      iex> MetricsUtils.counter_metric?(:last_seen)
      false

  ## See Also

  - `merge_metrics_update/2` which uses this function for merge strategy
  """
  @spec counter_metric?(atom() | any()) :: boolean()
  def counter_metric?(key) when is_atom(key) do
    key_str = Atom.to_string(key)
    String.starts_with?(key_str, "count_") or String.ends_with?(key_str, "_count")
  end

  def counter_metric?(_), do: false

  @doc """
  Merges counter maps by summing numeric values.

  Unlike `merge_metrics_update/2`, this function always sums numeric values
  regardless of the key name. Use this for maps that are known to contain
  only counter values (e.g., distribution maps, counter aggregations).

  ## Examples

      iex> existing = %{critical: 5, high: 10}
      iex> new = %{critical: 2, high: 3, low: 1}
      iex> MetricsUtils.merge_counters(existing, new)
      %{critical: 7, high: 13, low: 1}

  """
  @spec merge_counters(map(), map()) :: map()
  def merge_counters(existing, updates) when is_map(existing) and is_map(updates) do
    Map.merge(existing, updates, fn _key, v1, v2 ->
      if is_number(v1) and is_number(v2), do: v1 + v2, else: v2
    end)
  end

  def merge_counters(_existing, updates), do: updates
end
