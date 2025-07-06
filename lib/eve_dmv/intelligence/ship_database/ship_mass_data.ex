defmodule EveDmv.Intelligence.ShipDatabase.ShipMassData do
  @moduledoc """
  Ship mass data and utilities.

  Handles ship mass information for wormhole calculations and
  fleet movement analysis.
  """

  @doc """
  Get ship mass by ship type ID.
  """
  def get_ship_mass(ship_type_id) when is_integer(ship_type_id) do
    ship_masses()[ship_type_id] || 10_000_000
  end

  @doc """
  Get ship mass by ship name.
  """
  def get_ship_mass_by_name(ship_name) when is_binary(ship_name) do
    ship_masses_by_name()[ship_name] || 10_000_000
  end

  # Private data functions

  defp ship_masses do
    %{
      # Strategic Cruisers
      # Tengu
      29_984 => 12_900_000,
      # Legion
      29_986 => 13_000_000,
      # Proteus
      29_988 => 12_800_000,
      # Loki
      29_990 => 13_100_000,

      # Command Ships
      # Damnation
      22_442 => 13_500_000,
      # Nighthawk
      22_444 => 13_200_000,
      # Claymore
      22_446 => 13_800_000,
      # Sleipnir
      22_448 => 13_600_000,

      # Logistics Cruisers
      # Guardian
      11_985 => 11_800_000,
      # Basilisk
      11_987 => 11_900_000,
      # Oneiros
      11_989 => 12_100_000,
      # Scimitar
      11_993 => 12_000_000,

      # Heavy Assault Cruisers
      # Muninn
      12_003 => 12_200_000,
      # Cerberus
      12_005 => 12_000_000,
      # Zealot
      12_011 => 12_400_000,
      # Eagle
      12_015 => 12_100_000,

      # Interceptors
      # Ares
      11_174 => 1_200_000,
      # Stiletto
      11_176 => 1_150_000,
      # Crow
      11_178 => 1_180_000,
      # Malediction
      11_180 => 1_100_000,

      # EWAR Frigates
      # Crucifier
      11_192 => 1_300_000,
      # Maulus
      11_200 => 1_250_000,
      # Vigil
      11_202 => 1_280_000,
      # Griffin
      11_196 => 1_220_000,

      # Common ships
      # Rifter
      587 => 1_400_000,
      # Punisher
      588 => 1_350_000,
      # Bantam
      648 => 1_300_000,
      # Arbitrator
      621 => 11_500_000,
      # Drake
      1201 => 14_500_000
    }
  end

  defp ship_masses_by_name do
    %{
      # Command Ships
      "Damnation" => 13_500_000,
      "Nighthawk" => 13_200_000,
      "Claymore" => 13_800_000,
      "Sleipnir" => 13_600_000,

      # Strategic Cruisers
      "Legion" => 13_000_000,
      "Proteus" => 12_800_000,
      "Tengu" => 12_900_000,
      "Loki" => 13_100_000,

      # Logistics
      "Guardian" => 11_800_000,
      "Scimitar" => 12_000_000,
      "Basilisk" => 11_900_000,
      "Oneiros" => 12_100_000,

      # Heavy Assault Cruisers
      "Muninn" => 12_200_000,
      "Cerberus" => 12_000_000,
      "Zealot" => 12_400_000,
      "Eagle" => 12_100_000,

      # Interceptors
      "Ares" => 1_200_000,
      "Malediction" => 1_100_000,
      "Stiletto" => 1_150_000,
      "Crow" => 1_180_000,

      # EWAR Frigates
      "Crucifier" => 1_300_000,
      "Maulus" => 1_250_000,
      "Vigil" => 1_280_000,
      "Griffin" => 1_220_000,

      # Common ships
      "Rifter" => 1_400_000,
      "Punisher" => 1_350_000,
      "Bantam" => 1_300_000,
      "Maller" => 11_500_000,
      "Drake" => 14_500_000,
      "Stabber" => 10_500_000
    }
  end
end
