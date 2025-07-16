defmodule EveDmv.Contexts.CombatIntelligence.Domain.IntelligenceScoring do
  import Ash.Expr
  alias EveDmv.Contexts.CombatIntelligence.Infrastructure.AnalysisCache
  require Logger
  require Ash.Query

  @moduledoc """
  Calculates various intelligence scores for characters.

  This module computes specialized scores including danger ratings,
  hunter effectiveness, fleet command ability, solo pilot skill,
  and awox (betrayal) risk.
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Calculate intelligence score for a character using specific scoring algorithm.
  """
  @spec calculate_score(integer(), atom()) :: {:ok, map()} | {:error, term()}
  def calculate_score(character_id, scoring_type) do
    GenServer.call(__MODULE__, {:calculate_score, character_id, scoring_type})
  end

  @doc """
  Get recommendations for dealing with a specific character.
  """
  @spec get_recommendations(integer()) :: {:ok, [map()]} | {:error, term()}
  def get_recommendations(character_id) do
    GenServer.call(__MODULE__, {:get_recommendations, character_id})
  end

  @doc """
  Get cached scores for a character.
  """
  @spec get_cached_scores(integer()) :: {:ok, map()}
  def get_cached_scores(character_id) do
    case AnalysisCache.get_intelligence_scores(character_id) do
      {:ok, scores} -> {:ok, scores}
      {:error, :not_found} -> {:ok, %{}}
    end
  end

  @doc """
  Refresh all scores for a character.
  """
  @spec refresh_scores(integer()) :: {:ok, map()}
  def refresh_scores(character_id) do
    AnalysisCache.invalidate_intelligence_scores(character_id)
    # Recalculate all score types
    score_types = [
      :danger_rating,
      :hunter_score,
      :fleet_commander_score,
      :solo_pilot_score,
      :awox_risk_score
    ]

    scores =
      Enum.reduce(score_types, %{}, fn score_type, acc ->
        case calculate_score(character_id, score_type) do
          {:ok, score_data} -> Map.put(acc, score_type, score_data)
          {:error, _} -> acc
        end
      end)

    {:ok, scores}
  end

  # GenServer callbacks
  @impl GenServer
  def init(_opts) do
    {:ok,
     %{
       calculation_count: 0,
       cache_hits: 0,
       cache_misses: 0
     }}
  end

  @impl GenServer
  def handle_call({:calculate_score, character_id, scoring_type}, _from, state) do
    result = perform_score_calculation(character_id, scoring_type)

    new_state =
      case result do
        {:ok, _} -> %{state | calculation_count: state.calculation_count + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:get_recommendations, character_id}, _from, state) do
    recommendations = generate_recommendations(character_id)
    {:reply, {:ok, recommendations}, state}
  end

  # Private functions
  defp perform_score_calculation(character_id, scoring_type) do
    # Check cache first
    case AnalysisCache.get_intelligence_score(character_id, scoring_type) do
      {:ok, cached} ->
        {:ok, cached}

      {:error, :not_found} ->
        # Calculate score based on type
        case scoring_type do
          :danger_rating ->
            case calculate_danger_rating(character_id) do
              {:ok, score_data} ->
                AnalysisCache.put_intelligence_score(character_id, scoring_type, score_data)
                {:ok, score_data}

              {:error, _} ->
                {:error, :calculation_failed}
            end

          :hunter_score ->
            case calculate_hunter_score(character_id) do
              {:ok, score_data} ->
                AnalysisCache.put_intelligence_score(character_id, scoring_type, score_data)
                {:ok, score_data}

              {:error, _} ->
                {:error, :calculation_failed}
            end

          :fleet_commander_score ->
            case calculate_fleet_commander_score(character_id) do
              {:ok, score_data} ->
                AnalysisCache.put_intelligence_score(character_id, scoring_type, score_data)
                {:ok, score_data}

              {:error, _} ->
                {:error, :calculation_failed}
            end

          :solo_pilot_score ->
            case calculate_solo_pilot_score(character_id) do
              {:ok, score_data} ->
                AnalysisCache.put_intelligence_score(character_id, scoring_type, score_data)
                {:ok, score_data}

              {:error, _} ->
                {:error, :calculation_failed}
            end

          :awox_risk_score ->
            case calculate_awox_risk_score(character_id) do
              {:ok, score_data} ->
                AnalysisCache.put_intelligence_score(character_id, scoring_type, score_data)
                {:ok, score_data}

              {:error, _} ->
                {:error, :calculation_failed}
            end

          _ ->
            {:error, :unknown_scoring_type}
        end
    end
  end

  defp calculate_danger_rating(character_id) do
    # Calculate danger rating based on recent kills, kill frequency, and ship values destroyed
    # Get recent activity (last 30 days)
    thirty_days_ago = DateTime.utc_now() |> DateTime.add(-30 * 24 * 60 * 60, :second)

    query =
      EveDmv.Killmails.KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(killmail_time >= ^thirty_days_ago))
      |> Ash.Query.load([:participants])

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        # Filter killmails where character is an attacker
        character_kills =
          killmails
          |> Enum.filter(fn killmail ->
            Enum.any?(killmail.participants || [], fn p ->
              p.character_id == character_id && !p.is_victim
            end)
          end)

        kill_count = length(character_kills)

        if kill_count == 0 do
          {:ok,
           %{
             rating: 0,
             score: 0.0,
             confidence: :low,
             kill_frequency: 0.0,
             recent_kills: 0,
             reason: "no_recent_activity"
           }}
        else
          # Calculate kill frequency (kills per day)
          kill_frequency = kill_count / 30.0
          # Calculate average victim ship value (simplified - would need price data)
          avg_destruction_value = calculate_avg_destruction_value(character_kills)
          # Get solo vs gang kills
          solo_kills = Enum.count(character_kills, fn k -> k.attacker_count == 1 end)
          solo_ratio = solo_kills / kill_count
          # Calculate danger score (0-10 scale)
          # Max 3 points for frequency
          frequency_score = min(kill_frequency * 2, 3.0)
          # Max 3 for value
          destruction_score = min(avg_destruction_value / 100_000_000, 3.0)
          # Max 2 points for solo
          solo_score = solo_ratio * 2.0
          # Max 2 for high activity
          activity_score = min(kill_count / 30, 2.0)
          total_score = frequency_score + destruction_score + solo_score + activity_score

          rating =
            cond do
              # Extreme danger
              total_score >= 8.0 -> 5
              # High danger
              total_score >= 6.0 -> 4
              # Moderate danger
              total_score >= 4.0 -> 3
              # Low danger
              total_score >= 2.0 -> 2
              # Minimal danger
              true -> 1
            end

          confidence =
            cond do
              kill_count >= 20 -> :high
              kill_count >= 10 -> :medium
              true -> :low
            end

          {:ok,
           %{
             rating: rating,
             score: Float.round(total_score / 10.0, 2),
             confidence: confidence,
             kill_frequency: Float.round(kill_frequency, 2),
             recent_kills: kill_count,
             solo_ratio: Float.round(solo_ratio, 2),
             reason: "calculated_from_#{kill_count}_kills"
           }}
        end

      {:error, _reason} ->
        {:error, :data_fetch_failed}
    end
  end

  defp calculate_avg_destruction_value(killmails) do
    # Simplified calculation - in reality would look up ship prices
    # For now, use ship type ID as a rough proxy (bigger ID often = more expensive)
    values =
      killmails
      |> Enum.map(fn k -> k.victim_ship_type_id || 0 end)
      |> Enum.filter(fn id -> id > 0 end)

    if length(values) > 0 do
      # Rough conversion
      Enum.sum(values) / length(values) * 10_000
    else
      0
    end
  end

  defp calculate_hunter_score(character_id) do
    # Analyze hunting patterns: solo kills, tackle usage, target selection
    ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90 * 24 * 60 * 60, :second)

    query =
      EveDmv.Killmails.KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(killmail_time >= ^ninety_days_ago))
      |> Ash.Query.load([:participants])

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        # Get kills where character participated
        character_participations =
          killmails
          |> Enum.flat_map(fn killmail ->
            killmail.participants
            |> Enum.filter(fn p -> p.character_id == character_id && !p.is_victim end)
            |> Enum.map(fn p -> {killmail, p} end)
          end)

        total_kills = length(character_participations)

        if total_kills == 0 do
          {:ok,
           %{
             score: 0.0,
             rating: :no_data,
             confidence: :low,
             solo_kills: 0,
             tackle_usage: 0.0,
             reason: "no_kill_participation"
           }}
        else
          # Analyze hunting patterns
          solo_kills =
            character_participations
            |> Enum.count(fn {killmail, _p} -> killmail.attacker_count == 1 end)

          # Check for tackle ship usage (simplified - check common tackle ships)
          # Interceptors
          tackle_ships = [11969, 11971, 11963, 11965]

          tackle_usage =
            character_participations
            |> Enum.count(fn {_k, p} -> p.ship_type_id in tackle_ships end)

          # Final blow percentage
          final_blows =
            character_participations
            |> Enum.count(fn {_k, p} -> p.final_blow end)

          # Calculate hunter score
          # Max 4 points
          solo_score = min(solo_kills / total_kills * 4.0, 4.0)
          # Max 2 points
          tackle_score = min(tackle_usage / total_kills * 2.0, 2.0)
          # Max 2 points
          final_blow_score = min(final_blows / total_kills * 2.0, 2.0)
          # Max 2 points for 50+ kills
          activity_score = min(total_kills / 50.0, 2.0)
          total_score = solo_score + tackle_score + final_blow_score + activity_score
          normalized_score = total_score / 10.0

          rating =
            cond do
              normalized_score >= 0.8 -> :elite
              normalized_score >= 0.6 -> :experienced
              normalized_score >= 0.4 -> :competent
              normalized_score >= 0.2 -> :novice
              true -> :beginner
            end

          confidence =
            cond do
              total_kills >= 30 -> :high
              total_kills >= 15 -> :medium
              true -> :low
            end

          {:ok,
           %{
             score: Float.round(normalized_score, 2),
             rating: rating,
             confidence: confidence,
             solo_kills: solo_kills,
             tackle_usage: Float.round(tackle_usage / max(total_kills, 1), 2),
             final_blow_ratio: Float.round(final_blows / total_kills, 2),
             total_kills: total_kills,
             reason: "analyzed_#{total_kills}_kills"
           }}
        end

      {:error, _reason} ->
        {:error, :data_fetch_failed}
    end
  end

  defp calculate_fleet_commander_score(character_id) do
    # Analyze fleet leadership: large gang participation, consistent fleet members
    ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90 * 24 * 60 * 60, :second)

    query =
      EveDmv.Killmails.KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(killmail_time >= ^ninety_days_ago))
      |> Ash.Query.load([:participants])

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        # Get fleet kills where character participated
        fleet_participations =
          killmails
          # Fleet = 5+ members
          |> Enum.filter(fn k -> k.attacker_count >= 5 end)
          |> Enum.filter(fn killmail ->
            Enum.any?(killmail.participants || [], fn p ->
              p.character_id == character_id && !p.is_victim
            end)
          end)

        fleet_count = length(fleet_participations)

        if fleet_count == 0 do
          {:ok,
           %{
             score: 0.0,
             rating: :no_fleet_experience,
             confidence: :low,
             fleets_led: 0,
             avg_fleet_size: 0,
             reason: "no_fleet_participation"
           }}
        else
          # Analyze fleet patterns
          fleet_sizes = Enum.map(fleet_participations, & &1.attacker_count)
          avg_fleet_size = Enum.sum(fleet_sizes) / fleet_count
          # Check for large fleet participation (20+ members)
          large_fleets = Enum.count(fleet_sizes, &(&1 >= 20))
          # Check for consistent fleet mates (simplified)
          fleet_consistency = calculate_fleet_consistency(fleet_participations, character_id)
          # Calculate FC score
          # Max 3 points
          participation_score = min(fleet_count / 30.0, 3.0)
          # Max 3 points
          size_score = min(avg_fleet_size / 20.0, 3.0)
          # Max 2 points
          large_fleet_score = min(large_fleets / 10.0, 2.0)
          # Max 2 points
          consistency_score = fleet_consistency * 2.0
          total_score = participation_score + size_score + large_fleet_score + consistency_score
          normalized_score = total_score / 10.0

          rating =
            cond do
              normalized_score >= 0.8 -> :veteran_fc
              normalized_score >= 0.6 -> :experienced_fc
              normalized_score >= 0.4 -> :competent
              normalized_score >= 0.2 -> :junior_fc
              true -> :line_member
            end

          confidence =
            cond do
              fleet_count >= 20 -> :high
              fleet_count >= 10 -> :medium
              true -> :low
            end

          {:ok,
           %{
             score: Float.round(normalized_score, 2),
             rating: rating,
             confidence: confidence,
             fleets_participated: fleet_count,
             avg_fleet_size: Float.round(avg_fleet_size, 1),
             large_fleet_ratio: Float.round(large_fleets / fleet_count, 2),
             reason: "analyzed_#{fleet_count}_fleets"
           }}
        end

      {:error, _reason} ->
        {:error, :data_fetch_failed}
    end
  end

  defp calculate_fleet_consistency(fleet_participations, character_id) do
    # Calculate how often the character flies with the same people
    all_fleet_mates =
      fleet_participations
      |> Enum.flat_map(fn killmail ->
        killmail.participants
        |> Enum.filter(fn p -> p.character_id != character_id && !p.is_victim end)
        |> Enum.map(& &1.character_id)
      end)

    if Enum.empty?(all_fleet_mates) do
      0.0
    else
      # Count frequency of fleet mates
      mate_frequency =
        all_fleet_mates
        |> Enum.frequencies()
        |> Map.values()
        # Flown together 3+ times
        |> Enum.filter(&(&1 >= 3))
        |> length()

      # Normalize to 0-1 scale
      min(mate_frequency / 10.0, 1.0)
    end
  end

  defp calculate_solo_pilot_score(character_id) do
    # Analyze solo combat effectiveness and survival
    ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90 * 24 * 60 * 60, :second)

    query =
      EveDmv.Killmails.KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.filter(expr(killmail_time >= ^ninety_days_ago))
      |> Ash.Query.load([:participants])

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        # Get solo kills (attacker_count = 1)
        solo_kills =
          killmails
          |> Enum.filter(fn k -> k.attacker_count == 1 end)
          |> Enum.filter(fn killmail ->
            Enum.any?(killmail.participants || [], fn p ->
              p.character_id == character_id && !p.is_victim
            end)
          end)

        # Get solo losses
        solo_losses =
          killmails
          |> Enum.filter(fn killmail ->
            killmail.victim_character_id == character_id && killmail.attacker_count == 1
          end)

        kill_count = length(solo_kills)
        loss_count = length(solo_losses)

        if kill_count + loss_count == 0 do
          {:ok,
           %{
             score: 0.0,
             rating: :no_solo_activity,
             confidence: :low,
             solo_kills: 0,
             solo_losses: 0,
             efficiency: 0.0,
             reason: "no_solo_combat"
           }}
        else
          # Calculate efficiency
          efficiency =
            if loss_count == 0 do
              1.0
            else
              kill_count / (kill_count + loss_count)
            end

          # Analyze ship diversity in solo
          ship_diversity = calculate_ship_diversity(solo_kills)
          # Calculate solo pilot score
          # Max 3 points for 20+ kills
          kill_score = min(kill_count / 20.0, 3.0)
          # Max 4 points
          efficiency_score = efficiency * 4.0

          survival_score =
            if loss_count == 0 && kill_count >= 5 do
              # Bonus for no losses with 5+ kills
              2.0
            else
              max(0, 2.0 - loss_count / 10.0)
            end

          # Max 1 point
          diversity_score = ship_diversity
          total_score = kill_score + efficiency_score + survival_score + diversity_score
          normalized_score = total_score / 10.0

          rating =
            cond do
              normalized_score >= 0.8 -> :dangerous
              normalized_score >= 0.6 -> :skilled
              normalized_score >= 0.4 -> :competent
              normalized_score >= 0.2 -> :learning
              true -> :novice
            end

          confidence =
            cond do
              kill_count + loss_count >= 20 -> :high
              kill_count + loss_count >= 10 -> :medium
              true -> :low
            end

          {:ok,
           %{
             score: Float.round(normalized_score, 2),
             rating: rating,
             confidence: confidence,
             solo_kills: kill_count,
             solo_losses: loss_count,
             efficiency: Float.round(efficiency, 2),
             ship_diversity: Float.round(ship_diversity, 2),
             reason: "#{kill_count}_kills_#{loss_count}_losses"
           }}
        end

      {:error, _reason} ->
        {:error, :data_fetch_failed}
    end
  end

  defp calculate_ship_diversity(killmails) do
    # Calculate how diverse the ship usage is
    ship_types =
      killmails
      |> Enum.flat_map(fn k ->
        k.participants
        |> Enum.filter(fn p -> !p.is_victim end)
        |> Enum.map(& &1.ship_type_id)
      end)
      |> Enum.uniq()
      |> length()

    # Normalize: 1 ship = 0, 5+ ships = 1.0
    min((ship_types - 1) / 4.0, 1.0)
  end

  defp calculate_awox_risk_score(character_id) do
    # Analyze betrayal risk factors: corp history, blue-on-blue incidents
    # Get all killmails involving this character
    query =
      EveDmv.Killmails.KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.load([:participants])

    case Ash.read(query, domain: EveDmv.Api) do
      {:ok, killmails} ->
        # Find potential friendly fire incidents
        # Where character killed someone from same corp/alliance
        friendly_fire_incidents =
          killmails
          |> Enum.filter(fn killmail ->
            attacker =
              Enum.find(killmail.participants || [], fn p ->
                p.character_id == character_id && !p.is_victim
              end)

            if attacker do
              # Check if victim was in same corp/alliance
              victim_corp = killmail.victim_corporation_id
              victim_alliance = killmail.victim_alliance_id

              (victim_corp && victim_corp == attacker.corporation_id) ||
                (victim_alliance && victim_alliance == attacker.alliance_id)
            else
              false
            end
          end)

        ff_count = length(friendly_fire_incidents)
        # Get total kills to calculate ratio
        total_kills =
          killmails
          |> Enum.count(fn killmail ->
            Enum.any?(killmail.participants || [], fn p ->
              p.character_id == character_id && !p.is_victim
            end)
          end)

        # Calculate awox risk score
        if total_kills == 0 do
          {:ok,
           %{
             score: 0.0,
             rating: :unknown,
             confidence: :low,
             friendly_fire_count: 0,
             reason: "no_combat_history"
           }}
        else
          ff_ratio = ff_count / total_kills
          # Risk factors
          # Max 5 points for FF ratio
          base_risk = ff_ratio * 5.0
          # Max 3 points for incidents
          incident_risk = min(ff_count * 0.5, 3.0)
          # Mitigating factors (simplified - would check corp tenure, etc)
          mitigation =
            if total_kills >= 100 && ff_ratio < 0.01 do
              # Reduce risk for high activity with low FF
              2.0
            else
              0.0
            end

          risk_score = max(0, base_risk + incident_risk - mitigation) / 8.0

          rating =
            cond do
              risk_score >= 0.7 -> :extreme_risk
              risk_score >= 0.5 -> :high_risk
              risk_score >= 0.3 -> :moderate_risk
              risk_score >= 0.1 -> :low_risk
              true -> :minimal_risk
            end

          confidence =
            cond do
              total_kills >= 50 -> :high
              total_kills >= 20 -> :medium
              true -> :low
            end

          {:ok,
           %{
             score: Float.round(risk_score, 2),
             rating: rating,
             confidence: confidence,
             friendly_fire_count: ff_count,
             friendly_fire_ratio: Float.round(ff_ratio, 3),
             total_kills_analyzed: total_kills,
             reason: "analyzed_#{total_kills}_kills"
           }}
        end

      {:error, _reason} ->
        {:error, :data_fetch_failed}
    end
  end

  defp generate_recommendations(character_id) do
    # Generate tactical recommendations based on all intelligence scores
    with {:ok, danger} <- calculate_danger_rating(character_id),
         {:ok, hunter} <- calculate_hunter_score(character_id),
         {:ok, fc} <- calculate_fleet_commander_score(character_id),
         {:ok, solo} <- calculate_solo_pilot_score(character_id),
         {:ok, awox} <- calculate_awox_risk_score(character_id) do
      recommendations = []
      # Danger-based recommendations
      recommendations =
        if danger.rating >= 4 do
          recommendations ++
            [
              %{
                type: :warning,
                priority: :high,
                message: "Extreme threat - #{danger.recent_kills} kills in last 30 days",
                action: "Avoid solo engagement, use scouts when traveling"
              }
            ]
        else
          recommendations
        end

      # Hunter-based recommendations
      recommendations =
        if hunter.rating in [:elite, :experienced] do
          recommendations ++
            [
              %{
                type: :tactical,
                priority: :high,
                message: "Skilled hunter with #{hunter.solo_kills} solo kills",
                action: "Expect tackle ships and kiting tactics"
              }
            ]
        else
          recommendations
        end

      # FC-based recommendations
      recommendations =
        if fc.rating in [:veteran_fc, :experienced_fc] do
          recommendations ++
            [
              %{
                type: :strategic,
                priority: :medium,
                message: "Experienced FC - avg fleet size #{fc.avg_fleet_size}",
                action: "Expect coordinated fleet response if engaged"
              }
            ]
        else
          recommendations
        end

      # Solo pilot recommendations
      recommendations =
        if solo.rating == :dangerous && solo.efficiency > 0.8 do
          recommendations ++
            [
              %{
                type: :tactical,
                priority: :high,
                message: "Dangerous solo pilot - #{solo.efficiency * 100}% efficiency",
                action: "Do not engage solo unless confident in ship advantage"
              }
            ]
        else
          recommendations
        end

      # Awox risk recommendations
      recommendations =
        if awox.rating in [:high_risk, :extreme_risk] do
          recommendations ++
            [
              %{
                type: :security,
                priority: :critical,
                message: "High awox risk - #{awox.friendly_fire_count} blue-on-blue incidents",
                action: "Do not grant roles or access to valuable assets"
              }
            ]
        else
          recommendations
        end

      # Add general engagement recommendation
      engagement_risk = (danger.score + hunter.score + solo.score) / 3

      recommendations ++
        [
          %{
            type: :summary,
            priority: :medium,
            message: "Overall combat threat: #{Float.round(engagement_risk, 2)}/1.0",
            action:
              cond do
                engagement_risk > 0.7 -> "Avoid engagement unless with superior numbers"
                engagement_risk > 0.5 -> "Engage with caution, ensure escape route"
                engagement_risk > 0.3 -> "Standard engagement protocols apply"
                true -> "Low threat target, engage at will"
              end
          }
        ]
    else
      _ -> []
    end
  end
end
