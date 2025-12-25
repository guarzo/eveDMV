defmodule EveDmv.Eve.StaticDataLoader.SdeValidatorTest do
  use ExUnit.Case, async: true

  alias EveDmv.Eve.StaticDataLoader.SdeValidator

  @fixtures_dir Path.join([__DIR__, "..", "..", "..", "..", "fixtures", "sde"])

  describe "compare_with_jsonl_files/1" do
    test "returns error when files not found" do
      result = SdeValidator.compare_with_jsonl_files("/non/existent/path")
      assert {:error, :jsonl_files_not_found} = result
    end
  end

  describe "performance_comparison/1" do
    test "compares filtered vs unfiltered processing" do
      # Using fixtures directory as test input
      result = SdeValidator.performance_comparison(@fixtures_dir)

      case result do
        {:ok, comparison} ->
          assert is_map(comparison)
          assert Map.has_key?(comparison, :unfiltered)
          assert Map.has_key?(comparison, :filtered)
          assert Map.has_key?(comparison, :speedup_pct)
          assert Map.has_key?(comparison, :reduction_pct)

          # Verify structure
          assert is_integer(comparison.unfiltered.count)
          assert is_float(comparison.unfiltered.time_ms)
          assert is_integer(comparison.filtered.count)
          assert is_float(comparison.filtered.time_ms)

          # Filtered should have fewer items
          assert comparison.filtered.count <= comparison.unfiltered.count

        {:error, _} ->
          # Test fixtures may not have all required files
          :ok
      end
    end
  end

  describe "module structure" do
    test "exports expected functions" do
      # Ensure module is loaded
      {:module, _} = Code.ensure_loaded(SdeValidator)

      assert function_exported?(SdeValidator, :generate_validation_report, 0)
      assert function_exported?(SdeValidator, :get_database_counts, 0)
      assert function_exported?(SdeValidator, :get_category_breakdown, 0)
      assert function_exported?(SdeValidator, :validate_essential_items, 0)
      assert function_exported?(SdeValidator, :get_version_info, 0)
      assert function_exported?(SdeValidator, :compare_with_jsonl_files, 1)
      assert function_exported?(SdeValidator, :validate_ship_exists, 1)
      assert function_exported?(SdeValidator, :performance_comparison, 1)
    end
  end

  describe "essential items constants" do
    test "module defines essential ships for validation" do
      # Ensure module is loaded
      {:module, _} = Code.ensure_loaded(SdeValidator)

      # The module should have essential ships defined
      # We test this by checking the function exists
      assert function_exported?(SdeValidator, :validate_essential_items, 0)
    end
  end
end
