defmodule EveDmv.Intelligence.ShipDatabase do
  @moduledoc """
  Static ship data and classifications for fleet analysis.

  Provides a unified interface for ship classification, mass data,
  role information, doctrine analysis, and wormhole utilities.
  """

  alias EveDmv.Intelligence.ShipDatabase.ShipClassification
  # Extracted modules
  alias EveDmv.Intelligence.ShipDatabase.DoctrineData
  alias EveDmv.Intelligence.ShipDatabase.ShipMassData
  alias EveDmv.Intelligence.ShipDatabase.ShipRoleData
  alias EveDmv.Intelligence.ShipDatabase.WormholeUtils

  # Ship class functions
  def get_ship_class(ship_name) when is_binary(ship_name) do
    ShipClassification.get_ship_class_by_name(ship_name)
  end

  # Delegation to ShipClassification
  defdelegate get_ship_class(ship_type_id), to: ShipClassification

  # Ship mass functions
  def get_ship_mass(ship_name) when is_binary(ship_name) do
    ShipMassData.get_ship_mass_by_name(ship_name)
  end

  # Delegation to ShipMassData
  defdelegate get_ship_mass(ship_type_id), to: ShipMassData

  # Delegation to ShipRoleData
  defdelegate get_ship_role(ship_name), to: ShipRoleData

  # Delegation to WormholeUtils
  defdelegate get_wormhole_restrictions(ship_class), to: WormholeUtils

  # Delegation to DoctrineData
  defdelegate doctrine_ship?(ship_name, doctrine), to: DoctrineData

  # Ship category functions
  def get_ship_category(ship_name) when is_binary(ship_name) do
    ShipClassification.get_ship_category_by_name(ship_name)
  end

  # Delegation to ShipClassification
  defdelegate get_ship_category(ship_type_id), to: ShipClassification

  # Capital ship functions
  def is_capital?(ship_name) when is_binary(ship_name) do
    ShipClassification.is_capital_by_name?(ship_name)
  end

  # Delegation to ShipClassification
  defdelegate is_capital?(ship_type_id), to: ShipClassification

  # Delegation to WormholeUtils
  defdelegate wormhole_suitable?(ship_name), to: WormholeUtils

  # Delegation to ShipRoleData
  defdelegate optimal_gang_size(ship_composition), to: ShipRoleData

  def get_optimal_gang_size(ship_composition) do
    ShipRoleData.optimal_gang_size(ship_composition)
  end
end
