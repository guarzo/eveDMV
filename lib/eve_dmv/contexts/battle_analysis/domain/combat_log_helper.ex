defmodule EveDmv.Contexts.BattleAnalysis.Domain.CombatLogHelper do
  @moduledoc """
  Helper module for combat log processing.

  This module extracts complex logic from the CombatLog resource
  to reduce module dependencies and improve maintainability.
  """

  alias EveDmv.Contexts.BattleAnalysis.Domain.CombatLogParser
  alias EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser
  alias EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting
  require Logger

  @doc """
  Parse combat log content and extract structured data.
  """
  def parse_combat_log_content(content, opts \\ []) do
    pilot_name = Keyword.get(opts, :pilot_name)

    Logger.info("🔍 USING ENHANCED PARSER for combat log")

    case EnhancedCombatLogParser.parse_combat_log(
           content,
           pilot_name: pilot_name
         ) do
      {:ok,
       %{
         events: events,
         summary: summary,
         metadata: metadata,
         tactical_analysis: tactical_analysis,
         recommendations: recommendations
       }} ->
        {:ok,
         %{
           parsed_data: %{
             events: events,
             tactical_analysis: tactical_analysis,
             recommendations: recommendations
           },
           summary: summary,
           event_count: length(events),
           start_time: metadata[:start_time],
           end_time: metadata[:end_time]
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Analyze performance metrics from parsed combat log data.
  """
  def analyze_performance_metrics(parsed_data, pilot_name) do
    events = parsed_data.events

    # Try to get fitting data for enhanced analysis
    fitting_data = get_fitting_data(pilot_name)

    # Enhanced performance analysis with fitting correlation
    performance_metrics =
      if fitting_data do
        fitting_analysis =
          EnhancedCombatLogParser.analyze_fitting_vs_usage(
            events,
            fitting_data
          )

        Map.merge(parsed_data[:tactical_analysis] || %{}, %{
          fitting_correlation: fitting_analysis
        })
      else
        parsed_data[:tactical_analysis] || %{}
      end

    {:ok, performance_metrics}
  end

  @doc """
  Correlate combat log events with battle killmails.
  """
  def correlate_with_battle(events, battle_killmails) do
    correlation =
      CombatLogParser.correlate_with_killmails(
        events,
        battle_killmails
      )

    battle_correlation = %{
      killmail_correlations: correlation,
      match_quality: calculate_match_quality(correlation)
    }

    {:ok, battle_correlation}
  end

  defp get_fitting_data(pilot_name) do
    case Ash.read(ShipFitting,
           filter: [pilot_name: pilot_name],
           sort: [updated_at: :desc],
           limit: 1
         ) do
      {:ok, [fitting | _]} -> fitting.parsed_fitting
      _ -> nil
    end
  end

  defp calculate_match_quality(correlations) do
    # Calculate how well the combat log matches the battle
    matched_kills = Enum.count(correlations, fn c -> length(c.combat_events) > 0 end)
    total_kills = length(correlations)

    if total_kills > 0 do
      Float.round(matched_kills / total_kills * 100, 1)
    else
      0.0
    end
  end
end
