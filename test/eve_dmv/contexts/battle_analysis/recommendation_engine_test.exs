defmodule EveDmv.Shared.Strategic.RecommendationEngineTest do
  @moduledoc """
  Tests for the RecommendationEngine module.

  Tests the strategic recommendation system including:
  - Immediate action recommendations
  - Medium-term strategic planning
  - Long-term strategic guidance
  - Risk assessment and contingency planning
  """

  use ExUnit.Case, async: true

  alias EveDmv.Shared.Strategic.RecommendationEngine

  # Test fixtures for pattern analysis
  defp build_pattern_analysis(attrs \\ %{}) do
    default_patterns = [
      %{type: :offensive_preparation, confidence: 0.8},
      %{type: :harassment_campaign, confidence: 0.6}
    ]

    %{
      identified_patterns: Map.get(attrs, :identified_patterns, default_patterns)
    }
  end

  defp build_territorial_analysis(attrs \\ %{}) do
    %{
      territorial_assessment: %{
        situation: Map.get(attrs, :situation, :stable_control)
      },
      contested_areas: %{
        contestation_intensity: Map.get(attrs, :contestation_intensity, 0.3)
      }
    }
  end

  defp build_resource_analysis(attrs \\ %{}) do
    %{
      competition: %{
        competition_intensity: Map.get(attrs, :competition_intensity, 0.5)
      }
    }
  end

  defp build_trend_analysis(attrs \\ %{}) do
    %{
      momentum: %{
        momentum_direction: Map.get(attrs, :momentum_direction, :neutral)
      },
      trend_strength: %{
        overall_strength: Map.get(attrs, :overall_strength, 0.5)
      },
      inflection_points: Map.get(attrs, :inflection_points, []),
      trend_prediction: %{
        confidence_level: Map.get(attrs, :confidence_level, 0.6)
      },
      pattern_evolution: %{
        pattern_stability: Map.get(attrs, :pattern_stability, 0.7)
      },
      activity_trends: %{
        volatility: Map.get(attrs, :volatility, 0.4)
      }
    }
  end

  describe "generate_strategic_recommendations/4" do
    test "returns comprehensive recommendations structure" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      assert Map.has_key?(result, :immediate_actions)
      assert Map.has_key?(result, :medium_term_strategy)
      assert Map.has_key?(result, :long_term_planning)
      assert Map.has_key?(result, :risk_assessment)
      assert Map.has_key?(result, :contingency_planning)
      assert Map.has_key?(result, :strategic_priorities)
      assert Map.has_key?(result, :implementation_roadmap)
    end

    test "generates immediate actions" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      assert is_list(result.immediate_actions)

      if result.immediate_actions != [] do
        action = hd(result.immediate_actions)
        assert Map.has_key?(action, :action)
        assert Map.has_key?(action, :urgency)
        assert Map.has_key?(action, :reasoning)
      end
    end

    test "generates medium-term strategy" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      medium_term = result.medium_term_strategy
      assert Map.has_key?(medium_term, :primary_objectives)
      assert Map.has_key?(medium_term, :strategic_initiatives)
      assert Map.has_key?(medium_term, :resource_allocation)
      assert Map.has_key?(medium_term, :success_metrics)
    end

    test "generates long-term planning" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      long_term = result.long_term_planning
      assert Map.has_key?(long_term, :vision_statement)
      assert Map.has_key?(long_term, :strategic_goals)
      assert Map.has_key?(long_term, :capability_development)
      assert Map.has_key?(long_term, :milestone_planning)
    end

    test "includes risk assessment" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      risks = result.risk_assessment
      assert Map.has_key?(risks, :identified_risks)
      assert Map.has_key?(risks, :risk_matrix)
      assert Map.has_key?(risks, :high_priority_risks)
    end

    test "creates contingency plans" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      contingencies = result.contingency_planning
      assert Map.has_key?(contingencies, :plans)
      assert Map.has_key?(contingencies, :activation_protocol)
      assert Map.has_key?(contingencies, :communication_plan)
    end

    test "creates implementation roadmap" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      roadmap = result.implementation_roadmap
      assert Map.has_key?(roadmap, :phase_1)
      assert Map.has_key?(roadmap, :phase_2)
      assert Map.has_key?(roadmap, :phase_3)
      assert Map.has_key?(roadmap, :review_schedule)
    end
  end

  describe "generate_immediate_recommendations/2" do
    test "generates defensive recommendations for offensive preparation pattern" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [%{type: :offensive_preparation, confidence: 0.9}]
        })

      trend_analysis = build_trend_analysis()

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      assert is_list(recommendations)
      assert recommendations != []

      # Should have defensive-related recommendations
      actions = Enum.map(recommendations, & &1.action)

      assert Enum.any?(actions, fn action ->
               String.contains?(action, "defensive") or
                 String.contains?(action, "Reinforce")
             end)
    end

    test "generates anti-harassment recommendations for harassment pattern" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [%{type: :harassment_campaign, confidence: 0.8}]
        })

      trend_analysis = build_trend_analysis()

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      assert is_list(recommendations)
      assert recommendations != []
    end

    test "generates momentum-based recommendations for strong positive momentum" do
      pattern_analysis = build_pattern_analysis(%{identified_patterns: []})

      trend_analysis =
        build_trend_analysis(%{
          momentum_direction: :strong_positive,
          inflection_points: []
        })

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      assert is_list(recommendations)

      if recommendations != [] do
        actions = Enum.map(recommendations, & &1.action)

        assert Enum.any?(actions, fn action ->
                 action_lower = String.downcase(action)

                 String.contains?(action_lower, "exploit") or
                   String.contains?(action_lower, "capitalize") or
                   String.contains?(action_lower, "momentum")
               end)
      end
    end

    test "generates damage control for strong negative momentum" do
      pattern_analysis = build_pattern_analysis(%{identified_patterns: []})

      trend_analysis =
        build_trend_analysis(%{
          momentum_direction: :strong_negative,
          inflection_points: []
        })

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      assert is_list(recommendations)

      if recommendations != [] do
        # Should have critical urgency actions
        urgencies = Enum.map(recommendations, & &1.urgency)
        assert Enum.any?(urgencies, &(&1 == :critical))
      end
    end

    test "prioritizes by urgency" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [
            %{type: :offensive_preparation, confidence: 0.9},
            %{type: :reconnaissance_operation, confidence: 0.5}
          ]
        })

      trend_analysis = build_trend_analysis()

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      if length(recommendations) >= 2 do
        first_urgency = hd(recommendations).urgency
        # Critical and high should come before medium and low
        assert first_urgency in [:critical, :high]
      end
    end

    test "limits recommendations to top 5" do
      # Create many patterns
      patterns =
        for type <- [
              :offensive_preparation,
              :harassment_campaign,
              :supply_line_disruption,
              :reconnaissance_operation,
              :territorial_expansion
            ] do
          %{type: type, confidence: 0.8}
        end

      pattern_analysis = build_pattern_analysis(%{identified_patterns: patterns})
      trend_analysis = build_trend_analysis(%{momentum_direction: :strong_negative})

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      assert length(recommendations) <= 5
    end

    test "includes expected timeline based on urgency" do
      pattern_analysis = build_pattern_analysis()
      trend_analysis = build_trend_analysis()

      recommendations =
        RecommendationEngine.generate_immediate_recommendations(pattern_analysis, trend_analysis)

      if recommendations != [] do
        action = hd(recommendations)
        assert Map.has_key?(action, :expected_timeline)
        assert is_binary(action.expected_timeline)
      end
    end
  end

  describe "generate_medium_term_recommendations/2" do
    test "generates expansion strategies for dominant control" do
      territorial_analysis = build_territorial_analysis(%{situation: :dominant_control})
      resource_analysis = build_resource_analysis()

      result =
        RecommendationEngine.generate_medium_term_recommendations(
          territorial_analysis,
          resource_analysis
        )

      assert Map.has_key?(result, :primary_objectives)
      assert Map.has_key?(result, :strategic_initiatives)
      assert is_list(result.primary_objectives)
    end

    test "generates consolidation strategies for stable control" do
      territorial_analysis = build_territorial_analysis(%{situation: :stable_control})
      resource_analysis = build_resource_analysis()

      result =
        RecommendationEngine.generate_medium_term_recommendations(
          territorial_analysis,
          resource_analysis
        )

      assert is_map(result)
      assert Map.has_key?(result, :primary_objectives)
    end

    test "generates defensive strategies for contested territory" do
      territorial_analysis = build_territorial_analysis(%{situation: :contested_territory})
      resource_analysis = build_resource_analysis()

      result =
        RecommendationEngine.generate_medium_term_recommendations(
          territorial_analysis,
          resource_analysis
        )

      assert is_map(result)
    end

    test "generates alliance strategies for highly contested situations" do
      territorial_analysis = build_territorial_analysis(%{situation: :highly_contested})
      resource_analysis = build_resource_analysis()

      result =
        RecommendationEngine.generate_medium_term_recommendations(
          territorial_analysis,
          resource_analysis
        )

      assert is_map(result)
    end

    test "handles high resource competition" do
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis(%{competition_intensity: 0.9})

      result =
        RecommendationEngine.generate_medium_term_recommendations(
          territorial_analysis,
          resource_analysis
        )

      assert is_map(result)
      assert Map.has_key?(result, :resource_allocation)
    end

    test "handles nil territorial analysis" do
      result =
        RecommendationEngine.generate_medium_term_recommendations(
          nil,
          build_resource_analysis()
        )

      assert is_map(result)
    end

    test "handles nil resource analysis" do
      result =
        RecommendationEngine.generate_medium_term_recommendations(
          build_territorial_analysis(),
          nil
        )

      assert is_map(result)
    end

    test "includes success metrics" do
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()

      result =
        RecommendationEngine.generate_medium_term_recommendations(
          territorial_analysis,
          resource_analysis
        )

      assert Map.has_key?(result, :success_metrics)
      assert is_list(result.success_metrics)
    end
  end

  describe "generate_long_term_recommendations/1" do
    test "generates regional dominance goals for strong positive trend" do
      trend_analysis =
        build_trend_analysis(%{
          momentum_direction: :strong_positive,
          overall_strength: 0.8
        })

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert Map.has_key?(result, :vision_statement)
      assert Map.has_key?(result, :strategic_goals)
      assert is_binary(result.vision_statement)
    end

    test "generates steady growth goals for positive trend" do
      trend_analysis =
        build_trend_analysis(%{
          momentum_direction: :positive,
          overall_strength: 0.5
        })

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert is_map(result)
      assert result.strategic_goals != []
    end

    test "generates stable presence goals for neutral trend" do
      trend_analysis =
        build_trend_analysis(%{
          momentum_direction: :neutral,
          overall_strength: 0.4
        })

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert is_map(result)
    end

    test "generates strategic retreat goals for negative trend" do
      trend_analysis =
        build_trend_analysis(%{
          momentum_direction: :strong_negative,
          overall_strength: 0.2
        })

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert is_map(result)
      # Should have critical priorities
      priorities = Enum.map(result.strategic_goals, & &1.priority)
      assert Enum.any?(priorities, &(&1 == :critical))
    end

    test "includes capability development" do
      trend_analysis = build_trend_analysis()

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert Map.has_key?(result, :capability_development)
      capability_dev = result.capability_development
      assert Map.has_key?(capability_dev, :required_capabilities)
      assert Map.has_key?(capability_dev, :development_priorities)
    end

    test "includes milestone planning" do
      trend_analysis = build_trend_analysis()

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert Map.has_key?(result, :milestone_planning)
      assert is_list(result.milestone_planning)

      if result.milestone_planning != [] do
        milestone = hd(result.milestone_planning)
        assert Map.has_key?(milestone, :goal)
        assert Map.has_key?(milestone, :milestones)
      end
    end

    test "develops adaptation strategies for high volatility" do
      trend_analysis = build_trend_analysis(%{volatility: 0.8})

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert Map.has_key?(result, :adaptation_strategies)
      adaptation = result.adaptation_strategies
      assert adaptation.primary_approach == "Flexible response doctrine"
    end

    test "develops steady state strategies for low volatility" do
      trend_analysis = build_trend_analysis(%{volatility: 0.2})

      result = RecommendationEngine.generate_long_term_recommendations(trend_analysis)

      assert Map.has_key?(result, :adaptation_strategies)
      adaptation = result.adaptation_strategies
      assert adaptation.primary_approach == "Steady state optimization"
    end
  end

  describe "risk assessment" do
    test "identifies risks from patterns" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [%{type: :offensive_preparation, confidence: 0.9}]
        })

      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      risks = result.risk_assessment.identified_risks
      assert is_list(risks)

      if risks != [] do
        risk = hd(risks)
        assert Map.has_key?(risk, :risk)
        assert Map.has_key?(risk, :probability)
        assert Map.has_key?(risk, :impact)
      end
    end

    test "identifies risks from territorial contestation" do
      pattern_analysis = build_pattern_analysis(%{identified_patterns: []})
      territorial_analysis = build_territorial_analysis(%{contestation_intensity: 0.8})
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      risks = result.risk_assessment.identified_risks
      assert is_list(risks)
    end

    test "builds risk matrix grouped by impact" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      risk_matrix = result.risk_assessment.risk_matrix
      assert is_map(risk_matrix)
    end

    test "filters high priority risks" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [
            %{type: :offensive_preparation, confidence: 0.9}
          ]
        })

      territorial_analysis = build_territorial_analysis(%{contestation_intensity: 0.8})
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      high_priority = result.risk_assessment.high_priority_risks
      assert is_list(high_priority)
    end

    test "estimates mitigation budget" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      budget = result.risk_assessment.risk_mitigation_budget
      assert Map.has_key?(budget, :estimated_budget)
      assert Map.has_key?(budget, :cost_benefit_ratio)
    end
  end

  describe "contingency planning" do
    test "creates contingency plans for high priority risks" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [%{type: :offensive_preparation, confidence: 0.9}]
        })

      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      contingencies = result.contingency_planning
      assert Map.has_key?(contingencies, :plans)

      if contingencies.plans != [] do
        plan = hd(contingencies.plans)
        assert Map.has_key?(plan, :risk_scenario)
        assert Map.has_key?(plan, :contingency_plan)
        assert Map.has_key?(plan, :activation_triggers)
        assert Map.has_key?(plan, :resource_requirements)
      end
    end

    test "includes activation protocol" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      protocol = result.contingency_planning.activation_protocol
      assert Map.has_key?(protocol, :detection)
      assert Map.has_key?(protocol, :verification)
      assert Map.has_key?(protocol, :decision)
    end

    test "includes communication plan" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      comm_plan = result.contingency_planning.communication_plan
      assert Map.has_key?(comm_plan, :internal)
      assert Map.has_key?(comm_plan, :external)
    end

    test "defines recovery procedures" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      recovery = result.contingency_planning.recovery_procedures
      assert is_list(recovery)

      if recovery != [] do
        phase = hd(recovery)
        assert Map.has_key?(phase, :phase)
        assert Map.has_key?(phase, :actions)
      end
    end
  end

  describe "edge cases" do
    test "handles empty pattern list" do
      pattern_analysis = build_pattern_analysis(%{identified_patterns: []})
      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      assert is_map(result)
      assert Map.has_key?(result, :strategic_priorities)
    end

    test "handles unknown pattern types" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [%{type: :unknown_pattern, confidence: 0.5}]
        })

      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      assert is_map(result)
    end

    test "handles extreme confidence values" do
      pattern_analysis =
        build_pattern_analysis(%{
          identified_patterns: [
            %{type: :offensive_preparation, confidence: 1.0},
            %{type: :harassment_campaign, confidence: 0.0}
          ]
        })

      territorial_analysis = build_territorial_analysis()
      resource_analysis = build_resource_analysis()
      trend_analysis = build_trend_analysis()

      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      assert is_map(result)
    end

    test "handles nil values in nested structures" do
      pattern_analysis = build_pattern_analysis()
      territorial_analysis = nil
      resource_analysis = nil
      trend_analysis = build_trend_analysis()

      # This might not work perfectly but should not crash
      result =
        RecommendationEngine.generate_strategic_recommendations(
          pattern_analysis,
          territorial_analysis,
          resource_analysis,
          trend_analysis
        )

      assert is_map(result)
    end
  end
end
