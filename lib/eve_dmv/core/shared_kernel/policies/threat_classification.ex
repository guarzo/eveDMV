defmodule EveDmv.Core.SharedKernel.Policies.ThreatClassification do
  @moduledoc """
  Shared domain policy for classifying threat levels across the application.

  This policy provides consistent threat classification logic that can be
  used by different bounded contexts for threat assessment, alerting,
  and prioritization.
  """
  """

  alias EveDmv.Core.SharedKernel.ValueObjects.IskAmount

  @type threat_level :: :minimal | :low | :moderate | :high | :critical | :extreme

  @type threat_factors :: %{
          # 0.0 - 1.0
          combat_capability: float(),
          # Number of participants
          fleet_size: integer(),
          # Primary ship types
          ship_classes: [String.t()],
          # Total ISK value
          isk_value: IskAmount.t(),
          # :solo, :small_gang, :fleet, :capital
          activity_pattern: atom(),
          # :highsec, :lowsec, :nullsec, :wormhole
          security_class: atom(),
          # 0.0 - 1.0
          historical_aggression: float(),
          # -10.0 to 10.0
          alliance_standing: float()
        }

  @doc """
  Classify threat level based on multiple factors.
  """
  @spec classify_threat(threat_factors()) :: threat_level()
  def classify_threat(factors) when is_map(factors) do
    base_score = calculate_base_threat_score(factors)
    adjusted_score = apply_context_modifiers(base_score, factors)

    score_to_threat_level(adjusted_score)
  end

  @doc """
  Classify threat level for a character based on analysis data.
  """
  @spec classify_character_threat(map()) :: threat_level()
  def classify_character_threat(analysis) when is_map(analysis) do
    factors = %{
      combat_capability: Map.get(analysis, :combat_effectiveness, 0.0),
      fleet_size: 1,
      ship_classes: Map.get(analysis, :preferred_ships, []),
      isk_value: Map.get(analysis, :average_kill_value, IskAmount.zero()),
      activity_pattern: Map.get(analysis, :activity_pattern, :solo),
      security_class: Map.get(analysis, :primary_security_class, :unknown),
      historical_aggression: Map.get(analysis, :aggression_score, 0.0),
      alliance_standing: Map.get(analysis, :alliance_standing, 0.0)
    }

    classify_threat(factors)
  end

  @doc """
  Classify threat level for a fleet or group.
  """
  @spec classify_fleet_threat(map()) :: threat_level()
  def classify_fleet_threat(fleet_data) when is_map(fleet_data) do
    factors = %{
      combat_capability: Map.get(fleet_data, :fleet_effectiveness, 0.0),
      fleet_size: Map.get(fleet_data, :participant_count, 0),
      ship_classes: Map.get(fleet_data, :primary_ship_classes, []),
      isk_value: Map.get(fleet_data, :total_fleet_value, IskAmount.zero()),
      activity_pattern: determine_activity_pattern(fleet_data),
      security_class: Map.get(fleet_data, :operating_security_class, :unknown),
      historical_aggression: Map.get(fleet_data, :historical_aggression, 0.0),
      alliance_standing: Map.get(fleet_data, :average_standing, 0.0)
    }

    classify_threat(factors)
  end

  @doc """
  Classify threat level for a battle or engagement.
  """
  @spec classify_battle_threat(map()) :: threat_level()
  def classify_battle_threat(battle_data) when is_map(battle_data) do
    factors = %{
      combat_capability: Map.get(battle_data, :battle_intensity, 0.0),
      fleet_size: Map.get(battle_data, :total_participants, 0),
      ship_classes: Map.get(battle_data, :primary_ship_classes, []),
      isk_value: Map.get(battle_data, :total_value_destroyed, IskAmount.zero()),
      activity_pattern: Map.get(battle_data, :battle_type, :unknown),
      security_class: Map.get(battle_data, :system_security_class, :unknown),
      # Battles are inherently aggressive
      historical_aggression: 1.0,
      alliance_standing: Map.get(battle_data, :attacker_standing, 0.0)
    }

    classify_threat(factors)
  end

  @doc """
  Get threat level color for UI display.
  """
  @spec threat_color(threat_level()) :: String.t()
  # Green
  def threat_color(:minimal), do: "#28a745"
  # Info blue
  def threat_color(:low), do: "#17a2b8"
  # Warning yellow
  def threat_color(:moderate), do: "#ffc107"
  # Orange
  def threat_color(:high), do: "#fd7e14"
  # Red
  def threat_color(:critical), do: "#dc3545"
  # Purple
  def threat_color(:extreme), do: "#6f42c1"

  @doc """
  Get threat level priority for sorting and alerting.
  """
  @spec threat_priority(threat_level()) :: integer()
  def threat_priority(:minimal), do: 1
  def threat_priority(:low), do: 2
  def threat_priority(:moderate), do: 3
  def threat_priority(:high), do: 4
  def threat_priority(:critical), do: 5
  def threat_priority(:extreme), do: 6

  @doc """
  Get threat level description.
  """
  @spec threat_description(threat_level()) :: String.t()
  def threat_description(:minimal), do: "Minimal threat - Low capability or non-aggressive"
  def threat_description(:low), do: "Low threat - Limited capability or defensive posture"
  def threat_description(:moderate), do: "Moderate threat - Capable but not immediately dangerous"

  def threat_description(:high),
    do: "High threat - Significant capability and potential aggression"

  def threat_description(:critical),
    do: "Critical threat - High capability with aggressive intent"

  def threat_description(:extreme), do: "Extreme threat - Maximum capability with hostile intent"

  @doc """
  Check if threat level warrants immediate alert.
  """
  @spec requires_alert?(threat_level()) :: boolean()
  def requires_alert?(level) when level in [:high, :critical, :extreme], do: true
  def requires_alert?(_), do: false

  @doc """
  Check if threat level requires escalation.
  """
  @spec requires_escalation?(threat_level()) :: boolean()
  def requires_escalation?(level) when level in [:critical, :extreme], do: true
  def requires_escalation?(_), do: false

  @doc """
  Compare two threat levels.
  """
  @spec compare_threat_levels(threat_level(), threat_level()) :: :gt | :eq | :lt
  def compare_threat_levels(level1, level2) do
    priority1 = threat_priority(level1)
    priority2 = threat_priority(level2)

    cond do
      priority1 > priority2 -> :gt
      priority1 == priority2 -> :eq
      true -> :lt
    end
  end

  @doc """
  Get recommended response time for threat level.
  """
  @spec recommended_response_time(threat_level()) :: integer()
  # 1 hour
  def recommended_response_time(:minimal), do: 3600
  # 30 minutes
  def recommended_response_time(:low), do: 1800
  # 15 minutes
  def recommended_response_time(:moderate), do: 900
  # 5 minutes
  def recommended_response_time(:high), do: 300
  # 2 minutes
  def recommended_response_time(:critical), do: 120
  # 1 minute
  def recommended_response_time(:extreme), do: 60

  # Private functions

  defp calculate_base_threat_score(factors) do
    # Combat capability weight: 30%
    combat_score = Map.get(factors, :combat_capability, 0.0) * 0.3

    # Fleet size weight: 25%
    fleet_score = normalize_fleet_size(Map.get(factors, :fleet_size, 0)) * 0.25

    # Ship class weight: 20%
    ship_score = calculate_ship_class_score(Map.get(factors, :ship_classes, [])) * 0.2

    # ISK value weight: 15%
    isk_score = normalize_isk_value(Map.get(factors, :isk_value, IskAmount.zero())) * 0.15

    # Historical aggression weight: 10%
    aggression_score = Map.get(factors, :historical_aggression, 0.0) * 0.1

    combat_score + fleet_score + ship_score + isk_score + aggression_score
  end

  defp apply_context_modifiers(base_score, factors) do
    # Security class modifier
    security_modifier =
      case Map.get(factors, :security_class, :unknown) do
        # Lower threat in highsec
        :highsec -> -0.1
        # Baseline
        :lowsec -> 0.0
        # Higher threat in nullsec
        :nullsec -> 0.1
        # Highest threat in wormholes
        :wormhole -> 0.15
        _ -> 0.0
      end

    # Alliance standing modifier
    standing = Map.get(factors, :alliance_standing, 0.0)

    standing_modifier =
      cond do
        # Hostile standings increase threat
        standing <= -5.0 -> 0.2
        # Friendly standings decrease threat
        standing >= 5.0 -> -0.1
        true -> 0.0
      end

    # Activity pattern modifier
    pattern_modifier =
      case Map.get(factors, :activity_pattern, :solo) do
        :solo -> -0.05
        :small_gang -> 0.0
        :fleet -> 0.1
        :capital -> 0.2
        _ -> 0.0
      end

    base_score + security_modifier + standing_modifier + pattern_modifier
  end

  defp score_to_threat_level(score) when score >= 0.85, do: :extreme
  defp score_to_threat_level(score) when score >= 0.70, do: :critical
  defp score_to_threat_level(score) when score >= 0.55, do: :high
  defp score_to_threat_level(score) when score >= 0.35, do: :moderate
  defp score_to_threat_level(score) when score >= 0.15, do: :low
  defp score_to_threat_level(_), do: :minimal

  defp normalize_fleet_size(size) when size >= 100, do: 1.0
  defp normalize_fleet_size(size) when size >= 50, do: 0.8
  defp normalize_fleet_size(size) when size >= 20, do: 0.6
  defp normalize_fleet_size(size) when size >= 10, do: 0.4
  defp normalize_fleet_size(size) when size >= 5, do: 0.3
  defp normalize_fleet_size(size) when size >= 2, do: 0.2
  defp normalize_fleet_size(_), do: 0.1

  defp calculate_ship_class_score(ship_classes) do
    ship_classes
    |> Enum.map(&ship_class_threat_score/1)
    |> case do
      [] -> 0.0
      scores -> Enum.max(scores)
    end
  end

  defp ship_class_threat_score("Titan"), do: 1.0
  defp ship_class_threat_score("Supercarrier"), do: 0.95
  defp ship_class_threat_score("Dreadnought"), do: 0.9
  defp ship_class_threat_score("Carrier"), do: 0.85
  defp ship_class_threat_score("Force Auxiliary"), do: 0.8
  defp ship_class_threat_score("Battleship"), do: 0.7
  defp ship_class_threat_score("Battlecruiser"), do: 0.6
  defp ship_class_threat_score("Heavy Assault Cruiser"), do: 0.55
  defp ship_class_threat_score("Cruiser"), do: 0.5
  defp ship_class_threat_score("Heavy Interdictor"), do: 0.5
  defp ship_class_threat_score("Recon Ship"), do: 0.45
  defp ship_class_threat_score("Destroyer"), do: 0.4
  defp ship_class_threat_score("Frigate"), do: 0.3
  defp ship_class_threat_score(_), do: 0.2

  defp normalize_isk_value(isk_amount) do
    value = IskAmount.to_float(isk_amount)

    cond do
      # 50B+
      value >= 50_000_000_000 -> 1.0
      # 10B+
      value >= 10_000_000_000 -> 0.8
      # 1B+
      value >= 1_000_000_000 -> 0.6
      # 100M+
      value >= 100_000_000 -> 0.4
      # 10M+
      value >= 10_000_000 -> 0.2
      true -> 0.1
    end
  end

  defp determine_activity_pattern(fleet_data) do
    participant_count = Map.get(fleet_data, :participant_count, 0)
    ship_classes = Map.get(fleet_data, :primary_ship_classes, [])

    cond do
      Enum.any?(ship_classes, &(&1 in ["Titan", "Supercarrier", "Dreadnought", "Carrier"])) ->
        :capital

      participant_count >= 20 ->
        :fleet

      participant_count >= 5 ->
        :small_gang

      true ->
        :solo
    end
  end
end
