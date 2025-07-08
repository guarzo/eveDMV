defmodule EveDmv.Surveillance.Matching.MatchEvaluator do
  @moduledoc """
  Match evaluation module for surveillance profiles.

  This module handles the evaluation of candidate profiles against killmail data,
  including parallel evaluation for performance and match recording.
  """

    alias EveDmv.Surveillance.ProfileMatch
  alias EveDmv.Api
  alias EveDmv.Surveillance.Matching.IndexManager
  require Logger

  # Performance tuning constants
  @max_candidate_set_size 100

  @doc """
  Evaluate candidate profiles against a killmail in parallel.

  Returns a list of profile IDs that matched the killmail.
  """
  def evaluate_candidates_parallel(candidates, killmail) do
    # Limit candidate set size for performance
    limited_candidates = Enum.take(candidates, @max_candidate_set_size)

    # Evaluate candidates in parallel for better performance
    limited_candidates
    |> Task.async_stream(
      fn profile_id ->
        case IndexManager.get_compiled_profile(profile_id) do
          {:ok, compiled_fn} ->
            if compiled_fn.(killmail) do
              profile_id
            else
              nil
            end

          {:error, :not_found} ->
            Logger.warning("Compiled profile not found: #{profile_id}")
            nil
        end
      end,
      max_concurrency: System.schedulers_online(),
      timeout: 1000
    )
    |> Enum.reduce([], fn
      {:ok, nil}, acc ->
        acc

      {:ok, profile_id}, acc ->
        [profile_id | acc]

      {:exit, :timeout}, acc ->
        Logger.warning("Profile evaluation timeout")
        acc
    end)
  end

  @doc """
  Record a batch of profile matches to the database.

  Used for batch processing to improve performance.
  """
  def record_matches_batch(matches) when is_list(matches) do
    if length(matches) > 0 do
      Logger.info("Recording #{length(matches)} surveillance matches")

      # Prepare match records for bulk creation
      match_records =
        Enum.map(matches, fn {profile_id, killmail, timestamp} ->
          %{
            profile_id: profile_id,
            killmail_id: killmail["killmail_id"],
            killmail_data: killmail,
            matched_at: timestamp,
            match_quality: calculate_match_quality(killmail)
          }
        end)

      try do
        # Use bulk creation for better performance
        case Ash.bulk_create(match_records, ProfileMatch, :create,
               domain: Api,
               return_records?: false,
               return_errors?: true,
               stop_on_error?: false,
               batch_size: 100
             ) do
          %Ash.BulkResult{status: :success} ->
            Logger.info("Successfully recorded #{length(matches)} matches")
            :ok

          %Ash.BulkResult{status: :partial_success, errors: errors} ->
            Logger.warning("Partial success recording matches: #{length(errors)} errors")
            :ok

          %Ash.BulkResult{status: :error, errors: errors} ->
            Logger.error("Failed to record matches: #{inspect(errors)}")
            {:error, errors}
        end
      rescue
        error ->
          Logger.error("Exception recording matches: #{inspect(error)}")
          {:error, error}
      end
    else
      :ok
    end
  end

  @doc """
  Calculate match quality score for a killmail.

  Returns a float between 0.0 and 1.0 representing match quality.
  """
  def calculate_match_quality(killmail) do
    # Simple quality calculation based on data completeness and value
    completeness_score = calculate_data_completeness(killmail)
    value_score = calculate_value_score(killmail)

    # Weighted average
    completeness_score * 0.6 + value_score * 0.4
  end

  @doc """
  Generate a cache key for a killmail based on matching-relevant properties.
  """
  def generate_cache_key(killmail) do
    # Generate cache key based on killmail properties that affect matching
    key_fields = [
      killmail["killmail_id"],
      killmail["solar_system_id"] || killmail["system_id"],
      get_in(killmail, ["victim", "ship_type_id"]),
      killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]),
      length(killmail["attackers"] || [])
    ]

    hash = :crypto.hash(:md5, inspect(key_fields))
    Base.encode16(hash)
  end

  @doc """
  Calculate cache hit rate for monitoring purposes.
  """
  def calculate_cache_hit_rate do
    # This would need to be implemented with proper metrics tracking
    # For now return a placeholder
    0.0
  end

  @doc """
  Emit telemetry events for match evaluation performance.
  """
  def emit_matching_telemetry(start_time, candidates_count, matches_count) do
    duration = System.monotonic_time(:microsecond) - start_time

    :telemetry.execute([:eve_dmv, :surveillance, :matching_time], %{duration: duration}, %{})

    :telemetry.execute(
      [:eve_dmv, :surveillance, :profile, :evaluated],
      %{count: candidates_count},
      %{}
    )

    if matches_count > 0 do
      :telemetry.execute(
        [:eve_dmv, :surveillance, :profile, :match],
        %{count: matches_count},
        %{}
      )
    end

    Logger.debug(
      "Evaluated #{candidates_count} candidates in #{duration}μs, #{matches_count} matches"
    )
  end

  @doc """
  Validate killmail data structure for processing.

  Returns {:ok, killmail} or {:error, reason}.
  """
  def validate_killmail(killmail) when is_map(killmail) do
    required_fields = ["killmail_id", "victim", "attackers"]

    missing_fields =
      Enum.filter(required_fields, fn field -> is_nil(killmail[field]) end)

    case missing_fields do
      [] -> {:ok, killmail}
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  def validate_killmail(_), do: {:error, "Killmail must be a map"}

  # Private helper functions

  defp calculate_data_completeness(killmail) do
    # Check for presence of optional but useful fields
    optional_fields = [
      "solar_system_name",
      get_in(killmail, ["victim", "character_name"]),
      get_in(killmail, ["victim", "corporation_name"]),
      get_in(killmail, ["victim", "alliance_name"]),
      killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"])
    ]

    present_count = Enum.count(optional_fields, &(&1 != nil))
    present_count / length(optional_fields)
  end

  defp calculate_value_score(killmail) do
    total_value = killmail["total_value"] || get_in(killmail, ["zkb", "totalValue"]) || 0

    # Normalize value score (log scale to handle wide value ranges)
    cond do
      # 1B+ ISK
      total_value >= 1_000_000_000 -> 1.0
      # 100M+ ISK
      total_value >= 100_000_000 -> 0.8
      # 10M+ ISK
      total_value >= 10_000_000 -> 0.6
      # 1M+ ISK
      total_value >= 1_000_000 -> 0.4
      # Any value
      total_value > 0 -> 0.2
      # No value data
      true -> 0.0
    end
  end
end
