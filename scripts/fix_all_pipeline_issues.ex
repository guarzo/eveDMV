#!/usr/bin/env elixir

# Comprehensive script to fix all pipeline syntax issues

defmodule PipelineFixer do
  def fix_all_files do
    # Find all .ex files using secure approach
    {files_output, 0} = System.cmd("find", ["lib", "-name", "*.ex", "-type", "f"], stderr_to_stdout: true)
    
    files = String.split(files_output, "\n", trim: true)
    
    IO.puts("Found #{length(files)} files to check...")
    
    Enum.each(files, &fix_file/1)
    
    IO.puts("All files processed!")
  end
  
  def fix_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        fixed_content = fix_content(content)
        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("Fixed: #{file_path}")
        end
      {:error, reason} ->
        IO.puts("Error reading #{file_path}: #{reason}")
    end
  end
  
  def fix_content(content) do
    content
    # Fix empty arrows that need an expression
    |> fix_empty_arrows()
    # Fix orphaned pipelines at start of lines
    |> fix_orphaned_pipelines()
    # Fix malformed function calls
    |> fix_malformed_function_calls()
    # Fix pipeline continuation issues
    |> fix_pipeline_continuations()
  end
  
  defp fix_empty_arrows(content) do
    # Pattern: "battle ->\n      " with orphaned pipeline
    content
    |> String.replace(~r/(\w+\s*->\s*\n\s*)\|\>\s*(\w+)/m, "\\1\\2")
  end
  
  defp fix_orphaned_pipelines(content) do
    lines = String.split(content, "\n")
    
    fixed_lines = 
      lines
      |> Enum.with_index()
      |> Enum.map(fn {line, index} ->
        cond do
          # Line starts with |> followed by a word (orphaned pipeline)
          String.match?(line, ~r/^\s*\|>\s*[A-Za-z_][A-Za-z0-9_]*\s*$/) ->
            # Check if previous line ends with ->
            prev_line = if index > 0, do: Enum.at(lines, index - 1), else: ""
            if String.match?(prev_line || "", ~r/->\s*$/) do
              # Remove the |> and extra indentation
              String.replace(line, ~r/^\s*\|>\s*/, "        ")
            else
              line
            end
          
          # Line has orphaned |> at start with more complex expressions
          String.match?(line, ~r/^\s*\|>\s*/) ->
            # Remove the orphaned |>
            String.replace(line, ~r/^\s*\|>\s*/, "    ")
          
          true ->
            line
        end
      end)
    
    Enum.join(fixed_lines, "\n")
  end
  
  defp fix_malformed_function_calls(content) do
    content
    # Fix: word function_name() -> function_name(word)
    |> String.replace(~r/(\w+)\s+([A-Z][A-Za-z0-9_.]*\w+)\(\)/, "\\2(\\1)", global: true)
    # Fix: word String.something() -> String.something(word)
    |> String.replace(~r/(\w+)\s+(String\.[a-z_]+)\(\)/, "\\2(\\1)", global: true)
    # Fix: word Enum.something() -> Enum.something(word)
    |> String.replace(~r/(\w+)\s+(Enum\.[a-z_]+)\(\)/, "\\2(\\1)", global: true)
    # Fix other module calls
    |> String.replace(~r/(\w+)\s+([A-Z][A-Za-z0-9_]*\.[a-z_]+)\(\)/, "\\2(\\1)", global: true)
  end
  
  defp fix_pipeline_continuations(content) do
    content
    # Fix functions that got broken across lines incorrectly
    |> String.replace(~r/(\w+)\s*\n\s*\|>\s*([A-Z][A-Za-z_.]+)\(\)/m, "|> \\2(\\1)")
    # Fix bare function names that should be in pipeline
    |> String.replace(~r/\n\s*([A-Z][A-Za-z0-9_.]+)\(\)\s*$/m, " |> \\1()")
  end
end

# Run the fixer
PipelineFixer.fix_all_files()