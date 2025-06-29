defmodule EveDmvWeb.KillFeedLive do
  @moduledoc """
  Public live kill feed displaying real-time killmail data.
  """

  use EveDmvWeb, :live_view

  alias EveDmv.Api
  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.{KillmailEnriched, KillmailRaw}

  @topic "kill_feed"
  @feed_limit 50

  def mount(_params, _session, socket) do
    # Subscribe to kill feed updates
    if connected?(socket) do
      Phoenix.PubSub.subscribe(EveDmv.PubSub, @topic)
    end

    # Load initial killmails
    killmails = load_recent_killmails()
    system_stats = calculate_system_stats(killmails)

    socket =
      socket
      |> assign(:killmails, killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(killmails))
      |> assign(:total_isk_destroyed, calculate_total_isk(killmails))
      |> stream(:killmail_stream, killmails)

    {:ok, socket}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: "kill_feed", event: "new_kill", payload: killmail_data},
        socket
      ) do
    # Add new killmail to the stream
    new_killmail = build_killmail_display(killmail_data)

    # Update stats
    current_killmails = [new_killmail | socket.assigns.killmails]
    limited_killmails = Enum.take(current_killmails, @feed_limit)
    system_stats = calculate_system_stats(limited_killmails)

    socket =
      socket
      |> assign(:killmails, limited_killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, socket.assigns.total_kills_today + 1)
      |> assign(
        :total_isk_destroyed,
        Decimal.add(socket.assigns.total_isk_destroyed, new_killmail.total_value)
      )
      |> stream_insert(:killmail_stream, new_killmail, at: 0)

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def handle_event("refresh_feed", _params, socket) do
    killmails = load_recent_killmails()
    system_stats = calculate_system_stats(killmails)

    socket =
      socket
      |> assign(:killmails, killmails)
      |> assign(:system_stats, system_stats)
      |> assign(:total_kills_today, length(killmails))
      |> assign(:total_isk_destroyed, calculate_total_isk(killmails))
      |> stream(:killmail_stream, killmails, reset: true)

    {:noreply, socket}
  end

  def handle_event("filter_by_system", %{"system_id" => system_id}, socket) do
    system_id = String.to_integer(system_id)
    filtered_killmails = Enum.filter(socket.assigns.killmails, &(&1.solar_system_id == system_id))

    socket =
      socket
      |> stream(:killmail_stream, filtered_killmails, reset: true)

    {:noreply, socket}
  end

  # Private helper functions

  defp load_recent_killmails do
    # Try to load from enriched killmails first
    enriched =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.sort(killmail_time: :desc)
      |> Ash.Query.limit(@feed_limit)
      |> Ash.read!(domain: Api)

    if length(enriched) > 0 do
      Enum.map(enriched, &build_killmail_from_enriched/1)
    else
      # Fallback to raw killmails if no enriched data
      raw =
        KillmailRaw
        |> Ash.Query.new()
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.Query.limit(@feed_limit)
        |> Ash.read!(domain: Api)

      Enum.map(raw, &build_killmail_from_raw/1)
    end
  rescue
    _ ->
      # If database is empty, generate sample data for demo
      generate_sample_killmails()
  end

  defp build_killmail_from_enriched(enriched) do
    # Use name resolution for ship and system names if not already provided
    victim_ship_name =
      resolve_name_if_unknown(
        enriched.victim_ship_name,
        ["Unknown Ship"],
        fn -> NameResolver.ship_name(enriched.victim_ship_type_id) end
      )

    system_name =
      resolve_name_if_unknown(
        enriched.solar_system_name,
        ["Unknown System"],
        fn -> NameResolver.system_name(enriched.solar_system_id) end
      )

    system_security = NameResolver.system_security(enriched.solar_system_id)

    %{
      id: "#{enriched.killmail_id}-#{DateTime.to_unix(enriched.killmail_time)}",
      killmail_id: enriched.killmail_id,
      killmail_time: enriched.killmail_time,
      victim_character_id: enriched.victim_character_id,
      victim_character_name: enriched.victim_character_name || "Unknown Pilot",
      victim_corporation_name: enriched.victim_corporation_name || "Unknown Corp",
      victim_alliance_name: enriched.victim_alliance_name,
      victim_ship_name: victim_ship_name,
      solar_system_id: enriched.solar_system_id,
      solar_system_name: system_name,
      security_class: system_security.class,
      security_color: system_security.color,
      security_status: system_security.status,
      total_value: enriched.total_value || Decimal.new(0),
      ship_value: enriched.ship_value || Decimal.new(0),
      attacker_count: enriched.attacker_count || 0,
      final_blow_character_id: enriched.final_blow_character_id,
      final_blow_character_name: enriched.final_blow_character_name,
      age_minutes: DateTime.diff(DateTime.utc_now(), enriched.killmail_time, :minute),
      is_expensive: Decimal.gt?(enriched.total_value || Decimal.new(0), Decimal.new(100_000_000))
    }
  end

  defp build_killmail_from_raw(raw) do
    victim = find_victim_in_raw(raw.raw_data)
    final_blow = find_final_blow_in_raw(raw.raw_data)

    # Use name resolution for ship and system names
    victim_ship_name =
      resolve_name_if_unknown(
        get_in(victim, ["ship_name"]),
        ["Unknown Ship"],
        fn -> NameResolver.ship_name(raw.victim_ship_type_id) end
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
      total_value: safe_decimal_new(raw.raw_data["total_value"] || 0),
      ship_value: safe_decimal_new(raw.raw_data["ship_value"] || 0),
      attacker_count: raw.attacker_count,
      final_blow_character_id: get_in(final_blow, ["character_id"]),
      final_blow_character_name: get_in(final_blow, ["character_name"]),
      age_minutes: DateTime.diff(DateTime.utc_now(), raw.killmail_time, :minute),
      is_expensive: (raw.raw_data["total_value"] || 0) > 100_000_000
    }
  end

  defp build_killmail_display(killmail_data) do
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

  defp generate_killmail_id(killmail_data) do
    "#{killmail_data["killmail_id"]}-#{DateTime.utc_now() |> DateTime.to_unix()}"
  end

  defp expensive_kill_wanderer(killmail_data) do
    total_value =
      get_in(killmail_data, ["zkb", "totalValue"]) || killmail_data["total_value"] || 0

    total_value > 100_000_000
  end

  defp find_victim_in_raw(raw_data) do
    Enum.find(raw_data["participants"] || [], & &1["is_victim"])
  end

  defp find_final_blow_in_raw(raw_data) do
    Enum.find(raw_data["participants"] || [], &(&1["final_blow"] && !&1["is_victim"]))
  end

  defp generate_sample_killmails do
    # Generate sample data for demo purposes
    1..@feed_limit
    |> Enum.map(fn i ->
      timestamp = DateTime.add(DateTime.utc_now(), -i * 60, :second)
      value = Enum.random(10_000_000..1_000_000_000)
      system_id = Enum.random([30_000_142, 30_000_144, 30_002_187, 30_002_659])

      # Use name resolution for sample data too
      system_security = NameResolver.system_security(system_id)
      system_name = NameResolver.system_name(system_id)

      %{
        id: "demo-#{i}",
        killmail_id: 900_000_000 + i,
        killmail_time: timestamp,
        victim_character_name: "Demo Pilot #{i}",
        victim_corporation_name: "Demo Corp #{rem(i, 10)}",
        victim_alliance_name: if(rem(i, 3) == 0, do: "Demo Alliance", else: nil),
        victim_ship_name: Enum.random(["Rifter", "Punisher", "Merlin", "Venture", "Catalyst"]),
        solar_system_id: system_id,
        solar_system_name: system_name,
        security_class: system_security.class,
        security_color: system_security.color,
        security_status: system_security.status,
        total_value: safe_decimal_new(value),
        ship_value: safe_decimal_new(div(value, 3)),
        attacker_count: Enum.random(1..5),
        final_blow_character_name: "Attacker #{i}",
        age_minutes: i,
        is_expensive: value > 100_000_000
      }
    end)
  end

  defp calculate_system_stats(killmails) do
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

  defp calculate_total_isk(killmails) do
    Enum.reduce(killmails, Decimal.new(0), fn kill, acc ->
      Decimal.add(acc, kill.total_value)
    end)
  end

  # Helper functions for build_killmail_display

  defp parse_killmail_timestamp(killmail_data) do
    case killmail_data["kill_time"] || killmail_data["timestamp"] do
      nil ->
        DateTime.utc_now()

      timestamp when is_binary(timestamp) ->
        case DateTime.from_iso8601(timestamp) do
          {:ok, dt, _} -> dt
          _ -> DateTime.utc_now()
        end

      _ ->
        DateTime.utc_now()
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
  defp safe_decimal_new(value) when is_integer(value), do: Decimal.new(value)
  defp safe_decimal_new(value) when is_float(value), do: Decimal.from_float(value)
  defp safe_decimal_new(value) when is_binary(value), do: Decimal.new(value)
  defp safe_decimal_new(_), do: Decimal.new(0)

  # Helper function to resolve names if they are unknown/empty
  defp resolve_name_if_unknown(name, fallback_values, resolver_fn)
       when is_list(fallback_values) do
    if name in ([nil, ""] ++ fallback_values) do
      resolver_fn.()
    else
      name
    end
  end

  # Template helper functions

  def format_isk(decimal_value) when is_struct(decimal_value, Decimal) do
    value = Decimal.to_float(decimal_value)
    format_isk(value)
  end

  def format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000_000 -> "#{Float.round(value / 1_000_000_000_000, 1)}T ISK"
      value >= 1_000_000_000 -> "#{Float.round(value / 1_000_000_000, 1)}B ISK"
      value >= 1_000_000 -> "#{Float.round(value / 1_000_000, 1)}M ISK"
      value >= 1_000 -> "#{Float.round(value / 1_000, 1)}K ISK"
      true -> "#{trunc(value)} ISK"
    end
  end

  def format_isk(_), do: "0 ISK"

  def format_time_ago(minutes) when is_integer(minutes) do
    cond do
      minutes < 1 -> "Just now"
      minutes < 60 -> "#{minutes}m ago"
      minutes < 1440 -> "#{div(minutes, 60)}h ago"
      true -> "#{div(minutes, 1440)}d ago"
    end
  end

  def format_time_ago(_), do: "Unknown"
end
