defmodule EveDmv.Intelligence.Events do
  @moduledoc """
  Domain events for intelligence system real-time updates.

  These events are published when intelligence data changes and need to be 
  broadcast to connected clients for real-time UI updates.
  """

  defmodule ThreatLevelUpdated do
    @moduledoc """
    Published when a character's threat level changes significantly.
    """

    @enforce_keys [:character_id, :new_threat_level, :previous_threat_level, :updated_at]
    defstruct [
      :character_id,
      :new_threat_level,
      :previous_threat_level,
      :updated_at,
      # What caused the threat level change
      :analysis_factors,
      # Where the threat was detected
      :system_id,
      # How confident we are in this assessment
      :confidence_score
    ]
  end

  defmodule BattleDetected do
    @moduledoc """
    Published when a new battle is detected in real-time.
    """

    @enforce_keys [:battle_id, :system_id, :detected_at, :participant_count]
    defstruct [
      :battle_id,
      :system_id,
      :detected_at,
      :participant_count,
      # :small_gang, :medium_fleet, :large_fleet
      :estimated_scale,
      :involved_alliances,
      :isk_destroyed,
      # :developing, :concluded, :uncertain
      :battle_status
    ]
  end

  defmodule IntelligenceAlert do
    @moduledoc """
    Published for high-priority intelligence alerts requiring immediate attention.
    """

    @enforce_keys [:alert_id, :alert_type, :priority, :created_at]
    defstruct [
      :alert_id,
      # :hostile_activity, :cap_movement, :unusual_behavior, :system_breach
      :alert_type,
      # :low, :medium, :high, :critical
      :priority,
      :created_at,
      :expires_at,
      :title,
      :description,
      :related_character_ids,
      :related_system_ids,
      # What the user should do about this alert
      :action_required,
      # Additional context data
      :data
    ]
  end

  defmodule CharacterAnalysisUpdated do
    @moduledoc """
    Published when character analysis data is updated with new information.
    """

    @enforce_keys [:character_id, :updated_at, :analysis_type]
    defstruct [
      :character_id,
      :updated_at,
      # :behavior_pattern, :threat_assessment, :activity_tracking
      :analysis_type,
      :previous_data,
      :new_data,
      # List of significant changes detected
      :significant_changes,
      :confidence_level
    ]
  end

  defmodule SystemActivitySpikeDetected do
    @moduledoc """
    Published when unusual activity spikes are detected in a system.
    """

    @enforce_keys [:system_id, :detected_at, :activity_level, :baseline_level]
    defstruct [
      :system_id,
      :detected_at,
      # Current activity level
      :activity_level,
      # Normal baseline for comparison
      :baseline_level,
      # How much above normal (multiplier)
      :spike_magnitude,
      # :killmail_volume, :unique_visitors, :fleet_movement
      :activity_type,
      # How long the spike has been ongoing
      :duration_minutes,
      # Other events that might be related
      :related_events
    ]
  end

  defmodule ChainIntelligenceUpdate do
    @moduledoc """
    Published when wormhole chain intelligence data is updated.
    """

    @enforce_keys [:chain_id, :updated_at, :update_type]
    defstruct [
      :chain_id,
      :updated_at,
      # :new_connection, :connection_closed, :activity_detected, :threat_assessment
      :update_type,
      # List of system changes in the chain
      :system_changes,
      # Changes to threat assessment
      :threat_changes,
      # New wormhole signatures detected
      :new_signatures,
      # Pilot movement data if available
      :pilot_movements
    ]
  end

  defmodule VettingResultUpdated do
    @moduledoc """
    Published when character vetting status changes.
    """

    @enforce_keys [:character_id, :vetting_result, :updated_at]
    defstruct [
      :character_id,
      # :approved, :rejected, :flagged, :pending_review
      :vetting_result,
      :updated_at,
      :previous_result,
      # What influenced the vetting decision
      :vetting_factors,
      :reviewer_notes,
      :confidence_score,
      # When this vetting result expires
      :expires_at
    ]
  end

  defmodule FleetCompositionAnalyzed do
    @moduledoc """
    Published when a fleet composition analysis is completed.
    """

    @enforce_keys [:fleet_id, :system_id, :analyzed_at, :composition_type]
    defstruct [
      :fleet_id,
      :system_id,
      :analyzed_at,
      # :doctrine_identified, :mixed_fleet, :specialized_comp
      :composition_type,
      # Identified doctrine if any
      :doctrine_match,
      :effectiveness_rating,
      :threat_assessment,
      # Tactical recommendations
      :recommendations,
      :participant_count,
      :estimated_capabilities
    ]
  end
end
