defmodule EveDmvWeb.SurveillanceLive.BatchOperationService do
  @moduledoc """
  Service for batch operations on surveillance profiles.

  Handles batch deletion, enabling/disabling, and other
  bulk operations on multiple surveillance profiles.
  """

  alias EveDmv.Api
  alias EveDmv.Surveillance.MatchingEngine
  alias EveDmv.Surveillance.Profile

  require Logger
  require Ash.Query

  @type batch_result :: %{success: non_neg_integer(), failed: non_neg_integer()}

  @doc """
  Delete multiple profiles in batch.
  """
  @spec batch_delete_profiles([String.t()], map()) :: batch_result()
  def batch_delete_profiles(profile_ids, actor) do
    # First, fetch all profiles in a single query
    profiles_query =
      Profile
      |> Ash.Query.filter(id in ^profile_ids)

    case Ash.read(profiles_query, domain: Api, actor: actor) do
      {:ok, profiles} ->
        found_ids = Enum.map(profiles, & &1.id)
        not_found_ids = profile_ids -- found_ids

        # Log any profiles that weren't found
        Enum.each(not_found_ids, fn id ->
          Logger.warning("Profile not found for deletion: #{id}")
        end)

        # Use bulk_destroy for efficient batch deletion
        case Ash.bulk_destroy(profiles, :destroy, %{},
               domain: Api,
               actor: actor,
               return_errors?: true,
               batch_size: 100
             ) do
          %Ash.BulkResult{errors: [], records: _} = result ->
            reload_matching_engine()
            %{success: length(result.records) || length(profiles), failed: length(not_found_ids)}

          %Ash.BulkResult{errors: errors} = result ->
            Enum.each(errors, fn error ->
              Logger.warning("Failed to delete profile: #{inspect(error)}")
            end)

            reload_matching_engine()

            %{
              success: length(result.records) || 0,
              failed: length(errors) + length(not_found_ids)
            }
        end

      {:error, error} ->
        Logger.error("Failed to fetch profiles for deletion: #{inspect(error)}")
        %{success: 0, failed: length(profile_ids)}
    end
  end

  @doc """
  Update the active status of multiple profiles in batch.
  """
  @spec batch_update_profiles([String.t()], map(), map()) :: batch_result()
  def batch_update_profiles(profile_ids, update_data, actor) do
    # First, fetch all profiles in a single query
    profiles_query =
      Profile
      |> Ash.Query.filter(id in ^profile_ids)

    case Ash.read(profiles_query, domain: Api, actor: actor) do
      {:ok, profiles} ->
        found_ids = Enum.map(profiles, & &1.id)
        not_found_ids = profile_ids -- found_ids

        # Log any profiles that weren't found
        Enum.each(not_found_ids, fn id ->
          Logger.warning("Profile not found for update: #{id}")
        end)

        # Use bulk_update for efficient batch updates
        case Ash.bulk_update(profiles, :update, update_data,
               domain: Api,
               actor: actor,
               return_errors?: true,
               batch_size: 100
             ) do
          %Ash.BulkResult{errors: [], records: _} = result ->
            reload_matching_engine()
            %{success: length(result.records) || length(profiles), failed: length(not_found_ids)}

          %Ash.BulkResult{errors: errors} = result ->
            Enum.each(errors, fn error ->
              Logger.warning("Failed to update profile: #{inspect(error)}")
            end)

            reload_matching_engine()

            %{
              success: length(result.records) || 0,
              failed: length(errors) + length(not_found_ids)
            }
        end

      {:error, error} ->
        Logger.error("Failed to fetch profiles for update: #{inspect(error)}")
        %{success: 0, failed: length(profile_ids)}
    end
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
    MatchingEngine.reload_profiles()
  rescue
    error ->
      Logger.warning("Failed to reload matching engine: #{inspect(error)}")
  end
end
