defmodule EveDmvWeb.SurveillanceLive.BatchOperations do
  @moduledoc """
  Handles batch operations for surveillance profiles.

  Provides functions for batch deletion, enabling/disabling, and other
  bulk operations on multiple surveillance profiles.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Surveillance.{MatchingEngine, Profile}

  @type batch_result :: %{success: non_neg_integer(), failed: non_neg_integer()}

  @doc """
  Delete multiple profiles in batch.

  Returns a result map with success and failure counts.
  """
  @spec batch_delete_profiles([String.t()], map()) :: batch_result()
  def batch_delete_profiles(profile_ids, actor) do
    results = %{success: 0, failed: 0}

    results =
      Enum.reduce(profile_ids, results, fn profile_id, acc ->
        case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
          {:ok, profile} ->
            case Ash.destroy(profile, domain: Api, actor: actor) do
              :ok ->
                %{acc | success: acc.success + 1}

              {:error, error} ->
                Logger.warning("Failed to delete profile #{profile_id}: #{inspect(error)}")
                %{acc | failed: acc.failed + 1}
            end

          {:error, error} ->
            Logger.warning("Failed to find profile #{profile_id}: #{inspect(error)}")
            %{acc | failed: acc.failed + 1}
        end
      end)

    # Reload matching engine after batch operations
    reload_matching_engine()
    results
  end

  @doc """
  Update the active status of multiple profiles in batch.

  Returns a result map with success and failure counts.
  """
  @spec batch_update_profiles([String.t()], boolean(), map()) :: batch_result()
  def batch_update_profiles(profile_ids, is_active, actor) do
    results = %{success: 0, failed: 0}

    results =
      Enum.reduce(profile_ids, results, fn profile_id, acc ->
        case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
          {:ok, profile} ->
            case Ash.update(profile, %{is_active: is_active}, domain: Api, actor: actor) do
              {:ok, _} ->
                %{acc | success: acc.success + 1}

              {:error, error} ->
                Logger.warning("Failed to update profile #{profile_id}: #{inspect(error)}")
                %{acc | failed: acc.failed + 1}
            end

          {:error, error} ->
            Logger.warning("Failed to find profile #{profile_id}: #{inspect(error)}")
            %{acc | failed: acc.failed + 1}
        end
      end)

    # Reload matching engine after batch operations
    reload_matching_engine()
    results
  end

  @doc """
  Enable multiple profiles in batch.
  """
  @spec batch_enable_profiles([String.t()], map()) :: batch_result()
  def batch_enable_profiles(profile_ids, actor) do
    batch_update_profiles(profile_ids, true, actor)
  end

  @doc """
  Disable multiple profiles in batch.
  """
  @spec batch_disable_profiles([String.t()], map()) :: batch_result()
  def batch_disable_profiles(profile_ids, actor) do
    batch_update_profiles(profile_ids, false, actor)
  end

  # Private helper functions

  defp reload_matching_engine do
    try do
      MatchingEngine.reload_profiles()
      Logger.info("Reloaded matching engine profiles after batch operation")
    rescue
      error ->
        Logger.error("Failed to reload matching engine: #{inspect(error)}")
    end
  end
end
