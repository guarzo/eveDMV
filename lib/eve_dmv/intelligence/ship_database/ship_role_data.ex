defmodule EveDmv.Intelligence.ShipDatabase.ShipRoleData do
  @moduledoc """
  Ship role data and fleet composition utilities.

  Handles ship roles, fleet composition analysis, and optimal
  gang size calculations for tactical analysis.
  """

  @doc """
  Get ship role based on ship name.
  """
  def get_ship_role(ship_name) when is_binary(ship_name) do
    ship_roles()[ship_name] || "unknown"
  end

  @doc """
  Get optimal gang size for ship composition.
  """
  def optimal_gang_size(ship_composition) do
    roles = Enum.map(ship_composition, &get_ship_role/1)

    dps_count = Enum.count(roles, &(&1 == "dps"))
    logi_count = Enum.count(roles, &(&1 == "logistics"))

    cond do
      logi_count >= 2 && dps_count >= 5 -> 8
      logi_count >= 1 && dps_count >= 3 -> 5
      dps_count >= 2 -> 3
      true -> 1
    end
  end

  @doc """
  Analyze fleet composition and provide tactical insights.
  """
  def analyze_fleet_composition(ship_list) do
    roles = Enum.map(ship_list, &get_ship_role/1)
    role_counts = Enum.frequencies(roles)

    %{
      total_ships: length(ship_list),
      role_distribution: role_counts,
      dps_ships: Map.get(role_counts, "dps", 0),
      logistics_ships: Map.get(role_counts, "logistics", 0),
      tackle_ships: Map.get(role_counts, "tackle", 0),
      ewar_ships: Map.get(role_counts, "ewar", 0),
      fc_ships: Map.get(role_counts, "fc", 0),
      unknown_ships: Map.get(role_counts, "unknown", 0),
      optimal_size: optimal_gang_size(ship_list),
      composition_health: assess_composition_health(role_counts)
    }
  end

  @doc """
  Check if fleet composition is balanced for given activity.
  """
  def balanced_for_activity?(ship_composition, activity) do
    analysis = analyze_fleet_composition(ship_composition)

    case activity do
      :pvp ->
        analysis.logistics_ships >= 1 and
          analysis.dps_ships >= 3 and
          analysis.tackle_ships >= 1

      :pve ->
        analysis.dps_ships >= 2 and
          analysis.logistics_ships >= 1

      :roaming ->
        analysis.tackle_ships >= 1 and
          analysis.dps_ships >= 2

      :structure_bash ->
        analysis.dps_ships >= 5

      _ ->
        false
    end
  end

  # Private functions

  defp ship_roles do
    %{
      # Fleet Command
      "Damnation" => "fc",
      "Nighthawk" => "fc",
      "Claymore" => "fc",
      "Sleipnir" => "fc",

      # DPS
      "Legion" => "dps",
      "Proteus" => "dps",
      "Tengu" => "dps",
      "Loki" => "dps",
      "Muninn" => "dps",
      "Cerberus" => "dps",
      "Zealot" => "dps",
      "Eagle" => "dps",

      # Logistics
      "Guardian" => "logistics",
      "Scimitar" => "logistics",
      "Basilisk" => "logistics",
      "Oneiros" => "logistics",

      # Tackle
      "Ares" => "tackle",
      "Malediction" => "tackle",
      "Stiletto" => "tackle",
      "Crow" => "tackle",
      "Interceptor" => "tackle",

      # EWAR
      "Crucifier" => "ewar",
      "Maulus" => "ewar",
      "Vigil" => "ewar",
      "Griffin" => "ewar",

      # Common ships
      "Rifter" => "dps",
      "Punisher" => "dps",
      "Stabber" => "dps",
      "Drake" => "dps"
    }
  end

  defp assess_composition_health(role_counts) do
    dps = Map.get(role_counts, "dps", 0)
    logi = Map.get(role_counts, "logistics", 0)
    tackle = Map.get(role_counts, "tackle", 0)
    total = Enum.sum(Map.values(role_counts))

    cond do
      total == 0 ->
        "empty"

      logi == 0 and dps > 3 ->
        "no_logistics"

      tackle == 0 and dps > 2 ->
        "no_tackle"

      logi >= 2 and dps >= 5 and tackle >= 1 ->
        "excellent"

      logi >= 1 and dps >= 3 ->
        "good"

      dps >= 2 ->
        "minimal"

      true ->
        "poor"
    end
  end
end
