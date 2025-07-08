defmodule EveDmv.Intelligence.ShipDatabase.DoctrineData do
  @moduledoc """
  Ship doctrine data and classification utilities.

  Handles doctrine ship classifications for fleet composition
  analysis and doctrine adherence checking.
  """

  @doc """
  Check if ship is part of a specific doctrine.
  """
  def doctrine_ship?(ship_name, doctrine) do
    ships = doctrine_ships()[doctrine] || []
    ship_name in ships
  end

  @doc """
  Get all available doctrine types.
  """
  def available_doctrines do
    Map.keys(doctrine_ships())
  end

  @doc """
  Get all ships for a specific doctrine.
  """
  def get_doctrine_ships(doctrine) do
    doctrine_ships()[doctrine] || []
  end

  @doc """
  Identify primary doctrine for a fleet composition.
  """
  def identify_primary_doctrine(ship_list) do
    doctrine_scores =
      available_doctrines()
      |> Enum.map(fn doctrine ->
        ships_in_doctrine = Enum.count(ship_list, &doctrine_ship?(&1, doctrine))
        adherence_score = ships_in_doctrine / max(length(ship_list), 1)
        {doctrine, adherence_score, ships_in_doctrine}
      end)
      |> Enum.sort_by(fn {_, score, _} -> score end, :desc)

    case doctrine_scores do
      [{doctrine, score, count} | _] when score > 0.5 ->
        {:ok,
         %{
           doctrine: doctrine,
           adherence_score: score,
           ships_in_doctrine: count,
           total_ships: length(ship_list)
         }}

      [{doctrine, score, count} | _] when score > 0.3 ->
        {:partial,
         %{
           doctrine: doctrine,
           adherence_score: score,
           ships_in_doctrine: count,
           total_ships: length(ship_list)
         }}

      _ ->
        {:unknown,
         %{
           adherence_score: 0.0,
           ships_in_doctrine: 0,
           total_ships: length(ship_list)
         }}
    end
  end

  @doc """
  Calculate doctrine adherence score for a fleet.
  """
  def calculate_adherence_score(ship_list, doctrine) do
    ships_in_doctrine = Enum.count(ship_list, &doctrine_ship?(&1, doctrine))
    ships_in_doctrine / max(length(ship_list), 1)
  end

  @doc """
  Get suggested ships to complete a doctrine composition.
  """
  def suggest_doctrine_completion(current_ships, target_doctrine) do
    doctrine_ship_list = get_doctrine_ships(target_doctrine)
    current_roles = Enum.map(current_ships, &get_ship_role_from_name/1)

    missing_roles = identify_missing_roles(current_roles)

    suggestions =
      Enum.filter(doctrine_ship_list, fn ship ->
        role = get_ship_role_from_name(ship)
        role in missing_roles and ship not in current_ships
      end)
      |> Enum.take(5)

    %{
      suggested_ships: suggestions,
      missing_roles: missing_roles,
      current_adherence: calculate_adherence_score(current_ships, target_doctrine)
    }
  end

  # Private functions

  defp doctrine_ships do
    %{
      "armor_cruiser" => [
        "Legion",
        "Proteus",
        "Damnation",
        "Guardian",
        "Zealot",
        "Muninn",
        "Ares",
        "Crucifier"
      ],
      "armor" => [
        "Legion",
        "Proteus",
        "Damnation",
        "Guardian",
        "Zealot",
        "Muninn",
        "Ares",
        "Crucifier"
      ],
      "shield_cruiser" => [
        "Tengu",
        "Loki",
        "Nighthawk",
        "Scimitar",
        "Cerberus",
        "Eagle",
        "Stiletto",
        "Griffin"
      ],
      "shield" => [
        "Tengu",
        "Loki",
        "Nighthawk",
        "Scimitar",
        "Cerberus",
        "Eagle",
        "Stiletto",
        "Griffin"
      ],
      "unknown" => [],
      "mixed" => []
    }
  end

  defp get_ship_role_from_name(ship_name) do
    # Simple role mapping - in practice this would delegate to ShipRoleData
    role_map = %{
      "Damnation" => "fc",
      "Nighthawk" => "fc",
      "Claymore" => "fc",
      "Sleipnir" => "fc",
      "Legion" => "dps",
      "Proteus" => "dps",
      "Tengu" => "dps",
      "Loki" => "dps",
      "Muninn" => "dps",
      "Cerberus" => "dps",
      "Zealot" => "dps",
      "Eagle" => "dps",
      "Guardian" => "logistics",
      "Scimitar" => "logistics",
      "Basilisk" => "logistics",
      "Oneiros" => "logistics",
      "Ares" => "tackle",
      "Malediction" => "tackle",
      "Stiletto" => "tackle",
      "Crow" => "tackle",
      "Crucifier" => "ewar",
      "Maulus" => "ewar",
      "Vigil" => "ewar",
      "Griffin" => "ewar"
    }

    role_map[ship_name] || "unknown"
  end

  defp identify_missing_roles(current_roles) do
    role_counts = Enum.frequencies(current_roles)

    missing = []

    missing =
      if Map.get(role_counts, "logistics", 0) == 0, do: ["logistics" | missing], else: missing

    missing = if Map.get(role_counts, "tackle", 0) == 0, do: ["tackle" | missing], else: missing
    missing = if Map.get(role_counts, "dps", 0) < 3, do: ["dps" | missing], else: missing
    missing = if Map.get(role_counts, "ewar", 0) == 0, do: ["ewar" | missing], else: missing

    missing
  end
end
