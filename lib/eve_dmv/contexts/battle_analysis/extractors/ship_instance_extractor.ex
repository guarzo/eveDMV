defmodule EveDmv.Contexts.BattleAnalysis.Extractors.ShipInstanceExtractor do
  @moduledoc """
  Extracts ship instance data from battle information for performance analysis.

  Handles the complex process of identifying all ships that participated in a battle,
  extracting their combat context, and creating normalized ship instance records
  for both victims and attackers.
  """

  require Logger

  @doc """
  Extracts ship instances from battle data.

  Creates ship instance records from both victims and attackers,
  removing duplicates and adding battle context.
  """
  def extract_ship_instances(battle) do
    # Create ship instance records from BOTH victims AND attackers
    victims = Enum.flat_map(battle.killmails, &create_victim_ship_instance/1)
    attackers = Enum.flat_map(battle.killmails, &create_attacker_ship_instances/1)

    all_instances = victims ++ attackers

    # Remove duplicates (same character_id + ship_type_id combo)
    unique_instances =
      Enum.uniq_by(all_instances, fn instance ->
        # Remove attackers who are already in victims (they died later)
        {instance.character_id, instance.ship_type_id}
      end)

    # Filter out duplicates where attackers appear as victims later
    filtered_instances = remove_duplicate_attacker_victims(unique_instances, victims)

    # Add battle context to each instance
    enhanced_instances = Enum.map(filtered_instances, &extract_battle_context(battle, &1))

    {:ok, enhanced_instances}
  rescue
    error ->
      Logger.error("Failed to extract ship instances: #{inspect(error)}")
      {:error, :extraction_failed}
  end

  @doc """
  Creates ship instance data for victims from killmail.
  """
  def create_victim_ship_instance(killmail) do
    # Extract comprehensive ship instance data
    victim = killmail["victim"]

    [
      %{
        character_id: victim["character_id"],
        character_name: victim["character_name"],
        corporation_id: victim["corporation_id"],
        alliance_id: victim["alliance_id"],
        ship_type_id: victim["ship_type_id"],
        ship_name: get_ship_name(victim["ship_type_id"]),
        # Combat context
        death_time: killmail["killmail_time"],
        damage_taken: calculate_total_damage_taken(killmail),
        final_blow: extract_final_blow_data(killmail),
        attackers: extract_attacker_data(killmail),
        # Ship characteristics (estimated from type)
        ship_class: determine_ship_class(victim["ship_type_id"]),
        estimated_fitting: estimate_ship_fitting(killmail),
        theoretical_stats: get_theoretical_ship_stats(victim["ship_type_id"])
      }
    ]
  end

  @doc """
  Creates ship instance data for attackers from killmail.
  """
  def create_attacker_ship_instances(killmail) do
    # Extract ship instances for all attackers who participated
    attackers = killmail["attackers"] || []

    attackers
    |> Enum.filter(fn attacker ->
      # Only include attackers with character_id and ship_type_id
      attacker["character_id"] != nil &&
        attacker["ship_type_id"] != nil &&
        attacker["ship_type_id"] != 0
    end)
    |> Enum.map(fn attacker ->
      %{
        character_id: attacker["character_id"],
        character_name: attacker["character_name"],
        corporation_id: attacker["corporation_id"],
        alliance_id: attacker["alliance_id"],
        ship_type_id: attacker["ship_type_id"],
        ship_name: get_ship_name(attacker["ship_type_id"]),
        # Attackers survived this engagement
        death_time: nil,
        damage_taken: 0,
        # Combat context - their performance in this kill
        damage_dealt: attacker["damage_done"] || 0,
        final_blow: attacker["final_blow"] || false,
        weapon_type_id: attacker["weapon_type_id"],
        # Ship characteristics (estimated from type)
        ship_class: determine_ship_class(attacker["ship_type_id"]),
        estimated_fitting: estimate_ship_fitting_from_attacker(attacker),
        theoretical_stats: get_theoretical_ship_stats(attacker["ship_type_id"])
      }
    end)
  end

  # Private helper functions

  defp extract_battle_context(battle, ship_instance) do
    Map.put(ship_instance, :battle_context, %{
      battle_id: battle.battle_id,
      battle_duration: battle.metadata.duration_minutes,
      total_participants: length(battle._participants),
      isk_destroyed: battle.metadata.total_value
    })
  end

  defp extract_attacker_data(killmail) do
    (killmail["attackers"] || [])
    |> Enum.map(fn attacker ->
      %{
        character_id: attacker["character_id"],
        ship_type_id: attacker["ship_type_id"],
        damage_done: attacker["damage_done"] || 0,
        weapon_type_id: attacker["weapon_type_id"],
        final_blow: attacker["final_blow"] || false
      }
    end)
  end

  defp extract_final_blow_data(killmail) do
    final_blow_attacker = Enum.find(killmail["attackers"] || [], & &1["final_blow"])
    final_blow_attacker || %{}
  end

  defp calculate_total_damage_taken(killmail) do
    killmail["victim"]["damage_taken"] || 0
  end

  defp determine_ship_class(ship_type_id) do
    # Simplified ship class determination
    case ship_type_id do
      id when id in 587..591 -> "Frigate"
      id when id in 592..596 -> "Destroyer"
      id when id in 597..601 -> "Cruiser"
      id when id in 602..606 -> "Battlecruiser"
      id when id in 607..611 -> "Battleship"
      id when id in 324..358 -> "Capsule"
      _ -> "Unknown"
    end
  end

  defp estimate_ship_fitting(killmail) do
    victim = killmail["victim"]
    items = victim["items"] || []

    %{
      high_slots: filter_items_by_flag(items, [27, 28, 29, 30, 31, 32, 33, 34]),
      mid_slots: filter_items_by_flag(items, [19, 20, 21, 22, 23, 24, 25, 26]),
      low_slots: filter_items_by_flag(items, [11, 12, 13, 14, 15, 16, 17, 18]),
      rig_slots: filter_items_by_flag(items, [92, 93, 94]),
      estimated_value: calculate_fitting_value(items)
    }
  end

  defp estimate_ship_fitting_from_attacker(attacker) do
    # Estimate fitting based on weapon type and ship type
    weapon_type_id = attacker["weapon_type_id"]
    ship_type_id = attacker["ship_type_id"]

    %{
      estimated_role: estimate_role_from_ship_and_weapon(ship_type_id, weapon_type_id),
      high_slots: estimate_high_slots(weapon_type_id),
      mid_slots: [],
      low_slots: [],
      rig_slots: [],
      estimated_value: 0
    }
  end

  defp filter_items_by_flag(items, flags) do
    Enum.filter(items, fn item ->
      item["flag"] in flags
    end)
  end

  defp calculate_fitting_value(items) do
    # Simplified value calculation
    Enum.reduce(items, 0, fn item, acc ->
      acc + (item["quantity_dropped"] || 0) + (item["quantity_destroyed"] || 0)
    end)
  end

  defp get_theoretical_ship_stats(ship_type_id) do
    # Simplified theoretical stats based on ship type
    %{
      base_hp: get_base_hp(ship_type_id),
      expected_dps: get_expected_dps(ship_type_id),
      expected_survival_time: get_expected_survival_time(ship_type_id),
      mobility_class: get_mobility_class(ship_type_id),
      role_effectiveness_baseline: 1.0
    }
  end

  defp get_base_hp(ship_type_id) do
    # Ship class based HP estimates
    case determine_ship_class(ship_type_id) do
      "Frigate" -> 2500
      "Destroyer" -> 3500
      "Cruiser" -> 7500
      "Battlecruiser" -> 15000
      "Battleship" -> 25000
      "Capsule" -> 500
      _ -> 5000
    end
  end

  defp get_expected_dps(ship_type_id) do
    # Ship class based DPS estimates
    case determine_ship_class(ship_type_id) do
      "Frigate" -> 200
      "Destroyer" -> 300
      "Cruiser" -> 400
      "Battlecruiser" -> 600
      "Battleship" -> 800
      "Capsule" -> 0
      _ -> 300
    end
  end

  defp get_expected_survival_time(ship_type_id) do
    # Ship class based survival time estimates (seconds)
    case determine_ship_class(ship_type_id) do
      "Frigate" -> 30
      "Destroyer" -> 45
      "Cruiser" -> 90
      "Battlecruiser" -> 180
      "Battleship" -> 300
      "Capsule" -> 5
      _ -> 60
    end
  end

  defp get_mobility_class(ship_type_id) do
    # Ship class based mobility
    case determine_ship_class(ship_type_id) do
      "Frigate" -> "high"
      "Destroyer" -> "high"
      "Cruiser" -> "medium"
      "Battlecruiser" -> "low"
      "Battleship" -> "low"
      "Capsule" -> "very_high"
      _ -> "medium"
    end
  end

  defp get_ship_name(ship_type_id) do
    # Use name resolver if available, fallback to type ID
    # TODO: Implement EveDmv.Eve.NameResolver.resolve_type_id/1
    # EveDmv.Eve.NameResolver.resolve_type_id(ship_type_id) do
    case {:error, :not_implemented} do
      {:ok, name} -> name
      _ -> "Unknown Ship (#{ship_type_id})"
    end
  end

  defp remove_duplicate_attacker_victims(instances, victims) do
    victim_character_ids = MapSet.new(victims, & &1.character_id)

    Enum.reject(instances, fn instance ->
      # Remove attackers who appear as victims (they died later in the battle)
      instance.death_time == nil && MapSet.member?(victim_character_ids, instance.character_id)
    end)
  end

  defp estimate_role_from_ship_and_weapon(_ship_type_id, weapon_type_id) do
    # Simple role estimation based on weapon type
    cond do
      weapon_type_id == nil -> "Unknown"
      # Missile launchers
      weapon_type_id in 2410..2488 -> "DPS"
      # Turrets
      weapon_type_id in 2929..2969 -> "DPS"
      # Tackle modules
      weapon_type_id in 3520..3540 -> "Tackle"
      # Remote reps
      weapon_type_id in 3244..3246 -> "Logistics"
      true -> "Support"
    end
  end

  defp estimate_high_slots(weapon_type_id) when is_nil(weapon_type_id), do: []

  defp estimate_high_slots(weapon_type_id) do
    # Estimate high slot modules based on weapon
    [%{type_id: weapon_type_id, quantity: 1}]
  end
end
