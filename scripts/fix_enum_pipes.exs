#!/usr/bin/env elixir

defmodule EnumPipeFixer do
  @moduledoc """
  Fixes missing pipe operators in Enum function chains.
  
  This script finds patterns like:
    variable
    Enum.function(...)
  
  And converts them to:
    variable
    |> Enum.function(...)
  """

  def run(args \\ []) do
    dry_run = "--dry-run" in args
    
    IO.puts("Starting Enum pipe fixer#{if dry_run, do: " (DRY RUN)", else: ""}...")
    
    # Get all Elixir files
    files = get_elixir_files()
    IO.puts("Found #{length(files)} Elixir files to process")
    
    # Process each file
    results = Enum.map(files, &process_file(&1, dry_run))
    
    # Summary
    fixed_count = Enum.count(results, & &1.fixed > 0)
    total_fixes = Enum.sum(Enum.map(results, & &1.fixed))
    
    IO.puts("\nSummary:")
    IO.puts("  Files processed: #{length(files)}")
    IO.puts("  Files modified: #{fixed_count}")
    IO.puts("  Total fixes: #{total_fixes}")
    
    if dry_run do
      IO.puts("\nThis was a dry run. No files were actually modified.")
      IO.puts("Run without --dry-run to apply changes.")
    end
  end
  
  defp get_elixir_files do
    Path.wildcard("lib/**/*.{ex,exs}")
    |> Enum.filter(&File.regular?/1)
  end
  
  defp process_file(file_path, dry_run) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")
    
    {fixed_lines, fix_count} = fix_lines(lines)
    
    if fix_count > 0 do
      IO.puts("  Fixed #{fix_count} issues in #{file_path}")
      
      if not dry_run do
        new_content = Enum.join(fixed_lines, "\n")
        File.write!(file_path, new_content)
      end
    end
    
    %{file: file_path, fixed: fix_count}
  end
  
  defp fix_lines(lines) do
    lines
    |> Enum.with_index()
    |> Enum.reduce({[], 0}, fn {line, idx}, {acc_lines, fix_count} ->
      cond do
        # Skip if line already has a pipe
        String.contains?(line, "|>") ->
          {acc_lines ++ [line], fix_count}
          
        # Check if this line is an Enum call without a pipe
        should_add_pipe?(line, lines, idx) ->
          fixed_line = add_pipe_to_line(line)
          {acc_lines ++ [fixed_line], fix_count + 1}
          
        true ->
          {acc_lines ++ [line], fix_count}
      end
    end)
  end
  
  defp should_add_pipe?(line, lines, idx) do
    # Check if this line starts with Enum. and doesn't have a pipe
    if Regex.match?(~r/^\s*Enum\.[a-z_]+/, line) do
      # Look at previous non-empty lines to see if they end with something that should be piped
      check_previous_lines_for_pipeable(lines, idx - 1)
    else
      false
    end
  end
  
  defp check_previous_lines_for_pipeable(_lines, idx) when idx < 0, do: false
  
  defp check_previous_lines_for_pipeable(lines, idx) do
    prev_line = Enum.at(lines, idx, "")
    trimmed = String.trim(prev_line)
    
    cond do
      # Empty line, keep looking back
      trimmed == "" ->
        check_previous_lines_for_pipeable(lines, idx - 1)
        
      # Comment line, keep looking back  
      String.starts_with?(trimmed, "#") ->
        check_previous_lines_for_pipeable(lines, idx - 1)
        
      # Line ends with a pipe already
      String.ends_with?(trimmed, "|>") ->
        false
        
      # Line is an assignment or variable reference that could be piped
      # This includes patterns like:
      # - variable_name
      # - function_call()
      # - data_structure
      # - closing brackets/parens from previous expression
      Regex.match?(~r/[a-zA-Z0-9_\)\]\}]$/, trimmed) ->
        # Make sure it's not a definition line
        not Regex.match?(~r/^\s*(def|defp|defmacro|defmacrop)\s+/, prev_line)
        
      true ->
        false
    end
  end
  
  defp add_pipe_to_line(line) do
    # Find the indentation
    {indent, rest} = split_indent(line)
    
    # Add pipe with same indentation
    indent <> "|> " <> rest
  end
  
  defp split_indent(line) do
    case Regex.run(~r/^(\s*)(.*)$/, line) do
      [_, indent, rest] -> {indent, rest}
      _ -> {"", line}
    end
  end
end

# Run the script
EnumPipeFixer.run(System.argv())