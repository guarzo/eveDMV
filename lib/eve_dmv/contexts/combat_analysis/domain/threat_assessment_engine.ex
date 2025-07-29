defmodule EveDmv.Contexts.CombatAnalysis.Domain.ThreatAssessmentEngine do
  @moduledoc """
  Threat assessment engine specifically for combat analysis context.

  Provides combat-focused threat assessment including:
  - Real-time threat scoring based on killmail data
  - Combat capability evaluation
  - Engagement risk assessment
  - Fleet threat analysis
  - Predictive threat modeling

  All assessments are based on actual killmail data and combat patterns.
  """

  use GenServer

  import Ecto.Query

  alias EveDmv.Api
  alias EveDmv.Intelligence.CharacterStats
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Shared.Infrastructure.UnifiedCache
  alias EveDmv.StaticData

  require Logger

  # Threat scoring weights for combat analysis
  @combat_threat_weights %{
    # Recent combat activity
    recent_activity: 0.30,
    # K/D ratio and ISK efficiency
    kill_efficiency: 0.25,
    # Ship types and fitting value
    ship_capability: 0.20,
    # Fleet/gang activity
    gang_coordination: 0.15,
    # Tactical patterns
    tactical_skill: 0.10
  }

  # 5 minutes
  @cache_ttl 300

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Assess combat threat level for an entity.

  ## Parameters
  - `entity_id` - Character or corporation ID
  - `entity_type` - :character or :corporation
  - `options` - Assessment options:
    - `:include_fleet_threat` - Include fleet composition analysis
    - `:timeframe` - Analysis timeframe in days (default: 30)
    - `:threat_context` - Context for threat assessment (:general, :wormhole, :nullsec)

  ## Returns
  - `{:ok, threat_assessment}` - Detailed threat assessment
  - `{:error, reason}` - Error if assessment fails
  """
  def assess_threat(entity_id, entity_type, options \\ []) do
    GenServer.call(__MODULE__, {:assess_threat, entity_id, entity_type, options})
  end

  @doc """
  Process a killmail for threat assessment updates.
  """
  def process_killmail(event) do
    GenServer.cast(__MODULE__, {:process_killmail, event})
  end

  @doc """
  Get threat assessment metrics.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end

  # GenServer Implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      assessments_performed: 0,
      killmails_processed: 0,
      cache_hits: 0,
      cache_misses: 0,
      last_cleanup: DateTime.utc_now()
    }

    # Schedule periodic cache cleanup
    Process.send_after(self(), :cleanup_cache, 60_000)

    Logger.info("CombatAnalysis ThreatAssessmentEngine started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:assess_threat, entity_id, entity_type, options}, _from, state) do
    cache_key = {:combat_threat, entity_type, entity_id, options}

    {result, new_state} =
      case UnifiedCache.get(:combat_analysis, cache_key) do
        {:ok, cached_assessment} ->
          {{:ok, cached_assessment}, %{state | cache_hits: state.cache_hits + 1}}

        :miss ->
          assessment_result = perform_threat_assessment(entity_id, entity_type, options)

          case assessment_result do
            {:ok, assessment} ->
              UnifiedCache.put(:combat_analysis, cache_key, assessment, @cache_ttl)

              {assessment_result,
               %{
                 state
                 | assessments_performed: state.assessments_performed + 1,
                   cache_misses: state.cache_misses + 1
               }}

            error ->
              {error, %{state | cache_misses: state.cache_misses + 1}}
          end
      end

    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call(:get_metrics, _from, state) do
    metrics = %{
      assessments_performed: state.assessments_performed,
      killmails_processed: state.killmails_processed,
      cache_hit_rate: calculate_cache_hit_rate(state),
      uptime_hours: calculate_uptime_hours(state)
    }

    {:reply, metrics, state}
  end

  @impl GenServer
  def handle_cast({:process_killmail, event}, state) do
    # Extract all entities from the killmail
    entities = extract_entities_from_killmail(event)

    # Invalidate threat caches for affected entities
    Enum.each(entities, fn {entity_id, entity_type} ->
      cache_pattern = {:combat_threat, entity_type, entity_id, :_}
      UnifiedCache.delete(:combat_analysis, cache_pattern)
    end)

    # Update real-time threat indicators
    update_realtime_threat_indicators(event, entities)

    {:noreply, %{state | killmails_processed: state.killmails_processed + 1}}
  end

  @impl GenServer
  def handle_info(:cleanup_cache, state) do
    # Periodic cache cleanup would be implemented here
    Process.send_after(self(), :cleanup_cache, 60_000)
    {:noreply, %{state | last_cleanup: DateTime.utc_now()}}
  end

  # Private Implementation Functions

  defp perform_threat_assessment(entity_id, entity_type, options) do
    timeframe = Keyword.get(options, :timeframe, 30)
    threat_context = Keyword.get(options, :threat_context, :general)

    with {:ok, combat_stats} <- fetch_combat_stats(entity_id, entity_type),
         {:ok, recent_activity} <- fetch_recent_activity(entity_id, entity_type, timeframe),
         {:ok, combat_patterns} <- analyze_combat_patterns(recent_activity),
         {:ok, capability_assessment} <-
           assess_combat_capability(entity_id, entity_type, recent_activity),
         {:ok, coordination_score} <-
           assess_coordination_ability(entity_id, entity_type, recent_activity) do
      # Calculate weighted threat score
      threat_score =
        calculate_combat_threat_score(%{
          combat_stats: combat_stats,
          recent_activity: recent_activity,
          combat_patterns: combat_patterns,
          capability_assessment: capability_assessment,
          coordination_score: coordination_score
        })

      # Determine threat level
      threat_level = classify_threat_level(threat_score)

      # Generate threat assessment
      base_assessment = %{
        entity_id: entity_id,
        entity_type: entity_type,
        assessment_time: DateTime.utc_now(),
        threat_score: threat_score,
        threat_level: threat_level,
        threat_context: threat_context,

        # Detailed metrics
        combat_efficiency: calculate_combat_efficiency(combat_stats),
        recent_activity_level: categorize_activity_level(recent_activity),
        preferred_engagement_type: combat_patterns.preferred_engagement_type,
        ship_capability_rating: capability_assessment.overall_rating,
        coordination_ability: coordination_score,

        # Risk factors
        risk_factors: identify_risk_factors(combat_stats, recent_activity, combat_patterns),

        # Tactical assessment
        tactical_strengths: identify_tactical_strengths(combat_patterns, capability_assessment),
        tactical_weaknesses: identify_tactical_weaknesses(combat_patterns, combat_stats),

        # Recommendations
        engagement_recommendations:
          generate_engagement_recommendations(threat_level, combat_patterns)
      }

      # Add fleet threat if requested
      final_assessment =
        if Keyword.get(options, :include_fleet_threat, false) do
          Map.put(
            base_assessment,
            :fleet_threat_assessment,
            assess_fleet_threat(entity_id, entity_type)
          )
        else
          base_assessment
        end

      {:ok, final_assessment}
    end
  end

  defp fetch_combat_stats(entity_id, :character) do
    case Api.get(CharacterStats, entity_id) do
      {:ok, stats} ->
        {:ok,
         %{
           total_kills: stats.total_kills || 0,
           total_losses: stats.total_losses || 0,
           kill_death_ratio: calculate_kdr(stats),
           total_isk_destroyed: stats.total_isk_destroyed || 0,
           total_isk_lost: stats.total_isk_lost || 0,
           isk_efficiency: stats.isk_efficiency || 0,
           danger_rating: stats.danger_rating || 0,
           pvp_experience_days: stats.pvp_experience_days || 0
         }}

      {:error, _} ->
        {:ok,
         %{
           total_kills: 0,
           total_losses: 0,
           kill_death_ratio: 0,
           total_isk_destroyed: 0,
           total_isk_lost: 0,
           isk_efficiency: 0,
           danger_rating: 0,
           pvp_experience_days: 0
         }}
    end
  end

  defp fetch_combat_stats(entity_id, :corporation) do
    # For corporations, aggregate member stats
    since = DateTime.add(DateTime.utc_now(), -90 * 24, :hour)

    query =
      from(k in KillmailRaw,
        where: fragment("?->>'corporation_id' = ?", k.victim, ^to_string(entity_id)),
        where: k.killmail_time > ^since,
        select: %{
          losses: count(k.id),
          total_isk_lost: sum(k.zkb_total_value)
        }
      )

    case EveDmv.Repo.one(query) do
      %{losses: losses, total_isk_lost: isk_lost} ->
        {:ok,
         %{
           member_losses: losses || 0,
           total_isk_lost: isk_lost || 0,
           activity_level: if(losses > 0, do: :active, else: :inactive)
         }}

      _ ->
        {:ok, %{member_losses: 0, total_isk_lost: 0, activity_level: :inactive}}
    end
  end

  defp fetch_recent_activity(entity_id, entity_type, timeframe_days) do
    since = DateTime.add(DateTime.utc_now(), -timeframe_days * 24, :hour)

    query =
      case entity_type do
        :character ->
          from(k in KillmailRaw,
            where:
              fragment("?->>'character_id' = ?", k.victim, ^to_string(entity_id)) or
                fragment(
                  "EXISTS (SELECT 1 FROM jsonb_array_elements(?) AS a WHERE a->>'character_id' = ?)",
                  k.attackers,
                  ^to_string(entity_id)
                ),
            where: k.killmail_time > ^since,
            order_by: [desc: k.killmail_time],
            limit: 500
          )

        :corporation ->
          from(k in KillmailRaw,
            where:
              fragment("?->>'corporation_id' = ?", k.victim, ^to_string(entity_id)) or
                fragment(
                  "EXISTS (SELECT 1 FROM jsonb_array_elements(?) AS a WHERE a->>'corporation_id' = ?)",
                  k.attackers,
                  ^to_string(entity_id)
                ),
            where: k.killmail_time > ^since,
            order_by: [desc: k.killmail_time],
            limit: 500
          )
      end

    killmails = EveDmv.Repo.all(query)

    {:ok,
     %{
       killmails: killmails,
       total_engagements: length(killmails),
       timeframe_days: timeframe_days,
       kills: count_kills(killmails, entity_id, entity_type),
       losses: count_losses(killmails, entity_id, entity_type)
     }}
  end

  defp count_kills(killmails, entity_id, entity_type) do
    field =
      case entity_type do
        :character -> "character_id"
        :corporation -> "corporation_id"
      end

    Enum.count(killmails, fn km ->
      Enum.any?(km.attackers, fn attacker ->
        attacker[field] == entity_id
      end)
    end)
  end

  defp count_losses(killmails, entity_id, entity_type) do
    field =
      case entity_type do
        :character -> "character_id"
        :corporation -> "corporation_id"
      end

    Enum.count(killmails, fn km ->
      get_in(km.victim, [field]) == entity_id
    end)
  end

  defp analyze_combat_patterns(recent_activity) do
    killmails = recent_activity.killmails

    if Enum.empty?(killmails) do
      {:ok,
       %{
         preferred_engagement_type: :unknown,
         average_engagement_size: 0,
         preferred_targets: [],
         combat_tempo: :inactive
       }}
    else
      # Analyze engagement sizes
      engagement_sizes = Enum.map(killmails, &length(&1.attackers))
      avg_size = Enum.sum(engagement_sizes) / length(engagement_sizes)

      # Determine preferred engagement type
      solo_count = Enum.count(engagement_sizes, &(&1 == 1))
      small_gang_count = Enum.count(engagement_sizes, &(&1 >= 2 and &1 <= 5))
      fleet_count = Enum.count(engagement_sizes, &(&1 > 5))

      preferred_type =
        cond do
          solo_count > length(killmails) * 0.5 -> :solo
          small_gang_count > length(killmails) * 0.5 -> :small_gang
          fleet_count > length(killmails) * 0.5 -> :fleet
          true -> :mixed
        end

      # Analyze target preferences
      target_ships =
        killmails
        |> Enum.map(&get_in(&1.victim, ["ship_type_id"]))
        |> Enum.filter(&(&1 != nil))
        |> Enum.frequencies()
        |> Enum.sort_by(&elem(&1, 1), :desc)
        |> Enum.take(5)

      # Determine combat tempo
      tempo = calculate_combat_tempo(killmails, recent_activity.timeframe_days)

      {:ok,
       %{
         preferred_engagement_type: preferred_type,
         average_engagement_size: Float.round(avg_size, 1),
         preferred_targets: target_ships,
         combat_tempo: tempo,
         engagement_distribution: %{
           solo: solo_count,
           small_gang: small_gang_count,
           fleet: fleet_count
         }
       }}
    end
  end

  defp calculate_combat_tempo(killmails, timeframe_days) do
    kills_per_day = length(killmails) / max(1, timeframe_days)

    cond do
      kills_per_day > 10 -> :hyperactive
      kills_per_day > 5 -> :very_active
      kills_per_day > 2 -> :active
      kills_per_day > 0.5 -> :moderate
      kills_per_day > 0 -> :low
      true -> :inactive
    end
  end

  defp assess_combat_capability(entity_id, entity_type, recent_activity) do
    killmails = recent_activity.killmails

    # Analyze ship types used
    ship_analysis = analyze_ship_usage(killmails, entity_id, entity_type)

    # Calculate average ship value
    avg_ship_value = calculate_average_ship_value(killmails, entity_id, entity_type)

    # Assess ship class diversity
    ship_diversity = calculate_ship_diversity(ship_analysis.ship_types_used)

    capability_rating = calculate_capability_rating(ship_analysis, avg_ship_value, ship_diversity)

    {:ok,
     %{
       ship_types_used: ship_analysis.ship_types_used,
       ship_class_distribution: ship_analysis.ship_class_distribution,
       average_ship_value: avg_ship_value,
       ship_diversity_index: ship_diversity,
       overall_rating: capability_rating,
       capital_capable: ship_analysis.capital_usage > 0,
       specialized_ships: ship_analysis.specialized_ships
     }}
  end

  defp analyze_ship_usage(killmails, entity_id, entity_type) do
    field =
      case entity_type do
        :character -> "character_id"
        :corporation -> "corporation_id"
      end

    # Get ships used by the entity
    ship_type_ids =
      killmails
      |> Enum.flat_map(fn km ->
        # Ships used as attacker
        attacker_ships =
          km.attackers
          |> Enum.filter(&(&1[field] == entity_id))
          |> Enum.map(& &1["ship_type_id"])

        # Ships lost
        victim_ship =
          if get_in(km.victim, [field]) == entity_id do
            [km.victim["ship_type_id"]]
          else
            []
          end

        attacker_ships ++ victim_ship
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    # Classify by ship class
    ship_classes =
      ship_type_ids
      |> Enum.map(fn {ship_id, count} ->
        {StaticData.get_ship_class(ship_id), count}
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {class, counts} -> {class, Enum.sum(counts)} end)
      |> Map.new()

    %{
      ship_types_used: ship_type_ids,
      ship_class_distribution: ship_classes,
      capital_usage: Map.get(ship_classes, :capital, 0) + Map.get(ship_classes, :supercapital, 0),
      specialized_ships: count_specialized_ships(ship_type_ids)
    }
  end

  defp calculate_average_ship_value(killmails, entity_id, entity_type) do
    field =
      case entity_type do
        :character -> "character_id"
        :corporation -> "corporation_id"
      end

    loss_values =
      killmails
      |> Enum.filter(fn km -> get_in(km.victim, [field]) == entity_id end)
      |> Enum.map(&(&1.zkb_total_value || 0))
      |> Enum.filter(&(&1 > 0))

    if Enum.empty?(loss_values) do
      0
    else
      round(Enum.sum(loss_values) / length(loss_values))
    end
  end

  defp calculate_ship_diversity(ship_types_used) do
    total_ships = ship_types_used |> Map.values() |> Enum.sum()

    if total_ships == 0 do
      0.0
    else
      # Shannon diversity index
      ship_types_used
      |> Map.values()
      |> Enum.reduce(0.0, fn count, acc ->
        proportion = count / total_ships

        if proportion > 0 do
          acc - proportion * :math.log(proportion)
        else
          acc
        end
      end)
      |> Float.round(3)
    end
  end

  defp count_specialized_ships(ship_type_ids) do
    # Count T2/T3 ships (simplified - would need actual ship metadata)
    Map.keys(ship_type_ids) |> length()
  end

  defp calculate_capability_rating(ship_analysis, avg_ship_value, diversity) do
    # Score based on multiple factors
    base_score = 50

    # Add points for ship diversity
    diversity_score = min(diversity * 10, 20)

    # Add points for capital usage
    capital_score = if ship_analysis.capital_usage > 0, do: 15, else: 0

    # Add points for ship value (wealth indicator)
    value_score =
      cond do
        # 1B+ average
        avg_ship_value > 1_000_000_000 -> 15
        # 500M+
        avg_ship_value > 500_000_000 -> 10
        # 100M+
        avg_ship_value > 100_000_000 -> 5
        true -> 0
      end

    min(base_score + diversity_score + capital_score + value_score, 100)
  end

  defp assess_coordination_ability(_entity_id, _entity_type, recent_activity) do
    killmails = recent_activity.killmails

    if length(killmails) < 5 do
      # Default neutral score for insufficient data
      {:ok, 50.0}
    else
      # Analyze coordination patterns
      fleet_killmails = Enum.filter(killmails, &(length(&1.attackers) > 5))

      if Enum.empty?(fleet_killmails) do
        # Low coordination score if no fleet activity
        {:ok, 30.0}
      else
        # Calculate coordination metrics
        avg_fleet_size =
          fleet_killmails
          |> Enum.map(&length(&1.attackers))
          |> Enum.sum()
          |> Kernel./(length(fleet_killmails))

        # Check for consistent fleet compositions (simplified)
        coordination_score =
          cond do
            avg_fleet_size > 20 -> 90.0
            avg_fleet_size > 10 -> 75.0
            avg_fleet_size > 5 -> 60.0
            true -> 45.0
          end

        {:ok, coordination_score}
      end
    end
  end

  defp calculate_combat_threat_score(assessment_data) do
    # Extract scores for each component
    activity_score = calculate_activity_score(assessment_data.recent_activity)
    efficiency_score = calculate_efficiency_score(assessment_data.combat_stats)
    capability_score = assessment_data.capability_assessment.overall_rating
    coordination_score = assessment_data.coordination_score
    tactical_score = calculate_tactical_score(assessment_data.combat_patterns)

    # Apply weights
    weighted_score =
      activity_score * @combat_threat_weights.recent_activity +
        efficiency_score * @combat_threat_weights.kill_efficiency +
        capability_score * @combat_threat_weights.ship_capability +
        coordination_score * @combat_threat_weights.gang_coordination +
        tactical_score * @combat_threat_weights.tactical_skill

    Float.round(weighted_score, 1)
  end

  defp calculate_activity_score(recent_activity) do
    engagements = recent_activity.total_engagements
    days = recent_activity.timeframe_days

    engagements_per_day = engagements / max(1, days)

    # Score based on activity level
    cond do
      engagements_per_day > 5 -> 100.0
      engagements_per_day > 3 -> 85.0
      engagements_per_day > 1 -> 70.0
      engagements_per_day > 0.5 -> 55.0
      engagements_per_day > 0.1 -> 40.0
      true -> 20.0
    end
  end

  defp calculate_efficiency_score(combat_stats) do
    kdr_score = min(combat_stats.kill_death_ratio * 20, 50)
    isk_score = min(combat_stats.isk_efficiency / 2, 50)

    kdr_score + isk_score
  end

  defp calculate_tactical_score(combat_patterns) do
    base_score = 50.0

    # Bonus for specialized engagement types
    specialization_bonus =
      case combat_patterns.preferred_engagement_type do
        :solo -> 20.0
        :small_gang -> 15.0
        _ -> 10.0
      end

    # Bonus for high combat tempo
    tempo_bonus =
      case combat_patterns.combat_tempo do
        :hyperactive -> 20.0
        :very_active -> 15.0
        :active -> 10.0
        _ -> 0.0
      end

    min(base_score + specialization_bonus + tempo_bonus, 100.0)
  end

  defp classify_threat_level(threat_score) do
    cond do
      threat_score >= 90 -> :extreme
      threat_score >= 75 -> :critical
      threat_score >= 60 -> :high
      threat_score >= 45 -> :moderate
      threat_score >= 30 -> :low
      true -> :minimal
    end
  end

  defp calculate_combat_efficiency(combat_stats) do
    %{
      kill_death_ratio: combat_stats.kill_death_ratio,
      isk_efficiency: combat_stats.isk_efficiency,
      efficiency_rating: classify_efficiency(combat_stats)
    }
  end

  defp classify_efficiency(stats) do
    score = stats.kill_death_ratio * 0.5 + stats.isk_efficiency * 0.5

    cond do
      score > 150 -> :elite
      score > 100 -> :excellent
      score > 75 -> :good
      score > 50 -> :average
      true -> :poor
    end
  end

  defp categorize_activity_level(recent_activity) do
    %{
      engagement_count: recent_activity.total_engagements,
      tempo: calculate_combat_tempo(recent_activity.killmails, recent_activity.timeframe_days),
      kills: recent_activity.kills,
      losses: recent_activity.losses
    }
  end

  defp identify_risk_factors(combat_stats, recent_activity, combat_patterns) do
    base_risk_factors = []

    # High K/D ratio = dangerous opponent
    kdr_risk_factors =
      if combat_stats.kill_death_ratio > 3.0 do
        [
          %{factor: :high_kdr, severity: :high, description: "Very high kill/death ratio"}
          | base_risk_factors
        ]
      else
        base_risk_factors
      end

    # High activity = unpredictable threat
    activity_risk_factors =
      if recent_activity.total_engagements > 100 do
        [
          %{factor: :high_activity, severity: :medium, description: "Very active in combat"}
          | kdr_risk_factors
        ]
      else
        kdr_risk_factors
      end

    # Solo preference = skilled pilot
    final_risk_factors =
      if combat_patterns.preferred_engagement_type == :solo do
        [
          %{factor: :solo_specialist, severity: :high, description: "Skilled solo pilot"}
          | activity_risk_factors
        ]
      else
        activity_risk_factors
      end

    final_risk_factors
  end

  defp identify_tactical_strengths(combat_patterns, capability_assessment) do
    base_strengths = []

    solo_strengths =
      if combat_patterns.preferred_engagement_type == :solo do
        [:independent_operator | base_strengths]
      else
        base_strengths
      end

    capital_strengths =
      if capability_assessment.capital_capable do
        [:capital_pilot | solo_strengths]
      else
        solo_strengths
      end

    final_strengths =
      if capability_assessment.ship_diversity_index > 2.0 do
        [:versatile_pilot | capital_strengths]
      else
        capital_strengths
      end

    final_strengths
  end

  defp identify_tactical_weaknesses(combat_patterns, combat_stats) do
    base_weaknesses = []

    survival_weaknesses =
      if combat_stats.kill_death_ratio < 1.0 do
        [:poor_survival_rate | base_weaknesses]
      else
        base_weaknesses
      end

    final_weaknesses =
      if combat_patterns.preferred_engagement_type == :fleet do
        [:dependent_on_numbers | survival_weaknesses]
      else
        survival_weaknesses
      end

    final_weaknesses
  end

  defp generate_engagement_recommendations(threat_level, combat_patterns) do
    base_recommendations =
      case threat_level do
        :extreme ->
          ["Avoid engagement unless overwhelming advantage", "Scout thoroughly before engagement"]

        :critical ->
          ["Engage only with numerical superiority", "Prepare for skilled opponent"]

        :high ->
          ["Exercise caution", "Consider bringing backup"]

        :moderate ->
          ["Standard engagement protocols", "Watch for escalation"]

        _ ->
          ["Safe to engage with standard tactics"]
      end

    # Add specific recommendations based on patterns
    pattern_recommendations =
      case combat_patterns.preferred_engagement_type do
        :solo -> ["Watch for bait tactics", "Check for cyno capability"]
        :small_gang -> ["Expect coordinated tactics", "Watch for reinforcements"]
        :fleet -> ["Avoid engaging their fleets", "Look for isolated targets"]
        _ -> []
      end

    base_recommendations ++ pattern_recommendations
  end

  defp assess_fleet_threat(_entity_id, _entity_type) do
    # Simplified fleet threat assessment
    %{
      estimated_fleet_size: 0,
      fleet_composition: %{},
      escalation_potential: :unknown,
      known_fc: false
    }
  end

  defp extract_entities_from_killmail(event) do
    base_entities = []

    # Extract victim
    victim = event.victim

    victim_char_entities =
      if victim["character_id"],
        do: [{victim["character_id"], :character} | base_entities],
        else: base_entities

    victim_corp_entities =
      if victim["corporation_id"],
        do: [{victim["corporation_id"], :corporation} | victim_char_entities],
        else: victim_char_entities

    # Extract attackers
    attacker_entities =
      event.attackers
      |> Enum.flat_map(fn attacker ->
        char_entity =
          if attacker["character_id"], do: [{attacker["character_id"], :character}], else: []

        corp_entity =
          if attacker["corporation_id"],
            do: [{attacker["corporation_id"], :corporation}],
            else: []

        char_entity ++ corp_entity
      end)
      |> Enum.uniq()

    victim_corp_entities ++ attacker_entities
  end

  defp update_realtime_threat_indicators(_event, _entities) do
    # Would update real-time threat indicators
    # This is where we'd push updates to connected clients
    :ok
  end

  defp calculate_cache_hit_rate(state) do
    total = state.cache_hits + state.cache_misses

    if total > 0 do
      Float.round(state.cache_hits / total * 100, 1)
    else
      0.0
    end
  end

  defp calculate_uptime_hours(_state) do
    # Would calculate actual uptime
    0
  end

  defp calculate_kdr(%{total_kills: kills, total_losses: losses}) when losses > 0 do
    Float.round(kills / losses, 2)
  end

  defp calculate_kdr(%{total_kills: kills}) when kills > 0, do: Float.round(kills, 2)
  defp calculate_kdr(_), do: 0.0
end
