defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.ExperienceAnalyzer do
  @moduledoc """
  Analyzes participant experience levels and skill progression.

  Evaluates player experience based on various factors including security status,
  ship choices, combat performance, and historical patterns.
  """

  require Logger

  @doc """
  Analyze participant experience levels.
  """
  def analyze_participant_experience(participants) do
    Logger.debug("Analyzing participant experience levels")

    experience_distribution = calculate_experience_distribution(participants)
    skill_analysis = analyze_skill_levels(participants)
    skill_advantages = identify_skill_advantages(participants)
    veteran_players = identify_veteran_players(participants)
    rookie_players = identify_rookie_players(participants)
    experience_advantage = calculate_experience_advantage(participants)

    %{
      distribution: experience_distribution,
      skill_analysis: skill_analysis,
      skill_advantages: skill_advantages,
      veterans: veteran_players,
      rookies: rookie_players,
      advantage: experience_advantage,
      summary: %{
        average_experience: calculate_average_experience(participants),
        experience_diversity: measure_experience_diversity(experience_distribution),
        experience_gaps: identify_experience_gaps(veteran_players, rookie_players),
        mentorship_potential: identify_mentorship_pairs(veteran_players, rookie_players),
        fleet_maturity: assess_fleet_maturity(experience_distribution)
      }
    }
  end

  @doc """
  Calculate experience distribution across participants.
  """
  def calculate_experience_distribution(participants) do
    participants
    |> Enum.map(&estimate_experience_level/1)
    |> Enum.group_by(&Map.get(&1, :level))
    |> Enum.map(fn {level, participants_at_level} ->
      {level,
       %{
         count: length(participants_at_level),
         percentage: length(participants_at_level) / length(participants) * 100,
         average_score: calculate_average_score(participants_at_level)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Analyze skill levels based on ship choices and performance.
  """
  def analyze_skill_levels(participants) do
    # Group by ship class to analyze skill requirements
    by_ship_class =
      participants
      |> Enum.group_by(&Map.get(&1, :ship_class, :unknown))
      |> Enum.map(fn {ship_class, pilots} ->
        {ship_class,
         %{
           pilot_count: length(pilots),
           average_experience: calculate_average_pilot_experience(pilots),
           skill_requirement: get_ship_class_skill_requirement(ship_class),
           performance_metrics: calculate_class_performance_metrics(pilots)
         }}
      end)
      |> Enum.into(%{})

    # Analyze overall skill composition
    skill_composition = analyze_skill_composition(by_ship_class)

    %{
      by_ship_class: by_ship_class,
      skill_composition: skill_composition,
      advanced_ship_usage: calculate_advanced_ship_usage(participants),
      skill_gaps: identify_skill_gaps(by_ship_class)
    }
  end

  @doc """
  Identify skill advantages between groups.
  """
  def identify_skill_advantages(participants) do
    # Group participants by their primary affiliation
    affiliation_groups =
      participants
      |> Enum.group_by(fn p ->
        Map.get(p, :alliance_id) || Map.get(p, :corporation_id)
      end)
      |> Enum.filter(fn {_key, members} -> length(members) >= 3 end)

    # Calculate skill metrics for each group
    group_skills =
      Enum.map(affiliation_groups, fn {affiliation_id, members} ->
        {affiliation_id,
         %{
           average_experience: calculate_average_participant_experience(members),
           veteran_ratio: calculate_veteran_ratio(members),
           capital_pilots: count_capital_pilots(members),
           skill_diversity: calculate_skill_diversity(members)
         }}
      end)
      |> Enum.into(%{})

    # Identify advantages
    if map_size(group_skills) >= 2 do
      identify_group_advantages(group_skills)
    else
      %{
        clear_advantages: [],
        balanced_matchup: true,
        skill_gap: 0.0
      }
    end
  end

  @doc """
  Identify veteran players based on multiple factors.
  """
  def identify_veteran_players(participants) do
    participants
    |> Enum.filter(&veteran?/1)
    |> Enum.map(fn participant ->
      %{
        character_id: Map.get(participant, :character_id),
        character_name: Map.get(participant, :character_name),
        indicators: get_veteran_indicators(participant),
        estimated_sp: estimate_skill_points(participant),
        specializations: Map.get(participant, :specializations, [])
      }
    end)
    |> Enum.sort_by(&Map.get(&1, :estimated_sp), :desc)
  end

  @doc """
  Identify rookie players who may need support.
  """
  def identify_rookie_players(participants) do
    participants
    |> Enum.filter(&rookie?/1)
    |> Enum.map(fn participant ->
      %{
        character_id: Map.get(participant, :character_id),
        character_name: Map.get(participant, :character_name),
        indicators: get_rookie_indicators(participant),
        learning_opportunities: identify_learning_opportunities(participant),
        risk_factors: assess_rookie_risks(participant)
      }
    end)
  end

  @doc """
  Calculate overall experience advantage.
  """
  def calculate_experience_advantage(participants) do
    # Group by participant type (attacker/victim)
    by_type = Enum.group_by(participants, &Map.get(&1, :participant_type))

    attackers = Map.get(by_type, :attacker, [])
    victims = Map.get(by_type, :victim, [])

    attacker_exp = calculate_average_participant_experience(attackers)
    victim_exp = calculate_average_participant_experience(victims)

    advantage = attacker_exp - victim_exp

    %{
      attacker_experience: Float.round(attacker_exp, 1),
      victim_experience: Float.round(victim_exp, 1),
      advantage_magnitude: Float.round(abs(advantage), 1),
      favors: determine_advantage_favor(advantage),
      significance: assess_advantage_significance(advantage)
    }
  end

  # Private functions

  defp estimate_experience_level(participant) do
    # Estimate experience based on security status, ship type, and behavior
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)

    security_factor = calculate_security_experience_factor(security_status)
    ship_factor = calculate_ship_experience_factor(ship_class)
    performance_factor = calculate_performance_factor(participant)

    base_experience = (security_factor + ship_factor + performance_factor) / 3.0

    %{
      level: categorize_experience_level(base_experience),
      score: base_experience,
      factors: %{
        security_status: security_factor,
        ship_choice: ship_factor,
        performance: performance_factor
      },
      participant: participant
    }
  end

  defp calculate_security_experience_factor(security_status) do
    cond do
      # Outlaw, very experienced
      security_status < -5.0 -> 0.9
      # Criminal, experienced
      security_status < -2.0 -> 0.7
      # Suspect, moderate experience
      security_status < 0.0 -> 0.5
      # High-sec dweller, less PvP experience
      security_status > 4.0 -> 0.2
      # Mixed experience
      true -> 0.4
    end
  end

  defp calculate_ship_experience_factor(ship_class) do
    case ship_class do
      # Capital pilots are typically experienced
      :capital -> 0.9
      # Battleship pilots have significant experience
      :battleship -> 0.7
      # Cruiser pilots have moderate experience
      :cruiser -> 0.5
      # Frigate pilots vary widely
      :frigate -> 0.4
      # Unknown or special ships
      _ -> 0.3
    end
  end

  defp calculate_performance_factor(participant) do
    damage_done = Map.get(participant, :damage_done, 0)
    survived = Map.get(participant, :participant_type) == :attacker

    damage_score =
      cond do
        damage_done > 50_000 -> 0.9
        damage_done > 20_000 -> 0.7
        damage_done > 10_000 -> 0.5
        damage_done > 5000 -> 0.3
        true -> 0.1
      end

    survival_bonus = if survived, do: 0.2, else: 0.0

    min(1.0, damage_score + survival_bonus)
  end

  defp categorize_experience_level(score) do
    cond do
      score >= 0.8 -> :veteran
      score >= 0.6 -> :experienced
      score >= 0.4 -> :intermediate
      score >= 0.2 -> :novice
      true -> :rookie
    end
  end

  defp calculate_average_score(participants_at_level) do
    scores = Enum.map(participants_at_level, &Map.get(&1, :score))

    if Enum.empty?(scores) do
      0.0
    else
      Float.round(Enum.sum(scores) / length(scores), 2)
    end
  end

  defp calculate_average_pilot_experience(pilots) do
    experience_scores =
      pilots
      |> Enum.map(&estimate_participant_experience_score/1)

    if Enum.empty?(experience_scores) do
      0.0
    else
      Float.round(Enum.sum(experience_scores) / length(experience_scores), 1)
    end
  end

  defp estimate_participant_experience_score(participant) do
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_done = Map.get(participant, :damage_done, 0)

    # Base score from security status
    base_score =
      cond do
        security_status < -5.0 -> 80
        security_status < -2.0 -> 60
        security_status < 0.0 -> 40
        true -> 20
      end

    # Ship complexity bonus
    ship_bonus =
      case ship_class do
        :capital -> 30
        :battleship -> 20
        :cruiser -> 10
        :frigate -> 5
        _ -> 0
      end

    # Performance bonus
    performance_bonus = min(20, damage_done / 2500)

    base_score + ship_bonus + performance_bonus
  end

  defp get_ship_class_skill_requirement(ship_class) do
    case ship_class do
      :capital -> :very_high
      :battleship -> :high
      :cruiser -> :moderate
      :frigate -> :low
      _ -> :minimal
    end
  end

  defp calculate_class_performance_metrics(pilots) do
    total_damage =
      pilots
      |> Enum.map(&Map.get(&1, :damage_done, 0))
      |> Enum.sum()

    survival_rate =
      Enum.count(pilots, &(Map.get(&1, :participant_type) == :attacker)) /
        max(1, length(pilots))

    %{
      total_damage: total_damage,
      average_damage: if(Enum.empty?(pilots), do: 0, else: total_damage / length(pilots)),
      survival_rate: Float.round(survival_rate, 2)
    }
  end

  defp analyze_skill_composition(by_ship_class) do
    total_pilots =
      by_ship_class
      |> Map.values()
      |> Enum.map(&Map.get(&1, :pilot_count, 0))
      |> Enum.sum()

    if total_pilots == 0 do
      %{
        skill_level: :unknown,
        complexity: :simple
      }
    else
      # Calculate weighted skill level
      skill_weights = %{
        capital: 5,
        battleship: 3,
        cruiser: 2,
        frigate: 1,
        unknown: 0
      }

      weighted_score =
        by_ship_class
        |> Enum.map(fn {class, data} ->
          weight = Map.get(skill_weights, class, 0)
          count = Map.get(data, :pilot_count, 0)
          weight * count
        end)
        |> Enum.sum()

      average_skill = weighted_score / total_pilots

      %{
        skill_level: categorize_fleet_skill_level(average_skill),
        complexity: assess_doctrine_complexity(Map.keys(by_ship_class)),
        weighted_score: Float.round(average_skill, 2)
      }
    end
  end

  defp categorize_fleet_skill_level(score) do
    cond do
      score >= 3.5 -> :elite
      score >= 2.5 -> :veteran
      score >= 1.5 -> :experienced
      score >= 0.5 -> :novice
      true -> :rookie
    end
  end

  defp assess_doctrine_complexity(ship_classes) do
    unique_classes = length(Enum.uniq(ship_classes))

    cond do
      unique_classes >= 5 -> :highly_complex
      unique_classes >= 3 -> :complex
      unique_classes >= 2 -> :moderate
      true -> :simple
    end
  end

  defp calculate_advanced_ship_usage(participants) do
    advanced_ships = [:capital, :battleship]

    advanced_count =
      Enum.count(participants, fn p ->
        Map.get(p, :ship_class) in advanced_ships
      end)

    total = length(participants)

    if total > 0 do
      Float.round(advanced_count / total * 100, 1)
    else
      0.0
    end
  end

  defp identify_skill_gaps(by_ship_class) do
    # Identify classes with low average experience
    by_ship_class
    |> Enum.filter(fn {_class, data} ->
      Map.get(data, :average_experience, 0) < 40
    end)
    |> Enum.map(fn {class, data} ->
      %{
        ship_class: class,
        pilot_count: Map.get(data, :pilot_count),
        average_experience: Map.get(data, :average_experience),
        recommendation: generate_skill_recommendation(class, data)
      }
    end)
  end

  defp generate_skill_recommendation(ship_class, data) do
    avg_exp = Map.get(data, :average_experience, 0)

    case ship_class do
      :capital when avg_exp < 60 ->
        "Capital pilots need more experience - high risk of loss"

      :battleship when avg_exp < 40 ->
        "Battleship pilots may struggle with positioning and tank management"

      _ ->
        "Consider additional training for optimal performance"
    end
  end

  defp calculate_average_participant_experience(members) do
    if Enum.empty?(members) do
      0.0
    else
      experience_scores =
        members
        |> Enum.map(&estimate_participant_experience_score/1)

      Enum.sum(experience_scores) / length(experience_scores)
    end
  end

  defp calculate_veteran_ratio(members) do
    veterans = Enum.count(members, &veteran?/1)

    if Enum.empty?(members) do
      0.0
    else
      Float.round(veterans / length(members), 2)
    end
  end

  defp count_capital_pilots(members) do
    Enum.count(members, fn m ->
      Map.get(m, :ship_class) == :capital
    end)
  end

  defp calculate_skill_diversity(members) do
    ship_classes =
      members
      |> Enum.map(&Map.get(&1, :ship_class))
      |> Enum.uniq()
      |> length()

    ship_classes / max(1, length(members))
  end

  defp identify_group_advantages(group_skills) do
    # Find the strongest and weakest groups
    sorted_groups =
      group_skills
      |> Enum.sort_by(
        fn {_id, skills} ->
          Map.get(skills, :average_experience, 0)
        end,
        :desc
      )

    {strongest_id, strongest} = List.first(sorted_groups)
    {_weakest_id, weakest} = List.last(sorted_groups)

    skill_gap =
      Map.get(strongest, :average_experience, 0) -
        Map.get(weakest, :average_experience, 0)

    %{
      clear_advantages: [
        %{
          group: strongest_id,
          advantages: describe_advantages(strongest),
          margin: Float.round(skill_gap, 1)
        }
      ],
      balanced_matchup: skill_gap < 20,
      skill_gap: Float.round(skill_gap, 1),
      analysis: analyze_matchup(strongest, weakest)
    }
  end

  defp describe_advantages(group_skills) do
    []
    |> (fn advs ->
      if Map.get(group_skills, :veteran_ratio, 0) > 0.5 do
        ["High veteran ratio (#{Map.get(group_skills, :veteran_ratio) * 100}%)" | advs]
      else
        advs
      end
    end).()
    |> (fn advs ->
      if Map.get(group_skills, :capital_pilots, 0) > 0 do
        ["#{Map.get(group_skills, :capital_pilots)} capital pilots" | advs]
      else
        advs
      end
    end).()
  end

  defp analyze_matchup(strongest, weakest) do
    %{
      experience_difference:
        Map.get(strongest, :average_experience, 0) -
          Map.get(weakest, :average_experience, 0),
      veteran_ratio_difference:
        Map.get(strongest, :veteran_ratio, 0) -
          Map.get(weakest, :veteran_ratio, 0),
      likely_outcome: predict_matchup_outcome(strongest, weakest)
    }
  end

  defp predict_matchup_outcome(strongest, weakest) do
    exp_diff =
      Map.get(strongest, :average_experience, 0) -
        Map.get(weakest, :average_experience, 0)

    cond do
      exp_diff > 40 -> :heavily_favors_experienced
      exp_diff > 20 -> :favors_experienced
      exp_diff > 10 -> :slight_advantage
      true -> :evenly_matched
    end
  end

  defp veteran?(participant) do
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_done = Map.get(participant, :damage_done, 0)

    # Multiple indicators of veteran status
    low_sec_status = security_status < -5.0
    flies_capital = ship_class in [:capital, :battleship]
    high_damage = damage_done > 30_000

    # Veteran if meets at least 2 criteria
    indicators = [low_sec_status, flies_capital, high_damage]
    Enum.count(indicators, & &1) >= 2
  end

  defp get_veteran_indicators(participant) do
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_done = Map.get(participant, :damage_done, 0)

    base_indicators = []

    security_indicators =
      if security_status < -5.0 do
        ["Outlaw security status (#{Float.round(security_status, 1)})" | base_indicators]
      else
        base_indicators
      end

    ship_indicators =
      if ship_class in [:capital, :battleship] do
        ["Flies #{ship_class} class ships" | security_indicators]
      else
        security_indicators
      end

    final_indicators =
      if damage_done > 30_000 do
        ["High damage output (#{damage_done})" | ship_indicators]
      else
        ship_indicators
      end

    final_indicators
  end

  defp estimate_skill_points(participant) do
    # Rough estimation of skill points based on ship type
    ship_class = Map.get(participant, :ship_class, :unknown)

    base_sp =
      case ship_class do
        :capital -> 50_000_000
        :battleship -> 20_000_000
        :cruiser -> 10_000_000
        :frigate -> 5_000_000
        _ -> 2_000_000
      end

    # Adjust based on performance
    damage_done = Map.get(participant, :damage_done, 0)
    performance_multiplier = 1 + min(0.5, damage_done / 100_000)

    round(base_sp * performance_multiplier)
  end

  defp rookie?(participant) do
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_done = Map.get(participant, :damage_done, 0)

    # Indicators of rookie status
    high_sec_status = security_status > 4.0
    flies_frigate = ship_class == :frigate
    low_damage = damage_done < 5000

    # Rookie if meets at least 2 criteria
    indicators = [high_sec_status, flies_frigate, low_damage]
    Enum.count(indicators, & &1) >= 2
  end

  defp get_rookie_indicators(participant) do
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_done = Map.get(participant, :damage_done, 0)

    base_indicators = []

    security_indicators =
      if security_status > 4.0 do
        ["High security status (#{Float.round(security_status, 1)})" | base_indicators]
      else
        base_indicators
      end

    ship_indicators =
      if ship_class == :frigate do
        ["Flying basic frigate" | security_indicators]
      else
        security_indicators
      end

    final_indicators =
      if damage_done < 5000 do
        ["Low damage output (#{damage_done})" | ship_indicators]
      else
        ship_indicators
      end

    final_indicators
  end

  defp identify_learning_opportunities(participant) do
    ship_class = Map.get(participant, :ship_class, :unknown)
    damage_done = Map.get(participant, :damage_done, 0)
    survived = Map.get(participant, :participant_type) == :attacker

    base_opportunities = []

    ship_opportunities =
      if ship_class == :frigate do
        ["Progress to cruiser-class ships" | base_opportunities]
      else
        base_opportunities
      end

    damage_opportunities =
      if damage_done < 5000 do
        ["Improve weapon skills and fitting" | ship_opportunities]
      else
        ship_opportunities
      end

    final_opportunities =
      if survived do
        damage_opportunities
      else
        ["Focus on survival and positioning" | damage_opportunities]
      end

    final_opportunities
  end

  defp assess_rookie_risks(participant) do
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)

    base_risks = []

    security_risks =
      if security_status > 4.0 do
        ["May lose security status quickly" | base_risks]
      else
        base_risks
      end

    final_risks =
      if ship_class == :frigate do
        ["Vulnerable to larger ships" | security_risks]
      else
        security_risks
      end

    final_risks
  end

  defp determine_advantage_favor(advantage) do
    cond do
      advantage > 10 -> :attackers
      advantage < -10 -> :defenders
      true -> :balanced
    end
  end

  defp assess_advantage_significance(advantage) do
    abs_advantage = abs(advantage)

    cond do
      abs_advantage > 30 -> :decisive
      abs_advantage > 20 -> :significant
      abs_advantage > 10 -> :moderate
      abs_advantage > 5 -> :slight
      true -> :negligible
    end
  end

  defp calculate_average_experience(participants) do
    if Enum.empty?(participants) do
      0.0
    else
      experience_scores =
        participants
        |> Enum.map(&estimate_participant_experience_score/1)

      Float.round(Enum.sum(experience_scores) / length(experience_scores), 1)
    end
  end

  defp measure_experience_diversity(experience_distribution) do
    levels = Map.keys(experience_distribution)

    cond do
      Enum.empty?(levels) -> 0.0
      true -> calculate_shannon_diversity_index(experience_distribution, levels)
    end
  end

  defp calculate_shannon_diversity_index(experience_distribution, levels) do
    total_count =
      experience_distribution
      |> Map.values()
      |> Enum.map(&Map.get(&1, :count, 0))
      |> Enum.sum()

    if total_count == 0 do
      0.0
    else
      shannon_entropy =
        experience_distribution
        |> Map.values()
        |> Enum.map(&calculate_entropy_contribution(&1, total_count))
        |> Enum.sum()

      shannon_entropy / :math.log(length(levels))
    end
  end

  defp calculate_entropy_contribution(data, total_count) do
    count = Map.get(data, :count, 0)

    if count > 0 do
      p = count / total_count
      -p * :math.log(p)
    else
      0
    end
  end

  defp identify_experience_gaps(veteran_players, rookie_players) do
    vet_count = length(veteran_players)
    rookie_count = length(rookie_players)

    if vet_count > 0 and rookie_count > 0 do
      # Calculate experience gap metrics
      avg_vet_exp = calculate_average_experience_for_group(veteran_players)
      avg_rookie_exp = calculate_average_experience_for_group(rookie_players)

      gap = avg_vet_exp - avg_rookie_exp

      %{
        gap_size: Float.round(gap, 1),
        severity: classify_gap_severity(gap),
        veteran_count: vet_count,
        rookie_count: rookie_count,
        recommendations: generate_gap_recommendations(gap, vet_count, rookie_count)
      }
    else
      %{
        gap_size: 0.0,
        severity: :none,
        veteran_count: vet_count,
        rookie_count: rookie_count,
        recommendations: []
      }
    end
  end

  defp calculate_average_experience_for_group(players) do
    # Since these are already filtered veterans or rookies,
    # we'll use a simplified scoring
    if Enum.empty?(players) do
      0.0
    else
      # Veterans get high score, rookies get low score
      if Map.get(List.first(players), :estimated_sp, 0) > 10_000_000 do
        # Veteran average
        80.0
      else
        # Rookie average
        20.0
      end
    end
  end

  defp classify_gap_severity(gap) do
    cond do
      gap > 60 -> :extreme
      gap > 40 -> :severe
      gap > 20 -> :moderate
      gap > 10 -> :mild
      true -> :minimal
    end
  end

  defp generate_gap_recommendations(gap, vet_count, rookie_count) do
    base_recommendations = []

    matchmaking_recommendations =
      if gap > 40 do
        ["Consider skill-based matchmaking" | base_recommendations]
      else
        base_recommendations
      end

    pilot_recommendations =
      if rookie_count > vet_count * 2 do
        ["Fleet needs more experienced pilots" | matchmaking_recommendations]
      else
        matchmaking_recommendations
      end

    final_recommendations =
      if vet_count > 0 and rookie_count > 0 do
        ["Implement mentorship program" | pilot_recommendations]
      else
        pilot_recommendations
      end

    final_recommendations
  end

  defp identify_mentorship_pairs(veteran_players, rookie_players) do
    if Enum.empty?(veteran_players) or Enum.empty?(rookie_players) do
      []
    else
      # Simple pairing algorithm - match veterans with rookies
      pairs =
        Enum.zip(veteran_players, rookie_players)
        |> Enum.map(fn {veteran, rookie} ->
          %{
            mentor: %{
              id: Map.get(veteran, :character_id),
              name: Map.get(veteran, :character_name)
            },
            mentee: %{
              id: Map.get(rookie, :character_id),
              name: Map.get(rookie, :character_name)
            },
            compatibility: calculate_mentorship_compatibility(veteran, rookie),
            focus_areas: identify_mentorship_focus(veteran, rookie)
          }
        end)
        # Limit to 5 pairs
        |> Enum.take(5)

      %{
        pairs: pairs,
        unmatched_rookies: max(0, length(rookie_players) - length(veteran_players)),
        effectiveness: assess_mentorship_effectiveness(pairs)
      }
    end
  end

  defp calculate_mentorship_compatibility(_veteran, _rookie) do
    # Simplified compatibility score
    # In a real system, this would consider timezone, language, specializations
    # 60-100% compatibility
    :rand.uniform() * 0.4 + 0.6
  end

  defp identify_mentorship_focus(_veteran, rookie) do
    learning_opps = Map.get(rookie, :learning_opportunities, [])

    if Enum.empty?(learning_opps) do
      ["General PvP fundamentals", "Fleet tactics", "Fitting optimization"]
    else
      Enum.take(learning_opps, 3)
    end
  end

  defp assess_mentorship_effectiveness(pairs) do
    avg_compatibility =
      if Enum.empty?(pairs) do
        0.0
      else
        pairs
        |> Enum.map(&Map.get(&1, :compatibility, 0))
        |> Enum.sum()
        |> (fn sum -> sum / length(pairs) end).()
      end

    cond do
      avg_compatibility > 0.8 -> :high
      avg_compatibility > 0.6 -> :moderate
      true -> :low
    end
  end

  defp assess_fleet_maturity(experience_distribution) do
    # Assess overall fleet maturity based on experience distribution
    veteran_count = Map.get(experience_distribution, :veteran, %{}) |> Map.get(:count, 0)
    experienced_count = Map.get(experience_distribution, :experienced, %{}) |> Map.get(:count, 0)

    total_count =
      experience_distribution
      |> Map.values()
      |> Enum.map(&Map.get(&1, :count, 0))
      |> Enum.sum()

    if total_count == 0 do
      :unknown
    else
      mature_ratio = (veteran_count + experienced_count) / total_count

      cond do
        mature_ratio > 0.7 -> :highly_mature
        mature_ratio > 0.5 -> :mature
        mature_ratio > 0.3 -> :developing
        mature_ratio > 0.1 -> :novice
        true -> :rookie_fleet
      end
    end
  end
end
