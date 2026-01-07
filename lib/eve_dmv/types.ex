defmodule EveDmv.Types do
  @moduledoc """
  Shared type definitions for use across the application.

  Centralizes common types to ensure consistency and enable
  better Dialyzer analysis.

  ## Usage

  Use these types in your module specs:

      alias EveDmv.Types

      @spec get_character(Types.character_id()) :: Types.result(map())
      def get_character(character_id) do
        # ...
      end

  Or import specific types:

      @type character_id :: EveDmv.Types.character_id()
  """

  # Basic EVE Online identifiers
  @typedoc "EVE Online character ID"
  @type character_id :: pos_integer()

  @typedoc "EVE Online corporation ID"
  @type corporation_id :: pos_integer()

  @typedoc "EVE Online alliance ID"
  @type alliance_id :: pos_integer()

  @typedoc "EVE Online killmail ID"
  @type killmail_id :: pos_integer()

  @typedoc "EVE Online solar system ID"
  @type system_id :: pos_integer()

  @typedoc "EVE Online item type ID"
  @type type_id :: pos_integer()

  @typedoc "EVE Online region ID"
  @type region_id :: pos_integer()

  @typedoc "EVE Online constellation ID"
  @type constellation_id :: pos_integer()

  # EVE-specific enums
  @typedoc "Security classification from SDE security_class field"
  @type security_class :: :highsec | :lowsec | :nullsec | :wormhole | :unknown

  @typedoc "Entity type for surveillance and intelligence"
  @type entity_type :: :character | :corporation | :alliance | :system

  # Analysis results
  @typedoc "Threat level classification"
  @type threat_level :: :minimal | :low | :moderate | :high | :very_high | :extreme

  @typedoc "Activity period based on UTC hour"
  @type activity_period :: :morning | :afternoon | :evening | :night

  @typedoc "Trend direction for predictive analysis"
  @type trend_direction :: :increasing | :decreasing | :stable | :insufficient_data

  @typedoc "Momentum strength classification"
  @type momentum_strength :: :strong | :moderate | :weak | :minimal

  @typedoc "Ship role classification"
  @type ship_role ::
          :dps
          | :tackle
          | :logistics
          | :ewar
          | :command
          | :recon
          | :interdictor
          | :heavy_assault
          | :unknown

  @typedoc "Ship class/size classification"
  @type ship_class ::
          :frigate | :destroyer | :cruiser | :battlecruiser | :battleship | :capital | :unknown

  # Value types
  @typedoc "ISK currency amount (non-negative integer)"
  @type isk_amount :: non_neg_integer()

  @typedoc "System security status (float between -1.0 and 1.0)"
  @type security_status :: float()

  @typedoc "Damage amount in hit points"
  @type damage_amount :: non_neg_integer()

  # Common return types
  @typedoc "Success result wrapper"
  @type ok_result(t) :: {:ok, t}

  @typedoc "Error result with reason"
  @type error_result :: {:error, atom() | {atom(), any()}}

  @typedoc "Standard result type"
  @type result(t) :: ok_result(t) | error_result()

  @typedoc "Result with no success value (just :ok on success)"
  @type void_result :: :ok | error_result()

  @typedoc "Optional value that may be nil"
  @type maybe(t) :: t | nil

  @typedoc "Generic options keyword list"
  @type opts :: keyword()

  @typedoc "Pagination options"
  @type pagination_opts :: %{
          optional(:page) => pos_integer(),
          optional(:page_size) => pos_integer(),
          optional(:offset) => non_neg_integer(),
          optional(:limit) => pos_integer()
        }

  @typedoc "Time range specification"
  @type time_range ::
          :last_hour
          | :last_24h
          | :last_7d
          | :last_30d
          | :last_90d
          | {DateTime.t(), DateTime.t()}

  # Combat and threat statistics
  @typedoc "Basic combat statistics"
  @type combat_stats :: %{
          kills: non_neg_integer(),
          deaths: non_neg_integer(),
          isk_destroyed: float(),
          isk_lost: float()
        }

  @typedoc "Efficiency statistics"
  @type efficiency_stats :: %{
          kd_ratio: float(),
          isk_efficiency: float(),
          efficiency: float()
        }

  @typedoc "Dimensional threat scores"
  @type dimensional_scores :: %{
          combat_skill: score_component(),
          ship_mastery: score_component(),
          gang_effectiveness: score_component(),
          unpredictability: score_component(),
          recent_activity: score_component()
        }

  @typedoc "Score component with normalized value"
  @type score_component :: %{
          required(:normalized_score) => float(),
          optional(atom()) => any()
        }

  @typedoc "Threat assessment result"
  @type threat_assessment :: %{
          character_id: character_id(),
          threat_score: float(),
          threat_level: threat_level(),
          confidence: float(),
          analysis_window_days: pos_integer(),
          total_killmails: non_neg_integer(),
          dimensional_scores: dimensional_scores(),
          analyzed_at: DateTime.t()
        }

  # Correlation analysis types
  @typedoc "Correlation coefficient between -1.0 and 1.0"
  @type correlation_coefficient :: float()

  @typedoc "Activity correlation result"
  @type activity_correlation :: %{
          correlation_strength: float(),
          correlated_patterns: map(),
          activity_synchronization: map(),
          temporal_correlations: map()
        }

  # Gang/Fleet analysis types
  @typedoc "Gang synergy analysis result"
  @type gang_synergy :: %{
          coordination_score: float(),
          shared_victories: non_neg_integer(),
          role_compatibility: float(),
          success_metrics: map(),
          temporal_coordination: map(),
          engagement_patterns: map()
        }

  @typedoc "Gang effectiveness score result"
  @type gang_effectiveness_score :: %{
          raw_score: float(),
          normalized_score: float(),
          components: map(),
          gang_patterns: map(),
          insights: [String.t()]
        }

  # Predictive analysis types
  @typedoc "Historical score data point"
  @type historical_score :: {Date.t() | DateTime.t(), float()}

  @typedoc "Trend analysis result"
  @type trend_analysis :: %{
          direction: trend_direction(),
          strength: float()
        }

  @typedoc "Prediction result"
  @type prediction :: %{
          score: float(),
          confidence: float()
        }

  @typedoc "Threat evolution prediction"
  @type threat_evolution :: %{
          predicted_score: float(),
          confidence: float(),
          trend: trend_analysis(),
          prediction_window_days: pos_integer(),
          risk_indicators: [String.t()],
          recommendations: [String.t()]
        }

  @typedoc "Momentum analysis result"
  @type momentum_analysis :: %{
          momentum: float(),
          momentum_strength: momentum_strength(),
          recent_average: float(),
          baseline_average: float()
        }

  # Combat data types (for threat calculation input)
  @typedoc "Combat data for threat score calculation"
  @type combat_data :: %{
          character_id: character_id(),
          killmails: [map()],
          attacker_killmails: [map()],
          victim_killmails: [map()],
          analysis_period_days: pos_integer(),
          total_killmails: non_neg_integer()
        }

  # Battle analysis types
  @typedoc "Battle identifier (UUID string)"
  @type battle_id :: String.t()

  @typedoc "Ship identifier for performance tracking"
  @type ship_id :: pos_integer()

  # Fleet operations types
  @typedoc "Fleet participant data"
  @type participant :: %{
          required(:character_id) => pos_integer(),
          required(:ship_type_id) => pos_integer(),
          optional(:role) => atom()
        }

  @typedoc "Fleet data for analysis"
  @type fleet_data :: %{
          required(:participants) => [participant()],
          optional(:engagement_context) => atom(),
          optional(:doctrine_target) => String.t()
        }

  @typedoc "Fleet engagement data including killmails"
  @type engagement_data :: %{
          required(:engagement_id) => String.t(),
          required(:participants) => [participant()],
          required(:killmails) => [map()]
        }

  @typedoc "Doctrine identifier (UUID string)"
  @type doctrine_id :: String.t()

  @typedoc "Fleet doctrine definition"
  @type doctrine :: %{
          required(:id) => doctrine_id(),
          required(:name) => String.t(),
          optional(:description) => String.t(),
          optional(:ship_requirements) => map(),
          optional(:role_requirements) => map(),
          optional(:optional_ships) => [pos_integer()],
          optional(:mass_limits) => map(),
          optional(:is_active) => boolean()
        }

  # Surveillance types
  @typedoc "User identifier"
  @type user_id :: pos_integer()

  @typedoc "Surveillance profile identifier (UUID string)"
  @type profile_id :: String.t()

  @typedoc "Surveillance profile data"
  @type surveillance_profile :: %{
          required(:id) => profile_id(),
          required(:user_id) => user_id(),
          required(:name) => String.t(),
          optional(:criteria) => map(),
          optional(:is_active) => boolean()
        }

  @typedoc "Surveillance match data"
  @type surveillance_match :: %{
          required(:profile_id) => profile_id(),
          required(:matched_entity_id) => pos_integer(),
          required(:matched_at) => DateTime.t(),
          optional(:match_details) => map()
        }

  # Analysis result type alias for common patterns
  @typedoc "Standard analysis result with map data"
  @type analysis_result :: result(map())

  @typedoc "Standard list result"
  @type list_result(t) :: result([t])

  # Cache and monitoring types
  @typedoc "Cache statistics"
  @type cache_stats :: %{
          optional(:hit_count) => non_neg_integer(),
          optional(:miss_count) => non_neg_integer(),
          optional(:hit_rate) => float(),
          optional(:size) => non_neg_integer()
        }

  @typedoc "Health check result"
  @type health_check_result :: {:ok, map()} | {:error, term()}

  @typedoc "Side in a fleet engagement"
  @type fleet_side :: :attackers | :defenders | :all
end
