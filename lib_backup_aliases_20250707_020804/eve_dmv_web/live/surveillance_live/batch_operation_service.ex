defmodule EveDmvWeb.SurveillanceLive.BatchOperationService do
  @moduledoc """
  Service for batch operations on surveillance profiles.

  Handles batch deletion, enabling/disabling, and other
  bulk operations on multiple surveillance profiles.
  """

  require Logger

    alias EveDmv.Surveillance.MatchingEngine
  alias EveDmv.Api
  alias EveDmv.Surveillance.Profile

  @type batch_result :: %{success: non_neg_integer(), failed: non_neg_integer()}

  @doc """
  Delete multiple profiles in batch.
  """
  @spec batch_delete_profiles([String.t()], map()) :: batch_result()
  def batch_delete_profiles(profile_ids, actor) do
    results = %{success: 0, failed: 0}

    final_results =
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

    reload_matching_engine()
    final_results
  end

  @doc """
  Update the active status of multiple profiles in batch.
  """
  @spec batch_update_profiles([String.t()], map(), map()) :: batch_result()
  def batch_update_profiles(profile_ids, update_data, actor) do
    results = %{success: 0, failed: 0}

    final_results =
      Enum.reduce(profile_ids, results, fn profile_id, acc ->
        case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
          {:ok, profile} ->
            case Ash.update(profile, update_data, domain: Api, actor: actor) do
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

    reload_matching_engine()
    final_results
  end

  @doc """
  Enable multiple profiles in batch.
  """
  @spec batch_enable_profiles([String.t()], map()) :: batch_result()
  def batch_enable_profiles(profile_ids, actor) do
    batch_update_profiles(profile_ids, %{is_active: true}, actor)
  end

  @doc """
  Disable multiple profiles in batch.
  """
  @spec batch_disable_profiles([String.t()], map()) :: batch_result()
  def batch_disable_profiles(profile_ids, actor) do
    batch_update_profiles(profile_ids, %{is_active: false}, actor)
  end

  # Helper Functions

  defp reload_matching_engine do
    try do
      MatchingEngine.reload()
    rescue
      error ->
        Logger.warning("Failed to reload matching engine: #{inspect(error)}")
    end
  end
end
