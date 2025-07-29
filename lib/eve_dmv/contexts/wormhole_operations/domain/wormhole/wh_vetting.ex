defmodule EveDmv.Intelligence.Wormhole.Vetting do
  @moduledoc """
  Wormhole-specific vetting analysis for corporation recruitment.

  This resource provides comprehensive vetting information for evaluating
  potential recruits in wormhole corporations, focusing on J-space experience,
  security risks, and competency assessment.
  """

  use Ash.Resource,
    domain: EveDmv.Domains.Intelligence,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("wh_vetting")
    repo(EveDmv.Repo)

    custom_indexes do
      # Optimize common lookups
      index([:character_id], unique: true)
      index([:corporation_id])
      index([:overall_risk_score])
      index([:wh_experience_score])
      index([:inserted_at])

      # GIN indexes for JSONB columns
      index([:j_space_activity], name: "wh_vetting_j_space_activity_gin_idx", using: "gin")

      index([:eviction_associations],
        name: "wh_vetting_eviction_associations_gin_idx",
        using: "gin"
      )

      index([:alt_analysis], name: "wh_vetting_alt_analysis_gin_idx", using: "gin")
      index([:competency_metrics], name: "wh_vetting_competency_metrics_gin_idx", using: "gin")
      index([:risk_factors], name: "wh_vetting_risk_factors_gin_idx", using: "gin")
      index([:employment_history], name: "wh_vetting_employment_history_gin_idx", using: "gin")
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Character identification
    attribute(:character_id, :integer, allow_nil?: false, public?: true)
    attribute(:character_name, :string, allow_nil?: false, public?: true)
    attribute(:corporation_id, :integer, public?: true)
    attribute(:corporation_name, :string, public?: true)
    attribute(:alliance_id, :integer, public?: true)
    attribute(:alliance_name, :string, public?: true)

    # Vetting metadata
    # Character ID of requester
    attribute(:vetting_requested_by, :integer, public?: true)
    attribute(:vetting_requested_at, :utc_datetime, default: &DateTime.utc_now/0, public?: true)
    attribute(:last_updated_at, :utc_datetime, default: &DateTime.utc_now/0, public?: true)
    # pending, complete, failed
    attribute(:status, :string, default: "pending", public?: true)

    # Overall scoring (0-100 scale)
    # Lower is better
    attribute(:overall_risk_score, :integer, default: 50, public?: true)
    # Higher is better
    attribute(:wh_experience_score, :integer, default: 0, public?: true)
    # Higher is better
    attribute(:competency_score, :integer, default: 0, public?: true)
    # Higher is better
    attribute(:security_score, :integer, default: 50, public?: true)

    # J-space activity analysis (JSONB)
    attribute(:j_space_activity, :map, default: %{}, public?: true)
    # Format: %{
    #   "total_j_kills" => 145,
    #   "total_j_losses" => 23,
    #   "j_space_time_percent" => 78.5,
    #   "wh_classes_active" => [1, 2, 3, 4, 5, 6, 13],
    #   "home_holes" => [
    #     %{"system_id" => 31000142, "class" => 5, "duration_days" => 245, "confidence" => 0.9}
    #   ],
    #   "rolling_participation" => %{
    #     "times_rolled" => 67,
    #     "times_helped_roll" => 45,
    #     "rolling_competency" => 0.8
    #   },
    #   "wh_scanning_skills" => %{
    #     "probe_usage" => 234,
    #     "scan_success_rate" => 0.92,
    #     "deep_safe_usage" => true
    #   }
    # }

    # Eviction group detection (JSONB)
    attribute(:eviction_associations, :map, default: %{}, public?: true)
    # Format: %{
    #   "known_eviction_groups" => [
    #     %{"group_name" => "Group Name", "confidence" => 0.8, "last_seen" => "2024-01-15"}
    #   ],
    #   "eviction_participation" => %{
    #     "evictions_involved" => 3,
    #     "victim_corps" => ["Corp A", "Corp B"],
    #     "typical_role" => "dps"
    #   },
    #   "seed_scout_indicators" => %{
    #     "suspicious_applications" => 2,
    #     "timing_patterns" => ["joins_before_evictions"],
    #     "information_gathering" => true
    #   }
    # }

    # Alt character analysis (JSONB)
    attribute(:alt_analysis, :map, default: %{}, public?: true)
    # Format: %{
    #   "potential_alts" => [
    #     %{
    #       "character_id" => 95465499,
    #       "name" => "Alt Name",
    #       "confidence" => 0.7,
    #       "evidence" => ["same_ip", "login_patterns"]
    #     }
    #   ],
    #   "main_character_confidence" => 0.9,
    #   "account_age_days" => 1247,
    #   "character_bazaar_indicators" => %{
    #     "likely_purchased" => false,
    #     "skill_inconsistencies" => [],
    #     "name_history" => []
    #   }
    # }

    # Small gang competency (JSONB)
    attribute(:competency_metrics, :map, default: %{}, public?: true)
    # Format: %{
    #   "small_gang_performance" => %{
    #     "avg_gang_size" => 4.2,
    #     "preferred_size" => "2-8",
    #     "role_flexibility" => ["dps", "tackle", "ewar"],
    #     "fc_experience" => %{"times_fc" => 12, "success_rate" => 0.75}
    #   },
    #   "ship_specializations" => %{
    #     "primary_classes" => ["assault_frigates", "tactical_destroyers"],
    #     "doctrine_familiarity" => ["kitey", "brawling"],
    #     "capital_experience" => false
    #   },
    #   "wh_specific_skills" => %{
    #     "probe_scanning" => 5,
    #     "cloaking" => 5,
    #     "covops" => 4,
    #     "t3_cruisers" => 3
    #   }
    # }

    # Risk assessment (JSONB)
    attribute(:risk_factors, :map, default: %{}, public?: true)
    # Format: %{
    #   "security_flags" => [
    #     %{
    #       "type" => "suspicious_activity",
    #       "description" => "Multiple corp applications in 30 days",
    #       "severity" => "medium"
    #     }
    #   ],
    #   "behavioral_red_flags" => [
    #     "frequent_corp_hopping",
    #     "suspicious_timing"
    #   ],
    #   "awox_risk" => %{
    #     "probability" => 0.15,
    #     "indicators" => ["new_player", "no_references"],
    #     "mitigations" => ["limited_roles", "probation_period"]
    #   },
    #   "spy_risk" => %{
    #     "probability" => 0.25,
    #     "indicators" => ["competitor_connections", "information_seeking"],
    #     "mitigations" => ["information_compartmentalization"]
    #   }
    # }

    # Employment history (JSONB)
    attribute(:employment_history, :map, default: %{}, public?: true)
    # Format: %{
    #   "corp_changes" => 5,
    #   "avg_tenure_days" => 147,
    #   "suspicious_patterns" => [],
    #   "history" => [
    #     %{
    #       "corp_id" => 98388312,
    #       "corp_name" => "Previous Corp",
    #       "start_date" => "2023-01-15",
    #       "end_date" => "2023-08-20",
    #       "duration_days" => 217,
    #       "wh_corp" => true,
    #       "reason_left" => "corp_closed",
    #       "performance" => "good"
    #     }
    #   ]
    # }

    # Recommendations and notes
    # approve, reject, conditional, more_info
    attribute(:recommendation, :string, public?: true)
    # 0.0-1.0
    attribute(:recommendation_confidence, :float, default: 0.5, public?: true)
    attribute(:recruiter_notes, :string, public?: true)
    attribute(:auto_generated_summary, :string, public?: true)
    attribute(:requires_manual_review, :boolean, default: false, public?: true)

    # Data quality indicators
    attribute(:data_completeness_percent, :integer, default: 0, public?: true)
    attribute(:analysis_errors, :map, default: %{}, public?: true)

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
        :vetting_requested_by
      ])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:status, "pending")
        |> Ash.Changeset.change_attribute(:vetting_requested_at, DateTime.utc_now())
        |> Ash.Changeset.change_attribute(:last_updated_at, DateTime.utc_now())
      end)
    end

    update :update_analysis do
      description("Update vetting analysis with computed results")
      require_atomic?(false)

      accept([
        :overall_risk_score,
        :wh_experience_score,
        :competency_score,
        :security_score,
        :j_space_activity,
        :eviction_associations,
        :alt_analysis,
        :competency_metrics,
        :risk_factors,
        :employment_history,
        :recommendation,
        :recommendation_confidence,
        :auto_generated_summary,
        :requires_manual_review,
        :data_completeness_percent,
        :analysis_errors,
        :status
      ])

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end)

      validate(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :recommendation) do
          value
          when value in ["approve", "reject", "conditional", "more_info"] or is_nil(value) ->
            :ok

          _ ->
            {:error,
             field: :recommendation,
             message: "must be one of: approve, reject, conditional, more_info"}
        end
      end)

      validate(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :status) do
          value when value in ["pending", "complete", "failed"] or is_nil(value) ->
            :ok

          _ ->
            {:error, field: :status, message: "must be one of: pending, complete, failed"}
        end
      end)
    end

    update :add_recruiter_notes do
      description("Add or update recruiter notes")
      require_atomic?(false)

      accept([:recruiter_notes])

      change(fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end)
    end

    # Querying actions
    read :by_character do
      description("Find vetting record for a specific character")
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :by_status do
      description("Find vetting records by status")
      argument(:status, :string, allow_nil?: false)
      filter(expr(status == ^arg(:status)))
    end

    read :high_risk do
      description("Find high-risk vetting records")
      argument(:risk_threshold, :integer, default: 70)
      filter(expr(overall_risk_score >= ^arg(:risk_threshold)))
    end

    read :needs_review do
      description("Find vetting records requiring manual review")
      filter(expr(requires_manual_review == true or status == "pending"))
    end

    read :by_recommendation do
      description("Find vetting records by recommendation")
      argument(:recommendation, :string, allow_nil?: false)
      filter(expr(recommendation == ^arg(:recommendation)))
    end

    read :recent do
      description("Find recent vetting records")
      argument(:days, :integer, default: 30)

      filter(expr(vetting_requested_at >= ago(^arg(:days), :day)))
      prepare(build(sort: [vetting_requested_at: :desc]))
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update_analysis, action: :update_analysis)
    define(:add_notes, action: :add_recruiter_notes)
    define(:get_by_character, action: :by_character, args: [:character_id])
    define(:get_by_status, action: :by_status, args: [:status])
    define(:get_high_risk, action: :high_risk, args: [:risk_threshold])
    define(:get_needs_review, action: :needs_review)
    define(:get_by_recommendation, action: :by_recommendation, args: [:recommendation])
    define(:get_recent, action: :recent, args: [:days])
  end

  calculations do
    calculate :risk_level, :string do
      description("Human-readable risk level")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.overall_risk_score do
            score when score >= 80 -> "Critical"
            score when score >= 65 -> "High"
            score when score >= 35 -> "Medium"
            score when score >= 20 -> "Low"
            _ -> "Minimal"
          end
        end)
      end)
    end

    calculate :experience_level, :string do
      description("WH experience level assessment")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.wh_experience_score do
            score when score >= 80 -> "Expert"
            score when score >= 60 -> "Experienced"
            score when score >= 40 -> "Competent"
            score when score >= 20 -> "Novice"
            _ -> "Unknown"
          end
        end)
      end)
    end

    calculate :days_since_request, :integer do
      description("Days since vetting was requested")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.vetting_requested_at, :day)
        end)
      end)
    end

    calculate :status_badge, :string do
      description("Status with appropriate styling class")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.status do
            "complete" -> "success"
            "pending" -> "warning"
            "failed" -> "danger"
            _ -> "secondary"
          end
        end)
      end)
    end
  end

  preparations do
    prepare(build(load: [:risk_level, :experience_level, :days_since_request, :status_badge]))
  end
end
