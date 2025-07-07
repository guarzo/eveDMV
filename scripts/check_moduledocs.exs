#!/usr/bin/env elixir

defmodule ModuledocChecker do
  @moduledoc """
  Script to check for missing @moduledoc attributes in Elixir modules.
  """

  def check_missing_moduledocs do
    missing_docs =
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.filter(&is_elixir_module_file?/1)
      |> Enum.map(&check_file/1)
      |> Enum.filter(& &1)

    if Enum.empty?(missing_docs) do
      IO.puts("✅ All modules have @moduledoc attributes")
      System.halt(0)
    else
      IO.puts("❌ Found #{length(missing_docs)} modules missing @moduledoc:")
      Enum.each(missing_docs, fn {file, module} ->
        IO.puts("  - #{module} in #{file}")
      end)
      System.halt(1)
    end
  end

  defp is_elixir_module_file?(file) do
    String.ends_with?(file, ".ex") and not String.contains?(file, "/test/")
  end

  defp check_file(file) do
    case File.read(file) do
      {:ok, content} ->
        case extract_module_name(content) do
          nil -> nil
          module_name ->
            if has_moduledoc?(content) do
              nil
            else
              {file, module_name}
            end
        end
      {:error, _} -> nil
    end
  end

  defp extract_module_name(content) do
    case Regex.run(~r/^\s*defmodule\s+([A-Za-z0-9_.]+)/m, content) do
      [_, module_name] -> module_name
      _ -> nil
    end
  end

  defp has_moduledoc?(content) do
    # Check for @moduledoc presence (including @moduledoc false)
    Regex.match?(~r/^\s*@moduledoc/m, content)
  end
end

ModuledocChecker.check_missing_moduledocs()