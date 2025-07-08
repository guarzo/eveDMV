defmodule EveDmv.Quality.MetricsCollector.DocumentationMetrics do
  @moduledoc """
  Documentation metrics collection and analysis.

  Handles README quality, code documentation coverage,
  API documentation, and architecture documentation checks.
  """

  @doc """
  Collects comprehensive documentation metrics.
  """
  def collect_documentation_metrics do
    %{
      readme_quality: analyze_readme_quality(),
      code_documentation: analyze_code_documentation(),
      api_documentation: analyze_api_documentation(),
      architecture_documentation: check_architecture_docs()
    }
  end

  @doc """
  Calculates documentation score based on metrics.
  """
  def calculate_documentation_score(doc_metrics) do
    doc_metrics.code_documentation.documentation_percentage || 50
  end

  @doc """
  Generates documentation recommendations.
  """
  def generate_documentation_recommendations(doc_metrics) do
    recommendations = []

    # Check README quality
    readme = doc_metrics.readme_quality

    recommendations =
      cond do
        not readme.exists ->
          ["Create a README.md file" | recommendations]

        not readme.has_setup_instructions ->
          ["Add setup instructions to README" | recommendations]

        not readme.has_usage_examples ->
          ["Add usage examples to README" | recommendations]

        readme.sections < 5 ->
          ["Expand README with more sections (current: #{readme.sections})" | recommendations]

        true ->
          recommendations
      end

    # Check code documentation
    code_doc_percentage = doc_metrics.code_documentation.documentation_percentage

    recommendations =
      if code_doc_percentage < 80 do
        [
          "Increase code documentation coverage (current: #{round(code_doc_percentage)}%)"
          | recommendations
        ]
      else
        recommendations
      end

    # Check architecture docs
    arch_docs = doc_metrics.architecture_documentation

    recommendations =
      if arch_docs.architecture_docs_count == 0 do
        ["Add architecture documentation" | recommendations]
      else
        recommendations
      end

    recommendations
  end

  # README analysis

  defp analyze_readme_quality do
    case File.read("README.md") do
      {:ok, content} ->
        %{
          exists: true,
          length: String.length(content),
          sections: count_markdown_sections(content),
          has_setup_instructions: check_setup_instructions(content),
          has_usage_examples: check_usage_examples(content),
          has_badges: check_badges(content),
          has_table_of_contents: check_table_of_contents(content),
          completeness_score: calculate_readme_completeness(content)
        }

      _ ->
        %{
          exists: false,
          length: 0,
          sections: 0,
          has_setup_instructions: false,
          has_usage_examples: false,
          has_badges: false,
          has_table_of_contents: false,
          completeness_score: 0
        }
    end
  end

  defp count_markdown_sections(content) do
    content
    |> String.split("\n")
    |> Enum.count(&String.starts_with?(&1, "#"))
  end

  defp check_setup_instructions(content) do
    String.contains?(String.downcase(content), "setup") or
      String.contains?(String.downcase(content), "installation") or
      String.contains?(String.downcase(content), "getting started")
  end

  defp check_usage_examples(content) do
    String.contains?(String.downcase(content), "usage") or
      String.contains?(String.downcase(content), "example") or
      String.contains?(content, "```")
  end

  defp check_badges(content) do
    String.contains?(content, "![") or String.contains?(content, "[![")
  end

  defp check_table_of_contents(content) do
    String.contains?(String.downcase(content), "table of contents") or
      String.contains?(String.downcase(content), "## contents")
  end

  defp calculate_readme_completeness(content) do
    scores = [
      if(check_setup_instructions(content), do: 20, else: 0),
      if(check_usage_examples(content), do: 20, else: 0),
      if(check_badges(content), do: 10, else: 0),
      if(check_table_of_contents(content), do: 10, else: 0),
      if(count_markdown_sections(content) >= 5, do: 20, else: 10),
      if(String.length(content) > 1000, do: 20, else: 10)
    ]

    Enum.sum(scores)
  end

  # Code documentation analysis

  defp analyze_code_documentation do
    elixir_files = Path.wildcard("lib/**/*.ex")

    doc_analysis =
      Enum.map(elixir_files, &analyze_file_documentation/1)
      |> Enum.reduce(%{total: 0, documented: 0, with_moduledoc: 0, with_doc: 0}, fn file_data,
                                                                                    acc ->
        %{
          total: acc.total + 1,
          documented: acc.documented + if(file_data.has_docs, do: 1, else: 0),
          with_moduledoc: acc.with_moduledoc + if(file_data.has_moduledoc, do: 1, else: 0),
          with_doc: acc.with_doc + if(file_data.has_doc, do: 1, else: 0)
        }
      end)

    %{
      total_files: doc_analysis.total,
      documented_files: doc_analysis.documented,
      files_with_moduledoc: doc_analysis.with_moduledoc,
      files_with_doc: doc_analysis.with_doc,
      documentation_percentage:
        if(doc_analysis.total > 0,
          do: doc_analysis.documented / doc_analysis.total * 100,
          else: 0
        ),
      undocumented_files: find_undocumented_files(elixir_files)
    }
  end

  defp analyze_file_documentation(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        %{
          file: file_path,
          has_moduledoc: String.contains?(content, "@moduledoc"),
          has_doc: String.contains?(content, "@doc"),
          has_docs: String.contains?(content, "@moduledoc") or String.contains?(content, "@doc")
        }

      _ ->
        %{
          file: file_path,
          has_moduledoc: false,
          has_doc: false,
          has_docs: false
        }
    end
  end

  defp find_undocumented_files(files) do
    files
    |> Enum.filter(fn file ->
      case File.read(file) do
        {:ok, content} ->
          not (String.contains?(content, "@moduledoc") or String.contains?(content, "@doc"))

        _ ->
          true
      end
    end)
    # Limit to first 10 for performance
    |> Enum.take(10)
  end

  # API documentation

  defp analyze_api_documentation do
    %{
      has_api_docs: File.exists?("docs/api") or File.exists?("priv/static/docs"),
      openapi_spec: File.exists?("priv/static/openapi.json"),
      postman_collection: File.exists?("docs/postman_collection.json"),
      has_generated_docs: File.exists?("doc") and File.dir?("doc")
    }
  end

  # Architecture documentation

  defp check_architecture_docs do
    architecture_files = [
      "ARCHITECTURE.md",
      "docs/architecture.md",
      "docs/ARCHITECTURE.md",
      "TEAM_DELTA_PLAN.md",
      "docs/design.md"
    ]

    existing_docs =
      Enum.filter(architecture_files, &File.exists?/1)
    %{
      architecture_docs_count: length(existing_docs),
      has_team_plan: File.exists?("TEAM_DELTA_PLAN.md"),
      has_claude_md: File.exists?("CLAUDE.md"),
      has_project_status: File.exists?("PROJECT_STATUS.md"),
      existing_files: existing_docs,
      documentation_completeness: calculate_arch_doc_completeness(existing_docs)
    }
  end

  defp calculate_arch_doc_completeness(existing_docs) do
    expected_docs = [
      "ARCHITECTURE.md",
      "TEAM_DELTA_PLAN.md",
      "CLAUDE.md",
      "PROJECT_STATUS.md"
    ]

    existing_count = Enum.count(existing_docs, &(&1 in expected_docs))
    round(existing_count / length(expected_docs) * 100)
  end
end
