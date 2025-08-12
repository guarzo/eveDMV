defmodule EveDmv.Contexts.Intelligence.Core.GangEffectivenessEngine do
  @moduledoc """
  Analyzes gang participation and coordination effectiveness.
  Part of the multi-dimensional threat assessment system.
  """

  alias EveDmv.Contexts.Intelligence.Core.BehavioralPatternAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Platform.Database.KillmailRepository

  require Logger

  @doc """
  Analyze gang effectiveness for a character.
  """
  def analyze(character_id) do
    with {:ok, killmails} <- get_recent_killmails(character_id),
         {:ok, behavior} <- BehavioralPatternAnalyzer.get_gang_preferences(character_id) do
      analysis = %{
        character_id: character_id,
        effectiveness_score: calculate_effectiveness_score(killmails, character_id),
        coordination_rating: analyze_coordination(killmails, character_id),
        preferred_gang_size: behavior.preferred_size,
        gang_role: identify_gang_role(killmails, character_id),
        fleet_participation: calculate_fleet_participation(killmails, character_id),
        leadership_indicators: detect_leadership_patterns(killmails, character_id),
        analyzed_at: DateTime.utc_now()
      }

      {:ok, analysis}
    end
  end

  defp get_recent_killmails(character_id) do
    start_date = DateTime.utc_now() |> DateTimeUtils.add(-60 * 24 * 60 * 60, :second)
    KillmailRepository.get_by_character(character_id, start_date: start_date, limit: 1000)
  end

  defp calculate_effectiveness_score(killmails, character_id) do
    gang_kills =
      killmails
      |> Enum.filter(fn km ->
        km.victim.character_id != character_id and
          length(km.attackers) > 1
      end)

    if Enum.empty?(gang_kills) do
      0.0
    else
      # Analyze success rate in gang activities
      success_metrics =
        gang_kills
        |> Enum.map(fn km ->
          character_damage = get_character_damage_share(km, character_id)
          gang_size = length(km.attackers)

          # Higher score for higher damage contribution
          contribution_score = character_damage / 100

          # Adjust for gang size (smaller gangs = higher skill requirement)
          size_multiplier =
            cond do
              gang_size <= 5 -> 1.5
              gang_size <= 10 -> 1.2
              gang_size <= 25 -> 1.0
              true -> 0.8
            end

          contribution_score * size_multiplier
        end)

      avg_effectiveness = Enum.sum(success_metrics) / length(success_metrics)
      Float.round(avg_effectiveness, 3)
    end
  end

  defp get_character_damage_share(killmail, character_id) do
    case Enum.find(killmail.attackers, fn att -> att.character_id == character_id end) do
      nil -> 0
      attacker -> attacker.damage_done_percent || 0
    end
  end

  defp analyze_coordination(killmails, _character_id) do
    gang_activities =
      killmails
      |> Enum.filter(fn km -> length(km.attackers) > 1 end)

    if length(gang_activities) < 5 do
      0.0
    else
      # Look for patterns indicating good coordination
      coordination_scores =
        gang_activities
        |> Enum.map(fn km ->
          score = 0

          # Quick kills indicate good coordination
          # (This would need actual kill duration data)
          score = score + 0.3

          # Consistent gang composition suggests regular team
          score = score + analyze_gang_consistency(km, gang_activities) * 0.4

          # Role diversity in gang
          score = score + analyze_role_diversity(km) * 0.3

          score
        end)

      avg_coordination = Enum.sum(coordination_scores) / length(coordination_scores)
      # Scale to 0-5
      Float.round(avg_coordination * 5, 1)
    end
  end

  defp analyze_gang_consistency(current_km, all_kms) do
    # Check if similar pilots appear together
    current_pilots = current_km.attackers |> Enum.map(& &1.character_id) |> MapSet.new()

    consistency_scores =
      all_kms
      |> Enum.map(fn km ->
        other_pilots = km.attackers |> Enum.map(& &1.character_id) |> MapSet.new()

        intersection = MapSet.intersection(current_pilots, other_pilots) |> MapSet.size()
        union = MapSet.union(current_pilots, other_pilots) |> MapSet.size()

        if union > 0, do: intersection / union, else: 0
      end)

    Enum.sum(consistency_scores) / max(length(consistency_scores), 1)
  end

  defp analyze_role_diversity(killmail) do
    ship_classes =
      killmail.attackers
      |> Enum.map(fn att -> classify_ship_role(att.ship_type_id) end)
      |> Enum.uniq()
      |> length()

    # More diverse roles = better coordination
    min(ship_classes / 5, 1.0)
  end

  defp classify_ship_role(ship_type_id) do
    # Use proper ship role detection from static data
    alias EveDmv.StaticData.ShipRoles

    cond do
      ShipRoles.logistics_ship?(ship_type_id) -> :logistics
      ShipRoles.ewar_ship?(ship_type_id) -> :support
      ShipRoles.command_ship?(ship_type_id) -> :support
      # Interceptors and dictors are tackle ships
      ship_type_id in [11_172, 11_174, 11_176, 11_182, 11_184, 11_186, 11_188, 11_192] -> :tackle
      # Interdictors
      ship_type_id in [22_456, 22_452, 22_448, 22_460] -> :tackle
      # Default to DPS for other combat ships
      true -> :dps
    end
  end

  defp identify_gang_role(killmails, character_id) do
    # Analyze typical role in gangs
    gang_participations =
      killmails
      |> Enum.filter(fn km -> length(km.attackers) > 1 end)
      |> Enum.map(fn km ->
        case Enum.find(km.attackers, fn att -> att.character_id == character_id end) do
          nil ->
            nil

          attacker ->
            %{
              ship_type: attacker.ship_type_id,
              damage_share: attacker.damage_done_percent || 0,
              final_blow: attacker.final_blow || false
            }
        end
      end)
      |> Enum.filter(& &1)

    if Enum.empty?(gang_participations) do
      :unknown
    else
      # Determine most common role
      avg_damage =
        gang_participations
        |> Enum.map(& &1.damage_share)
        |> Enum.sum()
        |> Kernel./(length(gang_participations))

      final_blow_rate =
        gang_participations
        |> Enum.count(& &1.final_blow)
        |> Kernel./(length(gang_participations))

      cond do
        avg_damage > 30 -> :primary_dps
        final_blow_rate > 0.3 -> :tackle
        avg_damage < 10 -> :support
        true -> :flex
      end
    end
  end

  defp calculate_fleet_participation(killmails, character_id) do
    total_activities = length(killmails)

    fleet_activities =
      killmails
      |> Enum.count(fn km ->
        length(km.attackers) > 25 or
          (km.victim.character_id == character_id and length(km.attackers) > 25)
      end)

    if total_activities > 0 do
      Float.round(fleet_activities / total_activities, 2)
    else
      0.0
    end
  end

  defp detect_leadership_patterns(killmails, character_id) do
    # Look for patterns suggesting FC/leadership role
    gang_kills =
      killmails
      |> Enum.filter(fn km ->
        km.victim.character_id != character_id and
          length(km.attackers) > 5
      end)

    indicators = %{
      uses_command_ships: detect_command_ship_usage(gang_kills, character_id),
      consistent_early_aggression: detect_early_aggression(gang_kills, character_id),
      high_fleet_participation: calculate_fleet_participation(killmails, character_id) > 0.5,
      # Would need more data
      target_calling_patterns: false
    }

    leadership_score =
      indicators
      |> Map.values()
      |> Enum.count(& &1)
      |> Kernel./(4)

    %{
      score: Float.round(leadership_score, 2),
      indicators: indicators
    }
  end

  defp detect_command_ship_usage(killmails, character_id) do
    command_ship_ids = [
      # Command Ships
      22_442,
      22_444,
      22_446,
      22_448,
      # Command Destroyers
      37_480,
      37_481,
      37_482,
      37_483
    ]

    Enum.any?(killmails, fn km ->
      Enum.any?(km.attackers, fn att ->
        att.character_id == character_id and
          att.ship_type_id in command_ship_ids
      end)
    end)
  end

  defp detect_early_aggression(gang_kills, character_id) do
    # Check if character is often first on killmail
    first_aggressor_count =
      gang_kills
      |> Enum.count(fn km ->
        case List.first(km.attackers) do
          nil -> false
          first -> first.character_id == character_id
        end
      end)

    first_aggressor_count > length(gang_kills) * 0.2
  end
end
