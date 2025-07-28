defmodule CredoCustomChecks.RequireRealData do
  @moduledoc """
  A custom Credo check that ensures functions query real data instead of returning hardcoded values.

  This check identifies functions that return static data without any database queries
  or calculations, which indicates placeholder implementations.
  """

  use Credo.Check,
    category: :warning,
    base_priority: :high,
    tags: [:placeholder, :data],
    explanations: [
      check: """
      This check ensures functions use real data from the database or calculations.

      Functions that return hardcoded lists, maps, or values without querying
      the database or performing calculations are likely placeholder implementations.
      Real implementations should query actual game data.
      """,
      params: [
        suspicious_return_values: "List of return values that indicate placeholders",
        allow_in_tests: "Whether to allow these patterns in test files (default: true)"
      ]
    ],
    param_defaults: [
      suspicious_return_values: [
        {:ok, []},
        {:ok, %{}},
        {:error, :not_implemented},
        :not_implemented,
        []
      ],
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
      |> Code.prewalk(&traverse/2, &check_function_body(&1, &2, issue_meta))
    end
  end

  defp skip_file?(source_file, params) do
    allow_in_tests = Params.get(params, :allow_in_tests, param_defaults()[:allow_in_tests])

    is_test_file =
      String.contains?(source_file.filename, "/test/") ||
        String.ends_with?(source_file.filename, "_test.exs")

    is_spec_file =
      String.contains?(source_file.filename, "/spec/") ||
        String.contains?(source_file.filename, "behaviour") ||
        String.contains?(source_file.filename, "protocol")

    allow_in_tests && (is_test_file || is_spec_file)
  end

  defp traverse(ast, issues) do
    {ast, issues}
  end

  # Check function definitions
  defp check_function_body({:def, meta, [{name, _, args}, [do: body]]} = ast, issues, issue_meta)
       when is_atom(name) and is_list(args) do
    if suspicious_function_body?(body) do
      issue =
        issue_for(
          issue_meta,
          meta[:line],
          name,
          "Function returns hardcoded data without querying database or performing calculations"
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp check_function_body({:defp, meta, [{name, _, args}, [do: body]]} = ast, issues, issue_meta)
       when is_atom(name) and is_list(args) do
    if suspicious_function_body?(body) do
      issue =
        issue_for(
          issue_meta,
          meta[:line],
          name,
          "Private function returns hardcoded data without real implementation"
        )

      {ast, [issue | issues]}
    else
      {ast, issues}
    end
  end

  defp check_function_body(ast, issues, _issue_meta) do
    {ast, issues}
  end

  # Check if function body is suspicious
  defp suspicious_function_body?({:ok, []}) do
    true
  end

  defp suspicious_function_body?({:ok, {:%, _, [{:__aliases__, _, _}, {:%{}, _, []}]}}) do
    true
  end

  defp suspicious_function_body?({:ok, {:%{}, _, []}}) do
    true
  end

  defp suspicious_function_body?([]) do
    true
  end

  defp suspicious_function_body?({:%{}, _, []}) do
    true
  end

  defp suspicious_function_body?({:error, :not_implemented}) do
    true
  end

  defp suspicious_function_body?(:not_implemented) do
    true
  end

  # Check for functions that only return hardcoded lists
  defp suspicious_function_body?({:sigil_w, _, _}) do
    true
  end

  defp suspicious_function_body?(list) when is_list(list) do
    # If it's a literal list, it's suspicious
    Enum.all?(list, &literal_value?/1)
  end

  defp suspicious_function_body?(_) do
    false
  end

  defp literal_value?(value) when is_atom(value), do: true
  defp literal_value?(value) when is_number(value), do: true
  defp literal_value?(value) when is_binary(value), do: true
  defp literal_value?({a, b}), do: literal_value?(a) && literal_value?(b)
  defp literal_value?(list) when is_list(list), do: Enum.all?(list, &literal_value?/1)
  defp literal_value?(_), do: false

  defp issue_for(issue_meta, line_no, function_name, message) do
    format_issue(issue_meta,
      message: "#{message} in `#{function_name}/#{get_arity(function_name)}`",
      line_no: line_no || 1,
      trigger: to_string(function_name)
    )
  end

  defp get_arity(_function_name) do
    # Simplified - in real implementation would track actual arity
    "*"
  end
end
