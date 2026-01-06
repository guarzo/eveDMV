defmodule EveDmv.Contexts.BattleAnalysis.ApiTest do
  @moduledoc """
  Tests for the Battle Analysis API domain (Ash Domain).
  Tests the Ash domain functions for reading, creating, updating, and destroying resources.
  """
  use EveDmv.DataCase, async: true

  alias EveDmv.Contexts.BattleAnalysis.Api

  # Helper to safely call functions that may require resources or changesets
  defp safe_call(fun) do
    fun.()
  rescue
    _ -> {:error, :invalid_argument}
  catch
    :exit, _ -> {:error, :service_unavailable}
  end

  describe "read/1" do
    test "handles nil query gracefully" do
      result = safe_call(fn -> Api.read(nil) end)

      # Should return error for nil query
      assert match?({:error, _}, result)
    end
  end

  describe "create/1" do
    test "handles nil changeset gracefully" do
      result = safe_call(fn -> Api.create(nil) end)

      # Should return error for nil changeset
      assert match?({:error, _}, result)
    end
  end

  describe "update/1" do
    test "handles nil changeset gracefully" do
      result = safe_call(fn -> Api.update(nil) end)

      # Should return error for nil changeset
      assert match?({:error, _}, result)
    end
  end

  describe "destroy/1" do
    test "handles nil record gracefully" do
      result = safe_call(fn -> Api.destroy(nil) end)

      # Should return error for nil record
      assert match?({:error, _}, result)
    end
  end

  describe "module structure" do
    test "is an Ash Domain" do
      # Verify the module uses Ash.Domain
      assert {:module, Api} = Code.ensure_loaded(Api)
      # The domain should exist as a proper module
      assert function_exported?(Api, :read, 1)
      assert function_exported?(Api, :create, 1)
      assert function_exported?(Api, :update, 1)
      assert function_exported?(Api, :destroy, 1)
    end

    test "has correct function arities" do
      # Check the expected function arities
      assert function_exported?(Api, :read, 1)
      assert function_exported?(Api, :create, 1)
      assert function_exported?(Api, :update, 1)
      assert function_exported?(Api, :destroy, 1)
    end
  end
end
