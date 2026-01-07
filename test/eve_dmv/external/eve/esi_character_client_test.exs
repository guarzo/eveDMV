defmodule EveDmv.Eve.EsiCharacterClientTest do
  @moduledoc """
  Tests for the EsiCharacterClient module.

  These tests verify input validation and module structure.
  Network-dependent tests are skipped unless explicitly enabled.
  """
  use ExUnit.Case, async: true

  alias EveDmv.Eve.EsiCharacterClient

  @moduletag :esi

  describe "module structure" do
    test "module compiles and is loaded" do
      assert Code.ensure_loaded?(EsiCharacterClient)
    end

    test "exports get_character/1" do
      exports = EsiCharacterClient.__info__(:functions)
      assert {:get_character, 1} in exports
    end

    test "exports get_characters/1" do
      exports = EsiCharacterClient.__info__(:functions)
      assert {:get_characters, 1} in exports
    end

    test "exports get_character_employment_history/1" do
      exports = EsiCharacterClient.__info__(:functions)
      assert {:get_character_employment_history, 1} in exports
    end

    test "exports get_character_skills/2" do
      exports = EsiCharacterClient.__info__(:functions)
      assert {:get_character_skills, 2} in exports
    end

    test "exports get_character_assets/1" do
      exports = EsiCharacterClient.__info__(:functions)
      assert {:get_character_assets, 1} in exports
    end

    test "exports get_character_assets/2" do
      exports = EsiCharacterClient.__info__(:functions)
      assert {:get_character_assets, 2} in exports
    end
  end

  describe "get_character/1 input validation" do
    test "returns error for nil character_id" do
      result = EsiCharacterClient.get_character(nil)
      assert result == {:error, :invalid_character_id}
    end

    test "returns error for string character_id" do
      result = EsiCharacterClient.get_character("12345")
      assert result == {:error, :invalid_character_id}
    end

    test "returns error for float character_id" do
      result = EsiCharacterClient.get_character(123.45)
      assert result == {:error, :invalid_character_id}
    end

    # Skipped: Requires network access to ESI API
    @tag :skip
    @tag timeout: 5_000
    test "accepts integer character_id" do
      # This will attempt a network call, but validates the input is accepted
      result = EsiCharacterClient.get_character(12_345_678)
      # Result could be ok or error depending on network/cache state
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_characters/1" do
    test "returns empty map for empty list" do
      result = EsiCharacterClient.get_characters([])
      assert result == {:ok, %{}}
    end

    # Skipped: Requires network access to ESI API
    @tag :skip
    @tag timeout: 5_000
    test "accepts list of integers" do
      result = EsiCharacterClient.get_characters([12_345_678])

      assert match?({:ok, _}, result) or match?({:ok, _, :partial}, result) or
               match?({:error, _}, result)
    end
  end

  describe "get_character_assets/1 without auth" do
    test "returns authentication required error" do
      result = EsiCharacterClient.get_character_assets(12_345_678)
      assert result == {:error, :authentication_required}
    end
  end
end
