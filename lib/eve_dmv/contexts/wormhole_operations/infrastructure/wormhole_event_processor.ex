defmodule EveDmv.Contexts.WormholeOperations.Infrastructure.WormholeEventProcessor do
  @moduledoc """
  Wormhole event processing infrastructure.

  Processes incoming events from other contexts and initiates wormhole-specific
  analysis including character vetting, threat assessment, and fleet optimization.
  """

  alias EveDmv.Contexts.WormholeOperations.Domain.RecruitmentVetter
  alias EveDmv.Contexts.WormholeOperations.Domain.HomeDefenseAnalyzer
  alias EveDmv.Contexts.WormholeOperations.Domain.MassOptimizer

  require Logger

  # Ship type IDs for role detection (more reliable than string matching)
  @logistics_ship_ids [
    # T2 Logistics Cruisers
    # Guardian (Amarr)
    11_985,
    # Basilisk (Caldari) 
    11_987,
    # Oneiros (Gallente)
    11_989,
    # Scimitar (Minmatar)
    12_003,
    # T1 Logistics Cruisers
    # Augoror (Amarr)
    11_978,
    # Osprey (Caldari)
    11_982,
    # Exequror (Gallente)
    11_979,
    # Scythe (Minmatar)
    11_993,
    # Logistics Frigates
    # Inquisitor (Amarr)
    32_788,
    # Bantam (Caldari)
    32_790,
    # Navitas (Gallente)
    32_789,
    # Burst (Minmatar)
    32_791
  ]

  @scanner_ship_ids [
    # Covert Ops Frigates
    # Anathema (Amarr)
    11_940,
    # Buzzard (Caldari)
    11_939,
    # Helios (Gallente)
    11_941,
    # Cheetah (Minmatar)
    11_942,
    # Sisters of EVE Exploration Ships
    # Astero
    33_468,
    # Stratios
    33_470,
    # T3 Cruisers with scanning subsystems (simplified - would need subsystem detection)
    # Legion (with scanning subsystem)
    29_984,
    # Tengu (with scanning subsystem)
    29_986,
    # Proteus (with scanning subsystem)
    29_988,
    # Loki (with scanning subsystem)
    29_990
  ]

  @tackle_ship_ids [
    # Interdictors
    # Sabre (Minmatar)
    22_456,
    # Flycatcher (Caldari)
    22_452,
    # Eris (Gallente)
    22_448,
    # Heretic (Amarr)
    22_460,
    # Heavy Interdictors
    # Broadsword (Minmatar)
    12_011,
    # Onyx (Caldari)
    12_013,
    # Phobos (Gallente)
    12_009,
    # Devoter (Amarr)
    12_015,
    # Interceptors
    # Stiletto (Minmatar)
    11_172,
    # Crow (Caldari)
    11_174,
    # Ares (Gallente)
    11_176,
    # Malediction (Amarr)
    11_182,
    # Claw (Minmatar)
    11_184,
    # Raptor (Caldari)
    11_186,
    # Taranis (Gallente)
    11_188,
    # Crusader (Amarr)
    11_192
  ]

  @dps_ship_ids [
    # Strategic Cruisers
    # Legion
    29_984,
    # Tengu
    29_986,
    # Proteus
    29_988,
    # Loki
    29_990,
    # Heavy Assault Cruisers
    # Sacrilege (Amarr)
    12_003,
    # Cerberus (Caldari)
    12_005,
    # Ishtar (Gallente)
    11_993,
    # Vagabond (Minmatar)
    11_995,
    # Zealot (Amarr)
    12_023,
    # Eagle (Caldari)
    12_019,
    # Deimos (Gallente)
    12_021,
    # Muninn (Minmatar)
    12_017,
    # Battleships (simplified selection)
    # Apocalypse (Amarr)
    638,
    # Armageddon (Amarr)
    640,
    # Abaddon (Amarr)
    642,
    # Scorpion (Caldari)
    639,
    # Raven (Caldari)
    641,
    # Rokh (Caldari)
    643,
    # Megathron (Gallente)
    645,
    # Dominix (Gallente)
    644,
    # Hyperion (Gallente)
    646,
    # Tempest (Minmatar)
    647,
    # Typhoon (Minmatar)
    648,
    # Maelstrom (Minmatar)
    24_692
  ]

  def process_character_for_wormhole_vetting(%{character_id: character_id}) do
    Logger.info("Processing character #{character_id} for wormhole vetting")

    # Define default wormhole vetting criteria
    vetting_criteria = %{
      min_overall_score: 0.6,
      max_risk_score: 0.4,
      require_wormhole_experience: true,
      min_character_age_days: 30
    }

    # Initiate vetting analysis
    case RecruitmentVetter.perform_vetting_analysis(character_id, vetting_criteria) do
      {:ok, vetting_report} ->
        Logger.info(
          "Wormhole vetting completed for character #{character_id}: #{vetting_report.recommendation}"
        )

        {:ok,
         %{
           character_id: character_id,
           vetting_report: vetting_report,
           processed_at: DateTime.utc_now()
         }}

      {:error, reason} ->
        Logger.error("Failed to vet character #{character_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def process_threat_for_home_defense(%{threat_id: threat_id, system_id: system_id} = event) do
    Logger.info("Processing threat #{threat_id} for home defense in system #{system_id}")

    # Analyze defense capabilities for the threatened system
    case HomeDefenseAnalyzer.analyze_system_defense(system_id) do
      {:ok, defense_analysis} ->
        # Determine alert level based on threat severity and defense readiness
        alert_level = determine_alert_level(event, defense_analysis)

        # Generate defense recommendations
        recommendations =
          HomeDefenseAnalyzer.generate_defense_recommendations(
            system_id,
            defense_analysis,
            event
          )

        result = %{
          threat_id: threat_id,
          system_id: system_id,
          alert_level: alert_level,
          defense_readiness: defense_analysis.readiness_score,
          vulnerabilities: defense_analysis.vulnerabilities,
          recommendations: recommendations,
          processed_at: DateTime.utc_now()
        }

        # Log high severity alerts
        if alert_level in [:critical, :high] do
          Logger.warning("High severity threat detected in system #{system_id}: #{alert_level}")
        end

        {:ok, result}

      {:error, reason} ->
        Logger.error("Failed to analyze home defense for system #{system_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def process_fleet_for_wormhole_ops(%{fleet_id: fleet_id, fleet_data: fleet_data} = event) do
    Logger.info("Processing fleet #{fleet_id} for wormhole operations")

    # Extract target wormhole class from event or default to C5
    wormhole_class = Map.get(event, :target_wormhole_class, "C5")

    # Optimize fleet for wormhole mass constraints
    case MassOptimizer.optimize_fleet_composition(fleet_data, wormhole_class) do
      {:ok, optimization_result} ->
        # Check if fleet meets doctrine requirements
        doctrine_compliance = check_doctrine_compliance(fleet_data, wormhole_class)

        result = %{
          fleet_id: fleet_id,
          wormhole_class: wormhole_class,
          optimization: optimization_result,
          doctrine_compliance: doctrine_compliance,
          mass_efficiency: optimization_result.mass_efficiency,
          recommendations: optimization_result.recommendations,
          processed_at: DateTime.utc_now()
        }

        {:ok, result}

      {:error, reason} ->
        Logger.error("Failed to optimize fleet #{fleet_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Private helper functions

  defp determine_alert_level(%{severity: severity} = _threat_event, defense_analysis) do
    readiness = defense_analysis.readiness_score

    cond do
      severity == :critical and readiness < 0.5 -> :critical
      severity == :high and readiness < 0.6 -> :high
      severity == :medium and readiness < 0.7 -> :medium
      severity == :low or readiness > 0.8 -> :low
      true -> :medium
    end
  end

  defp check_doctrine_compliance(fleet_data, wormhole_class) do
    # Check for essential wormhole doctrine ships
    essential_roles = ["logistics", "scanner", "tackle", "dps"]

    covered_roles =
      Enum.filter(essential_roles, fn role ->
        Enum.any?(fleet_data.ships, fn ship ->
          ship_fills_role?(ship, role, wormhole_class)
        end)
      end)

    %{
      compliant: length(covered_roles) == length(essential_roles),
      covered_roles: covered_roles,
      missing_roles: essential_roles -- covered_roles,
      compliance_score: length(covered_roles) / length(essential_roles)
    }
  end

  defp ship_fills_role?(ship, role, _wormhole_class) do
    # Robust role detection based on ship type IDs (more reliable than string matching)
    case role do
      "logistics" ->
        ship.type_id in @logistics_ship_ids

      "scanner" ->
        ship.type_id in @scanner_ship_ids

      "tackle" ->
        ship.type_id in @tackle_ship_ids

      "dps" ->
        # Check if ship is in DPS ship list OR has damage output
        ship.type_id in @dps_ship_ids or (ship.damage_output && ship.damage_output > 0)

      _ ->
        false
    end
  end
end
