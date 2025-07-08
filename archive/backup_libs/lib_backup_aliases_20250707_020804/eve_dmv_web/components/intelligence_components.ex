defmodule EveDmvWeb.IntelligenceComponents do
  @moduledoc """
  Enhanced UI components for displaying intelligence analysis results.

  Provides sophisticated visualization components for character analysis,
  threat assessment, and intelligence scoring with improved user experience.
  """

  alias Phoenix.LiveView.JS
  use Phoenix.Component

  @doc """
  Displays a comprehensive intelligence score card with visual indicators.
  """
  attr(:score_data, :map, required: true)
  attr(:class, :string, default: "")

  def intelligence_score_card(assigns) do
    ~H"""
    <div class={"intelligence-score-card #{@class}"}>
      <div class="score-header">
        <div class="score-grade-display">
          <span class={"grade-badge grade-#{String.downcase(@score_data.score_grade)}"}>
            {@score_data.score_grade}
          </span>
          <div class="score-details">
            <div class="overall-score">{Float.round(@score_data.overall_score * 100, 1)}%</div>
            <div class="confidence-level">
              Confidence: {Float.round(@score_data.confidence_level * 100, 1)}%
            </div>
          </div>
        </div>

        <div class="score-methodology">
          <small class="text-muted">{@score_data.scoring_methodology}</small>
        </div>
      </div>

      <div class="component-scores">
        <h4>Component Analysis</h4>
        <div class="score-components">
          <%= for {component, score} <- @score_data.component_scores do %>
            <.score_component_bar
              label={humanize_component(component)}
              score={score}
              component={component}
            />
          <% end %>
        </div>
      </div>

      <div class="recommendations-section">
        <h4>Intelligence Assessment</h4>
        <ul class="recommendations-list">
          <%= for recommendation <- @score_data.recommendations do %>
            <li class="recommendation-item">
              <i class="icon-info"></i>
              {recommendation}
            </li>
          <% end %>
        </ul>
      </div>

      <div class="analysis-timestamp">
        <small class="text-muted">
          Analysis completed: {format_timestamp(@score_data.analysis_timestamp)}
        </small>
      </div>
    </div>
    """
  end

  @doc """
  Displays a horizontal score bar for individual components.
  """
  attr(:label, :string, required: true)
  attr(:score, :float, required: true)
  attr(:component, :atom, required: true)

  def score_component_bar(assigns) do
    ~H"""
    <div class="score-component">
      <div class="component-label">
        <span class="label-text">{@label}</span>
        <span class="score-value">{Float.round(@score * 100, 1)}%</span>
      </div>
      <div class="progress-bar-container">
        <div class={"progress-bar progress-#{score_color(@score)}"} style={"width: #{@score * 100}%"}>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Advanced threat assessment display with visual threat level indicators.
  """
  attr(:threat_data, :map, required: true)
  attr(:expanded, :boolean, default: false)

  def threat_assessment_display(assigns) do
    ~H"""
    <div class="threat-assessment-card">
      <div class="threat-header">
        <div class={"threat-level-indicator threat-#{@threat_data.threat_level}"}>
          <div class="threat-icon">
            {threat_level_icon(@threat_data.threat_level)}
          </div>
          <div class="threat-details">
            <h3>Threat Level: {String.upcase(@threat_data.threat_level)}</h3>
            <div class="threat-score">
              Score: {Float.round(@threat_data.threat_score * 100, 1)}%
            </div>
          </div>
        </div>

        <button
          class="expand-toggle"
          phx-click={
            JS.toggle(
              to:
                "#threat-details-#{:crypto.hash(:md5, inspect(@threat_data)) |> Base.encode16(case: :lower)}"
            )
          }
        >
          {if @expanded, do: "Hide Details", else: "Show Details"}
        </button>
      </div>

      <div
        id={"threat-details-#{:crypto.hash(:md5, inspect(@threat_data)) |> Base.encode16(case: :lower)}"}
        class={if @expanded, do: "threat-details expanded", else: "threat-details"}
      >
        <div class="threat-indicators">
          <h4>Threat Indicators</h4>
          <div class="indicators-grid">
            <%= for {indicator, score} <- @threat_data.threat_indicators do %>
              <div class="threat-indicator">
                <div class="indicator-label">{humanize_component(indicator)}</div>
                <div class="indicator-value">
                  <.threat_indicator_meter score={score} />
                  <span class="score-text">{Float.round(score * 100, 1)}%</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="mitigation-strategies">
          <h4>Recommended Mitigation Strategies</h4>
          <ul class="mitigation-list">
            <%= for strategy <- @threat_data.mitigation_strategies do %>
              <li class="mitigation-item">
                <i class="icon-shield"></i>
                {strategy}
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Displays behavioral pattern analysis with visual pattern indicators.
  """
  attr(:pattern_data, :map, required: true)
  attr(:character_name, :string, default: "Unknown")

  def behavioral_patterns_display(assigns) do
    ~H"""
    <div class="behavioral-patterns-card">
      <div class="patterns-header">
        <h3>Behavioral Pattern Analysis</h3>
        <div class="character-info">
          <span class="character-name">{@character_name}</span>
          <div class="confidence-indicator">
            <span class="confidence-label">Analysis Confidence:</span>
            <div class={"confidence-badge confidence-#{confidence_level(@pattern_data.confidence_score)}"}>
              {Float.round(@pattern_data.confidence_score * 100, 1)}%
            </div>
          </div>
        </div>
      </div>

      <div class="patterns-grid">
        <div class="pattern-category">
          <h4>Activity Rhythm</h4>
          <.activity_rhythm_display rhythm={@pattern_data.patterns.activity_rhythm} />
        </div>

        <div class="pattern-category">
          <h4>Engagement Patterns</h4>
          <.engagement_patterns_display patterns={@pattern_data.patterns.engagement_patterns} />
        </div>

        <div class="pattern-category">
          <h4>Social Patterns</h4>
          <.social_patterns_display patterns={@pattern_data.patterns.social_patterns} />
        </div>

        <div class="pattern-category">
          <h4>Anomaly Detection</h4>
          <.anomaly_detection_display anomalies={@pattern_data.patterns.anomaly_detection} />
        </div>
      </div>

      <div class="pattern-recommendations">
        <h4>Pattern-Based Recommendations</h4>
        <div class="recommendations-grid">
          <%= for recommendation <- @pattern_data.recommendations do %>
            <div class="recommendation-card">
              <i class="icon-lightbulb"></i>
              <span>{recommendation}</span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Recruitment fitness assessment display with decision factors.
  """
  attr(:fitness_data, :map, required: true)
  attr(:character_id, :integer, required: true)

  def recruitment_fitness_display(assigns) do
    ~H"""
    <div class="recruitment-fitness-card">
      <div class="fitness-header">
        <div class={"recruitment-decision recruitment-#{@fitness_data.recruitment_recommendation.decision}"}>
          <div class="decision-badge">
            {String.upcase(@fitness_data.recruitment_recommendation.decision)}
          </div>
          <div class="fitness-score">
            Fitness Score: {Float.round(@fitness_data.recruitment_score * 100, 1)}%
          </div>
          <div class="priority-indicator">
            Priority: {String.upcase(@fitness_data.recruitment_recommendation.priority)}
          </div>
        </div>
      </div>

      <div class="fitness-breakdown">
        <h4>Fitness Components</h4>
        <div class="fitness-components">
          <%= for {component, score} <- @fitness_data.fitness_components do %>
            <.fitness_component_display
              component={component}
              score={score}
              is_key_factor={component in @fitness_data.decision_factors}
            />
          <% end %>
        </div>
      </div>

      <div class="requirement-compliance">
        <h4>Corporation Requirements</h4>
        <div class="requirements-grid">
          <%= for {requirement, met} <- @fitness_data.requirement_scores do %>
            <div class={"requirement-item requirement-#{if met, do: "met", else: "not-met"}"}>
              <i class={if met, do: "icon-check", else: "icon-x"}></i>
              <span>{humanize_component(requirement)}</span>
            </div>
          <% end %>
        </div>
      </div>

      <div :if={length(@fitness_data.probation_recommendations) > 0} class="probation-terms">
        <h4>Recommended Probation Terms</h4>
        <ul class="probation-list">
          <%= for term <- @fitness_data.probation_recommendations do %>
            <li class="probation-term">
              <i class="icon-clock"></i>
              {term}
            </li>
          <% end %>
        </ul>
      </div>

      <div class="recruitment-notes">
        <div class="notes-content">
          <strong>Assessment Notes:</strong>
          <p>{@fitness_data.recruitment_recommendation.notes}</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Interactive intelligence dashboard with real-time updates.
  """
  attr(:dashboard_data, :map, required: true)
  attr(:live_updates, :boolean, default: false)

  def intelligence_dashboard(assigns) do
    ~H"""
    <div class="intelligence-dashboard">
      <div class="dashboard-header">
        <h2>Intelligence Operations Dashboard</h2>
        <div class="dashboard-controls">
          <div class="update-indicator">
            <span class={"status-dot status-#{if @live_updates, do: "active", else: "inactive"}"}>
            </span>
            <span class="status-text">
              {if @live_updates, do: "Live Updates Active", else: "Updates Paused"}
            </span>
          </div>
          <button class="refresh-button" phx-click="refresh_dashboard" title="Refresh Dashboard">
            <i class="icon-refresh"></i> Refresh
          </button>
        </div>
      </div>

      <div class="dashboard-metrics">
        <div class="metrics-grid">
          <.metric_card
            title="Active Analyses"
            value={@dashboard_data.active_analyses}
            icon="icon-activity"
            trend={@dashboard_data.analysis_trend}
          />

          <.metric_card
            title="Threat Alerts"
            value={@dashboard_data.threat_alerts}
            icon="icon-alert-triangle"
            trend={@dashboard_data.alert_trend}
            alert_level={@dashboard_data.max_threat_level}
          />

          <.metric_card
            title="Cache Performance"
            value={"#{@dashboard_data.cache_hit_ratio}%"}
            icon="icon-database"
            trend={@dashboard_data.cache_trend}
          />

          <.metric_card
            title="System Performance"
            value={"#{@dashboard_data.avg_response_time}ms"}
            icon="icon-cpu"
            trend={@dashboard_data.performance_trend}
          />
        </div>
      </div>

      <div class="dashboard-content">
        <div class="dashboard-section">
          <h3>Recent Intelligence Activity</h3>
          <.activity_timeline activities={@dashboard_data.recent_activities} />
        </div>

        <div class="dashboard-section">
          <h3>Threat Overview</h3>
          <.threat_overview_chart threats={@dashboard_data.threat_distribution} />
        </div>

        <div class="dashboard-section">
          <h3>Performance Metrics</h3>
          <.performance_metrics_display metrics={@dashboard_data.performance_metrics} />
        </div>
      </div>
    </div>
    """
  end

  # Helper components for complex displays

  defp activity_rhythm_display(assigns) do
    ~H"""
    <div class="activity-rhythm">
      <div class="rhythm-metric">
        <span class="metric-label">Consistency:</span>
        <.mini_progress_bar score={@rhythm.consistency_score} />
      </div>
      <div class="rhythm-metric">
        <span class="metric-label">Peak Period:</span>
        <span class="metric-value">{@rhythm.peak_activity_period}</span>
      </div>
      <div class="rhythm-metric">
        <span class="metric-label">Frequency:</span>
        <span class="metric-value">{Float.round(@rhythm.engagement_frequency, 2)}/day</span>
      </div>
    </div>
    """
  end

  defp engagement_patterns_display(assigns) do
    ~H"""
    <div class="engagement-patterns">
      <div class="pattern-metric">
        <span class="metric-label">Aggression Index:</span>
        <.mini_progress_bar score={@patterns.aggression_index} />
      </div>
      <div class="pattern-metric">
        <span class="metric-label">Risk Tolerance:</span>
        <.mini_progress_bar score={@patterns.risk_tolerance} />
      </div>
      <div class="pattern-metric">
        <span class="metric-label">Tactical Preferences:</span>
        <div class="tactical-tags">
          <%= for preference <- @patterns.tactical_preferences do %>
            <span class="tactical-tag">{preference}</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp social_patterns_display(assigns) do
    ~H"""
    <div class="social-patterns">
      <div class="social-metric">
        <span class="metric-label">Cooperation Index:</span>
        <.mini_progress_bar score={@patterns.cooperation_index} />
      </div>
      <div class="social-metric">
        <span class="metric-label">Leadership Indicators:</span>
        <div class="leadership-indicators">
          <%= for indicator <- @patterns.leadership_indicators do %>
            <span class="indicator-badge">{indicator}</span>
          <% end %>
        </div>
      </div>
      <div class="social-metric">
        <span class="metric-label">Social Influence:</span>
        <.mini_progress_bar score={@patterns.social_influence} />
      </div>
    </div>
    """
  end

  defp anomaly_detection_display(assigns) do
    ~H"""
    <div class="anomaly-detection">
      <div class="anomaly-summary">
        <div class={"anomaly-count anomaly-#{@anomalies.severity}"}>
          <span class="count-number">{@anomalies.anomaly_count}</span>
          <span class="count-label">Anomalies</span>
        </div>
        <div class="severity-indicator">
          Severity:
          <span class={"severity-#{@anomalies.severity}"}>{String.upcase(@anomalies.severity)}</span>
        </div>
      </div>

      <div :if={length(@anomalies.anomalies_detected) > 0} class="anomaly-list">
        <%= for anomaly <- @anomalies.anomalies_detected do %>
          <div class="anomaly-item">
            <i class="icon-alert-circle"></i>
            <span>{anomaly}</span>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp fitness_component_display(assigns) do
    ~H"""
    <div class={"fitness-component #{if @is_key_factor, do: "key-factor", else: ""}"}>
      <div class="component-header">
        <span class="component-name">
          {humanize_component(@component)}
          <%= if @is_key_factor do %>
            <i class="icon-star key-factor-icon" title="Key Decision Factor"></i>
          <% end %>
        </span>
        <span class="component-score">{Float.round(@score * 100, 1)}%</span>
      </div>
      <div class="component-bar">
        <div
          class={"progress-fill fitness-#{fitness_score_color(@score)}"}
          style={"width: #{@score * 100}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  defp metric_card(assigns) do
    ~H"""
    <div class={"metric-card #{if assigns[:alert_level], do: "alert-#{assigns.alert_level}", else: ""}"}>
      <div class="metric-icon">
        <i class={@icon}></i>
      </div>
      <div class="metric-content">
        <div class="metric-title">{@title}</div>
        <div class="metric-value">{@value}</div>
        <div class={"metric-trend trend-#{@trend}"}>
          <i class={"icon-#{trend_icon(@trend)}"}></i>
          <span>{trend_text(@trend)}</span>
        </div>
      </div>
    </div>
    """
  end

  defp activity_timeline(assigns) do
    ~H"""
    <div class="activity-timeline">
      <%= for activity <- Enum.take(@activities, 10) do %>
        <div class="timeline-item">
          <div class="timeline-marker"></div>
          <div class="timeline-content">
            <div class="activity-type">{activity.type}</div>
            <div class="activity-description">{activity.description}</div>
            <div class="activity-timestamp">{format_relative_time(activity.timestamp)}</div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp threat_overview_chart(assigns) do
    ~H"""
    <div class="threat-overview-chart">
      <div class="chart-legend">
        <%= for {level, count} <- @threats do %>
          <div class="legend-item">
            <span class={"legend-color threat-#{level}"}></span>
            <span class="legend-label">{String.upcase(level)}</span>
            <span class="legend-count">{count}</span>
          </div>
        <% end %>
      </div>

      <div class="chart-visualization">
        <!-- Simplified threat distribution chart -->
        <%= for {level, count} <- @threats do %>
          <div class="threat-bar">
            <div class="bar-label">{String.upcase(level)}</div>
            <div class="bar-container">
              <div
                class={"bar-fill threat-#{level}"}
                style={"width: #{calculate_bar_width(@threats, count)}%"}
              >
              </div>
            </div>
            <div class="bar-count">{count}</div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp performance_metrics_display(assigns) do
    ~H"""
    <div class="performance-metrics">
      <div class="metrics-row">
        <%= for {metric, value} <- @metrics do %>
          <div class="performance-metric">
            <div class="metric-name">{humanize_component(metric)}</div>
            <div class="metric-value">{format_metric_value(metric, value)}</div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp threat_indicator_meter(assigns) do
    ~H"""
    <div class="threat-meter">
      <div
        class={"meter-fill threat-meter-#{threat_meter_color(@score)}"}
        style={"width: #{@score * 100}%"}
      >
      </div>
    </div>
    """
  end

  defp mini_progress_bar(assigns) do
    ~H"""
    <div class="mini-progress-bar">
      <div
        class={"mini-progress-fill progress-#{score_color(@score)}"}
        style={"width: #{@score * 100}%"}
      >
      </div>
    </div>
    """
  end

  # Helper functions for styling and formatting

  defp humanize_component(component) when is_atom(component) do
    component
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_component(component) when is_binary(component) do
    component
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp score_color(score) when score >= 0.8, do: "excellent"
  defp score_color(score) when score >= 0.6, do: "good"
  defp score_color(score) when score >= 0.4, do: "average"
  defp score_color(score) when score >= 0.2, do: "poor"
  defp score_color(_score), do: "critical"

  defp fitness_score_color(score) when score >= 0.8, do: "high"
  defp fitness_score_color(score) when score >= 0.6, do: "medium"
  defp fitness_score_color(_score), do: "low"

  defp threat_meter_color(score) when score >= 0.8, do: "critical"
  defp threat_meter_color(score) when score >= 0.6, do: "high"
  defp threat_meter_color(score) when score >= 0.4, do: "medium"
  defp threat_meter_color(score) when score >= 0.2, do: "low"
  defp threat_meter_color(_score), do: "minimal"

  defp confidence_level(score) when score >= 0.8, do: "high"
  defp confidence_level(score) when score >= 0.6, do: "medium"
  defp confidence_level(_score), do: "low"

  defp threat_level_icon("critical"), do: "⚠️"
  defp threat_level_icon("high"), do: "🔴"
  defp threat_level_icon("medium"), do: "🟡"
  defp threat_level_icon("low"), do: "🟢"
  defp threat_level_icon(_), do: "⚪"

  defp trend_icon("up"), do: "trending-up"
  defp trend_icon("down"), do: "trending-down"
  defp trend_icon("stable"), do: "minus"

  defp trend_text("up"), do: "Increasing"
  defp trend_text("down"), do: "Decreasing"
  defp trend_text("stable"), do: "Stable"

  defp calculate_bar_width(threats, count) do
    max_count = threats |> Enum.map(fn {_, c} -> c end) |> Enum.max(fn -> 1 end)
    if max_count > 0, do: count / max_count * 100, else: 0
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.truncate(:second)
    |> DateTime.to_string()
  end

  defp format_relative_time(timestamp) do
    diff = DateTime.diff(DateTime.utc_now(), timestamp, :second)

    cond do
      diff < 60 -> "#{diff}s ago"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86_400 -> "#{div(diff, 3600)}h ago"
      true -> "#{div(diff, 86_400)}d ago"
    end
  end

  defp format_metric_value(:response_time_ms, value), do: "#{value}ms"
  defp format_metric_value(:cache_hit_ratio, value), do: "#{value}%"
  defp format_metric_value(:memory_usage_mb, value), do: "#{value}MB"
  defp format_metric_value(_, value), do: to_string(value)
end
