#!/usr/bin/env elixir

defmodule EnumPipeFixerV2 do
  @moduledoc """
  Fixes missing pipe operators in Enum function chains - Version 2.
  
  This version is more careful about identifying patterns that need fixing,
  avoiding false positives that break compilation.
  """

  def run(args \\ []) do
    dry_run = "--dry-run" in args
    verbose = "--verbose" in args
    
    IO.puts("Starting Enum pipe fixer v2#{if dry_run, do: " (DRY RUN)", else: ""}...")
    
    # Get all Elixir files
    files = get_elixir_files()
    IO.puts("Found #{length(files)} Elixir files to process")
    
    # Process each file
    results = Enum.map(files, &process_file(&1, dry_run, verbose))
    
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
  
  defp process_file(file_path, dry_run, verbose) do
    content = File.read!(file_path)
    lines = String.split(content, "\n")
    
    {fixed_lines, fix_count} = fix_lines_v2(lines, verbose)
    
    if fix_count > 0 do
      IO.puts("  Fixed #{fix_count} issues in #{file_path}")
      
      if not dry_run do
        new_content = Enum.join(fixed_lines, "\n")
        File.write!(file_path, new_content)
      end
    end
    
    %{file: file_path, fixed: fix_count}
  end
  
  defp fix_lines_v2(lines, verbose) do
    lines
    |> Enum.with_index()
    |> Enum.reduce({[], 0}, fn {line, idx}, {acc_lines, fix_count} ->
      cond do
        # Skip if line already has a pipe
        String.contains?(line, "|>") ->
          {acc_lines ++ [line], fix_count}
          
        # Check if this is a problematic Enum pattern that shouldn't be fixed
        is_enum_with_args?(line) ->
          {acc_lines ++ [line], fix_count}
          
        # Check if this line is an Enum call without a pipe that should be fixed
        should_add_pipe_v2?(line, lines, idx) ->
          fixed_line = add_pipe_to_line(line)
          if verbose do
            IO.puts("    Line #{idx + 1}: Adding pipe")
            IO.puts("      Before: #{String.trim(line)}")
            IO.puts("      After:  #{String.trim(fixed_line)}")
          end
          {acc_lines ++ [fixed_line], fix_count + 1}
          
        true ->
          {acc_lines ++ [line], fix_count}
      end
    end)
  end
  
  defp is_enum_with_args?(line) do
    # Check for patterns like:
    # Enum.any?(collection, predicate)
    # Enum.all?(items, condition)
    # These should NOT have pipes added
    trimmed = String.trim(line)
    
    # Pattern: Enum.function(arg1, arg2, ...)
    # This regex matches Enum calls that already have arguments in parentheses
    Regex.match?(~r/^\s*Enum\.[a-z_?!]+\([^,\)]+,/, trimmed) or
    # Also check for |> at the end going to the next line
    Regex.match?(~r/\|>\s*$/, trimmed)
  end
  
  defp should_add_pipe_v2?(line, lines, idx) do
    trimmed = String.trim(line)
    
    # Only consider lines that start with Enum. and don't have multiple arguments
    if Regex.match?(~r/^\s*Enum\.[a-z_?!]+\(/, trimmed) and 
       not is_enum_with_args?(line) do
      # Look at previous lines to see if they should be piped
      check_previous_for_pipeable_v2(lines, idx - 1)
    else
      false
    end
  end
  
  defp check_previous_for_pipeable_v2(_lines, idx) when idx < 0, do: false
  
  defp check_previous_for_pipeable_v2(lines, idx) do
    prev_line = Enum.at(lines, idx, "")
    trimmed = String.trim(prev_line)
    
    cond do
      # Empty line, keep looking back
      trimmed == "" ->
        check_previous_for_pipeable_v2(lines, idx - 1)
        
      # Comment line, keep looking back  
      String.starts_with?(trimmed, "#") ->
        check_previous_for_pipeable_v2(lines, idx - 1)
        
      # Line ends with a pipe already
      String.ends_with?(trimmed, "|>") ->
        false
        
      # Line is a function definition
      Regex.match?(~r/^\s*(def|defp|defmacro|defmacrop)\s+/, prev_line) ->
        false
        
      # Line is an assignment to a new variable (check indentation is preserved)
      # Only pipe if the assignment is already complete on the previous line
      Regex.match?(~r/^\s*[a-z_]+\s*=$/, prev_line) ->
        # Assignment continues on next line, should pipe
        true
        
      # Line ends with = (assignment on same line as value)
      String.ends_with?(trimmed, "=") ->
        false
        
      # Previous line looks like a complete expression that could be piped
      # This includes: variable names, function calls, data structures
      Regex.match?(~r/[a-zA-Z0-9_\)\]\}]$/, trimmed) ->
        # Additional check: make sure it's not a partial expression
        not String.ends_with?(trimmed, ",") and
        not String.ends_with?(trimmed, "->") and
        not String.ends_with?(trimmed, "do")
        
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
EnumPipeFixerV2.run(System.argv())