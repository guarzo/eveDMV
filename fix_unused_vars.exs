#!/usr/bin/env elixir

# Script to fix unused variable warnings by prefixing them with underscores

defmodule UnusedVarFixer do
  def fix_files() do
    # Get all Elixir files
    files = Path.wildcard("lib/**/*.ex")

    IO.puts("Found #{length(files)} files to process")

    Enum.each(files, &fix_file/1)

    IO.puts("Finished processing files")
  end

  def fix_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        original_content = content

        # Common patterns to fix
        patterns = [
          # Function parameters
          {~r/def\s+\w+\([^)]*\b([a-z_][a-zA-Z0-9_]*)\s*,/, "def \\g{1}(_\\g{2},"},
          {~r/def\s+\w+\([^)]*\b([a-z_][a-zA-Z0-9_]*)\s*\)/, "def \\g{1}(_\\g{2})"},

          # Private function parameters
          {~r/defp\s+\w+\([^)]*\b([a-z_][a-zA-Z0-9_]*)\s*,/, "defp \\g{1}(_\\g{2},"},
          {~r/defp\s+\w+\([^)]*\b([a-z_][a-zA-Z0-9_]*)\s*\)/, "defp \\g{1}(_\\g{2})"},

          # Variable assignments
          {~r/^\s*([a-z_][a-zA-Z0-9_]*)\s*=/, "    _\\g{1} ="},

          # Pattern matching
          {~r/\{[^}]*\b([a-z_][a-zA-Z0-9_]*)\s*,/, "{_\\g{1},"},
          {~r/\{[^}]*\b([a-z_][a-zA-Z0-9_]*)\s*}/, "{_\\g{1}}"}
        ]

        # Apply fixes carefully
        fixed_content = apply_safe_fixes(content)

        if fixed_content != original_content do
          File.write!(file_path, fixed_content)
          IO.puts("Fixed: #{file_path}")
        end

      {:error, reason} ->
        IO.puts("Error reading #{file_path}: #{reason}")
    end
  end

  def apply_safe_fixes(content) do
    # Only fix very specific patterns that are safe

    # Fix function parameters that are clearly unused
    content
    |> String.replace(
      ~r/def\s+(\w+)\(([^)]*)\b(killmails|timeline|participants|sides|options|fleet_compositions|battle_results|historical_data|outcome_analysis|tactical_patterns|side_performance|system_ids|threat_score|context|confidence_threshold|killmail|battle_analyses|ship_type_id|threat_result|map_id|erl_timestamp)\b/,
      fn match ->
        String.replace(
          match,
          ~r/\b(killmails|timeline|participants|sides|options|fleet_compositions|battle_results|historical_data|outcome_analysis|tactical_patterns|side_performance|system_ids|threat_score|context|confidence_threshold|killmail|battle_analyses|ship_type_id|threat_result|map_id|erl_timestamp)\b/,
          "_\\1"
        )
      end
    )
    |> String.replace(
      ~r/defp\s+(\w+)\(([^)]*)\b(killmails|timeline|participants|sides|options|fleet_compositions|battle_results|historical_data|outcome_analysis|tactical_patterns|side_performance|system_ids|threat_score|context|confidence_threshold|killmail|battle_analyses|ship_type_id|threat_result|map_id|erl_timestamp)\b/,
      fn match ->
        String.replace(
          match,
          ~r/\b(killmails|timeline|participants|sides|options|fleet_compositions|battle_results|historical_data|outcome_analysis|tactical_patterns|side_performance|system_ids|threat_score|context|confidence_threshold|killmail|battle_analyses|ship_type_id|threat_result|map_id|erl_timestamp)\b/,
          "_\\1"
        )
      end
    )
    # Fix variable assignments
    |> String.replace(~r/^\s*(duration|confidence_threshold|side_participants)\s*=/, "    _\\1 =")
    # Fix pattern matching
    |> String.replace(~r/\{[^}]*\b(erl_timestamp)\s*\}/, "{_\\1}")
  end
end

UnusedVarFixer.fix_files()
