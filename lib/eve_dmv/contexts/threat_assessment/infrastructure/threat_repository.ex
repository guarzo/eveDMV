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
    # Get corporation data from killmail records
    case fetch_corporation_basic_data(corporation_id) do
      {:ok, corp_data} ->
        # Enhance with member statistics
        member_stats = get_corporation_member_stats(corporation_id)
        alliance_data = get_corporation_alliance_data(corporation_id)
        activity_data = get_corporation_activity_data(corporation_id)

        enhanced_data =
          corp_data
          |> Map.merge(member_stats)
          |> Map.merge(alliance_data)
          |> Map.merge(activity_data)

        Result.ok(enhanced_data)

      {:error, reason} ->
        Result.error(reason, "Failed to fetch corporation data")
    end
  end

  defp get_fleet_data(fleet_id) do
    # In EVE, fleet_id might be treated as a killmail_id for a specific engagement
    # Get fleet data from participants and engagement information
    participants = get_fleet_participants_from_killmails(fleet_id)
    engagement_data = get_fleet_engagement_data(fleet_id)

    if Enum.empty?(participants) do
      Result.error(:no_fleet_data, "No fleet data found for ID #{fleet_id}")
    else
      fleet_data = %{
        fleet_id: fleet_id,
        participants: participants,
        participant_count: length(participants),
        engagement_data: engagement_data,
        fleet_type: determine_fleet_type_from_participants(participants),
        start_time: engagement_data.killmail_time,
        solar_system_id: engagement_data.solar_system_id,
        total_value: engagement_data.total_value
      }

      Result.ok(fleet_data)
    end
  end

  defp get_character_related_data(character_id) do
    # Query real killmail data for character
    killmail_stats = get_character_killmail_stats(character_id)

    # Get corporation data from recent killmails 
    corp_data = get_character_corporation_data(character_id)

    # Get alliance data if character is in one
    alliance_data = get_character_alliance_data(character_id)

    %{
      killmail_stats: killmail_stats,
      corp_data: corp_data,
      alliance_data: alliance_data
    }
  end

  defp get_corporation_related_data(corporation_id) do
    # Get real member statistics from killmail data
    member_stats = get_corporation_member_stats(corporation_id)

    # Get alliance data if corporation is in one
    alliance_data = get_corporation_alliance_data(corporation_id)

    # Get corporation activity from killmail data
    corp_activity = get_corporation_activity_data(corporation_id)

    %{
      member_stats: member_stats,
      alliance_data: alliance_data,
      corp_activity: corp_activity
    }
  end

  defp get_fleet_related_data(fleet_id) do
    # Note: Fleet ID might be synthetic - in EVE, fleets aren't directly tracked in killmails
    # We can infer fleet participation from killmails that happened close together

    # Get engagement participants from killmail data
    participants = get_fleet_participants_from_killmails(fleet_id)

    # Get engagement data based on killmail timestamps and locations
    engagement_data = get_fleet_engagement_data(fleet_id)

    %{
      participants: participants,
      engagement_data: engagement_data
    }
  end

  # Real data query helpers

  defp get_character_killmail_stats(character_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    # Query killmails where character was victim
    victim_query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(100)

    # Query killmails where character was attacker  
    recent_query =
      KillmailRaw
      |> new()
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(500)

    case {Ash.read(victim_query, domain: Api), Ash.read(recent_query, domain: Api)} do
      {{:ok, victim_killmails}, {:ok, recent_killmails}} ->
        # Filter for attacker involvement
        attacker_killmails =
          Enum.filter(recent_killmails, fn km ->
            case km.raw_data do
              %{"attackers" => attackers} when is_list(attackers) ->
                Enum.any?(attackers, &(&1["character_id"] == character_id))

              _ ->
                false
            end
          end)

        total_isk_destroyed = calculate_total_isk_destroyed(attacker_killmails)
        total_isk_lost = calculate_total_isk_lost(victim_killmails)

        %{
          kills: length(attacker_killmails),
          deaths: length(victim_killmails),
          isk_destroyed: total_isk_destroyed,
          isk_lost: total_isk_lost,
          efficiency: calculate_efficiency(total_isk_destroyed, total_isk_lost),
          activity_level:
            calculate_activity_level(length(attacker_killmails) + length(victim_killmails))
        }

      _ ->
        # Fallback to empty stats
        %{
          kills: 0,
          deaths: 0,
          isk_destroyed: 0,
          isk_lost: 0,
          efficiency: 0.0,
          activity_level: :low
        }
    end
  end

  defp get_character_corporation_data(character_id) do
    # Get corporation info from most recent killmail
    cutoff_date = DateTime.add(DateTime.utc_now(), -7, :day)

    query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      |> limit(1)

    case Ash.read(query, domain: Api) do
      {:ok, [killmail]} ->
        %{
          corporation_id: killmail.victim_corporation_id,
          corporation_name: "Corporation #{killmail.victim_corporation_id}",
          # Would need separate API call to get this
          member_count: nil
        }

      _ ->
        %{
          corporation_id: nil,
          corporation_name: "Unknown Corporation",
          member_count: 0
        }
    end
  end

  defp get_character_alliance_data(character_id) do
    # Get alliance info from most recent killmail
    cutoff_date = DateTime.add(DateTime.utc_now(), -7, :day)

    query =
      KillmailRaw
      |> new()
      |> filter(victim_character_id: character_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      |> limit(1)

    case Ash.read(query, domain: Api) do
      {:ok, [killmail]} when not is_nil(killmail.victim_alliance_id) ->
        %{
          alliance_id: killmail.victim_alliance_id,
          alliance_name: "Alliance #{killmail.victim_alliance_id}"
        }

      _ ->
        %{}
    end
  end

  defp get_corporation_member_stats(corporation_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    # Get killmails involving corporation members
    query =
      KillmailRaw
      |> new()
      |> filter(victim_corporation_id: corporation_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(200)

    case Ash.read(query, domain: Api) do
      {:ok, killmails} ->
        unique_members =
          killmails
          |> Enum.map(& &1.victim_character_id)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        %{
          active_members: length(unique_members),
          total_engagements: length(killmails),
          average_kills_per_member:
            if(length(unique_members) > 0,
              do: length(killmails) / length(unique_members),
              else: 0
            )
        }

      _ ->
        %{
          active_members: 0,
          total_engagements: 0,
          average_kills_per_member: 0
        }
    end
  end

  defp get_corporation_alliance_data(corporation_id) do
    # Get alliance info from most recent corporation killmail
    cutoff_date = DateTime.add(DateTime.utc_now(), -7, :day)

    query =
      KillmailRaw
      |> new()
      |> filter(victim_corporation_id: corporation_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> sort(killmail_time: :desc)
      |> limit(1)

    case Ash.read(query, domain: Api) do
      {:ok, [killmail]} when not is_nil(killmail.victim_alliance_id) ->
        %{
          alliance_id: killmail.victim_alliance_id,
          alliance_name: "Alliance #{killmail.victim_alliance_id}"
        }

      _ ->
        %{}
    end
  end

  defp get_corporation_activity_data(corporation_id) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    query =
      KillmailRaw
      |> new()
      |> filter(victim_corporation_id: corporation_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(100)

    case Ash.read(query, domain: Api) do
      {:ok, killmails} ->
        if Enum.empty?(killmails) do
          %{
            activity_level: :inactive,
            recent_kills: 0,
            peak_activity_day: nil
          }
        else
          # Group by day to find peak activity
          daily_activity =
            killmails
            |> Enum.group_by(fn km ->
              Date.from_iso8601!(Date.to_iso8601(DateTime.to_date(km.killmail_time)))
            end)
            |> Map.new(fn {date, kms} -> {date, length(kms)} end)

          peak_day =
            Enum.max_by(daily_activity, fn {_date, count} -> count end, fn -> {nil, 0} end)

          activity_level =
            cond do
              length(killmails) > 20 -> :high
              length(killmails) > 5 -> :moderate
              true -> :low
            end

          %{
            activity_level: activity_level,
            recent_kills: length(killmails),
            peak_activity_day: elem(peak_day, 0)
          }
        end

      _ ->
        %{
          activity_level: :inactive,
          recent_kills: 0,
          peak_activity_day: nil
        }
    end
  end

  defp get_fleet_participants_from_killmails(fleet_id) do
    # Since EVE doesn't track fleets directly in killmails, we'll treat fleet_id 
    # as a killmail_id and get participants from that specific engagement
    query =
      KillmailRaw
      |> new()
      |> filter(killmail_id: fleet_id)
      |> limit(1)

    case Ash.read(query, domain: Api) do
      {:ok, [killmail]} ->
        # Extract all participants from the killmail
        case killmail.raw_data do
          %{"attackers" => attackers} when is_list(attackers) ->
            participants =
              attackers
              |> Enum.map(fn attacker ->
                %{
                  character_id: attacker["character_id"],
                  corporation_id: attacker["corporation_id"],
                  alliance_id: attacker["alliance_id"],
                  ship_type_id: attacker["ship_type_id"],
                  damage_done: attacker["damage_done"] || 0
                }
              end)
              |> Enum.reject(fn p -> is_nil(p.character_id) end)

            # Add victim as participant
            victim_participant = %{
              character_id: killmail.victim_character_id,
              corporation_id: killmail.victim_corporation_id,
              alliance_id: killmail.victim_alliance_id,
              ship_type_id: killmail.victim_ship_type_id,
              # victim doesn't do damage
              damage_done: 0
            }

            [victim_participant | participants]

          _ ->
            []
        end

      _ ->
        []
    end
  end

  defp get_fleet_engagement_data(fleet_id) do
    # Use the killmail data to provide engagement information
    query =
      KillmailRaw
      |> new()
      |> filter(killmail_id: fleet_id)
      |> limit(1)

    case Ash.read(query, domain: Api) do
      {:ok, [killmail]} ->
        # Extract engagement data from killmail
        attacker_count =
          case killmail.raw_data do
            %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
            _ -> 0
          end

        # Get system info from killmail
        solar_system_id =
          case killmail.raw_data do
            %{"solar_system_id" => system_id} -> system_id
            _ -> nil
          end

        %{
          # This is one engagement
          total_engagements: 1,
          # attackers + victim
          participants: attacker_count + 1,
          solar_system_id: solar_system_id,
          killmail_time: killmail.killmail_time,
          total_value:
            case killmail.raw_data do
              %{"zkb" => %{"totalValue" => value}} -> value
              _ -> 0
            end
        }

      _ ->
        %{
          total_engagements: 0,
          participants: 0,
          solar_system_id: nil,
          killmail_time: nil,
          total_value: 0
        }
    end
  end

  # Helper functions for calculations

  defp calculate_total_isk_destroyed(killmails) do
    killmails
    |> Enum.map(fn km ->
      case km.raw_data do
        %{"zkb" => %{"totalValue" => value}} when is_number(value) -> value
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp calculate_total_isk_lost(killmails) do
    calculate_total_isk_destroyed(killmails)
  end

  defp calculate_efficiency(isk_destroyed, isk_lost) do
    if isk_lost > 0 do
      Float.round(isk_destroyed / (isk_destroyed + isk_lost) * 100, 2)
    else
      100.0
    end
  end

  defp calculate_activity_level(total_killmails) do
    cond do
      total_killmails > 20 -> :high
      total_killmails > 5 -> :moderate
      total_killmails > 0 -> :low
      true -> :inactive
    end
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

  defp fetch_corporation_basic_data(corporation_id) do
    # Get corporation data from killmail records
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    query =
      KillmailRaw
      |> new()
      |> filter(victim_corporation_id: corporation_id)
      |> filter(killmail_time: [gte: cutoff_date])
      |> limit(10)

    case Ash.read(query, domain: Api) do
      {:ok, [_ | _] = killmails} ->
        first_killmail = List.first(killmails)

        corp_data = %{
          corporation_id: corporation_id,
          corporation_name: "Corporation #{corporation_id}",
          alliance_id: first_killmail.victim_alliance_id,
          total_members: length(Enum.uniq_by(killmails, & &1.victim_character_id)),
          recent_activity: length(killmails),
          last_seen: DateTime.utc_now()
        }

        {:ok, corp_data}

      {:ok, []} ->
        # No killmail data found
        corp_data = %{
          corporation_id: corporation_id,
          corporation_name: "Corporation #{corporation_id}",
          alliance_id: nil,
          total_members: 0,
          recent_activity: 0,
          last_seen: nil
        }

        {:ok, corp_data}

      {:error, _reason} ->
        {:error, :database_error}
    end
  end

  defp determine_fleet_type_from_participants(participants) do
    if Enum.empty?(participants) do
      :unknown
    else
      participant_count = length(participants)

      cond do
        participant_count < 5 -> :small_gang
        participant_count < 15 -> :medium_gang
        participant_count < 50 -> :large_gang
        true -> :fleet
      end
    end
  end
end
