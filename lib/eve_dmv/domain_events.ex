defmodule EveDmv.DomainEvents do
  @moduledoc """
  Domain events for inter-context communication in the EVE DMV system.

  Events are the primary mechanism for bounded contexts to communicate
  without creating direct dependencies. Each event should be self-contained
  with all necessary data for subscribers to process it.
  """

  # Killmail Processing Events

  defmodule KillmailReceived do
    @moduledoc """
    Published when a new killmail is received from the data feed.
    This is the raw killmail before any enrichment.
    """

    defstruct [
      :killmail_id,
      :hash,
      :occurred_at,
      :solar_system_id,
      :victim,
      :attackers,
      :zkb_data,
      :received_at,
      :raw_data,
      :killmail_time,
      :zkb_total_value,
      :timestamp
    ]

    @enforce_keys [:killmail_id, :hash, :occurred_at]

    @type t :: %__MODULE__{
            killmail_id: integer(),
            hash: String.t(),
            occurred_at: DateTime.t(),
            solar_system_id: integer() | nil,
            victim: map(),
            attackers: [map()],
            zkb_data: map() | nil,
            received_at: DateTime.t(),
            raw_data: map() | nil,
            killmail_time: DateTime.t() | nil,
            zkb_total_value: integer() | nil,
            timestamp: DateTime.t() | nil
          }
  end

  defmodule KillmailEnriched do
    @moduledoc """
    Published when a killmail has been fully enriched with additional data
    like names, locations, prices, etc.
    """

    defstruct [
      :killmail_id,
      :enriched_data,
      :enrichment_duration_ms,
      :timestamp
    ]

    @enforce_keys [:killmail_id, :enriched_data]

    @type t :: %__MODULE__{
            killmail_id: integer(),
            enriched_data: map(),
            enrichment_duration_ms: integer() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule KillmailFailed do
    @moduledoc """
    Published when killmail processing fails at any stage.
    """

    defstruct [
      :killmail_id,
      :reason,
      :stage,
      :error_details,
      :timestamp
    ]

    @enforce_keys [:killmail_id, :reason, :stage]

    @type t :: %__MODULE__{
            killmail_id: integer(),
            reason: atom() | String.t(),
            stage: :ingestion | :enrichment | :storage,
            error_details: map() | nil,
            timestamp: DateTime.t()
          }
  end

  # Combat Intelligence Events

  defmodule BattleAnalysisComplete do
    @moduledoc """
    Published when battle analysis is completed.
    """

    defstruct [
      :battle_id,
      :battle_type,
      :participant_count,
      :isk_destroyed,
      :duration_seconds,
      :winner,
      :analysis_results,
      :timestamp
    ]

    @enforce_keys [:battle_id, :battle_type, :participant_count, :isk_destroyed]

    @type t :: %__MODULE__{
            battle_id: String.t(),
            battle_type: :small_gang | :fleet_fight | :large_scale_battle,
            participant_count: integer(),
            isk_destroyed: integer(),
            duration_seconds: integer() | nil,
            winner: :side_a | :side_b | :draw | nil,
            analysis_results: map() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule TacticalInsightGenerated do
    @moduledoc """
    Published when tactical insights are generated from battle analysis.
    """

    defstruct [
      :battle_id,
      :insight_type,
      :recommendations,
      :confidence_score,
      :tactical_patterns,
      :timestamp
    ]

    @enforce_keys [:battle_id, :insight_type, :recommendations]

    @type t :: %__MODULE__{
            battle_id: String.t(),
            insight_type: :recommendations | :patterns | :weaknesses,
            recommendations: map(),
            confidence_score: float() | nil,
            tactical_patterns: [map()] | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule CharacterAnalyzed do
    @moduledoc """
    Published when character intelligence analysis is completed.
    """

    defstruct [
      :character_id,
      :character_name,
      :analysis_type,
      :threat_level,
      :key_metrics,
      :recommendations,
      :timestamp
    ]

    @enforce_keys [:character_id, :character_name, :analysis_type]

    @type t :: %__MODULE__{
            character_id: integer(),
            character_name: String.t(),
            analysis_type: :full | :quick | :threat_only,
            threat_level: :minimal | :low | :medium | :high | :critical,
            key_metrics: map(),
            recommendations: [String.t()],
            timestamp: DateTime.t()
          }
  end

  defmodule CorporationAnalyzed do
    @moduledoc """
    Published when corporation intelligence analysis is completed.
    """

    defstruct [
      :corporation_id,
      :corporation_name,
      :member_count,
      :activity_metrics,
      :timezone_coverage,
      :top_threats,
      :timestamp
    ]

    @enforce_keys [:corporation_id, :corporation_name]

    @type t :: %__MODULE__{
            corporation_id: integer(),
            corporation_name: String.t(),
            member_count: integer() | nil,
            activity_metrics: map(),
            timezone_coverage: map(),
            top_threats: [map()],
            timestamp: DateTime.t()
          }
  end

  defmodule ThreatDetected do
    @moduledoc """
    Published when a significant threat is detected during analysis.
    """

    defstruct [
      :threat_id,
      :threat_type,
      :severity,
      :source_character_id,
      :source_character_name,
      :threat_details,
      :recommended_actions,
      :timestamp
    ]

    @enforce_keys [:threat_id, :threat_type, :severity]

    @type t :: %__MODULE__{
            threat_id: String.t(),
            threat_type: :hunter | :awoxer | :spy | :capital_pilot | :fleet_commander,
            severity: :low | :medium | :high | :critical,
            source_character_id: integer() | nil,
            source_character_name: String.t() | nil,
            threat_details: map(),
            recommended_actions: [String.t()],
            timestamp: DateTime.t()
          }
  end

  # Fleet Operations Events

  defmodule FleetAnalyzed do
    @moduledoc """
    Published when fleet composition analysis is completed.
    """

    defstruct [
      :fleet_id,
      :killmail_ids,
      :participant_count,
      :fleet_composition,
      :doctrine_compliance,
      :effectiveness_score,
      :analysis_results,
      :timestamp
    ]

    @enforce_keys [:fleet_id, :analysis_results]

    @type t :: %__MODULE__{
            fleet_id: String.t(),
            killmail_ids: [integer()],
            participant_count: integer(),
            fleet_composition: map(),
            doctrine_compliance: float(),
            effectiveness_score: float(),
            analysis_results: map(),
            timestamp: DateTime.t()
          }
  end

  defmodule DoctrineValidated do
    @moduledoc """
    Published when doctrine compliance validation is completed.
    """

    defstruct [
      :doctrine_name,
      :ships_analyzed,
      :compliance_score,
      :validation_results,
      :missing_roles,
      :timestamp
    ]

    @enforce_keys [:doctrine_name, :validation_results]

    @type t :: %__MODULE__{
            doctrine_name: String.t(),
            ships_analyzed: [map()],
            compliance_score: float(),
            validation_results: map(),
            missing_roles: [String.t()],
            timestamp: DateTime.t()
          }
  end

  # Wormhole Operations Events

  defmodule ChainThreatDetected do
    @moduledoc """
    Published when a threat is detected in the wormhole chain.
    """

    defstruct [
      :map_id,
      :system_id,
      :threat_level,
      :pilot_count,
      :hostile_count,
      :threat_details,
      :timestamp
    ]

    @enforce_keys [:map_id, :system_id, :threat_level]

    @type t :: %__MODULE__{
            map_id: String.t(),
            system_id: integer(),
            threat_level: :low | :medium | :high | :critical,
            pilot_count: integer() | nil,
            hostile_count: integer() | nil,
            threat_details: map() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule HostileMovement do
    @moduledoc """
    Published when hostile movement is detected in the wormhole chain.
    """

    defstruct [
      :system_id,
      :character_id,
      :character_name,
      :movement_type,
      :threat_level,
      :timestamp
    ]

    @enforce_keys [:system_id, :character_id]

    @type t :: %__MODULE__{
            system_id: integer(),
            character_id: integer(),
            character_name: String.t() | nil,
            movement_type: :jump | :dock | :undock | :warp,
            threat_level: :low | :medium | :high | :critical,
            timestamp: DateTime.t()
          }
  end

  defmodule ChainActivityPrediction do
    @moduledoc """
    Published when chain activity predictions are updated.
    """

    defstruct [
      :map_id,
      :prediction_type,
      :predicted_activity,
      :confidence_score,
      :time_window,
      :timestamp
    ]

    @enforce_keys [:map_id, :prediction_type]

    @type t :: %__MODULE__{
            map_id: String.t(),
            prediction_type: :traffic | :threat | :opportunity,
            predicted_activity: map(),
            confidence_score: float() | nil,
            time_window: map() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule ChainUpdated do
    @moduledoc """
    Published when wormhole chain topology is updated.
    """

    defstruct [
      :chain_id,
      :update_type,
      :systems_added,
      :systems_removed,
      :connections_changed,
      :chain_depth,
      :timestamp
    ]

    @enforce_keys [:chain_id, :update_type]

    @type t :: %__MODULE__{
            chain_id: String.t(),
            update_type: :connection_added | :connection_removed | :chain_cleared | :mass_updated,
            systems_added: [String.t()],
            systems_removed: [String.t()],
            connections_changed: [map()],
            chain_depth: integer(),
            timestamp: DateTime.t()
          }
  end

  defmodule VettingCompleted do
    @moduledoc """
    Published when wormhole recruitment vetting is completed.
    """

    defstruct [
      :character_id,
      :character_name,
      :recommendation,
      :risk_assessment,
      :experience_metrics,
      :red_flags,
      :green_flags,
      :timestamp
    ]

    @enforce_keys [:character_id, :character_name, :recommendation]

    @type t :: %__MODULE__{
            character_id: integer(),
            character_name: String.t(),
            recommendation: :approve | :reject | :conditional | :review,
            risk_assessment: map(),
            experience_metrics: map(),
            red_flags: [map()],
            green_flags: [map()],
            timestamp: DateTime.t()
          }
  end

  # Add alias for VettingComplete (used in code but defined as VettingCompleted)
  defmodule VettingComplete do
    @moduledoc """
    Alias for VettingCompleted event for backward compatibility.
    """
    defstruct [
      :character_id,
      :character_name,
      :recommendation,
      :risk_assessment,
      :experience_metrics,
      :red_flags,
      :green_flags,
      :timestamp
    ]
  end

  defmodule FleetAnalysisComplete do
    @moduledoc """
    Published when fleet analysis is completed.
    """

    defstruct [
      :engagement_id,
      :analysis_type,
      :results,
      :fleet_id,
      :fleet_commander,
      :participant_count,
      :effectiveness_score,
      :timestamp
    ]

    @enforce_keys [:engagement_id, :analysis_type, :results]

    @type t :: %__MODULE__{
            engagement_id: String.t(),
            analysis_type: atom(),
            results: map(),
            fleet_id: String.t() | nil,
            fleet_commander: String.t() | nil,
            participant_count: integer() | nil,
            effectiveness_score: float() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule SurveillanceMatch do
    @moduledoc """
    Published when a surveillance profile matches a killmail.
    """

    defstruct [
      :profile_id,
      :killmail_id,
      :match_type,
      :character_id,
      :character_name,
      :match_details,
      :confidence_score,
      :timestamp
    ]

    @enforce_keys [:profile_id, :killmail_id, :match_type]

    @type t :: %__MODULE__{
            profile_id: String.t(),
            killmail_id: integer(),
            match_type: :character | :corporation | :alliance | :ship_type | :location,
            character_id: integer() | nil,
            character_name: String.t() | nil,
            match_details: map(),
            confidence_score: float() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule SurveillanceAlert do
    @moduledoc """
    Published when a surveillance alert is triggered.
    """

    defstruct [
      :alert_id,
      :alert_type,
      :priority,
      :title,
      :message,
      :character_id,
      :character_name,
      :profile_id,
      :match_data,
      :timestamp
    ]

    @enforce_keys [:alert_id, :alert_type, :priority]

    @type t :: %__MODULE__{
            alert_id: String.t(),
            alert_type: :character_match | :threat_detected | :watch_list,
            priority: :low | :medium | :high | :critical,
            title: String.t() | nil,
            message: String.t() | nil,
            character_id: integer() | nil,
            character_name: String.t() | nil,
            profile_id: String.t() | nil,
            match_data: map() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule MassCalculated do
    @moduledoc """
    Published when wormhole mass calculations are updated.
    """

    defstruct [
      :wormhole_id,
      :connection_id,
      :total_mass,
      :remaining_mass,
      :mass_status,
      :ships_passed,
      :timestamp
    ]

    @enforce_keys [:wormhole_id, :total_mass, :remaining_mass]

    @type t :: %__MODULE__{
            wormhole_id: String.t(),
            connection_id: String.t() | nil,
            total_mass: integer(),
            remaining_mass: integer(),
            mass_status: :stable | :reduced | :critical | :collapsed,
            ships_passed: [map()],
            timestamp: DateTime.t()
          }
  end

  # Surveillance Events

  defmodule MatchFound do
    @moduledoc """
    Published when a surveillance profile matches a killmail.
    """

    defstruct [
      :match_id,
      :profile_id,
      :profile_name,
      :killmail_id,
      :match_type,
      :confidence_score,
      :matched_criteria,
      :timestamp
    ]

    @enforce_keys [:match_id, :profile_id, :killmail_id]

    @type t :: %__MODULE__{
            match_id: String.t(),
            profile_id: String.t(),
            profile_name: String.t() | nil,
            killmail_id: integer(),
            match_type: :victim | :attacker | :location | :ship_type,
            confidence_score: float(),
            matched_criteria: map(),
            timestamp: DateTime.t()
          }
  end

  defmodule AlertTriggered do
    @moduledoc """
    Published when a surveillance alert is triggered.
    """

    defstruct [
      :alert_id,
      :alert_type,
      :severity,
      :profile_id,
      :trigger_details,
      :notification_channels,
      :timestamp
    ]

    @enforce_keys [:alert_id, :alert_type, :severity]

    @type t :: %__MODULE__{
            alert_id: String.t(),
            alert_type: :immediate | :summary | :threshold_exceeded,
            severity: :info | :warning | :critical,
            profile_id: String.t() | nil,
            trigger_details: map(),
            notification_channels: [atom()],
            timestamp: DateTime.t()
          }
  end

  # Market Intelligence Events

  defmodule PriceUpdated do
    @moduledoc """
    Published when item prices are updated.
    """

    defstruct [
      :type_id,
      :type_name,
      :price_data,
      :source,
      :region_id,
      :timestamp
    ]

    @enforce_keys [:type_id, :price_data]

    @type t :: %__MODULE__{
            type_id: integer(),
            type_name: String.t() | nil,
            price_data: map(),
            source: :janice | :mutamarket | :esi | :aggregate,
            region_id: integer() | nil,
            timestamp: DateTime.t()
          }
  end

  defmodule MarketAnalyzed do
    @moduledoc """
    Published when market analysis is completed.
    """

    defstruct [
      :analysis_id,
      :analysis_type,
      :item_types_analyzed,
      :market_trends,
      :price_anomalies,
      :recommendations,
      :timestamp
    ]

    @enforce_keys [:analysis_id, :analysis_type]

    @type t :: %__MODULE__{
            analysis_id: String.t(),
            analysis_type: :kill_value | :fleet_value | :market_trend,
            item_types_analyzed: [integer()],
            market_trends: map(),
            price_anomalies: [map()],
            recommendations: [String.t()],
            timestamp: DateTime.t()
          }
  end

  # EVE Universe Events

  defmodule StaticDataUpdated do
    @moduledoc """
    Published when EVE static data is updated.
    """

    defstruct [
      :update_type,
      :affected_count,
      :data_version,
      :categories_updated,
      :timestamp
    ]

    @enforce_keys [:update_type, :affected_count]

    @type t :: %__MODULE__{
            update_type: :full | :partial | :patch,
            affected_count: integer(),
            data_version: String.t() | nil,
            categories_updated: [atom()],
            timestamp: DateTime.t()
          }
  end

  # Event Helpers

  @doc """
  Create a new event with automatic timestamp.
  """
  def new(event_module, params) do
    struct!(event_module, Map.put(params, :timestamp, DateTime.utc_now()))
  end

  @doc """
  Get the event type name from an event struct.
  """
  def event_type(%module{}), do: module

  @doc """
  Serialize an event to a map for storage or transmission.
  """
  def serialize(event) do
    event
    |> Map.from_struct()
    |> Map.put(:__type__, event.__struct__ |> Module.split() |> List.last())
  end

  @doc """
  Deserialize a map back to an event struct.
  """
  def deserialize(data) do
    type = Map.get(data, :__type__) || Map.get(data, "__type__")

    event_module = Module.safe_concat(__MODULE__, type)

    struct(event_module, data)
  end
end
