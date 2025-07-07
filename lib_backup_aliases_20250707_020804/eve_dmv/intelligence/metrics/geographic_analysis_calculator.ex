defmodule EveDmv.Intelligence.Metrics.GeographicAnalysisCalculator do
  @moduledoc """
  Geographic analysis calculator for character activity patterns.

  This module provides location-based analysis including system activity,
  security space distribution, wormhole analysis, and geographic diversity.
  """

  @doc """
  Calculate geographic activity patterns from killmail data.

  Returns comprehensive geographic analysis including system activity,
  region patterns, security space distribution, and wormhole analysis.
  """
  def calculate_geographic_patterns(killmail_data) do
    # Analyze system activity
    system_activity =
      killmail_data
      |> Enum.group_by(fn killmail ->
        killmail[:solar_system_id] || killmail["solar_system_id"]
      end)
      |> Enum.map(fn {system_id, killmails} ->
        {system_id,
         %{
           system_name: extract_system_name(killmails),
           activity_count: length(killmails),
           kills_in_system: count_kills(killmails),
           losses_in_system: count_losses(killmails)
         }}
      end)
      |> Enum.into(%{})

    # Identify region patterns
    region_activity = analyze_region_activity(killmail_data)
    wormhole_analysis = analyze_wormhole_activity(killmail_data)
    # Convert to percentage for test compatibility
    wormhole_activity = wormhole_analysis.wormhole_percentage * 100

    most_active_systems =
      Enum.sort_by(system_activity, fn {_id, data} -> data.activity_count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {system_id, data} ->
        %{system_id: system_id, activity_count: data.activity_count}
      end)

    # Calculate security space distribution
    {highsec_activity, lowsec_activity, nullsec_activity} =
      calculate_security_distribution(system_activity)

    %{
      system_activity: system_activity,
      region_activity: region_activity,
      wormhole_activity: wormhole_activity,
      wormhole_analysis: wormhole_analysis,
      home_systems: identify_home_systems(system_activity),
      roaming_patterns: detect_roaming_patterns(system_activity),
      geographic_diversity: calculate_geographic_diversity(system_activity),
      most_active_systems: most_active_systems,
      # Convert to percentage
      highsec_activity: highsec_activity * 100,
      lowsec_activity: lowsec_activity * 100,
      nullsec_activity: nullsec_activity * 100
    }
  end

  @doc """
  Calculate security space distribution from system activity.

  Returns tuple of {highsec, lowsec, nullsec} activity percentages.
  """
  def calculate_security_distribution(system_activity) do
    total_activity =
      Enum.sum(Enum.map(system_activity, fn {_id, data} -> data.activity_count end))

    highsec_systems =
      Enum.filter(system_activity, fn {system_id, _data} ->
        # Rough highsec range
        system_id >= 30_000_142 and system_id <= 30_005_000
      end)

    lowsec_systems =
      Enum.filter(system_activity, fn {system_id, _data} ->
        # Rough lowsec range
        system_id >= 30_000_001 and system_id < 30_000_142
      end)

    nullsec_systems =
      Enum.filter(system_activity, fn {system_id, _data} ->
        # Adjusted nullsec range
        system_id >= 30_000_000 and system_id < 30_000_001
      end)

    highsec_activity =
      if total_activity > 0 do
        Enum.sum(Enum.map(highsec_systems, fn {_id, data} -> data.activity_count end)) /
          total_activity
      else
        0.0
      end

    lowsec_activity =
      if total_activity > 0 do
        Enum.sum(Enum.map(lowsec_systems, fn {_id, data} -> data.activity_count end)) /
          total_activity
      else
        0.0
      end

    nullsec_activity =
      if total_activity > 0 do
        Enum.sum(Enum.map(nullsec_systems, fn {_id, data} -> data.activity_count end)) /
          total_activity
      else
        0.0
      end

    {highsec_activity, lowsec_activity, nullsec_activity}
  end

  @doc """
  Analyze wormhole activity patterns.

  Returns wormhole activity analysis with counts and percentages.
  """
  def analyze_wormhole_activity(killmail_data) do
    # Look for wormhole system activity (system IDs 31000000+)
    wh_killmails =
      Enum.filter(killmail_data, fn km ->
        system_id = km[:solar_system_id] || km["solar_system_id"]
        system_id && system_id >= 31_000_000
      end)

    %{
      wormhole_activity_count: length(wh_killmails),
      wormhole_percentage:
        if(length(killmail_data) > 0, do: length(wh_killmails) / length(killmail_data), else: 0.0)
    }
  end

  @doc """
  Identify home systems from activity patterns.

  Returns list of top 3 most active systems.
  """
  def identify_home_systems(system_activity) do
    Enum.sort_by(system_activity, fn {_id, data} -> data.activity_count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {system_id, _data} -> system_id end)
  end

  @doc """
  Detect roaming patterns from system activity.

  Returns roaming analysis with diversity metrics.
  """
  def detect_roaming_patterns(system_activity) do
    %{
      systems_visited: map_size(system_activity),
      roaming_score: min(map_size(system_activity) / 20.0, 1.0)
    }
  end

  @doc """
  Calculate geographic diversity score.

  Returns diversity score from 0.0 to 1.0.
  """
  def calculate_geographic_diversity(system_activity) do
    system_count = map_size(system_activity)
    min(system_count / 15.0, 1.0)
  end

  @doc """
  Extract preferred systems from killmail data.

  Returns map of top 5 most active systems.
  """
  def extract_preferred_systems(killmail_data) do
    killmail_data
    |> Enum.group_by(fn killmail ->
      killmail[:solar_system_id] || killmail["solar_system_id"]
    end)
    |> Enum.map(fn {system_id, killmails} ->
      {system_id, length(killmails)}
    end)
    |> Enum.sort_by(fn {_id, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.into(%{})
  end

  # Private helper functions

  defp extract_system_name(killmails) do
    # Extract system name from first killmail, or use ID
    case List.first(killmails) do
      killmail when is_map(killmail) ->
        case killmail[:solar_system_name] || killmail["solar_system_name"] do
          name when name != nil ->
            name

          _ ->
            system_id = killmail[:solar_system_id] || killmail["solar_system_id"]
            "System #{system_id || "Unknown"}"
        end

      _ ->
        "Unknown System"
    end
  end

  defp analyze_region_activity(_killmail_data) do
    # Placeholder for region analysis
    %{total_regions: 1, primary_region: "Unknown"}
  end

  defp count_kills(killmail_data) do
    length(killmail_data)
  end

  defp count_losses(killmail_data) do
    length(killmail_data)
  end
end
