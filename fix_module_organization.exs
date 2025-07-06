defmodule ModuleOrganizationFixer do
  @moduledoc """
  Automated fixer for Credo module organization warnings.
  Fixes:
  - Alias alphabetization
  - Import/alias/require ordering
  - Module attribute ordering
  - Grouped alias expansion
  """

  def run do
    files = Path.wildcard("lib/**/*.ex") ++ Path.wildcard("lib/**/*.exs")
    
    IO.puts("Processing #{length(files)} files...")
    
    results = Enum.map(files, fn file ->
      case fix_file(file) do
        :ok -> {:ok, file}
        {:error, reason} -> {:error, file, reason}
      end
    end)
    
    {successes, failures} = Enum.split_with(results, fn
      {:ok, _} -> true
      _ -> false
    end)
    
    IO.puts("\nCompleted:")
    IO.puts("  ✓ Fixed: #{length(successes)} files")
    IO.puts("  ✗ Failed: #{length(failures)} files")
    
    if length(failures) > 0 do
      IO.puts("\nFailed files:")
      Enum.each(failures, fn {:error, file, reason} ->
        IO.puts("  - #{file}: #{reason}")
      end)
    end
  end

  def fix_file(file_path) do
    try do
      content = File.read!(file_path)
      
      if contains_module_definition?(content) do
        fixed_content = fix_content(content)
        File.write!(file_path, fixed_content)
        :ok
      else
        :ok
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp contains_module_definition?(content) do
    String.contains?(content, "defmodule ")
  end

  defp fix_content(content) do
    # Split into module definition and body
    case Regex.split(~r/^defmodule\s+[\w\.]+\s+do$/m, content, parts: 2, include_captures: true) do
      [before_module, module_def, module_body] ->
        # Process the module body
        {fixed_body, after_end} = process_module_body(module_body)
        before_module <> module_def <> fixed_body <> after_end
      
      _ ->
        # No proper module definition found, return as is
        content
    end
  end

  defp process_module_body(body) do
    # Find the matching 'end' for the module
    {module_content, after_end} = extract_module_content(body)
    
    # Extract and organize different sections
    sections = extract_sections(module_content)
    
    # Fix and reorder sections
    fixed_sections = fix_sections(sections)
    
    # Reconstruct the module body
    fixed_body = reconstruct_module(fixed_sections)
    
    {fixed_body, after_end}
  end

  defp extract_module_content(body) do
    lines = String.split(body, "\n")
    {module_lines, rest} = extract_until_module_end(lines, 0, [])
    
    module_content = Enum.join(Enum.reverse(module_lines), "\n")
    after_end = Enum.join(rest, "\n")
    
    {module_content, after_end}
  end

  defp extract_until_module_end([], _depth, acc), do: {acc, []}
  defp extract_until_module_end([line | rest], depth, acc) do
    new_depth = cond do
      String.match?(line, ~r/\b(do|fn)\s*$/) -> depth + 1
      String.trim(line) == "end" -> depth - 1
      true -> depth
    end
    
    if new_depth < 0 do
      {acc, [line | rest]}
    else
      extract_until_module_end(rest, new_depth, [line | acc])
    end
  end

  defp extract_sections(content) do
    lines = String.split(content, "\n")
    
    %{
      moduledoc: extract_moduledoc(lines),
      behaviours: extract_behaviours(lines),
      uses: extract_uses(lines),
      imports: extract_imports(lines),
      aliases: extract_aliases(lines),
      requires: extract_requires(lines),
      module_attributes: extract_module_attributes(lines),
      types: extract_types(lines),
      defstruct: extract_defstruct(lines),
      other: extract_other(lines)
    }
  end

  defp extract_moduledoc(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*@moduledoc/))
    |> extract_multiline_content(lines)
  end

  defp extract_behaviours(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*@behaviour/))
  end

  defp extract_uses(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*use\s+/))
  end

  defp extract_imports(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*import\s+/))
    |> Enum.sort()
  end

  defp extract_aliases(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*alias\s+/))
    |> expand_grouped_aliases()
    |> Enum.sort()
  end

  defp extract_requires(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*require\s+/))
    |> Enum.sort()
  end

  defp extract_module_attributes(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*@\w+\s+/) and 
                   not String.match?(&1, ~r/^\s*@(moduledoc|doc|behaviour|type|spec|callback|macrocallback|typep|opaque|typedoc)/))
  end

  defp extract_types(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*@(type|typep|opaque)\s+/))
  end

  defp extract_defstruct(lines) do
    lines
    |> Enum.filter(&String.match?(&1, ~r/^\s*defstruct/))
  end

  defp extract_other(lines) do
    special_patterns = [
      ~r/^\s*@moduledoc/,
      ~r/^\s*@behaviour/,
      ~r/^\s*use\s+/,
      ~r/^\s*import\s+/,
      ~r/^\s*alias\s+/,
      ~r/^\s*require\s+/,
      ~r/^\s*@\w+\s+/,
      ~r/^\s*defstruct/
    ]
    
    lines
    |> Enum.reject(fn line ->
      Enum.any?(special_patterns, &String.match?(line, &1))
    end)
  end

  defp extract_multiline_content(matching_lines, all_lines) do
    # For moduledoc with triple quotes, we need to extract the full content
    matching_lines
  end

  defp expand_grouped_aliases(aliases) do
    Enum.flat_map(aliases, fn alias_line ->
      case Regex.run(~r/^\s*alias\s+([\w\.]+)\.\{([^}]+)\}/, alias_line) do
        [_, base, grouped] ->
          indent = extract_indent(alias_line)
          grouped
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.map(fn module ->
            "#{indent}alias #{base}.#{module}"
          end)
        
        _ ->
          [alias_line]
      end
    end)
  end

  defp extract_indent(line) do
    case Regex.run(~r/^(\s*)/, line) do
      [_, indent] -> indent
      _ -> ""
    end
  end

  defp fix_sections(sections) do
    sections
  end

  defp reconstruct_module(sections) do
    # Reconstruct in the correct order
    [
      sections.moduledoc,
      sections.behaviours,
      sections.uses,
      sections.imports,
      sections.aliases,
      sections.requires,
      sections.module_attributes,
      sections.types,
      sections.defstruct,
      sections.other
    ]
    |> Enum.map(&Enum.join(&1, "\n"))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
    |> String.replace(~r/\n{3,}/, "\n\n")
  end
end

# Run the fixer
ModuleOrganizationFixer.run()