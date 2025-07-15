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

  def process_character_for_wormhole_vetting(%{character_id: character_id} = _event) do
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
          recommendations: optimization_result.suggestions,
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
    # Simplified role detection based on ship type
    case role do
      "logistics" ->
        String.contains?(String.downcase(ship.type_name || ""), [
          "guardian",
          "basilisk",
          "oneiros",
          "scimitar"
        ])

      "scanner" ->
        String.contains?(String.downcase(ship.type_name || ""), [
          "astero",
          "helios",
          "buzzard",
          "cheetah",
          "anathema"
        ])

      "tackle" ->
        String.contains?(String.downcase(ship.type_name || ""), [
          "sabre",
          "flycatcher",
          "eris",
          "heretic",
          "devoter",
          "phobos",
          "broadsword",
          "onyx"
        ])

      "dps" ->
        ship.damage_output && ship.damage_output > 0

      _ ->
        false
    end
  end
end
