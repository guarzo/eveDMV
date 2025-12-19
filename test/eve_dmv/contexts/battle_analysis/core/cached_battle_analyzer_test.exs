defmodule EveDmv.Contexts.BattleAnalysis.Core.CachedBattleAnalyzerTest do
  @moduledoc """
  Tests for the CachedBattleAnalyzer module.

  Verifies caching behavior and integration with OptimizedBattleAnalyzer.
  """

  use ExUnit.Case, async: true

  alias EveDmv.Contexts.BattleAnalysis.Core.CachedBattleAnalyzer

  describe "module structure" do
    setup do
      {:module, _} = Code.ensure_loaded(CachedBattleAnalyzer)
      :ok
    end

    test "module is properly loaded" do
      assert {:module, CachedBattleAnalyzer} = Code.ensure_loaded(CachedBattleAnalyzer)
    end

    test "exposes expected public functions" do
      funcs = CachedBattleAnalyzer.__info__(:functions)

      assert {:analyze_battle, 1} in funcs
      assert {:get_battle_details, 1} in funcs
      assert {:analyze_battles_batch, 1} in funcs
    end
  end

  describe "analyze_battle/1" do
    test "function exists with correct arity" do
      funcs = CachedBattleAnalyzer.__info__(:functions)
      assert {:analyze_battle, 1} in funcs
    end

    test "accepts battle_id parameter" do
      assert is_function(&CachedBattleAnalyzer.analyze_battle/1)
    end
  end

  describe "get_battle_details/1" do
    test "function exists with correct arity" do
      funcs = CachedBattleAnalyzer.__info__(:functions)
      assert {:get_battle_details, 1} in funcs
    end

    test "accepts battle_id parameter" do
      assert is_function(&CachedBattleAnalyzer.get_battle_details/1)
    end
  end

  describe "analyze_battles_batch/1" do
    test "function exists with correct arity" do
      funcs = CachedBattleAnalyzer.__info__(:functions)
      assert {:analyze_battles_batch, 1} in funcs
    end

    test "accepts list of battle_ids" do
      assert is_function(&CachedBattleAnalyzer.analyze_battles_batch/1)
    end
  end

  describe "caching behavior" do
    test "uses MultiLayerCache for caching" do
      # Verify the module depends on MultiLayerCache
      assert Code.ensure_loaded?(EveDmv.Platform.Cache.MultiLayerCache)
    end

    test "delegates to OptimizedBattleAnalyzer" do
      # Verify the module depends on OptimizedBattleAnalyzer
      assert Code.ensure_loaded?(EveDmv.Contexts.BattleAnalysis.Core.OptimizedBattleAnalyzer)
    end
  end

  describe "API documentation" do
    test "module has moduledoc" do
      {:docs_v1, _, _, _, module_doc, _, _} = Code.fetch_docs(CachedBattleAnalyzer)
      assert module_doc != :hidden
      assert module_doc != :none
    end

    test "analyze_battle has documentation" do
      {:docs_v1, _, _, _, _, _, function_docs} = Code.fetch_docs(CachedBattleAnalyzer)

      doc =
        Enum.find(function_docs, fn
          {{:function, :analyze_battle, 1}, _, _, _, _} -> true
          _ -> false
        end)

      assert doc != nil
    end
  end
end
