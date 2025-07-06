defmodule EveDmv.Killmails.DataProcessor do
  @moduledoc """
  Unified data processor for killmail pipeline.

  This module consolidates the transformation logic to reduce coupling
  between pipeline stages and provide a single point of data processing.
  """

  require Logger

  alias EveDmv.Eve.NameResolver
  alias EveDmv.Killmails.{KillmailDataTransformer, ParticipantBuilder}

  @doc """
  Process enriched killmail data into all required formats in a single pass.

  This reduces parsing overhead and provides a consistent data structure
  for downstream consumers.
  """
  @spec process_killmail(map()) :: {:ok, processed_data()} | {:error, term()}
  def process_killmail(enriched_data) when is_map(enriched_data) do
    try do
      # Single pass through the data to create all required formats
      processed = %{
        raw_changeset: KillmailDataTransformer.build_raw_changeset(enriched_data),
        enriched_changeset: KillmailDataTransformer.build_enriched_changeset(enriched_data),
        participants: ParticipantBuilder.build_participants(enriched_data),
        original_data: enriched_data
      }

      {:ok, processed}
    rescue
      error ->
        Logger.error("Failed to process killmail data: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Extract database changesets from processed data.
  """
  @spec extract_database_changesets(processed_data()) ::
          {[map()], [map()], [list()]}
  def extract_database_changesets(processed_data) do
    {
      [processed_data.raw_changeset],
      [processed_data.enriched_changeset],
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
    required_fields = [:raw_changeset, :enriched_changeset, :participants, :original_data]

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
  """
  @spec get_victim_info(processed_data()) :: {String.t(), String.t()}
  def get_victim_info(processed_data) do
    original = processed_data.original_data
    victim_name = get_in(original, ["victim", "character_name"]) || "Unknown Pilot"

    system_id = original["solar_system_id"] || original["system_id"]

    system_name =
      case original["solar_system_name"] do
        name when name in [nil, "", "Unknown System"] and system_id != nil ->
          NameResolver.system_name(system_id)

        name when name != nil ->
          name

        _ ->
          "Unknown System"
      end

    {victim_name, system_name}
  end

  @typep processed_data :: %{
           raw_changeset: map(),
           enriched_changeset: map(),
           participants: list(),
           original_data: map()
         }
end
