#!/usr/bin/env elixir
# Script to remove unused functions from Elixir files

defmodule UnusedFunctionRemover do
  def run do
    IO.puts("🧹 Removing unused functions from Elixir codebase...")

    # Parse dialyzer output
    unused_functions = parse_dialyzer_output()
    IO.puts("Found #{Enum.count(unused_functions)} unused functions")

    # Group by file
    by_file = Enum.group_by(unused_functions, fn {file, _, _, _} -> file end)

    # Create backup directory
    backup_dir = "/tmp/unused_backup_#{:os.system_time(:second)}"
    File.mkdir_p!(backup_dir)
    IO.puts("Backup directory: #{backup_dir}")

    # Process each file
    Enum.each(by_file, fn {file, functions} ->
      process_file(file, functions, backup_dir)
    end)

    IO.puts("\n✅ Removal complete!")
    IO.puts("Run 'mix compile --warnings-as-errors' to verify")
  end

  defp parse_dialyzer_output do
    File.read!("/workspace/dialyzer.txt")
    |> String.split("\n")
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.filter(fn [line1, _] -> String.contains?(line1, "unused_fun") end)
    |> Enum.map(fn [line1, line2] ->
      case parse_unused_line(line1, line2) do
        nil -> nil
        result -> result
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_unused_line(location_line, message_line) do
    # Parse location line: "file.ex:123:unused_fun"
    case String.split(location_line, ":") do
      [file, line_num, "unused_fun" | _] ->
        # Parse message line: "Function name/arity will never be called."
        case Regex.run(~r/Function (\w+)\/(\d+) will never be called/, message_line) do
          [_, func_name, arity] ->
            {file, String.to_integer(line_num), func_name, String.to_integer(arity)}
          _ ->
            nil
        end
      _ ->
        nil
    end
  end

  defp process_file(file, functions, backup_dir) do
    unless File.exists?(file) do
      IO.puts("Skipping non-existent file: #{file}")
      :ok
    else

    IO.puts("\nProcessing: #{file}")
    IO.puts("  Functions to remove: #{length(functions)}")

    # Backup file
    File.cp!(file, Path.join(backup_dir, Path.basename(file)))

    # Read file content
    content = File.read!(file)
    lines = String.split(content, "\n")

    # Build a set of functions to remove
    functions_to_remove = MapSet.new(functions, fn {_, _, name, arity} ->
      {name, arity}
    end)

    # Process lines
    {new_lines, _} = remove_functions(lines, functions_to_remove)

    # Write back
    new_content = Enum.join(new_lines, "\n")
    File.write!(file, new_content)

    IO.puts("  ✓ Processed #{file}")
    end
  end

  defp remove_functions(lines, functions_to_remove) do
    remove_functions(lines, functions_to_remove, [], :normal)
  end

  defp remove_functions([], _functions, acc, state) do
    {Enum.reverse(acc), state}
  end

  defp remove_functions([line | rest], functions, acc, :normal) do
    cond do
      # Check for function definition
      match = Regex.run(~r/^\s*defp?\s+(\w+)\s*\(/, line) ->
        [_, func_name] = match
        # Try to determine arity
        case detect_function_arity(line, rest) do
          {:ok, arity, consumed_lines} ->
            if MapSet.member?(functions, {func_name, arity}) do
              IO.puts("  Removing: #{func_name}/#{arity}")
              # Skip this function
              remaining = skip_function_body(rest, consumed_lines)
              # Also skip any @doc or @spec above
              filtered_acc = remove_trailing_docs(acc)
              remove_functions(remaining, functions, filtered_acc, :normal)
            else
              # Keep the function
              remove_functions(rest, functions, [line | acc], :normal)
            end
          :error ->
            # Couldn't determine arity, keep it
            remove_functions(rest, functions, [line | acc], :normal)
        end

      # Skip empty lines after removals to avoid excessive whitespace
      String.trim(line) == "" && match?(["" | _], acc) ->
        remove_functions(rest, functions, acc, :normal)

      true ->
        remove_functions(rest, functions, [line | acc], :normal)
    end
  end

  defp detect_function_arity(first_line, _rest_lines) do
    # Simple detection - count parameters
    if String.contains?(first_line, "()") do
      {:ok, 0, 0}
    else
      # For now, use a simple heuristic
      # This would need to be more sophisticated for production use
      case Regex.run(~r/\((.*?)\)/, first_line) do
        [_, params] when params == "" ->
          {:ok, 0, 0}
        [_, params] ->
          # Count commas + 1
          arity = length(String.split(params, ","))
          {:ok, arity, 0}
        _ ->
          # Multi-line function signature - skip for now
          :error
      end
    end
  end

  defp skip_function_body(lines, already_consumed) do
    # Skip lines that were part of the function signature
    lines = Enum.drop(lines, already_consumed)

    # Find the end of the function
    case find_function_end(lines, 0) do
      {:ok, n} -> Enum.drop(lines, n + 1)
      :error -> lines
    end
  end

  defp find_function_end(lines, count) do
    find_function_end(lines, count, nil)
  end

  defp find_function_end([], count, _indent) do
    {:ok, count}
  end

  defp find_function_end([line | rest], count, base_indent) do
    trimmed = String.trim_leading(line)
    current_indent = String.length(line) - String.length(trimmed)

    cond do
      # Empty line
      trimmed == "" ->
        find_function_end(rest, count + 1, base_indent)

      # First non-empty line sets the base indent
      base_indent == nil ->
        find_function_end(rest, count + 1, current_indent)

      # Found end at same or lower indentation
      current_indent <= base_indent && Regex.match?(~r/^(defp?|end)\s/, trimmed) ->
        if trimmed == "end" && current_indent == base_indent do
          {:ok, count}
        else
          {:ok, count - 1}
        end

      true ->
        find_function_end(rest, count + 1, base_indent)
    end
  end

  defp remove_trailing_docs(acc) do
    acc
    |> Enum.reverse()
    |> Enum.drop_while(fn line ->
      trimmed = String.trim(line)
      trimmed == "" || String.starts_with?(trimmed, "@") || String.starts_with?(trimmed, "#")
    end)
    |> Enum.reverse()
  end
end

# Run the script
UnusedFunctionRemover.run()