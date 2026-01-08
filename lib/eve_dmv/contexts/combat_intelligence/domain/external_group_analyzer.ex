defmodule EveDmv.Contexts.CombatIntelligence.Domain.ExternalGroupAnalyzer do
  @moduledoc """
  Analyzes external groups (corporations/alliances) that a character has collaborated with.
  """

  alias EveDmv.Platform.Cache.QueryCache
  require Logger

  @external_groups_ttl :timer.hours(8)

  @doc """
  Analyze external groups for a character within a given time range.
  """
  @spec analyze(integer(), DateTime.t()) :: {:ok, list(map())} | {:error, term()}
  def analyze(character_id, since_date) do
    # Delegate to PlayerRepository which contains the consolidated external groups logic.
    # QueryCache.get_or_compute already wraps results in {:ok, value}
    EveDmv.Contexts.PlayerProfile.Infrastructure.PlayerRepository.get_external_groups(
      character_id,
      since_date
    )
  end

  # Legacy implementation kept for reference but no longer used
  def analyze_old(character_id, since_date) do
    cache_key = "external_groups:#{character_id}:#{Date.to_iso8601(DateTime.to_date(since_date))}"

    QueryCache.get_or_compute(
      cache_key,
      fn ->
        external_groups_query = """
        WITH character_corp_info AS (
          -- Get character's current corporation and alliance
          SELECT DISTINCT
            COALESCE(
              (SELECT raw_data->'victim'->>'corporation_id' FROM killmails_raw WHERE victim_character_id = $3 LIMIT 1),
              (SELECT attacker->>'corporation_id'
               FROM killmails_raw k, jsonb_array_elements(k.raw_data->'attackers') as attacker
               WHERE attacker->>'character_id' = $1 LIMIT 1)
            )::integer as char_corp_id,
            COALESCE(
              (SELECT raw_data->'victim'->>'alliance_id' FROM killmails_raw WHERE victim_character_id = $3 LIMIT 1),
              (SELECT attacker->>'alliance_id'
               FROM killmails_raw k, jsonb_array_elements(k.raw_data->'attackers') as attacker
               WHERE attacker->>'character_id' = $1 LIMIT 1)
            )::integer as char_alliance_id
        ),
        external_collaborations AS (
        SELECT
            k.killmail_id,
            k.killmail_time,
            k.solar_system_id,
            attacker->>'corporation_id' as ext_corp_id,
            attacker->>'corporation_name' as ext_corp_name,
            attacker->>'alliance_id' as ext_alliance_id,
            attacker->>'alliance_name' as ext_alliance_name,
            attacker->>'character_id' as ext_char_id,
            attacker->>'character_name' as ext_char_name,
            COALESCE((k.raw_data->>'total_value')::numeric, 0) as kill_value
          FROM killmails_raw k,
               jsonb_array_elements(k.raw_data->'attackers') as attacker,
               character_corp_info cci
          WHERE k.killmail_time >= $2
            AND EXISTS (
              SELECT 1 FROM jsonb_array_elements(k.raw_data->'attackers') as char_attacker
              WHERE char_attacker->>'character_id' = $1
            )
            AND attacker->>'character_id' != $1  -- Not the character themselves
            AND attacker->>'corporation_id' IS NOT NULL
            AND (
              attacker->>'corporation_id' != cci.char_corp_id::text  -- Different corporation
              OR (
                cci.char_alliance_id IS NULL AND attacker->>'alliance_id' IS NOT NULL  -- Character has no alliance, collaborator does
              )
            )
        ),
        corp_collaboration_stats AS (
        SELECT
            ext_corp_id::integer as corporation_id,
            ext_corp_name as corporation_name,
            ext_alliance_id::integer as alliance_id,
            ext_alliance_name as alliance_name,
            COUNT(DISTINCT killmail_id) as kills_together,
            COUNT(DISTINCT ext_char_id) as unique_pilots,
            COUNT(DISTINCT solar_system_id) as systems_active,
            SUM(kill_value) as total_isk_destroyed,
            AVG(kill_value) as avg_kill_value,
            MAX(killmail_time) as last_seen,
            MIN(killmail_time) as first_seen
          FROM external_collaborations
          WHERE ext_corp_id IS NOT NULL
          GROUP BY ext_corp_id, ext_corp_name, ext_alliance_id, ext_alliance_name
          HAVING COUNT(DISTINCT killmail_id) >= 2  -- At least 2 kills together
          ORDER BY kills_together DESC
          LIMIT 15
        )
        SELECT
          corporation_id,
          corporation_name,
          alliance_id,
          alliance_name,
          kills_together,
          unique_pilots,
          systems_active,
          total_isk_destroyed,
          avg_kill_value,
          last_seen,
        first_seen
        FROM corp_collaboration_stats
        """

        case EveDmv.Repo.query(external_groups_query, [
               to_string(character_id),
               since_date,
               character_id
             ]) do
          {:ok, %{rows: rows}} ->
            groups = Enum.map(rows, &process_external_group_row/1)

            {:ok, groups}

          {:error, error} ->
            Logger.error(
              "Failed to get external groups for character #{character_id}: #{inspect(error)}"
            )

            {:error, :query_failed}
        end
      end,
      ttl: @external_groups_ttl
    )
  end

  defp process_external_group_row([
         corp_id,
         corp_name,
         alliance_id,
         alliance_name,
         kills_together,
         unique_pilots,
         systems_active,
         total_isk,
         avg_kill_value,
         last_seen,
         first_seen
       ]) do
    collaboration_strength =
      calculate_collaboration_strength(kills_together, unique_pilots, systems_active)

    relationship_type =
      determine_relationship_type(
        kills_together,
        unique_pilots,
        first_seen,
        last_seen
      )

    days_since_last = calculate_days_since_last(last_seen)

    %{
      corporation_id: corp_id,
      corporation_name: corp_name || "Unknown Corporation",
      alliance_id: alliance_id,
      alliance_name: alliance_name,
      kills_together: kills_together,
      unique_pilots: unique_pilots,
      systems_active: systems_active,
      total_isk_destroyed: Decimal.to_float(total_isk || Decimal.new(0)),
      avg_kill_value: Decimal.to_float(avg_kill_value || Decimal.new(0)),
      last_seen: last_seen,
      first_seen: first_seen,
      days_since_last: days_since_last,
      collaboration_strength: collaboration_strength,
      relationship_type: relationship_type,
      trust_level: calculate_trust_level(kills_together, days_since_last)
    }
  end

  # Pattern matching in function heads instead of if statement
  defp calculate_days_since_last(nil), do: nil

  defp calculate_days_since_last(last_seen) do
    Date.diff(Date.utc_today(), Date.from_iso8601!(Date.to_iso8601(last_seen)))
  end

  defp calculate_collaboration_strength(kills_together, unique_pilots, systems_active) do
    base_score =
      case kills_together do
        n when n >= 20 -> 80
        n when n >= 10 -> 60
        n when n >= 5 -> 40
        n when n >= 2 -> 20
        _ -> 10
      end

    pilot_boost = min(unique_pilots * 5, 15)
    system_boost = min(systems_active * 2, 10)
    total_score = base_score + pilot_boost + system_boost

    cond do
      total_score >= 90 -> :very_strong
      total_score >= 70 -> :strong
      total_score >= 50 -> :moderate
      total_score >= 30 -> :weak
      true -> :minimal
    end
  end

  defp determine_relationship_type(kills_together, unique_pilots, first_seen, last_seen) do
    time_span_days =
      if first_seen && last_seen do
        last_seen_date =
          last_seen
          |> Date.to_iso8601()
          |> Date.from_iso8601!()

        first_seen_date =
          first_seen
          |> Date.to_iso8601()
          |> Date.from_iso8601!()

        Date.diff(last_seen_date, first_seen_date)
      else
        0
      end

    cond do
      kills_together >= 15 and time_span_days > 30 -> :long_term_ally
      kills_together >= 10 and time_span_days <= 7 -> :intensive_campaign
      kills_together >= 5 and unique_pilots >= 5 -> :joint_operations
      kills_together >= 3 and time_span_days <= 1 -> :single_event
      kills_together >= 2 and time_span_days <= 3 -> :short_term_cooperation
      true -> :occasional_teamup
    end
  end

  defp calculate_trust_level(kills_together, days_since_last) do
    base_trust =
      case kills_together do
        n when n >= 20 -> :high
        n when n >= 10 -> :moderate
        n when n >= 5 -> :developing
        _ -> :low
      end

    case {base_trust, days_since_last} do
      {trust, days} when days != nil and days <= 7 ->
        case trust do
          :low -> :developing
          :developing -> :moderate
          :moderate -> :high
          :high -> :very_high
        end

      {trust, days} when days != nil and days > 90 ->
        case trust do
          :high -> :moderate
          :moderate -> :developing
          :developing -> :low
          :low -> :minimal
        end

      {trust, _} ->
        trust
    end
  end
end
