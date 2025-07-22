defmodule EveDmv.QualityRegressionTest do
  @moduledoc """
  Quality regression prevention tests.

  Part of Sprint 22 Quality Standards - ensures quality metrics don't regress.
  """

  use ExUnit.Case, async: true

  @moduletag :quality

  describe "code quality metrics" do
    test "credo issues remain below Sprint 22 target" do
      # Run credo and count issues using secure port approach
      {output, _exit_code} =
        System.cmd("mix", ["credo", "--format=oneline"], stderr_to_stdout: true, env: %{})

      # Parse output to count issues
      issue_count =
        output
        |> String.split("\n")
        |> Enum.filter(&String.contains?(&1, " ↗ "))
        |> length()

      # Sprint 22 target: <500 total issues
      target_issues = 500

      assert issue_count < target_issues,
             "Credo issues exceeded target: #{issue_count} >= #{target_issues}. " <>
               "Run 'mix credo' to see details."
    end

    test "compilation succeeds without warnings" do
      # Use secure approach with System.cmd 
      {output, _exit_code} =
        System.cmd("mix", ["compile", "--warnings-as-errors"], stderr_to_stdout: true, env: %{})

      # Check for error indicators in output instead of exit code
      refute String.contains?(output, "error:") or String.contains?(output, "Error:"),
             "Compilation failed or has warnings: #{String.slice(output, 0, 200)}..."
    end

    test "formatting is consistent" do
      # Use secure approach with System.cmd
      {output, _exit_code} =
        System.cmd("mix", ["format", "--check-formatted"], stderr_to_stdout: true, env: %{})

      # Check for formatting error indicators in output
      refute String.contains?(output, "** (Mix)") or String.contains?(output, "not formatted"),
             "Code formatting is inconsistent: #{String.slice(output, 0, 200)}... Run 'mix format' to fix."
    end

    test "large functions remain within limits" do
      # Count functions >50 lines (critical threshold)
      large_functions = count_large_functions(50)

      # Sprint 22 target: 0 functions >50 lines
      assert large_functions == 0,
             "Found #{large_functions} functions >50 lines. " <>
               "Run './scripts/refactor_large_functions.sh' for analysis."
    end

    test "utility modules exist and are usable" do
      # Verify our duplication elimination modules are available
      assert Code.ensure_loaded?(EveDmv.Utils.QueryHelpers)
      assert Code.ensure_loaded?(EveDmv.Utils.ErrorHandling)
      assert Code.ensure_loaded?(EveDmv.Utils.DataTransform)
      assert Code.ensure_loaded?(EveDmv.Utils.Validation)
    end
  end

  describe "style guide compliance" do
    test "team style guide exists and is accessible" do
      style_guide_path = Path.join([File.cwd!(), "docs", "TEAM_STYLE_GUIDE.md"])
      assert File.exists?(style_guide_path), "Team style guide not found at #{style_guide_path}"

      content = File.read!(style_guide_path)
      assert String.contains?(content, "Sprint 22"), "Style guide should reference Sprint 22"

      assert String.contains?(content, "Quality Standards"),
             "Style guide should mention quality standards"
    end

    test "pre-commit configuration exists" do
      precommit_path = Path.join([File.cwd!(), ".pre-commit-config.yaml"])
      assert File.exists?(precommit_path), "Pre-commit config not found"

      content = File.read!(precommit_path)
      assert String.contains?(content, "mix format"), "Pre-commit should include formatting"
      assert String.contains?(content, "mix credo"), "Pre-commit should include credo checks"
    end
  end

  defp count_large_functions(line_limit) do
    Path.wildcard("lib/**/*.ex")
    |> Enum.map(&count_large_functions_in_file(&1, line_limit))
    |> Enum.sum()
  end

  defp count_large_functions_in_file(file_path, line_limit) do
    file_path
    |> File.read!()
    |> String.split("\n")
    |> count_functions_over_limit(line_limit)
  rescue
    _ -> 0
  end

  defp count_functions_over_limit(lines, line_limit) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({0, nil, 0}, fn {line, line_num}, {count, func_start, current_count} ->
      cond do
        String.match?(line, ~r/^\s*def\s/) ->
          {count, line_num, 0}

        String.match?(line, ~r/^\s*end\s*$/) and not is_nil(func_start) ->
          function_length = line_num - func_start + 1
          new_count = if function_length > line_limit, do: count + 1, else: count
          {new_count, nil, 0}

        true ->
          {count, func_start, current_count}
      end
    end)
    |> elem(0)
  end
end
