defmodule EveDmv.Killmails.KillmailBroadcaster do
  alias Broadway.Message
  alias EveDmv.Surveillance.MatchingEngine
  alias EveDmvWeb.Endpoint

  require Logger
  @moduledoc """
  Handles broadcasting and surveillance matching for processed killmails.

  Provides PubSub broadcasting to LiveView clients and surveillance profile
  matching for real-time notifications.
  """



  @doc """
  Broadcast killmails to LiveView clients via PubSub.

  Sends killmail data to the "killmail_feed" topic for real-time updates
  in the UI. Handles errors gracefully to prevent pipeline failures.
  """
  @spec broadcast_killmails([Message.t()]) :: :ok
  def broadcast_killmails(messages) do
    for %Message{data: killmail_data} <- messages do
      try do
        Endpoint.broadcast!("killmail_feed", "new_killmail", killmail_data)
      rescue
        error ->
          Logger.warning("Failed to broadcast killmail: #{inspect(error)}")
      end
    end

    :ok
  end

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
          matched_profiles when is_list(matched_profiles) and length(matched_profiles) > 0 ->
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
