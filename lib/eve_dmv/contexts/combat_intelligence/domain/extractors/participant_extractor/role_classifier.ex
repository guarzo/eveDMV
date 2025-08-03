defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.RoleClassifier do
  @compile {:nowarn_unused_function}
  @moduledoc """
  Classifies participant roles based on ship types and combat patterns.

  Analyzes ship classes, weapon types, and engagement patterns to determine
  tactical roles like DPS, logistics, tackle, etc.
  """

  require Logger

  @doc """
  Analyze participant roles in a battle.
  """
  def analyze_participant_roles(participants) do
    Logger.debug("Analyzing participant roles")

    # Perform comprehensive role analysis based on ship types and combat patterns
    role_distribution =
      participants
      |> Enum.group_by(&classify_participant_role/1)
      |> Enum.map(fn {role, role_participants} ->
        {role,
         %{
           count: length(role_participants),
           effectiveness: calculate_role_effectiveness(role_participants),
           key_players: identify_key_players(role_participants),
           survival_rate: calculate_role_survival_rate(role_participants),
           average_experience: calculate_average_role_experience(role_participants)
         }}
      end)
      |> Enum.into(%{})

    role_balance = analyze_role_balance(role_distribution)
    missing_roles = identify_missing_roles(role_distribution)
    role_synergies = analyze_role_synergies(role_distribution)

    %{
      role_distribution: role_distribution,
      role_balance: role_balance,
      missing_roles: missing_roles,
      role_synergies: role_synergies,
      summary: %{
        primary_doctrine: identify_primary_doctrine(role_distribution),
        role_diversity: calculate_role_diversity(role_distribution),
        doctrine_coherence: assess_doctrine_coherence(role_distribution),
        tactical_completeness: evaluate_tactical_completeness(role_distribution, missing_roles)
      }
    }
  end

  @doc """
  Classify a participant's tactical role.
  """
  def classify_participant_role(participant) do
    ship_type_id = Map.get(participant, :ship_type_id)
    weapon_type_id = Map.get(participant, :weapon_type_id)
    ship_name = Map.get(participant, :ship_name, "")

    # First try to classify by ship name patterns
    role_from_name = determine_tactical_role(ship_name)

    if role_from_name != :unknown do
      role_from_name
    else
      # Fallback to ship type and weapon classification
      determine_tactical_role_from_ship_and_weapon(ship_type_id, weapon_type_id)
    end
  end

  @doc """
  Determine tactical role from ship name.
  """
  def determine_tactical_role(ship_name) when is_binary(ship_name) do
    ship_lower = String.downcase(ship_name)

    cond do
      String.contains?(ship_lower, ["logi", "guardian", "basilisk", "oneiros", "scimitar"]) ->
        :logistics

      String.contains?(ship_lower, ["tackle", "interceptor", "dictor", "hictor"]) ->
        :tackle

      String.contains?(ship_lower, ["recon", "falcon", "rook", "arazu", "lachesis"]) ->
        :ewar

      String.contains?(ship_lower, ["command", "eos", "claymore", "vulture", "damnation"]) ->
        :command

      String.contains?(ship_lower, ["bomber", "hound", "manticore", "nemesis", "purifier"]) ->
        :bomber

      true ->
        :unknown
    end
  end

  def determine_tactical_role(_), do: :unknown

  @doc """
  Calculate effectiveness of participants in a role.
  """
  def calculate_role_effectiveness(role_participants) do
    if Enum.empty?(role_participants) do
      0.0
    else
      # Calculate effectiveness based on various factors
      damage_efficiency = calculate_damage_efficiency(role_participants)
      survival_rate = calculate_survival_rate(role_participants)
      kill_participation = calculate_kill_participation(role_participants)

      # Weight factors based on role importance
      weighted_score =
        damage_efficiency * 0.4 +
          survival_rate * 0.3 +
          kill_participation * 0.3

      %{
        overall: Float.round(weighted_score, 2),
        damage_efficiency: Float.round(damage_efficiency, 2),
        survival_rate: Float.round(survival_rate, 2),
        kill_participation: Float.round(kill_participation, 2),
        rating: categorize_effectiveness(weighted_score)
      }
    end
  end

  @doc """
  Identify key players in each role.
  """
  def identify_key_players(role_participants) do
    # Score each participant based on their performance metrics
    scored_participants =
      role_participants
      |> Enum.map(fn participant ->
        score = calculate_player_performance_score(participant)
        {participant, score}
      end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      # Top 5 players
      |> Enum.take(5)

    # Convert to structured output
    Enum.map(scored_participants, fn {participant, score} ->
      %{
        character_id: Map.get(participant, :character_id),
        character_name: Map.get(participant, :character_name),
        corporation_name: Map.get(participant, :corporation_name),
        ship_name: Map.get(participant, :ship_name),
        performance_score: Float.round(score, 2),
        damage_done: Map.get(participant, :damage_done, 0),
        final_blows: if(Map.get(participant, :final_blow, false), do: 1, else: 0),
        survived: Map.get(participant, :participant_type) == :attacker
      }
    end)
  end

  @doc """
  Analyze balance between different roles.
  """
  def analyze_role_balance(role_distribution) do
    total_participants =
      role_distribution
      |> Map.values()
      |> Enum.map(&Map.get(&1, :count, 0))
      |> Enum.sum()

    if total_participants == 0 do
      %{
        status: :no_participants,
        recommendations: []
      }
    else
      # Calculate role percentages
      role_percentages =
        Enum.map(role_distribution, fn {role, data} ->
          percentage = Map.get(data, :count, 0) / total_participants * 100
          {role, Float.round(percentage, 1)}
        end)
        |> Enum.into(%{})

      # Assess balance
      balance_status = assess_balance_status(role_percentages, total_participants)
      recommendations = generate_balance_recommendations(role_percentages, total_participants)

      %{
        status: balance_status,
        role_percentages: role_percentages,
        total_participants: total_participants,
        recommendations: recommendations,
        fleet_composition_type: determine_fleet_composition_type(role_percentages)
      }
    end
  end

  @doc """
  Identify missing critical roles.
  """
  def identify_missing_roles(role_distribution) do
    # Define critical roles by fleet size
    fleet_size =
      role_distribution
      |> Map.values()
      |> Enum.map(&Map.get(&1, :count, 0))
      |> Enum.sum()

    critical_roles = get_critical_roles_for_fleet_size(fleet_size)
    existing_roles = Map.keys(role_distribution)

    missing =
      critical_roles
      |> Enum.filter(fn role -> role not in existing_roles end)
      |> Enum.map(fn role ->
        %{
          role: role,
          importance: get_role_importance(role),
          reason: get_role_missing_reason(role, fleet_size)
        }
      end)

    %{
      missing_roles: missing,
      fleet_vulnerability: assess_fleet_vulnerability(missing),
      recommendations: generate_role_recommendations(missing, fleet_size)
    }
  end

  @doc """
  Analyze synergies between roles.
  """
  def analyze_role_synergies(role_distribution) do
    # Check for common role combinations that work well together
    existing_roles = Map.keys(role_distribution)

    synergies =
      existing_roles
      |> find_role_synergies()
      |> Enum.map(fn {role_a, role_b, synergy_type} ->
        %{
          roles: [role_a, role_b],
          synergy_type: synergy_type,
          effectiveness_bonus: get_synergy_bonus(synergy_type),
          description: describe_synergy(role_a, role_b, synergy_type)
        }
      end)

    anti_synergies = find_role_conflicts(existing_roles)

    %{
      positive_synergies: synergies,
      conflicts: anti_synergies,
      overall_synergy_score: calculate_overall_synergy_score(synergies, anti_synergies),
      tactical_coherence: assess_tactical_coherence(existing_roles)
    }
  end

  # Private functions

  defp determine_tactical_role_from_ship_and_weapon(ship_type_id, weapon_type_id) do
    # Use actual EVE ship type data for classification
    ship_class = EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id)

    case ship_class do
      :frigate -> classify_frigate_role_by_attributes(ship_type_id, weapon_type_id)
      :destroyer -> classify_destroyer_role_by_attributes(ship_type_id, weapon_type_id)
      :cruiser -> classify_cruiser_role_by_attributes(ship_type_id, weapon_type_id)
      :battlecruiser -> classify_battlecruiser_role_by_attributes(ship_type_id, weapon_type_id)
      :battleship -> classify_battleship_role_by_attributes(ship_type_id, weapon_type_id)
      :capital -> classify_capital_role_by_attributes(ship_type_id)
      :supercapital -> classify_supercapital_role_by_attributes(ship_type_id)
      # Default for unknown ship types
      _ -> :dps
    end
  end

  defp classify_frigate_role_by_attributes(ship_type_id, _weapon_type_id) do
    # Get ship attributes to determine frigate role
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        # Use actual ship attributes for classification
        cond do
          # High scan res = tackle
          Map.get(attributes, :scan_resolution, 0) > 800 -> :tackle
          # Small sig = ewar/recon
          Map.get(attributes, :signature_radius, 50) < 30 -> :ewar
          # Fast = tackle
          Map.get(attributes, :max_velocity, 0) > 500 -> :tackle
          # Default frigate role
          true -> :dps
        end

      _ ->
        # Fallback if attributes unavailable
        :dps
    end
  end

  defp classify_destroyer_role_by_attributes(ship_type_id, _weapon_type_id) do
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        # Destroyers are typically DPS or specialized tackle (interdictors)
        if Map.get(attributes, :warp_disrupt_field_range, 0) > 0 do
          # Interdictor
          :tackle
        else
          # Standard destroyer
          :dps
        end

      _ ->
        :dps
    end
  end

  defp classify_cruiser_role_by_attributes(ship_type_id, _weapon_type_id) do
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        cond do
          # Remote reps = logi
          Map.get(attributes, :remote_repair_amount, 0) > 0 -> :logistics
          # High scan = recon
          Map.get(attributes, :scan_strength, 0) > 25 -> :ewar
          # Command bursts = command ship
          Map.get(attributes, :command_burst_range, 0) > 0 -> :command
          # HAC = DPS
          Map.get(attributes, :heavy_assault_damage, 0) > 0 -> :dps
          # Default cruiser role
          true -> :dps
        end

      _ ->
        :dps
    end
  end

  defp classify_battlecruiser_role_by_attributes(ship_type_id, _weapon_type_id) do
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        if Map.get(attributes, :command_burst_range, 0) > 0 do
          # Command battlecruiser
          :command
        else
          # Standard battlecruiser
          :dps
        end

      _ ->
        :dps
    end
  end

  defp classify_battleship_role_by_attributes(ship_type_id, _weapon_type_id) do
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        cond do
          # Logistics battleship
          Map.get(attributes, :remote_repair_amount, 0) > 500 -> :logistics
          # Marauder
          Map.get(attributes, :marauder_bastion_mode, false) -> :dps
          # Standard battleship
          true -> :dps
        end

      _ ->
        :dps
    end
  end

  defp classify_capital_role_by_attributes(ship_type_id) do
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        cond do
          # Force Auxiliary
          Map.get(attributes, :capital_remote_repair, 0) > 0 -> :fax
          # Carrier
          Map.get(attributes, :fighter_capacity, 0) > 0 -> :carrier
          # Dreadnought
          Map.get(attributes, :doomsday_weapon, false) -> :dreadnought
          # Jump Freighter
          Map.get(attributes, :jump_drive_range, 0) > 0 -> :jump_freighter
          # Generic capital
          true -> :capital
        end

      _ ->
        :capital
    end
  end

  defp classify_supercapital_role_by_attributes(ship_type_id) do
    case EveDmv.StaticData.ShipTypes.get_ship_attributes(ship_type_id) do
      {:ok, attributes} ->
        cond do
          # Supercarrier
          Map.get(attributes, :supercarrier_fighters, 0) > 0 -> :supercarrier
          # Titan
          Map.get(attributes, :titan_doomsday, false) -> :titan
          # Mothership
          Map.get(attributes, :mothership_role, false) -> :mothership
          # Generic supercapital
          true -> :supercapital
        end

      _ ->
        :supercapital
    end
  end

  defp calculate_damage_efficiency(participants) do
    total_damage =
      participants
      |> Enum.map(&Map.get(&1, :damage_done, 0))
      |> Enum.sum()

    participant_count = length(participants)

    if participant_count > 0 do
      avg_damage = total_damage / participant_count
      # Normalize to 0-1 scale
      min(1.0, avg_damage / 50_000)
    else
      0.0
    end
  end

  defp calculate_survival_rate(participants) do
    survivors = Enum.count(participants, &(Map.get(&1, :participant_type) == :attacker))
    total = length(participants)

    if total > 0 do
      survivors / total
    else
      0.0
    end
  end

  defp calculate_kill_participation(participants) do
    with_damage = Enum.count(participants, &(Map.get(&1, :damage_done, 0) > 0))
    total = length(participants)

    if total > 0 do
      with_damage / total
    else
      0.0
    end
  end

  defp categorize_effectiveness(score) do
    cond do
      score >= 0.8 -> :excellent
      score >= 0.6 -> :good
      score >= 0.4 -> :average
      score >= 0.2 -> :poor
      true -> :very_poor
    end
  end

  defp calculate_player_performance_score(participant) do
    damage_done = Map.get(participant, :damage_done, 0)
    final_blow = if(Map.get(participant, :final_blow, false), do: 10_000, else: 0)
    survived = if(Map.get(participant, :participant_type) == :attacker, do: 5000, else: 0)

    damage_done + final_blow + survived
  end

  defp calculate_role_survival_rate(role_participants) do
    if Enum.empty?(role_participants) do
      0.0
    else
      survivors = Enum.count(role_participants, &(Map.get(&1, :participant_type) == :attacker))
      Float.round(survivors / length(role_participants), 2)
    end
  end

  defp calculate_average_role_experience(role_participants) do
    if Enum.empty?(role_participants) do
      0.0
    else
      experience_scores =
        role_participants
        |> Enum.map(&estimate_participant_experience/1)
        |> Enum.filter(&(&1 > 0))

      if Enum.empty?(experience_scores) do
        0.0
      else
        Float.round(Enum.sum(experience_scores) / length(experience_scores), 1)
      end
    end
  end

  defp estimate_participant_experience(participant) do
    # Simple experience estimation based on security status and ship class
    security_status = Map.get(participant, :security_status, 0.0)
    ship_class = Map.get(participant, :ship_class, :unknown)

    base_score =
      cond do
        security_status < -5.0 -> 80
        security_status < -2.0 -> 60
        security_status < 0.0 -> 40
        true -> 20
      end

    ship_bonus =
      case ship_class do
        :capital -> 20
        :battleship -> 15
        :cruiser -> 10
        :frigate -> 5
        _ -> 0
      end

    base_score + ship_bonus
  end

  defp assess_balance_status(role_percentages, total_participants) do
    dps_percent = Map.get(role_percentages, :dps, 0)
    logi_percent = Map.get(role_percentages, :logistics, 0)
    tackle_percent = Map.get(role_percentages, :tackle, 0)

    cond do
      total_participants < 5 ->
        :too_small_to_assess

      dps_percent > 80 ->
        :dps_heavy

      logi_percent < 5 and total_participants > 10 ->
        :needs_logistics

      tackle_percent < 5 and total_participants > 10 ->
        :needs_tackle

      dps_percent >= 40 and dps_percent <= 60 and logi_percent >= 10 and tackle_percent >= 10 ->
        :well_balanced

      true ->
        :suboptimal
    end
  end

  defp generate_balance_recommendations(role_percentages, total_participants) do
    dps_percent = Map.get(role_percentages, :dps, 0)
    logi_percent = Map.get(role_percentages, :logistics, 0)
    tackle_percent = Map.get(role_percentages, :tackle, 0)

    base_recommendations = []

    logi_recommendations =
      if logi_percent < 10 and total_participants > 10 do
        [
          "Add more logistics pilots (current: #{logi_percent}%, recommended: 15-20%)"
          | base_recommendations
        ]
      else
        base_recommendations
      end

    tackle_recommendations =
      if tackle_percent < 10 and total_participants > 10 do
        [
          "Add more tackle/interdiction (current: #{tackle_percent}%, recommended: 10-15%)"
          | logi_recommendations
        ]
      else
        logi_recommendations
      end

    final_recommendations =
      if dps_percent > 70 do
        [
          "Consider more balanced composition (current DPS: #{dps_percent}%, recommended: 50-60%)"
          | tackle_recommendations
        ]
      else
        tackle_recommendations
      end

    final_recommendations
  end

  defp determine_fleet_composition_type(role_percentages) do
    dps = Map.get(role_percentages, :dps, 0)
    logi = Map.get(role_percentages, :logistics, 0)
    tackle = Map.get(role_percentages, :tackle, 0)
    ewar = Map.get(role_percentages, :ewar, 0)

    cond do
      dps > 70 -> :alpha_doctrine
      logi > 25 -> :heavy_armor
      tackle > 30 -> :skirmish_doctrine
      ewar > 20 -> :electronic_warfare_doctrine
      dps >= 40 and dps <= 60 and logi >= 15 -> :balanced_doctrine
      true -> :mixed_doctrine
    end
  end

  defp get_critical_roles_for_fleet_size(fleet_size) do
    cond do
      fleet_size < 5 ->
        [:dps, :tackle]

      fleet_size < 15 ->
        [:dps, :tackle, :logistics]

      fleet_size < 30 ->
        [:dps, :tackle, :logistics, :ewar]

      fleet_size < 50 ->
        [:dps, :tackle, :logistics, :ewar, :command]

      true ->
        [:dps, :tackle, :logistics, :ewar, :command, :capital]
    end
  end

  defp get_role_importance(role) do
    case role do
      :logistics -> :critical
      :tackle -> :high
      :dps -> :high
      :ewar -> :moderate
      :command -> :moderate
      :capital -> :situational
      _ -> :low
    end
  end

  defp get_role_missing_reason(role, fleet_size) do
    case role do
      :logistics ->
        "Fleet lacks healing capability - high risk of cascading losses"

      :tackle ->
        "No tackle means enemies can disengage at will"

      :ewar ->
        "Missing electronic warfare reduces tactical options"

      :command ->
        if fleet_size > 30 do
          "Large fleet without command ships lacks coordination bonuses"
        else
          "Command ships provide valuable fleet bonuses"
        end

      _ ->
        "Role would enhance fleet effectiveness"
    end
  end

  defp assess_fleet_vulnerability(missing_roles) do
    critical_missing =
      Enum.count(missing_roles, fn %{importance: imp} -> imp in [:critical, :high] end)

    cond do
      critical_missing >= 2 -> :severe
      critical_missing == 1 -> :moderate
      true -> :low
    end
  end

  defp generate_role_recommendations(missing_roles, _fleet_size) do
    missing_roles
    |> Enum.filter(fn %{importance: imp} -> imp in [:critical, :high] end)
    |> Enum.map(fn %{role: role, reason: reason} ->
      "Add #{role} pilots: #{reason}"
    end)
    |> Enum.take(3)
  end

  defp find_role_synergies(existing_roles) do
    synergy_pairs = [
      {:tackle, :dps, :focus_fire},
      {:logistics, :dps, :sustained_damage},
      {:ewar, :tackle, :target_control},
      {:command, :logistics, :enhanced_reps},
      {:capital, :subcap_support, :force_multiplication}
    ]

    synergy_pairs
    |> Enum.filter(fn {role_a, role_b, _} ->
      role_a in existing_roles and role_b in existing_roles
    end)
  end

  defp get_synergy_bonus(synergy_type) do
    case synergy_type do
      :focus_fire -> 1.2
      :sustained_damage -> 1.3
      :target_control -> 1.15
      :enhanced_reps -> 1.25
      :force_multiplication -> 1.5
      _ -> 1.0
    end
  end

  defp describe_synergy(role_a, role_b, synergy_type) do
    case synergy_type do
      :focus_fire ->
        "#{role_a} holds targets for #{role_b} to eliminate efficiently"

      :sustained_damage ->
        "#{role_a} keeps #{role_b} pilots alive for prolonged engagement"

      :target_control ->
        "#{role_a} and #{role_b} work together to control enemy movement"

      :enhanced_reps ->
        "#{role_a} boosts #{role_b} effectiveness significantly"

      :force_multiplication ->
        "#{role_a} and #{role_b} create overwhelming firepower"

      _ ->
        "Roles complement each other"
    end
  end

  defp find_role_conflicts(existing_roles) do
    _conflict_pairs = [
      {:all_dps, "No support roles - glass cannon fleet"},
      {:no_tackle, "Cannot control engagement range"},
      {:capital_no_support, "Capitals vulnerable without subcap support"}
    ]

    base_conflicts = []

    dps_conflicts =
      if :dps in existing_roles and length(existing_roles) == 1 do
        [{:all_dps, "No support roles - glass cannon fleet"} | base_conflicts]
      else
        base_conflicts
      end

    final_conflicts =
      if :capital in existing_roles and :subcap_support not in existing_roles do
        [{:capital_no_support, "Capitals vulnerable without subcap support"} | dps_conflicts]
      else
        dps_conflicts
      end

    Enum.map(final_conflicts, fn {type, description} ->
      %{
        conflict_type: type,
        description: description,
        severity: :high
      }
    end)
  end

  defp calculate_overall_synergy_score(synergies, conflicts) do
    synergy_bonus =
      synergies
      |> Enum.map(&Map.get(&1, :effectiveness_bonus, 1.0))
      |> Enum.reduce(1.0, &*/2)

    conflict_penalty = length(conflicts) * 0.1

    max(0.0, synergy_bonus - conflict_penalty)
  end

  defp assess_tactical_coherence(existing_roles) do
    role_count = length(existing_roles)

    has_core_roles =
      [:dps, :logistics, :tackle]
      |> Enum.all?(&(&1 in existing_roles))

    cond do
      role_count >= 4 and has_core_roles -> :excellent
      role_count >= 3 and :dps in existing_roles and :logistics in existing_roles -> :good
      role_count >= 2 and :dps in existing_roles -> :acceptable
      role_count == 1 -> :poor
      true -> :none
    end
  end

  defp identify_primary_doctrine(role_distribution) do
    # Identify the primary doctrine based on role composition
    role_counts =
      Enum.map(role_distribution, fn {role, data} ->
        {role, Map.get(data, :count, 0)}
      end)
      |> Enum.into(%{})

    total = Map.values(role_counts) |> Enum.sum()

    if total == 0 do
      :unknown
    else
      # Check for specific doctrine patterns
      cond do
        Map.get(role_counts, :bomber, 0) / total > 0.5 ->
          :bomber_doctrine

        Map.get(role_counts, :capital, 0) / total > 0.3 ->
          :capital_doctrine

        Map.get(role_counts, :logistics, 0) / total > 0.25 ->
          :heavy_armor_doctrine

        Map.get(role_counts, :tackle, 0) / total > 0.3 ->
          :skirmish_doctrine

        true ->
          :mixed_doctrine
      end
    end
  end

  defp calculate_role_diversity(role_distribution) do
    role_count = map_size(role_distribution)

    if role_count == 0 do
      0.0
    else
      calculate_role_shannon_diversity(role_distribution, role_count)
    end
  end

  defp calculate_role_shannon_diversity(role_distribution, role_count) do
    total_participants =
      role_distribution
      |> Map.values()
      |> Enum.map(&Map.get(&1, :count, 0))
      |> Enum.sum()

    if total_participants == 0 do
      0.0
    else
      shannon_entropy =
        role_distribution
        |> Map.values()
        |> Enum.map(&calculate_role_entropy_contribution(&1, total_participants))
        |> Enum.sum()

      shannon_entropy / :math.log(role_count)
    end
  end

  defp calculate_role_entropy_contribution(data, total_participants) do
    count = Map.get(data, :count, 0)

    if count > 0 do
      p = count / total_participants
      -p * :math.log(p)
    else
      0
    end
  end

  defp assess_doctrine_coherence(role_distribution) do
    # Assess how well the roles work together as a doctrine
    roles = Map.keys(role_distribution)

    coherence_score =
      cond do
        # Perfect fleet composition
        MapSet.subset?(
          MapSet.new([:dps, :logistics, :tackle, :ewar]),
          MapSet.new(roles)
        ) ->
          1.0

        # Good composition
        MapSet.subset?(
          MapSet.new([:dps, :logistics, :tackle]),
          MapSet.new(roles)
        ) ->
          0.8

        # Basic composition
        MapSet.subset?(
          MapSet.new([:dps, :tackle]),
          MapSet.new(roles)
        ) ->
          0.6

        # DPS only
        :dps in roles ->
          0.4

        true ->
          0.2
      end

    %{
      score: Float.round(coherence_score, 2),
      rating: categorize_coherence(coherence_score),
      missing_elements: identify_missing_doctrine_elements(roles)
    }
  end

  defp categorize_coherence(score) do
    cond do
      score >= 0.8 -> :excellent
      score >= 0.6 -> :good
      score >= 0.4 -> :fair
      true -> :poor
    end
  end

  defp identify_missing_doctrine_elements(existing_roles) do
    ideal_roles = [:dps, :logistics, :tackle, :ewar, :command]

    ideal_roles -- existing_roles
  end

  defp evaluate_tactical_completeness(role_distribution, missing_roles) do
    existing_count = map_size(role_distribution)

    missing_critical =
      Enum.count(missing_roles.missing_roles, fn %{importance: imp} ->
        imp in [:critical, :high]
      end)

    completeness_score =
      if existing_count + not Enum.empty?(missing_roles.missing_roles) do
        existing_count / (existing_count + missing_critical)
      else
        0.0
      end

    %{
      score: Float.round(completeness_score, 2),
      rating: categorize_completeness(completeness_score),
      critical_gaps: missing_critical
    }
  end

  defp categorize_completeness(score) do
    cond do
      score >= 0.9 -> :complete
      score >= 0.7 -> :mostly_complete
      score >= 0.5 -> :partially_complete
      true -> :incomplete
    end
  end
end
