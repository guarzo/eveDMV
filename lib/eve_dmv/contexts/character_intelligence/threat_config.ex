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

  ## Bait Detection Thresholds

  - `bait_cheap_ship_threshold` (100M): Ships under this value are considered cheap/expendable
  - `bait_min_deaths` (3): Minimum deaths required before bait analysis applies
  - `bait_cheap_death_threshold` (60%): % of cheap ship deaths indicating bait pattern
  - `bait_low_damage_threshold` (5%): Low damage contribution when dying suggests tackle role
  - `bait_corp_kill_correlation` (40%): Deaths with corpmate kills nearby indicates bait
  - `bait_low_final_blow_rate` (10%): Low final blow rate suggests support role
  - `bait_positive_trade_ratio` (3.0): Corpmate kills value vs personal loss value
  - `bait_outgunned_threshold` (5): Average attackers at death indicating overextension
  - `bait_score_confirmed` (70): Score threshold for "Confirmed bait pilot"
  - `bait_score_likely` (50): Score threshold for "Likely bait pilot"
  - `bait_score_possible` (30): Score threshold for "Possible bait pilot"

  ## Target Assessment Thresholds

  - `target_capital_threshold` (30%): Capital kills % for "Capital hunter" classification
  - `target_highsec_threshold` (60%): Highsec kills % for "Highsec ganker" classification
  - `target_industrial_threshold` (40%): Industrial kills % for "Industrial hunter"
  - `target_wormhole_threshold` (60%): Wormhole kills % for "Wormhole hunter"
  - `target_solo_threshold` (70%): Solo kills % for "Solo hunter" classification
  - `target_pod_threshold` (20%): Pod kills % for "Pod hunter" classification

  ## ISK-Based Classification Thresholds

  - `elite_hunter_isk` (500M): Average victim ISK for "Elite hunter" classification
  - `standard_combatant_isk` (100M): Average victim ISK for "Standard combatant" classification
  - `casual_pvper_isk` (20M): Average victim ISK for "Casual PvPer" classification (below = "Opportunist")

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
  # Bait Detection Thresholds
  # =============================================================================
  # Bait detection identifies pilots who sacrifice cheap ships to enable corpmates
  # to secure kills. A multi-factor scoring system weights various bait indicators.

  # ISK threshold for "cheap" ships that may be used as bait.
  # Ships < 100M ISK are considered expendable/cheap for bait purposes.
  # This covers most T1 cruisers and below, while excluding expensive fits.
  @bait_cheap_ship_threshold 100_000_000

  # Minimum deaths required before bait analysis is meaningful.
  # At least 3 deaths needed to establish a pattern.
  @bait_min_deaths 3

  # Percentage of cheap ship deaths that indicates bait pattern (0-100).
  # 60%+ of deaths in cheap ships is a strong bait indicator.
  @bait_cheap_death_threshold 60

  # Damage contribution threshold for bait detection.
  # Bait pilots typically do < 5% damage when dying (holding tackle, not DPS).
  @bait_low_damage_threshold 0.05

  # Corpmate kill correlation threshold.
  # 40%+ of deaths having corpmate kills nearby strongly indicates bait.
  @bait_corp_kill_correlation 40

  # Final blow rate threshold for bait detection.
  # < 10% final blows suggests tackle/support role rather than damage dealer.
  @bait_low_final_blow_rate 0.10

  # Trade ratio threshold (corpmate kill value / personal loss value).
  # A ratio > 3.0 means corpmates killed 3x more ISK than the bait pilot lost.
  @bait_positive_trade_ratio 3.0

  # Average attacker count threshold for "outgunned" detection.
  # Dying to 5+ attackers on average suggests intentional overextension (bait).
  @bait_outgunned_threshold 5

  # Bait score classification thresholds (out of 100)
  @bait_score_confirmed 70
  @bait_score_likely 50
  @bait_score_possible 30

  # =============================================================================
  # Target Assessment Thresholds
  # =============================================================================
  # Target assessment classifies pilots based on their hunting patterns, including
  # victim types, security space, and kill style.

  # Capital hunter threshold: 30%+ kills on capital ships
  @target_capital_threshold 30

  # Highsec ganker threshold: 60%+ kills in highsec
  @target_highsec_threshold 60

  # Industrial hunter threshold: 40%+ kills on industrials/miners
  @target_industrial_threshold 40

  # Wormhole hunter threshold: 60%+ kills in wormhole space
  @target_wormhole_threshold 60

  # Solo hunter threshold: 70%+ solo kills
  @target_solo_threshold 70

  # Pod hunter threshold: 20%+ pod kills
  @target_pod_threshold 20

  # ISK-based target classification thresholds
  # These thresholds determine pilot classification based on average victim value
  # when no specific hunting pattern (capital, wormhole, industrial, etc.) is detected.
  #
  # Elite hunter: 500M+ ISK average victim value indicates selective high-value targeting.
  # This represents pilots who specifically hunt expensive ships, faction fits, or capitals.
  @elite_hunter_isk 500_000_000

  # Standard combatant: 100M-500M ISK average victim value indicates general PvP activity.
  # This represents the bulk of active PvPers killing typical combat ships.
  @standard_combatant_isk 100_000_000

  # Casual PvPer: 20M-100M ISK average victim value indicates opportunistic or low-end PvP.
  # Below this threshold, the pilot is classified as an "opportunist" (catching whatever is available).
  @casual_pvper_isk 20_000_000

  # Mining ship group IDs: 463 = Mining Barge, 543 = Exhumer
  @mining_group_ids [463, 543]

  # Industrial ship group IDs: 28 = Industrial, 380 = Deep Space Transport,
  # 902 = Freighter, 513 = Transport Ship, 941 = Industrial Command Ship (Orca), 1022 = ORE Industrial
  @industrial_group_ids [28, 380, 902, 513, 941, 1022]

  # Capsule type ID (the specific item type)
  @capsule_type_id 670

  # Capsule group ID (group 29 = Capsule in EVE SDE)
  # Used for consistent group-based classification in SQL queries
  @capsule_group_id 29

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

  # =============================================================================
  # Public API - Bait Detection Thresholds
  # =============================================================================

  @doc "Returns the ISK threshold for cheap/expendable ships (100M)."
  @spec bait_cheap_ship_threshold() :: integer()
  def bait_cheap_ship_threshold, do: @bait_cheap_ship_threshold

  @doc "Returns the minimum deaths required for bait analysis (3)."
  @spec bait_min_deaths() :: integer()
  def bait_min_deaths, do: @bait_min_deaths

  @doc "Returns the cheap death percentage threshold (60%)."
  @spec bait_cheap_death_threshold() :: integer()
  def bait_cheap_death_threshold, do: @bait_cheap_death_threshold

  @doc "Returns the low damage contribution threshold (5%)."
  @spec bait_low_damage_threshold() :: float()
  def bait_low_damage_threshold, do: @bait_low_damage_threshold

  @doc "Returns the corpmate kill correlation threshold (40%)."
  @spec bait_corp_kill_correlation() :: integer()
  def bait_corp_kill_correlation, do: @bait_corp_kill_correlation

  @doc "Returns the low final blow rate threshold (10%)."
  @spec bait_low_final_blow_rate() :: float()
  def bait_low_final_blow_rate, do: @bait_low_final_blow_rate

  @doc "Returns the positive trade ratio threshold (3.0x)."
  @spec bait_positive_trade_ratio() :: float()
  def bait_positive_trade_ratio, do: @bait_positive_trade_ratio

  @doc "Returns the outgunned attacker count threshold (5)."
  @spec bait_outgunned_threshold() :: integer()
  def bait_outgunned_threshold, do: @bait_outgunned_threshold

  @doc "Returns the bait score threshold for 'Confirmed bait pilot' (70)."
  @spec bait_score_confirmed() :: integer()
  def bait_score_confirmed, do: @bait_score_confirmed

  @doc "Returns the bait score threshold for 'Likely bait pilot' (50)."
  @spec bait_score_likely() :: integer()
  def bait_score_likely, do: @bait_score_likely

  @doc "Returns the bait score threshold for 'Possible bait pilot' (30)."
  @spec bait_score_possible() :: integer()
  def bait_score_possible, do: @bait_score_possible

  @doc """
  Classifies a bait score into a label.
  """
  @spec classify_bait_score(number()) :: String.t()
  def classify_bait_score(score) when is_number(score) do
    cond do
      score >= @bait_score_confirmed -> "Confirmed bait pilot"
      score >= @bait_score_likely -> "Likely bait pilot"
      score >= @bait_score_possible -> "Possible bait pilot"
      true -> "No bait indicators"
    end
  end

  def classify_bait_score(_), do: "No bait indicators"

  # =============================================================================
  # Public API - Target Assessment Thresholds
  # =============================================================================

  @doc "Returns the capital hunter threshold (30%)."
  @spec target_capital_threshold() :: integer()
  def target_capital_threshold, do: @target_capital_threshold

  @doc "Returns the highsec ganker threshold (60%)."
  @spec target_highsec_threshold() :: integer()
  def target_highsec_threshold, do: @target_highsec_threshold

  @doc "Returns the industrial hunter threshold (40%)."
  @spec target_industrial_threshold() :: integer()
  def target_industrial_threshold, do: @target_industrial_threshold

  @doc "Returns the wormhole hunter threshold (60%)."
  @spec target_wormhole_threshold() :: integer()
  def target_wormhole_threshold, do: @target_wormhole_threshold

  @doc "Returns the solo hunter threshold (70%)."
  @spec target_solo_threshold() :: integer()
  def target_solo_threshold, do: @target_solo_threshold

  @doc "Returns the pod hunter threshold (20%)."
  @spec target_pod_threshold() :: integer()
  def target_pod_threshold, do: @target_pod_threshold

  @doc "Returns the elite hunter ISK threshold (500M). Pilots with average victim value above this are elite hunters."
  @spec elite_hunter_isk() :: integer()
  def elite_hunter_isk, do: @elite_hunter_isk

  @doc "Returns the standard combatant ISK threshold (100M). Pilots with average victim value above this are standard combatants."
  @spec standard_combatant_isk() :: integer()
  def standard_combatant_isk, do: @standard_combatant_isk

  @doc "Returns the casual PvPer ISK threshold (20M). Pilots with average victim value above this are casual PvPers, below are opportunists."
  @spec casual_pvper_isk() :: integer()
  def casual_pvper_isk, do: @casual_pvper_isk

  @doc "Returns the mining ship group IDs."
  @spec mining_group_ids() :: [integer()]
  def mining_group_ids, do: @mining_group_ids

  @doc "Returns the industrial ship group IDs."
  @spec industrial_group_ids() :: [integer()]
  def industrial_group_ids, do: @industrial_group_ids

  @doc "Returns the capsule type ID (670)."
  @spec capsule_type_id() :: integer()
  def capsule_type_id, do: @capsule_type_id

  @doc "Returns the capsule group ID (29)."
  @spec capsule_group_id() :: integer()
  def capsule_group_id, do: @capsule_group_id

  @doc """
  Checks if a group ID represents a mining ship.
  """
  @spec mining_group?(integer()) :: boolean()
  def mining_group?(group_id) when is_integer(group_id) do
    group_id in @mining_group_ids
  end

  def mining_group?(_), do: false

  @doc """
  Checks if a group ID represents an industrial ship.
  """
  @spec industrial_group?(integer()) :: boolean()
  def industrial_group?(group_id) when is_integer(group_id) do
    group_id in @industrial_group_ids
  end

  def industrial_group?(_), do: false
end
