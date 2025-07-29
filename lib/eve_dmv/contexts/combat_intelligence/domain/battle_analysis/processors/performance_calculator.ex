defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Processors.PerformanceCalculator do
  @moduledoc """
  Handles performance calculations and metrics for battle analysis.

  Responsible for:
  - Calculating ISK efficiency and kill/death ratios
  - Analyzing ship class performance metrics
  - Computing battle intensity curves and scores
  - Identifying top performers and engagement metrics
  - Processing side-by-side performance comparisons
  """

  require Logger

  @doc """
  Calculate comprehensive performance metrics from killmails and participants.
  """
  def calculate_performance_metrics(killmails, participants) do
    # Group by side
    sides =
      participants
      |> Map.values()
      |> Enum.group_by(& &1.side)

    by_side =
      sides
      |> Enum.map(fn {side, side_participants} ->
        {side,
         %{
           kills: Enum.sum(Enum.map(side_participants, & &1.kills)),
           losses: Enum.sum(Enum.map(side_participants, & &1.losses)),
           isk_destroyed: calculate_side_isk_destroyed(side, killmails),
           isk_lost: calculate_side_isk_lost(side, killmails),
           efficiency: calculate_side_efficiency(side, killmails),
           k_d_ratio: calculate_side_kd_ratio(side_participants)
         }}
      end)
      |> Map.new()

    by_ship_class = analyze_ship_class_performance(killmails, participants)
    top_performers = identify_top_performers(participants)

    {:ok,
     %{
       by_side: by_side,
       by_ship_class: by_ship_class,
       top_performers: top_performers
     }}
  end

  @doc """
  Calculate total ISK destroyed across all killmails.
  """
  def calculate_total_isk_destroyed(killmails) do
    Enum.sum(Enum.map(killmails, &(&1.total_value || 0)))
  end

  @doc """
  Calculate ISK value destroyed by a specific side.
  """
  def calculate_side_isk_destroyed(side, killmails) do
    side_corps = get_side_corporations_from_data(side)

    killmails
    |> Enum.filter(fn km ->
      # Check if any attacker is from this side
      Enum.any?(km.attackers || [], fn attacker ->
        corp_id = attacker["corporation_id"]
        corp_id && corp_id in side_corps
      end)
    end)
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
  end

  @doc """
  Calculate ISK value lost by a specific side.
  """
  def calculate_side_isk_lost(side, killmails) do
    side_corps = get_side_corporations_from_data(side)

    killmails
    |> Enum.filter(fn km ->
      # Check if victim is from this side
      km.victim_corporation_id in side_corps
    end)
    |> Enum.map(&(&1.total_value || 0))
    |> Enum.sum()
  end

  @doc """
  Calculate ISK efficiency for a side: destroyed / (destroyed + lost) * 100.
  """
  def calculate_side_efficiency(side, killmails) do
    destroyed = calculate_side_isk_destroyed(side, killmails)
    lost = calculate_side_isk_lost(side, killmails)

    total = destroyed + lost

    if total > 0 do
      Float.round(destroyed / total * 100, 2)
    else
      # No activity = neutral efficiency
      50.0
    end
  end

  @doc """
  Calculate kill/death ratio for participants on a side.
  """
  def calculate_side_kd_ratio(participants) do
    total_kills = Enum.sum(Enum.map(participants, & &1.kills))
    total_deaths = Enum.sum(Enum.map(participants, & &1.losses))

    # Avoid division by zero
    if total_deaths > 0 do
      Float.round(total_kills / total_deaths, 2)
    else
      # If no deaths, return a high K/D ratio based on kills
      if total_kills > 0 do
        Float.round(total_kills * 1.0, 2)
      else
        0.0
      end
    end
  end

  @doc """
  Analyze performance metrics by ship class.
  """
  def analyze_ship_class_performance(killmails, participants) do
    # Extract ship usage data from participants
    ship_usage = extract_ship_usage_from_participants(participants)

    # Analyze kills made by each ship class
    kills_by_class = analyze_kills_by_ship_class(killmails)

    # Analyze losses by ship class
    losses_by_class = analyze_losses_by_ship_class(killmails)

    # Combine data for comprehensive analysis
    ship_classes =
      [ship_usage, kills_by_class, losses_by_class]
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()

    ship_classes
    |> Enum.map(fn ship_class ->
      ships_used = Map.get(ship_usage, ship_class, 0)
      kills_made = Map.get(kills_by_class, ship_class, 0)
      losses_taken = Map.get(losses_by_class, ship_class, 0)

      kill_efficiency = if ships_used > 0, do: Float.round(kills_made / ships_used, 2), else: 0.0

      survival_rate =
        if ships_used > 0,
          do: Float.round((ships_used - losses_taken) / ships_used * 100, 2),
          else: 100.0

      kd_ratio =
        if losses_taken > 0, do: Float.round(kills_made / losses_taken, 2), else: kills_made * 1.0

      {ship_class,
       %{
         ships_used: ships_used,
         kills_made: kills_made,
         losses_taken: losses_taken,
         kill_efficiency: kill_efficiency,
         survival_rate: survival_rate,
         kd_ratio: kd_ratio,
         tactical_role: determine_tactical_role(ship_class)
       }}
    end)
    |> Map.new()
  end

  @doc """
  Identify top performers by kill count.
  """
  def identify_top_performers(participants) do
    participants
    |> Map.values()
    |> Enum.filter(&(&1.kills > 0))
    |> Enum.sort_by(& &1.kills, :desc)
    |> Enum.take(10)
    |> Enum.map(fn participant ->
      %{
        character_id: participant.character_id,
        corporation_id: participant.corporation_id,
        kills: participant.kills,
        losses: participant.losses,
        damage_dealt: participant.damage_dealt,
        ships_used: MapSet.to_list(participant.ships_used),
        side: participant.side
      }
    end)
  end

  @doc """
  Calculate battle intensity curve over time.
  """
  def calculate_intensity_curve(killmails) do
    if Enum.empty?(killmails) do
      {:ok, %{timeline: [], peak_intensity: 0, average_intensity: 0}}
    else
      # Sort killmails by time
      sorted_kills = Enum.sort_by(killmails, & &1.killmail_time)

      # Create 1-minute time buckets from first to last kill
      start_time = List.first(sorted_kills).killmail_time
      end_time = List.last(sorted_kills).killmail_time
      time_buckets = create_time_buckets(start_time, end_time, 60)

      # Calculate metrics for each time bucket
      timeline_data =
        time_buckets
        |> Enum.map(fn bucket_start ->
          bucket_end = DateTime.add(bucket_start, 60, :second)

          # Find kills in this bucket
          bucket_kills =
            Enum.filter(sorted_kills, fn km ->
              DateTime.compare(km.killmail_time, bucket_start) != :lt and
                DateTime.compare(km.killmail_time, bucket_end) == :lt
            end)

          # Calculate bucket metrics
          kills_count = length(bucket_kills)
          total_isk = Enum.sum(Enum.map(bucket_kills, &calculate_killmail_isk_value/1))

          active_participants =
            bucket_kills
            |> Enum.flat_map(&extract_participants_from_killmail/1)
            |> Enum.uniq()
            |> length()

          # Determine intensity level and score
          intensity_level =
            determine_intensity_level(kills_count, total_isk / 60, active_participants)

          intensity_score =
            calculate_intensity_score(kills_count, total_isk / 60, active_participants)

          %{
            timestamp: bucket_start,
            kills_per_minute: kills_count,
            isk_per_minute: Float.round(total_isk / 60, 0),
            active_participants: active_participants,
            intensity_level: intensity_level,
            intensity_score: intensity_score
          }
        end)

      # Calculate overall metrics
      peak_intensity =
        timeline_data
        |> Enum.map(& &1.intensity_score)
        |> Enum.max(fn -> 0 end)

      average_intensity =
        if Enum.empty?(timeline_data) do
          0.0
        else
          timeline_data
          |> Enum.map(& &1.intensity_score)
          |> Enum.sum()
          |> Kernel./(length(timeline_data))
          |> Float.round(1)
        end

      {:ok,
       %{
         timeline: timeline_data,
         peak_intensity: peak_intensity,
         average_intensity: average_intensity
       }}
    end
  end

  @doc """
  Calculate kill rate (kills per minute).
  """
  def calculate_kill_rate(killmails) do
    if length(killmails) < 2 do
      0.0
    else
      sorted_kills = Enum.sort_by(killmails, & &1.killmail_time)

      duration_seconds =
        DateTime.diff(
          List.last(sorted_kills).killmail_time,
          List.first(sorted_kills).killmail_time
        )

      duration_minutes = max(duration_seconds / 60, 1)

      Float.round(length(killmails) / duration_minutes, 2)
    end
  end

  @doc """
  Calculate average pilot efficiency for participants.
  """
  def calculate_average_efficiency(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      efficiencies =
        participants
        |> Map.values()
        |> Enum.map(fn participant ->
          total_activity = participant.kills + participant.losses

          if total_activity > 0 do
            participant.kills / total_activity * 100
          else
            0.0
          end
        end)

      if Enum.empty?(efficiencies) do
        0.0
      else
        Float.round(Enum.sum(efficiencies) / length(efficiencies), 2)
      end
    end
  end

  @doc """
  Determine engagement intensity level based on kill rate and ISK values.
  """
  def calculate_engagement_intensity(killmails, active_participants) do
    if Enum.empty?(killmails) do
      :minimal
    else
      kill_rate = calculate_kill_rate(killmails)
      total_isk = calculate_total_isk_destroyed(killmails)

      isk_per_minute =
        if length(killmails) > 1 do
          sorted_kills = Enum.sort_by(killmails, & &1.killmail_time)

          duration_minutes =
            max(
              DateTime.diff(
                List.last(sorted_kills).killmail_time,
                List.first(sorted_kills).killmail_time
              ) / 60,
              1
            )

          total_isk / duration_minutes
        else
          total_isk
        end

      determine_intensity_level(kill_rate, isk_per_minute, active_participants)
    end
  end

  # Private helper functions

  defp get_side_corporations_from_data(side_data) do
    cond do
      # If side has a corporations field with a map
      is_map(side_data) && Map.has_key?(side_data, :corporations) ->
        Map.keys(side_data.corporations)

      # If side has a corporations field as atom key
      is_map(side_data) && Map.has_key?(side_data, "corporations") ->
        Map.keys(side_data["corporations"])

      # If side data is directly a map of corporations
      is_map(side_data) ->
        Map.keys(side_data)

      # If side data is a list of corporation IDs
      is_list(side_data) ->
        side_data

      # Default to empty list
      true ->
        []
    end
  end

  defp extract_ship_usage_from_participants(participants) do
    Map.values(participants)
    |> Enum.flat_map(fn participant ->
      participant.ships_used |> MapSet.to_list() |> Enum.map(&classify_ship/1)
    end)
    |> Enum.frequencies()
  end

  defp analyze_kills_by_ship_class(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      (km.attackers || [])
      |> Enum.filter(&(&1["final_blow"] == true))
      |> Enum.map(&classify_ship(&1["ship_type_id"]))
    end)
    |> Enum.frequencies()
  end

  defp analyze_losses_by_ship_class(killmails) do
    killmails
    |> Enum.map(&classify_ship(&1.victim_ship_type_id))
    |> Enum.frequencies()
  end

  defp determine_tactical_role(ship_class) do
    case ship_class do
      :frigate -> "Fast tackle, scouting, interception"
      :destroyer -> "Anti-frigate, small gang combat"
      :cruiser -> "Versatile mainline, logistics support"
      :battlecruiser -> "Heavy damage, mid-range combat"
      :battleship -> "Main DPS, anchor, tanking"
      :strategic_cruiser -> "Specialized roles, adaptable"
      :logistics -> "Fleet support, remote repair"
      :recon -> "EWAR, intelligence, force multiplication"
      :heavy_assault_cruiser -> "Specialized assault, high DPS"
      :capital -> "Strategic assets, major engagements"
      _ -> "General combat role"
    end
  end

  defp create_time_buckets(start_time, end_time, interval_seconds) do
    duration_seconds = DateTime.diff(end_time, start_time)
    bucket_count = max(div(duration_seconds, interval_seconds), 1)

    0..(bucket_count - 1)
    |> Enum.map(fn i ->
      DateTime.add(start_time, i * interval_seconds, :second)
    end)
  end

  defp calculate_killmail_isk_value(killmail) do
    cond do
      # Check zKillboard value first
      killmail.total_value && killmail.total_value > 0 ->
        killmail.total_value

      # Check raw_data zkb field
      get_in(killmail.raw_data, ["zkb", "totalValue"]) ->
        get_in(killmail.raw_data, ["zkb", "totalValue"])

      # Estimate based on ship type
      true ->
        estimate_killmail_value_by_ship(killmail.victim_ship_type_id)
    end
  end

  defp estimate_killmail_value_by_ship(ship_type_id) do
    # Rough ISK estimates by ship type ID ranges
    cond do
      # Frigates: 1-10M ISK
      ship_type_id in 580..599 -> 5_000_000
      # Destroyers: 5-20M ISK
      ship_type_id in 16_200..16_300 -> 12_000_000
      # Cruisers: 10-100M ISK
      ship_type_id in 620..650 -> 50_000_000
      # Battlecruisers: 50-200M ISK
      ship_type_id in 16_220..16_240 -> 125_000_000
      # Battleships: 100-500M ISK
      ship_type_id in 635..670 -> 300_000_000
      # Strategic Cruisers: 300M-1B ISK
      ship_type_id in 29_980..29_995 -> 650_000_000
      # Logistics: 100-300M ISK
      ship_type_id in [11_987, 11_989, 12_015, 12_019] -> 200_000_000
      # Capital ships: 1-10B ISK
      ship_type_id in 19_720..19_730 -> 5_000_000_000
      # Default fallback
      true -> 25_000_000
    end
  end

  defp extract_participants_from_killmail(killmail) do
    participants = [killmail.victim_character_id]

    attacker_participants =
      killmail.attackers ||
        []
        |> Enum.map(& &1["character_id"])
        |> Enum.filter(&(&1 && &1 != 0))

    participants ++ attacker_participants
  end

  defp determine_intensity_level(kills_per_minute, isk_per_minute, active_participants) do
    # Weighted scoring system
    kill_score =
      cond do
        kills_per_minute >= 5 -> 4
        kills_per_minute >= 2 -> 3
        kills_per_minute >= 1 -> 2
        kills_per_minute > 0 -> 1
        true -> 0
      end

    isk_score =
      cond do
        # 500M+ ISK/min
        isk_per_minute >= 500_000_000 -> 4
        # 100M+ ISK/min
        isk_per_minute >= 100_000_000 -> 3
        # 20M+ ISK/min
        isk_per_minute >= 20_000_000 -> 2
        isk_per_minute > 0 -> 1
        true -> 0
      end

    participant_score =
      cond do
        active_participants >= 50 -> 4
        active_participants >= 20 -> 3
        active_participants >= 10 -> 2
        active_participants >= 5 -> 1
        true -> 0
      end

    total_score = kill_score + isk_score + participant_score

    case total_score do
      score when score >= 10 -> :extreme
      score when score >= 7 -> :high
      score when score >= 4 -> :moderate
      score when score >= 2 -> :low
      _ -> :minimal
    end
  end

  defp calculate_intensity_score(kills_per_minute, isk_per_minute, active_participants) do
    # Normalized 0-100 intensity score
    kill_component = min(kills_per_minute * 10, 40)
    isk_component = min(isk_per_minute / 10_000_000, 40)
    participant_component = min(active_participants, 20)

    Float.round(kill_component + isk_component + participant_component, 1)
  end

  defp classify_ship(ship_type_id) do
    # Classify ship based on type ID ranges (simplified EVE ship classification)
    cond do
      # Frigates
      ship_type_id in [582, 583, 584, 585, 586, 587, 588, 589] -> :frigate
      # Destroyers
      ship_type_id in [16_236, 16_238, 16_240, 16_242] -> :destroyer
      # Cruisers
      ship_type_id in [620, 621, 622, 623, 624, 625, 626, 627] -> :cruiser
      # Battlecruisers
      ship_type_id in [16_227, 16_229, 16_231, 16_233] -> :battlecruiser
      # Battleships
      ship_type_id in [638, 639, 640, 641, 642, 643, 644, 645] -> :battleship
      # Strategic Cruisers (T3C)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> :strategic_cruiser
      # Logistics Cruisers
      ship_type_id in [11_987, 11_989, 12_015, 12_019] -> :logistics
      # Recon Ships
      ship_type_id in [11_957, 11_958, 11_965, 11_969] -> :recon
      # Heavy Assault Cruisers
      ship_type_id in [12_003, 12_005, 12_009, 12_011] -> :heavy_assault_cruiser
      # Capital Ships
      ship_type_id in [19_720, 19_722, 19_724, 19_726] -> :capital
      # Default
      true -> :unknown
    end
  end
end
