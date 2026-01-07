defmodule EveDmv.Contexts.CorporationIntelligence.Domain.CorporationComparator do
  @moduledoc """
  Handles comparison operations between multiple corporations.

  This module contains functions for comparing various aspects of corporations:
  - Member counts
  - Activity levels
  - Performance metrics
  - Timezone coverage
  - Operational focus

  These functions are used by the CorporationIntelligence API to generate
  comprehensive corporation comparisons.
  """

  @doc """
  Compares member counts across corporations.

  Returns a list of {corporation_id, member_count} tuples sorted by count descending.

  ## Parameters

    - corporations_data: Map of corporation_id => %{base_analysis: ..., performance: ...}

  ## Returns

    - List of {corporation_id, member_count} tuples sorted by member count (descending)
  """
  @spec compare_member_counts(map()) :: [{integer(), non_neg_integer()}]
  def compare_member_counts(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      member_count = get_in(data, [:base_analysis, :member_count]) || 0
      {corp_id, member_count}
    end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
  end

  @doc """
  Compares activity levels across corporations.

  Activity is measured by total kills in the analysis period.

  ## Parameters

    - corporations_data: Map of corporation_id => %{base_analysis: ..., performance: ...}

  ## Returns

    - List of {corporation_id, activity_count} tuples sorted by activity (descending)
  """
  @spec compare_activity_levels(map()) :: [{integer(), non_neg_integer()}]
  def compare_activity_levels(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      activity = get_in(data, [:performance, :efficiency_metrics, :total_kills]) || 0
      {corp_id, activity}
    end)
    |> Enum.sort_by(fn {_, activity} -> activity end, :desc)
  end

  @doc """
  Compares performance metrics across corporations.

  Returns detailed performance metrics including K/D ratio, ISK efficiency, and rating.

  ## Parameters

    - corporations_data: Map of corporation_id => %{base_analysis: ..., performance: ...}

  ## Returns

    - List of {corporation_id, metrics_map} tuples sorted by ISK efficiency (descending)
  """
  @spec compare_performance_metrics(map()) :: [{integer(), map()}]
  def compare_performance_metrics(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      metrics = get_in(data, [:performance, :efficiency_metrics]) || %{}

      {corp_id,
       %{
         kd_ratio: metrics[:kill_death_ratio] || 0,
         isk_efficiency: metrics[:isk_efficiency] || 0,
         rating: metrics[:efficiency_rating] || :unknown
       }}
    end)
    |> Enum.sort_by(fn {_, metrics} -> metrics.isk_efficiency end, :desc)
  end

  @doc """
  Compares timezone coverage across corporations.

  Returns primary timezone and coverage classification for each corporation.

  ## Parameters

    - corporations_data: Map of corporation_id => %{base_analysis: ..., performance: ...}

  ## Returns

    - List of {corporation_id, timezone_info} tuples
  """
  @spec compare_timezone_coverage(map()) :: [{integer(), map()}]
  def compare_timezone_coverage(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      timezone =
        get_in(data, [:base_analysis, :activity_patterns, :primary_timezones, :primary_tz]) ||
          "Unknown"

      coverage =
        get_in(data, [:base_analysis, :activity_patterns, :primary_timezones, :coverage]) ||
          "Unknown"

      {corp_id, %{primary_tz: timezone, coverage: coverage}}
    end)
  end

  @doc """
  Compares operational focus across corporations.

  Returns the primary operational focus (e.g., PvP, industry, etc.) for each corporation.

  ## Parameters

    - corporations_data: Map of corporation_id => %{base_analysis: ..., performance: ...}

  ## Returns

    - List of {corporation_id, focus} tuples
  """
  @spec compare_operational_focus(map()) :: [{integer(), String.t() | atom()}]
  def compare_operational_focus(corporations_data) do
    corporations_data
    |> Enum.map(fn {corp_id, data} ->
      focus =
        get_in(data, [:base_analysis, :activity_patterns, :operational_focus, :focus]) ||
          "Unknown"

      {corp_id, focus}
    end)
  end
end
