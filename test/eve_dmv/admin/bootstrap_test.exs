defmodule EveDmv.Admin.BootstrapTest do
  use EveDmv.DataCase, async: true

  alias EveDmv.Admin.Bootstrap
  alias EveDmv.Users.User

  describe "bootstrap_configured?/0" do
    test "returns false when no environment variables are set" do
      with_env(%{}, fn ->
        refute Bootstrap.bootstrap_configured?()
      end)
    end

    test "returns true when ADMIN_BOOTSTRAP_CHARACTERS is set" do
      with_env(%{"ADMIN_BOOTSTRAP_CHARACTERS" => "Test User"}, fn ->
        assert Bootstrap.bootstrap_configured?()
      end)
    end

    test "returns true when ADMIN_BOOTSTRAP_CHARACTER_IDS is set" do
      with_env(%{"ADMIN_BOOTSTRAP_CHARACTER_IDS" => "123456789"}, fn ->
        assert Bootstrap.bootstrap_configured?()
      end)
    end

    test "returns false when environment variables are empty strings" do
      with_env(%{"ADMIN_BOOTSTRAP_CHARACTERS" => "", "ADMIN_BOOTSTRAP_CHARACTER_IDS" => ""}, fn ->
        refute Bootstrap.bootstrap_configured?()
      end)
    end
  end

  describe "bootstrap_from_env/0" do
    test "handles empty configuration gracefully" do
      with_env(%{}, fn ->
        result = Bootstrap.bootstrap_from_env()

        assert result.character_names == []
        assert result.character_ids == []
        assert result.total_processed == 0
      end)
    end

    test "parses character names correctly" do
      with_env(%{"ADMIN_BOOTSTRAP_CHARACTERS" => "John Doe, Jane Smith ,  Bob  "}, fn ->
        result = Bootstrap.bootstrap_from_env()

        # All will fail since users don't exist, but we can test parsing
        assert length(result.character_names) == 3
        assert result.total_processed == 3

        # Check that all attempts failed with :user_not_found
        assert Enum.all?(result.character_names, fn
                 {:error, :user_not_found, _} -> true
                 _ -> false
               end)
      end)
    end

    test "parses character IDs correctly" do
      with_env(%{"ADMIN_BOOTSTRAP_CHARACTER_IDS" => "123456789, 987654321, invalid, 555"}, fn ->
        result = Bootstrap.bootstrap_from_env()

        # Should parse 3 valid IDs (invalid one is filtered out)
        assert length(result.character_ids) == 3
        assert result.total_processed == 3

        # All will fail since users don't exist
        assert Enum.all?(result.character_ids, fn
                 {:error, :user_not_found, _} -> true
                 _ -> false
               end)
      end)
    end

    test "filters out invalid character IDs" do
      with_env(%{"ADMIN_BOOTSTRAP_CHARACTER_IDS" => "123, invalid, -1, 0, 456"}, fn ->
        result = Bootstrap.bootstrap_from_env()

        # Should only process valid positive integers (123, 456)
        assert length(result.character_ids) == 2
        assert result.total_processed == 2
      end)
    end
  end

  # Test helper to temporarily set environment variables
  defp with_env(env_map, func) do
    # Save original values
    original_env = Enum.into(env_map, %{}, fn {key, _} -> {key, System.get_env(key)} end)

    try do
      # Set test environment variables
      Enum.each(env_map, fn {key, value} ->
        System.put_env(key, value)
      end)

      func.()
    after
      # Restore original values
      Enum.each(original_env, fn {key, original_value} ->
        if original_value do
          System.put_env(key, original_value)
        else
          System.delete_env(key)
        end
      end)
    end
  end
end
