#!/usr/bin/env elixir
# Fix broken pipeline conversions

defmodule BrokenPipelineFixer do
  def fix_file(file_path) do
    content = File.read!(file_path)
    
    # Fix patterns that were incorrectly converted
    fixed_content = 
      content
      # Fix: value round() -> round(value)
      |> String.replace(~r/(\w+)\s+round\(\)/, "round(\\1)")
      # Fix: value Integer.to_string() -> Integer.to_string(value) 
      |> String.replace(~r/(\w+)\s+Integer\.to_string\(\)/, "Integer.to_string(\\1)")
      # Fix: value Enum.sum() -> Enum.sum(value)
      |> String.replace(~r/(\w+)\s+Enum\.sum\(\)/, "Enum.sum(\\1)")
      # Fix: value Enum.uniq() -> Enum.uniq(value)
      |> String.replace(~r/(\w+)\s+Enum\.uniq\(\)/, "Enum.uniq(\\1)")
      # Fix: value String.reverse() -> String.reverse(value)
      |> String.replace(~r/(\w+)\s+String\.reverse\(\)/, "String.reverse(\\1)")
      # Fix: value Atom.to_string() -> Atom.to_string(value)
      |> String.replace(~r/(\w+)\s+Atom\.to_string\(\)/, "Atom.to_string(\\1)")
      # Fix: value String.capitalize() -> String.capitalize(value)
      |> String.replace(~r/(\w+)\s+String\.capitalize\(\)/, "String.capitalize(\\1)")
      # Fix: value to_string() -> to_string(value)
      |> String.replace(~r/(\w+)\s+to_string\(\)/, "to_string(\\1)")
      # Fix: value Map.new() -> Map.new(value)
      |> String.replace(~r/(\w+)\s+Map\.new\(\)/, "Map.new(\\1)")
      # Fix: value Repo.all() -> Repo.all(value)
      |> String.replace(~r/(\w+)\s+Repo\.all\(\)/, "Repo.all(\\1)")
      # Fix: value Stream.run() -> Stream.run(value) 
      |> String.replace(~r/(\w+)\s+Stream\.run\(\)/, "Stream.run(\\1)")
      # Fix: value atomize_keys() -> atomize_keys(value)
      |> String.replace(~r/(\w+)\s+atomize_keys\(\)/, "atomize_keys(\\1)")
      # Fix: value ensure_all_roles() -> ensure_all_roles(value)
      |> String.replace(~r/(\w+)\s+ensure_all_roles\(\)/, "ensure_all_roles(\\1)")
      # Fix: value normalize_confidence_scores() -> normalize_confidence_scores(value)
      |> String.replace(~r/(\w+)\s+normalize_confidence_scores\(\)/, "normalize_confidence_scores(\\1)")
      
      # Fix missing pipe operators
      |> String.replace(~r/\n(\s+)(\w+)\n/, "\n\\1|> \\2\n")
      
    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts("Fixed broken pipelines in #{file_path}")
    end
  end
  
  def run do
    # Get list of files that likely have issues from the error messages
    problematic_files = [
      "lib/eve_dmv/contexts/battle_analysis/domain/ship_performance_analyzer.ex",
      "lib/eve_dmv_web/components/character_intel_components.ex",
      "lib/eve_dmv_web/live/battle_analysis_live.ex", 
      "lib/eve_dmv_web/live/fleet_operations/components/fleet_composition_component.ex",
      "lib/eve_dmv/analytics/battle_detector/assessment.ex",
      "lib/eve_dmv/analytics/battle_detector_fixed.ex",
      "lib/eve_dmv/analytics/fleet_analyzer.ex",
      "lib/eve_dmv/analytics/module_classifier.ex",
      "lib/eve_dmv/analytics/player_stats_engine.ex",
      "lib/eve_dmv/contexts.ex"
    ]
    
    # Also scan all files for compilation errors
    all_files = Path.wildcard("lib/**/*.ex") |> Enum.filter(&File.regular?/1)
    
    IO.puts("Fixing broken pipeline conversions...")
    
    (problematic_files ++ all_files)
    |> Enum.uniq()
    |> Enum.each(&fix_file/1)
    
    IO.puts("Pipeline fixes complete!")
  end
end

BrokenPipelineFixer.run()