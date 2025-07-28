defmodule CredoCustomChecks.NoModuloClassification do
  @moduledoc """
  A custom Credo check that detects modulo-based classification patterns.

  This check identifies code that uses modulo operations for arbitrary classifications,
  which is a common placeholder pattern (e.g., ship_type_id % 10).
  """

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    tags: [:placeholder, :classification],
    explanations: [
      check: """
      This check prevents the use of modulo operations for classification purposes.

      Using modulo operations like `ship_type_id % 10` for classification is a
      placeholder pattern that produces arbitrary results. Real classifications
      should be based on actual game data and logic.
      """,
      params: [
        allow_in_tests: "Whether to allow modulo patterns in test files (default: true)"
      ]
    ],
    param_defaults: [
      allow_in_tests: true
    ]

  alias Credo.Code

  @doc false
  def run(source_file, params \\ []) do
    if skip_file?(source_file, params) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Code.prewalk(&traverse/2, &find_modulo_issues(&1, &2, issue_meta))
    end
  end

  defp skip_file?(source_file, params) do
    allow_in_tests = Params.get(params, :allow_in_tests, param_defaults()[:allow_in_tests])

    allow_in_tests &&
      (String.contains?(source_file.filename, "/test/") ||
         String.ends_with?(source_file.filename, "_test.exs"))
  end

  defp traverse(ast, issues) do
    {ast, issues}
  end

  defp find_modulo_issues({:rem, meta, [left, right]} = ast, issues, issue_meta) do
    if classification_pattern?(left, right) do
      issue =
        issue_for(
          issue_meta,
          meta[:line],
          "Modulo operation used for classification - use real data instead"
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp find_modulo_issues({:%, meta, [left, right]} = ast, issues, issue_meta) do
    if classification_pattern?(left, right) do
      issue =
        issue_for(
          issue_meta,
          meta[:line],
          "Modulo operation used for classification - use real data instead"
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp find_modulo_issues(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp classification_pattern?(left, right) do
    # Check if left side contains ID-like variables
    id_pattern =
      case left do
        {:ship_type_id, _, _} -> true
        {:type_id, _, _} -> true
        {:character_id, _, _} -> true
        {:corporation_id, _, _} -> true
        {:alliance_id, _, _} -> true
        {:solar_system_id, _, _} -> true
        _ -> false
      end

    # Check if right side is a small constant (typical for classification)
    small_constant =
      case right do
        n when is_integer(n) and n > 1 and n <= 20 -> true
        _ -> false
      end

    id_pattern && small_constant
  end

  defp issue_for(issue_meta, line_no, message) do
    format_issue(issue_meta,
      message: message,
      line_no: line_no || 1
    )
  end
end
