defmodule EveDmv.Intelligence.MemberActivityIntelligence do
  @moduledoc """
  Member activity intelligence and engagement tracking for wormhole corporations.

  Tracks participation in home defense operations, contribution to corp PvP activities,
  activity patterns, and early warning for member burnout or disengagement.
  """

  use Ash.Resource,
    domain: EveDmv.Domains.Intelligence,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("member_activity_intelligence")
    repo(EveDmv.Repo)

    custom_indexes do
      # Optimize common lookups
      index([:corporation_id])
      index([:character_id])
      index([:activity_period_start])
      index([:activity_period_end])
      index([:engagement_score])

      # GIN indexes for JSONB columns
      index([:activity_patterns], name: "member_activity_patterns_gin_idx", using: "gin")
      index([:participation_metrics], name: "member_participation_metrics_gin_idx", using: "gin")
      index([:warning_indicators], name: "member_warning_indicators_gin_idx", using: "gin")
      index([:timezone_analysis], name: "member_timezone_analysis_gin_idx", using: "gin")
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Member identification
    attribute(:character_id, :integer, allow_nil?: false, public?: true)
    attribute(:character_name, :string, allow_nil?: false, public?: true)
    attribute(:corporation_id, :integer, allow_nil?: false, public?: true)
    attribute(:corporation_name, :string, allow_nil?: false, public?: true)
    attribute(:alliance_id, :integer, public?: true)
    attribute(:alliance_name, :string, public?: true)

    # Analysis period
    attribute(:activity_period_start, :utc_datetime, allow_nil?: false, public?: true)
    attribute(:activity_period_end, :utc_datetime, allow_nil?: false, public?: true)
    attribute(:analysis_generated_at, :utc_datetime, default: &DateTime.utc_now/0, public?: true)

    # Activity metrics
    attribute(:total_pvp_kills, :integer, default: 0, public?: true)
    attribute(:total_pvp_losses, :integer, default: 0, public?: true)
    attribute(:home_defense_participations, :integer, default: 0, public?: true)
    attribute(:chain_operations_participations, :integer, default: 0, public?: true)
    attribute(:fleet_participations, :integer, default: 0, public?: true)
    attribute(:solo_activities, :integer, default: 0, public?: true)

    # Engagement scoring
    # 0.0-100.0
    attribute(:engagement_score, :float, default: 0.0, public?: true)
    # increasing, decreasing, stable, irregular
    attribute(:activity_trend, :string, default: "stable", public?: true)
    # 0-100
    attribute(:burnout_risk_score, :integer, default: 0, public?: true)
    # 0-100
    attribute(:disengagement_risk_score, :integer, default: 0, public?: true)

    # Activity patterns analysis (JSONB)
    attribute(:activity_patterns, :map, default: %{}, public?: true)
    # Format: %{
    #   "daily_activity" => %{
    #     "monday" => %{"kills" => 3, "participations" => 2, "hours_active" => 4.5},
    #     "tuesday" => %{"kills" => 1, "participations" => 1, "hours_active" => 2.0},
    #     "wednesday" => %{"kills" => 0, "participations" => 0, "hours_active" => 0.0},
    #     ...
    #   },
    #   "hourly_activity" => %{
    #     "00" => %{"activity_count" => 2, "avg_participation" => 0.8},
    #     "01" => %{"activity_count" => 1, "avg_participation" => 0.5},
    #     ...
    #   },
    #   "monthly_trends" => %{
    #     "2024-01" => %{"kills" => 45, "losses" => 12, "participations" => 28},
    #     "2024-02" => %{"kills" => 38, "losses" => 15, "participations" => 22},
    #     ...
    #   },
    #   "activity_streaks" => %{
    #     "current_active_streak_days" => 12,
    #     "longest_active_streak_days" => 28,
    #     "current_inactive_streak_days" => 0,
    #     "longest_inactive_streak_days" => 7
    #   }
    # }

    # Participation metrics (JSONB)
    attribute(:participation_metrics, :map, default: %{}, public?: true)
    # Format: %{
    #   "home_defense" => %{
    #     "total_opportunities" => 15,
    #     "participated" => 12,
    #     "participation_rate" => 0.8,
    #     "avg_response_time_minutes" => 8.5,
    #     "effectiveness_rating" => 0.85,
    #     "recent_participations" => [
    #       %{"date" => "2024-01-15T14:30:00Z", "outcome" => "successful", "role" => "dps"},
    #       %{"date" => "2024-01-12T09:15:00Z", "outcome" => "successful", "role" => "tackle"}
    #     ]
    #   },
    #   "fleet_operations" => %{
    #     "total_fleets_invited" => 25,
    #     "attended" => 18,
    #     "attendance_rate" => 0.72,
    #     "avg_fleet_duration_hours" => 2.3,
    #     "leadership_roles_filled" => 3,
    #     "preferred_ship_types" => ["HAC", "Logistics", "Tackle"],
    #     "performance_ratings" => %{
    #       "dps" => 0.8,
    #       "logistics" => 0.9,
    #       "tackle" => 0.75,
    #       "fc" => 0.6
    #     }
    #   },
    #   "chain_operations" => %{
    #     "scanning_contributions" => 45,
    #     "wormhole_rolling_participation" => 12,
    #     "eviction_participations" => 3,
    #     "chain_security_patrols" => 28,
    #     "intel_reports_submitted" => 67
    #   },
    #   "skill_development" => %{
    #     "new_ships_flown" => ["Loki", "Guardian"],
    #     "new_roles_attempted" => ["fleet_commander"],
    #     "training_queue_progress" => 0.85,
    #     "recommended_skills" => ["Cynosural Field Theory V", "Jump Drive Calibration V"]
    #   }
    # }

    # Early warning indicators (JSONB)
    attribute(:warning_indicators, :map, default: %{}, public?: true)
    # Format: %{
    #   "burnout_signals" => [
    #     %{
    #       "indicator" => "decreased_participation",
    #       "severity" => "medium",
    #       "description" => "Fleet participation dropped from 80% to 45% over last 30 days",
    #       "recommendation" => "Check in with member, suggest break or role change"
    #     },
    #     %{
    #       "indicator" => "increased_losses",
    #       "severity" => "low",
    #       "description" => "Loss rate increased by 15% indicating possible frustration",
    #       "recommendation" => "Offer mentoring or skill training suggestions"
    #     }
    #   ],
    #   "disengagement_signals" => [
    #     %{
    #       "indicator" => "reduced_communication",
    #       "severity" => "high",
    #       "description" => "No comms activity for 14+ days despite being online",
    #       "recommendation" => "Direct leadership outreach required"
    #     }
    #   ],
    #   "positive_trends" => [
    #     %{
    #       "indicator" => "skill_progression",
    #       "description" => "Completed 3 major skill training goals this month",
    #       "impact" => "Increased fleet effectiveness and member satisfaction"
    #     }
    #   ],
    #   "risk_assessment" => %{
    #     "overall_risk" => "low",
    #     "primary_concerns" => ["slight participation decline"],
    #     "protective_factors" => ["strong peer relationships", "active skill training"],
    #     "recommended_interventions" => ["informal check-in", "offer new role opportunities"]
    #   }
    # }

    # Timezone and availability analysis (JSONB)
    attribute(:timezone_analysis, :map, default: %{}, public?: true)
    # Format: %{
    #   "detected_timezone" => "US/Pacific",
    #   "confidence_score" => 0.92,
    #   "primary_activity_hours" => %{
    #     "weekday" => {"19:00", "23:30"},
    #     "weekend" => {"14:00", "02:00"}
    #   },
    #   "availability_windows" => [
    #     %{"day" => "monday", "start" => "19:00", "end" => "23:00", "reliability" => 0.85},
    #     %{"day" => "friday", "start" => "18:00", "end" => "01:00", "reliability" => 0.92}
    #   ],
    #   "coverage_contribution" => %{
    #     "eu_coverage" => 0.15,
    #     "us_coverage" => 0.78,
    #     "au_coverage" => 0.05,
    #     "critical_gaps_filled" => ["US late evening", "weekend prime time"]
    #   },
    #   "activity_consistency" => %{
    #     "weekly_consistency" => 0.75,
    #     "schedule_predictability" => 0.68,
    #     "seasonal_patterns" => ["more active in winter months"]
    #   }
    # }

    # Comparative metrics
    # 1-100
    attribute(:corp_percentile_ranking, :integer, default: 50, public?: true)
    # -2.0 to 2.0 (std deviations)
    attribute(:peer_comparison_score, :float, default: 0.0, public?: true)

    timestamps()
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :character_id,
        :character_name,
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :activity_period_start,
        :activity_period_end
      ])

      validate(fn changeset, _context ->
        start_date = Ash.Changeset.get_attribute(changeset, :activity_period_start)
        end_date = Ash.Changeset.get_attribute(changeset, :activity_period_end)

        if start_date && end_date && DateTime.compare(start_date, end_date) == :gt do
          {:error, field: :activity_period_end, message: "must be after activity_period_start"}
        else
          :ok
        end
      end)

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:analysis_generated_at, DateTime.utc_now())
      end)
    end

    update :update_analysis do
      description("Update member activity analysis data")
      require_atomic?(false)

      accept([
        :total_pvp_kills,
        :total_pvp_losses,
        :home_defense_participations,
        :chain_operations_participations,
        :fleet_participations,
        :solo_activities,
        :engagement_score,
        :activity_trend,
        :burnout_risk_score,
        :disengagement_risk_score,
        :activity_patterns,
        :participation_metrics,
        :warning_indicators,
        :timezone_analysis,
        :corp_percentile_ranking,
        :peer_comparison_score
      ])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:analysis_generated_at, DateTime.utc_now())
      end)
    end

    update :record_activity do
      description("Record new activity for member")
      require_atomic?(false)

      argument(:activity_type, :string, allow_nil?: false)
      argument(:activity_data, :map, default: %{})

      change(fn changeset, context ->
        activity_type = Ash.Changeset.get_argument(changeset, :activity_type)

        updated_changeset =
          case activity_type do
            "pvp_kill" ->
              current_kills = Ash.Changeset.get_attribute(changeset, :total_pvp_kills) || 0
              Ash.Changeset.change_attribute(changeset, :total_pvp_kills, current_kills + 1)

            "pvp_loss" ->
              current_losses = Ash.Changeset.get_attribute(changeset, :total_pvp_losses) || 0
              Ash.Changeset.change_attribute(changeset, :total_pvp_losses, current_losses + 1)

            "home_defense" ->
              current_participation =
                Ash.Changeset.get_attribute(changeset, :home_defense_participations) || 0

              Ash.Changeset.change_attribute(
                changeset,
                :home_defense_participations,
                current_participation + 1
              )

            "fleet_operation" ->
              current_participation =
                Ash.Changeset.get_attribute(changeset, :fleet_participations) || 0

              Ash.Changeset.change_attribute(
                changeset,
                :fleet_participations,
                current_participation + 1
              )

            "chain_operation" ->
              current_participation =
                Ash.Changeset.get_attribute(changeset, :chain_operations_participations) || 0

              Ash.Changeset.change_attribute(
                changeset,
                :chain_operations_participations,
                current_participation + 1
              )

            _ ->
              changeset
          end

        Ash.Changeset.change_attribute(
          updated_changeset,
          :analysis_generated_at,
          DateTime.utc_now()
        )
      end)
    end

    # Querying actions
    read :by_character do
      description("Find activity intelligence for a character")
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :by_corporation do
      description("Find member activity for a corporation")
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :high_engagement do
      description("Find highly engaged members")
      argument(:threshold, :float, default: 75.0)
      filter(expr(engagement_score >= ^arg(:threshold)))
    end

    read :at_risk_members do
      description("Find members at risk of burnout or disengagement")
      argument(:risk_threshold, :integer, default: 60)

      filter(
        expr(
          burnout_risk_score >= ^arg(:risk_threshold) or
            disengagement_risk_score >= ^arg(:risk_threshold)
        )
      )
    end

    read :activity_declining do
      description("Find members with declining activity trends")
      filter(expr(activity_trend == "decreasing"))
    end

    read :top_performers do
      description("Find top performing members by percentile ranking")
      argument(:percentile_threshold, :integer, default: 80)
      filter(expr(corp_percentile_ranking >= ^arg(:percentile_threshold)))
      prepare(build(sort: [corp_percentile_ranking: :desc]))
    end

    read :recent_analysis do
      description("Find recently updated member analysis")
      argument(:days, :integer, default: 7)
      filter(expr(analysis_generated_at >= ago(^arg(:days), :day)))
      prepare(build(sort: [analysis_generated_at: :desc]))
    end

    read :by_activity_period do
      description("Find member analysis for specific time period")
      argument(:start_date, :utc_datetime, allow_nil?: false)
      argument(:end_date, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          activity_period_start >= ^arg(:start_date) and
            activity_period_end <= ^arg(:end_date)
        )
      )
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update_analysis, action: :update_analysis)
    define(:record_activity, action: :record_activity, args: [:activity_type, :activity_data])
    define(:get_by_character, action: :by_character, args: [:character_id])
    define(:get_by_corporation, action: :by_corporation, args: [:corporation_id])
    define(:get_high_engagement, action: :high_engagement, args: [:threshold])
    define(:get_at_risk, action: :at_risk_members, args: [:risk_threshold])
    define(:get_declining, action: :activity_declining)
    define(:get_top_performers, action: :top_performers, args: [:percentile_threshold])
    define(:get_recent, action: :recent_analysis, args: [:days])
    define(:get_by_period, action: :by_activity_period, args: [:start_date, :end_date])
  end

  calculations do
    calculate :activity_status, :string do
      description("Overall member activity status")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          cond do
            record.engagement_score >= 80 -> "Highly Active"
            record.engagement_score >= 60 -> "Active"
            record.engagement_score >= 40 -> "Moderately Active"
            record.engagement_score >= 20 -> "Low Activity"
            true -> "Inactive"
          end
        end)
      end)
    end

    calculate :risk_level, :string do
      description("Member risk assessment level")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          max_risk = max(record.burnout_risk_score, record.disengagement_risk_score)

          cond do
            max_risk >= 80 -> "Critical"
            max_risk >= 60 -> "High"
            max_risk >= 40 -> "Medium"
            max_risk >= 20 -> "Low"
            true -> "Minimal"
          end
        end)
      end)
    end

    calculate :participation_rate, :float do
      description("Overall participation rate percentage")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          total_activities = record.total_pvp_kills + record.total_pvp_losses

          total_participations =
            record.home_defense_participations +
              record.chain_operations_participations +
              record.fleet_participations

          if total_activities > 0 do
            Float.round(total_participations / total_activities * 100, 1)
          else
            0.0
          end
        end)
      end)
    end

    calculate :activity_consistency, :string do
      description("Activity consistency rating")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          patterns = record.activity_patterns || %{}
          consistency = patterns["activity_consistency"] || %{}
          weekly_consistency = consistency["weekly_consistency"] || 0.0

          cond do
            weekly_consistency >= 0.8 -> "Very Consistent"
            weekly_consistency >= 0.6 -> "Consistent"
            weekly_consistency >= 0.4 -> "Somewhat Consistent"
            weekly_consistency >= 0.2 -> "Inconsistent"
            true -> "Very Inconsistent"
          end
        end)
      end)
    end

    calculate :days_since_analysis, :integer do
      description("Days since last analysis update")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.analysis_generated_at, :day)
        end)
      end)
    end

    calculate :primary_timezone, :string do
      description("Member's primary timezone")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          timezone_analysis = record.timezone_analysis || %{}
          timezone_analysis["detected_timezone"] || "Unknown"
        end)
      end)
    end
  end

  preparations do
    prepare(
      build(
        load: [
          :activity_status,
          :risk_level,
          :participation_rate,
          :activity_consistency,
          :days_since_analysis,
          :primary_timezone
        ]
      )
    )
  end
end
