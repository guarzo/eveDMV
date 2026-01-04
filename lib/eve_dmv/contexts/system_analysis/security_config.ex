defmodule EveDmv.Contexts.SystemAnalysis.SecurityConfig do
  @moduledoc """
  Configuration constants for security-based danger calculations.

  All values are documented with rationale based on EVE Online's security
  classification system. These provide danger modifiers for heatmap and
  activity analysis based on the system's security class.

  ## Security Class Modifiers

  Security classes are derived from the EVE SDE `security_class` field:

  - `"highsec"` (0.5): High security space - CONCORD protection reduces danger
  - `"lowsec"` (1.0): Low security space - baseline danger (no CONCORD, gate guns exist)
  - `"nullsec"` (1.5): Null security space - no protection, bubble mechanics increase risk
  - `"wormhole"` (1.8): Wormhole space - no local chat, no cynos, unpredictable connections

  ## Fallback Modifiers

  When `security_class` is not available (legacy data or edge cases), the
  `security_status` numeric value is used:

  - >= 0.5: Treated as highsec (modifier 0.5)
  - >= 0.0: Treated as lowsec (modifier 1.0)
  - < 0.0: Treated as nullsec (modifier 1.5)

  ## Why Wormholes are Most Dangerous

  Wormholes have a higher modifier (1.8) than nullsec (1.5) because:
  - No local chat means no warning of enemy presence
  - No cynosural fields means no rapid reinforcement
  - Mass limits on connections restrict fleet composition
  - Connections are temporary and unpredictable
  - Environmental effects can modify combat dynamics
  """

  # =============================================================================
  # Security Class Danger Modifiers
  # =============================================================================

  # High security space (0.5 to 1.0 security status)
  # CONCORD provides protection, reducing overall danger.
  # Modifier of 0.5 means danger is halved compared to lowsec baseline.
  @highsec_modifier 0.5

  # Low security space (0.1 to 0.4 security status)
  # No CONCORD but gate guns provide some deterrent.
  # Used as the baseline modifier (1.0).
  @lowsec_modifier 1.0

  # Null security space (0.0 and below)
  # No protection at all, bubbles allow dictors/hictors to catch targets.
  # Modifier of 1.5 reflects 50% increased danger over lowsec.
  @nullsec_modifier 1.5

  # Wormhole space (J-space systems)
  # Most dangerous: no local, no cynos, mass limits, temporary connections.
  # Modifier of 1.8 reflects highest danger level.
  @wormhole_modifier 1.8

  # Default modifier when security class is unknown
  # Uses lowsec baseline as a conservative default.
  @unknown_modifier 1.0

  # =============================================================================
  # Public API - Security Class Modifiers
  # =============================================================================

  @doc """
  Returns the danger modifier for a given security class string.

  Uses the `security_class` field from the EVE SDE solar systems table
  to determine the appropriate danger multiplier.

  ## Parameters

  - `security_class`: One of `"highsec"`, `"lowsec"`, `"nullsec"`, `"wormhole"`, or `nil`

  ## Returns

  - A float danger modifier, or `nil` if the security class is unknown/nil

  ## Examples

      iex> SecurityConfig.security_danger_modifier("highsec")
      0.5

      iex> SecurityConfig.security_danger_modifier("wormhole")
      1.8

      iex> SecurityConfig.security_danger_modifier(nil)
      nil
  """
  @spec security_danger_modifier(String.t() | nil) :: float() | nil
  def security_danger_modifier("highsec"), do: @highsec_modifier
  def security_danger_modifier("lowsec"), do: @lowsec_modifier
  def security_danger_modifier("nullsec"), do: @nullsec_modifier
  def security_danger_modifier("wormhole"), do: @wormhole_modifier
  def security_danger_modifier(_), do: nil

  @doc """
  Returns the danger modifier based on numeric security status.

  Used as a fallback when `security_class` is not available. Maps
  security_status ranges to approximate security class modifiers.

  ## Parameters

  - `security_status`: The numeric security status (-1.0 to 1.0)

  ## Returns

  - A float danger modifier based on the security status range

  ## Examples

      iex> SecurityConfig.fallback_security_modifier(0.8)
      0.5

      iex> SecurityConfig.fallback_security_modifier(0.3)
      1.0

      iex> SecurityConfig.fallback_security_modifier(-0.5)
      1.5
  """
  @spec fallback_security_modifier(number() | nil) :: float()
  def fallback_security_modifier(security_status) when is_number(security_status) do
    cond do
      security_status >= 0.5 -> @highsec_modifier
      security_status >= 0.0 -> @lowsec_modifier
      true -> @nullsec_modifier
    end
  end

  def fallback_security_modifier(_), do: @unknown_modifier

  @doc """
  Returns the danger modifier for a system, using security_class if available,
  falling back to security_status if not.

  This is the recommended function to use for danger calculations as it
  handles both the preferred class-based lookup and the fallback gracefully.

  ## Parameters

  - `security_class`: The security class string (may be nil)
  - `security_status`: The numeric security status (used as fallback)

  ## Returns

  - A float danger modifier

  ## Examples

      iex> SecurityConfig.danger_modifier("highsec", 0.9)
      0.5

      iex> SecurityConfig.danger_modifier(nil, 0.3)
      1.0
  """
  @spec danger_modifier(String.t() | nil, number() | nil) :: float()
  def danger_modifier(security_class, security_status) do
    security_danger_modifier(security_class) ||
      fallback_security_modifier(security_status)
  end

  # =============================================================================
  # Public API - Raw Modifier Values
  # =============================================================================

  @doc "Returns the highsec danger modifier (0.5)."
  @spec highsec_modifier() :: float()
  def highsec_modifier, do: @highsec_modifier

  @doc "Returns the lowsec danger modifier (1.0)."
  @spec lowsec_modifier() :: float()
  def lowsec_modifier, do: @lowsec_modifier

  @doc "Returns the nullsec danger modifier (1.5)."
  @spec nullsec_modifier() :: float()
  def nullsec_modifier, do: @nullsec_modifier

  @doc "Returns the wormhole danger modifier (1.8)."
  @spec wormhole_modifier() :: float()
  def wormhole_modifier, do: @wormhole_modifier

  @doc "Returns the unknown/default danger modifier (1.0)."
  @spec unknown_modifier() :: float()
  def unknown_modifier, do: @unknown_modifier
end
