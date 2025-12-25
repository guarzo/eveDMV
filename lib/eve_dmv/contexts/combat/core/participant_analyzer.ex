defmodule EveDmv.Contexts.Combat.Core.ParticipantAnalyzer do
  @moduledoc """
  Unified participant analysis module that extracts and analyzes combat participants.

  Consolidates the best features from multiple implementations:
  - Basic participant extraction
  - Advanced role classification
  - Experience analysis
  - Affiliation tracking
  - Activity patterns
  """

  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.ActivityTracker
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.AffiliationAnalyzer
  alias EveDmv.Contexts.Combat.Core.ParticipantAnalyzer.RoleClassifier
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.External.Eve.MarketDataService

  require Logger

  @doc """
  Analyze all participants in a set of killmails.

  Returns comprehensive participant data including:
  - Individual participant profiles
  - Role classifications
  - Affiliation groupings
  - Performance metrics
  """
  def analyze_participants(killmails) when is_list(killmails) do
    participants =
      killmails
      |> extract_all_participants()
      |> deduplicate_participants()
      |> enrich_participants()
      |> classify_roles()
      |> analyze_affiliations()
      |> calculate_metrics()

    {:ok,
     %{
       all_participants: participants,
       by_role: group_by_role(participants),
       by_affiliation: group_by_affiliation(participants),
       by_corporation: group_by_corporation(participants),
       by_alliance: group_by_alliance(participants),
       metrics: calculate_aggregate_metrics(participants),
       mvp_candidates: identify_mvp_candidates(participants),
       activity_timeline: build_activity_timeline(participants, killmails)
     }}
  end

  @doc """
  Get performance metrics for a specific participant in a battle.
  """
  def get_participant_performance(battle_killmails, character_id) do
    with {:ok, analysis} <- analyze_participants(battle_killmails),
         participant <- find_participant(analysis.all_participants, character_id) do
      {:ok,
       %{
         character_id: character_id,
         kills: count_kills(battle_killmails, character_id),
         deaths: count_deaths(battle_killmails, character_id),
         damage_dealt: calculate_damage_dealt(battle_killmails, character_id),
         final_blows: count_final_blows(battle_killmails, character_id),
         solo_kills: count_solo_kills(battle_killmails, character_id),
         isk_destroyed: calculate_isk_destroyed(battle_killmails, character_id),
         isk_lost: calculate_isk_lost(battle_killmails, character_id),
         ships_used: get_ships_used(battle_killmails, character_id),
         primary_role: participant[:role],
         combat_score: participant[:combat_score],
         efficiency_rating: participant[:efficiency_rating]
       }}
    else
      _ -> {:error, :participant_not_found}
    end
  end

  @doc """
  Get role classifications for all participants in a battle.
  """
  def get_participant_roles(battle_killmails) do
    with {:ok, analysis} <- analyze_participants(battle_killmails) do
      {:ok, analysis.by_role}
    end
  end

  # Private Functions

  defp extract_all_participants(killmails) do
    Enum.flat_map(killmails, &extract_from_killmail/1)
  end

  defp extract_from_killmail(killmail) do
    victim = extract_victim(killmail)
    attackers = extract_attackers(killmail)

    [victim | attackers]
    |> Enum.map(&add_killmail_reference(&1, killmail))
  end

  defp extract_victim(killmail) do
    victim = killmail.victim || %{}

    %{
      character_id: victim["character_id"],
      character_name: victim["character_name"],
      corporation_id: victim["corporation_id"],
      corporation_name: victim["corporation_name"],
      alliance_id: victim["alliance_id"],
      alliance_name: victim["alliance_name"],
      ship_type_id: victim["ship_type_id"],
      ship_name: victim["ship_name"],
      participant_type: :victim,
      damage_taken: victim["damage_taken"] || 0,
      position: extract_position(victim),
      items: victim["items"] || []
    }
  end

  defp extract_attackers(killmail) do
    (killmail.attackers || [])
    |> Enum.map(fn attacker ->
      %{
        character_id: attacker["character_id"],
        character_name: attacker["character_name"],
        corporation_id: attacker["corporation_id"],
        corporation_name: attacker["corporation_name"],
        alliance_id: attacker["alliance_id"],
        alliance_name: attacker["alliance_name"],
        ship_type_id: attacker["ship_type_id"],
        ship_name: attacker["ship_type_name"],
        participant_type: :attacker,
        damage_done: attacker["damage_done"] || 0,
        final_blow: attacker["final_blow"] || false,
        security_status: attacker["security_status"],
        weapon_type_id: attacker["weapon_type_id"]
      }
    end)
    |> Enum.reject(&is_nil(&1.character_id))
  end

  defp add_killmail_reference(participant, killmail) do
    participant
    |> Map.put(:killmail_id, killmail.killmail_id)
    |> Map.put(:killmail_time, killmail.killmail_time)
    |> Map.put(:solar_system_id, killmail.solar_system_id)
  end

  defp deduplicate_participants(participants) do
    participants
    |> Enum.group_by(& &1.character_id)
    |> Enum.map(fn {character_id, instances} ->
      merge_participant_instances(character_id, instances)
    end)
    |> Enum.reject(&is_nil(&1.character_id))
  end

  defp merge_participant_instances(_character_id, instances) do
    base = List.first(instances)

    instances
    |> Enum.reduce(base, fn instance, acc ->
      acc
      |> Map.update(:killmail_ids, [instance.killmail_id], &[instance.killmail_id | &1])
      |> Map.update(:killmail_times, [instance.killmail_time], &[instance.killmail_time | &1])
      |> Map.update(
        :ships_used,
        [instance.ship_type_id],
        &Enum.uniq([instance.ship_type_id | &1])
      )
      |> Map.update(
        :total_damage_done,
        instance[:damage_done] || 0,
        &(&1 + (instance[:damage_done] || 0))
      )
      |> Map.update(
        :total_damage_taken,
        instance[:damage_taken] || 0,
        &(&1 + (instance[:damage_taken] || 0))
      )
      |> Map.update(:final_blows, 0, &if(instance[:final_blow], do: &1 + 1, else: &1))
      |> Map.update(:appearances, 1, &(&1 + 1))
    end)
  end

  defp enrich_participants(participants) do
    Enum.map(participants, &enrich_participant/1)
  end

  defp enrich_participant(participant) do
    participant
    |> add_kill_death_counts()
    |> add_activity_metrics()
    |> add_threat_assessment()
  end

  defp classify_roles(participants) do
    Enum.map(participants, &RoleClassifier.classify_role/1)
  end

  defp analyze_affiliations(participants) do
    AffiliationAnalyzer.analyze_affiliations(participants)
  end

  defp calculate_metrics(participants) do
    Enum.map(participants, &calculate_participant_metrics/1)
  end

  defp calculate_participant_metrics(participant) do
    participant
    |> Map.put(:combat_score, calculate_combat_score(participant))
    |> Map.put(:efficiency_rating, calculate_efficiency_rating(participant))
    |> Map.put(:threat_level, assess_threat_level(participant))
    |> Map.put(:activity_score, calculate_activity_score(participant))
  end

  defp group_by_role(participants) do
    Enum.group_by(participants, &(&1[:role] || :unknown))
  end

  defp group_by_affiliation(participants) do
    Enum.group_by(participants, &(&1[:affiliation] || :neutral))
  end

  defp group_by_corporation(participants) do
    Enum.group_by(participants, & &1.corporation_id)
    |> Enum.reject(fn {corp_id, _} -> is_nil(corp_id) end)
    |> Map.new()
  end

  defp group_by_alliance(participants) do
    Enum.group_by(participants, & &1.alliance_id)
    |> Enum.reject(fn {alliance_id, _} -> is_nil(alliance_id) end)
    |> Map.new()
  end

  defp calculate_aggregate_metrics(participants) do
    %{
      total_participants: length(participants),
      unique_corporations:
        participants |> Enum.map(& &1.corporation_id) |> Enum.uniq() |> length(),
      unique_alliances:
        participants
        |> Enum.map(& &1.alliance_id)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
        |> length(),
      average_combat_score: calculate_average(participants, :combat_score),
      total_damage_dealt: Enum.reduce(participants, 0, &(&1[:total_damage_done] + &2)),
      total_damage_taken: Enum.reduce(participants, 0, &(&1[:total_damage_taken] + &2))
    }
  end

  defp identify_mvp_candidates(participants) do
    participants
    |> Enum.sort_by(& &1[:combat_score], :desc)
    |> Enum.take(5)
  end

  defp build_activity_timeline(participants, killmails) do
    ActivityTracker.build_timeline(participants, killmails)
  end

  defp extract_position(entity_data) do
    case entity_data["position"] do
      %{"x" => x, "y" => y, "z" => z} -> %{x: x, y: y, z: z}
      _ -> nil
    end
  end

  defp add_kill_death_counts(participant) do
    kills =
      Enum.count(participant[:killmail_ids] || [], fn _ ->
        participant.participant_type == :attacker
      end)

    deaths = if participant.participant_type == :victim, do: 1, else: 0

    participant
    |> Map.put(:kills, kills)
    |> Map.put(:deaths, deaths)
  end

  defp add_activity_metrics(participant) do
    participant
    |> Map.put(:engagement_rate, calculate_engagement_rate(participant))
    |> Map.put(:survival_time, calculate_survival_time(participant))
  end

  defp add_threat_assessment(participant) do
    threat_level =
      case participant[:combat_score] do
        score when score >= 100 -> :extreme
        score when score >= 75 -> :high
        score when score >= 50 -> :moderate
        score when score >= 25 -> :low
        _ -> :minimal
      end

    Map.put(participant, :threat_assessment, threat_level)
  end

  defp calculate_combat_score(participant) do
    kills = participant[:kills] || 0
    deaths = participant[:deaths] || 0
    final_blows = participant[:final_blows] || 0
    damage_ratio = calculate_damage_ratio(participant)

    # Weighted score calculation
    (kills * 10 + final_blows * 5 + damage_ratio * 20 - deaths * 15)
    |> max(0)
  end

  defp calculate_efficiency_rating(participant) do
    damage_done = participant[:total_damage_done] || 0
    damage_taken = participant[:total_damage_taken] || 1

    ratio = damage_done / damage_taken

    # Convert to percentage
    min(ratio * 100, 100)
  end

  defp assess_threat_level(participant) do
    combat_score = participant[:combat_score] || 0
    ship_value = estimate_ship_value(participant[:ships_used] || [])

    # Combined threat assessment
    (combat_score * 0.7 + ship_value * 0.3) / 100
  end

  defp calculate_activity_score(participant) do
    appearances = participant[:appearances] || 1
    time_span = calculate_time_span(participant[:killmail_times] || [])

    if time_span > 0 do
      # Activities per hour
      appearances / time_span * 60
    else
      0
    end
  end

  defp calculate_damage_ratio(participant) do
    damage_done = participant[:total_damage_done] || 0
    damage_taken = participant[:total_damage_taken] || 1

    damage_done / damage_taken
  end

  defp calculate_engagement_rate(participant) do
    appearances = participant[:appearances] || 0
    time_span = calculate_time_span(participant[:killmail_times] || [])

    if time_span > 0 do
      appearances / time_span
    else
      0
    end
  end

  defp calculate_survival_time(participant) do
    if participant[:deaths] > 0 do
      times = participant[:killmail_times] || []

      if Enum.any?(times) do
        first = List.first(times)
        last = List.last(times)
        DateTimeUtils.diff(last, first, :minute)
      else
        0
      end
    else
      :survived
    end
  end

  defp calculate_time_span([]), do: 0
  defp calculate_time_span([_]), do: 0

  defp calculate_time_span(times) do
    sorted = Enum.sort(times, DateTime)
    first = List.first(sorted)
    last = List.last(sorted)
    DateTimeUtils.diff(last, first, :minute)
  end

  defp estimate_ship_value(ship_type_ids) do
    # Calculate ship value using market data service
    case get_ship_values(ship_type_ids) do
      {:ok, values} ->
        # Return average relative value score (0-100)
        total_value = Enum.sum(Map.values(values))
        ship_count = length(ship_type_ids)

        if ship_type_ids == [] do
          0
        else
          avg_value = total_value / ship_count
          # Convert to relative threat value score (0-100)
          # Per million ISK
          min(100, avg_value / 1_000_000)
        end

      {:error, _} ->
        # Fallback to classification-based estimation
        ship_type_ids
        |> Enum.map(&estimate_value_from_classification/1)
        |> Enum.sum()
        |> Kernel.div(max(1, length(ship_type_ids)))
    end
  end

  defp get_ship_values(ship_type_ids) do
    # Get market values for multiple ships efficiently
    ship_type_ids
    |> Enum.uniq()
    |> Enum.reduce({:ok, %{}}, fn type_id, acc ->
      case acc do
        {:ok, values} ->
          case MarketDataService.get_ship_price(type_id) do
            {:ok, price_data} ->
              {:ok, Map.put(values, type_id, price_data.sell || 0.0)}

            {:error, _} ->
              # Use fallback estimation
              {:ok, Map.put(values, type_id, estimate_value_from_classification(type_id))}
          end

        error ->
          error
      end
    end)
  end

  defp estimate_value_from_classification(ship_type_id) do
    # Fallback value estimation based on ship classification
    case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id) do
      :frigate -> 2_000_000.0
      :destroyer -> 8_000_000.0
      :cruiser -> 50_000_000.0
      :battlecruiser -> 120_000_000.0
      :battleship -> 300_000_000.0
      :capital -> 2_000_000_000.0
      :supercapital -> 25_000_000_000.0
      _ -> 25_000_000.0
    end
  end

  defp calculate_average(list, key) do
    sum = Enum.reduce(list, 0, &((&1[key] || 0) + &2))
    count = length(list)

    if count > 0, do: sum / count, else: 0
  end

  defp find_participant(participants, character_id) do
    Enum.find(participants, &(&1.character_id == character_id))
  end

  defp count_kills(killmails, character_id) do
    Enum.count(killmails, fn km ->
      Enum.any?(km.attackers || [], &(&1["character_id"] == character_id))
    end)
  end

  defp count_deaths(killmails, character_id) do
    Enum.count(killmails, fn km ->
      get_in(km.victim, ["character_id"]) == character_id
    end)
  end

  defp calculate_damage_dealt(killmails, character_id) do
    Enum.reduce(killmails, 0, fn km, acc ->
      attacker = Enum.find(km.attackers || [], &(&1["character_id"] == character_id))
      acc + (attacker["damage_done"] || 0)
    end)
  end

  defp count_final_blows(killmails, character_id) do
    Enum.count(killmails, fn km ->
      Enum.any?(km.attackers || [], fn attacker ->
        attacker["character_id"] == character_id && attacker["final_blow"]
      end)
    end)
  end

  defp count_solo_kills(killmails, character_id) do
    Enum.count(killmails, fn km ->
      attackers = km.attackers || []
      length(attackers) == 1 && List.first(attackers)["character_id"] == character_id
    end)
  end

  defp calculate_isk_destroyed(killmails, character_id) do
    Enum.reduce(killmails, 0.0, fn km, acc ->
      if Enum.any?(km.attackers || [], &(&1["character_id"] == character_id)) do
        acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
      else
        acc
      end
    end)
  end

  defp calculate_isk_lost(killmails, character_id) do
    Enum.reduce(killmails, 0.0, fn km, acc ->
      if get_in(km.victim, ["character_id"]) == character_id do
        acc + (get_in(km.zkb, ["totalValue"]) || 0.0)
      else
        acc
      end
    end)
  end

  defp get_ships_used(killmails, character_id) do
    killmails
    |> Enum.flat_map(fn km ->
      victim_ship =
        if get_in(km.victim, ["character_id"]) == character_id do
          [
            %{
              ship_type_id: km.victim["ship_type_id"],
              ship_name: km.victim["ship_name"],
              role: :victim
            }
          ]
        else
          []
        end

      attacker_ships =
        km.attackers
        |> Enum.filter(&(&1["character_id"] == character_id))
        |> Enum.map(fn attacker ->
          %{
            ship_type_id: attacker["ship_type_id"],
            ship_name: attacker["ship_type_name"],
            role: :attacker
          }
        end)

      victim_ship ++ attacker_ships
    end)
    |> Enum.uniq_by(& &1.ship_type_id)
  end
end
