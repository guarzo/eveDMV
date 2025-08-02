defmodule EveDmvWeb.Live.FleetOperations.Components.FleetCompositionComponent do
  @moduledoc """
  Component for displaying fleet composition analysis and doctrine compliance.
  """
  """

  use Phoenix.LiveComponent
  alias EveDmvWeb.Utils.FormattingUtils

  def render(assigns) do
    ~H"""
    <div class="fleet-composition-analysis">
      <h3>Fleet Composition Analysis</h3>

      <div class="composition-stats">
        <div class="stat-card">
          <span class="label">Total Ships</span>
          <span class="value"><%= map_size(@composition_data.ship_classes || %{}) %></span>
        </div>

        <div class="stat-card">
          <span class="label">Total Value</span>
          <span class="value"><%= format_isk(@composition_data.total_value || 0) %></span>
        </div>

        <div class="stat-card">
          <span class="label">Average Value</span>
          <span class="value"><%= format_isk_short(@composition_data.avg_value || 0) %></span>
        </div>
      </div>

      <div class="ship-classes">
        <%= for {ship_class, data} <- (@composition_data.ship_classes || %{}) do %>
          <div class="ship-class-row">
            <span class="class-name"><%= ship_class %></span>
            <span class="count"><%= data.count || 0 %></span>
            <span class="percentage"><%= Float.round(data.percentage || 0.0, 1) %>%</span>
          </div>
        <% end %>
      </div>

      <div class="doctrine-analysis">
        <div class="compliance-score">
          <div class={"score-circle score-#{doctrine_score_class(@composition_data.doctrine_analysis.compliance_score)}"}>
            <span class="score"><%= Float.round(@composition_data.doctrine_analysis.compliance_score || 0.0, 1) %>%</span>
          </div>

          <span class={"rating-#{compliance_rating(@composition_data.doctrine_analysis.compliance_score)}"}>
            <%= format_compliance_rating(@composition_data.doctrine_analysis.compliance_score) %>
          </span>
        </div>

        <div class="recommendations">
          <%= for recommendation <- (@composition_data.doctrine_analysis.recommendations || []) do %>
            <div class="recommendation">
              <span class="type"><%= format_recommendation_type(recommendation.type) %></span>
              <span class="description"><%= recommendation.description %></span>
            </div>
          <% end %>
        </div>

        <div class="deviations">
          <%= for deviation <- (@composition_data.doctrine_analysis.deviations || []) do %>
            <div class="deviation">
              <span class="deviation-type"><%= format_deviation_type(deviation.type) %></span>
              <span class="impact"><%= deviation.impact %></span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000_000 -> "#{Float.round(value / 1_000_000_000_000, 1)}T"
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K"
      true -> "#{round(value)}"
    end
  end

  defp format_isk(nil), do: "0"
  defp format_isk(_), do: "0"

  defp format_isk_short(value) do
    FormattingUtils.format_isk_short(value)
  end

  defp doctrine_score_class(score) when is_number(score) do
    cond do
      score >= 80 -> "excellent"
      score >= 60 -> "good"
      score >= 40 -> "fair"
      true -> "poor"
    end
  end

  defp doctrine_score_class(_), do: "unknown"

  defp compliance_rating(score) when is_number(score) do
    cond do
      score >= 80 -> "excellent"
      score >= 60 -> "good"
      score >= 40 -> "fair"
      true -> "poor"
    end
  end

  defp compliance_rating(_), do: "unknown"

  defp format_compliance_rating(score) when is_number(score) do
    cond do
      score >= 80 -> "Excellent"
      score >= 60 -> "Good"
      score >= 40 -> "Fair"
      true -> "Poor"
    end
  end

  defp format_compliance_rating(_), do: "Unknown"

  defp format_recommendation_type(type) when is_binary(type), do: String.capitalize(type)

  defp format_recommendation_type(type) when is_atom(type),
    do: Atom.to_string(type) |> String.capitalize()

  defp format_recommendation_type(_), do: "Unknown"

  defp format_deviation_type(type) when is_binary(type), do: String.capitalize(type)

  defp format_deviation_type(type) when is_atom(type),
    do: Atom.to_string(type) |> String.capitalize()

  defp format_deviation_type(_), do: "Unknown"
end
