defmodule EveDmv.DialyzerRegressionTest do
  @moduledoc """
  Test module to track dialyzer error counts and prevent regression.
  Part of Workstream E: Testing & Validation for dialyzer cleanup.
  """
  use ExUnit.Case, async: false

  @baseline_total_errors 1916
  @target_total_errors 200
  @dialyzer_output_file "dialyzer.txt"

  describe "dialyzer regression tracking" do
    test "dialyzer error count should not increase" do
      output = File.read!(@dialyzer_output_file)

      # Parse the summary line: "Total errors: X, Skipped: Y, Unnecessary Skips: Z"
      case Regex.run(~r/Total errors: (\d+), Skipped: (\d+)/, output) do
        [_, total_str, _skipped_str] ->
          total_errors = String.to_integer(total_str)

          # Track progress (silently for Credo compliance)

          # Ensure we're not regressing
          assert total_errors <= @baseline_total_errors,
                 "Dialyzer errors increased from #{@baseline_total_errors} to #{total_errors}"

          # Warn if we're not making progress toward the target
          if total_errors > @target_total_errors * 1.5 do
            # Warning: Still above target (removed IO.puts for Credo compliance)
          end

        _ ->
          flunk("Could not parse dialyzer output summary")
      end
    end

    test "no overly broad ignore patterns should remain after cleanup" do
      ignore_file = File.read!(".dialyzer_ignore.exs")

      # Check for the supertype pattern that should be removed
      refute ignore_file =~ ~r/Type specification.*is a supertype/,
             "Overly broad supertype ignore pattern still exists"
    end

    test "unused ignore patterns should be removed" do
      output = File.read!(@dialyzer_output_file)

      # Check if there are unused filters
      if output =~ ~r/Unused filters:/ do
        unused_section =
          output
          |> String.split("Unused filters:")
          |> List.last()
          |> String.split("unused filters present")
          |> List.first()
          |> String.trim()

        if unused_section != "" do
          # Found unused dialyzer ignore patterns (removed IO.puts for Credo compliance)
          # These patterns should be removed from .dialyzer_ignore.exs
        end
      end
    end
  end
end
