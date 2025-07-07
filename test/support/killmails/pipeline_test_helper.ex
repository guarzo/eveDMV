defmodule EveDmv.Killmails.PipelineTestHelper do
  @moduledoc """
  Helper module for manually testing the killmail ingestion pipeline.
  """

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailEnriched
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant
  alias EveDmv.Killmails.TestDataGenerator
  alias EveDmv.Repo

  require Logger

  @doc """
  Insert test killmail data directly into the database to test basic functionality.
  """
  def insert_test_data(count \\ 5) do
    Logger.info("Inserting #{count} test killmails...")

    killmails = TestDataGenerator.generate_multiple_killmails(count)

    results =
      Enum.map(killmails, fn killmail ->
        try do
          insert_single_killmail(killmail)
          {:ok, killmail["killmail_id"]}
        rescue
          error ->
            Logger.error(
              "Failed to insert killmail #{killmail["killmail_id"]}: #{inspect(error)}"
            )

            {:error, killmail["killmail_id"], error}
        end
      end)

    success_count = Enum.count(results, fn {status, _} -> status == :ok end)

    error_count =
      Enum.count(results, fn
        {status, _, _} when status == :error -> true
        _ -> false
      end)

    Logger.info("Inserted #{success_count} killmails successfully, #{error_count} errors")
    results
  end

  @doc """
  Check the current status of killmail data in the database.
  """
  def check_database_status do
    raw_count = count_killmails_raw()
    enriched_count = count_killmails_enriched()
    participants_count = count_participants()

    # Database status: #{raw_count} raw, #{enriched_count} enriched, #{participants_count} participants

    # Show recent killmails
    recent_killmails = get_recent_killmails(5)

    # Recent killmails: #{length(recent_killmails)} found

    {:ok,
     %{
       raw_count: raw_count,
       enriched_count: enriched_count,
       participants_count: participants_count,
       recent: recent_killmails
     }}
  rescue
    error ->
      Logger.error("Failed to check database status: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Clear all test data from the database.
  """
  def clear_test_data do
    Logger.info("Clearing test data...")

    try do
      # Clear in order to respect foreign key constraints
      Repo.delete_all(Participant)
      Repo.delete_all(KillmailEnriched)
      Repo.delete_all(KillmailRaw)

      Logger.info("Test data cleared successfully")
      :ok
    rescue
      error ->
        Logger.error("Failed to clear test data: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Test a single killmail insertion using the same logic as the pipeline.
  """
  def test_single_insertion do
    killmail = TestDataGenerator.generate_sample_killmail()

    Logger.info("Testing single killmail insertion: #{killmail["killmail_id"]}")

    try do
      result = insert_single_killmail(killmail)
      Logger.info("Single insertion successful")
      {:ok, result}
    rescue
      error ->
        Logger.error("Single insertion failed: #{inspect(error)}")
        {:error, error}
    end
  end

  # Private helper functions

  defp create_with_error_handling(resource, changeset, label) do
    case Ash.create(resource, changeset, domain: Api) do
      {:ok, result} ->
        result

      {:error, error} ->
        Logger.error("Failed to create #{label}: #{inspect(error)}")
        raise "Failed to create #{label}: #{inspect(error)}"
    end
  end

  defp insert_single_killmail(killmail) do
    # Use the same logic as the pipeline
    raw_changeset = build_raw_changeset(killmail)
    enriched_changeset = build_enriched_changeset(killmail)
    participants = build_participants(killmail)

    Repo.transaction(fn ->
      # Insert raw killmail
      raw = create_with_error_handling(KillmailRaw, raw_changeset, "raw killmail")
      Logger.debug("Created raw killmail: #{raw.killmail_id}")

      # Insert enriched killmail
      enriched =
        create_with_error_handling(KillmailEnriched, enriched_changeset, "enriched killmail")

      Logger.debug("Created enriched killmail: #{enriched.killmail_id}")

      # Insert participants
      Enum.each(participants, fn participant_data ->
        participant = create_with_error_handling(Participant, participant_data, "participant")
        Logger.debug("Created participant: #{participant.character_id}")
      end)

      :ok
    end)
  end

  # Copy the same helper functions from the pipeline
  defp build_raw_changeset(enriched) do
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"]),
      killmail_hash: enriched["killmail_hash"] || generate_hash(enriched),
      solar_system_id: get_in(enriched, ["system", "id"]) || enriched["solar_system_id"],
      victim_character_id: get_victim_character_id(enriched),
      victim_corporation_id: get_victim_corporation_id(enriched),
      victim_alliance_id: get_victim_alliance_id(enriched),
      victim_ship_type_id:
        get_in(enriched, ["ship", "type_id"]) || get_victim_ship_type_id(enriched),
      attacker_count: count_attackers(enriched),
      raw_data: enriched,
      source: "test_data"
    }
  end

  defp build_enriched_changeset(enriched) do
    %{
      killmail_id: enriched["killmail_id"],
      killmail_time: parse_timestamp(enriched["timestamp"]),
      victim_character_id: get_victim_character_id(enriched),
      victim_character_name: get_victim_character_name(enriched),
      victim_corporation_id: get_victim_corporation_id(enriched),
      victim_corporation_name: get_victim_corporation_name(enriched),
      victim_alliance_id: get_victim_alliance_id(enriched),
      victim_alliance_name: get_victim_alliance_name(enriched),
      solar_system_id: get_in(enriched, ["system", "id"]) || enriched["solar_system_id"],
      solar_system_name: get_in(enriched, ["system", "name"]) || enriched["solar_system_name"],
      victim_ship_type_id:
        get_in(enriched, ["ship", "type_id"]) || get_victim_ship_type_id(enriched),
      victim_ship_name: get_in(enriched, ["ship", "name"]) || get_victim_ship_name(enriched),
      total_value: parse_decimal(enriched["isk_value"] || enriched["total_value"]),
      ship_value: parse_decimal(enriched["ship_value"]),
      fitted_value: parse_decimal(enriched["fitted_value"]),
      attacker_count: count_attackers(enriched),
      final_blow_character_id: get_final_blow_character_id(enriched),
      final_blow_character_name: get_final_blow_character_name(enriched),
      kill_category: "test",
      victim_ship_category: "test",
      module_tags: enriched["module_tags"] || [],
      noteworthy_modules: enriched["noteworthy_modules"] || [],
      price_data_source: enriched["price_data_source"] || "test_data"
    }
  end

  defp build_participants(enriched) do
    participants = enriched["participants"] || []

    Enum.map(participants, fn p ->
      %{
        killmail_id: enriched["killmail_id"],
        killmail_time: parse_timestamp(enriched["timestamp"]),
        character_id: p["character_id"],
        character_name: p["character_name"],
        corporation_id: p["corporation_id"],
        corporation_name: p["corporation_name"],
        alliance_id: p["alliance_id"],
        alliance_name: p["alliance_name"],
        faction_id: p["faction_id"],
        faction_name: p["faction_name"],
        ship_type_id: p["ship_type_id"],
        ship_name: p["ship_name"],
        weapon_type_id: p["weapon_type_id"],
        weapon_name: p["weapon_name"],
        damage_done: p["damage_done"] || 0,
        security_status: p["security_status"],
        is_victim: p["is_victim"] || false,
        final_blow: p["final_blow"] || false,
        solar_system_id: get_in(enriched, ["system", "id"]) || enriched["solar_system_id"]
      }
    end)
  end

  # Helper functions for data queries
  defp count_killmails_raw do
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.count!(domain: Api)
  end

  defp count_killmails_enriched do
    KillmailEnriched
    |> Ash.Query.new()
    |> Ash.count!(domain: Api)
  end

  defp count_participants do
    Participant
    |> Ash.Query.new()
    |> Ash.count!(domain: Api)
  end

  defp get_recent_killmails(limit) do
    KillmailRaw
    |> Ash.Query.new()
    |> Ash.Query.sort(killmail_time: :desc)
    |> Ash.Query.limit(limit)
    |> Ash.read!(domain: Api)
  end

  # Copy helper functions from pipeline
  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(%DateTime{} = dt), do: dt
  defp parse_timestamp(_), do: DateTime.utc_now()

  defp parse_decimal(nil), do: Decimal.new(0)
  defp parse_decimal(value) when is_number(value), do: Decimal.new(value)

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  defp parse_decimal(_), do: Decimal.new(0)

  defp generate_hash(enriched) do
    id = enriched["killmail_id"]
    timestamp = enriched["timestamp"]
    "#{id}-#{timestamp}" |> :crypto.hash(:sha256) |> Base.encode16(case: :lower)
  end

  defp get_victim_character_id(enriched) do
    case find_victim(enriched) do
      %{"character_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_character_name(enriched) do
    case find_victim(enriched) do
      %{"character_name" => name} -> name
      _ -> nil
    end
  end

  defp get_victim_corporation_id(enriched) do
    case find_victim(enriched) do
      %{"corporation_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_corporation_name(enriched) do
    case find_victim(enriched) do
      %{"corporation_name" => name} -> name
      _ -> nil
    end
  end

  defp get_victim_alliance_id(enriched) do
    case find_victim(enriched) do
      %{"alliance_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_alliance_name(enriched) do
    case find_victim(enriched) do
      %{"alliance_name" => name} -> name
      _ -> nil
    end
  end

  defp get_victim_ship_type_id(enriched) do
    case find_victim(enriched) do
      %{"ship_type_id" => id} -> id
      _ -> nil
    end
  end

  defp get_victim_ship_name(enriched) do
    case find_victim(enriched) do
      %{"ship_name" => name} -> name
      _ -> nil
    end
  end

  defp get_final_blow_character_id(enriched) do
    case find_final_blow_attacker(enriched) do
      %{"character_id" => id} -> id
      _ -> nil
    end
  end

  defp get_final_blow_character_name(enriched) do
    case find_final_blow_attacker(enriched) do
      %{"character_name" => name} -> name
      _ -> nil
    end
  end

  defp find_victim(enriched) do
    participants = enriched["participants"] || []
    Enum.find(participants, fn p -> p["is_victim"] end)
  end

  defp find_final_blow_attacker(enriched) do
    participants = enriched["participants"] || []
    Enum.find(participants, fn p -> p["final_blow"] && !p["is_victim"] end)
  end

  defp count_attackers(enriched) do
    participants = enriched["participants"] || []
    attackers = Enum.filter(participants, fn p -> !p["is_victim"] end)
    length(attackers)
  end
end
