defmodule EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatRepository do
  @moduledoc """
  Repository for threat assessment data access.

  Provides data access layer for entity data, security context,
  and related information needed for threat analysis.
  """

  use EveDmv.ErrorHandler

  alias EveDmv.Result
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Api

  import Ash.Query
  require Logger

  @doc """
  Get entity data for threat assessment.
  """
  def get_entity_data(entity_id, entity_type) do
    case entity_type do
      :character ->
        get_character_data(entity_id)

      :corporation ->
        get_corporation_data(entity_id)

      :fleet ->
        get_fleet_data(entity_id)

      _ ->
        Result.error(:invalid_entity_type, "Unsupported entity type: #{entity_type}")
    end
  end

  @doc """
  Get related data for threat assessment context.
  """
  def get_related_data(entity_id, entity_type) do
    case entity_type do
      :character ->
        get_character_related_data(entity_id)

      :corporation ->
        get_corporation_related_data(entity_id)

      :fleet ->
        get_fleet_related_data(entity_id)

      _ ->
        %{}
    end
  end

  @doc """
  Get security context for entity.
  """
  def get_security_context(_entity_id, _entity_type) do
    # Placeholder implementation
    %{
      security_clearance: :standard,
      access_level: :public,
      classification: :unclassified,
      data_sensitivity: :low,
      retention_policy: :standard
    }
  end

  @doc """
  Store threat assessment results.
  """
  def store_assessment(entity_id, entity_type, assessment_data) do
    # Placeholder implementation - would store to database
    Logger.info("Storing threat assessment",
      entity_id: entity_id,
      entity_type: entity_type,
      threat_level: Map.get(assessment_data, :threat_level)
    )

    Result.ok(:stored)
  end

  @doc """
  Get historical threat assessments.
  """
  def get_assessment_history(_entity_id, _entity_type, days_back \\ 30) do
    # Placeholder implementation
    # Weekly assessments
    history =
      1..days_back
      |> Enum.take_every(7)
      |> Enum.map(fn days_ago ->
        date = DateTime.add(DateTime.utc_now(), -days_ago, :day)

        %{
          assessment_date: date,
          threat_level: Enum.random([:minimal, :low, :medium, :high, :critical]),
          vulnerability_count: :rand.uniform(10),
          assessment_confidence: Enum.random([:very_low, :low, :medium, :high]),
          notes: "Historical assessment sample"
        }
      end)
      |> Enum.reverse()

    Result.ok(history)
  end

  # Private helper functions

  defp get_character_data(character_id) do
    # Query actual character data from database
    case fetch_character_basic_data(character_id) do
      {:ok, basic_data} ->
        case fetch_character_killmail_stats(character_id) do
          {:ok, activity_stats} ->
            character_data = Map.merge(basic_data, activity_stats)
            Result.ok(character_data)

          {:error, reason} ->
            Logger.warning(
              "Failed to fetch killmail stats for character #{character_id}: #{inspect(reason)}"
            )

            # Return basic character data with default activity stats
            character_data =
              Map.merge(basic_data, %{
                total_kills: 0,
                total_losses: 0,
                recent_kills: 0,
                recent_losses: 0,
                avg_ship_value: 0,
                solo_ratio: 0.0,
                aggression_percentile: 0,
                is_fc: false,
                prime_timezone: "UTC",
                activity_by_hour: %{},
                batphone_probability: 0.0
              })

            Result.ok(character_data)
        end

      {:error, reason} ->
        Result.error(reason, "Failed to fetch character data")
    end
  end

  defp get_corporation_data(corporation_id) do
    # Placeholder implementation
    corporation_data = %{
      corporation_id: corporation_id,
      corporation_name: "Sample Corporation #{corporation_id}",
      alliance_id: nil,
      member_count: :rand.uniform(500) + 50,
      founded_date:
        DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -:rand.uniform(2000) - 100, :day)),
      ceo_id: 123_456,
      ticker: "[SMPL]",
      description: "Sample corporation for threat assessment"
    }

    Result.ok(corporation_data)
  end

  defp get_fleet_data(fleet_id) do
    # Placeholder implementation
    fleet_data = %{
      fleet_id: fleet_id,
      fleet_name: "Sample Fleet #{fleet_id}",
      participant_count: :rand.uniform(50) + 5,
      fleet_commander: "Sample FC",
      fleet_type:
        Enum.random([
          :capital_fleet,
          :battleship_fleet,
          :cruiser_fleet,
          :frigate_gang,
          :mixed_composition
        ]),
      engagement_context:
        Enum.random([:defensive, :offensive, :roaming, :strategic_op, :training]),
      start_time:
        DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -:rand.uniform(120), :minute)),
      end_time: nil
    }

    Result.ok(fleet_data)
  end

  defp get_character_related_data(_character_id) do
    %{
      killmail_stats: generate_sample_killmail_stats(),
      corp_data: %{
        corporation_id: 98_000_001,
        corporation_name: "Sample Corp",
        member_count: 150
      },
      alliance_data: %{}
    }
  end

  defp get_corporation_related_data(_corporation_id) do
    %{
      member_stats: generate_sample_member_stats(),
      alliance_data: %{},
      corp_activity: generate_sample_corp_activity()
    }
  end

  defp get_fleet_related_data(_fleet_id) do
    %{
      participants: generate_sample_participants(),
      engagement_data: generate_sample_engagement_data()
    }
  end

  # Sample data generation helpers

  defp generate_sample_killmail_stats do
    %{
      "total_kills" => :rand.uniform(500),
      "total_losses" => :rand.uniform(200),
      "high_value_losses" => :rand.uniform(50),
      "peak_hour_activity" => :rand.uniform(100),
      "total_activity" => :rand.uniform(1000) + 100,
      "easy_target_kills" => :rand.uniform(200),
      "escalated_engagements" => :rand.uniform(50),
      "total_engagements" => :rand.uniform(300) + 50,
      "successful_retreats" => :rand.uniform(30),
      "failed_retreats" => :rand.uniform(20)
    }
  end

  defp generate_sample_member_stats do
    Enum.map(1..20, fn i ->
      %{
        character_id: 1_000_000 + i,
        character_name: "Member #{i}",
        recent_kills: :rand.uniform(20),
        recent_losses: :rand.uniform(10),
        activity_score: :rand.uniform(100)
      }
    end)
  end

  defp generate_sample_corp_activity do
    %{
      total_kills: :rand.uniform(2000),
      total_losses: :rand.uniform(800),
      weekly_activity: :rand.uniform(500),
      member_participation_rate: :rand.uniform() * 0.8 + 0.2
    }
  end

  defp generate_sample_participants do
    Enum.map(1..(:rand.uniform(20) + 5), fn i ->
      %{
        character_id: 2_000_000 + i,
        character_name: "Pilot #{i}",
        ship_type: "Sample Ship Type",
        ship_value: :rand.uniform(1_000_000_000),
        fleet_role: if(rem(i, 5) == 0, do: "Squad Commander", else: "Member")
      }
    end)
  end

  defp generate_sample_engagement_data do
    %{
      engagement_type: Enum.random([:defensive, :offensive, :roaming, :strategic_op, :training]),
      duration_minutes: :rand.uniform(120) + 10,
      isk_destroyed: :rand.uniform(10_000_000_000),
      isk_lost: :rand.uniform(5_000_000_000),
      participants_lost: :rand.uniform(5),
      objective_achieved: :rand.uniform() > 0.5
    }
  end

  # Real database query functions

  defp fetch_character_basic_data(character_id) do
    # First check if we have basic character data in our cache/database
    # For now, we'll extract from killmail data if we don't have a Characters table
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(10)

    case Ash.read(victim_query, domain: Api) do
      {:ok, [_ | _] = killmails} ->
        # Extract basic character info from killmail data
        first_killmail = List.first(killmails)

        basic_data = %{
          character_id: character_id,
          character_name: "Character #{character_id}",
          corporation_id: first_killmail.victim_corporation_id,
          alliance_id: first_killmail.victim_alliance_id,
          security_status: 0.0,
          # Estimate
          creation_date: DateTime.utc_now() |> DateTime.add(-365 * 3, :day),
          last_seen: DateTime.utc_now()
        }

        {:ok, basic_data}

      {:ok, []} ->
        # No killmail data found, return basic structure
        basic_data = %{
          character_id: character_id,
          character_name: "Character #{character_id}",
          corporation_id: nil,
          alliance_id: nil,
          security_status: 0.0,
          creation_date: DateTime.utc_now() |> DateTime.add(-365, :day),
          last_seen: nil
        }

        {:ok, basic_data}

      {:error, _reason} ->
        {:error, :database_error}
    end
  end

  defp fetch_character_killmail_stats(character_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    # Fetch killmails where character was victim
    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(200)

    # Fetch killmails where character was attacker (simplified approach)
    attacker_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(1000)

    with {:ok, victim_killmails} <- Ash.read(victim_query, domain: Api),
         {:ok, potential_attacker_killmails} <- Ash.read(attacker_query, domain: Api) do
      # Filter for attacker involvement
      attacker_killmails =
        Enum.filter(potential_attacker_killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              Enum.any?(attackers, &(&1["character_id"] == character_id))

            _ ->
              false
          end
        end)

      all_killmails = victim_killmails ++ attacker_killmails

      activity_stats = %{
        total_kills: length(attacker_killmails),
        total_losses: length(victim_killmails),
        recent_kills: length(attacker_killmails),
        recent_losses: length(victim_killmails),
        avg_ship_value: calculate_avg_ship_value(victim_killmails),
        solo_ratio: calculate_solo_ratio(attacker_killmails),
        aggression_percentile: calculate_aggression_percentile(all_killmails),
        is_fc: detect_fc_activity(attacker_killmails),
        prime_timezone: analyze_prime_timezone(all_killmails),
        activity_by_hour: analyze_activity_by_hour(all_killmails),
        batphone_probability: calculate_batphone_probability(all_killmails)
      }

      {:ok, activity_stats}
    else
      {:error, _reason} ->
        {:error, :database_error}
    end
  end

  defp calculate_avg_ship_value(killmails) do
    if Enum.empty?(killmails) do
      0
    else
      # Simplified ship value calculation based on type
      values =
        Enum.map(killmails, fn km ->
          case km.victim_ship_type_id do
            # Frigates
            id when id in 580..700 -> 5_000_000
            # Destroyers
            id when id in 420..450 -> 15_000_000
            # Cruisers
            id when id in 620..650 -> 50_000_000
            # Battlecruisers
            id when id in 540..570 -> 150_000_000
            # Battleships
            id when id in 640..670 -> 300_000_000
            # Capitals
            id when id in 19_720..19_740 -> 2_000_000_000
            # Default
            _ -> 25_000_000
          end
        end)

      Enum.sum(values) / length(values)
    end
  end

  defp calculate_solo_ratio(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      solo_kills =
        Enum.count(killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              length(attackers) == 1

            _ ->
              false
          end
        end)

      solo_kills / length(killmails)
    end
  end

  defp calculate_aggression_percentile(killmails) do
    # Calculate based on activity frequency
    if Enum.empty?(killmails) do
      0
    else
      kills_per_day = length(killmails) / 30
      min(100, round(kills_per_day * 10))
    end
  end

  defp detect_fc_activity(killmails) do
    # Look for patterns that suggest FC activity (leading engagements, command ships)
    command_ships =
      Enum.count(killmails, fn km ->
        case km.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.any?(attackers, fn attacker ->
              attacker["ship_type_id"] in [22_470, 22_852, 17_918, 17_920]
            end)

          _ ->
            false
        end
      end)

    command_ships > 2
  end

  defp analyze_prime_timezone(killmails) do
    if Enum.empty?(killmails) do
      "UTC"
    else
      # Analyze kill times to determine most active timezone
      hours =
        Enum.map(killmails, fn km ->
          DateTime.to_time(km.killmail_time).hour
        end)

      most_common_hour =
        hours
        |> Enum.frequencies()
        |> Enum.max_by(&elem(&1, 1))
        |> elem(0)

      case most_common_hour do
        h when h in 0..6 -> "AUTZ"
        h when h in 7..14 -> "EUTZ"
        h when h in 15..23 -> "USTZ"
      end
    end
  end

  defp analyze_activity_by_hour(killmails) do
    if Enum.empty?(killmails) do
      %{}
    else
      killmails
      |> Enum.map(&DateTime.to_time(&1.killmail_time).hour)
      |> Enum.frequencies()
      |> Enum.into(%{})
    end
  end

  defp calculate_batphone_probability(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Look for patterns of large fleet engagements
      large_fleet_engagements =
        Enum.count(killmails, fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              length(attackers) > 20

            _ ->
              false
          end
        end)

      min(1.0, large_fleet_engagements / length(killmails))
    end
  end
end
