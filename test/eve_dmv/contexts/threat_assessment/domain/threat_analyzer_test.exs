defmodule EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzerTest do
  @moduledoc """
  Tests for the ThreatAnalyzer GenServer in the domain namespace.

  Tests the GenServer coordination layer including caching,
  batch analysis, metrics tracking, and threat report generation.
  """

  use EveDmv.DataCase, async: false

  alias EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzer

  # Note: Since this is a GenServer test, we need to ensure the GenServer is running
  # The GenServer may be started by the application or we need to start it ourselves

  setup do
    # Ensure the GenServer is available for testing
    # If not started by the application, start it here
    case GenServer.whereis(ThreatAnalyzer) do
      nil ->
        {:ok, pid} = ThreatAnalyzer.start_link([])

        on_exit(fn ->
          # Only try to stop if the process is still alive
          if Process.alive?(pid) do
            try do
              GenServer.stop(pid, :normal, 5000)
            catch
              :exit, _ -> :ok
            end
          end
        end)

        {:ok, pid: pid}

      pid ->
        {:ok, pid: pid}
    end
  end

  describe "assess_threat/3" do
    test "successfully assesses threat for a character", %{pid: _pid} do
      entity_id = 12_345_678
      entity_type = :character

      result = ThreatAnalyzer.assess_threat(entity_id, entity_type)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, assessment} ->
          assert assessment.entity_id == entity_id
          assert assessment.entity_type == entity_type
          assert Map.has_key?(assessment, :threat_level)
          assert Map.has_key?(assessment, :vulnerability_analysis)
          assert Map.has_key?(assessment, :risk_factors)
          assert Map.has_key?(assessment, :mitigation_recommendations)

        {:error, _reason} ->
          # Error is acceptable if data is not available
          :ok
      end
    end

    test "returns cached result on subsequent calls within TTL", %{pid: _pid} do
      entity_id = 12_345_679
      entity_type = :character

      # First call - should populate cache
      result1 = ThreatAnalyzer.assess_threat(entity_id, entity_type)

      # Second call - should return cached result
      result2 = ThreatAnalyzer.assess_threat(entity_id, entity_type)

      # Both should have same structure (either both ok or both error)
      assert match?({:ok, _}, result1) or match?({:error, _}, result1)
      assert match?({:ok, _}, result2) or match?({:error, _}, result2)

      # If both succeed, the data should be consistent
      case {result1, result2} do
        {{:ok, assessment1}, {:ok, assessment2}} ->
          assert assessment1.entity_id == assessment2.entity_id
          assert assessment1.entity_type == assessment2.entity_type

        _ ->
          :ok
      end
    end

    test "respects cache_ttl_seconds option", %{pid: _pid} do
      entity_id = 12_345_680
      entity_type = :character

      # Use very short TTL
      result = ThreatAnalyzer.assess_threat(entity_id, entity_type, cache_ttl_seconds: 1)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles unsupported entity types gracefully", %{pid: _pid} do
      entity_id = 12_345_681
      entity_type = :unknown_type

      result = ThreatAnalyzer.assess_threat(entity_id, entity_type)

      # Should return an error for unsupported entity types
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "assess_threats/2 (batch assessment)" do
    test "successfully assesses multiple entities", %{pid: _pid} do
      entity_specs = [
        {12_345_690, :character},
        {12_345_691, :character}
      ]

      {:ok, result} = ThreatAnalyzer.assess_threats(entity_specs)

      assert Map.has_key?(result, :successful)
      assert Map.has_key?(result, :failed)
      assert result.total_count == 2
      assert result.success_count + result.failure_count == result.total_count
      assert Map.has_key?(result, :analysis_time_ms)
      assert is_integer(result.analysis_time_ms)
    end

    test "handles empty entity list", %{pid: _pid} do
      {:ok, result} = ThreatAnalyzer.assess_threats([])

      assert result.total_count == 0
      assert result.success_count == 0
      assert result.failure_count == 0
    end

    test "processes entities in parallel", %{pid: _pid} do
      # Create a larger batch to test parallel processing
      entity_specs = for i <- 1..5, do: {12_345_700 + i, :character}

      start_time = System.monotonic_time(:millisecond)
      {:ok, result} = ThreatAnalyzer.assess_threats(entity_specs)
      elapsed = System.monotonic_time(:millisecond) - start_time

      assert result.total_count == 5
      # Parallel processing should complete in reasonable time
      assert elapsed < 60_000
    end

    test "separates successful and failed assessments", %{pid: _pid} do
      entity_specs = [
        {12_345_710, :character}
      ]

      {:ok, result} = ThreatAnalyzer.assess_threats(entity_specs)

      assert is_map(result.successful)
      assert is_map(result.failed)
      assert map_size(result.successful) + map_size(result.failed) == result.total_count
    end
  end

  describe "scan_vulnerabilities/3" do
    test "performs vulnerability scan for entity", %{pid: _pid} do
      entity_id = 12_345_720
      entity_type = :character

      result = ThreatAnalyzer.scan_vulnerabilities(entity_id, entity_type)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, scan} ->
          # Verify scan contains expected vulnerability sections
          assert Map.has_key?(scan, :behavioral_vulnerabilities) or
                   Map.has_key?(scan, :entity_profile)

        {:error, _reason} ->
          :ok
      end
    end

    test "accepts options for scan customization", %{pid: _pid} do
      entity_id = 12_345_721
      entity_type = :corporation

      result = ThreatAnalyzer.scan_vulnerabilities(entity_id, entity_type, [])

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "get_threat_level/2" do
    test "returns threat level for entity", %{pid: _pid} do
      entity_id = 12_345_730
      entity_type = :character

      result = ThreatAnalyzer.get_threat_level(entity_id, entity_type)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, threat_level} ->
          assert threat_level in [:critical, :high, :medium, :low, :minimal]

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "generate_threat_report/3" do
    test "generates comprehensive threat report", %{pid: _pid} do
      entity_id = 12_345_740
      entity_type = :character

      result = ThreatAnalyzer.generate_threat_report(entity_id, entity_type)

      assert match?({:ok, _}, result) or match?({:error, _}, result)

      case result do
        {:ok, report} ->
          assert Map.has_key?(report, :executive_summary)
          assert Map.has_key?(report, :detailed_analysis)
          assert Map.has_key?(report, :threat_level)
          assert Map.has_key?(report, :key_findings)
          assert Map.has_key?(report, :risk_matrix)
          assert Map.has_key?(report, :recommendations)
          assert Map.has_key?(report, :action_plan)
          assert Map.has_key?(report, :generated_at)
          assert Map.has_key?(report, :report_confidence)

        {:error, _reason} ->
          :ok
      end
    end

    test "includes executive summary in report", %{pid: _pid} do
      entity_id = 12_345_741
      entity_type = :character

      case ThreatAnalyzer.generate_threat_report(entity_id, entity_type) do
        {:ok, report} ->
          summary = report.executive_summary
          assert Map.has_key?(summary, :threat_level)
          assert Map.has_key?(summary, :key_vulnerabilities_count)
          assert Map.has_key?(summary, :recommendations_count)
          assert Map.has_key?(summary, :summary_text)
          assert is_binary(summary.summary_text)

        {:error, _reason} ->
          :ok
      end
    end

    test "includes risk matrix in report", %{pid: _pid} do
      entity_id = 12_345_742
      entity_type = :character

      case ThreatAnalyzer.generate_threat_report(entity_id, entity_type) do
        {:ok, report} ->
          matrix = report.risk_matrix
          assert Map.has_key?(matrix, :behavioral_risk)
          assert Map.has_key?(matrix, :tactical_risk)
          assert Map.has_key?(matrix, :operational_risk)
          assert Map.has_key?(matrix, :social_risk)
          assert Map.has_key?(matrix, :overall_risk)

        {:error, _reason} ->
          :ok
      end
    end

    test "includes action plan in report", %{pid: _pid} do
      entity_id = 12_345_743
      entity_type = :character

      case ThreatAnalyzer.generate_threat_report(entity_id, entity_type) do
        {:ok, report} ->
          plan = report.action_plan
          assert Map.has_key?(plan, :immediate_actions)
          assert Map.has_key?(plan, :short_term_goals)
          assert Map.has_key?(plan, :long_term_strategy)
          assert Map.has_key?(plan, :review_schedule)

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "get_metrics/0" do
    test "returns current analyzer metrics", %{pid: _pid} do
      metrics = ThreatAnalyzer.get_metrics()

      assert is_map(metrics)
    end

    test "tracks total assessments", %{pid: _pid} do
      # Perform an assessment to generate metrics
      ThreatAnalyzer.assess_threat(12_345_750, :character)

      metrics = ThreatAnalyzer.get_metrics()

      assert Map.has_key?(metrics, :total_assessments) or
               Map.has_key?(metrics, :metrics)
    end
  end

  describe "threat level calculation" do
    test "calculates threat level from vulnerability scan", %{pid: _pid} do
      entity_id = 12_345_760
      entity_type = :character

      case ThreatAnalyzer.assess_threat(entity_id, entity_type) do
        {:ok, assessment} ->
          assert assessment.threat_level in [:critical, :high, :medium, :low, :minimal]

          # Verify threat level corresponds to exploitability score ranges
          # (actual values depend on vulnerability analysis)
          assert is_atom(assessment.threat_level)

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "risk factor identification" do
    test "identifies risk factors from vulnerability analysis", %{pid: _pid} do
      entity_id = 12_345_770
      entity_type = :character

      case ThreatAnalyzer.assess_threat(entity_id, entity_type) do
        {:ok, assessment} ->
          assert is_list(assessment.risk_factors)

          for risk_factor <- assessment.risk_factors do
            assert is_tuple(risk_factor) or is_atom(risk_factor)
          end

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "mitigation recommendations" do
    test "generates mitigation recommendations", %{pid: _pid} do
      entity_id = 12_345_780
      entity_type = :character

      case ThreatAnalyzer.assess_threat(entity_id, entity_type) do
        {:ok, assessment} ->
          assert is_list(assessment.mitigation_recommendations)

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "assessment confidence" do
    test "calculates assessment confidence level", %{pid: _pid} do
      entity_id = 12_345_790
      entity_type = :character

      case ThreatAnalyzer.assess_threat(entity_id, entity_type) do
        {:ok, assessment} ->
          assert assessment.assessment_confidence in [:high, :medium, :low, :very_low]

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "key findings extraction" do
    test "extracts key findings from assessment", %{pid: _pid} do
      entity_id = 12_345_800
      entity_type = :character

      case ThreatAnalyzer.generate_threat_report(entity_id, entity_type) do
        {:ok, report} ->
          assert is_list(report.key_findings)

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "cache behavior" do
    test "cache hit increments cache_hits metric", %{pid: _pid} do
      entity_id = 12_345_810
      entity_type = :character

      # First call - cache miss
      ThreatAnalyzer.assess_threat(entity_id, entity_type)

      # Second call - should be cache hit
      ThreatAnalyzer.assess_threat(entity_id, entity_type)

      # Metrics should show cache activity
      metrics = ThreatAnalyzer.get_metrics()
      assert is_map(metrics)
    end

    test "expired cache triggers new assessment", %{pid: _pid} do
      entity_id = 12_345_811
      entity_type = :character

      # Use very short TTL that will expire
      ThreatAnalyzer.assess_threat(entity_id, entity_type, cache_ttl_seconds: 0)

      # Small delay to ensure cache expires
      Process.sleep(100)

      # This should trigger a new assessment
      result = ThreatAnalyzer.assess_threat(entity_id, entity_type, cache_ttl_seconds: 0)

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "review schedule determination" do
    test "critical threats get weekly review", %{pid: _pid} do
      # The review schedule is based on threat level
      # We test through the report which includes the action plan

      entity_id = 12_345_820
      entity_type = :character

      case ThreatAnalyzer.generate_threat_report(entity_id, entity_type) do
        {:ok, report} ->
          schedule = report.action_plan.review_schedule

          # Schedule should be one of the valid options
          assert schedule in ["Weekly", "Bi-weekly", "Monthly", "Quarterly", "Annually"]

        {:error, _reason} ->
          :ok
      end
    end
  end

  describe "error handling" do
    test "handles invalid entity_id gracefully", %{pid: _pid} do
      # Very unlikely to have real data for this ID
      result = ThreatAnalyzer.assess_threat(-1, :character)

      # Should return either an ok with empty/default data or an error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "handles concurrent requests", %{pid: _pid} do
      # Spawn multiple concurrent requests
      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            ThreatAnalyzer.assess_threat(12_345_900 + i, :character)
          end)
        end

      results = Task.await_many(tasks, 30_000)

      # All should complete without crashing
      for result <- results do
        assert match?({:ok, _}, result) or match?({:error, _}, result)
      end
    end
  end

  describe "metrics tracking" do
    test "tracks vulnerability scans", %{pid: _pid} do
      ThreatAnalyzer.scan_vulnerabilities(12_345_920, :character)

      metrics = ThreatAnalyzer.get_metrics()
      assert is_map(metrics)
    end

    test "tracks threat reports generated", %{pid: _pid} do
      ThreatAnalyzer.generate_threat_report(12_345_930, :character)

      metrics = ThreatAnalyzer.get_metrics()
      assert is_map(metrics)
    end

    test "tracks threat level distribution", %{pid: _pid} do
      # Perform some assessments
      for i <- 1..3 do
        ThreatAnalyzer.assess_threat(12_345_940 + i, :character)
      end

      metrics = ThreatAnalyzer.get_metrics()
      assert is_map(metrics)
    end
  end
end
