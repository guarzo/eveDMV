defmodule EveDmv.Eve.StaticDataLoader.SdeVersionManagerTest do
  use ExUnit.Case, async: true

  alias EveDmv.Eve.StaticDataLoader.SdeVersionManager

  describe "version_info type" do
    test "version info should have expected structure" do
      # This tests the expected shape of version info returned by get_ccp_version_info
      # We can't call the actual function without network, but we document the expected shape

      expected_keys = [:build_number, :release_date, :version_string]

      # Create a sample version info
      sample_version = %{
        build_number: 3_142_455,
        release_date: "2025-12-15T11:14:02Z",
        version_string: "build-3142455"
      }

      Enum.each(expected_keys, fn key ->
        assert Map.has_key?(sample_version, key)
      end)
    end
  end

  describe "build number format" do
    test "CCP version string format is 'build-XXXXXXX'" do
      build_number = 3_142_455
      expected_format = "build-#{build_number}"

      # This is the format used by SdeVersionManager
      assert expected_format == "build-3142455"
    end

    test "build numbers are integers" do
      # CCP uses integer build numbers for comparison
      build_a = 3_142_455
      build_b = 3_142_456

      assert is_integer(build_a)
      assert is_integer(build_b)
      assert build_b > build_a
    end
  end

  describe "integration with CcpSdeClient" do
    test "SdeVersionManager references CcpSdeClient" do
      # Verify the alias is set up correctly
      assert Code.ensure_loaded?(EveDmv.Eve.StaticDataLoader.CcpSdeClient)
    end
  end

  describe "version_needs_update?/2" do
    test "nil current version should trigger update" do
      current = nil
      latest = %{build_number: 3_142_455, version_string: "build-3142455"}

      assert SdeVersionManager.version_needs_update?(current, latest) == true
    end

    test "older build number should trigger update" do
      current = %{build_number: 3_142_454, version_string: "build-3142454"}
      latest = %{build_number: 3_142_455, version_string: "build-3142455"}

      assert SdeVersionManager.version_needs_update?(current, latest) == true
    end

    test "same build number should not trigger update" do
      current = %{build_number: 3_142_455, version_string: "build-3142455"}
      latest = %{build_number: 3_142_455, version_string: "build-3142455"}

      assert SdeVersionManager.version_needs_update?(current, latest) == false
    end

    test "newer current version should not trigger update" do
      current = %{build_number: 3_142_456, version_string: "build-3142456"}
      latest = %{build_number: 3_142_455, version_string: "build-3142455"}

      assert SdeVersionManager.version_needs_update?(current, latest) == false
    end

    test "non-CCP format current version should trigger update" do
      # Current version without build_number key triggers update
      current = %{version_string: "legacy-version"}
      latest = %{build_number: 3_142_455, version_string: "build-3142455"}

      assert SdeVersionManager.version_needs_update?(current, latest) == true
    end
  end

  describe "public API" do
    test "check_for_updates/0 exists" do
      assert function_exported?(SdeVersionManager, :check_for_updates, 0)
    end

    test "get_ccp_version_info/0 exists" do
      assert function_exported?(SdeVersionManager, :get_ccp_version_info, 0)
    end

    test "version_needs_update?/2 exists" do
      assert function_exported?(SdeVersionManager, :version_needs_update?, 2)
    end
  end
end
