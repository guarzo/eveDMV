defmodule EveDmv.Killmails.DisplayService do
  @moduledoc """
  Business logic for killmail display and formatting
  """

  alias EveDmv.Api
  alias EveDmv.Constants.Isk
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Utils.ParsingUtils

  require Ash.Query

  @feed_limit 50

  def load_recent_killmails(limit \\ @feed_limit) do
    # Always load from raw killmails since enriched data isn't actually enriched
    # This gives us access to character/corp names from wanderer-kills
    raw =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(limit)
      |> Ash.read!(domain: Api)

    # Preload names for raw killmails
    preload_raw_killmail_names(raw)
    Enum.map(raw, &build_killmail_from_raw/1)
  end

  def preload_killmail_names(killmails) do
    # Extract all unique IDs that need name resolution
    ship_type_ids =
      killmails
      |> Stream.map(& &1.victim_ship_type_id)
      |> Stream.reject(&is_nil/1)
      |> Enum.uniq()

    system_ids =
      killmails
      |> Stream.map(& &1.solar_system_id)
      |> Stream.reject(&is_nil/1)
      |> Enum.uniq()

    # Bulk preload all names into cache
    NameResolver.ship_names(ship_type_ids)
    NameResolver.system_names(system_ids)

    # Preload system security data too
    Enum.each(system_ids, &NameResolver.system_security/1)
  end

  # REMOVED: build_killmail_from_enriched function
  # Enriched table provides no value - see /docs/architecture/enriched-raw-analysis.md

  def build_killmail_display(killmail_data) do
    # Handle wanderer-kills format with separate victim and attackers
    victim = killmail_data["victim"] || %{}
    attackers = killmail_data["attackers"] || []
    final_blow = Enum.find(attackers, & &1["final_blow"])

    system_id = extract_solar_system_id(killmail_data)

    # Use name resolution for ship and system names
    victim_ship_name =
      resolve_name_if_unknown(
        victim["ship_name"],
        ["Unknown Ship"],
        fn -> NameResolver.ship_name(victim["ship_type_id"]) end
      )

    system_name =
      resolve_name_if_unknown(
        killmail_data["solar_system_name"],
        ["Unknown System"],
        fn -> NameResolver.system_name(system_id) end
      )

    system_security = NameResolver.system_security(system_id)

    %{
      id: generate_killmail_id(killmail_data),
      killmail_id: killmail_data["killmail_id"],
      killmail_time: parse_killmail_timestamp(killmail_data),
      victim_character_id: victim["character_id"],
      victim_character_name: victim["character_name"] || "Unknown Pilot",
      victim_corporation_name: victim["corporation_name"] || "Unknown Corp",
      victim_alliance_name: victim["alliance_name"],
      victim_ship_name: victim_ship_name,
      solar_system_id: system_id,
      solar_system_name: system_name,
      security_class: system_security.class,
      security_color: system_security.color,
      security_status: system_security.status,
      total_value: extract_total_value(killmail_data),
      ship_value: extract_ship_value(killmail_data),
      attacker_count: killmail_data["attacker_count"] || length(attackers),
      final_blow_character_id: get_in(final_blow, ["character_id"]),
      final_blow_character_name: get_in(final_blow, ["character_name"]),
      age_minutes: 0,
      is_expensive: expensive_kill_wanderer(killmail_data)
    }
  end

  def calculate_system_stats(killmails) do
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, kills} ->
      system_name = List.first(kills).solar_system_name
      kill_count = length(kills)

      total_isk =
        Enum.reduce(kills, Decimal.new(0), fn kill, acc ->
          Decimal.add(acc, kill.total_value)
        end)

      %{
        system_id: system_id,
        system_name: system_name,
        kill_count: kill_count,
        total_isk: total_isk,
        avg_isk: if(kill_count > 0, do: Decimal.div(total_isk, kill_count), else: Decimal.new(0))
      }
    end)
    |> Enum.sort_by(& &1.kill_count, :desc)
    |> Enum.take(10)
  end

  def calculate_total_isk(killmails) do
    Enum.reduce(killmails, Decimal.new(0), fn kill, acc ->
      Decimal.add(acc, kill.total_value)
    end)
  end

  # Private helpers

  defp preload_raw_killmail_names(raw_killmails) do
    # Extract IDs from raw killmail data
    ship_type_ids =
      raw_killmails
      |> Enum.map(fn raw ->
        victim = find_victim_in_raw(raw.raw_data)
        get_in(victim, ["ship_type_id"])
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    system_ids =
      raw_killmails
      |> Enum.map(fn raw ->
        get_in(raw.raw_data, ["solar_system_id"])
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    # Bulk preload all names into cache
    NameResolver.ship_names(ship_type_ids)
    NameResolver.system_names(system_ids)

    # Preload system security data
    Enum.each(system_ids, &NameResolver.system_security/1)
  end

  defp build_killmail_from_raw(raw) do
    # Cache current time to ensure consistency
    now = DateTime.utc_now()
    victim = find_victim_in_raw(raw.raw_data)
    final_blow = find_final_blow_in_raw(raw.raw_data)

    # Use name resolution for ship and system names
    victim_ship_type_id = get_in(victim, ["ship_type_id"]) || raw.victim_ship_type_id

    victim_ship_name =
      resolve_name_if_unknown(
        get_in(victim, ["ship_name"]),
        ["Unknown Ship"],
        fn -> NameResolver.ship_name(victim_ship_type_id) end
      )

    system_name =
      resolve_name_if_unknown(
        raw.raw_data["solar_system_name"],
        ["Unknown System"],
        fn -> NameResolver.system_name(raw.solar_system_id) end
      )

    system_security = NameResolver.system_security(raw.solar_system_id)

    %{
      id: "#{raw.killmail_id}-#{DateTime.to_unix(raw.killmail_time)}",
      killmail_id: raw.killmail_id,
      killmail_time: raw.killmail_time,
      victim_character_id: get_in(victim, ["character_id"]) || raw.victim_character_id,
      victim_character_name: get_in(victim, ["character_name"]) || "Unknown Pilot",
      victim_corporation_name: get_in(victim, ["corporation_name"]) || "Unknown Corp",
      victim_alliance_name: get_in(victim, ["alliance_name"]),
      victim_ship_name: victim_ship_name,
      solar_system_id: raw.solar_system_id,
      solar_system_name: system_name,
      security_class: system_security.class,
      security_color: system_security.color,
      security_status: system_security.status,
      total_value: extract_total_value(raw.raw_data),
      ship_value: extract_ship_value(raw.raw_data),
      attacker_count: raw.attacker_count,
      final_blow_character_id: get_in(final_blow, ["character_id"]),
      final_blow_character_name: get_in(final_blow, ["character_name"]),
      age_minutes: DateTime.diff(now, raw.killmail_time, :minute),
      is_expensive: expensive_kill_wanderer(raw.raw_data)
    }
  end

  defp find_victim_in_raw(raw_data) do
    # Handle wanderer-kills format with separate victim field
    case raw_data["victim"] do
      nil ->
        # Fallback to old participants format
        Enum.find(raw_data["participants"] || [], & &1["is_victim"])

      victim ->
        victim
    end
  end

  defp find_final_blow_in_raw(raw_data) do
    # Handle wanderer-kills format with separate attackers field
    case raw_data["attackers"] do
      nil ->
        # Fallback to old participants format
        Enum.find(raw_data["participants"] || [], &(&1["final_blow"] && !&1["is_victim"]))

      attackers when is_list(attackers) ->
        Enum.find(attackers, & &1["final_blow"])

      _ ->
        nil
    end
  end

  defp generate_killmail_id(killmail_data) do
    # Use current timestamp for ID generation
    now = DateTime.utc_now()
    "#{killmail_data["killmail_id"]}-#{DateTime.to_unix(now)}"
  end

  defp expensive_kill_wanderer(killmail_data) do
    total_value =
      get_in(killmail_data, ["zkb", "totalValue"]) || killmail_data["total_value"] || 0

    total_value > Isk.million() * 100
  end

  defp parse_killmail_timestamp(killmail_data) do
    # Cache fallback time to avoid multiple calls
    fallback_time = DateTime.utc_now()

    case killmail_data["kill_time"] || killmail_data["timestamp"] do
      nil ->
        fallback_time

      timestamp when is_binary(timestamp) ->
        case DateTime.from_iso8601(timestamp) do
          {:ok, dt, _} -> dt
          _ -> fallback_time
        end

      _ ->
        fallback_time
    end
  end

  defp extract_solar_system_id(killmail_data) do
    killmail_data["solar_system_id"] || killmail_data["system_id"] || 30_000_142
  end

  defp extract_total_value(killmail_data) do
    value = get_in(killmail_data, ["zkb", "totalValue"]) || killmail_data["total_value"] || 0
    safe_decimal_new(value)
  end

  defp extract_ship_value(killmail_data) do
    value = get_in(killmail_data, ["zkb", "destroyedValue"]) || killmail_data["ship_value"] || 0
    safe_decimal_new(value)
  end

  # Helper function to safely create Decimal from various number types
  defp safe_decimal_new(value), do: ParsingUtils.parse_decimal(value)

  # Helper function to resolve names if they are unknown/empty
  defp resolve_name_if_unknown(name, fallback_values, resolver_fn)
       when is_list(fallback_values) do
    if name in ([nil, ""] ++ fallback_values) do
      resolver_fn.()
    else
      name
    end
  end
end
