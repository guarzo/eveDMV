defmodule EveDmv.Killmails.DataProcessor do
  @moduledoc """
  Unified data processor for killmail pipeline.

  This module consolidates the transformation logic to reduce coupling
  between pipeline stages and provide a single point of data processing.

  Corporation, alliance, and character names are resolved during ingestion
  to avoid expensive ESI calls at display time.
  """

  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.KillmailDataTransformer
  alias EveDmv.Killmails.ParticipantBuilder

  require Logger

  @typep processed_data :: %{
           raw_changeset: map(),
           # REMOVED: enriched_changeset - see /docs/architecture/enriched-raw-analysis.md
           participants: list(),
           original_data: map()
         }

  @doc """
  Process enriched killmail data into all required formats in a single pass.

  This reduces parsing overhead and provides a consistent data structure
  for downstream consumers.
  """
  @dialyzer {:nowarn_function, process_killmail: 1}
  @spec process_killmail(map()) :: {:ok, processed_data()} | {:error, term()}
  def process_killmail(enriched_data) when is_map(enriched_data) do
    # Enrich with corporation/alliance names before building participants
    enriched_with_names = enrich_entity_names(enriched_data)

    # Single pass through the data to create all required formats
    processed = %{
      raw_changeset: KillmailDataTransformer.build_raw_changeset(enriched_with_names),
      # REMOVED: enriched_changeset - see /docs/architecture/enriched-raw-analysis.md
      participants: ParticipantBuilder.build_participants(enriched_with_names),
      original_data: enriched_with_names
    }

    {:ok, processed}
  rescue
    error ->
      Logger.error("Failed to process killmail data: #{inspect(error)}")
      {:error, error}
  end

  @doc """
  Extract database changesets from processed data.
  """
  @spec extract_database_changesets(processed_data()) ::
          {[map()], [list()]}
  def extract_database_changesets(processed_data) do
    {
      [processed_data.raw_changeset],
      # REMOVED: enriched_changeset - see /docs/architecture/enriched-raw-analysis.md
      [processed_data.participants]
    }
  end

  @doc """
  Extract broadcast data from processed data.
  """
  @spec extract_broadcast_data(processed_data()) :: map()
  def extract_broadcast_data(processed_data) do
    processed_data.original_data
  end

  @doc """
  Validate that processed data contains all required fields.
  """
  @spec validate_processed_data(processed_data()) :: :ok | {:error, term()}
  def validate_processed_data(processed_data) do
    required_fields = [:raw_changeset, :participants, :original_data]

    missing_fields =
      Enum.filter(required_fields, fn field ->
        not Map.has_key?(processed_data, field) or is_nil(Map.get(processed_data, field))
      end)

    case missing_fields do
      [] -> :ok
      fields -> {:error, {:missing_fields, fields}}
    end
  end

  @doc """
  Get killmail ID from processed data for logging and tracking.
  """
  @spec get_killmail_id(processed_data()) :: integer() | nil
  def get_killmail_id(processed_data) do
    processed_data.original_data["killmail_id"]
  end

  @doc """
  Get victim information for logging.

  Note: This function does NOT query the database to avoid N+1 queries during
  pipeline processing. It only uses data already present in the killmail.
  For display purposes, use the DisplayService which properly batches lookups.
  """
  @spec get_victim_info(processed_data()) :: {String.t(), String.t()}
  def get_victim_info(processed_data) do
    original = processed_data.original_data
    victim_name = get_in(original, ["victim", "character_name"]) || "Unknown Pilot"

    system_id = original["solar_system_id"] || original["system_id"]

    # Use only data from the original killmail - do NOT query the database here
    # to avoid N+1 queries during pipeline processing. The system name will be
    # resolved properly when displayed via DisplayService which batches lookups.
    system_name =
      case original["solar_system_name"] do
        name when is_binary(name) and name != "" and name != "Unknown System" ->
          name

        _ when is_integer(system_id) ->
          "System #{system_id}"

        _ ->
          "Unknown System"
      end

    {victim_name, system_name}
  end

  # ============================================================================
  # Entity Name Enrichment
  # ============================================================================

  @doc """
  Enriches killmail data with corporation and alliance names from ESI.

  This is called during ingestion so names are stored in the database and
  don't need to be resolved at display time (which would be slow).
  """
  @spec enrich_entity_names(map()) :: map()
  def enrich_entity_names(killmail_data) do
    # Extract all unique corporation and alliance IDs
    {corp_ids, alliance_ids} = extract_entity_ids(killmail_data)

    # Batch resolve corporation names
    corp_names =
      if Enum.empty?(corp_ids) do
        %{}
      else
        NameResolver.corporation_names(corp_ids)
      end

    # Batch resolve alliance names
    alliance_names =
      if Enum.empty?(alliance_ids) do
        %{}
      else
        NameResolver.alliance_names(alliance_ids)
      end

    # Inject names back into the data
    inject_entity_names(killmail_data, corp_names, alliance_names)
  end

  defp extract_entity_ids(killmail_data) do
    victim = killmail_data["victim"] || %{}
    attackers = killmail_data["attackers"] || []

    # Collect corporation IDs (only if no name already present)
    corp_ids =
      [victim | attackers]
      |> Enum.filter(fn p ->
        p["corporation_id"] != nil and
          (p["corporation_name"] == nil or p["corporation_name"] == "")
      end)
      |> Enum.map(& &1["corporation_id"])
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    # Collect alliance IDs (only if no name already present)
    alliance_ids =
      [victim | attackers]
      |> Enum.filter(fn p ->
        p["alliance_id"] != nil and
          (p["alliance_name"] == nil or p["alliance_name"] == "")
      end)
      |> Enum.map(& &1["alliance_id"])
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)

    {corp_ids, alliance_ids}
  end

  defp inject_entity_names(killmail_data, corp_names, alliance_names) do
    # Update victim
    victim = killmail_data["victim"] || %{}

    updated_victim =
      victim
      |> maybe_add_corp_name(corp_names)
      |> maybe_add_alliance_name(alliance_names)

    # Update attackers
    attackers = killmail_data["attackers"] || []

    updated_attackers =
      Enum.map(attackers, fn attacker ->
        attacker
        |> maybe_add_corp_name(corp_names)
        |> maybe_add_alliance_name(alliance_names)
      end)

    killmail_data
    |> Map.put("victim", updated_victim)
    |> Map.put("attackers", updated_attackers)
  end

  defp maybe_add_corp_name(participant, corp_names) do
    corp_id = participant["corporation_id"]
    existing_name = participant["corporation_name"]

    cond do
      is_binary(existing_name) and existing_name != "" ->
        participant

      corp_id != nil and Map.has_key?(corp_names, corp_id) ->
        Map.put(participant, "corporation_name", corp_names[corp_id])

      true ->
        participant
    end
  end

  defp maybe_add_alliance_name(participant, alliance_names) do
    alliance_id = participant["alliance_id"]
    existing_name = participant["alliance_name"]

    cond do
      is_binary(existing_name) and existing_name != "" ->
        participant

      alliance_id != nil and Map.has_key?(alliance_names, alliance_id) ->
        Map.put(participant, "alliance_name", alliance_names[alliance_id])

      true ->
        participant
    end
  end
end
