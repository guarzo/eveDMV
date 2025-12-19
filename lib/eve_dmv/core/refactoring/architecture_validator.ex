defmodule EveDmv.Core.Refactoring.ArchitectureValidator do
  @moduledoc """
  Validates the architecture of the EVE DMV codebase.

  Checks for:
  - Circular dependencies between modules
  - Boundary violations between contexts
  - Naming convention adherence
  - Module organization patterns
  - Clean architecture principles
  """

  require Logger

  defstruct [
    :modules,
    :dependencies,
    :violations,
    :circular_deps,
    :boundary_violations,
    :naming_violations
  ]

  @context_boundaries %{
    # Each context should only depend on these allowed modules
    "CharacterIntelligence" => ["Core", "Platform", "Api"],
    "CorporationIntelligence" => ["Core", "Platform", "Api"],
    "BattleAnalysis" => ["Core", "Platform", "Api"],
    "CombatIntelligence" => ["Core", "Platform", "Api", "BattleAnalysis"],
    "Surveillance" => ["Core", "Platform", "Api"],
    "MarketIntelligence" => ["Core", "Platform", "External"],
    "SystemAnalysis" => ["Core", "Platform", "Api"],
    "FleetOperations" => ["Core", "Platform", "Api"]
  }

  @forbidden_dependencies [
    # Controllers should not directly call contexts
    {~r/Web\.Controllers/, ~r/Contexts\.[^.]+\.[^.]+$/},
    # Contexts should not depend on web modules
    {~r/Contexts/, ~r/Web/},
    # Core should not depend on contexts
    {~r/Core/, ~r/Contexts/},
    # Platform should not depend on contexts
    {~r/Platform/, ~r/Contexts/}
  ]

  @naming_patterns %{
    context: ~r/^EveDmv\.Contexts\.[A-Z][a-zA-Z]+/,
    core: ~r/^EveDmv\.Core\.[A-Z][a-zA-Z]+/,
    platform: ~r/^EveDmv\.Platform\.[A-Z][a-zA-Z]+/,
    external: ~r/^EveDmv\.External\.[A-Z][a-zA-Z]+/,
    web: ~r/^EveDmvWeb\.[A-Z][a-zA-Z]+/
  }

  @doc """
  Run full architecture validation
  """
  def validate(opts \\ []) do
    Logger.info("Starting architecture validation...")

    state = %__MODULE__{
      modules: [],
      dependencies: %{},
      violations: [],
      circular_deps: [],
      boundary_violations: [],
      naming_violations: []
    }

    # Collect all modules and their dependencies
    initial_state = collect_modules_and_dependencies(state)

    # Run all checks in pipeline
    final_state =
      initial_state
      |> detect_circular_dependencies()
      |> check_boundary_violations()
      |> check_naming_conventions()
      |> check_forbidden_dependencies()

    # Generate report
    report = generate_validation_report(final_state, opts)

    Logger.info("Architecture validation complete")
    {:ok, report}
  end

  @doc """
  Check for circular dependencies between specific modules
  """
  def check_circular_dependency(module1, module2) do
    deps1 = get_module_dependencies(module1)
    deps2 = get_module_dependencies(module2)

    circular = module2 in deps1 && module1 in deps2

    if circular do
      {:circular, module1, module2}
    else
      :ok
    end
  end

  @doc """
  Validate module boundaries for a specific context
  """
  def validate_context_boundaries(context_name) do
    allowed = Map.get(@context_boundaries, context_name, [])
    context_module = "EveDmv.Contexts.#{context_name}"

    violations = find_boundary_violations(context_module, allowed)

    if violations == [] do
      :ok
    else
      {:violations, violations}
    end
  end

  @doc """
  Generate a dependency graph in DOT format
  """
  def generate_dependency_graph do
    # Collect dependencies directly instead of from validation report
    initial_state = %__MODULE__{
      modules: [],
      dependencies: %{},
      violations: [],
      circular_deps: [],
      boundary_violations: [],
      naming_violations: []
    }

    state = collect_modules_and_dependencies(initial_state)

    dot_content = build_dot_graph(state.dependencies)

    File.write!("/tmp/eve_dmv_dependencies.dot", dot_content)
    Logger.info("Dependency graph written to /tmp/eve_dmv_dependencies.dot")

    Logger.info(
      "Generate PNG with: dot -Tpng /tmp/eve_dmv_dependencies.dot -o /tmp/eve_dmv_dependencies.png"
    )

    {:ok, "/tmp/eve_dmv_dependencies.dot"}
  end

  ## Private Functions

  defp collect_modules_and_dependencies(state) do
    modules = find_all_modules()

    dependencies =
      Enum.reduce(modules, %{}, fn {module, path}, acc ->
        deps = extract_dependencies(path)
        Map.put(acc, module, deps)
      end)

    %{state | modules: modules, dependencies: dependencies}
  end

  defp find_all_modules do
    Path.wildcard("/workspace/lib/**/*.ex")
    |> Enum.map(fn path ->
      case extract_module_name(path) do
        nil -> nil
        name -> {name, path}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_module_name(path) do
    case File.read(path) do
      {:ok, content} ->
        case Regex.run(~r/defmodule\s+([A-Za-z0-9\.]+)/, content) do
          [_, module_name] -> module_name
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp extract_dependencies(path) do
    case File.read(path) do
      {:ok, content} ->
        # Extract alias dependencies
        aliases =
          Regex.scan(~r/alias\s+([A-Za-z0-9\.]+)/, content)
          |> Enum.map(fn [_, dep] -> dep end)

        # Extract import dependencies
        imports =
          Regex.scan(~r/import\s+([A-Za-z0-9\.]+)/, content)
          |> Enum.map(fn [_, dep] -> dep end)

        # Extract use dependencies
        uses =
          Regex.scan(~r/use\s+([A-Za-z0-9\.]+)/, content)
          |> Enum.map(fn [_, dep] -> dep end)

        # Extract function calls
        calls =
          Regex.scan(~r/([A-Z][A-Za-z0-9]*(?:\.[A-Z][A-Za-z0-9]*)+)\./, content)
          |> Enum.map(fn [_, dep] -> dep end)

        (aliases ++ imports ++ uses ++ calls)
        |> Enum.uniq()
        |> Enum.filter(&String.starts_with?(&1, "EveDmv"))

      _ ->
        []
    end
  end

  defp detect_circular_dependencies(state) do
    circular_deps = find_circular_deps(state.dependencies)
    %{state | circular_deps: circular_deps}
  end

  defp find_circular_deps(dependencies) do
    modules = Map.keys(dependencies)

    Enum.reduce(modules, [], fn module, acc ->
      cycles = find_cycles_from(module, dependencies, [module], [])
      acc ++ cycles
    end)
    |> Enum.uniq()
  end

  defp find_cycles_from(current, dependencies, path, found_cycles) do
    deps = Map.get(dependencies, current, [])

    Enum.reduce(deps, found_cycles, fn dep, acc ->
      cond do
        dep in path ->
          # Found a cycle
          cycle_start = Enum.find_index(path, &(&1 == dep))
          cycle = Enum.slice(path, cycle_start..-1) ++ [dep]
          [cycle | acc]

        length(path) < 10 ->
          # Continue searching (limit depth to avoid infinite recursion)
          find_cycles_from(dep, dependencies, path ++ [dep], acc)

        true ->
          acc
      end
    end)
  end

  defp check_boundary_violations(state) do
    violations =
      Enum.flat_map(state.modules, fn {module, _path} ->
        check_module_boundaries(module, state.dependencies)
      end)

    %{state | boundary_violations: violations}
  end

  defp check_module_boundaries(module, dependencies) do
    if String.starts_with?(module, "EveDmv.Contexts.") do
      context = extract_context_name(module)
      allowed = Map.get(@context_boundaries, context, [])
      deps = Map.get(dependencies, module, [])

      violations =
        Enum.filter(deps, fn dep ->
          !allowed_dependency?(dep, allowed)
        end)

      if violations == [] do
        []
      else
        [{module, violations}]
      end
    else
      []
    end
  end

  defp extract_context_name(module) do
    case String.split(module, ".") do
      ["EveDmv", "Contexts", context | _] -> context
      _ -> nil
    end
  end

  defp allowed_dependency?(dep, allowed_patterns) do
    Enum.any?(allowed_patterns, fn pattern ->
      String.contains?(dep, pattern)
    end) || !String.starts_with?(dep, "EveDmv")
  end

  defp check_naming_conventions(state) do
    violations =
      Enum.flat_map(state.modules, fn {module, path} ->
        if violation = check_naming_violation(module, path) do
          [{module, path, violation}]
        else
          []
        end
      end)

    %{state | naming_violations: violations}
  end

  defp check_naming_violation(module, path) do
    cond do
      String.contains?(path, "/contexts/") && !Regex.match?(@naming_patterns.context, module) ->
        "Module in contexts/ should match pattern: #{inspect(@naming_patterns.context)}"

      String.contains?(path, "/core/") && !Regex.match?(@naming_patterns.core, module) ->
        "Module in core/ should match pattern: #{inspect(@naming_patterns.core)}"

      String.contains?(path, "/platform/") && !Regex.match?(@naming_patterns.platform, module) ->
        "Module in platform/ should match pattern: #{inspect(@naming_patterns.platform)}"

      String.contains?(path, "/external/") && !Regex.match?(@naming_patterns.external, module) ->
        "Module in external/ should match pattern: #{inspect(@naming_patterns.external)}"

      String.contains?(path, "eve_dmv_web") && !Regex.match?(@naming_patterns.web, module) ->
        "Web module should match pattern: #{inspect(@naming_patterns.web)}"

      true ->
        nil
    end
  end

  defp check_forbidden_dependencies(state) do
    violations =
      Enum.flat_map(state.modules, fn {module, _path} ->
        deps = Map.get(state.dependencies, module, [])

        find_module_violations(module, deps)
      end)

    %{state | violations: state.violations ++ violations}
  end

  defp find_module_violations(module, deps) do
    Enum.flat_map(@forbidden_dependencies, fn {from_pattern, to_pattern} ->
      if Regex.match?(from_pattern, module) do
        forbidden = Enum.filter(deps, &Regex.match?(to_pattern, &1))

        if forbidden == [] do
          []
        else
          [{module, from_pattern, forbidden}]
        end
      else
        []
      end
    end)
  end

  defp find_boundary_violations(context_module, allowed_patterns) do
    dependencies = get_module_dependencies(context_module)

    Enum.filter(dependencies, fn dep ->
      !allowed_dependency?(dep, allowed_patterns)
    end)
  end

  defp get_module_dependencies(module_name) do
    # Find the file for this module
    path = find_module_file(module_name)

    if path do
      extract_dependencies(path)
    else
      []
    end
  end

  defp find_module_file(module_name) do
    # Convert module name to likely file path
    file_path =
      module_name
      |> String.replace("EveDmv.", "")
      |> String.replace("EveDmvWeb.", "")
      |> String.split(".")
      |> Enum.map(&Macro.underscore/1)
      |> Path.join()

    candidates = [
      "/workspace/lib/eve_dmv/#{file_path}.ex",
      "/workspace/lib/eve_dmv_web/#{file_path}.ex",
      "/workspace/lib/#{file_path}.ex"
    ]

    Enum.find(candidates, &File.exists?/1)
  end

  defp build_dot_graph(dependencies) do
    nodes =
      Map.keys(dependencies)
      |> Enum.map(&simplify_module_name/1)
      |> Enum.uniq()

    edges =
      Enum.flat_map(dependencies, fn {from, deps} ->
        Enum.map(deps, fn to ->
          {simplify_module_name(from), simplify_module_name(to)}
        end)
      end)
      |> Enum.uniq()

    """
    digraph EVE_DMV_Dependencies {
      rankdir=LR;
      node [shape=box, style=filled, fillcolor=lightblue];
      
      // Nodes
      #{Enum.map_join(nodes, "\n", fn n -> "  \"#{n}\";" end)}
      
      // Edges
      #{Enum.map_join(edges, "\n", fn {f, t} -> "  \"#{f}\" -> \"#{t}\";" end)}
    }
    """
  end

  defp simplify_module_name(name) do
    name
    |> String.replace("EveDmv.", "")
    |> String.replace("EveDmvWeb.", "Web.")
  end

  defp generate_validation_report(state, opts) do
    report = %{
      timestamp: DateTime.utc_now(),
      summary: %{
        total_modules: length(state.modules),
        circular_dependencies: length(state.circular_deps),
        boundary_violations: length(state.boundary_violations),
        naming_violations: length(state.naming_violations),
        forbidden_dependencies: length(state.violations)
      },
      details: %{
        circular_dependencies: format_circular_deps(state.circular_deps),
        boundary_violations: format_boundary_violations(state.boundary_violations),
        naming_violations: format_naming_violations(state.naming_violations),
        forbidden_dependencies: format_forbidden_deps(state.violations)
      },
      health_score: calculate_health_score(state),
      recommendations: generate_recommendations(state)
    }

    if Keyword.get(opts, :report, true) do
      print_report(report)
    end

    report
  end

  defp format_circular_deps(deps) do
    Enum.map(deps, fn cycle ->
      %{
        modules: cycle,
        description: "Circular dependency: #{Enum.join(cycle, " -> ")}"
      }
    end)
  end

  defp format_boundary_violations(violations) do
    Enum.map(violations, fn {module, deps} ->
      %{
        module: module,
        violations: deps,
        description: "Module #{module} has forbidden dependencies: #{Enum.join(deps, ", ")}"
      }
    end)
  end

  defp format_naming_violations(violations) do
    Enum.map(violations, fn {module, path, reason} ->
      %{
        module: module,
        path: path,
        reason: reason
      }
    end)
  end

  defp format_forbidden_deps(violations) do
    Enum.map(violations, fn {module, pattern, deps} ->
      %{
        module: module,
        pattern: inspect(pattern),
        forbidden_dependencies: deps
      }
    end)
  end

  defp calculate_health_score(state) do
    base_score = 100

    deductions = [
      length(state.circular_deps) * 10,
      length(state.boundary_violations) * 5,
      length(state.naming_violations) * 2,
      length(state.violations) * 3
    ]

    score = base_score - Enum.sum(deductions)
    max(0, score)
  end

  defp generate_recommendations(state) do
    []
    |> maybe_add_recommendation(
      Enum.any?(state.circular_deps),
      "Break circular dependencies by introducing abstractions or events"
    )
    |> maybe_add_recommendation(
      Enum.any?(state.boundary_violations),
      "Refactor to respect context boundaries"
    )
    |> maybe_add_recommendation(
      Enum.any?(state.naming_violations),
      "Fix module naming to match directory structure"
    )
    |> maybe_add_recommendation(
      Enum.any?(state.violations),
      "Remove forbidden dependencies between layers"
    )
  end

  defp maybe_add_recommendation(list, true, recommendation), do: list ++ [recommendation]
  defp maybe_add_recommendation(list, false, _recommendation), do: list

  defp print_report(report) do
    Logger.info("""

    ========================================
    Architecture Validation Report
    ========================================

    Summary:
    - Total Modules: #{report.summary.total_modules}
    - Circular Dependencies: #{report.summary.circular_dependencies}
    - Boundary Violations: #{report.summary.boundary_violations}
    - Naming Violations: #{report.summary.naming_violations}
    - Forbidden Dependencies: #{report.summary.forbidden_dependencies}

    Health Score: #{report.health_score}/100

    Recommendations:
    #{Enum.map_join(report.recommendations, "\n", fn r -> "- #{r}" end)}

    ========================================
    """)

    if report.summary.circular_dependencies > 0 do
      Logger.warning("Found #{report.summary.circular_dependencies} circular dependencies!")
    end

    if report.summary.boundary_violations > 0 do
      Logger.warning("Found #{report.summary.boundary_violations} boundary violations!")
    end
  end
end
