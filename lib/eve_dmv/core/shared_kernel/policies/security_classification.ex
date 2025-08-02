defmodule EveDmv.Core.SharedKernel.Policies.SecurityClassification do
  @moduledoc """
  Shared domain policy for classifying EVE Online security levels and their implications.

  This policy provides consistent security classification logic across different
  bounded contexts, including threat assessment, operational planning, and
  risk evaluation.
  """

  alias EveDmv.Core.SharedKernel.ValueObjects.SystemId

  @type security_class :: :highsec | :lowsec | :nullsec | :wormhole | :abyssal | :unknown
  # -1.0 to 1.0
  @type security_status :: float()
  @type risk_level :: :minimal | :low | :moderate | :high | :extreme

  @doc """
  Get security classification from system ID.
  """
  @spec classify_system(SystemId.t()) :: security_class()
  def classify_system(system_id) do
    SystemId.security_class(system_id)
  end

  @doc """
  Get security classification from security status value.
  """
  @spec classify_by_security_status(security_status()) :: security_class()
  def classify_by_security_status(sec_status) when sec_status >= 0.5, do: :highsec
  def classify_by_security_status(sec_status) when sec_status > 0.0, do: :lowsec
  def classify_by_security_status(sec_status) when sec_status <= 0.0, do: :nullsec

  @doc """
  Get risk level for a security classification.
  """
  @spec get_risk_level(security_class()) :: risk_level()
  def get_risk_level(:highsec), do: :minimal
  def get_risk_level(:lowsec), do: :moderate
  def get_risk_level(:nullsec), do: :high
  def get_risk_level(:wormhole), do: :extreme
  def get_risk_level(:abyssal), do: :extreme
  def get_risk_level(:unknown), do: :low

  @doc """
  Check if PvP is allowed in this security class.
  """
  @spec pvp_allowed?(security_class()) :: boolean()
  # Limited PvP (war, suspect, criminal)
  def pvp_allowed?(:highsec), do: false
  def pvp_allowed?(:lowsec), do: true
  def pvp_allowed?(:nullsec), do: true
  def pvp_allowed?(:wormhole), do: true
  # PvE environment
  def pvp_allowed?(:abyssal), do: false
  def pvp_allowed?(:unknown), do: false

  @doc """
  Check if gate/station guns are present.
  """
  @spec has_gate_guns?(security_class()) :: boolean()
  def has_gate_guns?(:highsec), do: true
  def has_gate_guns?(:lowsec), do: true
  def has_gate_guns?(:nullsec), do: false
  def has_gate_guns?(:wormhole), do: false
  def has_gate_guns?(:abyssal), do: false
  def has_gate_guns?(:unknown), do: false

  @doc """
  Check if CONCORD response is active.
  """
  @spec has_concord_response?(security_class()) :: boolean()
  def has_concord_response?(:highsec), do: true
  def has_concord_response?(:lowsec), do: false
  def has_concord_response?(:nullsec), do: false
  def has_concord_response?(:wormhole), do: false
  def has_concord_response?(:abyssal), do: false
  def has_concord_response?(:unknown), do: false

  @doc """
  Get insurance payout multiplier for losses in this security class.
  """
  @spec insurance_multiplier(security_class()) :: float()
  def insurance_multiplier(:highsec), do: 1.0
  def insurance_multiplier(:lowsec), do: 0.5
  def insurance_multiplier(:nullsec), do: 0.0
  def insurance_multiplier(:wormhole), do: 0.0
  def insurance_multiplier(:abyssal), do: 0.0
  def insurance_multiplier(:unknown), do: 0.0

  @doc """
  Get sovereignty mechanics availability.
  """
  @spec has_sovereignty?(security_class()) :: boolean()
  def has_sovereignty?(:highsec), do: false
  def has_sovereignty?(:lowsec), do: false
  def has_sovereignty?(:nullsec), do: true
  def has_sovereignty?(:wormhole), do: false
  def has_sovereignty?(:abyssal), do: false
  def has_sovereignty?(:unknown), do: false

  @doc """
  Check if cynos can be lit in this security class.
  """
  @spec cyno_allowed?(security_class()) :: boolean()
  def cyno_allowed?(:highsec), do: false
  def cyno_allowed?(:lowsec), do: true
  def cyno_allowed?(:nullsec), do: true
  def cyno_allowed?(:wormhole), do: false
  def cyno_allowed?(:abyssal), do: false
  def cyno_allowed?(:unknown), do: false

  @doc """
  Get escalation potential for security class.
  """
  @spec escalation_potential(security_class()) :: :none | :limited | :full
  # No escalation beyond CONCORD
  def escalation_potential(:highsec), do: :none
  # Limited by gate guns
  def escalation_potential(:lowsec), do: :limited
  # Full escalation possible
  def escalation_potential(:nullsec), do: :full
  # Full escalation, no backup
  def escalation_potential(:wormhole), do: :full
  # Isolated environment
  def escalation_potential(:abyssal), do: :none
  def escalation_potential(:unknown), do: :none

  @doc """
  Get recommended fleet composition for operations in security class.
  """
  @spec recommended_fleet_composition(security_class()) :: [String.t()]
  def recommended_fleet_composition(:highsec) do
    ["Frigate", "Destroyer", "Cruiser", "Battlecruiser", "Battleship"]
  end

  def recommended_fleet_composition(:lowsec) do
    ["Frigate", "Destroyer", "Cruiser", "Battlecruiser", "Battleship", "Heavy Assault Cruiser"]
  end

  def recommended_fleet_composition(:nullsec) do
    [
      "Frigate",
      "Destroyer",
      "Cruiser",
      "Battlecruiser",
      "Battleship",
      "Heavy Assault Cruiser",
      "Carrier",
      "Dreadnought"
    ]
  end

  def recommended_fleet_composition(:wormhole) do
    ["Strategic Cruiser", "Heavy Assault Cruiser", "Battleship", "Dreadnought"]
  end

  def recommended_fleet_composition(:abyssal) do
    ["Cruiser", "Battlecruiser", "Battleship"]
  end

  def recommended_fleet_composition(:unknown), do: []

  @doc """
  Get threat assessment modifiers for security class.
  """
  @spec threat_modifiers(security_class()) :: map()
  def threat_modifiers(:highsec) do
    %{
      base_threat_multiplier: 0.3,
      escalation_risk: 0.1,
      response_time_minutes: 1,
      backup_availability: 0.9
    }
  end

  def threat_modifiers(:lowsec) do
    %{
      base_threat_multiplier: 0.7,
      escalation_risk: 0.4,
      response_time_minutes: 5,
      backup_availability: 0.5
    }
  end

  def threat_modifiers(:nullsec) do
    %{
      base_threat_multiplier: 1.0,
      escalation_risk: 0.8,
      response_time_minutes: 15,
      backup_availability: 0.3
    }
  end

  def threat_modifiers(:wormhole) do
    %{
      base_threat_multiplier: 1.2,
      escalation_risk: 0.9,
      response_time_minutes: 30,
      backup_availability: 0.1
    }
  end

  def threat_modifiers(:abyssal) do
    %{
      base_threat_multiplier: 0.1,
      escalation_risk: 0.0,
      response_time_minutes: 0,
      backup_availability: 0.0
    }
  end

  def threat_modifiers(:unknown) do
    %{
      base_threat_multiplier: 0.5,
      escalation_risk: 0.3,
      response_time_minutes: 10,
      backup_availability: 0.2
    }
  end

  @doc """
  Calculate operational risk score for security class and fleet composition.
  """
  @spec calculate_operational_risk(security_class(), [String.t()], integer()) :: float()
  def calculate_operational_risk(security_class, ship_classes, participant_count) do
    modifiers = threat_modifiers(security_class)
    base_risk = modifiers.base_threat_multiplier

    # Fleet size multiplier
    size_multiplier =
      cond do
        participant_count >= 100 -> 1.5
        participant_count >= 50 -> 1.3
        participant_count >= 20 -> 1.1
        participant_count >= 10 -> 1.0
        true -> 0.8
      end

    # Ship class risk multiplier
    ship_multiplier = calculate_ship_risk_multiplier(ship_classes, security_class)

    # Escalation risk
    escalation_multiplier = 1.0 + modifiers.escalation_risk

    base_risk * size_multiplier * ship_multiplier * escalation_multiplier
  end

  @doc """
  Get security class display name.
  """
  @spec display_name(security_class()) :: String.t()
  def display_name(:highsec), do: "High Security"
  def display_name(:lowsec), do: "Low Security"
  def display_name(:nullsec), do: "Null Security"
  def display_name(:wormhole), do: "Wormhole Space"
  def display_name(:abyssal), do: "Abyssal Space"
  def display_name(:unknown), do: "Unknown"

  @doc """
  Get security class color for UI display.
  """
  @spec security_color(security_class()) :: String.t()
  # Green
  def security_color(:highsec), do: "#28a745"
  # Yellow
  def security_color(:lowsec), do: "#ffc107"
  # Red
  def security_color(:nullsec), do: "#dc3545"
  # Purple
  def security_color(:wormhole), do: "#6f42c1"
  # Cyan
  def security_color(:abyssal), do: "#17a2b8"
  # Gray
  def security_color(:unknown), do: "#6c757d"

  @doc """
  Compare security levels (higher is safer).
  """
  @spec compare_security(security_class(), security_class()) :: :gt | :eq | :lt
  def compare_security(sec1, sec2) do
    priority1 = security_priority(sec1)
    priority2 = security_priority(sec2)

    cond do
      priority1 > priority2 -> :gt
      priority1 == priority2 -> :eq
      true -> :lt
    end
  end

  @doc """
  Check if security class allows specific ship types.
  """
  @spec ship_allowed?(security_class(), String.t()) :: boolean()
  def ship_allowed?(:highsec, ship_class) do
    ship_class not in ["Titan", "Supercarrier", "Carrier", "Dreadnought", "Force Auxiliary"]
  end

  def ship_allowed?(_, _), do: true

  # Private functions

  defp security_priority(:highsec), do: 5
  defp security_priority(:lowsec), do: 4
  defp security_priority(:abyssal), do: 3
  defp security_priority(:nullsec), do: 2
  defp security_priority(:wormhole), do: 1
  defp security_priority(:unknown), do: 0

  defp calculate_ship_risk_multiplier(ship_classes, security_class) do
    ship_classes
    |> Enum.map(&ship_risk_score(&1, security_class))
    |> case do
      [] -> 1.0
      scores -> Enum.max(scores)
    end
  end

  defp ship_risk_score(ship_class, security_class) do
    base_risk =
      case ship_class do
        "Titan" -> 2.0
        "Supercarrier" -> 1.8
        "Dreadnought" -> 1.6
        "Carrier" -> 1.4
        "Force Auxiliary" -> 1.2
        "Battleship" -> 1.0
        "Battlecruiser" -> 0.8
        "Heavy Assault Cruiser" -> 0.7
        "Strategic Cruiser" -> 0.9
        "Cruiser" -> 0.6
        "Destroyer" -> 0.4
        "Frigate" -> 0.3
        _ -> 0.5
      end

    # Adjust based on security class restrictions
    case security_class do
      :highsec
      when ship_class in ["Titan", "Supercarrier", "Carrier", "Dreadnought", "Force Auxiliary"] ->
        # Not allowed
        0.0

      :wormhole when ship_class in ["Titan", "Supercarrier"] ->
        # Limited effectiveness
        base_risk * 0.5

      _ ->
        base_risk
    end
  end
end
