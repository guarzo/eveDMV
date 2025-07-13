defmodule EveDmv.Analytics.ModuleClassifier do
  @moduledoc """
  Module classification engine for ship role analysis.

  This module analyzes fitted modules from killmail data to classify ship roles
  with confidence scoring. It uses pattern matching against known module types
  to determine primary and secondary roles for ships in fleet engagements.

  ## Role Classifications

  - **Tackle**: Scramblers, disruptors, webs, interdiction
  - **Logistics**: Remote reps, cap transfers, triage modules  
  - **EWAR**: ECM, damps, painters, neuts
  - **DPS**: Weapons, damage amplifiers
  - **Command**: Command bursts, warfare links
  - **Support**: Utility modules, specialized equipment

  ## Confidence Scoring

  Role confidence is calculated based on:
  - Module pattern matches (0.0-1.0 per module)
  - Module count and strength
  - Ship class appropriateness
  - Overall fitting coherence
  """

  alias EveDmv.Intelligence.ShipDatabase

  @type role :: :tackle | :logistics | :ewar | :dps | :command | :support
  @type confidence :: float()
  @type module_classification :: %{
          role => confidence()
        }

  @doc """
  Classify ship role from killmail raw data.

  Returns a map of roles to confidence scores (0.0-1.0).
  """
  @spec classify_ship_role(map()) :: module_classification()
  def classify_ship_role(killmail_data) do
    victim_items = get_victim_fitting_items(killmail_data)
    ship_type_id = get_victim_ship_type_id(killmail_data)

    modules_by_slot = group_modules_by_slot(victim_items)

    base_classification = %{
      tackle: 0.0,
      logistics: 0.0,
      ewar: 0.0,
      dps: 0.0,
      command: 0.0,
      support: 0.0
    }

    base_classification
    |> classify_high_slot_modules(modules_by_slot.high_slots)
    |> classify_mid_slot_modules(modules_by_slot.mid_slots)
    |> classify_low_slot_modules(modules_by_slot.low_slots)
    |> classify_rig_modules(modules_by_slot.rig_slots)
    |> apply_ship_class_adjustments(ship_type_id)
    |> normalize_confidence_scores()
  end

  @doc """
  Analyze module patterns for detailed role breakdown.

  Returns detailed analysis including:
  - Primary role (highest confidence)
  - Secondary roles (above threshold)
  - Module breakdown by category
  - Ship appropriateness score
  """
  @spec analyze_module_patterns(map()) :: %{
          primary_role: role(),
          secondary_roles: [role()],
          role_scores: module_classification(),
          module_breakdown: map(),
          ship_appropriateness: float(),
          analysis_metadata: map()
        }
  def analyze_module_patterns(killmail_data) do
    role_scores = classify_ship_role(killmail_data)
    victim_items = get_victim_fitting_items(killmail_data)
    ship_type_id = get_victim_ship_type_id(killmail_data)

    primary_role = determine_primary_role(role_scores)
    secondary_roles = determine_secondary_roles(role_scores, primary_role)

    module_breakdown = categorize_modules(victim_items)
    ship_appropriateness = calculate_ship_appropriateness(role_scores, ship_type_id)

    %{
      primary_role: primary_role,
      secondary_roles: secondary_roles,
      role_scores: role_scores,
      module_breakdown: module_breakdown,
      ship_appropriateness: ship_appropriateness,
      analysis_metadata: %{
        module_count: length(victim_items),
        ship_type_id: ship_type_id,
        ship_class: ShipDatabase.get_ship_class(ship_type_id),
        ship_category: ShipDatabase.get_ship_category(ship_type_id),
        analyzed_at: DateTime.utc_now()
      }
    }
  end

  # Private helper functions

  defp get_victim_fitting_items(killmail_data) do
    case killmail_data do
      %{"victim" => %{"items" => items}} when is_list(items) -> items
      %{victim: %{items: items}} when is_list(items) -> items
      _ -> []
    end
  end

  defp get_victim_ship_type_id(killmail_data) do
    case killmail_data do
      %{"victim" => %{"ship_type_id" => type_id}} -> type_id
      %{victim: %{ship_type_id: type_id}} -> type_id
      _ -> 0
    end
  end

  defp group_modules_by_slot(items) do
    items_by_flag = Enum.group_by(items, &get_item_flag/1)

    %{
      high_slots: extract_slot_items(items_by_flag, 27..34),
      mid_slots: extract_slot_items(items_by_flag, 19..26),
      low_slots: extract_slot_items(items_by_flag, 11..18),
      rig_slots: extract_slot_items(items_by_flag, 92..94),
      subsystem_slots: extract_slot_items(items_by_flag, 125..132)
    }
  end

  defp get_item_flag(item) do
    case item do
      %{"flag" => flag} -> flag
      %{flag: flag} -> flag
      _ -> 0
    end
  end

  defp extract_slot_items(items_by_flag, slot_range) do
    slot_range
    |> Enum.flat_map(fn slot -> Map.get(items_by_flag, slot, []) end)
    |> Enum.map(&extract_module_info/1)
  end

  defp extract_module_info(item) do
    %{
      type_id: get_item_value(item, "type_id") || get_item_value(item, :type_id) || 0,
      type_name:
        get_item_value(item, "type_name") || get_item_value(item, :type_name) || "Unknown",
      quantity: get_item_value(item, "quantity") || get_item_value(item, :quantity) || 1
    }
  end

  defp get_item_value(item, key) do
    case item do
      %{^key => value} -> value
      _ -> nil
    end
  end

  # Role classification by slot type

  defp classify_high_slot_modules(classification, high_slots) do
    Enum.reduce(high_slots, classification, fn module, acc ->
      module_name = String.downcase(module.type_name)

      cond do
        # DPS modules
        is_weapon_module?(module_name) ->
          update_role_confidence(acc, :dps, 0.8)

        # Remote repair modules (logistics)
        is_remote_repair_module?(module_name) ->
          update_role_confidence(acc, :logistics, 0.9)

        # Utility/support modules
        is_utility_module?(module_name) ->
          update_role_confidence(acc, :support, 0.4)

        true ->
          acc
      end
    end)
  end

  defp classify_mid_slot_modules(classification, mid_slots) do
    Enum.reduce(mid_slots, classification, fn module, acc ->
      module_name = String.downcase(module.type_name)

      cond do
        # Tackle modules
        is_tackle_module?(module_name) ->
          update_role_confidence(acc, :tackle, 0.8)

        # EWAR modules
        is_ewar_module?(module_name) ->
          update_role_confidence(acc, :ewar, 0.7)

        # Shield logistics
        is_shield_logistics_module?(module_name) ->
          update_role_confidence(acc, :logistics, 0.8)

        # Command modules
        is_command_module?(module_name) ->
          update_role_confidence(acc, :command, 0.6)

        # Support modules
        is_support_module?(module_name) ->
          update_role_confidence(acc, :support, 0.3)

        true ->
          acc
      end
    end)
  end

  defp classify_low_slot_modules(classification, low_slots) do
    Enum.reduce(low_slots, classification, fn module, acc ->
      module_name = String.downcase(module.type_name)

      cond do
        # DPS enhancement modules
        is_damage_module?(module_name) ->
          update_role_confidence(acc, :dps, 0.6)

        # Armor logistics
        is_armor_logistics_module?(module_name) ->
          update_role_confidence(acc, :logistics, 0.8)

        # Support/tank modules
        is_tank_module?(module_name) ->
          update_role_confidence(acc, :support, 0.2)

        true ->
          acc
      end
    end)
  end

  defp classify_rig_modules(classification, rig_slots) do
    Enum.reduce(rig_slots, classification, fn module, acc ->
      module_name = String.downcase(module.type_name)

      cond do
        # DPS enhancement rigs
        is_dps_rig?(module_name) ->
          update_role_confidence(acc, :dps, 0.3)

        # Tank/support rigs
        is_tank_rig?(module_name) ->
          update_role_confidence(acc, :support, 0.2)

        # Logistics rigs
        is_logistics_rig?(module_name) ->
          update_role_confidence(acc, :logistics, 0.4)

        true ->
          acc
      end
    end)
  end

  # Module pattern matching functions

  defp is_weapon_module?(module_name) do
    weapon_patterns = [
      "launcher",
      "turret",
      "laser",
      "railgun",
      "autocannon",
      "artillery",
      "blaster",
      "beam",
      "pulse",
      "howitzer",
      "cannon",
      "torpedo",
      "missile",
      "rocket",
      "bomb",
      "smartbomb"
    ]

    Enum.any?(weapon_patterns, &String.contains?(module_name, &1))
  end

  defp is_remote_repair_module?(module_name) do
    remote_repair_patterns = [
      "remote armor repairer",
      "remote shield booster",
      "remote hull repairer",
      "remote capacitor transmitter",
      "triage",
      "capital remote"
    ]

    Enum.any?(remote_repair_patterns, &String.contains?(module_name, &1))
  end

  defp is_tackle_module?(module_name) do
    tackle_patterns = [
      "warp scrambler",
      "warp disruptor",
      "stasis webifier",
      "heavy interdictor",
      "bubble",
      "interdiction sphere",
      "focused warp disruptor",
      "faction warp scrambler"
    ]

    Enum.any?(tackle_patterns, &String.contains?(module_name, &1))
  end

  defp is_ewar_module?(module_name) do
    ewar_patterns = [
      "ecm",
      "sensor dampener",
      "tracking disruptor",
      "target painter",
      "energy neutralizer",
      "energy vampire",
      "guidance disruptor",
      "remote sensor dampener",
      "signal amplifier"
    ]

    Enum.any?(ewar_patterns, &String.contains?(module_name, &1))
  end

  defp is_shield_logistics_module?(module_name) do
    shield_logi_patterns = [
      "large shield transporter",
      "medium shield transporter",
      "capital shield transporter",
      "ancillary shield"
    ]

    Enum.any?(shield_logi_patterns, &String.contains?(module_name, &1))
  end

  defp is_armor_logistics_module?(module_name) do
    armor_logi_patterns = [
      "large armor repairer",
      "medium armor repairer",
      "capital armor repairer",
      "ancillary armor"
    ]

    Enum.any?(armor_logi_patterns, &String.contains?(module_name, &1))
  end

  defp is_command_module?(module_name) do
    command_patterns = [
      "command burst",
      "warfare link",
      "gang assist",
      "command processor",
      "mindlink"
    ]

    Enum.any?(command_patterns, &String.contains?(module_name, &1))
  end

  defp is_damage_module?(module_name) do
    damage_patterns = [
      "gyrostabilizer",
      "heat sink",
      "magnetic field stabilizer",
      "ballistic control system",
      "damage control",
      "overdrive",
      "tracking enhancer",
      "tracking computer"
    ]

    Enum.any?(damage_patterns, &String.contains?(module_name, &1))
  end

  defp is_utility_module?(module_name) do
    utility_patterns = [
      "probe launcher",
      "cynosural field",
      "jump drive",
      "cloaking device",
      "cargo scanner",
      "data analyzer"
    ]

    Enum.any?(utility_patterns, &String.contains?(module_name, &1))
  end

  defp is_support_module?(module_name) do
    support_patterns = [
      "afterburner",
      "microwarpdrive",
      "shield extender",
      "armor plate",
      "resistance",
      "hardener",
      "amplifier"
    ]

    Enum.any?(support_patterns, &String.contains?(module_name, &1))
  end

  defp is_tank_module?(module_name) do
    tank_patterns = [
      "armor plate",
      "shield extender",
      "hardener",
      "resistance",
      "adaptive",
      "energized",
      "membrane",
      "coating"
    ]

    Enum.any?(tank_patterns, &String.contains?(module_name, &1))
  end

  defp is_dps_rig?(module_name) do
    dps_rig_patterns = [
      "burst aerator",
      "collision accelerator",
      "discharge elutriation",
      "hybridization",
      "warhead",
      "semiconductor"
    ]

    Enum.any?(dps_rig_patterns, &String.contains?(module_name, &1))
  end

  defp is_tank_rig?(module_name) do
    tank_rig_patterns = [
      "trimark",
      "core defense",
      "anti-em",
      "anti-thermal",
      "anti-kinetic",
      "anti-explosive",
      "shield",
      "armor"
    ]

    Enum.any?(tank_rig_patterns, &String.contains?(module_name, &1))
  end

  defp is_logistics_rig?(module_name) do
    logistics_rig_patterns = [
      "repair",
      "remote",
      "capacitor",
      "energy",
      "ancillary"
    ]

    Enum.any?(logistics_rig_patterns, &String.contains?(module_name, &1))
  end

  # Confidence scoring and normalization

  defp update_role_confidence(classification, role, confidence_increase) do
    current_confidence = Map.get(classification, role, 0.0)
    new_confidence = min(1.0, current_confidence + confidence_increase)
    Map.put(classification, role, new_confidence)
  end

  defp apply_ship_class_adjustments(classification, ship_type_id) do
    ship_class = ShipDatabase.get_ship_class(ship_type_id)
    ship_category = ShipDatabase.get_ship_category(ship_type_id)

    case {ship_class, ship_category} do
      {:logistics, _} ->
        # Dedicated logistics ships get logistics boost
        update_role_confidence(classification, :logistics, 0.5)

      {:command_ship, _} ->
        # Command ships get command boost
        update_role_confidence(classification, :command, 0.6)

      {:interceptor, _} ->
        # Interceptors get tackle boost
        update_role_confidence(classification, :tackle, 0.4)

      {_, "Capital"} ->
        # Capitals are usually DPS or logistics
        classification
        |> update_role_confidence(:dps, 0.2)
        |> update_role_confidence(:logistics, 0.1)

      {_, "Frigate"} ->
        # Frigates often tackle or support
        classification
        |> update_role_confidence(:tackle, 0.2)
        |> update_role_confidence(:support, 0.1)

      _ ->
        classification
    end
  end

  defp normalize_confidence_scores(classification) do
    # Ensure no role exceeds 1.0 confidence
    Enum.map(classification, fn {role, confidence} ->
      {role, min(1.0, confidence)}
    end)
    |> Enum.into(%{})
  end

  defp determine_primary_role(role_scores) do
    {primary_role, _score} = Enum.max_by(role_scores, fn {_role, score} -> score end)
    primary_role
  end

  defp determine_secondary_roles(role_scores, primary_role) do
    secondary_threshold = 0.3

    role_scores
    |> Enum.filter(fn {role, score} -> role != primary_role and score >= secondary_threshold end)
    |> Enum.sort_by(fn {_role, score} -> score end, :desc)
    |> Enum.map(fn {role, _score} -> role end)
  end

  defp categorize_modules(items) do
    Enum.reduce(
      items,
      %{weapons: 0, tank: 0, ewar: 0, tackle: 0, logistics: 0, support: 0},
      fn item, acc ->
        module_name =
          String.downcase(
            get_item_value(item, "type_name") || get_item_value(item, :type_name) || ""
          )

        cond do
          is_weapon_module?(module_name) -> Map.update!(acc, :weapons, &(&1 + 1))
          is_tank_module?(module_name) -> Map.update!(acc, :tank, &(&1 + 1))
          is_ewar_module?(module_name) -> Map.update!(acc, :ewar, &(&1 + 1))
          is_tackle_module?(module_name) -> Map.update!(acc, :tackle, &(&1 + 1))
          is_remote_repair_module?(module_name) -> Map.update!(acc, :logistics, &(&1 + 1))
          true -> Map.update!(acc, :support, &(&1 + 1))
        end
      end
    )
  end

  defp calculate_ship_appropriateness(role_scores, ship_type_id) do
    ship_class = ShipDatabase.get_ship_class(ship_type_id)
    ship_category = ShipDatabase.get_ship_category(ship_type_id)
    primary_role = determine_primary_role(role_scores)

    # Calculate how appropriate the ship is for its detected role
    base_appropriateness =
      case {ship_class, primary_role} do
        {:logistics, :logistics} -> 1.0
        {:command_ship, :command} -> 1.0
        {:interceptor, :tackle} -> 0.9
        {_, :dps} when ship_category in ["Battleship", "Cruiser", "Battlecruiser"] -> 0.8
        {_, :tackle} when ship_category == "Frigate" -> 0.8
        {_, :ewar} when ship_category == "Cruiser" -> 0.7
        _ -> 0.5
      end

    # Adjust based on role distribution
    primary_confidence = Map.get(role_scores, primary_role, 0.0)
    base_appropriateness * primary_confidence
  end
end
