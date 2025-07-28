defmodule EveDmv.Shared.Intelligence.Facade do
  @moduledoc """
  Facade module that provides a simplified interface to the intelligence system.

  This module maintains backward compatibility while delegating to the new
  modular intelligence components.
  """

  alias EveDmv.Shared.Intelligence.{Collector, Processor, FusionEngine, ReportBuilder}

  require Logger

  @doc """
  Performs complete intelligence gathering and fusion pipeline.

  This is the main entry point for intelligence operations.
  """
  def gather_and_analyze_intelligence(analysis_area, options \\ []) do
    with {:ok, raw_intelligence} <- Collector.collect_raw_intelligence(analysis_area, options),
         processed <- Processor.process_intelligence_sources(raw_intelligence),
         {:ok, fused} <- FusionEngine.perform_intelligence_fusion(processed, options),
         confidence <- FusionEngine.assess_intelligence_confidence(fused),
         report <- ReportBuilder.compile_intelligence_report(fused, confidence, options) do
      {:ok,
       %{
         report: report,
         raw_intelligence: raw_intelligence,
         processed_intelligence: processed,
         fused_intelligence: fused,
         confidence_assessment: confidence
       }}
    else
      {:error, reason} = error ->
        Logger.error("Intelligence pipeline failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Collects raw intelligence from specified sources.
  Delegates to Collector module.
  """
  defdelegate collect_raw_intelligence(analysis_area, options \\ []),
    to: Collector

  @doc """
  Processes intelligence sources.
  Delegates to Processor module.
  """
  defdelegate process_intelligence_sources(raw_intelligence),
    to: Processor

  @doc """
  Performs intelligence fusion.
  Delegates to FusionEngine module.
  """
  defdelegate perform_intelligence_fusion(processed_intelligence, options \\ []),
    to: FusionEngine

  @doc """
  Assesses intelligence confidence.
  Delegates to FusionEngine module.
  """
  defdelegate assess_intelligence_confidence(fused_intelligence),
    to: FusionEngine

  @doc """
  Compiles intelligence report.
  Delegates to ReportBuilder module.
  """
  defdelegate compile_intelligence_report(
                fused_intelligence,
                confidence_assessment,
                options \\ []
              ),
              to: ReportBuilder

  @doc """
  Assesses intelligence value.
  Delegates to ReportBuilder module.
  """
  defdelegate assess_intelligence_value(intelligence_report, assessment_criteria \\ []),
    to: ReportBuilder

  @doc """
  Formats report for output.
  Delegates to ReportBuilder module.
  """
  defdelegate format_for_output(report, output_type),
    to: ReportBuilder
end
