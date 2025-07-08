defmodule EveDmv.Contexts.ThreatAssessment.Domain.ThreatAnalyzer do
  @moduledoc """
  Core threat analysis service for EVE DMV.

  Provides comprehensive threat assessment including vulnerability scanning,
  behavioral analysis, tactical weakness identification, and security assessment
  for characters, corporations, and fleets.
  """

  use GenServer
    alias EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatRepository
  alias EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache
  alias EveDmv.Result
  alias EveDmv.Shared.MetricsCalculator
  use EveDmv.ErrorHandler

    alias EveDmv.Contexts.ThreatAssessment.Analyzers.VulnerabilityScanner
  # Import analyzers

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Perform comprehensive threat assessment for an entity.
  """
  def assess_threat(entity_id, entity_type, opts \\ []) do
    GenServer.call(__MODULE__, {:assess_threat, entity_id, entity_type, opts}, 30_000)
  end

  @doc """
  Analyze multiple entities in batch for threat assessment.
  """
  def assess_threats(entity_specs, opts \\ []) when is_list(entity_specs) do
    GenServer.call(__MODULE__, {:assess_threats, entity_specs, opts}, 60_000)
  end

  @doc """
  Get vulnerability scan results for an entity.
  """
  def scan_vulnerabilities(entity_id, entity_type, opts \\ []) do
    GenServer.call(__MODULE__, {:scan_vulnerabilities, entity_id, entity_type, opts})
  end

  @doc """
  Get threat level assessment for an entity.
  """
  def get_threat_level(entity_id, entity_type) do
    GenServer.call(__MODULE__, {:get_threat_level, entity_id, entity_type})
  end

  @doc """
  Generate threat intelligence report.
  """
  def generate_threat_report(entity_id, entity_type, opts \\ []) do
    GenServer.call(__MODULE__, {:generate_report, entity_id, entity_type, opts})
  end

  @doc """
  Get analyzer metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    state = %{
      analysis_cache: %{},
      metrics: %{
        total_assessments: 0,
        vulnerability_scans: 0,
        threat_reports_generated: 0,
        cache_hits: 0,
        cache_misses: 0,
        average_analysis_time_ms: 0,
        threat_level_distribution: %{
          critical: 0,
          high: 0,
          medium: 0,
          low: 0,
          minimal: 0
        }
      },
      recent_analysis_times: []
    }

    Logger.info("ThreatAnalyzer started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:assess_threat, entity_id, entity_type, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Check cache first
    cache_key = generate_cache_key(entity_id, entity_type, opts)

    case Map.get(state.analysis_cache, cache_key) do
      %{timestamp: ts, data: data} when ts != nil ->
        if cache_valid?(ts, opts) do
          new_state = update_metrics(state, :cache_hit, 0)
          {:reply, {:ok, data}, new_state}
        else
          # Cache expired, perform analysis
          perform_and_cache_assessment(entity_id, entity_type, opts, cache_key, start_time, state)
        end

      _ ->
        # No cache, perform analysis
        perform_and_cache_assessment(entity_id, entity_type, opts, cache_key, start_time, state)
    end
  end

  @impl GenServer
  def handle_call({:assess_threats, entity_specs, opts}, _from, state) do
    start_time = System.monotonic_time(:millisecond)

    # Parallel batch analysis
    tasks =
      Enum.map(entity_specs, fn {entity_id, entity_type} ->
        Task.async(fn ->
          {{entity_id, entity_type}, perform_threat_assessment(entity_id, entity_type, opts)}
        end)
      end)

    # Collect results with timeout
    results = Task.await_many(tasks, 30_000)

    # Process results
    {successful, failed} =
      Enum.split_with(results, fn {_spec, result} ->
        match?({:ok, _}, result)
      end)

    analysis_time = System.monotonic_time(:millisecond) - start_time
    new_state = update_metrics(state, :batch_analysis, analysis_time)

    batch_result = %{
      successful: Map.new(successful, fn {spec, {:ok, data}} -> {spec, data} end),
      failed: Map.new(failed, fn {spec, {:error, reason}} -> {spec, reason} end),
      total_count: length(entity_specs),
      success_count: length(successful),
      failure_count: length(failed),
      analysis_time_ms: analysis_time
    }

    {:reply, {:ok, batch_result}, new_state}
  end

  @impl GenServer
  def handle_call({:scan_vulnerabilities, entity_id, entity_type, opts}, _from, state) do
    case perform_vulnerability_scan(entity_id, entity_type, opts) do
      {:ok, scan_result} ->
        new_state = update_metrics(state, :vulnerability_scan, 0)
        {:reply, {:ok, scan_result}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_threat_level, entity_id, entity_type}, _from, state) do
    case perform_threat_level_assessment(entity_id, entity_type) do
      {:ok, threat_level} ->
        {:reply, {:ok, threat_level}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:generate_report, entity_id, entity_type, opts}, _from, state) do
    case generate_comprehensive_threat_report(entity_id, entity_type, opts) do
      {:ok, report} ->
        new_state = update_metrics(state, :threat_report, 0)
        {:reply, {:ok, report}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = calculate_current_metrics(state)
    {:reply, metrics, state}
  end

  # Private functions

  defp perform_and_cache_assessment(entity_id, entity_type, opts, cache_key, start_time, state) do
    case perform_threat_assessment(entity_id, entity_type, opts) do
      {:ok, assessment} ->
        analysis_time = System.monotonic_time(:millisecond) - start_time

        # Cache the result
        cache_entry = %{
          timestamp: DateTime.utc_now(),
          data: assessment
        }

        new_cache = Map.put(state.analysis_cache, cache_key, cache_entry)

        threat_level = Map.get(assessment, :threat_level, :unknown)

        new_state =
          %{state | analysis_cache: new_cache}
          |> update_metrics(:cache_miss, analysis_time)
          |> update_threat_level_distribution(threat_level)

        {:reply, {:ok, assessment}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp perform_threat_assessment(entity_id, entity_type, opts) do
    with {:ok, base_data} <- gather_base_data(entity_id, entity_type),
         {:ok, vulnerability_scan} <-
           analyze_vulnerabilities(entity_id, entity_type, base_data, opts) do
      assessment = %{
        entity_id: entity_id,
        entity_type: entity_type,
        timestamp: DateTime.utc_now(),
        vulnerability_analysis: vulnerability_scan,
        threat_level: calculate_threat_level(vulnerability_scan),
        risk_factors: identify_risk_factors(vulnerability_scan),
        mitigation_recommendations: generate_mitigation_recommendations(vulnerability_scan),
        assessment_confidence: calculate_assessment_confidence(base_data, vulnerability_scan)
      }

      {:ok, assessment}
    end
  end

  defp gather_base_data(entity_id, entity_type) do
    case ThreatRepository.get_entity_data(entity_id, entity_type) do
      {:ok, entity_data} ->
        # Gather all necessary base data
        base_data = %{
          entity_data: entity_data,
          related_data: ThreatRepository.get_related_data(entity_id, entity_type),
          security_context: ThreatRepository.get_security_context(entity_id, entity_type)
        }

        {:ok, base_data}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp analyze_vulnerabilities(entity_id, entity_type, base_data, opts) do
    scan_opts = Keyword.put(opts, :entity_type, entity_type)
    VulnerabilityScanner.analyze(entity_id, base_data, scan_opts)
  end

  defp perform_vulnerability_scan(entity_id, entity_type, opts) do
    with {:ok, base_data} <- gather_base_data(entity_id, entity_type) do
      scan_opts = Keyword.put(opts, :entity_type, entity_type)
      VulnerabilityScanner.analyze(entity_id, base_data, scan_opts)
    end
  end

  defp perform_threat_level_assessment(entity_id, entity_type) do
    case perform_threat_assessment(entity_id, entity_type, []) do
      {:ok, assessment} ->
        {:ok, assessment.threat_level}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_comprehensive_threat_report(entity_id, entity_type, opts) do
    case perform_threat_assessment(entity_id, entity_type, opts) do
      {:ok, assessment} ->
        report = %{
          executive_summary: create_executive_summary(assessment),
          detailed_analysis: assessment.vulnerability_analysis,
          threat_level: assessment.threat_level,
          key_findings: extract_key_findings(assessment),
          risk_matrix: create_risk_matrix(assessment),
          recommendations: assessment.mitigation_recommendations,
          action_plan: create_action_plan(assessment),
          generated_at: DateTime.utc_now(),
          report_confidence: assessment.assessment_confidence
        }

        {:ok, report}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp calculate_threat_level(vulnerability_scan) do
    # Calculate overall threat level based on vulnerability analysis
    exploitability_score = Map.get(vulnerability_scan, :exploitability_rating, %{})
    overall_score = Map.get(exploitability_score, :overall_exploitability_score, 0.0)

    cond do
      overall_score > 80 -> :critical
      overall_score > 60 -> :high
      overall_score > 40 -> :medium
      overall_score > 20 -> :low
      true -> :minimal
    end
  end

  defp identify_risk_factors(vulnerability_scan) do
    risk_factors = []

    # Extract behavioral risk factors
    behavioral = Map.get(vulnerability_scan, :behavioral_vulnerabilities, %{})
    risk_factors = add_behavioral_risks(risk_factors, behavioral)

    # Extract tactical risk factors
    tactical = Map.get(vulnerability_scan, :tactical_vulnerabilities, %{})
    risk_factors = add_tactical_risks(risk_factors, tactical)

    # Extract operational risk factors
    operational = Map.get(vulnerability_scan, :operational_vulnerabilities, %{})
    risk_factors = add_operational_risks(risk_factors, operational)

    # Extract social risk factors
    social = Map.get(vulnerability_scan, :social_vulnerabilities, %{})
    risk_factors = add_social_risks(risk_factors, social)

    risk_factors
  end

  defp generate_mitigation_recommendations(vulnerability_scan) do
    recommendations = []

    # Behavioral mitigations
    behavioral = Map.get(vulnerability_scan, :behavioral_vulnerabilities, %{})
    recommendations = add_behavioral_mitigations(recommendations, behavioral)

    # Tactical mitigations
    tactical = Map.get(vulnerability_scan, :tactical_vulnerabilities, %{})
    recommendations = add_tactical_mitigations(recommendations, tactical)

    # Operational mitigations
    operational = Map.get(vulnerability_scan, :operational_vulnerabilities, %{})
    recommendations = add_operational_mitigations(recommendations, operational)

    # Social mitigations
    social = Map.get(vulnerability_scan, :social_vulnerabilities, %{})
    recommendations = add_social_mitigations(recommendations, social)

    recommendations
  end

  defp calculate_assessment_confidence(base_data, vulnerability_scan) do
    # Calculate confidence based on data quality and completeness
    data_quality = assess_data_quality(base_data)
    analysis_completeness = assess_analysis_completeness(vulnerability_scan)

    overall_confidence = (data_quality + analysis_completeness) / 2

    cond do
      overall_confidence > 0.8 -> :high
      overall_confidence > 0.6 -> :medium
      overall_confidence > 0.4 -> :low
      true -> :very_low
    end
  end

  defp create_executive_summary(assessment) do
    threat_level = assessment.threat_level
    key_vulnerabilities = length(assessment.risk_factors)

    summary =
      "Threat assessment completed for #{assessment.entity_type} #{assessment.entity_id}. " <>
        "Overall threat level: #{threat_level}. " <>
        "#{key_vulnerabilities} risk factors identified. " <>
        "#{length(assessment.mitigation_recommendations)} mitigation recommendations provided."

    %{
      threat_level: threat_level,
      key_vulnerabilities_count: key_vulnerabilities,
      recommendations_count: length(assessment.mitigation_recommendations),
      summary_text: summary,
      assessment_date: assessment.timestamp
    }
  end

  defp extract_key_findings(assessment) do
    vulnerability_analysis = assessment.vulnerability_analysis

    findings = []

    # Extract high-priority vulnerabilities
    if Map.has_key?(vulnerability_analysis, :behavioral_vulnerabilities) do
      behavioral = vulnerability_analysis.behavioral_vulnerabilities

      if Map.get(behavioral, :behavioral_vulnerability_score, 0) > 70 do
        findings = ["High behavioral vulnerability score detected" | findings]
      end
    end

    if Map.has_key?(vulnerability_analysis, :tactical_vulnerabilities) do
      tactical = vulnerability_analysis.tactical_vulnerabilities

      if Map.get(tactical, :tactical_vulnerability_score, 0) > 70 do
        findings = ["Significant tactical vulnerabilities identified" | findings]
      end
    end

    if Map.has_key?(vulnerability_analysis, :security_assessment) do
      security = vulnerability_analysis.security_assessment

      if Map.get(security, :overall_security_score, 100) < 40 do
        findings = ["Poor overall security posture" | findings]
      end
    end

    findings
  end

  defp create_risk_matrix(assessment) do
    vulnerability_analysis = assessment.vulnerability_analysis

    %{
      behavioral_risk: get_risk_level(vulnerability_analysis, :behavioral_vulnerabilities),
      tactical_risk: get_risk_level(vulnerability_analysis, :tactical_vulnerabilities),
      operational_risk: get_risk_level(vulnerability_analysis, :operational_vulnerabilities),
      social_risk: get_risk_level(vulnerability_analysis, :social_vulnerabilities),
      overall_risk: assessment.threat_level
    }
  end

  defp create_action_plan(assessment) do
    recommendations = assessment.mitigation_recommendations

    # Prioritize recommendations
    {immediate, short_term, long_term} = categorize_recommendations(recommendations)

    %{
      immediate_actions: immediate,
      short_term_goals: short_term,
      long_term_strategy: long_term,
      review_schedule: determine_review_schedule(assessment.threat_level)
    }
  end

  defp generate_cache_key(entity_id, entity_type, opts) do
    opts_hash = :erlang.phash2(opts)
    "#{entity_type}:#{entity_id}:#{opts_hash}"
  end

  defp cache_valid?(timestamp, opts) do
    ttl = Keyword.get(opts, :cache_ttl_seconds, 300)
    age = DateTime.diff(DateTime.utc_now(), timestamp, :second)
    age < ttl
  end

  defp update_metrics(state, event_type, duration) do
    new_metrics =
      case event_type do
        :cache_hit ->
          %{state.metrics | cache_hits: state.metrics.cache_hits + 1}

        :cache_miss ->
          %{
            state.metrics
            | cache_misses: state.metrics.cache_misses + 1,
              total_assessments: state.metrics.total_assessments + 1
          }

        :batch_analysis ->
          %{state.metrics | total_assessments: state.metrics.total_assessments + 1}

        :vulnerability_scan ->
          %{state.metrics | vulnerability_scans: state.metrics.vulnerability_scans + 1}

        :threat_report ->
          %{state.metrics | threat_reports_generated: state.metrics.threat_reports_generated + 1}
      end

    # Update timing metrics
    new_times =
      if duration > 0 do
        [duration | Enum.take(state.recent_analysis_times, 99)]
      else
        state.recent_analysis_times
      end

    %{state | metrics: new_metrics, recent_analysis_times: new_times}
  end

  defp update_threat_level_distribution(state, threat_level) do
    new_distribution =
      Map.update(state.metrics.threat_level_distribution, threat_level, 1, &(&1 + 1))

    new_metrics = %{state.metrics | threat_level_distribution: new_distribution}
    %{state | metrics: new_metrics}
  end

  # Metrics calculation delegated to shared module
  defp calculate_current_metrics(state) do
    MetricsCalculator.calculate_current_metrics(state)
  end

  # Helper functions for risk analysis

  defp add_behavioral_risks(risk_factors, behavioral) do
    vulnerabilities = Map.get(behavioral, :vulnerabilities, %{})

    predictable_patterns = Map.get(vulnerabilities, :predictable_patterns, [])

    if length(predictable_patterns) > 0 do
      [{:behavioral, "Predictable activity patterns", :medium} | risk_factors]
    else
      risk_factors
    end
  end

  defp add_tactical_risks(risk_factors, tactical) do
    tactical_score = Map.get(tactical, :tactical_vulnerability_score, 0)

    if tactical_score > 50 do
      [{:tactical, "Significant tactical vulnerabilities", :high} | risk_factors]
    else
      risk_factors
    end
  end

  defp add_operational_risks(risk_factors, operational) do
    operational_score = Map.get(operational, :operational_vulnerability_score, 0)

    if operational_score > 50 do
      [{:operational, "Operational security gaps", :medium} | risk_factors]
    else
      risk_factors
    end
  end

  defp add_social_risks(risk_factors, social) do
    social_score = Map.get(social, :social_vulnerability_score, 0)

    if social_score > 50 do
      [{:social, "Social engineering vulnerabilities", :medium} | risk_factors]
    else
      risk_factors
    end
  end

  defp add_behavioral_mitigations(recommendations, behavioral) do
    mitigations = Map.get(behavioral, :mitigation_recommendations, [])
    recommendations ++ mitigations
  end

  defp add_tactical_mitigations(recommendations, tactical) do
    mitigations = Map.get(tactical, :recommended_counter_strategies, [])
    recommendations ++ mitigations
  end

  defp add_operational_mitigations(recommendations, operational) do
    mitigations = Map.get(operational, :security_recommendations, [])
    recommendations ++ mitigations
  end

  defp add_social_mitigations(recommendations, social) do
    mitigations = Map.get(social, :social_engineering_recommendations, [])
    recommendations ++ mitigations
  end

  defp assess_data_quality(base_data) do
    # Simple data quality assessment
    if map_size(base_data) > 0 do
      0.8
    else
      0.2
    end
  end

  defp assess_analysis_completeness(vulnerability_scan) do
    # Check if all analysis components are present
    required_components = [
      :behavioral_vulnerabilities,
      :tactical_vulnerabilities,
      :operational_vulnerabilities,
      :social_vulnerabilities
    ]

    present_components = Enum.count(required_components, &Map.has_key?(vulnerability_scan, &1))
    present_components / length(required_components)
  end

  defp get_risk_level(vulnerability_analysis, component) do
    case Map.get(vulnerability_analysis, component) do
      nil ->
        :unknown

      component_data ->
        score_key =
          case component do
            :behavioral_vulnerabilities -> :behavioral_vulnerability_score
            :tactical_vulnerabilities -> :tactical_vulnerability_score
            :operational_vulnerabilities -> :operational_vulnerability_score
            :social_vulnerabilities -> :social_vulnerability_score
          end

        score = Map.get(component_data, score_key, 0)

        cond do
          score > 70 -> :high
          score > 50 -> :medium
          score > 30 -> :low
          true -> :minimal
        end
    end
  end

  defp categorize_recommendations(recommendations) do
    # Simple categorization - in reality would analyze recommendation priorities
    total = length(recommendations)
    immediate_count = div(total, 3)
    short_term_count = div(total, 3)

    immediate = Enum.take(recommendations, immediate_count)
    short_term = Enum.take(recommendations, short_term_count) |> Enum.drop(immediate_count)
    long_term = Enum.drop(recommendations, immediate_count + short_term_count)

    {immediate, short_term, long_term}
  end

  defp determine_review_schedule(threat_level) do
    case threat_level do
      :critical -> "Weekly"
      :high -> "Bi-weekly"
      :medium -> "Monthly"
      :low -> "Quarterly"
      :minimal -> "Annually"
    end
  end
end
