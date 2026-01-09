defmodule EveDmv.Killmails.KillmailBroadcaster do
  @moduledoc """
  Handles broadcasting and surveillance matching for processed killmails.

  Provides PubSub broadcasting to LiveView clients and surveillance profile
  matching for real-time notifications.

  ## Performance Optimization

  This module includes display-ready data in broadcasts to eliminate
  database queries from LiveView handle_info callbacks. Payload includes:
  - Pre-formatted ISK values
  - Time-ago strings
  - zkillboard URLs
  - All entity names and IDs

  This reduces cascading queries during high-frequency broadcasts (100+ kills/min).
  """

  alias Broadway.Message
  alias EveDmv.Surveillance.MatchingEngine

  require Logger

  # Use PubSub directly instead of Endpoint to avoid web layer dependency
  @pubsub EveDmv.PubSub

  # Time constants for formatting
  @seconds_per_day 86_400

  # High value threshold: 1 billion ISK
  @high_value_threshold 1_000_000_000

  @doc """
  Broadcast killmails to LiveView clients via PubSub.

  Sends killmail data to the "kill_feed" topic for real-time updates
  in the UI. Includes pre-formatted display data to avoid database queries
  in LiveViews. Handles errors gracefully to prevent pipeline failures.
  """
  @spec broadcast_killmails([Message.t()]) :: :ok
  def broadcast_killmails(messages) do
    for %Message{data: killmail_data} <- messages do
      try do
        # Build enriched payload with display-ready data
        # Skip broadcasting if payload is nil (invalid format)
        case build_broadcast_payload(killmail_data) do
          nil ->
            :skipped

          payload ->
            # Use PubSub directly to avoid web layer dependency
            Phoenix.PubSub.broadcast(@pubsub, "kill_feed", {"new_kill", payload})
        end
      rescue
        error ->
          Logger.warning("Failed to broadcast killmail: #{inspect(error)}")
      end
    end

    :ok
  end

  @doc """
  Build broadcast payload with display-ready data.

  Extracts essential data from the killmail tuple and adds pre-formatted
  display fields to eliminate database queries in LiveViews.
  """
  @spec build_broadcast_payload({map(), map(), [map()]} | map() | term()) :: map() | nil
  def build_broadcast_payload({raw_changeset, enriched_changeset, participants}) do
    killmail_id = raw_changeset[:killmail_id]
    killmail_time = raw_changeset[:killmail_time]
    total_value = enriched_changeset[:total_value] || Decimal.new(0)

    %{
      # Core identifiers
      killmail_id: killmail_id,
      killmail_time: killmail_time,
      solar_system_id: raw_changeset[:solar_system_id],
      solar_system_name: enriched_changeset[:solar_system_name],
      # Victim data
      victim: %{
        character_id: raw_changeset[:victim_character_id],
        character_name: enriched_changeset[:victim_character_name],
        corporation_id: raw_changeset[:victim_corporation_id],
        corporation_name: enriched_changeset[:victim_corporation_name],
        alliance_id: raw_changeset[:victim_alliance_id],
        alliance_name: enriched_changeset[:victim_alliance_name],
        ship_type_id: raw_changeset[:victim_ship_type_id],
        ship_name: enriched_changeset[:victim_ship_name],
        damage_taken: raw_changeset[:damage_taken]
      },
      # Value data
      total_value: total_value,
      ship_value: enriched_changeset[:ship_value],
      fitted_value: enriched_changeset[:fitted_value],
      # Attacker summary
      attacker_count: length(raw_changeset[:attackers] || []),
      attackers: raw_changeset[:attackers] || [],
      # Participants for detailed display
      participants: participants,
      # Module analysis
      module_tags: enriched_changeset[:module_tags] || [],
      noteworthy_modules: enriched_changeset[:noteworthy_modules] || [],
      # Pre-computed display fields to avoid LiveView database queries
      display: %{
        time_ago: format_time_ago(killmail_time),
        value_formatted: format_isk(total_value),
        zkillboard_url: "https://zkillboard.com/kill/#{killmail_id}/",
        is_high_value: high_value?(total_value)
      }
    }
  end

  # Handle legacy format where killmail_data is already a map
  def build_broadcast_payload(killmail_data) when is_map(killmail_data) do
    # If it's already in the new format, return as-is
    if Map.has_key?(killmail_data, :display) do
      killmail_data
    else
      # Legacy map format - add display fields
      killmail_id = killmail_data[:killmail_id] || killmail_data["killmail_id"]
      killmail_time = killmail_data[:killmail_time] || killmail_data["killmail_time"]
      total_value = killmail_data[:total_value] || killmail_data["total_value"] || Decimal.new(0)

      Map.put(killmail_data, :display, %{
        time_ago: format_time_ago(killmail_time),
        value_formatted: format_isk(total_value),
        zkillboard_url: "https://zkillboard.com/kill/#{killmail_id}/",
        is_high_value: high_value?(total_value)
      })
    end
  end

  # Fallback for unexpected formats - return nil to signal invalid data
  def build_broadcast_payload(other) do
    Logger.warning("Unexpected killmail data format, skipping broadcast: #{inspect(other)}")
    nil
  end

  # ISK formatting helpers
  defp format_isk(nil), do: "0 ISK"
  defp format_isk(%Decimal{} = value), do: format_isk(Decimal.to_float(value))

  defp format_isk(value) when is_number(value) do
    cond do
      value >= 1_000_000_000_000 ->
        "#{Float.round(value / 1_000_000_000_000, 2)}T ISK"

      value >= 1_000_000_000 ->
        "#{Float.round(value / 1_000_000_000, 2)}B ISK"

      value >= 1_000_000 ->
        "#{Float.round(value / 1_000_000, 2)}M ISK"

      value >= 1_000 ->
        "#{Float.round(value / 1_000, 2)}K ISK"

      true ->
        "#{round(value)} ISK"
    end
  end

  defp format_isk(_), do: "0 ISK"

  # Time formatting helpers
  defp format_time_ago(nil), do: "just now"

  defp format_time_ago(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < @seconds_per_day -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, @seconds_per_day)}d ago"
    end
  end

  defp format_time_ago(%NaiveDateTime{} = ndt) do
    case DateTime.from_naive(ndt, "Etc/UTC") do
      {:ok, dt} -> format_time_ago(dt)
      _ -> "unknown"
    end
  end

  defp format_time_ago(iso_string) when is_binary(iso_string) do
    case DateTime.from_iso8601(iso_string) do
      {:ok, dt, _} -> format_time_ago(dt)
      _ -> "unknown"
    end
  end

  defp format_time_ago(_), do: "unknown"

  defp high_value?(nil), do: false

  defp high_value?(%Decimal{} = value),
    do: Decimal.compare(value, @high_value_threshold) != :lt

  defp high_value?(value) when is_number(value), do: value >= @high_value_threshold
  defp high_value?(_), do: false

  @doc """
  Check surveillance profiles for killmail matches.

  Uses the surveillance matching engine to find profiles that match
  the killmail data and triggers notifications for matches.
  """
  @spec check_surveillance_matches([Message.t()]) :: :ok
  def check_surveillance_matches(messages) do
    Logger.debug("Checking surveillance matches for #{length(messages)} killmails")

    for %Message{data: {raw_changeset, enriched_changeset, _participants}} <- messages do
      try do
        # Extract killmail data for surveillance matching
        killmail_data = build_killmail_data_for_matching(raw_changeset, enriched_changeset)

        # Use the surveillance matching engine to find matching profiles
        case MatchingEngine.match_killmail(killmail_data) do
          matched_profiles when is_list(matched_profiles) and matched_profiles != [] ->
            Logger.info(
              "🎯 Killmail #{killmail_data["killmail_id"]} matched #{length(matched_profiles)} surveillance profiles"
            )

            # Send notifications for matched profiles (handled by the matching engine internally)
            :ok

          [] ->
            Logger.debug("No surveillance matches for killmail #{killmail_data["killmail_id"]}")

          error ->
            Logger.warning("Surveillance matching returned unexpected result: #{inspect(error)}")
        end
      rescue
        error ->
          Logger.warning("Failed to check surveillance matches: #{inspect(error)}")
      end
    end

    :ok
  end

  @doc """
  Build killmail data structure compatible with surveillance matching engine.

  Combines data from raw and enriched changesets into a format that
  the surveillance matching engine expects.
  """
  @dialyzer {:nowarn_function, build_killmail_data_for_matching: 2}
  @spec build_killmail_data_for_matching(map(), map()) :: map()
  def build_killmail_data_for_matching(raw_changeset, enriched_changeset) do
    # Combine data from both raw and enriched changesets
    base_data = %{
      "killmail_id" => raw_changeset[:killmail_id],
      "killmail_time" => raw_changeset[:killmail_time],
      "solar_system_id" => raw_changeset[:solar_system_id],
      "victim" => build_victim_data(raw_changeset, enriched_changeset),
      "attackers" => raw_changeset[:attackers] || [],
      "attacker_count" => length(raw_changeset[:attackers] || [])
    }

    # Add enriched data if available
    enriched_data = %{
      "total_value" => enriched_changeset[:total_value],
      "ship_value" => enriched_changeset[:ship_value],
      "fitted_value" => enriched_changeset[:fitted_value],
      "solar_system_name" => enriched_changeset[:solar_system_name],
      "module_tags" => enriched_changeset[:module_tags] || [],
      "noteworthy_modules" => enriched_changeset[:noteworthy_modules] || []
    }

    Map.merge(base_data, enriched_data)
  end

  @doc """
  Build victim data structure for surveillance matching.

  Extracts victim information from both raw and enriched changesets
  to create a comprehensive victim data structure.
  """
  @spec build_victim_data(map(), map()) :: map()
  def build_victim_data(raw_changeset, enriched_changeset) do
    %{
      "character_id" => raw_changeset[:victim_character_id],
      "corporation_id" => raw_changeset[:victim_corporation_id],
      "alliance_id" => raw_changeset[:victim_alliance_id],
      "ship_type_id" => raw_changeset[:victim_ship_type_id],
      "damage_taken" => raw_changeset[:damage_taken],
      "character_name" => enriched_changeset[:victim_character_name],
      "corporation_name" => enriched_changeset[:victim_corporation_name],
      "alliance_name" => enriched_changeset[:victim_alliance_name],
      "ship_name" => enriched_changeset[:victim_ship_name]
    }
  end
end
