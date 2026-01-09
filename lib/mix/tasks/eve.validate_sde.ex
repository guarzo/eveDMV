defmodule Mix.Tasks.Eve.ValidateSde do
  @moduledoc """
  Validates the SDE data import and generates a validation report.

  This is Phase 7 of the SDE migration - Testing & Validation.

  ## Usage

      # Run full validation
      mix eve.validate_sde

      # Compare with JSONL files (if available)
      mix eve.validate_sde --compare /path/to/extracted/sde

      # Run performance comparison
      mix eve.validate_sde --performance /path/to/extracted/sde

      # Verbose output
      mix eve.validate_sde --verbose

  ## What it validates

  1. **Record counts**: Checks total items and solar systems in database
  2. **Category breakdown**: Shows items by category and killmail-relevant counts
  3. **Essential items**: Verifies common ships, modules, and drones exist
  4. **Version info**: Shows current SDE version in database

  ## Example output

      SDE Validation Report
      =====================
      Timestamp: 2025-12-18T10:00:00Z

      Database Counts:
        Total Item Types: 8,234
        Published Items: 7,891
        Solar Systems: 8,436

      Category Breakdown:
        Ships: 856
        Modules: 4,231
        Charges: 1,123
        ...

      Essential Items Coverage:
        Ships: 12/12 (100%)
        Modules: 4/4 (100%)
        Drones: 3/3 (100%)

      Version Info:
        SDE Version: build-3142455
        Build Number: 3142455
        Last Updated: 2025-12-15T11:14:02Z

      VALIDATION PASSED
  """

  @shortdoc "Validates SDE data import"

  use Mix.Task

  # Dialyzer can't infer that compare_with_jsonl_files can return {:ok, _}
  # because file existence is a runtime check. This is a dev tool, so suppress.
  @dialyzer {:nowarn_function, run_comparison: 2}

  alias EveDmv.Eve.StaticDataLoader.SdeValidator

  @switches [
    compare: :string,
    performance: :string,
    verbose: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    # Start the application
    Mix.Task.run("app.start")

    shell = Mix.shell()

    shell.info("\n" <> IO.ANSI.bright() <> "SDE Validation Report" <> IO.ANSI.reset())
    shell.info(String.duplicate("=", 50))
    shell.info("")

    # Run main validation
    case SdeValidator.generate_validation_report() do
      {:ok, report} ->
        print_report(report, opts, shell)

        # Run comparison if requested
        if compare_path = opts[:compare] do
          run_comparison(compare_path, shell)
        end

        # Run performance test if requested
        if perf_path = opts[:performance] do
          run_performance(perf_path, shell)
        end

        # Print final status
        if report.summary.validation_passed do
          shell.info("")
          shell.info(IO.ANSI.green() <> "VALIDATION PASSED" <> IO.ANSI.reset())
        else
          shell.info("")
          shell.error("VALIDATION FAILED")
          System.halt(1)
        end

      {:error, reason} ->
        shell.error("Error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp print_report(report, opts, shell) do
    # Timestamp
    shell.info("Timestamp: #{report.timestamp}")
    shell.info("")

    # Database Counts
    shell.info(IO.ANSI.bright() <> "Database Counts:" <> IO.ANSI.reset())
    shell.info("  Total Item Types: #{format_number(report.database_counts.total_item_types)}")
    shell.info("  Published Items: #{format_number(report.database_counts.published_item_types)}")
    shell.info("  Solar Systems: #{format_number(report.database_counts.solar_systems)}")
    shell.info("")

    # Category Breakdown
    shell.info(IO.ANSI.bright() <> "Category Breakdown:" <> IO.ANSI.reset())

    shell.info(
      "  Killmail-Relevant Items: #{format_number(report.category_breakdown.killmail_relevant_count)}"
    )

    shell.info("  Total Categories: #{report.category_breakdown.total_categories}")

    if opts[:verbose] do
      shell.info("  By Category:")

      report.category_breakdown.by_category
      |> Enum.sort_by(fn {_id, data} -> -data.count end)
      |> Enum.each(fn {_id, data} ->
        relevance = if data.is_killmail_relevant, do: " [killmail]", else: ""
        shell.info("    #{data.category_name}: #{format_number(data.count)}#{relevance}")
      end)
    end

    shell.info("")

    # Essential Items
    shell.info(IO.ANSI.bright() <> "Essential Items Coverage:" <> IO.ANSI.reset())
    coverage = report.essential_item_coverage
    print_coverage("Ships", coverage.ships, shell)
    print_coverage("Modules", coverage.modules, shell)
    print_coverage("Drones", coverage.drones, shell)

    if not coverage.all_present do
      shell.info("")
      shell.info(IO.ANSI.yellow() <> "  Missing items detected!" <> IO.ANSI.reset())

      if coverage.ships.missing != [],
        do: shell.info("    Missing ships: #{inspect(coverage.ships.missing)}")

      if coverage.modules.missing != [],
        do: shell.info("    Missing modules: #{inspect(coverage.modules.missing)}")

      if coverage.drones.missing != [],
        do: shell.info("    Missing drones: #{inspect(coverage.drones.missing)}")
    end

    shell.info("")

    # Version Info
    shell.info(IO.ANSI.bright() <> "Version Info:" <> IO.ANSI.reset())
    version = report.version_info
    shell.info("  SDE Version: #{version.sde_version || "not set"}")

    if version.sde_build_number do
      shell.info("  Build Number: #{version.sde_build_number}")
    end

    shell.info("  Last Updated: #{version.last_updated || "never"}")
  end

  defp print_coverage(name, data, shell) do
    pct = if data.expected > 0, do: round(data.found / data.expected * 100), else: 0

    status =
      if data.missing == [],
        do: IO.ANSI.green() <> "OK" <> IO.ANSI.reset(),
        else: IO.ANSI.red() <> "MISSING" <> IO.ANSI.reset()

    shell.info("  #{name}: #{data.found}/#{data.expected} (#{pct}%) #{status}")
  end

  defp run_comparison(path, shell) do
    shell.info("")
    shell.info(IO.ANSI.bright() <> "JSONL Comparison:" <> IO.ANSI.reset())

    case SdeValidator.compare_with_jsonl_files(path) do
      {:ok, comparison} ->
        shell.info("  JSONL Total Types: #{format_number(comparison.jsonl_total_types)}")
        shell.info("  JSONL Filtered Types: #{format_number(comparison.jsonl_filtered_types)}")
        shell.info("  JSONL Solar Systems: #{format_number(comparison.jsonl_systems)}")
        shell.info("  Reduction: #{comparison.types_reduction_pct}%")
        shell.info("")
        shell.info("  DB Item Types: #{format_number(comparison.db_item_types)}")
        shell.info("  DB Solar Systems: #{format_number(comparison.db_solar_systems)}")
        shell.info("")
        types_match = if comparison.types_match, do: "YES", else: "NO"
        systems_match = if comparison.systems_match, do: "YES", else: "NO"
        shell.info("  Types Match: #{types_match}")
        shell.info("  Systems Match: #{systems_match}")

      {:error, :jsonl_files_not_found} ->
        shell.info(IO.ANSI.yellow() <> "  JSONL files not found at #{path}" <> IO.ANSI.reset())

      {:error, reason} ->
        shell.error("  Error: #{inspect(reason)}")
    end
  end

  defp run_performance(path, shell) do
    shell.info("")
    shell.info(IO.ANSI.bright() <> "Performance Comparison:" <> IO.ANSI.reset())

    case SdeValidator.performance_comparison(path) do
      {:ok, result} ->
        shell.info(
          "  Unfiltered: #{format_number(result.unfiltered.count)} items in #{Float.round(result.unfiltered.time_ms, 1)}ms"
        )

        shell.info(
          "  Filtered: #{format_number(result.filtered.count)} items in #{Float.round(result.filtered.time_ms, 1)}ms"
        )

        shell.info("  Speedup: #{result.speedup_pct}%")
        shell.info("  Reduction: #{result.reduction_pct}%")

      {:error, reason} ->
        shell.error("  Error: #{inspect(reason)}")
    end
  end

  defp format_number(num) when is_integer(num) do
    num
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(num), do: "#{num}"
end
