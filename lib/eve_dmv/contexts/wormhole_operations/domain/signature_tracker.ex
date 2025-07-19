defmodule EveDmv.Contexts.WormholeOperations.Domain.SignatureTracker do
  @moduledoc """
  Tracks and manages wormhole signatures within systems.

  Provides signature lifecycle management, type identification,
  and intelligent signature analysis for wormhole operations.

  Features:
  - Signature tracking with automatic type detection
  - Signature lifecycle (unscanned -> identified -> critical -> gone)
  - K162 spawn detection and backtracking
  - Signature strength analysis for site difficulty
  - Integration with chain tracking for connection management
  """

  alias EveDmv.StaticData
  alias EveDmv.Contexts.WormholeOperations.Domain.ChainTracker
  require Logger

  # Signature type patterns for identification
  @signature_patterns %{
    # Wormhole signatures like H296, K162
    wormhole: ~r/^[A-Z]\d{3}$/,
    # Data sites
    data: ~r/Data\s+(Site|Perimeter)/i,
    # Relic sites
    relic: ~r/Relic\s+(Site|Perimeter)/i,
    # Gas sites
    gas: ~r/(Nebula|Reservoir|Cloud)/i,
    # Combat sites
    combat: ~r/(Garrison|Outpost|Perimeter|Frontier)/i
  }

  # Wormhole signature strengths by class
  @wormhole_strengths %{
    wormhole_c1: 0.10,
    wormhole_c2: 0.10,
    wormhole_c3: 0.10,
    wormhole_c4: 0.05,
    wormhole_c5: 0.01,
    wormhole_c6: 0.01,
    highsec: 0.10,
    lowsec: 0.10,
    nullsec: 0.05
  }

  # Site difficulty by signature strength
  @site_difficulties %{
    {0.25, 1.0} => :easy,
    {0.10, 0.25} => :medium,
    {0.05, 0.10} => :hard,
    {0.01, 0.05} => :dangerous,
    {0.0, 0.01} => :deadly
  }

  @doc """
  Track a new signature in a system.

  ## Parameters
  - system_id: EVE system ID
  - sig_id: In-game signature ID (e.g., "ABC-123")
  - sig_type: Type of signature (wormhole, data, relic, gas, combat, unknown)
  - options:
    - strength: Signal strength percentage (0.0 - 1.0)
    - name: Scanned name of the signature
    - wormhole_type: For wormholes, the type code (H296, K162, etc)
    - destination_id: For wormholes, the destination system ID
  """
  def track_signature(system_id, sig_id, sig_type, options \\ []) do
    with {:ok, system} <- validate_system(system_id),
         {:ok, sig_type} <- validate_signature_type(sig_type) do
      signature = %{
        system_id: system_id,
        system_name: system.system_name,
        system_class: StaticData.classify_system(system_id),
        sig_id: sig_id,
        sig_type: sig_type,
        strength: Keyword.get(options, :strength),
        name: Keyword.get(options, :name),
        status: determine_status(sig_type, options),
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        metadata: build_metadata(sig_type, options)
      }

      # In production, would persist to database
      {:ok, enrich_signature(signature)}
    end
  end

  @doc """
  Update an existing signature with new information.

  Handles signature lifecycle transitions and updates metadata.
  """
  def update_signature(system_id, sig_id, updates) do
    # In production, would fetch from database
    # For now, create updated signature

    with {:ok, _system} <- validate_system(system_id) do
      updated_sig =
        %{
          system_id: system_id,
          sig_id: sig_id,
          updated_at: DateTime.utc_now()
        }
        |> Map.merge(updates)
        |> handle_status_transition()

      {:ok, updated_sig}
    end
  end

  @doc """
  Analyze signatures in a system to identify patterns and threats.

  Returns analysis including:
  - New K162 spawns (indicating incoming connections)
  - Missing signatures (possibly collapsed/despawned)
  - Site composition and difficulty breakdown
  - Recommended actions
  """
  def analyze_system_signatures(system_id, current_sigs, previous_sigs \\ []) do
    with {:ok, system} <- validate_system(system_id) do
      current_ids = MapSet.new(current_sigs, & &1.sig_id)
      previous_ids = MapSet.new(previous_sigs, & &1.sig_id)

      # Detect changes
      new_sigs = MapSet.difference(current_ids, previous_ids) |> MapSet.to_list()
      missing_sigs = MapSet.difference(previous_ids, current_ids) |> MapSet.to_list()

      # Find new K162s (incoming wormholes)
      new_k162s =
        current_sigs
        |> Enum.filter(fn sig ->
          sig.sig_id in new_sigs and
            get_in(sig, [:metadata, :wormhole_type]) == "K162"
        end)

      # Analyze site composition
      site_breakdown = analyze_site_composition(current_sigs)

      # Generate threat assessment
      threat_assessment =
        assess_signature_threats(new_k162s, site_breakdown, system.security_class)

      analysis = %{
        system_id: system_id,
        system_name: system.system_name,
        total_signatures: length(current_sigs),
        changes: %{
          new: length(new_sigs),
          missing: length(missing_sigs),
          new_k162s: length(new_k162s)
        },
        composition: site_breakdown,
        threat_assessment: threat_assessment,
        recommendations: generate_recommendations(new_k162s, site_breakdown, threat_assessment)
      }

      {:ok, analysis}
    end
  end

  @doc """
  Detect signature patterns that indicate specific activities.

  Patterns detected:
  - Rage rolling (rapid signature changes)
  - Active farming (progressive site clearing)
  - Chain rolling (systematic connection cycling)
  """
  def detect_activity_patterns(_system_id, signature_history, time_window_minutes \\ 60) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -time_window_minutes * 60, :second)

    # Filter recent signatures
    recent_sigs =
      Enum.filter(signature_history, fn sig ->
        DateTime.compare(sig.created_at, cutoff_time) == :gt
      end)

    # Group by signature ID to track lifecycle
    sig_lifecycles = Enum.group_by(recent_sigs, & &1.sig_id)

    # Detect patterns
    patterns = %{
      rage_rolling: detect_rage_rolling(sig_lifecycles, time_window_minutes),
      active_farming: detect_active_farming(sig_lifecycles),
      chain_rolling: detect_chain_rolling(sig_lifecycles),
      scanning_activity: calculate_scanning_rate(recent_sigs, time_window_minutes)
    }

    # Generate activity summary
    {:ok,
     %{
       time_window_minutes: time_window_minutes,
       patterns_detected: patterns,
       activity_level: determine_activity_level(patterns),
       recommendations: activity_recommendations(patterns)
     }}
  end

  @doc """
  Calculate optimal signature scanning order based on threat and value.
  """
  def prioritize_signatures(signatures, priorities \\ %{}) do
    default_priorities = %{
      # Always scan wormholes first
      wormhole: 100,
      # Combat sites for ISK
      combat: 20,
      # Data sites moderate priority
      data: 30,
      # Relic sites moderate priority
      relic: 30,
      # Gas sites lower priority
      gas: 10,
      # Unknown could be anything
      unknown: 50
    }

    priorities = Map.merge(default_priorities, priorities)

    sorted_sigs =
      signatures
      |> Enum.map(fn sig ->
        priority_score = calculate_priority_score(sig, priorities)
        Map.put(sig, :scan_priority, priority_score)
      end)
      |> Enum.sort_by(& &1.scan_priority, :desc)

    {:ok,
     %{
       prioritized_signatures: sorted_sigs,
       estimated_scan_time: estimate_scan_time(sorted_sigs),
       high_priority_count: Enum.count(sorted_sigs, &(&1.scan_priority > 75))
     }}
  end

  # Private helper functions

  defp validate_system(system_id) do
    case StaticData.get_system(system_id) do
      nil -> {:error, :system_not_found}
      system -> {:ok, system}
    end
  end

  defp validate_signature_type(sig_type)
       when sig_type in [:wormhole, :data, :relic, :gas, :combat, :unknown] do
    {:ok, sig_type}
  end

  defp validate_signature_type(_), do: {:error, :invalid_signature_type}

  defp determine_status(sig_type, options) do
    cond do
      sig_type == :unknown -> :unscanned
      sig_type == :wormhole and Keyword.has_key?(options, :destination_id) -> :active
      sig_type == :wormhole and Keyword.get(options, :mass_status) == :critical -> :critical
      Keyword.has_key?(options, :name) -> :identified
      true -> :partial
    end
  end

  defp build_metadata(:wormhole, options) do
    %{
      wormhole_type: Keyword.get(options, :wormhole_type),
      destination_id: Keyword.get(options, :destination_id),
      mass_status: Keyword.get(options, :mass_status, :fresh),
      time_status: Keyword.get(options, :time_status, :fresh)
    }
  end

  defp build_metadata(_sig_type, options) do
    %{
      site_name: Keyword.get(options, :name),
      cleared: Keyword.get(options, :cleared, false)
    }
  end

  defp enrich_signature(%{sig_type: :wormhole} = signature) do
    # Add wormhole-specific enrichments
    wh_type = get_in(signature, [:metadata, :wormhole_type])

    enrichments =
      case wh_type do
        "K162" ->
          %{
            connection_type: :incoming,
            threat_level: :high,
            notes: "Incoming connection - potential threat"
          }

        nil ->
          %{}

        _ ->
          %{
            connection_type: :outgoing,
            mass_limit: get_in(ChainTracker.get_mass_limits(wh_type), [:ok, :total]),
            jump_limit: get_in(ChainTracker.get_mass_limits(wh_type), [:ok, :jump])
          }
      end

    Map.merge(signature, enrichments)
  end

  defp enrich_signature(signature), do: signature

  defp handle_status_transition(signature) do
    old_status = Map.get(signature, :old_status)
    new_status = Map.get(signature, :status)

    transition_metadata =
      case {old_status, new_status} do
        {:active, :critical} ->
          %{transitioned_at: DateTime.utc_now(), alert: :mass_critical}

        {:identified, :gone} ->
          %{collapsed_at: DateTime.utc_now(), lifetime_minutes: calculate_lifetime(signature)}

        _ ->
          %{}
      end

    Map.merge(signature, transition_metadata)
  end

  defp analyze_site_composition(signatures) do
    signatures
    |> Enum.group_by(& &1.sig_type)
    |> Enum.map(fn {type, sigs} ->
      {type,
       %{
         count: length(sigs),
         percentage: length(sigs) / max(length(signatures), 1) * 100,
         identified: Enum.count(sigs, &(&1.status in [:identified, :active]))
       }}
    end)
    |> Map.new()
  end

  defp assess_signature_threats(new_k162s, site_breakdown, security_class) do
    threat_score = 0

    # K162s are immediate threats
    threat_score = threat_score + length(new_k162s) * 30

    # Many combat sites might indicate active farmers
    combat_count = get_in(site_breakdown, [:combat, :count]) || 0
    threat_score = threat_score + if combat_count > 5, do: 20, else: 0

    # Low-class wormholes with many sigs are high-traffic
    total_sigs =
      site_breakdown
      |> Map.values()
      |> Enum.map(& &1.count)
      |> Enum.sum()

    threat_score =
      if security_class in ["C1", "C2", "C3"] and total_sigs > 10 do
        threat_score + 15
      else
        threat_score
      end

    %{
      score: threat_score,
      level:
        cond do
          threat_score >= 60 -> :extreme
          threat_score >= 40 -> :high
          threat_score >= 20 -> :medium
          threat_score >= 10 -> :low
          true -> :minimal
        end,
      factors: %{
        new_k162s: length(new_k162s),
        combat_sites: combat_count,
        total_signatures: total_sigs
      }
    }
  end

  defp generate_recommendations(new_k162s, site_breakdown, threat_assessment) do
    recommendations = []

    # K162 recommendations
    recommendations =
      if length(new_k162s) > 0 do
        ["#{length(new_k162s)} new K162(s) detected - check for hostiles" | recommendations]
      else
        recommendations
      end

    # Threat level recommendations
    recommendations =
      case threat_assessment.level do
        level when level in [:extreme, :high] ->
          ["High threat environment - maintain hole control" | recommendations]

        :medium ->
          ["Moderate activity - keep scouts active" | recommendations]

        _ ->
          recommendations
      end

    # Site recommendations
    wh_count = get_in(site_breakdown, [:wormhole, :count]) || 0

    recommendations =
      if wh_count > 3 do
        ["Multiple wormholes present - map chain carefully" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["System appears quiet - continue normal operations"]
    else
      recommendations
    end
  end

  defp detect_rage_rolling(sig_lifecycles, _time_window) do
    # Rage rolling: Many wormholes appearing and disappearing quickly
    wh_sigs =
      sig_lifecycles
      |> Enum.filter(fn {_id, sigs} ->
        Enum.any?(sigs, &(&1.sig_type == :wormhole))
      end)

    short_lived_whs =
      Enum.count(wh_sigs, fn {_id, sigs} ->
        lifetime = calculate_signature_lifetime(sigs)
        # Less than 30 minutes
        lifetime > 0 and lifetime < 30
      end)

    %{
      detected: short_lived_whs >= 3,
      confidence: min(short_lived_whs * 25, 100),
      collapsed_holes: short_lived_whs
    }
  end

  defp detect_active_farming(sig_lifecycles) do
    # Active farming: Sites being cleared systematically
    cleared_sites =
      sig_lifecycles
      |> Enum.count(fn {_id, sigs} ->
        Enum.any?(sigs, fn sig ->
          sig.sig_type in [:data, :relic, :combat] and
            get_in(sig, [:metadata, :cleared])
        end)
      end)

    %{
      detected: cleared_sites >= 3,
      sites_cleared: cleared_sites,
      estimated_farmers: div(cleared_sites, 3) + 1
    }
  end

  defp detect_chain_rolling(sig_lifecycles) do
    # Chain rolling: Specific wormhole being repeatedly collapsed
    wh_collapses =
      sig_lifecycles
      |> Enum.map(fn {_id, sigs} ->
        wh_sigs = Enum.filter(sigs, &(&1.sig_type == :wormhole))

        if length(wh_sigs) >= 2 do
          get_in(List.first(wh_sigs), [:metadata, :wormhole_type])
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    max_collapses =
      if map_size(wh_collapses) > 0 do
        wh_collapses |> Map.values() |> Enum.max()
      else
        0
      end

    %{
      detected: max_collapses >= 2,
      most_rolled: wh_collapses |> Enum.max_by(fn {_k, v} -> v end, fn -> {nil, 0} end),
      total_rolls: Map.values(wh_collapses) |> Enum.sum()
    }
  end

  defp calculate_scanning_rate(sigs, time_window) do
    identified_count = Enum.count(sigs, &(&1.status in [:identified, :active]))
    rate_per_hour = identified_count / max(time_window / 60, 1)

    %{
      signatures_scanned: identified_count,
      rate_per_hour: Float.round(rate_per_hour, 2),
      efficiency:
        cond do
          rate_per_hour > 10 -> :excellent
          rate_per_hour > 5 -> :good
          rate_per_hour > 2 -> :moderate
          true -> :slow
        end
    }
  end

  defp determine_activity_level(patterns) do
    active_patterns =
      Enum.count(
        [
          patterns.rage_rolling.detected,
          patterns.active_farming.detected,
          patterns.chain_rolling.detected
        ],
        & &1
      )

    scan_rate = patterns.scanning_activity.rate_per_hour

    cond do
      active_patterns >= 2 or scan_rate > 15 -> :very_high
      active_patterns >= 1 or scan_rate > 10 -> :high
      scan_rate > 5 -> :moderate
      scan_rate > 2 -> :low
      true -> :minimal
    end
  end

  defp activity_recommendations(patterns) do
    recommendations = []

    recommendations =
      if patterns.rage_rolling.detected do
        ["Rage rolling detected - hostile fleet likely seeking targets" | recommendations]
      else
        recommendations
      end

    recommendations =
      if patterns.active_farming.detected do
        ["Active farming detected - potential targets in system" | recommendations]
      else
        recommendations
      end

    recommendations =
      if patterns.chain_rolling.detected do
        ["Chain rolling detected - someone controlling connections" | recommendations]
      else
        recommendations
      end

    recommendations =
      case patterns.scanning_activity.efficiency do
        :excellent -> ["Very high scan rate - multiple scanners active" | recommendations]
        :slow -> ["Low scan activity - possibly safe to operate" | recommendations]
        _ -> recommendations
      end

    if Enum.empty?(recommendations) do
      ["Normal signature activity detected"]
    else
      recommendations
    end
  end

  defp calculate_priority_score(signature, priorities) do
    base_priority = Map.get(priorities, signature.sig_type, 0)

    # Adjust based on signature properties
    adjustments = 0

    # Boost K162 priority
    adjustments =
      if get_in(signature, [:metadata, :wormhole_type]) == "K162" do
        adjustments + 50
      else
        adjustments
      end

    # Boost unscanned signatures
    adjustments =
      if signature.status == :unscanned do
        adjustments + 20
      else
        adjustments
      end

    # Reduce priority for cleared sites
    adjustments =
      if get_in(signature, [:metadata, :cleared]) do
        adjustments - 30
      else
        adjustments
      end

    # Boost critical wormholes
    adjustments =
      if signature.status == :critical do
        adjustments + 30
      else
        adjustments
      end

    max(0, min(100, base_priority + adjustments))
  end

  defp estimate_scan_time(signatures) do
    # Estimate based on signature count and types
    # 30 seconds per sig average
    base_time = length(signatures) * 30

    # Adjust for difficulty
    difficulty_modifier =
      signatures
      |> Enum.map(fn sig ->
        case sig.sig_type do
          # Wormholes take longer
          :wormhole -> 1.5
          # Unknown sigs need full scan
          :unknown -> 2.0
          _ -> 1.0
        end
      end)
      |> Enum.sum()
      |> Kernel./(length(signatures))

    seconds = base_time * difficulty_modifier

    %{
      total_seconds: round(seconds),
      formatted: format_duration(seconds)
    }
  end

  defp format_duration(seconds) do
    minutes = div(round(seconds), 60)
    remaining_seconds = rem(round(seconds), 60)

    "#{minutes}m #{remaining_seconds}s"
  end

  defp calculate_lifetime(signature) do
    if signature.created_at and Map.get(signature, :collapsed_at) do
      DateTime.diff(signature.collapsed_at, signature.created_at, :minute)
    else
      0
    end
  end

  defp calculate_signature_lifetime(sigs) do
    sorted = Enum.sort_by(sigs, & &1.created_at, DateTime)

    if length(sorted) >= 2 do
      first = List.first(sorted)
      last = List.last(sorted)
      DateTime.diff(last.created_at, first.created_at, :minute)
    else
      0
    end
  end
end
