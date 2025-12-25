defmodule EveDmv.Contexts.CharacterIntelligence.ThreatConfig do
  @moduledoc """
  Configuration constants for threat scoring calculations.

  All values are documented with rationale based on EVE Online combat statistics
  and PvP behavior analysis. These provide normalization factors and thresholds
  for the threat scoring engine.

  ## Usage Normalization

  Normalization factors determine what constitutes "high" or "maximum" values
  for various metrics. A character reaching the normalization threshold is
  considered to have maximized that particular metric (score = 1.0).

  ## Ship Classification

  Ship classes are determined by EVE Online group IDs from the Static Data Export (SDE).
  These group IDs are maintained by CCP and represent the official ship classifications.

  ## Threshold Constants

  - `ship_usage_normalization` (10): Characters using 10+ different ship types are highly versatile
  - `ship_diversity_normalization` (5): Characters with 5+ unique ship classes show diverse tactics
  - `ship_variety_max` (15): Using 15+ different ship types indicates exceptional variance
  - `kd_ratio_max` (5.0): A 5:1 K/D ratio represents elite combat performance
  - `isk_efficiency_max` (3.0): A 3:1 ISK efficiency represents strong economic performance
  - `damage_contribution_excellent` (0.15): 15% average damage indicates primary DPS role
  - `high_value_target_isk` (100M): Targets worth 100M+ ISK are considered "valuable"
  - `opportunist_target_isk` (500M): Characters killing 500M+ targets are opportunists
  - `fleet_size_threshold` (3): More than 3 attackers indicates fleet action
  - `large_fleet_threshold` (10): More than 10 attackers indicates large fleet
  - `leadership_final_blow_rate` (0.33): 33% final blow rate indicates leadership
  - `high_activity_kills_per_day` (2): 2+ kills/day indicates high activity
  - `active_hours_max` (12): Active across 12+ hours indicates timezone flexibility
  - `active_systems_max` (20): Activity in 20+ systems indicates geographic variance
  - `escalation_risk_threshold` (0.5): Risk above 50% indicates high escalation potential

  ## Ship Group IDs (from EVE SDE)

  - Frigate: Group 25
  - Destroyer: Group 420
  - Cruiser: Group 26
  - Battlecruiser: Groups 419, 1201
  - Battleship: Group 27
  - Capital: Groups 485, 547, 659, 30, 1538, 883
  - Logistics: Groups 832, 1527
  - EWAR: Groups 833, 893
  - Command: Group 900
  - Tackle: Groups 831, 541
  """

  # =============================================================================
  # Ship Usage and Diversity Normalization
  # =============================================================================

  # A character using 10+ different ship types is considered highly versatile.
  # Based on EVE PvP statistics, the top 10% of active PvPers regularly use
  # 10 or more distinct ship types.
  @ship_usage_normalization 10

  # A character with 5+ unique ship classes shows diverse tactical capabilities.
  # Ship classes include distinct roles like frigate, cruiser, battleship, etc.
  @ship_diversity_normalization 5

  # Using 15+ different ship types indicates exceptional variance in ship selection.
  # This threshold is used for unpredictability scoring.
  @ship_variety_max 15

  # =============================================================================
  # Combat Performance Normalization
  # =============================================================================

  # A kill/death ratio of 5:1 or higher represents elite combat performance.
  @kd_ratio_max 5.0

  # An ISK efficiency ratio of 3:1 represents strong economic combat performance.
  @isk_efficiency_max 3.0

  # A 15% average damage contribution indicates a primary damage dealer.
  @damage_contribution_excellent 0.15

  # High-value kills threshold: 100M+ ISK.
  @high_value_target_isk 100_000_000

  # Opportunist pattern threshold: 500M+ ISK targets.
  @opportunist_target_isk 500_000_000

  # =============================================================================
  # Fleet and Gang Normalization
  # =============================================================================

  # More than 3 attackers indicates a fleet action (vs solo/small gang).
  @fleet_size_threshold 3

  # More than 10 attackers indicates a large fleet action.
  @large_fleet_threshold 10

  # A 33% final blow rate indicates strong combat leadership.
  @leadership_final_blow_rate 0.33

  # =============================================================================
  # Activity and Timing Normalization
  # =============================================================================

  # 2+ kills per day indicates high activity level.
  @high_activity_kills_per_day 2

  # Active across 12+ hours indicates timezone flexibility.
  @active_hours_max 12

  # Activity in 20+ different systems indicates high geographic variance.
  @active_systems_max 20

  # =============================================================================
  # Risk Assessment Thresholds
  # =============================================================================

  # Escalation risk threshold for determining high-risk situations.
  # A value above 0.5 (50%) indicates significant escalation risk that warrants
  # alerting users. This threshold is used in cross-system intelligence analysis
  # to identify situations where threat levels are likely to increase.
  @escalation_risk_threshold 0.5

  # =============================================================================
  # Fallback Score Constants
  # =============================================================================

  # Score assigned when there is insufficient recent data (< 3 killmails in 30 days).
  # A low score of 0.3 indicates the character is likely inactive or has minimal
  # recent activity. This is intentionally conservative to avoid overestimating
  # threats from dormant characters.
  @insufficient_data_score 0.3

  # Score assigned when recent activity weighting is disabled via options.
  # A neutral score of 0.5 means the recent activity dimension contributes
  # neither positively nor negatively to the overall threat assessment.
  @weighting_disabled_neutral_score 0.5

  # Minimum number of recent killmails required for reliable recent activity analysis.
  # Below this threshold, the insufficient_data_score is used instead.
  @minimum_recent_killmails 3

  # =============================================================================
  # Ship Class Group IDs (from EVE SDE)
  # =============================================================================

  # Group 25 = Frigate (standard T1 frigates)
  @frigate_group_ids [25]

  # Group 420 = Destroyer
  @destroyer_group_ids [420]

  # Group 26 = Cruiser
  @cruiser_group_ids [26]

  # Group 419 = Combat Battlecruiser, Group 1201 = Attack Battlecruiser
  @battlecruiser_group_ids [419, 1201]

  # Group 27 = Battleship
  @battleship_group_ids [27]

  # Capital ship groups:
  # 485 = Dreadnought, 547 = Carrier, 659 = Supercarrier, 30 = Titan,
  # 1538 = Force Auxiliary, 883 = Capital Industrial Ship (Rorqual)
  @capital_group_ids [485, 547, 659, 30, 1538, 883]

  # Logistics ship groups: 832 = Logistics (T2), 1527 = Logistics Frigate
  @logistics_group_ids [832, 1527]

  # EWAR ship groups: 833 = Electronic Attack Ship, 893 = Recon Ship
  @ewar_group_ids [833, 893]

  # Command ship groups: 900 = Command Ship
  @command_group_ids [900]

  # Tackle ship groups: 831 = Interceptor, 541 = Interdictor
  @tackle_group_ids [831, 541]

  # =============================================================================
  # Ship Category IDs (from EVE SDE)
  # =============================================================================

  # Category 6 = Ship
  @ship_category_id 6

  # =============================================================================
  # Public API - Usage Normalization
  # =============================================================================

  @doc "Returns the ship usage normalization threshold (10 ship types)."
  @spec ship_usage_normalization() :: integer()
  def ship_usage_normalization, do: @ship_usage_normalization

  @doc "Returns the ship diversity normalization threshold (5 ship classes)."
  @spec ship_diversity_normalization() :: integer()
  def ship_diversity_normalization, do: @ship_diversity_normalization

  @doc "Returns the maximum ship variety threshold (15 ship types)."
  @spec ship_variety_max() :: integer()
  def ship_variety_max, do: @ship_variety_max

  # =============================================================================
  # Public API - Combat Performance
  # =============================================================================

  @doc "Returns the maximum K/D ratio threshold (5.0)."
  @spec kd_ratio_max() :: float()
  def kd_ratio_max, do: @kd_ratio_max

  @doc "Returns the maximum ISK efficiency threshold (3.0)."
  @spec isk_efficiency_max() :: float()
  def isk_efficiency_max, do: @isk_efficiency_max

  @doc "Returns the excellent damage contribution threshold (15%)."
  @spec damage_contribution_excellent() :: float()
  def damage_contribution_excellent, do: @damage_contribution_excellent

  @doc "Returns the high value target ISK threshold (100M)."
  @spec high_value_target_isk() :: integer()
  def high_value_target_isk, do: @high_value_target_isk

  @doc "Returns the opportunist target ISK threshold (500M)."
  @spec opportunist_target_isk() :: integer()
  def opportunist_target_isk, do: @opportunist_target_isk

  # =============================================================================
  # Public API - Fleet Normalization
  # =============================================================================

  @doc "Returns the fleet size threshold (3 attackers)."
  @spec fleet_size_threshold() :: integer()
  def fleet_size_threshold, do: @fleet_size_threshold

  @doc "Returns the large fleet threshold (10 attackers)."
  @spec large_fleet_threshold() :: integer()
  def large_fleet_threshold, do: @large_fleet_threshold

  @doc "Returns the leadership final blow rate threshold (33%)."
  @spec leadership_final_blow_rate() :: float()
  def leadership_final_blow_rate, do: @leadership_final_blow_rate

  # =============================================================================
  # Public API - Activity Normalization
  # =============================================================================

  @doc "Returns the high activity kills per day threshold (2)."
  @spec high_activity_kills_per_day() :: integer()
  def high_activity_kills_per_day, do: @high_activity_kills_per_day

  @doc "Returns the maximum active hours threshold (12)."
  @spec active_hours_max() :: integer()
  def active_hours_max, do: @active_hours_max

  @doc "Returns the maximum active systems threshold (20)."
  @spec active_systems_max() :: integer()
  def active_systems_max, do: @active_systems_max

  # =============================================================================
  # Public API - Risk Assessment Thresholds
  # =============================================================================

  @doc """
  Returns the escalation risk threshold (0.5 / 50%).

  Risk values above this threshold indicate high escalation risk that warrants
  alerting users. Used in cross-system intelligence analysis to identify
  situations where threat levels are likely to increase.
  """
  @spec escalation_risk_threshold() :: float()
  def escalation_risk_threshold, do: @escalation_risk_threshold

  # =============================================================================
  # Public API - Fallback Scores
  # =============================================================================

  @doc """
  Returns the score assigned when insufficient recent data is available.

  A low score of 0.3 indicates the character is likely inactive. This is
  intentionally conservative to avoid overestimating dormant characters.
  """
  @spec insufficient_data_score() :: float()
  def insufficient_data_score, do: @insufficient_data_score

  @doc """
  Returns the neutral score assigned when recent activity weighting is disabled.

  A neutral score of 0.5 means the dimension contributes neither positively
  nor negatively to the overall threat assessment.
  """
  @spec weighting_disabled_neutral_score() :: float()
  def weighting_disabled_neutral_score, do: @weighting_disabled_neutral_score

  @doc """
  Returns the minimum number of recent killmails required for reliable analysis.

  Below this threshold (3 killmails), the insufficient_data_score is used.
  """
  @spec minimum_recent_killmails() :: integer()
  def minimum_recent_killmails, do: @minimum_recent_killmails

  # =============================================================================
  # Public API - Ship Group IDs
  # =============================================================================

  @doc "Returns the EVE group IDs for frigate hulls."
  @spec frigate_group_ids() :: [integer()]
  def frigate_group_ids, do: @frigate_group_ids

  @doc "Returns the EVE group IDs for destroyer hulls."
  @spec destroyer_group_ids() :: [integer()]
  def destroyer_group_ids, do: @destroyer_group_ids

  @doc "Returns the EVE group IDs for cruiser hulls."
  @spec cruiser_group_ids() :: [integer()]
  def cruiser_group_ids, do: @cruiser_group_ids

  @doc "Returns the EVE group IDs for battlecruiser hulls."
  @spec battlecruiser_group_ids() :: [integer()]
  def battlecruiser_group_ids, do: @battlecruiser_group_ids

  @doc "Returns the EVE group IDs for battleship hulls."
  @spec battleship_group_ids() :: [integer()]
  def battleship_group_ids, do: @battleship_group_ids

  @doc "Returns the EVE group IDs for capital ships."
  @spec capital_group_ids() :: [integer()]
  def capital_group_ids, do: @capital_group_ids

  @doc "Returns the EVE group IDs for logistics ships."
  @spec logistics_group_ids() :: [integer()]
  def logistics_group_ids, do: @logistics_group_ids

  @doc "Returns the EVE group IDs for EWAR ships."
  @spec ewar_group_ids() :: [integer()]
  def ewar_group_ids, do: @ewar_group_ids

  @doc "Returns the EVE group IDs for command ships."
  @spec command_group_ids() :: [integer()]
  def command_group_ids, do: @command_group_ids

  @doc "Returns the EVE group IDs for tackle ships."
  @spec tackle_group_ids() :: [integer()]
  def tackle_group_ids, do: @tackle_group_ids

  @doc "Returns the EVE category ID for ships."
  @spec ship_category_id() :: integer()
  def ship_category_id, do: @ship_category_id

  # =============================================================================
  # Public API - Derived Functions
  # =============================================================================

  @doc """
  Returns all ship group IDs that are considered subcapital combat ships.
  """
  @spec subcapital_combat_group_ids() :: [integer()]
  def subcapital_combat_group_ids do
    @frigate_group_ids ++
      @destroyer_group_ids ++
      @cruiser_group_ids ++
      @battlecruiser_group_ids ++
      @battleship_group_ids
  end

  @doc """
  Returns all tactical support ship group IDs (logistics, EWAR, command).
  """
  @spec tactical_support_group_ids() :: [integer()]
  def tactical_support_group_ids do
    @logistics_group_ids ++ @ewar_group_ids ++ @command_group_ids
  end

  @doc """
  Classifies a group ID into a ship class atom.

  Returns :unknown if the group ID doesn't match any known ship class.
  """
  @spec classify_by_group_id(integer()) :: atom()
  def classify_by_group_id(group_id) when is_integer(group_id) do
    cond do
      group_id in @frigate_group_ids -> :frigate
      group_id in @destroyer_group_ids -> :destroyer
      group_id in @cruiser_group_ids -> :cruiser
      group_id in @battlecruiser_group_ids -> :battlecruiser
      group_id in @battleship_group_ids -> :battleship
      group_id in @capital_group_ids -> :capital
      group_id in @logistics_group_ids -> :logistics
      group_id in @ewar_group_ids -> :ewar
      group_id in @command_group_ids -> :command
      group_id in @tackle_group_ids -> :tackle
      true -> :unknown
    end
  end

  def classify_by_group_id(_), do: :unknown

  @doc """
  Checks if a group ID represents a tactical priority target.

  Tactical priority targets include logistics, EWAR, and command ships.
  """
  @spec tactical_target_group?(integer()) :: boolean()
  def tactical_target_group?(group_id) when is_integer(group_id) do
    group_id in tactical_support_group_ids()
  end

  def tactical_target_group?(_), do: false

  @doc """
  Checks if a group ID represents a capital ship.
  """
  @spec capital_group?(integer()) :: boolean()
  def capital_group?(group_id) when is_integer(group_id) do
    group_id in @capital_group_ids
  end

  def capital_group?(_), do: false
end
