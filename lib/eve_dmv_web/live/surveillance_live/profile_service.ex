defmodule EveDmvWeb.SurveillanceLive.ProfileService do
  @moduledoc """
  Service for profile CRUD operations in surveillance live view.

  Handles creating, updating, deleting, and loading surveillance profiles
  with proper error handling and matching engine integration.
  """

  alias EveDmv.Api
  alias EveDmv.Database.SurveillanceRepository
  alias EveDmv.Surveillance.MatchingEngine
  alias EveDmv.Surveillance.Profile
  alias EveDmvWeb.SurveillanceLive.Components

  require Logger

  @doc """
  Load all profiles for a specific user.

  Returns a list of profiles with their associated matches loaded.
  """
  @spec load_user_profiles(integer(), map()) :: [Profile.t()]
  def load_user_profiles(user_id, current_user) do
    SurveillanceRepository.get_user_profiles(user_id, current_user)
  end

  @doc """
  Create a new surveillance profile.

  Takes profile parameters, validates the filter tree JSON, and creates the profile
  with proper error handling and matching engine reload.
  """
  @spec create_profile(map(), String.t(), map()) ::
          {:ok, Profile.t(), boolean()} | {:error, String.t()}
  def create_profile(profile_params, user_id, current_user) do
    # Parse JSON filter tree
    {filter_tree, has_json_error} =
      case Jason.decode(profile_params["filter_tree"] || "{}") do
        {:ok, parsed} ->
          {parsed, false}

        {:error, error} ->
          Logger.warning("Invalid JSON in filter tree: #{inspect(error)}")
          {Components.sample_filter_tree(), true}
      end

    profile_data = %{
      name: profile_params["name"],
      description: profile_params["description"],
      user_id: user_id,
      filter_tree: filter_tree,
      is_active: true
    }

    case Ash.create(Profile, profile_data, domain: Api, actor: current_user) do
      {:ok, profile} ->
        reload_matching_engine()
        {:ok, profile, has_json_error}

      {:error, error} ->
        Logger.warning("Failed to create profile: #{inspect(error)}")
        {:error, format_error_message(error)}
    end
  end

  @doc """
  Update an existing surveillance profile.
  """
  @spec update_profile(String.t(), map(), map()) ::
          {:ok, Profile.t(), boolean()} | {:error, String.t()}
  def update_profile(profile_id, profile_params, current_user) do
    case Ash.get(Profile, profile_id, domain: Api, actor: current_user) do
      {:ok, profile} ->
        # Parse JSON filter tree
        {filter_tree, has_json_error} =
          case Jason.decode(profile_params["filter_tree"] || "{}") do
            {:ok, parsed} ->
              {parsed, false}

            {:error, error} ->
              Logger.warning("Invalid JSON in filter tree: #{inspect(error)}")
              {Components.sample_filter_tree(), true}
          end

        update_data = %{
          name: profile_params["name"],
          description: profile_params["description"],
          filter_tree: filter_tree,
          is_active: Map.get(profile_params, "is_active", true)
        }

        case Ash.update(profile, update_data, domain: Api, actor: current_user) do
          {:ok, updated_profile} ->
            reload_matching_engine()
            {:ok, updated_profile, has_json_error}

          {:error, error} ->
            Logger.warning("Failed to update profile: #{inspect(error)}")
            {:error, format_error_message(error)}
        end

      {:error, error} ->
        Logger.warning("Failed to find profile: #{inspect(error)}")
        {:error, "Profile not found"}
    end
  end

  @doc """
  Toggle the active state of a surveillance profile.
  """
  @spec toggle_profile(String.t(), map()) :: {:ok, Profile.t()} | {:error, String.t()}
  def toggle_profile(profile_id, current_user) do
    case Ash.get(Profile, profile_id, domain: Api, actor: current_user) do
      {:ok, profile} ->
        case Ash.update(profile, %{is_active: !profile.is_active},
               domain: Api,
               actor: current_user
             ) do
          {:ok, updated_profile} ->
            reload_matching_engine()
            {:ok, updated_profile}

          {:error, error} ->
            Logger.warning("Failed to toggle profile: #{inspect(error)}")
            {:error, format_error_message(error)}
        end

      {:error, error} ->
        Logger.warning("Failed to find profile: #{inspect(error)}")
        {:error, "Profile not found"}
    end
  end

  @doc """
  Delete a surveillance profile.
  """
  @spec delete_profile(String.t(), map()) :: :ok | {:error, String.t()}
  def delete_profile(profile_id, current_user) do
    case Ash.get(Profile, profile_id, domain: Api, actor: current_user) do
      {:ok, profile} ->
        case Ash.destroy(profile, domain: Api, actor: current_user) do
          :ok ->
            reload_matching_engine()
            :ok

          {:error, error} ->
            Logger.warning("Failed to delete profile: #{inspect(error)}")
            {:error, format_error_message(error)}
        end

      {:error, error} ->
        Logger.warning("Failed to find profile: #{inspect(error)}")
        {:error, "Profile not found"}
    end
  end

  # Helper Functions

  defp reload_matching_engine do
    MatchingEngine.reload_profiles()
  rescue
    error ->
      Logger.warning("Failed to reload matching engine: #{inspect(error)}")
  end

  defp format_error_message(error) do
    case error do
      %{__exception__: true, message: message} when is_binary(message) ->
        message

      %{__exception__: true} = exception ->
        Exception.message(exception)

      error when is_binary(error) ->
        error

      error when is_atom(error) ->
        Atom.to_string(error)

      error ->
        inspect(error)
    end
  end
end
