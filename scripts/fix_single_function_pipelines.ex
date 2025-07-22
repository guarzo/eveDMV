#!/usr/bin/env elixir
# Fix single function pipelines automatically

defmodule PipelineFixer do
  def fix_file(file_path) do
    content = File.read!(file_path)
    
    # Pattern 1: |> Function.call() -> Function.call()
    fixed_content = 
      content
      |> String.replace(~r/\|>\s+([A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*)\(\)/, "\\1()")
      |> String.replace(~r/\|>\s+([A-Za-z_][A-Za-z0-9_]*)\(\)/, "\\1()")
      |> String.replace(~r/\|>\s+Enum\.([A-Za-z_][A-Za-z0-9_]*)\(\)/, "Enum.\\1()")
      |> String.replace(~r/\|>\s+String\.([A-Za-z_][A-Za-z0-9_]*)\(\)/, "String.\\1()")
      |> String.replace(~r/\|>\s+Map\.([A-Za-z_][A-Za-z0-9_]*)\(\)/, "Map.\\1()")
      |> String.replace(~r/\|>\s+List\.([A-Za-z_][A-Za-z0-9_]*)\(\)/, "List.\\1()")
      
    if fixed_content != content do
      File.write!(file_path, fixed_content)
      IO.puts("Fixed pipelines in #{file_path}")
    end
  end
  
  def run do
    # Find all .ex files
    files = 
      Path.wildcard("lib/**/*.ex")
      |> Enum.filter(&File.regular?/1)
    
    IO.puts("Fixing single function pipelines in #{length(files)} files...")
    
    Enum.each(files, &fix_file/1)
    
    IO.puts("Pipeline fixes complete!")
  end
end

PipelineFixer.run()