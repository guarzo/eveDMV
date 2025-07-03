defmodule EveDmv.Intelligence.WHVettingAnalyzer do
  @moduledoc """
  Comprehensive vetting analysis for wormhole corporation recruitment.

  Provides deep analysis of potential recruits including J-space experience,
  security risk assessment, eviction group detection, and alt character analysis.
  """

  require Logger
  require Ash.Query

  alias EveDmv.Api
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.{CharacterStats, WHVetting}
  alias EveDmv.Killmails.Participant

  @doc """
  Perform comprehensive vetting analysis for a character.

  Returns {:ok, vetting_record} or {:error, reason}
  """
  def analyze_character(character_id, requested_by_id \\ nil) do
    with {:ok, character_info} <- validate_and_get_character_info(character_id),
         {:ok, analysis_data} <- collect_all_analysis_data(character_id),
         {:ok, scores} <- calculate_all_scores(analysis_data),
         {:ok, recommendation} <- generate_recommendation_data(scores, analysis_data.risk_factors) do
      create_vetting_record(
        character_id,
        character_info,
        analysis_data,
        scores,
        recommendation,
        requested_by_id
      )
    end
  end

  defp validate_and_get_character_info(character_id) do
    if is_nil(character_id) do
      {:error, "Character ID cannot be nil"}
    else
      Logger.info("Starting WH vetting analysis for character #{character_id}")
      get_character_info(character_id)
    end
  end

  defp collect_all_analysis_data(character_id) do
    with {:ok, j_space_activity} <- analyze_j_space_activity(character_id),
         {:ok, eviction_associations} <- analyze_eviction_associations(character_id),
         {:ok, alt_analysis} <- analyze_alt_patterns(character_id),
         {:ok, competency_metrics} <- analyze_small_gang_competency(character_id),
         {:ok, risk_factors} <- analyze_risk_factors(character_id),
         {:ok, employment_history} <- analyze_employment_history(character_id) do
      {:ok,
       %{
         j_space_activity: j_space_activity,
         eviction_associations: eviction_associations,
         alt_analysis: alt_analysis,
         competency_metrics: competency_metrics,
         risk_factors: risk_factors,
         employment_history: employment_history
       }}
    end
  end

  defp calculate_all_scores(analysis_data) do
    scores =
      calculate_scores(
        analysis_data.j_space_activity,
        analysis_data.eviction_associations,
        analysis_data.alt_analysis,
        analysis_data.competency_metrics,
        analysis_data.risk_factors,
        analysis_data.employment_history
      )

    {:ok, scores}
  end

  defp generate_recommendation_data(scores, risk_factors) do
    recommendation = generate_recommendation(scores, risk_factors)
    {:ok, recommendation}
  end

  defp create_vetting_record(
         character_id,
         character_info,
         analysis_data,
         scores,
         recommendation,
         requested_by_id
       ) do
    auto_summary = generate_auto_summary(character_info, scores, analysis_data.risk_factors)

    vetting_data =
      build_vetting_data(
        character_id,
        character_info,
        analysis_data,
        scores,
        recommendation,
        auto_summary,
        requested_by_id
      )

    save_vetting_record(character_id, vetting_data)
  end

  defp build_vetting_data(
         character_id,
         character_info,
         analysis_data,
         scores,
         recommendation,
         auto_summary,
         requested_by_id
       ) do
    %{
      character_id: character_id,
      character_name: character_info.character_name,
      corporation_id: character_info.corporation_id,
      corporation_name: character_info.corporation_name,
      alliance_id: character_info.alliance_id,
      alliance_name: character_info.alliance_name,
      vetting_requested_by: requested_by_id,
      overall_risk_score: scores.overall_risk_score,
      wh_experience_score: scores.wh_experience_score,
      competency_score: scores.competency_score,
      security_score: scores.security_score,
      j_space_activity: analysis_data.j_space_activity,
      eviction_associations: analysis_data.eviction_associations,
      alt_analysis: analysis_data.alt_analysis,
      competency_metrics: analysis_data.competency_metrics,
      risk_factors: analysis_data.risk_factors,
      employment_history: analysis_data.employment_history,
      recommendation: recommendation.decision,
      recommendation_confidence: recommendation.confidence,
      auto_generated_summary: auto_summary,
      requires_manual_review: recommendation.requires_manual_review,
      data_completeness_percent:
        calculate_data_completeness([
          analysis_data.j_space_activity,
          analysis_data.eviction_associations,
          analysis_data.alt_analysis,
          analysis_data.competency_metrics
        ]),
      status: "complete"
    }
  end

  defp save_vetting_record(character_id, vetting_data) do
    case WHVetting.get_by_character(character_id) do
      {:ok, [existing]} ->
        WHVetting.update_analysis(existing, vetting_data)

      {:ok, []} ->
        WHVetting.create(vetting_data)

      {:error, _} ->
        WHVetting.create(vetting_data)
    end
  rescue
    error ->
      Logger.error("WH vetting analysis failed for character #{character_id}: #{inspect(error)}")
      {:error, error}
  end

  # Character information retrieval
  defp get_character_info(character_id) do
    # Try ESI first for the most current data
    case EsiClient.get_character(character_id) do
      {:ok, char_data} ->
        # Get corporation and alliance info
        corp_info =
          case EsiClient.get_corporation(char_data.corporation_id) do
            {:ok, corp} -> %{corporation_name: corp.name, alliance_id: corp.alliance_id}
            _ -> %{corporation_name: "Unknown Corporation", alliance_id: nil}
          end

        alliance_info =
          if corp_info.alliance_id do
            case EsiClient.get_alliance(corp_info.alliance_id) do
              {:ok, alliance} -> %{alliance_name: alliance.name}
              _ -> %{alliance_name: nil}
            end
          else
            %{alliance_name: nil}
          end

        {:ok,
         %{
           character_name: char_data.name,
           corporation_id: char_data.corporation_id,
           corporation_name: corp_info.corporation_name,
           alliance_id: corp_info.alliance_id,
           alliance_name: alliance_info.alliance_name
         }}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch character info from ESI for #{character_id}: #{inspect(reason)}"
        )

        # Fallback to local character stats
        character_stats = get_or_create_character_stats(character_id)

        {:ok,
         %{
           character_name: character_stats.character_name || "Character #{character_id}",
           corporation_id: character_stats.corporation_id,
           corporation_name: character_stats.corporation_name,
           alliance_id: character_stats.alliance_id,
           alliance_name: character_stats.alliance_name
         }}
    end
  end

  # J-space activity analysis
  defp analyze_j_space_activity(character_id) do
    # Get killmails in J-space (security < 0.0 typically indicates wormhole space)
    j_space_kills = get_j_space_killmails(character_id, :kills)
    j_space_losses = get_j_space_killmails(character_id, :losses)

    total_kills = get_total_killmails(character_id, :kills)
    total_losses = get_total_killmails(character_id, :losses)

    j_space_time_percent =
      calculate_j_space_time_percentage(
        j_space_kills ++ j_space_losses,
        total_kills + total_losses
      )

    wh_classes_active = extract_wh_classes(j_space_kills ++ j_space_losses)
    home_holes = identify_home_holes(j_space_kills ++ j_space_losses)

    rolling_participation = analyze_rolling_patterns(character_id)
    scanning_skills = analyze_scanning_patterns(j_space_kills ++ j_space_losses)

    activity = %{
      "total_j_kills" => length(j_space_kills),
      "total_j_losses" => length(j_space_losses),
      "j_space_time_percent" => j_space_time_percent,
      "wh_classes_active" => wh_classes_active,
      "home_holes" => home_holes,
      "rolling_participation" => rolling_participation,
      "wh_scanning_skills" => scanning_skills
    }

    {:ok, activity}
  end

  # Eviction group detection
  defp analyze_eviction_associations(character_id) do
    # Known eviction groups (this would be configurable in a real system)
    known_eviction_groups = [
      "Hard Knocks Citizens",
      "Lazerhawks",
      "No Holes Barred",
      "Mouth Trumpet Cavalry",
      "Inner Hell"
    ]

    eviction_participation = analyze_eviction_participation(character_id, known_eviction_groups)
    seed_scout_indicators = analyze_seed_scout_patterns(character_id)

    associations = %{
      "known_eviction_groups" =>
        find_eviction_group_connections(character_id, known_eviction_groups),
      "eviction_participation" => eviction_participation,
      "seed_scout_indicators" => seed_scout_indicators
    }

    {:ok, associations}
  end

  # Alt character analysis
  defp analyze_alt_patterns(character_id) do
    potential_alts = find_potential_alts(character_id)
    character_bazaar_indicators = analyze_character_bazaar_signs(character_id)

    # Get character creation date and age
    account_age = calculate_account_age(character_id)
    main_confidence = assess_main_character_confidence(character_id, potential_alts)

    analysis = %{
      "potential_alts" => potential_alts,
      "main_character_confidence" => main_confidence,
      "account_age_days" => account_age,
      "character_bazaar_indicators" => character_bazaar_indicators
    }

    {:ok, analysis}
  end

  # Small gang competency analysis
  defp analyze_small_gang_competency(character_id) do
    gang_performance = analyze_small_gang_performance(character_id)
    ship_specializations = analyze_ship_specializations(character_id)
    wh_specific_skills = assess_wh_skills(character_id)

    competency = %{
      "small_gang_performance" => gang_performance,
      "ship_specializations" => ship_specializations,
      "wh_specific_skills" => wh_specific_skills
    }

    {:ok, competency}
  end

  # Risk factor analysis
  defp analyze_risk_factors(character_id) do
    security_flags = identify_security_flags(character_id)
    behavioral_flags = identify_behavioral_red_flags(character_id)
    awox_risk = assess_awox_risk(character_id, security_flags, behavioral_flags)
    spy_risk = assess_spy_risk(character_id, security_flags, behavioral_flags)

    risks = %{
      "security_flags" => security_flags,
      "behavioral_red_flags" => behavioral_flags,
      "awox_risk" => awox_risk,
      "spy_risk" => spy_risk
    }

    {:ok, risks}
  end

  # Employment history analysis
  defp analyze_employment_history(character_id) do
    case EsiClient.get_character_employment_history(character_id) do
      {:error, reason} ->
        Logger.warning(
          "Could not fetch employment history for character #{character_id}: #{inspect(reason)}"
        )

        # Return fallback employment history data
        {:ok,
         %{
           "corp_changes" => 0,
           "avg_tenure_days" => 0,
           "suspicious_patterns" => ["Unable to verify employment history"],
           "history" => []
         }}
    end
  end

  # Helper functions for specific analyses
  defp get_j_space_killmails(character_id, type) do
    # Query actual J-space killmails for the character
    cutoff_date = DateTime.add(DateTime.utc_now(), -365, :day)

    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        participants
        |> Enum.filter(fn p ->
          km = p.killmail_enriched

          km && j_space_system?(km.solar_system_id) &&
            case type do
              :kills -> not p.is_victim
              :losses -> p.is_victim
            end
        end)
        |> Enum.map(& &1.killmail_enriched)
        |> Enum.uniq_by(& &1.killmail_id)

      {:error, reason} ->
        Logger.error("Failed to get J-space killmails: #{inspect(reason)}")
        []
    end
  rescue
    error ->
      Logger.error("Error getting J-space killmails: #{inspect(error)}")
      []
  end

  defp get_total_killmails(character_id, type) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -365, :day)

    participant_query =
      case type do
        :kills ->
          Participant
          |> Ash.Query.new()
          |> Ash.Query.filter(character_id == ^character_id)
          |> Ash.Query.filter(updated_at >= ^cutoff_date)
          |> Ash.Query.filter(is_victim == false)

        :losses ->
          Participant
          |> Ash.Query.new()
          |> Ash.Query.filter(character_id == ^character_id)
          |> Ash.Query.filter(updated_at >= ^cutoff_date)
          |> Ash.Query.filter(is_victim == true)
      end

    case Ash.count(participant_query, domain: Api) do
      {:ok, count} ->
        count

      {:error, reason} ->
        Logger.error("Failed to count killmails: #{inspect(reason)}")
        0
    end
  rescue
    error ->
      Logger.error("Error counting killmails: #{inspect(error)}")
      0
  end

  # Currently unused but may be useful for future eviction detection
  # defp has_character_participation?(killmail, character_id, role) do
  #   case Ash.read(Participant, domain: Api) do
  #     {:ok, participants} ->
  #       relevant_participants =
  #         Enum.filter(participants, fn p -> p.killmail_id == killmail.killmail_id end)

  #       Enum.any?(relevant_participants, fn p ->
  #         p.character_id == character_id and
  #           ((role == :attacker and not p.is_victim) or (role == :victim and p.is_victim))
  #       end)

  #     {:error, _} ->
  #       false
  #   end
  # rescue
  #   _ -> false
  # end

  defp j_space_system?(system_id) do
    # Wormhole systems typically have IDs in the 31000000+ range
    # This is a simplified check - in production you'd check against static data
    system_id >= 31_000_000
  end

  defp calculate_j_space_time_percentage(j_space_kms, total_kms) do
    if total_kms > 0 do
      Float.round(length(j_space_kms) / total_kms * 100, 1)
    else
      0.0
    end
  end

  defp extract_wh_classes(killmails) do
    # Extract wormhole classes from system IDs
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.uniq()
    |> Enum.map(&determine_wh_class/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp determine_wh_class(system_id) do
    # Determine WH class based on system ID ranges
    # This is a simplified mapping - real implementation would use static data

    # Special cases first
    if system_id == 31_000_005, do: "thera", else: check_wh_class_range(system_id)
  end

  defp check_wh_class_range(system_id) when system_id >= 31_000_000 and system_id < 31_007_000 do
    # Calculate class based on range
    class_number = div(system_id - 31_000_000, 1000) + 1

    case class_number do
      n when n in 1..6 -> n
      7 -> "shattered"
      _ -> nil
    end
  end

  defp check_wh_class_range(_system_id), do: nil

  defp identify_home_holes(killmails) do
    # Identify likely home wormhole systems based on activity patterns
    killmails
    |> Enum.filter(&j_space_system?(&1.solar_system_id))
    |> Enum.group_by(&{&1.solar_system_id, &1.solar_system_name})
    |> Enum.map(fn {{system_id, system_name}, system_kms} ->
      # Calculate home hole indicators
      total_activity = length(system_kms)

      # Group by month to see consistency
      monthly_activity =
        system_kms
        |> Enum.group_by(fn km ->
          {km.killmail_time.year, km.killmail_time.month}
        end)
        |> map_size()

      # Time spread (days between first and last activity)
      time_spread =
        case system_kms
             |> Enum.map(& &1.killmail_time)
             |> Enum.min_max() do
          {oldest, newest} ->
            DateTime.diff(newest, oldest, :day)

          :error ->
            0
        end

      # Home hole score based on activity density and consistency
      score = total_activity * monthly_activity / max(1, time_spread / 30)

      %{
        system_id: system_id,
        system_name: system_name || "J#{rem(system_id, 100_000)}",
        activity_count: total_activity,
        months_active: monthly_activity,
        home_score: Float.round(score, 2)
      }
    end)
    |> Enum.sort_by(& &1.home_score, :desc)
    |> Enum.take(3)
  end

  defp analyze_rolling_patterns(character_id) do
    # Analyze participation in wormhole rolling activities
    cutoff_date = DateTime.add(DateTime.utc_now(), -180, :day)

    # Get killmails where character was involved
    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        # Group by system and time to identify rolling patterns
        rolling_events =
          participants
          |> Enum.filter(fn p ->
            p.killmail_enriched && j_space_system?(p.killmail_enriched.solar_system_id)
          end)
          |> Enum.group_by(fn p ->
            # Group by system and hour
            km = p.killmail_enriched
            {km.solar_system_id, %{km.killmail_time | minute: 0, second: 0, microsecond: {0, 6}}}
          end)
          |> Enum.filter(fn {_key, group} ->
            # Multiple kills in same system/hour suggests rolling
            length(group) >= 3
          end)

        # Check for rolling ship usage (high mass ships)
        rolling_ships = ["Megathron", "Armageddon", "Scorpion", "Hyperion", "Abaddon", "Rokh"]

        times_in_rolling_ship =
          participants
          |> Enum.count(fn p ->
            p.ship_name in rolling_ships
          end)

        %{
          "times_rolled" => length(rolling_events),
          "times_helped_roll" => times_in_rolling_ship,
          "rolling_competency" =>
            if times_in_rolling_ship > 0 do
              min(1.0, times_in_rolling_ship / 10)
            else
              0.0
            end
        }

      {:error, _} ->
        %{
          "times_rolled" => 0,
          "times_helped_roll" => 0,
          "rolling_competency" => 0.0
        }
    end
  end

  defp analyze_scanning_patterns(killmails) do
    # Analyze probe usage and scanning competency from ship usage and activity patterns
    scanning_ships = [
      "Astero",
      "Stratios",
      "Anathema",
      "Buzzard",
      "Cheetah",
      "Helios",
      "Tengu",
      "Proteus",
      "Legion",
      "Loki"
    ]

    # Count scanning ship usage
    scanning_activity =
      killmails
      |> Enum.filter(fn km ->
        ship_name = km.ship_type_name || ""
        Enum.any?(scanning_ships, &String.contains?(ship_name, &1))
      end)
      |> length()

    total_killmails = length(killmails)

    # Calculate probe usage percentage
    probe_usage =
      if total_killmails > 0 do
        min(100, round(scanning_activity / total_killmails * 100))
      else
        0
      end

    # Estimate scan success rate based on scanning ship survival
    scanning_losses =
      killmails
      |> Enum.filter(fn km ->
        ship_name = km.ship_type_name || ""
        km.is_victim && Enum.any?(scanning_ships, &String.contains?(ship_name, &1))
      end)
      |> length()

    scan_success_rate =
      if scanning_activity > 0 do
        survival_rate = (scanning_activity - scanning_losses) / scanning_activity
        Float.round(max(0.0, survival_rate), 2)
      else
        0.0
      end

    # Deep safe usage indicator - T3 cruiser or cloaky ship usage suggests advanced scanning
    deep_safe_usage =
      killmails
      |> Enum.any?(fn km ->
        ship_name = km.ship_type_name || ""

        String.contains?(ship_name, "Tengu") or
          String.contains?(ship_name, "Proteus") or
          String.contains?(ship_name, "Legion") or
          String.contains?(ship_name, "Loki") or
          String.contains?(ship_name, "Astero") or
          String.contains?(ship_name, "Stratios")
      end)

    %{
      "probe_usage" => probe_usage,
      "scan_success_rate" => scan_success_rate,
      "deep_safe_usage" => deep_safe_usage
    }
  end

  defp find_eviction_group_connections(character_id, known_groups) do
    # Check for connections to known eviction groups through shared killmails
    # 2 years
    cutoff_date = DateTime.add(DateTime.utc_now(), -730, :day)

    # Get all killmails involving this character
    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        # Get all killmail IDs
        killmail_ids =
          participants
          |> Enum.map(& &1.killmail_id)
          |> Enum.uniq()

        # Find other participants in those killmails
        co_participants_query =
          Participant
          |> Ash.Query.new()
          |> Ash.Query.filter(killmail_id in ^killmail_ids)
          |> Ash.Query.filter(character_id != ^character_id)

        case Ash.read(co_participants_query, domain: Api) do
          {:ok, co_participants} ->
            # Check for eviction group members
            co_participants
            |> Enum.filter(fn p ->
              p.corporation_name in known_groups or
                p.alliance_name in known_groups
            end)
            |> Enum.group_by(fn p ->
              p.corporation_name || p.alliance_name
            end)
            |> Enum.map(fn {group, members} ->
              %{
                group_name: group,
                shared_killmails: length(members),
                first_interaction: members |> Enum.map(& &1.updated_at) |> Enum.min(DateTime),
                last_interaction: members |> Enum.map(& &1.updated_at) |> Enum.max(DateTime)
              }
            end)

          {:error, _} ->
            []
        end

      {:error, _} ->
        []
    end
  end

  defp analyze_eviction_participation(character_id, _known_groups) do
    # Analyze character's participation in eviction activities
    # 2 years
    cutoff_date = DateTime.add(DateTime.utc_now(), -730, :day)

    # Get all J-space killmails
    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        # Filter for J-space activity
        j_space_activity =
          participants
          |> Enum.filter(fn p ->
            p.killmail_enriched && j_space_system?(p.killmail_enriched.solar_system_id)
          end)

        # Group by victim corporation to identify potential evictions
        victim_corps =
          j_space_activity
          # Character was attacker
          |> Enum.filter(fn p -> not p.is_victim end)
          |> Enum.map(fn p ->
            # Find victim in same killmail
            victim = find_victim_in_killmail(p.killmail_enriched)

            {victim["corporation_id"], victim["corporation_name"],
             p.killmail_enriched.killmail_time}
          end)
          |> Enum.reject(fn {corp_id, _, _} -> is_nil(corp_id) end)
          |> Enum.group_by(fn {corp_id, corp_name, _} -> {corp_id, corp_name} end)
          |> Enum.map(fn {{corp_id, corp_name}, kills} ->
            # Count kills over time to identify eviction patterns
            kill_times = Enum.map(kills, fn {_, _, time} -> time end)
            {first_kill, last_kill} = Enum.min_max_by(kill_times, & &1, DateTime)
            duration_hours = DateTime.diff(last_kill, first_kill, :hour)

            %{
              corporation_id: corp_id,
              corporation_name: corp_name || "Unknown",
              kill_count: length(kills),
              duration_hours: duration_hours,
              # Eviction pattern: many kills in short time
              # 7 days
              likely_eviction: length(kills) >= 10 and duration_hours <= 168
            }
          end)
          |> Enum.filter(& &1.likely_eviction)

        # Determine typical role based on ship usage in evictions
        eviction_ships =
          j_space_activity
          |> Enum.filter(fn p ->
            not p.is_victim and
              Enum.any?(victim_corps, fn vc ->
                victim = find_victim_in_killmail(p.killmail_enriched)
                victim["corporation_id"] == vc.corporation_id
              end)
          end)
          |> Enum.map(& &1.ship_name)
          |> Enum.frequencies()

        typical_role = determine_eviction_role(eviction_ships)

        %{
          "evictions_involved" => length(victim_corps),
          # Top 5
          "victim_corps" => Enum.take(victim_corps, 5),
          "typical_role" => typical_role
        }

      {:error, _} ->
        %{
          "evictions_involved" => 0,
          "victim_corps" => [],
          "typical_role" => "unknown"
        }
    end
  end

  defp find_victim_in_killmail(killmail) do
    participants = killmail.participants || []

    victim = Enum.find(participants, & &1.is_victim)

    if victim do
      %{
        "character_id" => victim.character_id,
        "character_name" => victim.character_name,
        "corporation_id" => victim.corporation_id,
        "corporation_name" => victim.corporation_name
      }
    else
      %{}
    end
  end

  defp determine_eviction_role(ship_frequencies) do
    cond do
      # Structure bashers
      Enum.any?(ship_frequencies, fn {ship, _} ->
        String.contains?(ship || "", ["Oracle", "Talos", "Naga", "Tornado"])
      end) ->
        "structure_basher"

      # Hole control
      Enum.any?(ship_frequencies, fn {ship, _} ->
        String.contains?(ship || "", ["Devoter", "Phobos", "Onyx", "Broadsword"])
      end) ->
        "hole_control"

      # Hunter killer
      Enum.any?(ship_frequencies, fn {ship, _} ->
        String.contains?(ship || "", ["Sabre", "Loki", "Proteus", "Legion"])
      end) ->
        "hunter_killer"

      # Support
      Enum.any?(ship_frequencies, fn {ship, _} ->
        String.contains?(ship || "", ["Guardian", "Oneiros", "Scimitar", "Basilisk"])
      end) ->
        "support"

      true ->
        "dps"
    end
  end

  defp analyze_seed_scout_patterns(_character_id) do
    # Analyze patterns that might indicate seed/scout behavior
    # ESI employment history is currently unavailable, return default values
    %{
      "suspicious_applications" => 0,
      "timing_patterns" => [],
      "information_gathering" => false
    }
  end

  defp find_potential_alts(character_id) do
    # Find potential alt characters based on activity patterns
    # This is a simplified implementation - real detection would be more sophisticated

    # Get character's killmails to find associates
    cutoff_date = DateTime.add(DateTime.utc_now(), -365, :day)

    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        # Find characters that appear frequently together
        killmail_ids =
          participants
          |> Enum.map(& &1.killmail_id)
          |> Enum.uniq()

        # Get all participants in those killmails
        co_participants_query =
          Participant
          |> Ash.Query.new()
          |> Ash.Query.filter(killmail_id in ^killmail_ids)
          |> Ash.Query.filter(character_id != ^character_id)
          # Only attackers
          |> Ash.Query.filter(is_victim == false)

        case Ash.read(co_participants_query, domain: Api) do
          {:ok, co_participants} ->
            # Find characters that appear together frequently
            potential_alts =
              co_participants
              |> Enum.group_by(& &1.character_id)
              |> Enum.map(fn {char_id, appearances} ->
                %{
                  character_id: char_id,
                  character_name: List.first(appearances).character_name,
                  shared_killmails: length(appearances),
                  # High correlation suggests alt
                  correlation_score: length(appearances) / max(1, length(killmail_ids))
                }
              end)
              |> Enum.filter(fn alt ->
                # High correlation and significant activity
                alt.correlation_score > 0.7 and alt.shared_killmails > 10
              end)
              |> Enum.sort_by(& &1.correlation_score, :desc)
              |> Enum.take(5)

            potential_alts

          _ ->
            []
        end

      _ ->
        []
    end
  end

  defp analyze_character_bazaar_signs(character_id) do
    # Analyze signs that character might have been purchased on character bazaar

    # Get character info and history
    case EsiClient.get_character(character_id) do
      {:ok, character_data} ->
        character_name = character_data["name"]

        # Check for name patterns common in bazaar characters
        name_patterns = analyze_character_name(character_name)

        # Get employment history to check for gaps
        employment_gaps = []

        # Check skill patterns (would need authenticated access)
        # For now, we'll check killmail activity patterns
        skill_inconsistencies = detect_skill_inconsistencies(character_id)

        # Likely purchased if multiple indicators present
        likely_purchased =
          length(name_patterns) > 0 or
            length(employment_gaps) > 0 or
            length(skill_inconsistencies) > 0

        %{
          "likely_purchased" => likely_purchased,
          "skill_inconsistencies" => skill_inconsistencies,
          "name_history" => name_patterns
        }

      _ ->
        %{
          "likely_purchased" => false,
          "skill_inconsistencies" => [],
          "name_history" => []
        }
    end
  end

  defp analyze_character_name(name) when is_binary(name) do
    patterns = []

    # Common bazaar naming patterns
    patterns =
      if Regex.match?(~r/^[A-Z][a-z]+\s\d+$/, name) do
        ["generic_name_with_number" | patterns]
      else
        patterns
      end

    patterns =
      if String.length(name) < 6 do
        ["unusually_short_name" | patterns]
      else
        patterns
      end

    patterns =
      if Regex.match?(~r/\d{4,}/, name) do
        ["multiple_numbers_in_name" | patterns]
      else
        patterns
      end

    patterns
  end

  defp analyze_character_name(_), do: []

  defp detect_skill_inconsistencies(character_id) do
    # Detect skill inconsistencies from killmail patterns
    # Characters that suddenly fly ships requiring high SP after long inactivity

    # 2 years
    cutoff_date = DateTime.add(DateTime.utc_now(), -730, :day)

    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.sort(updated_at: :asc)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        # Group ships by time periods
        ship_progression =
          participants
          |> Enum.group_by(fn p ->
            # Group by 6-month periods
            date = p.updated_at
            {date.year, div(date.month - 1, 6)}
          end)
          |> Enum.map(fn {period, period_participants} ->
            ships =
              period_participants
              |> Enum.map(& &1.ship_name)
              |> Enum.uniq()
              |> Enum.reject(&is_nil/1)

            {period, ships}
          end)
          |> Enum.sort()

        # Look for sudden jumps in ship complexity
        detect_ship_progression_anomalies(ship_progression)

      _ ->
        []
    end
  end

  defp detect_ship_progression_anomalies(ship_progression) do
    # Simple detection of unusual progression
    anomalies = []

    # Check if character jumped from T1 frigates to capitals
    has_frigate_period =
      Enum.any?(ship_progression, fn {_, ships} ->
        Enum.any?(
          ships,
          &String.contains?(&1 || "", ["Rifter", "Merlin", "Punisher", "Incursus"])
        )
      end)

    has_capital_period =
      Enum.any?(ship_progression, fn {_, ships} ->
        Enum.any?(ships, &String.contains?(&1 || "", ["Carrier", "Dreadnought", "Titan"]))
      end)

    if has_frigate_period and has_capital_period and length(ship_progression) < 4 do
      ["rapid_skill_progression" | anomalies]
    else
      anomalies
    end
  end

  defp calculate_account_age(character_id) do
    # Calculate days since character creation using ESI data
    case EsiClient.get_character(character_id) do
      {:ok, character_data} ->
        birthday_str = character_data["birthday"]

        if birthday_str do
          case DateTime.from_iso8601(birthday_str) do
            {:ok, birthday, _} ->
              DateTime.diff(DateTime.utc_now(), birthday, :day)

            _ ->
              # Fallback
              365
          end
        else
          365
        end

      _ ->
        # Fallback if ESI fails
        365
    end
  end

  defp assess_main_character_confidence(character_id, potential_alts) do
    # Assess confidence that this is the main character based on various factors
    case CharacterStats.get_by_character_id(character_id) do
      {:ok, [stats]} ->
        # Calculate confidence based on activity level, age, and alt patterns
        activity_score = min(1.0, (stats.total_kills + stats.total_losses) / 100.0)

        # Main characters typically have more diverse activity
        diversity_score = calculate_activity_diversity(stats)

        # Check if character name/creation patterns suggest it's an alt
        alt_indicators = length(potential_alts)
        alt_penalty = min(0.3, alt_indicators * 0.1)

        # Combine factors
        base_confidence = activity_score * 0.4 + diversity_score * 0.4 + 0.2
        final_confidence = max(0.1, base_confidence - alt_penalty)

        Float.round(final_confidence, 2)

      {:ok, []} ->
        # No character stats available, lower confidence
        0.3

      {:error, _} ->
        0.4
    end
  end

  defp calculate_activity_diversity(stats) do
    # Calculate diversity score based on various activity metrics
    ship_diversity =
      if stats.ship_usage && map_size(stats.ship_usage) > 0 do
        # More ship types used = higher diversity
        min(1.0, map_size(stats.ship_usage) / 10.0)
      else
        0.2
      end

    # Geographic diversity (if available)
    geo_diversity =
      if stats.most_active_regions && length(stats.most_active_regions) > 0 do
        min(1.0, length(stats.most_active_regions) / 5.0)
      else
        0.3
      end

    # Average the diversity metrics
    (ship_diversity + geo_diversity) / 2.0
  end

  defp analyze_small_gang_performance(character_id) do
    case get_or_create_character_stats(character_id) do
      stats ->
        %{
          "avg_gang_size" => stats.avg_gang_size || 1.0,
          "preferred_size" => determine_preferred_gang_size(stats.avg_gang_size || 1.0),
          # Would be determined from ship usage
          "role_flexibility" => ["dps"],
          "fc_experience" => %{"times_fc" => 0, "success_rate" => 0.0}
        }
    end
  end

  defp determine_preferred_gang_size(avg_size) do
    cond do
      avg_size <= 1.5 -> "solo"
      avg_size <= 3.0 -> "2-3"
      avg_size <= 8.0 -> "small_gang"
      avg_size <= 15.0 -> "medium_gang"
      true -> "large_gang"
    end
  end

  defp analyze_ship_specializations(character_id) do
    stats = get_or_create_character_stats(character_id)

    primary_classes = extract_primary_ship_classes(stats.ship_usage || %{})

    %{
      "primary_classes" => primary_classes,
      "doctrine_familiarity" => ["unknown"],
      "capital_experience" => stats.flies_capitals || false
    }
  end

  defp extract_primary_ship_classes(ship_usage) do
    # Analyze ship usage to determine primary classes
    if map_size(ship_usage) == 0 do
      ["unknown"]
    else
      # Sort ship usage by frequency and extract primary classes
      ship_usage
      |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
      # Top 3 most used ship types
      |> Enum.take(3)
      |> Enum.map(fn {ship_type, _count} ->
        classify_ship_class(ship_type)
      end)
      |> Enum.uniq()
    end
  end

  defp classify_ship_class(ship_type) do
    # Convert ship type names to general classes
    downcased = String.downcase(ship_type)

    ship_class_mappings()
    |> Enum.find_value("other", fn {keywords, class} ->
      if Enum.any?(keywords, &String.contains?(downcased, &1)), do: class
    end)
  end

  defp ship_class_mappings do
    [
      {["frigate", "interceptor", "assault", "stealth"], "frigates"},
      {["destroyer"], "destroyers"},
      {["battlecruiser"], "battlecruisers"},
      {["battleship"], "battleships"},
      {["industrial"], "industrials"},
      {["logistics"], "logistics"},
      {["command"], "command_ships"},
      {["cruiser", "strategic", "heavy assault", "recon"], "cruisers"}
    ]
  end

  defp assess_wh_skills(character_id) do
    # Assess WH-relevant skills based on ship usage patterns and activity
    case get_or_create_character_stats(character_id) do
      stats ->
        ship_usage = stats.ship_usage || %{}

        # Infer skills from ship usage patterns
        scanning_skill = estimate_scanning_skill(ship_usage, stats)
        cloaking_skill = estimate_cloaking_skill(ship_usage)
        covops_skill = estimate_covops_skill(ship_usage)
        t3_skill = estimate_t3_skill(ship_usage)

        %{
          "probe_scanning" => scanning_skill,
          "cloaking" => cloaking_skill,
          "covops" => covops_skill,
          "t3_cruisers" => t3_skill
        }
    end
  end

  defp estimate_scanning_skill(ship_usage, stats) do
    # Estimate scanning skill based on exploration activity and ship usage
    exploration_ships = ["Astero", "Stratios", "Anathema", "Buzzard", "Cheetah", "Helios"]

    exploration_usage =
      ship_usage
      |> Enum.filter(fn {ship, _} ->
        Enum.any?(exploration_ships, &String.contains?(ship, &1))
      end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    # Higher exploration ship usage suggests better scanning skills
    base_skill = min(5, exploration_usage / 10)

    # Bonus for overall experience
    experience_bonus = if stats.total_kills + stats.total_losses > 100, do: 1, else: 0

    round(base_skill + experience_bonus)
  end

  defp estimate_cloaking_skill(ship_usage) do
    # Estimate cloaking skill based on cloaky ship usage
    cloaky_ships = ["Astero", "Stratios", "Pilgrim", "Falcon", "Rook", "Blackbird", "Recon"]

    cloaky_usage =
      ship_usage
      |> Enum.filter(fn {ship, _} ->
        Enum.any?(cloaky_ships, &String.contains?(ship, &1))
      end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    min(5, cloaky_usage / 15)
  end

  defp estimate_covops_skill(ship_usage) do
    # Estimate covert ops skill based on covops ship usage
    covops_ships = [
      "Anathema",
      "Buzzard",
      "Cheetah",
      "Helios",
      "Pilgrim",
      "Falcon",
      "Rook",
      "Arazu"
    ]

    covops_usage =
      ship_usage
      |> Enum.filter(fn {ship, _} ->
        Enum.any?(covops_ships, &String.contains?(ship, &1))
      end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    min(5, covops_usage / 20)
  end

  defp estimate_t3_skill(ship_usage) do
    # Estimate T3 cruiser skill based on T3 ship usage
    t3_ships = ["Legion", "Loki", "Proteus", "Tengu"]

    t3_usage =
      ship_usage
      |> Enum.filter(fn {ship, _} ->
        Enum.any?(t3_ships, &String.contains?(ship, &1))
      end)
      |> Enum.map(fn {_, count} -> count end)
      |> Enum.sum()

    min(5, t3_usage / 25)
  end

  defp identify_security_flags(character_id) do
    # Identify security-related red flags
    flags = []

    # Check character stats if available
    case get_or_create_character_stats(character_id) do
      stats when not is_nil(stats) ->
        flags =
          flags
          |> maybe_add_flag(
            stats.dangerous_rating > 8,
            "high_threat_rating"
          )
          |> maybe_add_flag(
            stats.awox_probability > 0.3,
            "awox_history"
          )
          |> maybe_add_flag(
            stats.npc_corp_time > 0.8,
            "excessive_npc_corp_time"
          )

        # Check employment history for rapid corp changes
        # Currently not implemented - would analyze corp changes here
        flags

      _ ->
        flags
    end
  end

  defp maybe_add_flag(flags, true, flag), do: [flag | flags]
  defp maybe_add_flag(flags, false, _flag), do: flags

  defp identify_behavioral_red_flags(character_id) do
    # Identify behavioral patterns that might indicate risk
    flags = []

    # Get recent activity patterns
    cutoff_date = DateTime.add(DateTime.utc_now(), -90, :day)

    participant_query =
      Participant
      |> Ash.Query.new()
      |> Ash.Query.filter(character_id == ^character_id)
      |> Ash.Query.filter(updated_at >= ^cutoff_date)
      |> Ash.Query.load(:killmail_enriched)

    case Ash.read(participant_query, domain: Api) do
      {:ok, participants} ->
        # Check for suspicious patterns

        # 1. Excessive structure bashing
        structure_kills =
          participants
          |> Enum.filter(fn p ->
            not p.is_victim and
              p.killmail_enriched &&
              String.contains?(p.ship_name || "", ["Citadel", "Engineering", "Refinery"])
          end)
          |> length()

        flags = maybe_add_flag(flags, structure_kills > 20, "structure_basher")

        # 2. Blue killing patterns
        same_alliance_kills =
          participants
          |> Enum.filter(fn p ->
            not p.is_victim and
              p.killmail_enriched &&
              Enum.any?(p.killmail_enriched.participants || [], fn victim ->
                victim.is_victim and
                  victim.alliance_id == p.alliance_id and
                  victim.alliance_id != nil
              end)
          end)
          |> length()

        flags = maybe_add_flag(flags, same_alliance_kills > 0, "blue_killer")

        # 3. Exclusively highsec activity
        highsec_only =
          participants
          |> Enum.all?(fn p ->
            # Not J-space
            p.killmail_enriched &&
              p.killmail_enriched.solar_system_id < 31_000_000
          end)

        flags = maybe_add_flag(flags, highsec_only, "no_wh_experience")

        flags

      {:error, _} ->
        flags
    end
  end

  defp assess_awox_risk(character_id, security_flags, behavioral_flags) do
    # Assess AWOX (attacking own teammates) risk based on behavior patterns
    indicators = []
    base_probability = 0.05

    # Check for blue killer behavior
    indicators =
      if "blue_killer" in behavioral_flags do
        ["Previously killed friendly targets" | indicators]
      else
        indicators
      end

    # Check for high threat rating
    indicators =
      if "high_threat" in security_flags do
        ["High threat character profile" | indicators]
      else
        indicators
      end

    # Check employment history for corp hopping
    {indicators, base_probability} =
      case get_or_create_character_stats(character_id) do
        stats ->
          employment_changes = stats.corp_changes || 0

          if employment_changes > 5 do
            {["Frequent corporation changes (#{employment_changes})" | indicators],
             base_probability + 0.1}
          else
            {indicators, base_probability}
          end
      end

    # Calculate final probability
    risk_modifiers = length(indicators) * 0.05
    final_probability = min(0.8, base_probability + risk_modifiers)

    # Determine mitigations based on risk level
    mitigations =
      cond do
        final_probability > 0.3 -> ["reject_application", "too_high_risk"]
        final_probability > 0.15 -> ["probation_period", "limited_roles", "close_monitoring"]
        final_probability > 0.05 -> ["limited_roles", "probation_period"]
        true -> ["standard_vetting"]
      end

    %{
      "probability" => Float.round(final_probability, 2),
      "indicators" => indicators,
      "mitigations" => mitigations
    }
  end

  defp assess_spy_risk(character_id, security_flags, behavioral_flags) do
    # Assess espionage risk based on character patterns and history
    base_probability = 0.08

    # Collect all risk indicators
    behavioral_indicators = collect_behavioral_indicators(behavioral_flags)
    security_indicators = collect_security_indicators(security_flags)

    # Check character age and experience
    {age_indicators, age_probability_modifier} = assess_character_age_risk(character_id)

    # Combine all indicators
    all_indicators = behavioral_indicators ++ security_indicators ++ age_indicators

    # Calculate final probability
    risk_modifiers = length(all_indicators) * 0.1
    final_probability = min(0.9, base_probability + age_probability_modifier + risk_modifiers)

    # Determine mitigations based on risk level
    mitigations = determine_spy_risk_mitigations(final_probability)

    %{
      "probability" => Float.round(final_probability, 2),
      "indicators" => all_indicators,
      "mitigations" => mitigations
    }
  end

  defp collect_behavioral_indicators(behavioral_flags) do
    indicators = []

    indicators =
      if "seed_scout" in behavioral_flags do
        ["Potential seed scout behavior detected" | indicators]
      else
        indicators
      end

    if "infiltration_patterns" in behavioral_flags do
      ["Infiltration activity patterns detected" | indicators]
    else
      indicators
    end
  end

  defp collect_security_indicators(security_flags) do
    if "conflict_corp_hopping" in security_flags do
      ["Corporation changes during conflict periods"]
    else
      []
    end
  end

  defp assess_character_age_risk(character_id) do
    case get_or_create_character_stats(character_id) do
      stats ->
        char_age_days = stats.character_age_days || 365
        total_activity = (stats.total_kills || 0) + (stats.total_losses || 0)

        cond do
          # Young character with limited activity could be spy alt
          char_age_days < 90 and total_activity < 10 ->
            {["Young character with minimal activity"], 0.15}

          # Very experienced character with no clear progression could be purchased
          char_age_days > 1000 and total_activity < 50 ->
            {["Experienced character with minimal recent activity"], 0.1}

          true ->
            {[], 0.0}
        end
    end
  end

  defp determine_spy_risk_mitigations(final_probability) do
    cond do
      final_probability > 0.4 ->
        ["reject_application", "too_high_risk"]

      final_probability > 0.25 ->
        ["information_compartmentalization", "no_critical_roles", "background_verification"]

      final_probability > 0.15 ->
        ["information_compartmentalization", "gradual_access_increase"]

      true ->
        ["standard_information_security"]
    end
  end

  # Scoring calculations
  defp calculate_scores(
         j_space_activity,
         eviction_associations,
         alt_analysis,
         competency_metrics,
         risk_factors,
         employment_history
       ) do
    wh_experience_score = calculate_wh_experience_score(j_space_activity, employment_history)
    competency_score = calculate_competency_score(competency_metrics, j_space_activity)
    security_score = calculate_security_score(risk_factors, eviction_associations, alt_analysis)

    overall_risk_score =
      calculate_overall_risk_score(security_score, wh_experience_score, competency_score)

    %{
      wh_experience_score: wh_experience_score,
      competency_score: competency_score,
      security_score: security_score,
      overall_risk_score: overall_risk_score
    }
  end

  defp calculate_wh_experience_score(j_space_activity, _employment_history) do
    j_kills = j_space_activity["total_j_kills"] || 0
    j_losses = j_space_activity["total_j_losses"] || 0
    j_time_percent = j_space_activity["j_space_time_percent"] || 0.0
    wh_classes = length(j_space_activity["wh_classes_active"] || [])

    base_score = min(90, j_kills * 2 + j_losses)
    time_bonus = min(20, j_time_percent / 5)
    class_bonus = min(15, wh_classes * 3)

    round(base_score + time_bonus + class_bonus)
  end

  defp calculate_competency_score(competency_metrics, j_space_activity) do
    gang_perf = competency_metrics["small_gang_performance"] || %{}
    ship_specs = competency_metrics["ship_specializations"] || %{}
    wh_skills = competency_metrics["wh_specific_skills"] || %{}

    avg_gang_size = gang_perf["avg_gang_size"] || 1.0
    primary_classes = length(ship_specs["primary_classes"] || [])
    skill_levels = Enum.sum(Map.values(wh_skills))

    # Small gang focused scoring
    gang_score =
      cond do
        avg_gang_size >= 2.0 and avg_gang_size <= 8.0 -> 30
        avg_gang_size > 1.0 -> 20
        true -> 10
      end

    ship_score = min(25, primary_classes * 8)
    skill_score = min(25, skill_levels * 3)
    activity_score = min(20, (j_space_activity["total_j_kills"] || 0) / 5)

    round(gang_score + ship_score + skill_score + activity_score)
  end

  defp calculate_security_score(risk_factors, eviction_associations, alt_analysis) do
    security_flags = length(risk_factors["security_flags"] || [])
    behavioral_flags = length(risk_factors["behavioral_red_flags"] || [])
    eviction_groups = length(eviction_associations["known_eviction_groups"] || [])
    awox_risk = risk_factors["awox_risk"]["probability"] || 0.1
    spy_risk = risk_factors["spy_risk"]["probability"] || 0.1
    main_confidence = alt_analysis["main_character_confidence"] || 0.8

    base_score = 100
    penalty = security_flags * 15 + behavioral_flags * 10 + eviction_groups * 20
    risk_penalty = (awox_risk + spy_risk) * 50
    alt_penalty = (1.0 - main_confidence) * 30

    max(0, round(base_score - penalty - risk_penalty - alt_penalty))
  end

  defp calculate_overall_risk_score(security_score, wh_experience_score, competency_score) do
    # Lower risk score is better
    base_risk = 100 - security_score
    experience_reduction = wh_experience_score / 5
    competency_reduction = competency_score / 10

    max(0, round(base_risk - experience_reduction - competency_reduction))
  end

  # Recommendation generation
  defp generate_recommendation(scores, _risk_factors) do
    %{
      overall_risk_score: risk,
      wh_experience_score: exp,
      competency_score: comp,
      security_score: sec
    } = scores

    cond do
      sec < 40 or risk > 80 ->
        %{decision: "reject", confidence: 0.9, requires_manual_review: false}

      exp > 70 and comp > 60 and sec > 70 ->
        %{decision: "approve", confidence: 0.8, requires_manual_review: false}

      exp > 40 and comp > 40 and sec > 60 ->
        %{decision: "conditional", confidence: 0.7, requires_manual_review: true}

      true ->
        %{decision: "more_info", confidence: 0.5, requires_manual_review: true}
    end
  end

  defp generate_auto_summary(character_info, scores, _risk_factors) do
    experience_level =
      case scores.wh_experience_score do
        score when score >= 70 -> "experienced"
        score when score >= 40 -> "competent"
        score when score >= 20 -> "novice"
        _ -> "minimal"
      end

    risk_level =
      case scores.overall_risk_score do
        score when score >= 70 -> "high"
        score when score >= 40 -> "medium"
        _ -> "low"
      end

    "#{character_info.character_name} shows #{experience_level} wormhole experience with #{risk_level} security risk. " <>
      "WH Experience: #{scores.wh_experience_score}/100, Competency: #{scores.competency_score}/100, " <>
      "Security: #{scores.security_score}/100."
  end

  defp calculate_data_completeness(data_sections) do
    # Calculate percentage of data sections that have meaningful content
    non_empty_sections =
      Enum.count(data_sections, fn section ->
        case section do
          map when is_map(map) -> map_size(map) > 0
          _ -> false
        end
      end)

    round(non_empty_sections / length(data_sections) * 100)
  end

  defp get_or_create_character_stats(character_id) do
    case CharacterStats.get_by_character_id(character_id) do
      {:ok, [stats]} ->
        stats

      _ ->
        # Create basic stats if none exist
        %CharacterStats{
          character_id: character_id,
          character_name: "Unknown",
          total_kills: 0,
          total_losses: 0,
          avg_gang_size: 1.0,
          ship_usage: %{},
          flies_capitals: false
        }
    end
  end

  # Public API functions expected by tests

  @doc """
  Calculate J-space experience from killmail data.
  """
  def calculate_j_space_experience(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{
        total_j_kills: 0,
        total_j_losses: 0,
        j_space_time_percent: 0.0,
        wormhole_systems_visited: [],
        most_active_wh_class: nil
      }
    else
      # Filter for J-space killmails
      j_space_killmails =
        Enum.filter(killmails, fn km ->
          system_id = Map.get(km, :solar_system_id, 0)
          classify_system_type(system_id) == :wormhole
        end)

      # Count kills vs losses
      kills = Enum.count(j_space_killmails, fn km -> not Map.get(km, :is_victim, false) end)
      losses = Enum.count(j_space_killmails, fn km -> Map.get(km, :is_victim, false) end)

      # Calculate percentage of time in J-space
      total_killmails = length(killmails)

      j_space_percent =
        if total_killmails > 0 do
          length(j_space_killmails) / total_killmails * 100
        else
          0.0
        end

      # Extract visited systems
      systems_visited =
        j_space_killmails
        |> Enum.map(&Map.get(&1, :solar_system_id))
        |> Enum.uniq()
        |> Enum.sort()

      # Determine most active WH class (simplified)
      most_active_class =
        if length(systems_visited) > 0 do
          # Simple heuristic: lower system IDs are typically lower class
          avg_system_id = Enum.sum(systems_visited) / length(systems_visited)

          cond do
            avg_system_id < 31_001_000 -> "C1"
            avg_system_id < 31_002_000 -> "C2"
            avg_system_id < 31_003_000 -> "C3"
            avg_system_id < 31_004_000 -> "C4"
            avg_system_id < 31_005_000 -> "C5"
            true -> "C6"
          end
        else
          nil
        end

      %{
        total_j_kills: kills,
        total_j_losses: losses,
        j_space_time_percent: Float.round(j_space_percent, 1),
        wormhole_systems_visited: systems_visited,
        most_active_wh_class: most_active_class
      }
    end
  end

  @doc """
  Analyze security risks from character data and employment history.
  """
  def analyze_security_risks(character_data, employment_history) do
    _character_id = Map.get(character_data, :character_id, 0)

    # Analyze corp hopping
    corp_hopping = detect_corp_hopping(employment_history)

    # Collect risk factors
    risk_factors =
      []
      |> then(fn factors -> if corp_hopping, do: ["corp_hopping" | factors], else: factors end)
      |> then(fn factors ->
        if Enum.empty?(employment_history), do: ["no_employment_history" | factors], else: factors
      end)
      |> then(fn factors ->
        if length(employment_history) <= 2, do: ["limited_history" | factors], else: factors
      end)

    # Calculate risk score (0-100, higher is more risky)
    # Base risk for any character
    base_risk = 10

    # Calculate corp hopping penalty with severity levels
    corp_hopping_penalty =
      if corp_hopping do
        # Calculate severity based on average tenure
        avg_tenure = calculate_average_tenure(employment_history)

        cond do
          # Extreme corp hopping (< 1 month avg)
          avg_tenure < 30 -> 50
          # High corp hopping (< 3 months avg)
          avg_tenure < 90 -> 40
          # Standard corp hopping (< 6 months avg)
          true -> 30
        end
      else
        0
      end

    history_penalty = if Enum.empty?(employment_history), do: 25, else: 0
    new_player_penalty = if length(employment_history) <= 1, do: 15, else: 0

    risk_score = min(100, base_risk + corp_hopping_penalty + history_penalty + new_player_penalty)

    %{
      risk_score: risk_score,
      risk_factors: risk_factors,
      corp_hopping_detected: corp_hopping
    }
  end

  @doc """
  Detect known eviction groups from killmail data.
  """
  def detect_eviction_groups(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{
        eviction_group_detected: false,
        known_groups: [],
        confidence_score: 0.0
      }
    else
      # Known eviction group names/patterns
      known_eviction_groups = [
        "hard knocks",
        "lazerhawks",
        "no holes barred",
        "mouth trumpet cavalry",
        "inner hell",
        "wormhole society",
        "origin",
        "amplified",
        "nova elite"
      ]

      # Extract corporation/alliance names from killmails
      entities =
        killmails
        |> Enum.flat_map(fn km ->
          corp_name = Map.get(km, :attacker_corporation_name, "")
          alliance_name = Map.get(km, :attacker_alliance_name, "")
          [corp_name, alliance_name]
        end)
        |> Enum.filter(&(&1 != ""))
        |> Enum.map(&String.downcase/1)

      # Check for matches
      detected_groups =
        known_eviction_groups
        |> Enum.filter(fn group ->
          Enum.any?(entities, fn entity ->
            String.contains?(entity, group)
          end)
        end)

      eviction_detected = length(detected_groups) > 0

      # Calculate confidence based on multiple factors
      confidence =
        if eviction_detected do
          base_confidence = 0.6
          multiple_groups_bonus = if length(detected_groups) > 1, do: 0.2, else: 0.0
          activity_bonus = min(0.2, length(killmails) / 50)
          min(1.0, base_confidence + multiple_groups_bonus + activity_bonus)
        else
          0.0
        end

      %{
        eviction_group_detected: eviction_detected,
        known_groups: detected_groups,
        confidence_score: Float.round(confidence, 2)
      }
    end
  end

  @doc """
  Analyze potential alt character patterns.
  """
  def analyze_alt_character_patterns(character_data, killmails) do
    character_name = Map.get(character_data, :character_name, "Unknown")

    # Extract unique character names from killmails (potential associates)
    associated_characters =
      killmails
      |> Enum.map(&Map.get(&1, :attacker_character_name, ""))
      |> Enum.filter(&(&1 != "" and &1 != character_name))
      |> Enum.uniq()

    # Extract systems where activity occurred
    systems_visited =
      killmails
      |> Enum.map(&Map.get(&1, :solar_system_id, 0))
      |> Enum.filter(&(&1 > 0))
      |> Enum.uniq()

    # Simple timing correlation analysis
    killmail_times =
      killmails
      |> Enum.map(&Map.get(&1, :killmail_time))
      |> Enum.filter(&(&1 != nil))

    timing_correlation =
      if length(killmail_times) > 1 do
        # Calculate time spans between killmails
        time_diffs =
          killmail_times
          |> Enum.sort(DateTime)
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1, :minute) end)

        # Lower average time between kills might indicate coordinated activity
        if length(time_diffs) > 0 do
          avg_diff = Enum.sum(time_diffs) / length(time_diffs)
          # Score from 0-1, where lower time gaps = higher correlation
          # Normalize to 2-hour window
          max(0.0, 1.0 - avg_diff / 120)
        else
          0.0
        end
      else
        0.0
      end

    %{
      # Limit to top 10
      potential_alts: Enum.take(associated_characters, 10),
      shared_systems: systems_visited,
      timing_correlation: Float.round(timing_correlation, 3)
    }
  end

  @doc """
  Calculate small gang competency from killmail data.
  """
  def calculate_small_gang_competency(killmails) when is_list(killmails) do
    if Enum.empty?(killmails) do
      %{
        small_gang_performance: %{},
        avg_gang_size: 0.0,
        preferred_size: "unknown",
        solo_capability: false
      }
    else
      # Extract gang sizes from killmails
      gang_sizes =
        killmails
        |> Enum.map(&Map.get(&1, :attacker_count, 1))
        |> Enum.filter(&(&1 > 0))

      # Calculate average gang size
      avg_gang_size =
        if length(gang_sizes) > 0 do
          Enum.sum(gang_sizes) / length(gang_sizes)
        else
          0.0
        end

      # Determine preferred gang size category
      preferred_size =
        cond do
          avg_gang_size <= 1.5 -> "solo"
          avg_gang_size <= 3.0 -> "small_gang"
          avg_gang_size <= 8.0 -> "medium_gang"
          avg_gang_size <= 20.0 -> "large_gang"
          true -> "fleet"
        end

      # Check solo capability
      solo_kills = Enum.count(gang_sizes, &(&1 == 1))
      solo_capability = solo_kills > 0 and solo_kills / length(gang_sizes) >= 0.2

      # Calculate performance metrics
      kills = Enum.count(killmails, fn km -> not Map.get(km, :is_victim, false) end)
      losses = Enum.count(killmails, fn km -> Map.get(km, :is_victim, false) end)

      kill_efficiency =
        if kills + losses > 0 do
          kills / (kills + losses)
        else
          0.0
        end

      performance = %{
        kill_efficiency: Float.round(kill_efficiency, 3),
        total_engagements: length(killmails),
        kills: kills,
        losses: losses
      }

      %{
        small_gang_performance: performance,
        avg_gang_size: Float.round(avg_gang_size, 1),
        preferred_size: preferred_size,
        solo_capability: solo_capability
      }
    end
  end

  @doc """
  Generate recruitment recommendation based on analysis data.
  """
  def generate_recommendation(analysis_data) do
    # Extract key metrics
    metrics = extract_recommendation_metrics(analysis_data)

    # Check for immediate rejection conditions
    case check_rejection_conditions(metrics) do
      {:reject, confidence, reasoning} ->
        build_recommendation("reject", confidence, reasoning, [], metrics)

      :continue ->
        # Evaluate candidate quality
        {recommendation, confidence, reasoning, conditions} = evaluate_candidate_quality(metrics)
        build_recommendation(recommendation, confidence, reasoning, conditions, metrics)
    end
  end

  defp extract_recommendation_metrics(analysis_data) do
    j_space_exp = Map.get(analysis_data, :j_space_experience, %{})
    security_risks = Map.get(analysis_data, :security_risks, %{})
    eviction_groups = Map.get(analysis_data, :eviction_groups, %{})
    competency = Map.get(analysis_data, :competency_metrics, %{})

    %{
      j_kills: Map.get(j_space_exp, :total_j_kills, 0),
      j_losses: Map.get(j_space_exp, :total_j_losses, 0),
      j_time_percent: Map.get(j_space_exp, :j_space_time_percent, 0.0),
      risk_score: Map.get(security_risks, :risk_score, 50),
      eviction_detected: Map.get(eviction_groups, :eviction_group_detected, false),
      competency: competency
    }
  end

  defp check_rejection_conditions(metrics) do
    cond do
      metrics.eviction_detected ->
        {:reject, 0.95, "Known eviction group association detected"}

      metrics.risk_score >= 80 ->
        {:reject, 0.9, "High security risk score (#{metrics.risk_score}/100)"}

      true ->
        :continue
    end
  end

  defp evaluate_candidate_quality(metrics) do
    cond do
      # High quality candidate
      metrics.j_kills >= 30 and metrics.j_time_percent >= 60.0 and metrics.risk_score <= 25 ->
        {"approve", 0.85, "Strong J-space experience with low risk", []}

      # Good candidate with some concerns
      metrics.j_kills >= 15 and metrics.j_time_percent >= 40.0 and metrics.risk_score <= 40 ->
        {"conditional", 0.75, "Good J-space experience, manageable risk",
         ["probationary_period", "limited_access"]}

      # Decent candidate needing review
      metrics.j_kills >= 5 and metrics.risk_score <= 50 ->
        {"conditional", 0.6, "Some J-space experience, requires monitoring",
         ["extended_probation", "mentor_assignment"]}

      # Insufficient data or experience
      metrics.j_kills < 5 and metrics.j_time_percent < 20.0 ->
        {"more_info", 0.4, "Limited J-space experience, need more data",
         ["skill_assessment", "trial_period"]}

      # Default to requiring more info
      true ->
        {"more_info", 0.5, "Mixed indicators, requires detailed review",
         ["manual_interview", "reference_check"]}
    end
  end

  defp build_recommendation(recommendation, confidence, reasoning, conditions, _metrics) do
    %{
      recommendation: recommendation,
      confidence: confidence,
      reasoning: reasoning,
      conditions: conditions
    }
  end

  @doc """
  Format analysis data into a summary.
  """
  def format_analysis_summary(analysis) do
    character_name = Map.get(analysis, :character_name, "Unknown")
    j_space_exp = Map.get(analysis, :j_space_experience, %{})
    security_risks = Map.get(analysis, :security_risks, %{})
    recommendation = Map.get(analysis, :recommendation, %{})

    # Extract key metrics
    j_kills = Map.get(j_space_exp, :total_j_kills, 0)
    j_losses = Map.get(j_space_exp, :total_j_losses, 0)
    j_time_percent = Map.get(j_space_exp, :j_space_time_percent, 0.0)
    risk_score = Map.get(security_risks, :risk_score, 0)
    rec_decision = Map.get(recommendation, :recommendation, "unknown")
    rec_confidence = Map.get(recommendation, :confidence, 0.0)

    # Generate summary text
    summary_text = """
    Vetting Analysis for #{character_name}

    J-Space Experience: #{j_kills} kills, #{j_losses} losses (#{j_time_percent}% of activity)
    Security Risk Score: #{risk_score}/100

    Recommendation: #{String.upcase(rec_decision)} (#{Float.round(rec_confidence * 100)}% confidence)

    #{Map.get(recommendation, :reasoning, "No reasoning provided")}
    """

    # Key metrics for quick reference
    key_metrics = %{
      j_space_kills: j_kills,
      j_space_losses: j_losses,
      j_space_percentage: j_time_percent,
      risk_score: risk_score,
      recommendation: rec_decision,
      confidence: rec_confidence
    }

    %{
      summary_text: String.trim(summary_text),
      key_metrics: key_metrics
    }
  end

  @doc """
  Classify system type based on system ID.
  """
  def classify_system_type(system_id) when is_integer(system_id) do
    cond do
      system_id >= 31_000_000 -> :wormhole
      system_id >= 30_000_000 -> :known_space
      system_id > 0 -> :known_space
      true -> :unknown
    end
  end

  def classify_system_type(_), do: :unknown

  @doc """
  Calculate time overlap between two timestamps.
  """
  def calculate_time_overlap(time1, time2) when not is_nil(time1) and not is_nil(time2) do
    # Calculate absolute difference in minutes
    diff_seconds = abs(DateTime.diff(time1, time2, :second))
    diff_minutes = diff_seconds / 60

    # Return normalized overlap score (0-1, higher = closer in time)
    # Use exponential decay function
    # 1-hour half-life
    :math.exp(-diff_minutes / 60)
  end

  def calculate_time_overlap(_, _), do: 0.0

  @doc """
  Normalize corporation name for comparison.
  """
  def normalize_corporation_name(nil), do: ""

  def normalize_corporation_name(corp_name) when is_binary(corp_name) do
    corp_name
    |> String.downcase()
    # Remove alliance tags
    |> String.replace(~r/\s*\[.*?\]\s*/, "")
    |> String.trim()
  end

  def normalize_corporation_name(_), do: ""

  @doc """
  Store vetting analysis data to the database.
  """
  def store_vetting_analysis(analysis_data) do
    character_id = Map.get(analysis_data, :character_id)

    # Create vetting record structure
    vetting_data = %{
      character_id: character_id,
      character_name: Map.get(analysis_data, :character_name, "Unknown"),
      analyst_character_id: Map.get(analysis_data, :analyst_character_id),
      recommendation: Map.get(analysis_data, :recommendation, %{}),
      # Add other fields as needed
      status: "complete",
      analysis_timestamp: DateTime.utc_now()
    }

    # Try to create the vetting record
    case WHVetting.create(vetting_data) do
      {:ok, vetting_record} ->
        {:ok, vetting_record}

      {:error, reason} ->
        Logger.error("Failed to store vetting analysis: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper functions for the new API functions

  # defp detect_suspicious_employment_patterns(employment_history, tenures) do
  #   patterns = []

  #   # Check for very short stays
  #   short_stays = Enum.filter(tenures, fn tenure -> tenure < 30 end)
  #   patterns = if length(short_stays) > 2, do: ["multiple_short_stays" | patterns], else: patterns

  #   # Check for pattern of leaving corps quickly
  #   _recent_history = Enum.take(employment_history, 5)
  #   recent_tenures = Enum.take(tenures, 4)

  #   if length(recent_tenures) >= 3 and Enum.all?(recent_tenures, fn t -> t < 90 end) do
  #     ["rapid_recent_changes" | patterns]
  #   else
  #     patterns
  #   end
  # end

  defp calculate_average_tenure(employment_history) do
    if length(employment_history) <= 2 do
      # Default to 1 year if insufficient data
      365
    else
      tenures =
        employment_history
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [current, previous] ->
          start_date = Map.get(previous, :start_date)
          end_date = Map.get(current, :start_date)

          if is_struct(start_date, DateTime) and is_struct(end_date, DateTime) do
            DateTime.diff(end_date, start_date, :day)
          else
            # Default to 1 year if dates missing
            365
          end
        end)

      if length(tenures) > 0 do
        Enum.sum(tenures) / length(tenures)
      else
        365
      end
    end
  end

  defp detect_corp_hopping(employment_history) do
    if length(employment_history) <= 2 do
      false
    else
      avg_tenure = calculate_average_tenure(employment_history)

      # Get individual tenures for additional analysis
      tenures =
        employment_history
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [current, previous] ->
          start_date = Map.get(previous, :start_date)
          end_date = Map.get(current, :start_date)

          if is_struct(start_date, DateTime) and is_struct(end_date, DateTime) do
            DateTime.diff(end_date, start_date, :day)
          else
            365
          end
        end)

      if length(tenures) > 0 do
        # Less than 3 months
        short_tenures = Enum.count(tenures, &(&1 < 90))

        # Corp hopping if average tenure < 6 months OR 30%+ short tenures
        avg_tenure < 180 or short_tenures / length(tenures) >= 0.3
      else
        false
      end
    end
  end
end
