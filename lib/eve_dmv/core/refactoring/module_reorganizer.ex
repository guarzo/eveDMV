defmodule EveDmv.Core.Refactoring.ModuleReorganizer do
  @moduledoc """
  Tools for reorganizing and refactoring module structure.

  Addresses:
  - Misplaced modules
  - Deep nesting issues
  - Naming convention violations
  - Module organization patterns
  """

  require Logger

  # @max_nesting_depth 4
  # @allowed_top_level_dirs ["contexts", "core", "platform", "external", "utilities", "shared"]

  # @naming_conventions %{
  #   contexts: ~r/^EveDmv\.Contexts\.[A-Z][a-zA-Z]+/,
  #   core: ~r/^EveDmv\.Core\.[A-Z][a-zA-Z]+/,
  #   platform: ~r/^EveDmv\.Platform\.[A-Z][a-zA-Z]+/,
  #   external: ~r/^EveDmv\.External\.[A-Z][a-zA-Z]+/,
  #   utilities: ~r/^EveDmv\.Utilities\.[A-Z][a-zA-Z]+/,
  #   web: ~r/^EveDmvWeb\.[A-Z][a-zA-Z]+/
  # }

  @doc """
  Analyze module organization and report issues
  """
  def analyze_organization do
    # Check for misplaced modules
    misplaced_issues = check_misplaced_modules()

    # Check for deep nesting
    nesting_issues = check_deep_nesting()

    # Check naming conventions
    naming_issues = check_naming_conventions()

    # Check for duplicate functionality
    duplicate_issues = check_duplicate_modules()

    # Combine all issues
    all_issues = misplaced_issues ++ nesting_issues ++ naming_issues ++ duplicate_issues

    # Generate report
    generate_report(all_issues)
  end

  @doc """
  Fix module organization issues
  """
  def fix_organization(opts \\ []) do
    dry_run = Keyword.get(opts, :dry_run, true)

    Logger.info("Starting module reorganization (dry_run: #{dry_run})")

    fixes = []

    # Flatten deeply nested modules
    fixes_with_flatten = fixes ++ flatten_nested_modules(dry_run)

    # Move misplaced modules to correct locations
    fixes_with_relocate = fixes_with_flatten ++ relocate_misplaced_modules(dry_run)

    # Fix naming convention violations
    fixes_with_naming = fixes_with_relocate ++ fix_naming_violations(dry_run)

    # Consolidate duplicate modules
    final_fixes = fixes_with_naming ++ consolidate_duplicates(dry_run)

    Logger.info("Module reorganization complete. Applied #{length(final_fixes)} fixes.")
    {:ok, final_fixes}
  end

  ## Analysis Functions

  defp check_misplaced_modules do
    # Check for cache modules outside of platform/cache
    cache_modules =
      find_files_matching("cache")
      |> Enum.filter(fn path ->
        !String.contains?(path, "/platform/cache/") &&
          !String.contains?(path, "/infrastructure/") &&
          !String.contains?(path, "/core/utils/cache.ex")
      end)

    misplaced_cache =
      if Enum.empty?(cache_modules), do: [], else: [{:misplaced_cache, cache_modules}]

    # Check for error modules outside of core/errors
    error_modules =
      find_files_matching("error")
      |> Enum.filter(fn path ->
        !String.contains?(path, "/core/errors/") &&
          !String.contains?(path, "/utilities/error_formatter.ex")
      end)

    misplaced_error =
      if Enum.empty?(error_modules), do: [], else: [{:misplaced_error, error_modules}]

    # Check for utils outside of core/utils
    utils_modules =
      find_files_matching("utils")
      |> Enum.filter(fn path ->
        !String.contains?(path, "/core/utils/")
      end)

    misplaced_utils =
      if Enum.empty?(utils_modules), do: [], else: [{:misplaced_utils, utils_modules}]

    misplaced_cache ++ misplaced_error ++ misplaced_utils
  end

  defp check_deep_nesting do
    deeply_nested = find_deeply_nested_directories()

    if Enum.empty?(deeply_nested) do
      []
    else
      [{:deep_nesting, deeply_nested}]
    end
  end

  defp check_naming_conventions do
    all_modules = find_all_modules()

    Enum.reduce(all_modules, [], fn {path, module_name}, acc ->
      if violation = check_naming_violation(path, module_name) do
        [{:naming_violation, path, violation} | acc]
      else
        acc
      end
    end)
  end

  defp check_duplicate_modules do
    # Check for multiple cache implementations
    cache_modules =
      [
        "/workspace/lib/eve_dmv/platform/cache/cache.ex",
        "/workspace/lib/eve_dmv/core/utils/cache.ex",
        "/workspace/lib/eve_dmv/config/cache.ex"
      ]
      |> Enum.filter(&File.exists?/1)

    cache_duplication_problems =
      if length(cache_modules) > 1 do
        [{:duplicate_functionality, :cache, cache_modules}]
      else
        []
      end

    # Check for multiple error handling modules
    error_modules =
      [
        "/workspace/lib/eve_dmv/core/errors/error.ex",
        "/workspace/lib/eve_dmv/core/utils/error_handling.ex",
        "/workspace/lib/eve_dmv/utilities/error_formatter.ex"
      ]
      |> Enum.filter(&File.exists?/1)

    if length(error_modules) > 1 do
      [{:duplicate_functionality, :error_handling, error_modules} | cache_duplication_problems]
    else
      cache_duplication_problems
    end
  end

  ## Fix Functions

  defp flatten_nested_modules(dry_run) do
    # Find modules in deeply nested analyzer directories
    nested_analyzers = find_deeply_nested_analyzers()

    Enum.map(nested_analyzers, fn path ->
      new_path = calculate_flattened_path(path)

      if dry_run do
        Logger.info("[DRY RUN] Would move #{path} to #{new_path}")
        {:move, path, new_path}
      else
        move_module(path, new_path)
        {:moved, path, new_path}
      end
    end)
  end

  defp relocate_misplaced_modules(dry_run) do
    # Move cache modules to platform/cache
    cache_moves =
      find_misplaced_cache_modules()
      |> Enum.map(fn path ->
        new_path = calculate_proper_cache_path(path)

        if dry_run do
          Logger.info("[DRY RUN] Would move cache module #{path} to #{new_path}")
          {:move_cache, path, new_path}
        else
          move_module(path, new_path)
          {:moved_cache, path, new_path}
        end
      end)

    # Move error modules to core/errors
    error_moves =
      find_misplaced_error_modules()
      |> Enum.map(fn path ->
        new_path = calculate_proper_error_path(path)

        if dry_run do
          Logger.info("[DRY RUN] Would move error module #{path} to #{new_path}")
          {:move_error, path, new_path}
        else
          move_module(path, new_path)
          {:moved_error, path, new_path}
        end
      end)

    cache_moves ++ error_moves
  end

  defp fix_naming_violations(dry_run) do
    all_modules = find_all_modules()

    Enum.reduce(all_modules, [], fn {path, module_name}, acc ->
      handle_module_naming(path, module_name, acc, dry_run)
    end)
  end

  defp consolidate_duplicates(dry_run) do
    # Consolidate cache modules
    cache_consolidation = consolidate_cache_modules(dry_run)

    # Consolidate error handling modules
    error_consolidation = consolidate_error_modules(dry_run)

    cache_consolidation ++ error_consolidation
  end

  ## Helper Functions

  defp handle_module_naming(path, module_name, acc, dry_run) do
    case calculate_correct_module_name(path) do
      nil ->
        acc

      ^module_name ->
        acc

      correct_name ->
        if dry_run do
          Logger.info("[DRY RUN] Would rename module #{module_name} to #{correct_name}")
          [{:rename, path, module_name, correct_name} | acc]
        else
          rename_module_in_file(path, module_name, correct_name)
          [{:renamed, path, module_name, correct_name} | acc]
        end
    end
  end

  defp find_files_matching(pattern) do
    Path.wildcard("/workspace/lib/eve_dmv/**/*#{pattern}*.ex")
  end

  defp find_deeply_nested_directories do
    Path.wildcard("/workspace/lib/eve_dmv/**/**/**/**/**/*.ex")
    |> Enum.map(&Path.dirname/1)
    |> Enum.uniq()
  end

  defp find_deeply_nested_analyzers do
    Path.wildcard("/workspace/lib/eve_dmv/contexts/*/domain/analyzers/*/**.ex")
  end

  defp find_all_modules do
    Path.wildcard("/workspace/lib/eve_dmv/**/*.ex")
    |> Enum.map(fn path ->
      module_name = extract_module_name(path)
      {path, module_name}
    end)
    |> Enum.reject(fn {_path, name} -> is_nil(name) end)
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

  defp check_naming_violation(path, module_name) do
    cond do
      String.contains?(path, "/contexts/") &&
          !String.starts_with?(module_name, "EveDmv.Contexts.") ->
        "Should start with EveDmv.Contexts"

      String.contains?(path, "/core/") && !String.starts_with?(module_name, "EveDmv.Core.") ->
        "Should start with EveDmv.Core"

      String.contains?(path, "/platform/") &&
          !String.starts_with?(module_name, "EveDmv.Platform.") ->
        "Should start with EveDmv.Platform"

      String.contains?(path, "/external/") &&
          !String.starts_with?(module_name, "EveDmv.External.") ->
        "Should start with EveDmv.External"

      true ->
        nil
    end
  end

  defp calculate_flattened_path(deep_path) do
    # Convert deeply nested analyzer to flatter structure
    # e.g., contexts/fleet_operations/domain/analyzers/fleet_asset_manager/readiness_analyzer.ex
    # becomes contexts/fleet_operations/analyzers/fleet_asset_readiness_analyzer.ex

    parts = Path.split(deep_path)
    filename = Path.basename(deep_path)

    if String.contains?(deep_path, "/domain/analyzers/") do
      context = Enum.at(parts, Enum.find_index(parts, &(&1 == "contexts")) + 1)
      new_filename = String.replace(filename, "_analyzer.ex", "_analyzer.ex")
      "/workspace/lib/eve_dmv/contexts/#{context}/analyzers/#{new_filename}"
    else
      deep_path
    end
  end

  defp find_misplaced_cache_modules do
    Path.wildcard("/workspace/lib/eve_dmv/**/*cache*.ex")
    |> Enum.filter(fn path ->
      !String.contains?(path, "/platform/cache/") &&
        !String.contains?(path, "/infrastructure/")
    end)
  end

  defp find_misplaced_error_modules do
    Path.wildcard("/workspace/lib/eve_dmv/**/*error*.ex")
    |> Enum.filter(fn path ->
      # Allow things like "error_handler"
      !String.contains?(path, "/core/errors/") &&
        !String.contains?(path, "_error_")
    end)
  end

  defp calculate_proper_cache_path(old_path) do
    filename = Path.basename(old_path)
    "/workspace/lib/eve_dmv/platform/cache/#{filename}"
  end

  defp calculate_proper_error_path(old_path) do
    filename = Path.basename(old_path)
    "/workspace/lib/eve_dmv/core/errors/#{filename}"
  end

  defp calculate_correct_module_name(path) do
    relative_path =
      String.replace(path, "/workspace/lib/", "")
      |> String.replace(".ex", "")
      |> String.replace("/", ".")

    # Convert to proper module name
    Enum.map_join(String.split(relative_path, "."), ".", &Macro.camelize/1)
  end

  defp move_module(from_path, to_path) do
    # Ensure target directory exists
    File.mkdir_p!(Path.dirname(to_path))

    # Move the file
    File.rename!(from_path, to_path)

    # Update module name in the file
    update_module_name_in_file(to_path)

    Logger.info("Moved #{from_path} to #{to_path}")
  end

  defp rename_module_in_file(path, old_name, new_name) do
    {:ok, content} = File.read(path)

    new_content = String.replace(content, "defmodule #{old_name}", "defmodule #{new_name}")

    File.write!(path, new_content)
    Logger.info("Renamed module #{old_name} to #{new_name} in #{path}")
  end

  defp update_module_name_in_file(path) do
    correct_name = calculate_correct_module_name(path)

    if correct_name do
      {:ok, content} = File.read(path)

      case Regex.run(~r/defmodule\s+([A-Za-z0-9\.]+)/, content) do
        [full_match, current_name] ->
          if current_name != correct_name do
            new_content = String.replace(content, full_match, "defmodule #{correct_name}")
            File.write!(path, new_content)
            Logger.info("Updated module name to #{correct_name} in #{path}")
          end

        _ ->
          :ok
      end
    end
  end

  defp consolidate_cache_modules(_dry_run) do
    # Keep platform/cache as the canonical location
    # Remove or merge others
    []
  end

  defp consolidate_error_modules(_dry_run) do
    # Keep core/errors as the canonical location
    # Merge error handling utilities
    []
  end

  defp generate_report(issues) do
    report = %{
      timestamp: DateTime.utc_now(),
      total_issues: length(issues),
      issues_by_type: group_issues_by_type(issues),
      recommendations: generate_recommendations(issues),
      summary: generate_summary(issues)
    }

    Logger.info("Module Organization Analysis Report:")
    Logger.info("=====================================")
    Logger.info("Total issues found: #{report.total_issues}")

    Enum.each(report.issues_by_type, fn {type, items} ->
      Logger.info("#{type}: #{length(items)} issues")
    end)

    report
  end

  defp group_issues_by_type(issues) do
    Enum.group_by(issues, fn
      {:misplaced_cache, _} -> :misplaced_cache
      {:misplaced_error, _} -> :misplaced_error
      {:misplaced_utils, _} -> :misplaced_utils
      {:deep_nesting, _} -> :deep_nesting
      {:naming_violation, _, _} -> :naming_violation
      {:duplicate_functionality, _, _} -> :duplicate_functionality
      _ -> :other
    end)
  end

  defp generate_recommendations(issues) do
    base_recommendations = []

    nesting_recommendations =
      if Enum.any?(issues, fn {type, _} -> type == :deep_nesting end) do
        ["Flatten deeply nested module structures" | base_recommendations]
      else
        base_recommendations
      end

    duplicate_recommendations =
      if Enum.any?(issues, fn {type, _} -> type == :duplicate_functionality end) do
        ["Consolidate duplicate functionality into single modules" | nesting_recommendations]
      else
        nesting_recommendations
      end

    recommendations =
      if Enum.any?(issues, fn {type, _, _} -> type == :naming_violation end) do
        ["Fix module naming to match directory structure" | duplicate_recommendations]
      else
        duplicate_recommendations
      end

    recommendations
  end

  defp generate_summary(issues) do
    %{
      has_critical_issues: length(issues) > 10,
      requires_refactoring: length(issues) > 5,
      health_score: calculate_health_score(issues)
    }
  end

  defp calculate_health_score(issues) do
    base_score = 100
    deduction = length(issues) * 5
    max(0, base_score - deduction)
  end
end
