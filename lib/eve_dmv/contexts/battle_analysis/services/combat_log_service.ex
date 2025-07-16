defmodule EveDmv.Contexts.BattleAnalysis.Services.CombatLogService do
  @moduledoc """
  Service module for combat log operations.

  This module handles the business logic for combat log processing,
  reducing dependencies in the resource module.
  """

  alias EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser
  alias EveDmv.Contexts.BattleAnalysis.Domain.CombatLogParser
  alias EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting

  require Logger

  @doc """
  Processes file upload and prepares combat log data.
  """
  def process_file_upload(file_upload, pilot_name, battle_id \\ nil) do
    with {:ok, content} <- File.read(file_upload.path),
         compressed <- :zlib.compress(content),
         content_hash <- :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) do
      {:ok,
       %{
         raw_content: Base.encode64(compressed),
         content_hash: content_hash,
         file_name: file_upload.filename,
         file_size: byte_size(content),
         uploaded_at: DateTime.utc_now(),
         pilot_name: pilot_name,
         battle_id: battle_id
       }}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Parses combat log content using enhanced parser.
  """
  def parse_combat_log(raw_content, pilot_name) do
    with {:ok, compressed} <- Base.decode64(raw_content),
         content <- :zlib.uncompress(compressed) do
      Logger.info("🔍 USING ENHANCED PARSER for combat log")

      case EnhancedCombatLogParser.parse_combat_log(content, pilot_name: pilot_name) do
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
             end_time: metadata[:end_time],
             parse_status: :completed
           }}

        {:error, reason} ->
          {:error,
           %{
             parse_status: :failed,
             parse_error: inspect(reason)
           }}
      end
    else
      {:error, reason} ->
        {:error,
         %{
           parse_status: :failed,
           parse_error: "Failed to decode or decompress content: #{inspect(reason)}"
         }}
    end
  end

  @doc """
  Analyzes combat performance with optional fitting correlation.
  """
  def analyze_performance(events, pilot_name) do
    # Try to get fitting data for enhanced analysis
    fitting_data = get_latest_fitting_data(pilot_name)

    if fitting_data do
      fitting_analysis = EnhancedCombatLogParser.analyze_fitting_vs_usage(events, fitting_data)
      %{fitting_correlation: fitting_analysis}
    else
      %{}
    end
  end

  @doc """
  Correlates combat log events with battle killmails.
  """
  def correlate_with_battle(events, battle_killmails) do
    correlation = CombatLogParser.correlate_with_killmails(events, battle_killmails)

    %{
      killmail_correlations: correlation,
      match_quality: calculate_match_quality(correlation)
    }
  end

  # Private helper functions

  defp get_latest_fitting_data(pilot_name) do
    case Ash.read(ShipFitting,
           domain: EveDmv.Contexts.BattleAnalysis.Api,
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
