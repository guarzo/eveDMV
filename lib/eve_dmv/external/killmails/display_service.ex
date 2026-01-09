defmodule EveDmv.Killmails.DisplayService do
  @moduledoc """
  Business logic for killmail display and formatting
  """

  alias EveDmv.Constants.Isk
  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Core.Utils.ParsingUtils
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.KillmailRaw

  require Ash.Query

  @feed_limit 50

  def load_recent_killmails(limit \\ @feed_limit, filters \\ %{}, offset \\ 0) do
    # Always load from raw killmails since enriched data isn't actually enriched
    # This gives us access to character/corp names from wanderer-kills
    base_query =
      KillmailRaw
      |> Ash.Query.new()
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(limit)
      |> Ash.Query.offset(offset)

    # Apply filters if provided
    query = apply_filters(base_query, filters)

    raw = Ash.read!(query, domain: EveDmv.Api)

    # Preload names for raw killmails
    preload_raw_killmail_names(raw)

    # Map to display format
    killmails = Enum.map(raw, &build_killmail_from_raw/1)

    # Apply post-load filters (for fields not in the raw table)
    apply_post_load_filters(killmails, filters)
  end

  @doc """
  Load killmails for pagination with metadata about whether more exist.
  """
  def load_killmails_page(limit \\ @feed_limit, filters \\ %{}, offset \\ 0) do
    # Load one extra to check if there are more
    killmails = load_recent_killmails(limit + 1, filters, offset)

    has_more = length(killmails) > limit
    page_killmails = if has_more, do: Enum.take(killmails, limit), else: killmails

    %{
      killmails: page_killmails,
      has_more: has_more,
      next_offset: offset + length(page_killmails)
    }
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

    # Preload system security data using batch function
    NameResolver.system_securities(system_ids)
  end

  def build_killmail_display(killmail_data) do
    # Use pre-computed display fields from KillmailBroadcaster when available
    case killmail_data do
      %{display: display, victim: victim_data}
      when is_map(display) and map_size(display) > 0 and is_map(victim_data) ->
        # Use optimized format from KillmailBroadcaster
        build_from_optimized_payload(killmail_data)

      _ ->
        # Legacy format - do full processing
        build_from_raw_data(killmail_data)
    end
  end

  # Build display from optimized payload with pre-computed fields
  defp build_from_optimized_payload(payload) do
    start_time = System.monotonic_time(:microsecond)
    killmail_id = payload[:killmail_id]

    victim = payload[:victim] || %{}
    system_id = payload[:solar_system_id]
    display = payload[:display] || %{}

    # Extract final blow attacker from attackers array
    attackers = payload[:attackers] || []
    final_blow = Enum.find(attackers, &(&1[:final_blow] || &1["final_blow"]))

    # Get system security info (this is cached and fast)
    system_security = NameResolver.system_security(system_id)

    # Ship name from payload, with fallback to resolver if missing
    used_name_resolver = victim[:ship_name] in [nil, "Unknown Ship"]

    victim_ship_name =
      case victim[:ship_name] do
        nil -> NameResolver.ship_name(victim[:ship_type_id])
        "Unknown Ship" -> NameResolver.ship_name(victim[:ship_type_id])
        name -> name
      end

    # Calculate age_minutes from killmail_time
    killmail_time = payload[:killmail_time]
    age_minutes = calculate_age_minutes(killmail_time)

    result = %{
      id: generate_killmail_id(payload, killmail_time),
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      victim_character_id: victim[:character_id],
      victim_character_name: victim[:character_name] || "Unknown Pilot",
      victim_corporation_name: victim[:corporation_name] || "Unknown Corp",
      victim_alliance_name: victim[:alliance_name],
      victim_ship_name: victim_ship_name,
      solar_system_id: system_id,
      solar_system_name: payload[:solar_system_name] || "Unknown System",
      security_class: system_security.class,
      security_color: system_security.color,
      security_status: system_security.status,
      total_value: payload[:total_value] || Decimal.new(0),
      ship_value: payload[:ship_value],
      attacker_count: payload[:attacker_count] || 0,
      final_blow_character_id: get_final_blow_field(final_blow, :character_id),
      final_blow_character_name: get_final_blow_field(final_blow, :character_name),
      age_minutes: age_minutes,
      is_expensive: display[:is_high_value] || false
    }

    # Emit telemetry for optimized path performance monitoring
    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute(
      [:eve_dmv, :killmail, :display, :optimized_path],
      %{duration: duration},
      %{
        killmail_id: killmail_id,
        attacker_count: payload[:attacker_count] || 0,
        used_name_resolver: used_name_resolver
      }
    )

    result
  end

  # Helper to get final blow field with atom/string key support
  defp get_final_blow_field(nil, _field), do: nil

  defp get_final_blow_field(final_blow, field) when is_atom(field) do
    final_blow[field] || final_blow[Atom.to_string(field)]
  end

  # Calculate age in minutes from killmail time
  defp calculate_age_minutes(nil), do: 0

  defp calculate_age_minutes(killmail_time) when is_struct(killmail_time, DateTime) do
    DateTimeUtils.diff(DateTime.utc_now(), killmail_time, :minute)
  end

  defp calculate_age_minutes(killmail_time) when is_binary(killmail_time) do
    case DateTime.from_iso8601(killmail_time) do
      {:ok, dt, _} -> DateTimeUtils.diff(DateTime.utc_now(), dt, :minute)
      _ -> 0
    end
  end

  defp calculate_age_minutes(_), do: 0

  # Build display from raw wanderer-kills data (legacy path)
  defp build_from_raw_data(killmail_data) do
    # Handle both wanderer-kills formats:
    # 1. Separate victim/attackers fields
    # 2. Participants array with is_victim flag
    victim = find_victim_in_raw(killmail_data)
    attackers = find_attackers_in_raw(killmail_data)
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

    # Corporation names are resolved at ingestion time - no dynamic lookup available
    victim_corporation_name =
      resolve_name_if_unknown(
        victim["corporation_name"],
        ["Unknown Corp"],
        fn -> "Unknown Corp" end
      )

    system_security = NameResolver.system_security(system_id)

    # Parse killmail_time once for both ID generation and display
    killmail_time = parse_killmail_timestamp(killmail_data)

    %{
      id: generate_killmail_id(killmail_data, killmail_time),
      killmail_id: killmail_data["killmail_id"],
      killmail_time: killmail_time,
      victim_character_id: victim["character_id"],
      victim_character_name: victim["character_name"] || "Unknown Pilot",
      victim_corporation_name: victim_corporation_name,
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

    # Bulk preload static data (ships, systems)
    # Corporation names are resolved at ingestion time in DataProcessor.enrich_entity_names/1
    NameResolver.ship_names(ship_type_ids)
    NameResolver.system_names(system_ids)
    NameResolver.system_securities(system_ids)
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

    # Corporation names are resolved at ingestion time - no dynamic lookup available
    victim_corporation_name =
      resolve_name_if_unknown(
        get_in(victim, ["corporation_name"]),
        ["Unknown Corp"],
        fn -> "Unknown Corp" end
      )

    system_security = NameResolver.system_security(raw.solar_system_id)

    %{
      id: "#{raw.killmail_id}-#{DateTime.to_unix(raw.killmail_time)}",
      killmail_id: raw.killmail_id,
      killmail_time: raw.killmail_time,
      victim_character_id: get_in(victim, ["character_id"]) || raw.victim_character_id,
      victim_character_name: get_in(victim, ["character_name"]) || "Unknown Pilot",
      victim_corporation_name: victim_corporation_name,
      victim_alliance_name: get_in(victim, ["alliance_name"]),
      victim_ship_name: victim_ship_name,
      solar_system_id: raw.solar_system_id,
      solar_system_name: system_name,
      security_class: system_security.class,
      security_color: system_security.color,
      security_status: system_security.status,
      total_value: get_total_value(raw),
      ship_value: extract_ship_value(raw.raw_data),
      attacker_count: raw.attacker_count,
      final_blow_character_id: get_in(final_blow, ["character_id"]),
      final_blow_character_name: get_in(final_blow, ["character_name"]),
      age_minutes: DateTimeUtils.diff(now, raw.killmail_time, :minute),
      is_expensive: expensive_kill_wanderer(raw.raw_data)
    }
  end

  defp find_victim_in_raw(raw_data) do
    # Handle wanderer-kills format with separate victim field
    case raw_data["victim"] do
      nil ->
        # Fallback to old participants format
        Enum.find(raw_data["participants"] || [], & &1["is_victim"]) || %{}

      victim ->
        victim
    end
  end

  defp find_attackers_in_raw(raw_data) do
    # Handle wanderer-kills format with separate attackers field
    case raw_data["attackers"] do
      nil ->
        # Fallback to old participants format
        Enum.filter(raw_data["participants"] || [], &(!&1["is_victim"]))

      attackers when is_list(attackers) ->
        attackers

      _ ->
        []
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

  defp generate_killmail_id(killmail_data, killmail_time) do
    # Use killmail_time for stable ID generation
    # Handle both atom keys (optimized payload) and string keys (raw data)
    killmail_id = killmail_data[:killmail_id] || killmail_data["killmail_id"]
    generate_killmail_id_from_time(killmail_id, killmail_time)
  end

  @doc """
  Generates a stable killmail ID from a killmail_id and killmail_time.

  Handles both DateTime structs and ISO8601 strings for the time parameter.
  Returns a string in the format "killmail_id-unix_timestamp".

  ## Examples

      iex> generate_killmail_id_from_time(12345, ~U[2024-01-15 10:30:00Z])
      "12345-1705314600"

      iex> generate_killmail_id_from_time(12345, "2024-01-15T10:30:00Z")
      "12345-1705314600"

      iex> generate_killmail_id_from_time(12345, nil)
      "12345-0"
  """
  @spec generate_killmail_id_from_time(integer() | String.t(), DateTime.t() | String.t() | nil) ::
          String.t()
  def generate_killmail_id_from_time(killmail_id, killmail_time) do
    timestamp = killmail_time_to_unix(killmail_time)
    "#{killmail_id}-#{timestamp}"
  end

  # Convert killmail_time to unix timestamp, handling various formats
  defp killmail_time_to_unix(nil), do: 0

  defp killmail_time_to_unix(killmail_time) when is_struct(killmail_time, DateTime) do
    DateTime.to_unix(killmail_time)
  end

  defp killmail_time_to_unix(killmail_time) when is_binary(killmail_time) do
    case DateTime.from_iso8601(killmail_time) do
      {:ok, dt, _} -> DateTime.to_unix(dt)
      _ -> 0
    end
  end

  defp killmail_time_to_unix(_), do: 0

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

  # Use the resource's total_value attribute if available, otherwise extract from raw_data
  defp get_total_value(raw) do
    if raw.total_value && Decimal.compare(raw.total_value, Decimal.new(0)) != :eq do
      raw.total_value
    else
      extract_total_value(raw.raw_data)
    end
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

  # Filter functions
  defp apply_filters(query, filters) do
    query
    |> maybe_filter_by_system(filters[:system_id])
    |> maybe_filter_by_ship_type(filters[:ship_type_id])
    |> maybe_filter_by_value_range(filters[:min_value], filters[:max_value])
  end

  defp maybe_filter_by_system(query, nil), do: query

  defp maybe_filter_by_system(query, system_id) do
    Ash.Query.filter(query, solar_system_id == ^system_id)
  end

  defp maybe_filter_by_ship_type(query, nil), do: query

  defp maybe_filter_by_ship_type(query, ship_type_id) do
    Ash.Query.filter(query, victim_ship_type_id == ^ship_type_id)
  end

  defp maybe_filter_by_value_range(query, nil, nil), do: query

  defp maybe_filter_by_value_range(query, min_value, nil) do
    Ash.Query.filter(query, total_value >= ^min_value)
  end

  defp maybe_filter_by_value_range(query, nil, max_value) do
    Ash.Query.filter(query, total_value <= ^max_value)
  end

  defp maybe_filter_by_value_range(query, min_value, max_value) do
    query
    |> Ash.Query.filter(total_value >= ^min_value)
    |> Ash.Query.filter(total_value <= ^max_value)
  end

  # Post-load filters for fields not in the raw table
  defp apply_post_load_filters(killmails, filters) do
    killmails
    |> maybe_filter_by_alliance(filters[:alliance_name])
    |> maybe_filter_by_corporation(filters[:corporation_name])
    |> maybe_filter_by_character(filters[:character_name])
    |> maybe_filter_by_ship_class(filters[:ship_class])
  end

  defp maybe_filter_by_alliance(killmails, nil), do: killmails

  defp maybe_filter_by_alliance(killmails, alliance_name) do
    Enum.filter(killmails, fn km ->
      km.victim_alliance_name &&
        String.downcase(km.victim_alliance_name) == String.downcase(alliance_name)
    end)
  end

  defp maybe_filter_by_corporation(killmails, nil), do: killmails

  defp maybe_filter_by_corporation(killmails, corporation_name) do
    Enum.filter(killmails, fn km ->
      km.victim_corporation_name &&
        String.downcase(km.victim_corporation_name) == String.downcase(corporation_name)
    end)
  end

  defp maybe_filter_by_character(killmails, nil), do: killmails

  defp maybe_filter_by_character(killmails, character_name) do
    Enum.filter(killmails, fn km ->
      (km.victim_character_name &&
         String.downcase(km.victim_character_name) == String.downcase(character_name)) ||
        (km.final_blow_character_name &&
           String.downcase(km.final_blow_character_name) == String.downcase(character_name))
    end)
  end

  defp maybe_filter_by_ship_class(killmails, nil), do: killmails

  defp maybe_filter_by_ship_class(killmails, ship_class) do
    # This would require ship classification logic
    # For now, we'll do simple name matching
    Enum.filter(killmails, fn km ->
      km.victim_ship_name &&
        String.contains?(String.downcase(km.victim_ship_name), String.downcase(ship_class))
    end)
  end

  # Helper function to get available alliances from recent kills
  def get_recent_alliances(limit \\ 100) do
    killmails = load_recent_killmails(limit)

    killmails
    |> Enum.map(& &1.victim_alliance_name)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_alliance, count} -> count end, :desc)
    |> Enum.take(20)
    |> Enum.map(fn {alliance, count} -> %{name: alliance, count: count} end)
  end

  # Helper function to get available ship types from recent kills
  def get_recent_ship_types(limit \\ 100) do
    killmails = load_recent_killmails(limit)

    killmails
    |> Enum.map(& &1.victim_ship_name)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_ship, count} -> count end, :desc)
    |> Enum.take(20)
    |> Enum.map(fn {ship, count} -> %{name: ship, count: count} end)
  end
end
