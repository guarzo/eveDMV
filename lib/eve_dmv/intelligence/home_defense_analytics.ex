defmodule EveDmv.Intelligence.HomeDefenseAnalytics do
  @moduledoc """
  Analytics for wormhole corporation home defense capabilities.

  Tracks timezone coverage, member activity patterns, rage rolling participation,
  and response times to threats for comprehensive home defense assessment.
  """

  use Ash.Resource,
    domain: EveDmv.Domains.Intelligence,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("home_defense_analytics")
    repo(EveDmv.Repo)

    custom_indexes do
      # Optimize common lookups
      index([:corporation_id], unique: true)
      index([:alliance_id])
      index([:analysis_period_start])
      index([:analysis_period_end])
      index([:overall_defense_score])

      # GIN indexes for JSONB columns
      index([:timezone_coverage], name: "home_defense_timezone_coverage_gin_idx", using: "gin")

      index([:rolling_participation],
        name: "home_defense_rolling_participation_gin_idx",
        using: "gin"
      )

      index([:response_metrics], name: "home_defense_response_metrics_gin_idx", using: "gin")

      index([:member_activity_patterns],
        name: "home_defense_member_activity_gin_idx",
        using: "gin"
      )

      index([:defensive_capabilities], name: "home_defense_capabilities_gin_idx", using: "gin")
      index([:coverage_gaps], name: "home_defense_coverage_gaps_gin_idx", using: "gin")
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Corporation identification
    attribute(:corporation_id, :integer, allow_nil?: false, public?: true)
    attribute(:corporation_name, :string, allow_nil?: false, public?: true)
    attribute(:alliance_id, :integer, public?: true)
    attribute(:alliance_name, :string, public?: true)
    attribute(:home_system_id, :integer, public?: true)
    attribute(:home_system_name, :string, public?: true)

    # Analysis metadata
    attribute(:analysis_period_start, :utc_datetime, allow_nil?: false, public?: true)
    attribute(:analysis_period_end, :utc_datetime, allow_nil?: false, public?: true)
    # Character ID
    attribute(:analysis_requested_by, :integer, public?: true)
    attribute(:last_updated_at, :utc_datetime, default: &DateTime.utc_now/0, public?: true)

    # Overall scoring (0-100 scale)
    attribute(:overall_defense_score, :integer, default: 50, public?: true)
    attribute(:timezone_coverage_score, :integer, default: 0, public?: true)
    attribute(:response_time_score, :integer, default: 0, public?: true)
    attribute(:rolling_competency_score, :integer, default: 0, public?: true)
    attribute(:member_participation_score, :integer, default: 0, public?: true)

    # Timezone coverage analysis (JSONB)
    attribute(:timezone_coverage, :map, default: %{}, public?: true)
    # Format: %{
    #   "coverage_by_hour" => %{
    #     "0" => %{"pilots_online" => 3, "fc_available" => true, "logi_available" => true},
    #     "1" => %{"pilots_online" => 2, "fc_available" => false, "logi_available" => true},
    #     ...
    #   },
    #   "timezone_distribution" => %{
    #     "US_TZ" => %{"member_count" => 45, "active_count" => 38},
    #     "EU_TZ" => %{"member_count" => 32, "active_count" => 28},
    #     "AU_TZ" => %{"member_count" => 18, "active_count" => 15}
    #   },
    #   "critical_gaps" => [
    #     %{"start_hour" => 8, "end_hour" => 14, "severity" => "high", "description" => "No FC coverage"}
    #   ],
    #   "peak_strength_hours" => [18, 19, 20, 21, 22]
    # }

    # Rage rolling participation (JSONB)
    attribute(:rolling_participation, :map, default: %{}, public?: true)
    # Format: %{
    #   "total_rolling_ops" => 45,
    #   "member_participation" => %{
    #     "95465499" => %{
    #       "name" => "Pilot Name",
    #       "ops_attended" => 23,
    #       "participation_rate" => 0.51,
    #       "preferred_ships" => ["Higgs Anchor Battleship", "Rolling Cruiser"],
    #       "competency_rating" => 0.8
    #     }
    #   },
    #   "rolling_efficiency" => %{
    #     "avg_time_per_hole" => 145.5,
    #     "success_rate" => 0.94,
    #     "incidents" => 2,
    #     "collateral_damage" => 15000000
    #   },
    #   "hole_types_rolled" => %{
    #     "static_c4" => 23,
    #     "static_c5" => 15,
    #     "wandering_holes" => 7
    #   }
    # }

    # Response metrics (JSONB)
    attribute(:response_metrics, :map, default: %{}, public?: true)
    # Format: %{
    #   "threat_responses" => %{
    #     "avg_response_time_seconds" => 180,
    #     "fastest_response_seconds" => 45,
    #     "slowest_response_seconds" => 600,
    #     "response_rate" => 0.87
    #   },
    #   "home_defense_battles" => %{
    #     "total_defenses" => 12,
    #     "successful_defenses" => 9,
    #     "failed_defenses" => 2,
    #     "evaded_threats" => 1,
    #     "success_rate" => 0.75
    #   },
    #   "escalation_patterns" => %{
    #     "batphone_calls" => 5,
    #     "alliance_support" => 3,
    #     "successful_escalations" => 7,
    #     "avg_escalation_time" => 420
    #   },
    #   "threat_types_faced" => %{
    #     "solo_hunters" => 15,
    #     "small_gangs" => 8,
    #     "eviction_scouts" => 3,
    #     "major_threats" => 1
    #   }
    # }

    # Member activity patterns (JSONB)
    attribute(:member_activity_patterns, :map, default: %{}, public?: true)
    # Format: %{
    #   "active_members" => 67,
    #   "total_members" => 89,
    #   "activity_by_timezone" => %{
    #     "US_TZ" => %{"peak_online" => 25, "avg_online" => 18, "min_online" => 8},
    #     "EU_TZ" => %{"peak_online" => 22, "avg_online" => 16, "min_online" => 5},
    #     "AU_TZ" => %{"peak_online" => 12, "avg_online" => 8, "min_online" => 2}
    #   },
    #   "role_coverage" => %{
    #     "fleet_commanders" => %{"total" => 8, "active" => 6, "coverage_hours" => 18},
    #     "logistics_pilots" => %{"total" => 15, "active" => 12, "coverage_hours" => 20},
    #     "tackle_specialists" => %{"total" => 25, "active" => 20, "coverage_hours" => 22},
    #     "dps_pilots" => %{"total" => 45, "active" => 38, "coverage_hours" => 24}
    #   },
    #   "engagement_readiness" => %{
    #     "always_ready" => 12,
    #     "usually_ready" => 23,
    #     "sometimes_ready" => 18,
    #     "rarely_ready" => 14
    #   }
    # }

    # Defensive capabilities (JSONB)
    attribute(:defensive_capabilities, :map, default: %{}, public?: true)
    # Format: %{
    #   "fleet_compositions" => %{
    #     "home_defense_doctrine" => %{
    #       "ships" => ["Guardian", "Damnation", "Legion", "Cerberus"],
    #       "pilot_requirement" => 8,
    #       "effectiveness_rating" => 0.85
    #     },
    #     "rapid_response" => %{
    #       "ships" => ["Interceptor", "Assault Frigate", "Heavy Interdictor"],
    #       "pilot_requirement" => 3,
    #       "effectiveness_rating" => 0.92
    #     }
    #   },
    #   "infrastructure" => %{
    #     "citadels" => 3,
    #     "weapon_timers" => 5,
    #     "tethering_points" => 8,
    #     "safe_spots" => 25
    #   },
    #   "intel_network" => %{
    #     "scout_coverage" => 0.78,
    #     "chain_monitoring" => true,
    #     "wanderer_integration" => true,
    #     "alert_systems" => ["discord", "in_game"]
    #   }
    # }

    # Coverage gaps and recommendations (JSONB)
    attribute(:coverage_gaps, :map, default: %{}, public?: true)
    # Format: %{
    #   "critical_weaknesses" => [
    #     %{
    #       "type" => "timezone_gap",
    #       "description" => "No FC coverage between 08:00-14:00 EVE",
    #       "severity" => "high",
    #       "recommendation" => "Recruit AU TZ FC"
    #     }
    #   ],
    #   "improvement_priorities" => [
    #     %{
    #       "area" => "response_time",
    #       "current_score" => 65,
    #       "target_score" => 85,
    #       "action_items" => ["Improve alert systems", "Pre-position response fleet"]
    #     }
    #   ],
    #   "threat_preparedness" => %{
    #     "eviction_readiness" => 0.7,
    #     "small_gang_response" => 0.9,
    #     "solo_hunter_deterrence" => 0.85
    #   }
    # }

    # Summary metrics
    attribute(:total_members_analyzed, :integer, default: 0, public?: true)
    attribute(:active_members_count, :integer, default: 0, public?: true)
    attribute(:critical_gaps_count, :integer, default: 0, public?: true)
    attribute(:data_completeness_percent, :integer, default: 0, public?: true)

    timestamps()
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :home_system_id,
        :home_system_name,
        :analysis_period_start,
        :analysis_period_end,
        :analysis_requested_by
      ])

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end)
    end

    update :update_analysis do
      description("Update home defense analysis with computed results")
      require_atomic?(false)

      accept([
        :overall_defense_score,
        :timezone_coverage_score,
        :response_time_score,
        :rolling_competency_score,
        :member_participation_score,
        :timezone_coverage,
        :rolling_participation,
        :response_metrics,
        :member_activity_patterns,
        :defensive_capabilities,
        :coverage_gaps,
        :total_members_analyzed,
        :active_members_count,
        :critical_gaps_count,
        :data_completeness_percent
      ])

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end)
    end

    # Querying actions
    read :by_corporation do
      description("Find analytics for a specific corporation")
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_alliance do
      description("Find analytics for corporations in an alliance")
      argument(:alliance_id, :integer, allow_nil?: false)
      filter(expr(alliance_id == ^arg(:alliance_id)))
    end

    read :low_defense_score do
      description("Find corporations with low defense scores")
      argument(:threshold, :integer, default: 60)
      filter(expr(overall_defense_score < ^arg(:threshold)))
    end

    read :critical_gaps do
      description("Find corporations with critical coverage gaps")
      filter(expr(critical_gaps_count > 0))
    end

    read :recent_analysis do
      description("Find recent analysis records")
      argument(:days, :integer, default: 30)

      filter(expr(last_updated_at >= ago(^arg(:days), :day)))
      prepare(build(sort: [last_updated_at: :desc]))
    end

    read :top_defenders do
      description("Find corporations with highest defense scores")
      argument(:limit, :integer, default: 10)

      filter(expr(overall_defense_score > 70))
      prepare(build(sort: [overall_defense_score: :desc]))
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update_analysis, action: :update_analysis)
    define(:get_by_corporation, action: :by_corporation, args: [:corporation_id])
    define(:get_by_alliance, action: :by_alliance, args: [:alliance_id])
    define(:get_low_defense, action: :low_defense_score, args: [:threshold])
    define(:get_critical_gaps, action: :critical_gaps)
    define(:get_recent, action: :recent_analysis, args: [:days])
    define(:get_top_defenders, action: :top_defenders, args: [:limit])
  end

  calculations do
    calculate :defense_rating, :string do
      description("Human-readable defense rating")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.overall_defense_score do
            score when score >= 85 -> "Excellent"
            score when score >= 70 -> "Good"
            score when score >= 55 -> "Fair"
            score when score >= 40 -> "Poor"
            _ -> "Critical"
          end
        end)
      end)
    end

    calculate :timezone_coverage_rating, :string do
      description("Timezone coverage assessment")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.timezone_coverage_score do
            score when score >= 80 -> "24/7 Coverage"
            score when score >= 60 -> "Good Coverage"
            score when score >= 40 -> "Partial Coverage"
            score when score >= 20 -> "Limited Coverage"
            _ -> "Poor Coverage"
          end
        end)
      end)
    end

    calculate :response_readiness, :string do
      description("Response time readiness level")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.response_time_score do
            score when score >= 85 -> "Rapid Response"
            score when score >= 70 -> "Quick Response"
            score when score >= 55 -> "Moderate Response"
            score when score >= 40 -> "Slow Response"
            _ -> "Poor Response"
          end
        end)
      end)
    end

    calculate :days_since_analysis, :integer do
      description("Days since last analysis")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.last_updated_at, :day)
        end)
      end)
    end

    calculate :member_activity_rate, :float do
      description("Percentage of active members")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          if record.total_members_analyzed > 0 do
            Float.round(record.active_members_count / record.total_members_analyzed * 100, 1)
          else
            0.0
          end
        end)
      end)
    end
  end

  preparations do
    prepare(
      build(
        load: [
          :defense_rating,
          :timezone_coverage_rating,
          :response_readiness,
          :days_since_analysis,
          :member_activity_rate
        ]
      )
    )
  end
end
