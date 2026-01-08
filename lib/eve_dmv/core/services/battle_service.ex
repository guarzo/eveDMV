defmodule EveDmv.Core.Services.BattleService do
  @moduledoc """
  Service layer for battle-related operations.
  Orchestrates between contexts without creating circular dependencies.
  """

  alias EveDmv.Contexts.BattleAnalysis
  require Logger

  @doc """
  Analyzes a battle with all intelligence layers.
  Coordinates between contexts without direct coupling.
  """
  def analyze_battle_comprehensive(killmail_ids) when is_list(killmail_ids) do
    with {:ok, battle} <- detect_and_build_battle(killmail_ids),
         {:ok, participants} <- analyze_participants(battle),
         {:ok, intelligence} <- gather_intelligence(battle, participants),
         {:ok, predictions} <- generate_predictions(battle, participants) do
      {:ok,
       %{
         battle: battle,
         participants: participants,
         intelligence: intelligence,
         predictions: predictions,
         analyzed_at: DateTime.utc_now()
       }}
    else
      {:error, reason} = error ->
        Logger.error("Battle analysis failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Detects battle from killmail IDs
  """
  def detect_battle(killmail_ids) when is_list(killmail_ids) do
    BattleAnalysis.analyze_battle_from_killmail_ids(killmail_ids)
  end

  @doc """
  Gets battle timeline for a specific battle.

  Retrieves a detailed timeline including:
  - Chronological events
  - Battle phases (engagement, escalation, etc.)
  - Fleet composition changes over time
  - Key moments and turning points

  ## Parameters
  - battle_id: String identifier for the battle

  ## Returns
  - {:ok, timeline} with full battle timeline data
  - {:error, reason} if battle not found or timeline reconstruction fails
  """
  def get_battle_timeline(battle_id) when is_binary(battle_id) do
    case BattleAnalysis.get_battle_with_timeline(battle_id) do
      {:ok, timeline} ->
        {:ok, timeline}

      {:error, :battle_not_found} = error ->
        Logger.warning("Battle not found: #{battle_id}")
        error

      {:error, reason} = error ->
        Logger.error("Failed to retrieve battle timeline for #{battle_id}: #{inspect(reason)}")
        error
    end
  end

  def get_battle_timeline(_battle_id) do
    {:error, :invalid_battle_id}
  end

  @doc """
  Analyzes battle metrics
  """
  def analyze_battle_metrics(battle) do
    # Calculate metrics locally
    {:ok,
     %{
       total_participants: count_total_participants(battle),
       duration: calculate_battle_duration(battle),
       intensity: calculate_engagement_intensity(battle)
     }}
  end

  defp count_total_participants(battle) do
    attackers = Map.get(battle, :attackers, [])
    victims = Map.get(battle, :victims, [])
    length(attackers) + length(victims)
  end

  defp detect_and_build_battle(killmail_ids) do
    # Only calls BattleAnalysis context
    case BattleAnalysis.analyze_battle_from_killmail_ids(killmail_ids) do
      {:ok, battle} -> {:ok, battle}
      {:error, _} = error -> error
    end
  end

  defp analyze_participants(battle) do
    # Extract participant IDs without calling other contexts
    participant_ids = extract_participant_ids(battle)

    {:ok,
     %{
       attackers: Enum.filter(participant_ids, &attacker?(&1, battle)),
       victims: Enum.filter(participant_ids, &victim?(&1, battle)),
       total_count: length(participant_ids),
       unique_corporations: count_unique_corporations(battle),
       unique_alliances: count_unique_alliances(battle)
     }}
  end

  defp gather_intelligence(battle, participants) do
    # For now, return basic intelligence without circular dependencies
    # This will be expanded when we have character service
    {:ok,
     %{
       battle_type: classify_battle_type(battle, participants),
       engagement_profile: analyze_engagement_profile(battle),
       force_multipliers: identify_force_multipliers(battle)
     }}
  end

  defp generate_predictions(battle, participants) do
    # Generate predictions without circular calls
    {:ok,
     %{
       outcome_probability: calculate_outcome_probability(battle, participants),
       escalation_risk: calculate_escalation_risk(battle, participants),
       reinforcement_likelihood: calculate_reinforcement_likelihood(participants)
     }}
  end

  defp extract_participant_ids(battle) do
    attackers = Map.get(battle, :attackers, [])
    victims = Map.get(battle, :victims, [])

    (attackers ++ victims)
    |> Enum.map(&extract_character_id/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
  end

  defp extract_character_id(%{character_id: id}), do: id
  defp extract_character_id(%{"character_id" => id}), do: id
  defp extract_character_id(_), do: nil

  defp attacker?(character_id, battle) do
    attackers = Map.get(battle, :attackers, [])

    Enum.any?(attackers, fn attacker ->
      extract_character_id(attacker) == character_id
    end)
  end

  defp victim?(character_id, battle) do
    victims = Map.get(battle, :victims, [])

    Enum.any?(victims, fn victim ->
      extract_character_id(victim) == character_id
    end)
  end

  defp count_unique_corporations(battle) do
    battle
    |> extract_all_participants()
    |> Enum.map(&extract_corporation_id/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_alliances(battle) do
    battle
    |> extract_all_participants()
    |> Enum.map(&extract_alliance_id/1)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> length()
  end

  defp extract_all_participants(battle) do
    attackers = Map.get(battle, :attackers, [])
    victims = Map.get(battle, :victims, [])
    attackers ++ victims
  end

  defp extract_corporation_id(%{corporation_id: id}), do: id
  defp extract_corporation_id(%{"corporation_id" => id}), do: id
  defp extract_corporation_id(_), do: nil

  defp extract_alliance_id(%{alliance_id: id}), do: id
  defp extract_alliance_id(%{"alliance_id" => id}), do: id
  defp extract_alliance_id(_), do: nil

  defp classify_battle_type(_battle, participants) do
    participant_count = participants.total_count

    cond do
      participant_count <= 2 -> :duel
      participant_count <= 10 -> :small_gang
      participant_count <= 50 -> :medium_fleet
      participant_count <= 150 -> :large_fleet
      true -> :massive_battle
    end
  end

  defp analyze_engagement_profile(battle) do
    %{
      duration: calculate_battle_duration(battle),
      intensity: calculate_engagement_intensity(battle),
      geographic_spread: calculate_geographic_spread(battle)
    }
  end

  defp calculate_battle_duration(battle) do
    killmails = Map.get(battle, :killmails, [])

    if Enum.empty?(killmails) do
      0
    else
      times = Enum.map(killmails, &extract_killmail_time/1)
      min_time = Enum.min(times, DateTime)
      max_time = Enum.max(times, DateTime)
      DateTime.diff(max_time, min_time, :second)
    end
  end

  defp extract_killmail_time(%{killmail_time: time}), do: time

  defp extract_killmail_time(%{"killmail_time" => time}) when is_binary(time) do
    case DateTime.from_iso8601(time) do
      {:ok, datetime, _} -> datetime
      _ -> DateTime.utc_now()
    end
  end

  defp extract_killmail_time(_), do: DateTime.utc_now()

  defp calculate_engagement_intensity(battle) do
    killmails = Map.get(battle, :killmails, [])
    duration = calculate_battle_duration(battle)

    if duration > 0 do
      # Kills per minute
      length(killmails) / (duration / 60.0)
    else
      0.0
    end
  end

  defp calculate_geographic_spread(battle) do
    systems =
      battle
      |> Map.get(:killmails, [])
      |> Enum.map(&extract_system_id/1)
      |> Enum.uniq()
      |> length()

    %{
      system_count: systems,
      concentrated: systems == 1
    }
  end

  defp extract_system_id(%{solar_system_id: id}), do: id
  defp extract_system_id(%{"solar_system_id" => id}), do: id
  defp extract_system_id(_), do: nil

  defp identify_force_multipliers(battle) do
    attackers = Map.get(battle, :attackers, [])

    %{
      logistics_present: has_logistics_ships?(attackers),
      ewar_present: has_ewar_ships?(attackers),
      capital_present: has_capital_ships?(attackers)
    }
  end

  defp has_logistics_ships?(participants) do
    # Check for common logistics ship type IDs
    logistics_ship_ids = [11_985, 11_987, 11_989, 11_978, 11_969, 11_971]
    has_ship_types?(participants, logistics_ship_ids)
  end

  defp has_ewar_ships?(participants) do
    # Check for common EWAR ship type IDs
    ewar_ship_ids = [11_959, 11_961, 11_963, 11_965, 11_174, 11_176]
    has_ship_types?(participants, ewar_ship_ids)
  end

  defp has_capital_ships?(participants) do
    # Check for capital ship type IDs
    capital_ship_ids = [19_720, 19_722, 19_724, 19_726, 23_917, 23_919]
    has_ship_types?(participants, capital_ship_ids)
  end

  defp has_ship_types?(participants, ship_type_ids) do
    Enum.any?(participants, fn participant ->
      ship_type = extract_ship_type_id(participant)
      ship_type in ship_type_ids
    end)
  end

  defp extract_ship_type_id(%{ship_type_id: id}), do: id
  defp extract_ship_type_id(%{"ship_type_id" => id}), do: id
  defp extract_ship_type_id(_), do: nil

  defp calculate_outcome_probability(_battle, participants) do
    # Simple probability based on participant balance
    attacker_count = length(participants.attackers)
    victim_count = length(participants.victims)
    total = attacker_count + victim_count

    if total > 0 do
      attacker_ratio = attacker_count / total

      cond do
        # Overwhelming attacker advantage
        attacker_ratio > 0.8 -> 0.9
        # Moderate attacker advantage
        attacker_ratio > 0.6 -> 0.7
        # Balanced
        attacker_ratio > 0.4 -> 0.5
        # Defender advantage
        true -> 0.3
      end
    else
      0.5
    end
  end

  defp calculate_escalation_risk(battle, participants) do
    # Risk based on battle type and force multipliers
    battle_type = classify_battle_type(battle, participants)
    force_multipliers = identify_force_multipliers(battle)

    base_risk =
      case battle_type do
        :duel -> 0.1
        :small_gang -> 0.3
        :medium_fleet -> 0.5
        :large_fleet -> 0.7
        :massive_battle -> 0.9
      end

    # Adjust for force multipliers
    risk_adjustment =
      if(force_multipliers.capital_present, do: 0.2, else: 0) +
        if force_multipliers.logistics_present, do: 0.1, else: 0

    min(base_risk + risk_adjustment, 1.0)
  end

  defp calculate_reinforcement_likelihood(participants) do
    # Based on corporation/alliance diversity
    corp_count = participants.unique_corporations
    alliance_count = participants.unique_alliances

    cond do
      # Multiple alliances likely means more reinforcements
      alliance_count > 3 -> 0.8
      alliance_count > 1 -> 0.6
      corp_count > 5 -> 0.5
      corp_count > 2 -> 0.3
      true -> 0.1
    end
  end
end
