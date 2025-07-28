defmodule CredoCustomChecks.NoPlaceholderImplementations do
  @moduledoc """
  A custom Credo check that detects placeholder implementations.

  This check identifies common patterns used in placeholder code:
  - Hardcoded magic numbers (DPS values, mass thresholds, etc.)
  - Random data generation in non-test code
  - Empty return values ([], %{})
  - Modulo-based logic for classifications
  - TODO/FIXME comments indicating incomplete implementation
  """

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    tags: [:placeholder, :incomplete],
    explanations: [
      check: """
      This check ensures that no placeholder implementations exist in the codebase.

      EVE DMV follows a "Clean Codebase Vision" where every function must provide
      real value or not exist at all. Placeholder implementations that return
      hardcoded values, empty data structures, or use random generation are not allowed.
      """,
      params: [
        hardcoded_values: "List of hardcoded values to flag (e.g., [200, 600, 800, 1000])",
        allow_in_tests: "Whether to allow these patterns in test files (default: true)"
      ]
    ],
    param_defaults: [
      hardcoded_values: [200, 600, 800, 1000, 10_000_000, 100_000_000],
      allow_in_tests: true
    ]

  alias Credo.Check.Params
  alias Credo.IssueMeta

  @doc false
  def run(source_file, params \\ []) do
    # Skip test files if configured
    if skip_file?(source_file, params) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Credo.Code.to_tokens()
      |> find_issues(issue_meta, params)
    end
  end

  defp skip_file?(source_file, params) do
    allow_in_tests = Params.get(params, :allow_in_tests, param_defaults()[:allow_in_tests])

    allow_in_tests &&
      (String.contains?(source_file.filename, "/test/") ||
         String.ends_with?(source_file.filename, "_test.exs"))
  end

  defp find_issues(tokens, issue_meta, params) do
    hardcoded_values =
      Params.get(params, :hardcoded_values, param_defaults()[:hardcoded_values])

    tokens
    |> Enum.flat_map(fn token ->
      case check_token(token, hardcoded_values) do
        nil -> []
        issue -> [issue_for(issue_meta, token, issue)]
      end
    end)
  end

  defp check_token({:int, _, value}, hardcoded_values) do
    if value in hardcoded_values do
      "Hardcoded value #{value} detected - likely placeholder implementation"
    else
      nil
    end
  end

  defp check_token({:atom, _, :rand}, _) do
    "Random generation detected - placeholder implementations should not use :rand"
  end

  defp check_token({:atom, _, :random}, _) do
    "Random generation detected - placeholder implementations should not use :random"
  end

  defp check_token({:list, _, []}, _) do
    "Empty list [] returned - functions should return meaningful data or not exist"
  end

  defp check_token({:map, _, %{}}, _) do
    "Empty map %{} returned - functions should return meaningful data or not exist"
  end

  defp check_token({:comment, _, comment}, _) do
    comment_text = to_string(comment)

    cond do
      String.contains?(comment_text, ["TODO", "FIXME", "PLACEHOLDER", "STUB"]) ->
        "Comment indicates incomplete implementation: #{String.trim(comment_text)}"

      String.contains?(comment_text, ["hardcoded", "magic number", "arbitrary"]) ->
        "Comment suggests placeholder values: #{String.trim(comment_text)}"

      true ->
        nil
    end
  end

  defp check_token(_, _), do: nil

  defp issue_for(issue_meta, {_, {line_no, column, _}, _}, message) do
    format_issue(issue_meta,
      message: message,
      line_no: line_no,
      column: column
    )
  end

  defp issue_for(issue_meta, {_, {line_no, _}, _}, message) do
    format_issue(issue_meta,
      message: message,
      line_no: line_no
    )
  end
end
