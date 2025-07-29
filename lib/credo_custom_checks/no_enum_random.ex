defmodule CredoCustomChecks.NoEnumRandom do
  @moduledoc """
  A custom Credo check that detects usage of Enum.random/1 in non-test code.

  This check prevents the use of random selection in production code, which is
  often used as a placeholder for real logic.
  """

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    tags: [:placeholder, :random],
    explanations: [
      check: """
      This check prevents the use of Enum.random/1 in production code.

      Using Enum.random/1 to select values is a placeholder pattern that should
      not exist in production code. All selections should be based on real logic
      and data, not random chance.
      """,
      params: [
        allow_in_tests: "Whether to allow Enum.random in test files (default: true)"
      ]
    ],
    param_defaults: [
      allow_in_tests: true
    ]

  alias Credo.Check.Params
  alias Credo.Code
  alias Credo.IssueMeta

  @doc false
  def run(source_file, params \\ []) do
    if skip_file?(source_file, params) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> Code.prewalk(&traverse/2, &find_enum_random(&1, &2, issue_meta))
    end
  end

  defp skip_file?(source_file, params) do
    allow_in_tests = Params.get(params, :allow_in_tests, param_defaults()[:allow_in_tests])

    allow_in_tests &&
      (String.contains?(source_file.filename, "/test/") ||
         String.ends_with?(source_file.filename, "_test.exs") ||
         String.contains?(source_file.filename, "/factory") ||
         String.contains?(source_file.filename, "/mock"))
  end

  defp traverse(ast, issues) do
    {ast, issues}
  end

  defp find_enum_random(
         {{:., _, [{:__aliases__, _, [:Enum]}, :random]}, meta, _args} = ast,
         issues,
         issue_meta
       ) do
    issue =
      issue_for(
        issue_meta,
        meta[:line],
        "Enum.random/1 detected - use deterministic logic instead of random selection"
      )

    {ast, [issue | issues]}
  end

  defp find_enum_random({:random, meta, args} = ast, issues, issue_meta) when is_list(args) do
    issue =
      issue_for(
        issue_meta,
        meta[:line],
        "Random function detected - placeholder implementations should use real logic"
      )

    {ast, [issue | issues]}
  end

  defp find_enum_random(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, line_no, message) do
    Credo.Check.format_issue(__MODULE__, issue_meta,
      message: message,
      line_no: line_no || 1,
      trigger: "Enum.random"
    )
  end
end
