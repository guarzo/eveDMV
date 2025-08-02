defmodule EveDmv.Eve.ShipGroups do
  @moduledoc """
  Constants for EVE Online ship groups and classifications.

  This module provides structured access to ship group classifications
  based on actual EVE SDE data. Used by StaticData and other modules
  for consistent ship categorization.
  """

  # Primary ship group classifications
  @ship_groups %{
    # Frigates
    # Standard frigates
    25 => :frigate,
    # Assault frigates
    324 => :assault_frigate,
    # Covert ops
    830 => :covert_ops,
    # Interceptors
    831 => :interceptor,
    # Interdictors
    541 => :interdictor,
    # EAFs
    893 => :electronic_attack_frigate,
    # Logi frigates
    1527 => :logistics_frigate,

    # Destroyers
    # Standard destroyers
    420 => :destroyer,
    # T3 destroyers
    1534 => :tactical_destroyer,

    # Cruisers
    # Standard cruisers
    26 => :cruiser,
    # HACs
    358 => :heavy_assault_cruiser,
    # HICs
    894 => :heavy_interdictor,
    # Force recons
    833 => :force_recon,
    # Combat recons
    906 => :combat_recon,
    # Logistics
    832 => :logistics,
    883 => :logistics_cruiser,
    # T3Cs
    963 => :strategic_cruiser,

    # Battlecruisers
    # Command Ships (actually group 419 in EVE)
    419 => :command_ship,
    # Attack BCs
    1201 => :attack_battlecruiser,
    # Command destroyers
    540 => :command_destroyer,

    # Battleships
    # Standard battleships
    27 => :battleship,
    # Marauders
    898 => :marauder,
    # Black ops
    900 => :black_ops,

    # Capital Ships
    # Dreadnoughts
    485 => :dreadnought,
    # Carriers
    547 => :carrier,
    # Supercarriers/Motherships
    659 => :supercarrier,
    # Titans
    30 => :titan,
    # Force auxiliaries
    1538 => :force_auxiliary,

    # Industrial Ships
    # Standard industrials
    28 => :industrial,
    # DSTs
    380 => :deep_space_transport,
    # Blockade runners
    1202 => :blockade_runner,
    # Freighters
    513 => :freighter,
    # Jump freighters
    902 => :jump_freighter,

    # Mining Ships
    # Mining barges
    543 => :mining_barge,
    # Exhumers
    1213 => :exhumer,
    # Orcas/Porpoises
    941 => :industrial_command_ship,

    # Special
    # Rookie ships
    237 => :corvette,
    # Shuttles
    31 => :shuttle
  }

  @doc """
  Get all ship groups.
  Returns a map of group_id => classification atom.
  """
  def all_groups, do: @ship_groups

  @doc """
  Get ship classification by group ID.
  Returns the classification atom or :unknown.
  """
  def get_classification(group_id) when is_integer(group_id) do
    Map.get(@ship_groups, group_id, :unknown)
  end

  @doc """
  Get all ships of a specific classification.
  Returns list of group IDs.
  """
  def get_groups_by_classification(classification) do
    @ship_groups
    |> Enum.filter(fn {_group_id, class} -> class == classification end)
    |> Enum.map(fn {group_id, _class} -> group_id end)
  end

  @doc """
  Check if a group ID represents a capital ship.
  """
  def capital?(group_id) when is_integer(group_id) do
    # Dreads, carriers, supers, titans, FAXes
    group_id in [485, 547, 659, 30, 1538]
  end

  @doc """
  Check if a group ID represents a subcapital combat ship.
  """
  def subcapital_combat?(group_id) when is_integer(group_id) do
    classification = get_classification(group_id)

    classification in [
      :frigate,
      :assault_frigate,
      :interceptor,
      :interdictor,
      :electronic_attack_frigate,
      :destroyer,
      :tactical_destroyer,
      :cruiser,
      :heavy_assault_cruiser,
      :heavy_interdictor,
      :force_recon,
      :combat_recon,
      :logistics_cruiser,
      :strategic_cruiser,
      :battlecruiser,
      :attack_battlecruiser,
      :battleship,
      :marauder,
      :black_ops
    ]
  end

  @doc """
  Check if a group ID represents a logistics ship.
  """
  def logistics?(group_id) when is_integer(group_id) do
    classification = get_classification(group_id)
    classification in [:logistics_frigate, :logistics_cruiser, :force_auxiliary]
  end

  @doc """
  Check if a group ID represents an EWAR ship.
  """
  def ewar?(group_id) when is_integer(group_id) do
    classification = get_classification(group_id)
    classification in [:electronic_attack_frigate, :force_recon, :combat_recon]
  end

  @doc """
  Check if a group ID represents an industrial ship.
  """
  def industrial?(group_id) when is_integer(group_id) do
    classification = get_classification(group_id)

    classification in [
      :industrial,
      :deep_space_transport,
      :blockade_runner,
      :freighter,
      :jump_freighter,
      :mining_barge,
      :exhumer,
      :industrial_command_ship
    ]
  end

  @doc """
  Get role category for a ship group.
  Returns :combat, :logistics, :ewar, :industrial, :special.
  """
  def get_role_category(group_id) when is_integer(group_id) do
    cond do
      __MODULE__.logistics?(group_id) -> :logistics
      __MODULE__.ewar?(group_id) -> :ewar
      industrial?(group_id) -> :industrial
      subcapital_combat?(group_id) or capital?(group_id) -> :combat
      true -> :special
    end
  end

  @doc """
  Get size category for a ship group.
  Returns :frigate, :destroyer, :cruiser, :battlecruiser, :battleship, :capital, :industrial.
  """
  def get_size_category(group_id) when is_integer(group_id) do
    classification = get_classification(group_id)

    case classification do
      class
      when class in [
             :frigate,
             :assault_frigate,
             :covert_ops,
             :interceptor,
             :interdictor,
             :electronic_attack_frigate,
             :logistics_frigate
           ] ->
        :frigate

      class when class in [:destroyer, :tactical_destroyer, :command_destroyer] ->
        :destroyer

      class
      when class in [
             :cruiser,
             :heavy_assault_cruiser,
             :heavy_interdictor,
             :force_recon,
             :combat_recon,
             :logistics_cruiser,
             :strategic_cruiser
           ] ->
        :cruiser

      class when class in [:battlecruiser, :attack_battlecruiser] ->
        :battlecruiser

      class when class in [:battleship, :marauder, :black_ops] ->
        :battleship

      class when class in [:dreadnought, :carrier, :supercarrier, :titan, :force_auxiliary] ->
        :capital

      class
      when class in [
             :industrial,
             :deep_space_transport,
             :blockade_runner,
             :freighter,
             :jump_freighter,
             :mining_barge,
             :exhumer,
             :industrial_command_ship
           ] ->
        :industrial

      _ ->
        :special
    end
  end

  @doc """
  Get display name for a classification.
  """
  def display_name(classification) when is_atom(classification) do
    case classification do
      :frigate -> "Frigate"
      :assault_frigate -> "Assault Frigate"
      :covert_ops -> "Covert Ops"
      :interceptor -> "Interceptor"
      :interdictor -> "Interdictor"
      :electronic_attack_frigate -> "Electronic Attack Ship"
      :logistics_frigate -> "Logistics Frigate"
      :destroyer -> "Destroyer"
      :tactical_destroyer -> "Tactical Destroyer"
      :command_destroyer -> "Command Destroyer"
      :cruiser -> "Cruiser"
      :heavy_assault_cruiser -> "Heavy Assault Cruiser"
      :heavy_interdictor -> "Heavy Interdictor"
      :force_recon -> "Force Recon Ship"
      :combat_recon -> "Combat Recon Ship"
      :logistics_cruiser -> "Logistics Cruiser"
      :strategic_cruiser -> "Strategic Cruiser"
      :battlecruiser -> "Battlecruiser"
      :attack_battlecruiser -> "Attack Battlecruiser"
      :battleship -> "Battleship"
      :marauder -> "Marauder"
      :black_ops -> "Black Ops Battleship"
      :dreadnought -> "Dreadnought"
      :carrier -> "Carrier"
      :supercarrier -> "Supercarrier"
      :titan -> "Titan"
      :force_auxiliary -> "Force Auxiliary"
      :industrial -> "Industrial"
      :deep_space_transport -> "Deep Space Transport"
      :blockade_runner -> "Blockade Runner"
      :freighter -> "Freighter"
      :jump_freighter -> "Jump Freighter"
      :mining_barge -> "Mining Barge"
      :exhumer -> "Exhumer"
      :industrial_command_ship -> "Industrial Command Ship"
      :corvette -> "Corvette"
      :shuttle -> "Shuttle"
      _ -> "Unknown"
    end
  end
end
