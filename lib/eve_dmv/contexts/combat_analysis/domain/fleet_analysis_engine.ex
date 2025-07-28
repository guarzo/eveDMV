defmodule EveDmv.Contexts.CombatAnalysis.Domain.FleetAnalysisEngine do
  @moduledoc """
  Engine for fleet composition and effectiveness analysis.

  Provides comprehensive fleet analysis including composition optimization,
  doctrine effectiveness, and tactical recommendations.
  """

  use GenServer
  require Logger

  alias EveDmv.Shared.Infrastructure.UnifiedCache

  # Ship class categories for analysis
  @ship_classes %{
    "frigate" => %{size: :small, role: :tackle},
    "destroyer" => %{size: :small, role: :support},
    "cruiser" => %{size: :medium, role: :dps},
    "battlecruiser" => %{size: :medium, role: :dps},
    "battleship" => %{size: :large, role: :dps},
    "carrier" => %{size: :capital, role: :support},
    "dreadnought" => %{size: :capital, role: :dps},
    "titan" => %{size: :supercapital, role: :dps}
  }

  # Fleet doctrine archetypes
  @doctrine_types %{
    armor_brawler: %{tank: :armor, engagement: :close, mobility: :low},
    shield_kiter: %{tank: :shield, engagement: :long, mobility: :high},
    alpha_strike: %{tank: :shield, engagement: :long, mobility: :medium},
    nano_gang: %{tank: :shield, engagement: :medium, mobility: :very_high}
  }

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyze fleet composition for effectiveness and optimization.
  """
  def analyze_composition(participants, options \\ []) do
    GenServer.call(__MODULE__, {:analyze_composition, participants, options})
  end

  @doc """
  Get ship class information.
  """
  def get_ship_classes() do
    @ship_classes
  end

  @doc """
  Get doctrine type information.
  """
  def get_doctrine_types() do
    @doctrine_types
  end

  @doc """
  Compare two fleet compositions for effectiveness.
  """
  def compare_fleets(fleet_a, fleet_b, options \\ []) do
    GenServer.call(__MODULE__, {:compare_fleets, fleet_a, fleet_b, options})
  end

  @doc """
  Suggest fleet composition improvements.
  """
  def suggest_improvements(composition, constraints \\ []) do
    GenServer.call(__MODULE__, {:suggest_improvements, composition, constraints})
  end

  @doc """
  Analyze fleet performance in battle.
  """
  def analyze_performance(fleet_data, battle_results) do
    GenServer.call(__MODULE__, {:analyze_performance, fleet_data, battle_results})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      analyses_performed: 0,
      composition_cache: %{},
      static_data_loaded: false
    }

    # Load ship static data
    Task.start(fn -> load_ship_static_data() end)

    Logger.info("FleetAnalysisEngine started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:analyze_composition, participants, options}, _from, state) do
    case perform_composition_analysis(participants, options) do
      {:ok, analysis} ->
        {:reply, {:ok, analysis}, %{state | analyses_performed: state.analyses_performed + 1}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:compare_fleets, fleet_a, fleet_b, options}, _from, state) do
    case perform_fleet_comparison(fleet_a, fleet_b, options) do
      {:ok, comparison} ->
        {:reply, {:ok, comparison}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:suggest_improvements, composition, constraints}, _from, state) do
    case generate_improvement_suggestions(composition, constraints) do
      {:ok, suggestions} ->
        {:reply, {:ok, suggestions}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:analyze_performance, fleet_data, battle_results}, _from, state) do
    case analyze_fleet_performance(fleet_data, battle_results) do
      {:ok, performance} ->
        {:reply, {:ok, performance}, state}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  # Private functions

  defp perform_composition_analysis(participants, options) do
    try do
      analysis_type = Keyword.get(options, :analysis_type, :comprehensive)

      composition = analyze_ship_composition(participants)
      doctrine = identify_fleet_doctrine(composition)
      effectiveness = calculate_fleet_effectiveness(composition, doctrine)
      roles = analyze_tactical_roles(participants)
      balance = assess_fleet_balance(composition)

      analysis = %{
        analysis_type: analysis_type,
        analyzed_at: DateTime.utc_now(),
        total_participants: length(participants),
        composition: composition,
        doctrine: doctrine,
        effectiveness: effectiveness,
        tactical_roles: roles,
        fleet_balance: balance,
        strengths: identify_fleet_strengths(composition, doctrine),
        weaknesses: identify_fleet_weaknesses(composition, doctrine),
        recommendations: generate_composition_recommendations(composition, doctrine)
      }

      # Cache the analysis
      cache_key = {:fleet_analysis, :composition, generate_composition_hash(participants)}
      # 30 minutes
      UnifiedCache.cache_combat_analysis(cache_key, analysis, 1800)

      {:ok, analysis}
    rescue
      error ->
        Logger.error("Failed to analyze fleet composition: #{inspect(error)}")
        {:error, :analysis_failed}
    end
  end

  defp perform_fleet_comparison(fleet_a, fleet_b, options) do
    try do
      comparison_type = Keyword.get(options, :comparison_type, :effectiveness)

      analysis_a = perform_composition_analysis(fleet_a, [])
      analysis_b = perform_composition_analysis(fleet_b, [])

      case {analysis_a, analysis_b} do
        {{:ok, comp_a}, {:ok, comp_b}} ->
          comparison = %{
            comparison_type: comparison_type,
            compared_at: DateTime.utc_now(),
            fleet_a: comp_a,
            fleet_b: comp_b,
            effectiveness_comparison:
              compare_effectiveness(comp_a.effectiveness, comp_b.effectiveness),
            doctrine_matchup: analyze_doctrine_matchup(comp_a.doctrine, comp_b.doctrine),
            tactical_advantage: determine_tactical_advantage(comp_a, comp_b),
            recommendations: generate_comparison_recommendations(comp_a, comp_b)
          }

          {:ok, comparison}

        {error_a, _} ->
          error_a

        {_, error_b} ->
          error_b
      end
    rescue
      error ->
        Logger.error("Failed to compare fleets: #{inspect(error)}")
        {:error, :comparison_failed}
    end
  end

  defp generate_improvement_suggestions(composition, constraints) do
    try do
      current_analysis = analyze_ship_composition(composition)
      current_doctrine = identify_fleet_doctrine(current_analysis)

      suggestions = %{
        generated_at: DateTime.utc_now(),
        current_composition: current_analysis,
        current_doctrine: current_doctrine,
        constraints: constraints,
        improvements: []
      }

      # Analyze different improvement areas
      role_improvements = suggest_role_improvements(current_analysis)
      doctrine_improvements = suggest_doctrine_improvements(current_doctrine)
      balance_improvements = suggest_balance_improvements(current_analysis)

      all_improvements = role_improvements ++ doctrine_improvements ++ balance_improvements

      # Filter by constraints and prioritize
      filtered_improvements = filter_suggestions_by_constraints(all_improvements, constraints)
      prioritized_improvements = prioritize_suggestions(filtered_improvements)

      suggestions = %{suggestions | improvements: prioritized_improvements}

      {:ok, suggestions}
    rescue
      error ->
        Logger.error("Failed to generate improvement suggestions: #{inspect(error)}")
        {:error, :suggestion_failed}
    end
  end

  defp analyze_fleet_performance(fleet_data, battle_results) do
    try do
      # Simplified performance analysis using only composition data
      composition = analyze_ship_composition(fleet_data)

      performance = %{
        analyzed_at: DateTime.utc_now(),
        fleet_composition: composition,
        performance_summary: %{
          note: "Detailed battle performance analysis requires battle data infrastructure",
          composition_score: calculate_base_effectiveness(composition)
        },
        recommendations: ["Implement battle data collection for detailed performance analysis"]
      }

      {:ok, performance}
    rescue
      error ->
        Logger.error("Failed to analyze fleet performance: #{inspect(error)}")
        {:error, :performance_analysis_failed}
    end
  end

  # Analysis helper functions

  defp analyze_ship_composition(participants) do
    ship_counts =
      Enum.reduce(participants, %{}, fn participant, acc ->
        ship_type = get_ship_type_name(participant[:ship_type_id] || participant.ship_type_id)
        Map.update(acc, ship_type, 1, &(&1 + 1))
      end)

    total_ships = Enum.sum(Map.values(ship_counts))

    %{
      total_ships: total_ships,
      ship_counts: ship_counts,
      ship_distribution: calculate_ship_distribution(ship_counts, total_ships),
      size_distribution: calculate_size_distribution(ship_counts),
      role_distribution: calculate_role_distribution(ship_counts)
    }
  end

  defp identify_fleet_doctrine(composition) do
    # Analyze ship composition to identify doctrine
    size_dist = composition.size_distribution
    role_dist = composition.role_distribution

    cond do
      size_dist[:large] > 0.6 && role_dist[:dps] > 0.7 ->
        %{type: :armor_brawler, confidence: 0.8, description: "Heavy armor brawling doctrine"}

      size_dist[:medium] > 0.5 && role_dist[:dps] > 0.6 ->
        %{
          type: :shield_kiter,
          confidence: 0.7,
          description: "Medium range shield kiting doctrine"
        }

      size_dist[:small] > 0.7 && role_dist[:tackle] > 0.4 ->
        %{type: :nano_gang, confidence: 0.9, description: "Fast nano gang doctrine"}

      true ->
        %{type: :mixed, confidence: 0.5, description: "Mixed or unclear doctrine"}
    end
  end

  defp calculate_fleet_effectiveness(composition, doctrine) do
    base_effectiveness = calculate_base_effectiveness(composition)
    doctrine_modifier = get_doctrine_effectiveness_modifier(doctrine)
    balance_modifier = get_balance_effectiveness_modifier(composition)

    overall_effectiveness = base_effectiveness * doctrine_modifier * balance_modifier

    %{
      overall_score: Float.round(overall_effectiveness, 3),
      base_effectiveness: Float.round(base_effectiveness, 3),
      doctrine_modifier: Float.round(doctrine_modifier, 3),
      balance_modifier: Float.round(balance_modifier, 3),
      components: %{
        role_diversity: calculate_role_diversity(composition),
        size_distribution_score: calculate_size_distribution_score(composition),
        doctrine_coherence: calculate_doctrine_coherence(composition)
      }
    }
  end

  defp analyze_tactical_roles(participants) do
    roles =
      Enum.reduce(participants, %{}, fn participant, acc ->
        role = determine_ship_role(participant[:ship_type_id] || participant.ship_type_id)
        Map.update(acc, role, 1, &(&1 + 1))
      end)

    total = Enum.sum(Map.values(roles))

    %{
      total_ships: total,
      role_counts: roles,
      role_percentages:
        Enum.map(roles, fn {role, count} ->
          {role, Float.round(count / total * 100, 1)}
        end)
        |> Map.new()
    }
  end

  defp assess_fleet_balance(composition) do
    role_dist = composition.role_distribution

    # Ideal ratios for balanced fleet
    ideal_ratios = %{
      dps: 0.60,
      support: 0.20,
      tackle: 0.15,
      logistics: 0.05
    }

    balance_scores =
      Enum.map(ideal_ratios, fn {role, ideal} ->
        actual = Map.get(role_dist, role, 0.0)
        deviation = abs(actual - ideal)
        score = max(0.0, 1.0 - deviation / ideal)
        {role, score}
      end)
      |> Map.new()

    overall_balance = Enum.sum(Map.values(balance_scores)) / map_size(balance_scores)

    %{
      overall_balance: Float.round(overall_balance, 3),
      role_balance_scores: balance_scores,
      recommendations: generate_balance_recommendations(balance_scores, role_dist)
    }
  end

  # Helper functions for calculations

  defp calculate_ship_distribution(ship_counts, total) do
    Enum.map(ship_counts, fn {ship, count} ->
      {ship, Float.round(count / total, 3)}
    end)
    |> Map.new()
  end

  defp calculate_size_distribution(ship_counts) do
    Enum.reduce(ship_counts, %{}, fn {ship, count}, acc ->
      size = get_ship_size_category(ship)
      Map.update(acc, size, count, &(&1 + count))
    end)
  end

  defp calculate_role_distribution(ship_counts) do
    total = Enum.sum(Map.values(ship_counts))

    Enum.reduce(ship_counts, %{}, fn {ship, count}, acc ->
      role = get_ship_role_category(ship)
      Map.update(acc, role, count / total, &(&1 + count / total))
    end)
  end

  defp get_ship_size_category(ship_name) do
    # Simplified ship size categorization
    cond do
      String.contains?(String.downcase(ship_name), ["frigate", "destroyer"]) -> :small
      String.contains?(String.downcase(ship_name), ["cruiser", "battlecruiser"]) -> :medium
      String.contains?(String.downcase(ship_name), ["battleship"]) -> :large
      String.contains?(String.downcase(ship_name), ["carrier", "dreadnought"]) -> :capital
      String.contains?(String.downcase(ship_name), ["titan", "supercarrier"]) -> :supercapital
      true -> :unknown
    end
  end

  defp get_ship_role_category(ship_name) do
    # Simplified ship role categorization
    cond do
      String.contains?(String.downcase(ship_name), ["interceptor", "assault"]) -> :tackle
      String.contains?(String.downcase(ship_name), ["logistics", "guardian"]) -> :logistics
      String.contains?(String.downcase(ship_name), ["electronic", "blackbird"]) -> :support
      true -> :dps
    end
  end

  # Real implementations using ship static data

  defp load_ship_static_data() do
    # Load ship type data from the static data system
    case EveDmv.Api.read(EveDmv.Eve.ItemType, filter: [published: true]) do
      {:ok, ship_types} ->
        Logger.info("Loaded #{length(ship_types)} ship types for fleet analysis")
        :ok

      error ->
        Logger.warning("Failed to load ship static data: #{inspect(error)}")
        :error
    end
  end

  defp get_ship_type_name(ship_type_id) do
    case EveDmv.Api.read(EveDmv.Eve.ItemType, filter: [type_id: ship_type_id]) do
      {:ok, [ship_type]} -> ship_type.type_name || "Unknown Ship #{ship_type_id}"
      _ -> "Unknown Ship #{ship_type_id}"
    end
  end

  defp determine_ship_role(ship_type_id) do
    ship_name = get_ship_type_name(ship_type_id)
    get_ship_role_category(ship_name)
  end

  defp calculate_base_effectiveness(composition) do
    # Base effectiveness on actual fleet balance and size distribution
    balance_score = composition[:fleet_balance][:overall_balance] || 0.5
    size_variety = map_size(composition[:size_distribution] || %{})
    role_variety = map_size(composition[:role_distribution] || %{})

    # Normalize variety scores (more variety generally better up to a point)
    # Ideal: 4 size categories
    size_score = min(size_variety / 4.0, 1.0)
    # Ideal: 4 role categories
    role_score = min(role_variety / 4.0, 1.0)

    Float.round(balance_score * 0.5 + size_score * 0.25 + role_score * 0.25, 3)
  end

  defp get_doctrine_effectiveness_modifier(doctrine) do
    # Doctrine effectiveness based on confidence
    confidence = doctrine[:confidence] || 0.5

    case doctrine[:type] do
      # Strong doctrine when executed well
      :armor_brawler -> confidence * 0.95
      # Good balanced doctrine
      :shield_kiter -> confidence * 0.90
      # High skill required
      :nano_gang -> confidence * 0.85
      # Situational effectiveness
      :alpha_strike -> confidence * 0.88
      # Unknown/mixed doctrine penalty
      _ -> 0.70
    end
  end

  defp get_balance_effectiveness_modifier(composition) do
    balance_score = composition[:fleet_balance][:overall_balance] || 0.5
    # Scale balance score to effectiveness modifier (0.7 to 1.3 range)
    Float.round(0.7 + balance_score * 0.6, 3)
  end

  defp identify_fleet_strengths(composition, doctrine) do
    strengths = []

    role_dist = composition[:role_distribution] || %{}
    size_dist = composition[:size_distribution] || %{}

    strengths =
      if Map.get(role_dist, :dps, 0) > 0.7 do
        ["High damage potential" | strengths]
      else
        strengths
      end

    strengths =
      if Map.get(role_dist, :logistics, 0) > 0.1 do
        ["Good logistics support" | strengths]
      else
        strengths
      end

    strengths =
      if Map.get(size_dist, :small, 0) > 0.5 do
        ["High mobility" | strengths]
      else
        strengths
      end

    strengths =
      if doctrine[:confidence] && doctrine[:confidence] > 0.8 do
        ["Clear tactical doctrine" | strengths]
      else
        strengths
      end

    if Enum.empty?(strengths), do: ["Balanced composition"], else: strengths
  end

  defp identify_fleet_weaknesses(composition, doctrine) do
    weaknesses = []

    role_dist = composition[:role_distribution] || %{}
    size_dist = composition[:size_distribution] || %{}

    weaknesses =
      if Map.get(role_dist, :logistics, 0) < 0.05 do
        ["Limited logistics support" | weaknesses]
      else
        weaknesses
      end

    weaknesses =
      if Map.get(role_dist, :tackle, 0) < 0.1 do
        ["Insufficient tackle" | weaknesses]
      else
        weaknesses
      end

    weaknesses =
      if Map.get(size_dist, :large, 0) > 0.8 do
        ["Low mobility due to heavy ships" | weaknesses]
      else
        weaknesses
      end

    weaknesses =
      if doctrine[:confidence] && doctrine[:confidence] < 0.6 do
        ["Unclear tactical doctrine" | weaknesses]
      else
        weaknesses
      end

    if Enum.empty?(weaknesses), do: ["No major weaknesses identified"], else: weaknesses
  end

  defp generate_composition_recommendations(composition, doctrine) do
    recommendations = []

    role_dist = composition[:role_distribution] || %{}

    recommendations =
      if Map.get(role_dist, :logistics, 0) < 0.05 do
        ["Add logistics ships for sustainability" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Map.get(role_dist, :tackle, 0) < 0.1 do
        ["Add tackle ships for engagement control" | recommendations]
      else
        recommendations
      end

    recommendations =
      if Map.get(role_dist, :support, 0) < 0.1 do
        ["Consider adding EWAR support ships" | recommendations]
      else
        recommendations
      end

    recommendations =
      if doctrine[:confidence] && doctrine[:confidence] < 0.7 do
        ["Standardize ship types for better doctrine cohesion" | recommendations]
      else
        recommendations
      end

    if Enum.empty?(recommendations),
      do: ["Composition appears well-balanced"],
      else: recommendations
  end

  defp compare_effectiveness(eff_a, eff_b) do
    score_a = eff_a[:overall_score] || 0.5
    score_b = eff_b[:overall_score] || 0.5

    difference = score_a - score_b

    winner =
      cond do
        difference > 0.05 -> :fleet_a
        difference < -0.05 -> :fleet_b
        true -> :even
      end

    %{
      winner: winner,
      advantage: abs(difference),
      score_a: score_a,
      score_b: score_b,
      margin:
        case winner do
          :even -> "Close match"
          _ when abs(difference) > 0.2 -> "Significant advantage"
          _ -> "Moderate advantage"
        end
    }
  end

  defp analyze_doctrine_matchup(doctrine_a, doctrine_b) do
    type_a = doctrine_a[:type] || :mixed
    type_b = doctrine_b[:type] || :mixed

    matchup =
      case {type_a, type_b} do
        {:shield_kiter, :armor_brawler} -> {:favorable, "Range advantage vs slow brawlers"}
        {:armor_brawler, :nano_gang} -> {:favorable, "Tank advantage vs fragile ships"}
        {:nano_gang, :shield_kiter} -> {:favorable, "Speed advantage vs kiters"}
        {:alpha_strike, :armor_brawler} -> {:favorable, "Alpha damage vs slow targets"}
        {same, same} -> {:even, "Mirror matchup"}
        _ -> {:neutral, "Unclear doctrine matchup"}
      end

    {result, description} = matchup

    %{
      matchup: result,
      description: description,
      confidence: (doctrine_a[:confidence] || 0.5) * (doctrine_b[:confidence] || 0.5)
    }
  end

  defp determine_tactical_advantage(comp_a, comp_b) do
    advantages = []

    # Compare role distributions
    role_a = comp_a[:tactical_roles][:role_percentages] || %{}
    role_b = comp_b[:tactical_roles][:role_percentages] || %{}

    advantages =
      if Map.get(role_a, :logistics, 0) > Map.get(role_b, :logistics, 0) + 5 do
        ["Better logistics support" | advantages]
      else
        advantages
      end

    advantages =
      if Map.get(role_a, :tackle, 0) > Map.get(role_b, :tackle, 0) + 5 do
        ["Superior tackle capability" | advantages]
      else
        advantages
      end

    # Compare effectiveness scores
    eff_a = comp_a[:effectiveness][:overall_score] || 0.5
    eff_b = comp_b[:effectiveness][:overall_score] || 0.5

    winner =
      if eff_a > eff_b + 0.05 do
        :fleet_a
      else
        if eff_b > eff_a + 0.05 do
          :fleet_b
        else
          :even
        end
      end

    %{
      advantage: winner,
      factors: if(Enum.empty?(advantages), do: ["No clear advantages"], else: advantages),
      magnitude: abs(eff_a - eff_b)
    }
  end

  defp generate_comparison_recommendations(comp_a, comp_b) do
    recommendations = []

    advantage = determine_tactical_advantage(comp_a, comp_b)
    doctrine_matchup = analyze_doctrine_matchup(comp_a[:doctrine], comp_b[:doctrine])

    recommendations =
      case advantage[:advantage] do
        :fleet_a ->
          ["Leverage #{Enum.join(advantage[:factors], ", ")}" | recommendations]

        :fleet_b ->
          ["Counter opponent's #{Enum.join(advantage[:factors], ", ")}" | recommendations]

        :even ->
          ["Focus on execution and coordination" | recommendations]
      end

    recommendations =
      case doctrine_matchup[:matchup] do
        :favorable ->
          ["Exploit doctrine advantage: #{doctrine_matchup[:description]}" | recommendations]

        :unfavorable ->
          ["Mitigate doctrine disadvantage: #{doctrine_matchup[:description]}" | recommendations]

        _ ->
          recommendations
      end

    if Enum.empty?(recommendations),
      do: ["Evenly matched - focus on tactical execution"],
      else: recommendations
  end

  defp suggest_role_improvements(analysis) do
    role_dist = analysis[:role_distribution] || %{}
    suggestions = []

    suggestions =
      if Map.get(role_dist, :logistics, 0) < 0.05 do
        [
          %{
            type: :add_logistics,
            priority: :high,
            description: "Add logistics ships for fleet sustainability"
          }
        ] ++ suggestions
      else
        suggestions
      end

    suggestions =
      if Map.get(role_dist, :tackle, 0) < 0.1 do
        [
          %{
            type: :add_tackle,
            priority: :medium,
            description: "Add tackle ships for engagement control"
          }
        ] ++ suggestions
      else
        suggestions
      end

    suggestions
  end

  defp suggest_doctrine_improvements(doctrine) do
    suggestions = []

    suggestions =
      if doctrine[:confidence] && doctrine[:confidence] < 0.7 do
        [
          %{
            type: :doctrine_clarity,
            priority: :high,
            description: "Standardize ship types for clearer doctrine"
          }
        ] ++ suggestions
      else
        suggestions
      end

    suggestions
  end

  defp suggest_balance_improvements(analysis) do
    balance = analysis[:fleet_balance] || %{}
    suggestions = []

    if balance[:overall_balance] && balance[:overall_balance] < 0.6 do
      role_scores = balance[:role_balance_scores] || %{}

      # Find the most imbalanced role
      worst_role = Enum.min_by(role_scores, fn {_role, score} -> score end, fn -> nil end)

      suggestions =
        case worst_role do
          {role, _score} ->
            [
              %{
                type: :rebalance_roles,
                priority: :medium,
                description: "Rebalance #{role} ships for better fleet composition"
              }
            ] ++ suggestions

          nil ->
            suggestions
        end
    end

    suggestions
  end

  defp filter_suggestions_by_constraints(suggestions, constraints) do
    # Filter suggestions based on constraints like max_ships, budget, etc.
    max_ships = Keyword.get(constraints, :max_ships, 999)
    allowed_types = Keyword.get(constraints, :allowed_ship_types, :all)

    Enum.filter(suggestions, fn suggestion ->
      # Simple filtering logic - can be expanded
      case {suggestion[:type], allowed_types} do
        {_, :all} -> true
        {:add_logistics, types} when is_list(types) -> :logistics in types
        {:add_tackle, types} when is_list(types) -> :tackle in types
        _ -> true
      end
    end)
  end

  defp prioritize_suggestions(suggestions) do
    # Sort by priority: high > medium > low
    priority_order = %{high: 3, medium: 2, low: 1}

    Enum.sort_by(
      suggestions,
      fn suggestion ->
        Map.get(priority_order, suggestion[:priority], 0)
      end,
      :desc
    )
  end

  defp generate_balance_recommendations(balance_scores, role_dist) do
    recommendations = []

    recommendations =
      if Map.get(balance_scores, :logistics, 1.0) < 0.5 do
        [
          "Add more logistics ships (current: #{Float.round(Map.get(role_dist, :logistics, 0) * 100, 1)}%)"
        ] ++ recommendations
      else
        recommendations
      end

    recommendations =
      if Map.get(balance_scores, :tackle, 1.0) < 0.5 do
        [
          "Add more tackle ships (current: #{Float.round(Map.get(role_dist, :tackle, 0) * 100, 1)}%)"
        ] ++ recommendations
      else
        recommendations
      end

    recommendations =
      if Map.get(balance_scores, :dps, 1.0) < 0.7 do
        ["Consider adding more DPS ships"] ++ recommendations
      else
        recommendations
      end

    if Enum.empty?(recommendations), do: ["Fleet balance appears good"], else: recommendations
  end

  defp generate_composition_hash(participants) do
    # Create a more meaningful hash based on ship types
    ship_types =
      Enum.map(participants, fn p ->
        p[:ship_type_id] || p.ship_type_id || 0
      end)
      |> Enum.sort()

    :erlang.phash2(ship_types)
  end

  # New helper functions for effectiveness components
  defp calculate_role_diversity(composition) do
    role_dist = composition[:role_distribution] || %{}
    role_count = map_size(role_dist)

    # Higher diversity up to 4 roles is better
    Float.round(min(role_count / 4.0, 1.0), 3)
  end

  defp calculate_size_distribution_score(composition) do
    size_dist = composition[:size_distribution] || %{}
    size_count = map_size(size_dist)

    # Balanced size distribution is better
    if size_count == 0 do
      0.0
    else
      # Calculate how evenly distributed the sizes are
      total_ships = Enum.sum(Map.values(size_dist))
      expected_per_size = total_ships / size_count

      deviations =
        Enum.map(size_dist, fn {_size, count} ->
          abs(count - expected_per_size) / expected_per_size
        end)

      avg_deviation = Enum.sum(deviations) / length(deviations)
      Float.round(max(0.0, 1.0 - avg_deviation), 3)
    end
  end

  defp calculate_doctrine_coherence(composition) do
    # Simple coherence based on how concentrated the ship types are
    ship_counts = composition[:ship_counts] || %{}
    total_ships = composition[:total_ships] || 1

    if total_ships == 0 do
      0.0
    else
      # Higher concentration of similar ships = higher coherence
      max_concentration =
        if map_size(ship_counts) > 0 do
          Enum.max(Map.values(ship_counts)) / total_ships
        else
          0.0
        end

      Float.round(max_concentration, 3)
    end
  end
end
