defmodule EveDmv.Contexts.CorporationIntelligence do
  @moduledoc """
  Context module for corporation intelligence and combat doctrine analysis.

  Provides the public API for corporation threat assessment, doctrine recognition,
  and tactical intelligence gathering.
  """

  alias EveDmv.Api
  alias EveDmv.Contexts.CorporationIntelligence.Domain.CombatDoctrineAnalyzer
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.Participant
  alias EveDmv.Utils.TimezoneAnalyzer

  require Ash.Query

  @doc """
  Analyzes a corporation's combat doctrines based on their killmail history.

  Identifies doctrine patterns such as:
  - Shield Kiting
  - Armor Brawling
  - EWAR Heavy
  - Capital Escalation
  - Alpha Strike
  - Nano Gang
  - Logistics Heavy

  ## Examples

      iex> CorporationIntelligence.analyze_combat_doctrines(corporation_id)
      {:ok, %{
        primary_doctrine: :shield_kiting,
        doctrine_confidence: 0.85,
        secondary_doctrines: [:nano_gang],
        fleet_compositions: [...],
        tactical_preferences: %{...}
      }}
  """
  def analyze_combat_doctrines(corporation_id, options \\ []) do
    case CombatDoctrineAnalyzer.analyze_combat_doctrines(corporation_id, options) do
      {:ok, analysis} -> {:ok, analysis}
      error -> error
    end
  end

  @doc """
  Compares combat doctrines between multiple corporations.

  Useful for identifying tactical advantages and vulnerabilities.
  """
  def compare_combat_doctrines(corporation_ids, options \\ []) when is_list(corporation_ids) do
    case CombatDoctrineAnalyzer.compare_combat_doctrines(corporation_ids, options) do
      {:ok, comparison} -> {:ok, comparison}
      error -> error
    end
  end

  @doc """
  Generates counter-doctrine recommendations against a target corporation.

  Analyzes the target's preferred doctrines and suggests effective counters.
  """
  def generate_counter_doctrine(target_corporation_id, options \\ []) do
    case CombatDoctrineAnalyzer.generate_counter_doctrine(target_corporation_id, options) do
      {:ok, recommendations} -> {:ok, recommendations}
      error -> error
    end
  end

  @doc """
  Tracks doctrine evolution over time for a corporation.

  Shows how tactics and fleet compositions have changed.
  """
  def track_doctrine_evolution(corporation_id, options \\ []) do
    case CombatDoctrineAnalyzer.track_doctrine_evolution(corporation_id, options) do
      {:ok, evolution} -> {:ok, evolution}
      error -> error
    end
  end

  @doc """
  Gets a comprehensive intelligence report for a corporation.

  Combines doctrine analysis, member threat assessments, and activity metrics.
  """
  def get_corporation_intelligence_report(corporation_id) do
    # Get basic info first
    corp_info =
      case get_corporation_info(corporation_id) do
        {:ok, info} -> info
        _ -> %{corporation_id: corporation_id, name: "Unknown Corporation", ticker: "UNKN"}
      end

    # Try to get each component, but use defaults if they fail
    doctrine_analysis =
      case analyze_combat_doctrines(corporation_id) do
        {:ok, analysis} ->
          analysis

        {:error, :insufficient_fleet_data} ->
          # Generate fallback analysis from participant data
          generate_fallback_analysis(corporation_id)

        _ ->
          generate_fallback_analysis(corporation_id)
      end

    doctrine_evolution =
      case track_doctrine_evolution(corporation_id) do
        {:ok, evolution} -> evolution
        _ -> generate_fallback_evolution(corporation_id)
      end

    member_threats =
      case analyze_top_member_threats(corporation_id) do
        {:ok, threats} -> threats
        _ -> %{top_threats: [], average_threat_score: 0, threat_distribution: %{}}
      end

    activity_metrics =
      case calculate_activity_metrics(corporation_id) do
        {:ok, metrics} ->
          metrics

        _ ->
          %{
            active_members: 0,
            kills_per_day: 0,
            prime_timezone: "Unknown",
            activity_trend: :stable,
            engagement_frequency: 0
          }
      end

    {:ok,
     %{
       corporation: corp_info,
       doctrine_analysis: doctrine_analysis,
       doctrine_evolution: doctrine_evolution,
       member_threats: member_threats,
       activity_metrics: activity_metrics,
       summary: generate_intelligence_summary(doctrine_analysis, member_threats, activity_metrics)
     }}
  end

  @doc """
  Analyzes threat levels of top members in a corporation.
  """
  def analyze_top_member_threats(corporation_id, limit \\ 10) do
    alias EveDmv.Contexts.CharacterIntelligence

    # Get active members from last 60 days
    sixty_days_ago = DateTime.utc_now() |> DateTime.add(-60, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^sixty_days_ago)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Get unique character IDs with activity counts
        member_activities =
          participants
          |> Enum.filter(& &1.character_id)
          |> Enum.group_by(& &1.character_id)
          |> Enum.map(fn {char_id, activities} ->
            {char_id, length(activities)}
          end)
          |> Enum.sort_by(fn {_id, count} -> count end, :desc)
          # Get more to account for failed threat analysis
          |> Enum.take(limit * 2)

        # Analyze threats for most active members
        threat_results =
          member_activities
          |> Enum.map(fn {character_id, activity_count} ->
            case CharacterIntelligence.analyze_character_threat(character_id) do
              {:ok, threat_data} ->
                character_name = NameResolver.character_name(character_id)

                %{
                  character_id: character_id,
                  character_name: character_name,
                  threat_score: threat_data.threat_score,
                  activity_count: activity_count,
                  threat_level: categorize_threat_level(threat_data.threat_score)
                }

              _ ->
                nil
            end
          end)
          |> Enum.filter(& &1)
          |> Enum.sort_by(& &1.threat_score, :desc)
          |> Enum.take(limit)

        # Calculate statistics
        threat_scores = Enum.map(threat_results, & &1.threat_score)

        average_threat =
          if length(threat_scores) > 0,
            do: Enum.sum(threat_scores) / length(threat_scores),
            else: 0

        threat_distribution = calculate_threat_distribution(threat_results)

        {:ok,
         %{
           top_threats: threat_results,
           average_threat_score: Float.round(average_threat, 1),
           threat_distribution: threat_distribution
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Calculates activity metrics for a corporation.
  """
  def calculate_activity_metrics(corporation_id, days_back \\ 30) do
    time_cutoff = DateTime.utc_now() |> DateTime.add(-days_back, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^time_cutoff)
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        # Calculate metrics
        total_activities = length(participants)

        active_members =
          participants
          |> Enum.map(& &1.character_id)
          |> Enum.filter(& &1)
          |> Enum.uniq()
          |> length()

        kills_per_day = if days_back > 0, do: total_activities / days_back, else: 0.0

        # Calculate prime timezone from killmail times
        # Convert participants to format expected by TimezoneAnalyzer
        killmail_data = Enum.map(participants, fn p -> %{killmail_time: p.killmail_time} end)
        prime_timezone = TimezoneAnalyzer.analyze_primary_timezone(killmail_data)

        # Calculate activity trend (compare last half vs first half of period)
        activity_trend = calculate_activity_trend(participants, days_back)

        # Engagement frequency (activities per active member per day)
        engagement_frequency =
          if active_members > 0 and days_back > 0 do
            total_activities / (active_members * days_back)
          else
            0.0
          end

        {:ok,
         %{
           active_members: active_members,
           kills_per_day: Float.round(kills_per_day, 1),
           prime_timezone: prime_timezone,
           activity_trend: activity_trend,
           engagement_frequency: Float.round(engagement_frequency, 2)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Clears cached intelligence data for a corporation.
  """
  def clear_corporation_cache(_corporation_id) do
    # This is a placeholder - in a production system you might have specific
    # intelligence caches to clear. For now, the AnalysisCache handles this.
    :ok
  end

  # Private helper functions

  defp get_corporation_info(corporation_id) do
    # Get corporation info from recent killmail data using Ash
    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Api) do
      {:ok, [participant | _]} ->
        {:ok,
         %{
           corporation_id: corporation_id,
           name: participant.corporation_name || "Unknown Corporation",
           ticker: extract_ticker_from_name(participant.corporation_name),
           member_count: get_member_count(corporation_id),
           alliance_id: participant.alliance_id,
           alliance_name: participant.alliance_name
         }}

      {:ok, []} ->
        {:ok,
         %{
           corporation_id: corporation_id,
           name: "Unknown Corporation",
           ticker: "UNKN",
           member_count: 0,
           alliance_id: nil,
           alliance_name: nil
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_intelligence_summary(doctrine_analysis, member_threats, _activity_metrics) do
    primary_doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)
    doctrine_confidence = Map.get(doctrine_analysis, :doctrine_confidence, 0)
    avg_threat = Map.get(member_threats, :average_threat_score, 0)

    # Calculate a fallback threat score if we don't have member threat data
    calculated_threat =
      if avg_threat > 0 do
        avg_threat
      else
        # Generate threat score from available data
        tactical_prefs = Map.get(doctrine_analysis, :tactical_preferences, %{})
        combat_efficiency = Map.get(tactical_prefs, :combat_efficiency, 0)
        activity_level = Map.get(tactical_prefs, :activity_level, "Very Low Activity")

        base_score =
          case activity_level do
            "High Activity" -> 40
            "Moderate Activity" -> 30
            "Low Activity" -> 20
            "Minimal Activity" -> 15
            _ -> 10
          end

        # Add efficiency bonus
        efficiency_bonus = if combat_efficiency > 80, do: 15, else: round(combat_efficiency / 8)

        # Add doctrine confidence bonus
        confidence_bonus = round(doctrine_confidence * 10)

        min(base_score + efficiency_bonus + confidence_bonus, 100)
      end

    threat_level =
      cond do
        calculated_threat >= 75 -> "Very High"
        calculated_threat >= 50 -> "High"
        calculated_threat >= 25 -> "Moderate"
        true -> "Low"
      end

    %{
      threat_level: threat_level,
      primary_doctrine: primary_doctrine,
      doctrine_confidence: doctrine_confidence,
      average_member_threat: calculated_threat,
      summary:
        "#{threat_level} threat corporation specializing in #{format_doctrine_name(primary_doctrine)} doctrine",
      key_capabilities: extract_key_capabilities(doctrine_analysis),
      vulnerabilities: identify_vulnerabilities(doctrine_analysis),
      recommendations: generate_tactical_recommendations(doctrine_analysis, member_threats)
    }
  end

  defp format_doctrine_name(doctrine) do
    case doctrine do
      :unknown ->
        "Unknown"

      nil ->
        "Unknown"

      :small_gang ->
        "Small Gang"

      _ ->
        doctrine
        |> to_string()
        |> String.replace("_", " ")
        |> String.split()
        |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  defp extract_key_capabilities(doctrine_analysis) do
    doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)

    case doctrine do
      :shield_kiting ->
        ["Long range engagement", "High mobility", "Kiting tactics"]

      :armor_brawling ->
        ["Close range DPS", "Heavy tank", "Sustained combat"]

      :ewar_heavy ->
        ["Electronic warfare", "Force multiplication", "Disruption tactics"]

      :capital_escalation ->
        ["Capital ship deployment", "Escalation capability", "Heavy assets"]

      :alpha_strike ->
        ["High alpha damage", "Coordinated strikes", "Target elimination"]

      :nano_gang ->
        ["Hit and run tactics", "High speed", "Small gang warfare"]

      :logistics_heavy ->
        ["Strong logistics", "Sustained fights", "Defensive positioning"]

      :small_gang ->
        ["Small gang operations", "Flexible composition", "Quick deployment"]

      _ ->
        # Check if we have tactical preferences data to extract capabilities
        tactical_prefs = Map.get(doctrine_analysis, :tactical_preferences, %{})

        if map_size(tactical_prefs) > 0 do
          generate_capabilities_from_data(tactical_prefs)
        else
          ["Limited intelligence available"]
        end
    end
  end

  defp identify_vulnerabilities(doctrine_analysis) do
    doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)

    case doctrine do
      :shield_kiting ->
        ["Vulnerable to fast tackle", "Weak in close range", "Capacitor dependent"]

      :armor_brawling ->
        ["Limited range", "Slow mobility", "Vulnerable to kiting"]

      :ewar_heavy ->
        ["DPS limited", "Requires coordination", "Vulnerable to alpha"]

      :capital_escalation ->
        ["Immobile assets", "Escalation trap risk", "Subcap dependent"]

      :alpha_strike ->
        ["Reload vulnerability", "Close range weakness", "Coordination dependent"]

      :nano_gang ->
        ["Low tank", "Numbers disadvantage", "Vulnerable to camps"]

      :logistics_heavy ->
        ["DPS limited", "Logistics vulnerable", "Slow positioning"]

      :small_gang ->
        ["Limited numbers", "Vulnerable to blobs", "Range dependent"]

      _ ->
        # Try to extract vulnerabilities from available data
        tactical_prefs = Map.get(doctrine_analysis, :tactical_preferences, %{})

        if map_size(tactical_prefs) > 0 do
          generate_vulnerabilities_from_data(tactical_prefs)
        else
          ["Limited tactical intelligence"]
        end
    end
  end

  defp generate_tactical_recommendations(doctrine_analysis, member_threats) do
    doctrine = Map.get(doctrine_analysis, :primary_doctrine, :unknown)

    base_recommendations =
      case doctrine do
        :shield_kiting ->
          [
            "Use fast tackle to close range",
            "Employ damping/tracking disruption",
            "Force close-range engagement"
          ]

        :armor_brawling ->
          [
            "Maintain range control",
            "Use mobility advantage",
            "Avoid prolonged brawls"
          ]

        :ewar_heavy ->
          [
            "Focus fire on EWAR ships",
            "Use sensor boosters",
            "Bring ECCM support"
          ]

        :capital_escalation ->
          [
            "Avoid escalation traps",
            "Use hit-and-run tactics",
            "Target subcap support first"
          ]

        :small_gang ->
          [
            "Use superior numbers",
            "Control engagement range",
            "Force unfavorable fights"
          ]

        _ ->
          # Generate recommendations based on available data
          tactical_prefs = Map.get(doctrine_analysis, :tactical_preferences, %{})

          if map_size(tactical_prefs) > 0 do
            generate_recommendations_from_data(tactical_prefs)
          else
            [
              "Gather more intelligence",
              "Monitor activity patterns",
              "Prepare flexible response"
            ]
          end
      end

    # Add recommendations based on member threats
    threat_recommendations =
      if member_threats.average_threat_score >= 50 do
        ["Exercise caution - skilled pilots", "Expect advanced tactics"]
      else
        []
      end

    base_recommendations ++ threat_recommendations
  end

  # Helper functions for corporation info
  defp extract_ticker_from_name(corp_name) when is_binary(corp_name) do
    # Simple ticker extraction - first 4 characters uppercase
    corp_name
    |> String.upcase()
    |> String.replace(~r/[^A-Z0-9]/, "")
    |> String.slice(0, 4)
    |> case do
      "" -> "UNKN"
      ticker -> ticker
    end
  end

  defp extract_ticker_from_name(_), do: "UNKN"

  defp get_member_count(corporation_id) do
    # Count unique members from killmail data in last 90 days
    ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^ninety_days_ago)
         |> Ash.Query.select([:character_id])
         |> Ash.read(domain: Api) do
      {:ok, participants} ->
        participants
        |> Enum.map(& &1.character_id)
        |> Enum.filter(& &1)
        |> Enum.uniq()
        |> length()

      {:error, _} ->
        0
    end
  end

  defp calculate_activity_trend(participants, days_back) when days_back >= 14 do
    # Split into two periods and compare
    half_period = div(days_back, 2)
    cutoff_time = DateTime.utc_now() |> DateTime.add(-half_period, :day)

    recent_count =
      participants |> Enum.count(&(DateTime.compare(&1.killmail_time, cutoff_time) == :gt))

    older_count = length(participants) - recent_count

    cond do
      older_count == 0 and recent_count > 0 -> :increasing
      recent_count == 0 and older_count > 0 -> :decreasing
      recent_count > older_count * 1.2 -> :increasing
      older_count > recent_count * 1.2 -> :decreasing
      true -> :stable
    end
  end

  defp calculate_activity_trend(_participants, _days_back), do: :stable

  defp categorize_threat_level(score) when score >= 90, do: :extreme
  defp categorize_threat_level(score) when score >= 75, do: :high
  defp categorize_threat_level(score) when score >= 50, do: :moderate
  defp categorize_threat_level(score) when score >= 25, do: :low
  defp categorize_threat_level(_), do: :minimal

  defp calculate_threat_distribution(threat_results) do
    distribution =
      threat_results
      |> Enum.map(& &1.threat_level)
      |> Enum.frequencies()

    %{
      extreme: Map.get(distribution, :extreme, 0),
      high: Map.get(distribution, :high, 0),
      moderate: Map.get(distribution, :moderate, 0),
      low: Map.get(distribution, :low, 0),
      minimal: Map.get(distribution, :minimal, 0)
    }
  end

  # Generate fallback intelligence analysis from participant data when fleet data is insufficient
  defp generate_fallback_analysis(corporation_id) do
    # Get recent participant data for analysis
    ninety_days_ago = DateTime.utc_now() |> DateTime.add(-90, :day)

    case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
         |> Ash.Query.filter(killmail_time >= ^ninety_days_ago)
         |> Ash.Query.limit(1000)
         |> Ash.read(domain: Api) do
      {:ok, participants} when participants != [] ->
        valid_participants = participants |> Enum.filter(& &1.character_id)

        # Analyze ship usage patterns
        ship_usage =
          valid_participants
          |> Enum.map(& &1.ship_type_id)
          |> Enum.frequencies()
          |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
          |> Enum.take(5)

        # Determine doctrine hint based on most used ships
        primary_doctrine = infer_doctrine_from_ships(ship_usage)

        # Calculate basic metrics
        total_activities = length(valid_participants)
        kills = Enum.count(valid_participants, &(not &1.is_victim))
        _losses = Enum.count(valid_participants, & &1.is_victim)
        efficiency = if total_activities > 0, do: kills / total_activities * 100, else: 0

        # Generate ship composition summary
        ship_names =
          ship_usage
          |> Enum.map(fn {ship_id, count} ->
            ship_name = NameResolver.ship_name(ship_id)
            "#{ship_name} (#{count})"
          end)
          |> Enum.take(3)

        fleet_comp_text =
          if length(ship_names) > 0 do
            "Frequently uses: #{Enum.join(ship_names, ", ")}"
          else
            "Mixed ship composition"
          end

        # Calculate confidence based on data quality
        confidence = calculate_fallback_confidence(total_activities, length(ship_usage))

        %{
          primary_doctrine: primary_doctrine,
          doctrine_confidence: confidence,
          secondary_doctrines: [],
          fleet_compositions: [%{ships: ship_names, description: fleet_comp_text}],
          tactical_preferences: %{
            combat_efficiency: Float.round(efficiency, 1),
            preferred_ships: ship_names,
            activity_level: categorize_activity_level(total_activities)
          }
        }

      _ ->
        # Fallback to unknown if no data
        %{
          primary_doctrine: :unknown,
          doctrine_confidence: 0.0,
          secondary_doctrines: [],
          fleet_compositions: [],
          tactical_preferences: %{}
        }
    end
  end

  # Infer basic doctrine from ship usage patterns
  defp infer_doctrine_from_ships(ship_usage) when length(ship_usage) > 0 do
    # Get the most used ship types and try to infer doctrine
    _top_ships = ship_usage |> Enum.take(3) |> Enum.map(&elem(&1, 0))

    # This is a simplified inference - in reality you'd want more sophisticated logic
    # For now, just return a basic classification
    # This could be expanded with actual ship type analysis
    :small_gang
  end

  defp infer_doctrine_from_ships(_), do: :unknown

  # Calculate confidence based on available data
  defp calculate_fallback_confidence(total_activities, unique_ships) do
    case {total_activities, unique_ships} do
      {activities, ships} when activities >= 50 and ships >= 5 -> 0.6
      {activities, ships} when activities >= 20 and ships >= 3 -> 0.4
      {activities, _} when activities >= 10 -> 0.3
      {activities, _} when activities >= 5 -> 0.2
      _ -> 0.1
    end
  end

  # Categorize activity level
  defp categorize_activity_level(total_activities) do
    cond do
      total_activities >= 100 -> "High Activity"
      total_activities >= 50 -> "Moderate Activity"
      total_activities >= 20 -> "Low Activity"
      total_activities >= 5 -> "Minimal Activity"
      true -> "Very Low Activity"
    end
  end

  # Generate capabilities based on tactical preferences data
  defp generate_capabilities_from_data(tactical_prefs) do
    capabilities = []

    capabilities =
      if Map.get(tactical_prefs, :combat_efficiency, 0) > 80 do
        ["High combat effectiveness" | capabilities]
      else
        capabilities
      end

    capabilities =
      case Map.get(tactical_prefs, :activity_level) do
        "High Activity" -> ["Frequent operations" | capabilities]
        "Moderate Activity" -> ["Regular operations" | capabilities]
        _ -> capabilities
      end

    capabilities =
      if length(Map.get(tactical_prefs, :preferred_ships, [])) > 2 do
        ["Diverse ship usage" | capabilities]
      else
        ["Focused ship preferences" | capabilities]
      end

    if length(capabilities) > 0, do: capabilities, else: ["Limited intelligence available"]
  end

  # Generate vulnerabilities based on tactical preferences data
  defp generate_vulnerabilities_from_data(tactical_prefs) do
    vulnerabilities = []

    vulnerabilities =
      case Map.get(tactical_prefs, :activity_level) do
        "Very Low Activity" -> ["Irregular presence" | vulnerabilities]
        "Minimal Activity" -> ["Limited engagement" | vulnerabilities]
        _ -> vulnerabilities
      end

    vulnerabilities =
      if Map.get(tactical_prefs, :combat_efficiency, 0) < 50 do
        ["Poor combat record" | vulnerabilities]
      else
        vulnerabilities
      end

    if length(vulnerabilities) > 0, do: vulnerabilities, else: ["Analysis requires more data"]
  end

  # Generate tactical recommendations based on available data
  defp generate_recommendations_from_data(tactical_prefs) do
    recommendations = []

    recommendations =
      case Map.get(tactical_prefs, :activity_level) do
        "High Activity" -> ["Expect frequent engagements" | recommendations]
        "Moderate Activity" -> ["Prepare for regular conflicts" | recommendations]
        "Low Activity" -> ["Monitor for activity spikes" | recommendations]
        _ -> ["Exploit low activity windows" | recommendations]
      end

    recommendations =
      if Map.get(tactical_prefs, :combat_efficiency, 0) > 80 do
        ["Exercise caution - effective pilots" | recommendations]
      else
        ["Exploit poor combat record" | recommendations]
      end

    recommendations =
      if length(Map.get(tactical_prefs, :preferred_ships, [])) > 2 do
        ["Prepare for varied ship types" | recommendations]
      else
        ["Counter specific ship preferences" | recommendations]
      end

    if length(recommendations) > 0, do: recommendations, else: ["Gather more tactical data"]
  end

  # Generate fallback doctrine evolution showing activity patterns instead of doctrine changes
  defp generate_fallback_evolution(corporation_id) do
    # Generate last 6 months of activity data
    months =
      for i <- 6..1//-1 do
        start_date = Date.utc_today() |> Date.add(-i * 30) |> DateTime.new!(~T[00:00:00])
        end_date = Date.utc_today() |> Date.add(-(i - 1) * 30) |> DateTime.new!(~T[00:00:00])

        case Ash.Query.for_read(Participant, :by_corporation, %{corporation_id: corporation_id})
             |> Ash.Query.filter(killmail_time >= ^start_date and killmail_time < ^end_date)
             |> Ash.Query.limit(500)
             |> Ash.read(domain: Api) do
          {:ok, participants} when participants != [] ->
            valid_participants = participants |> Enum.filter(& &1.character_id)
            activity_count = length(valid_participants)

            activity_level =
              cond do
                activity_count >= 20 -> "Active"
                activity_count >= 10 -> "Moderate"
                activity_count >= 5 -> "Low Activity"
                activity_count > 0 -> "Minimal"
                true -> "Inactive"
              end

            %{
              period: "#{i} months ago",
              doctrine: activity_level,
              confidence: if(activity_count > 0, do: 0.8, else: 0.1),
              activities: activity_count
            }

          _ ->
            %{
              period: "#{i} months ago",
              doctrine: "Inactive",
              confidence: 0.1,
              activities: 0
            }
        end
      end

    %{time_periods: months}
  end
end
