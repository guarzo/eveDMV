#\!/bin/bash
# Fix remaining import ordering issues

set -e

echo "=== FIXING REMAINING IMPORT ORDERING ISSUES ==="

# Get all files with import ordering issues
mix credo --strict --format=json | jq -r '.issues[] | select(.message | contains("alias must appear before require") or contains("use must appear before alias")) | .filename' | sort | uniq > /tmp/files_to_fix.txt

echo "Found $(wc -l < /tmp/files_to_fix.txt) files to fix"

# Process each file
while IFS= read -r file; do
    echo "Processing: $file"
    
    # Create a backup
    cp "$file" "$file.bak"
    
    # Use Elixir script to fix the file
    elixir -e '
    defmodule ImportFixer do
      def fix_file(filepath) do
        content = File.read\!(filepath)
        lines = String.split(content, "\n")
        
        fixed_lines = fix_module(lines)
        
        File.write\!(filepath, Enum.join(fixed_lines, "\n"))
      end
      
      def fix_module(lines) do
        case find_module_boundaries(lines) do
          nil -> lines
          {module_start, content_end} ->
            before_module = Enum.slice(lines, 0..module_start)
            module_content = Enum.slice(lines, (module_start + 1)..(content_end - 1))
            after_content = Enum.slice(lines, content_end..-1)
            
            fixed_content = reorganize_imports(module_content)
            
            before_module ++ fixed_content ++ after_content
        end
      end
      
      def find_module_boundaries(lines) do
        module_idx = Enum.find_index(lines, &String.match?(&1, ~r/^\s*defmodule\s+/))
        
        if module_idx do
          # Find first def/defp/defmacro/defstruct/@
          content_end = 
            lines
            |> Enum.with_index()
            |> Enum.find(fn {line, idx} ->
              idx > module_idx && 
              String.match?(line, ~r/^\s*(def|defp|defmacro|defmacrop|defstruct|defexception|@moduledoc|@doc)\s+/)
            end)
          
          case content_end do
            nil -> {module_idx, length(lines)}
            {_, idx} -> {module_idx, idx}
          end
        end
      end
      
      def reorganize_imports(lines) do
        {imports, other} = Enum.split_with(lines, fn line ->
          trimmed = String.trim(line)
          trimmed == "" ||
          String.starts_with?(trimmed, "#") ||
          String.starts_with?(trimmed, "use ") ||
          String.starts_with?(trimmed, "alias ") ||
          String.starts_with?(trimmed, "require ") ||
          String.starts_with?(trimmed, "import ")
        end)
        
        # Categorize imports
        categorized = Enum.group_by(imports, fn line ->
          trimmed = String.trim(line)
          cond do
            trimmed == "" -> :blank
            String.starts_with?(trimmed, "#") -> :comment
            String.starts_with?(trimmed, "use ") -> :use
            String.starts_with?(trimmed, "alias ") -> :alias
            String.starts_with?(trimmed, "require ") -> :require
            String.starts_with?(trimmed, "import ") -> :import
            true -> :other
          end
        end)
        
        # Get sorted lists
        uses = Map.get(categorized, :use, []) |> Enum.sort()
        aliases = Map.get(categorized, :alias, []) |> Enum.sort()
        requires = Map.get(categorized, :require, []) |> Enum.sort()
        imports = Map.get(categorized, :import, []) |> Enum.sort()
        
        # Build result preserving comments
        result = []
        
        # Add uses
        if length(uses) > 0 do
          result = result ++ uses
          if length(aliases) + length(requires) + length(imports) > 0 do
            result = result ++ [""]
          end
        end
        
        # Add aliases  
        if length(aliases) > 0 do
          result = result ++ aliases
          if length(requires) + length(imports) > 0 do
            result = result ++ [""]
          end
        end
        
        # Add requires
        if length(requires) > 0 do
          result = result ++ requires
          if length(imports) > 0 do
            result = result ++ [""]
          end
        end
        
        # Add imports
        if length(imports) > 0 do
          result = result ++ imports
          if length(other) > 0 do
            result = result ++ [""]
          end
        end
        
        # Add other lines back
        result ++ other
      end
    end
    
    ImportFixer.fix_file("'"$file"'")
    '
    
    # Check if the file compiles
    if elixirc --warnings-as-errors "$file" 2>/dev/null; then
        echo "✓ Fixed: $file"
        rm -f "$file.bak"
    else
        echo "✗ Failed to fix: $file (restoring backup)"
        mv "$file.bak" "$file"
    fi
    
done < /tmp/files_to_fix.txt

echo "=== IMPORT ORDERING FIX COMPLETE ==="

# Check remaining errors
echo "Checking remaining errors..."
REMAINING=$(mix credo --strict | grep -E "(alias must appear before|use must appear before)" | wc -l)
echo "Remaining import ordering errors: $REMAINING"
