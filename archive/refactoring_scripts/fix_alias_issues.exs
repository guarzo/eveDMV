#!/usr/bin/env elixir

# Script to fix alias organization issues more carefully
defmodule AliasOrganizationFixer do
  def fix_all_files() do
    "lib"
    |> File.ls!()
    |> Enum.each(fn dir ->
      Path.join("lib", dir)
      |> find_ex_files()
      |> Enum.each(&fix_file/1)
    end)
  end

  defp find_ex_files(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.flat_map(fn file ->
          path = Path.join(dir, file)

          cond do
            String.ends_with?(file, ".ex") -> [path]
            File.dir?(path) -> find_ex_files(path)
            true -> []
          end
        end)

      _ ->
        []
    end
  end

  defp fix_file(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        fixed_content =
          content
          |> fix_grouped_aliases()
          |> fix_alias_ordering()
          |> alphabetize_aliases()

        if fixed_content != content do
          File.write!(file_path, fixed_content)
          IO.puts("Fixed: #{file_path}")
        end

      _ ->
        :ok
    end
  end

  defp fix_grouped_aliases(content) do
    # Pattern to match grouped aliases like: alias Module.{A, B, C}
    content
    |> String.replace(~r/alias\s+([^{\s]+)\{([^}]+)\}/m, fn match ->
      [_, prefix, modules] = Regex.run(~r/alias\s+([^{\s]+)\{([^}]+)\}/, match)

      modules
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(fn mod -> "  alias #{prefix}#{mod}" end)
      |> Enum.join("\n")
    end)
  end

  defp fix_alias_ordering(content) do
    lines = String.split(content, "\n")

    # Find the module declaration and organize imports after it
    {before_imports, after_imports} =
      lines
      |> Enum.with_index()
      |> Enum.find_index(fn {line, _} ->
        String.match?(line, ~r/^\s*def\s+/) or String.match?(line, ~r/^\s*@\w+/)
      end)
      |> case do
        nil -> {lines, []}
        idx -> Enum.split(lines, idx)
      end

    # Extract and organize imports from the before_imports section
    {imports, non_imports} =
      before_imports
      |> Enum.split_with(fn line ->
        String.match?(line, ~r/^\s*(use|alias|require|import)\s+/)
      end)

    # Sort imports: use, alias, require, import
    sorted_imports =
      imports
      |> Enum.sort_by(fn line ->
        cond do
          String.match?(line, ~r/^\s*use\s+/) -> {1, line}
          String.match?(line, ~r/^\s*alias\s+/) -> {2, line}
          String.match?(line, ~r/^\s*require\s+/) -> {3, line}
          String.match?(line, ~r/^\s*import\s+/) -> {4, line}
          true -> {5, line}
        end
      end)

    # Reconstruct the content
    (non_imports ++ sorted_imports ++ after_imports)
    |> Enum.join("\n")
  end

  defp alphabetize_aliases(content) do
    # Find consecutive alias lines and sort them
    lines = String.split(content, "\n")

    lines
    |> Enum.chunk_while(
      [],
      fn line, acc ->
        if String.match?(line, ~r/^\s*alias\s+/) do
          {:cont, acc ++ [line]}
        else
          case acc do
            [] -> {:cont, [line]}
            aliases -> {:cont, Enum.sort(aliases) ++ [line], []}
          end
        end
      end,
      fn acc ->
        case acc do
          [] -> {:cont, []}
          aliases -> {:cont, Enum.sort(aliases), []}
        end
      end
    )
    |> List.flatten()
    |> Enum.join("\n")
  end
end

AliasOrganizationFixer.fix_all_files()
