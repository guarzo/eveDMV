defmodule EveDmv.Intelligence.Analyzers.FleetAssetManager.RequirementsBuilderTest do
  @moduledoc """
  Tests for RequirementsBuilder module, focusing on default value configuration
  and fallback behavior when ship data is unavailable.
  """
  use ExUnit.Case, async: true

  alias EveDmv.Intelligence.Analyzers.FleetAssetManager.RequirementsBuilder

  describe "default ship configuration" do
    test "default_ship_mass_kg returns the configured default mass" do
      # 12,000,000 kg represents a standard T1 cruiser mass
      assert RequirementsBuilder.default_ship_mass_kg() == 12_000_000
    end

    test "default_ship_estimated_cost returns the configured default cost" do
      # 50,000,000 ISK represents a conservatively fitted T1 cruiser
      assert RequirementsBuilder.default_ship_estimated_cost() == 50_000_000
    end

    test "default_ship_info returns a complete map with all required fields" do
      defaults = RequirementsBuilder.default_ship_info()

      assert is_map(defaults)
      assert defaults.mass_kg == RequirementsBuilder.default_ship_mass_kg()
      assert defaults.estimated_cost == RequirementsBuilder.default_ship_estimated_cost()
      assert defaults.category == "Unknown"
      assert defaults.role == "unknown"
      assert defaults.ship_class == "Unknown"
      assert defaults.wormhole_suitable == false
    end

    test "default values are consistent between accessor functions and default_ship_info" do
      defaults = RequirementsBuilder.default_ship_info()

      assert defaults.mass_kg == RequirementsBuilder.default_ship_mass_kg()
      assert defaults.estimated_cost == RequirementsBuilder.default_ship_estimated_cost()
    end
  end

  describe "get_ship_info fallback behavior" do
    test "get_ship_info uses default mass when StaticData returns nil for unknown ship" do
      # Using a ship name that definitely doesn't exist in StaticData
      ship_info = RequirementsBuilder.get_ship_info("NonExistent Imaginary Ship XYZ123")

      # Should fall back to default mass
      assert ship_info.mass_kg == RequirementsBuilder.default_ship_mass_kg()
    end

    test "get_ship_info uses default values for all fields when ship is unknown" do
      ship_info = RequirementsBuilder.get_ship_info("Completely Fake Ship Name")
      defaults = RequirementsBuilder.default_ship_info()

      # Should fall back to defaults for all nil-returning fields
      assert ship_info.mass_kg == defaults.mass_kg
      assert ship_info.role == defaults.role
      assert ship_info.category == defaults.category
      assert ship_info.ship_class == defaults.ship_class
    end

    test "get_ship_info returns proper structure even for unknown ships" do
      ship_info = RequirementsBuilder.get_ship_info("Unknown Ship For Testing")

      # Verify the structure is complete
      assert Map.has_key?(ship_info, :mass_kg)
      assert Map.has_key?(ship_info, :estimated_cost)
      assert Map.has_key?(ship_info, :category)
      assert Map.has_key?(ship_info, :role)
      assert Map.has_key?(ship_info, :ship_class)
      assert Map.has_key?(ship_info, :wormhole_suitable)

      # All numeric values should be valid numbers (not nil)
      assert is_number(ship_info.mass_kg)
      assert is_number(ship_info.estimated_cost)
      assert ship_info.mass_kg > 0
      assert ship_info.estimated_cost > 0
    end
  end

  describe "build_ship_requirements_with_missing" do
    test "reports missing ships when ship_data lacks the ship_name" do
      doctrine_template = %{
        "dps" => %{
          "preferred_ships" => ["Missing Ship Alpha", "Missing Ship Beta"],
          "required" => 2
        }
      }

      # Empty ship_data means all ships will be missing
      ship_data = %{}

      {requirements, missing} =
        RequirementsBuilder.build_ship_requirements_with_missing(doctrine_template, ship_data)

      # Requirements should be empty since all ships are missing
      assert requirements == %{}

      # Missing list should contain all ships
      assert length(missing) == 2
      assert {"Missing Ship Alpha", "dps"} in missing
      assert {"Missing Ship Beta", "dps"} in missing
    end
  end

  describe "wormhole compatibility thresholds" do
    test "default mass allows passage through cruiser wormholes" do
      # Default mass of 12,000,000 kg should allow passage through:
      # - Frigate holes (up to 20,000,000 kg) - yes
      # - Cruiser holes (up to 90,000,000 kg) - yes
      # - Battleship holes (up to 300,000,000 kg) - yes
      # - Capital holes (up to 1,800,000,000 kg) - yes
      default_mass = RequirementsBuilder.default_ship_mass_kg()

      assert default_mass <= 20_000_000, "Default mass should fit through frigate holes"
      assert default_mass <= 90_000_000, "Default mass should fit through cruiser holes"
      assert default_mass <= 300_000_000, "Default mass should fit through battleship holes"
      assert default_mass <= 1_800_000_000, "Default mass should fit through capital holes"
    end
  end
end
