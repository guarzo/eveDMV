defmodule EveDmv.Repo.Migrations.AddEnumeratedCheckConstraints do
  @moduledoc """
  Adds check constraints for enumerated fields in analytics and surveillance tables.

  This ensures data integrity by restricting certain text fields to predefined values.
  """

  use Ecto.Migration

  def up do
    # WH Vetting status enumeration
    create constraint(:wh_vetting, :status_check,
      check: "status IN ('pending', 'approved', 'rejected', 'under_review', 'requires_manual_review')"
    )

    create constraint(:wh_vetting, :recommendation_check,
      check: "recommendation IN ('accept', 'reject', 'investigate', 'conditional_accept') OR recommendation IS NULL"
    )

    # WH Fleet Composition fleet size categories
    create constraint(:wh_fleet_composition, :fleet_size_category_check,
      check: "fleet_size_category IN ('micro', 'small', 'medium', 'large', 'capital', 'super_capital')"
    )

    # System Inhabitants threat level
    create constraint(:system_inhabitants, :threat_level_check,
      check: "threat_level IN ('unknown', 'friendly', 'neutral', 'hostile', 'extremely_hostile')"
    )

    # Surveillance Notifications
    create constraint(:surveillance_notifications, :notification_type_check,
      check: "notification_type IN ('profile_match', 'system_alert', 'threat_detected', 'killmail_alert', 'custom')"
    )

    create constraint(:surveillance_notifications, :priority_check,
      check: "priority IN ('low', 'normal', 'high', 'critical', 'urgent')"
    )

    # Ship Stats enumerations
    create constraint(:ship_stats, :ship_category_check,
      check: "ship_category IN ('frigate', 'destroyer', 'cruiser', 'battlecruiser', 'battleship', 'capital', 'industrial', 'special')"
    )

    create constraint(:ship_stats, :popularity_trend_check,
      check: "popularity_trend IN ('rising', 'stable', 'declining', 'unknown')"
    )

    create constraint(:ship_stats, :meta_tier_check,
      check: "meta_tier IN ('S', 'A', 'B', 'C', 'D', 'unranked')"
    )

    create constraint(:ship_stats, :role_classification_check,
      check: "role_classification IN ('dps', 'tank', 'support', 'logistics', 'ewar', 'tackle', 'mixed')"
    )

    # Player Stats enumerations
    create constraint(:player_stats, :preferred_gang_size_check,
      check: "preferred_gang_size IN ('solo', 'small_gang', 'medium_gang', 'large_gang', 'fleet')"
    )

    create constraint(:player_stats, :primary_activity_check,
      check: "primary_activity IN ('solo_pvp', 'small_gang', 'fleet_pvp', 'ratting', 'mining', 'exploration', 'trading', 'mixed')"
    )

    # Member Activity Intelligence
    create constraint(:member_activity_intelligence, :activity_trend_check,
      check: "activity_trend IN ('increasing', 'stable', 'decreasing', 'volatile', 'unknown')"
    )

    # EVE Solar Systems security class
    create constraint(:eve_solar_systems, :security_class_check,
      check: "security_class IN ('highsec', 'lowsec', 'nullsec', 'wormhole', 'abyssal', 'unknown') OR security_class IS NULL"
    )

    # Chain Connections enumerations
    create constraint(:chain_connections, :connection_type_check,
      check: "connection_type IN ('wormhole', 'stargate', 'cyno', 'bridge', 'unknown')"
    )

    create constraint(:chain_connections, :mass_status_check,
      check: "mass_status IN ('stable', 'destab', 'critical', 'unknown')"
    )

    create constraint(:chain_connections, :time_status_check,
      check: "time_status IN ('stable', 'beginning_eol', 'eol', 'unknown')"
    )

    # Character Stats enumerations (if they have text fields)
    create constraint(:character_stats, :batphone_probability_check,
      check: "batphone_probability IN ('low', 'medium', 'high', 'very_high', 'unknown') OR batphone_probability IS NULL"
    )

    create constraint(:character_stats, :prime_timezone_check,
      check: "prime_timezone ~ '^[A-Z]{3,4}$' OR prime_timezone IS NULL"
    )
  end

  def down do
    # Drop all check constraints in reverse order
    drop constraint(:character_stats, :prime_timezone_check)
    drop constraint(:character_stats, :batphone_probability_check)
    drop constraint(:chain_connections, :time_status_check)
    drop constraint(:chain_connections, :mass_status_check)
    drop constraint(:chain_connections, :connection_type_check)
    drop constraint(:eve_solar_systems, :security_class_check)
    drop constraint(:member_activity_intelligence, :activity_trend_check)
    drop constraint(:player_stats, :primary_activity_check)
    drop constraint(:player_stats, :preferred_gang_size_check)
    drop constraint(:ship_stats, :role_classification_check)
    drop constraint(:ship_stats, :meta_tier_check)
    drop constraint(:ship_stats, :popularity_trend_check)
    drop constraint(:ship_stats, :ship_category_check)
    drop constraint(:surveillance_notifications, :priority_check)
    drop constraint(:surveillance_notifications, :notification_type_check)
    drop constraint(:system_inhabitants, :threat_level_check)
    drop constraint(:wh_fleet_composition, :fleet_size_category_check)
    drop constraint(:wh_vetting, :recommendation_check)
    drop constraint(:wh_vetting, :status_check)
  end
end