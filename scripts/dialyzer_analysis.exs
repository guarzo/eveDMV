#!/usr/bin/env elixir
# Script to analyze dialyzer output and categorize errors by workstream
# Part of Workstream E: Testing & Validation

defmodule DialyzerAnalysis do
  @moduledoc """
  Analyzes dialyzer output to help track progress across workstreams.
  """

  @workstream_patterns %{
    "A" => [
      # Type specification issues
      ~r/Type specification.*is a supertype/,
      ~r/The specification.*has an opaque subtype/,
      ~r/Invalid type specification/,
      ~r/Type mismatch.*expected.*got/
    ],
    "B" => [
      # Battle & Combat module patterns
      ~r/timeline_builder.*not_implemented/,
      ~r/battle_sharing.*curator_unavailable/,
      ~r/tactical_highlight_manager.*battle_data_unavailable/,
      ~r/battle_.*pattern_match/,
      ~r/combat_.*pattern_match/
    ],
    "C" => [
      # Enum & Pattern coverage
      ~r/threat_detector.*:stable/,
      ~r/external_group_analyzer.*enum/,
      ~r/combat_intelligence_engine.*:minimal/,
      ~r/The pattern can never match/,
      ~r/This clause cannot match/
    ],
    "D" => [
      # Infrastructure & Cache patterns
      ~r/cache.*pattern_match.*:miss/,
      ~r/wanderer.*client/,
      ~r/authentication.*manager/,
      ~r/external.*service/
    ]
  }

  def analyze(file_path \\ "dialyzer.txt") do
    case File.read(file_path) do
      {:ok, content} ->
        errors = parse_errors(content)
        
        IO.puts("📊 Dialyzer Error Analysis")
        IO.puts("=" |> String.duplicate(50))
        IO.puts("")
        
        # Summary
        summary = extract_summary(content)
        IO.puts("📈 Summary:")
        IO.puts("  Total Errors: #{summary.total}")
        IO.puts("  Skipped: #{summary.skipped}")
        IO.puts("  Net Errors: #{summary.total - summary.skipped}")
        IO.puts("")
        
        # Categorize by workstream
        categorized = categorize_by_workstream(errors)
        
        IO.puts("📋 Errors by Workstream:")
        for {workstream, ws_errors} <- categorized |> Enum.sort() do
          count = length(ws_errors)
          percentage = Float.round(count / length(errors) * 100, 1)
          IO.puts("  Workstream #{workstream}: #{count} errors (#{percentage}%)")
        end
        IO.puts("  Uncategorized: #{length(categorized["Other"])} errors")
        IO.puts("")
        
        # Top error types
        IO.puts("🔝 Top Error Types:")
        errors
        |> Enum.group_by(&extract_error_type/1)
        |> Enum.map(fn {type, errs} -> {type, length(errs)} end)
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(10)
        |> Enum.each(fn {type, count} ->
          IO.puts("  #{type}: #{count}")
        end)
        IO.puts("")
        
        # Top affected modules
        IO.puts("🔥 Top Affected Modules:")
        errors
        |> Enum.group_by(&extract_module/1)
        |> Enum.map(fn {module, errs} -> {module, length(errs)} end)
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(10)
        |> Enum.each(fn {module, count} ->
          IO.puts("  #{module}: #{count} errors")
        end)
        
        # Generate detailed report
        generate_detailed_report(categorized)
        
      {:error, reason} ->
        IO.puts("Error reading file: #{reason}")
    end
  end

  defp parse_errors(content) do
    content
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "lib/"))
    |> Enum.filter(&String.contains?(&1, ":"))
  end

  defp extract_summary(content) do
    case Regex.run(~r/Total errors: (\d+), Skipped: (\d+)/, content) do
      [_, total_str, skipped_str] ->
        %{
          total: String.to_integer(total_str),
          skipped: String.to_integer(skipped_str)
        }
      _ ->
        %{total: 0, skipped: 0}
    end
  end

  defp categorize_by_workstream(errors) do
    Enum.reduce(errors, %{"Other" => []}, fn error, acc ->
      workstream = find_workstream(error)
      Map.update(acc, workstream, [error], &[error | &1])
    end)
  end

  defp find_workstream(error) do
    Enum.find_value(@workstream_patterns, "Other", fn {workstream, patterns} ->
      if Enum.any?(patterns, &Regex.match?(&1, error)) do
        workstream
      end
    end)
  end

  defp extract_error_type(error) do
    cond do
      error =~ ~r/:pattern_match/ -> "pattern_match"
      error =~ ~r/:no_return/ -> "no_return"
      error =~ ~r/:callback_type_mismatch/ -> "callback_type_mismatch"
      error =~ ~r/:invalid_contract/ -> "invalid_contract"
      error =~ ~r/:call/ -> "call"
      error =~ ~r/:opaque_type_test/ -> "opaque_type_test"
      error =~ ~r/:unknown_type/ -> "unknown_type"
      error =~ ~r/:unused_fun/ -> "unused_fun"
      true -> "other"
    end
  end

  defp extract_module(error) do
    case String.split(error, ":") do
      [path | _] -> 
        path
        |> String.replace("lib/eve_dmv/", "")
        |> String.replace(".ex", "")
        |> String.replace("/", ".")
      _ -> 
        "unknown"
    end
  end

  defp generate_detailed_report(categorized) do
    timestamp = DateTime.utc_now() |> DateTime.to_string()
    
    report = %{
      timestamp: timestamp,
      workstream_breakdown: Enum.map(categorized, fn {ws, errors} ->
        %{
          workstream: ws,
          error_count: length(errors),
          sample_errors: Enum.take(errors, 3)
        }
      end)
    }
    
    File.write!("dialyzer_workstream_report.json", Jason.encode!(report, pretty: true))
    IO.puts("\n✅ Detailed report saved to dialyzer_workstream_report.json")
  end
end

# Run the analysis
DialyzerAnalysis.analyze()