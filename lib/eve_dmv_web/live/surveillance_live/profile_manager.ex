defmodule EveDmvWeb.SurveillanceLive.ProfileManager do
  @moduledoc """
  Handles CRUD operations for surveillance profiles.

  Provides functions for creating, updating, deleting, and loading surveillance profiles
  with proper error handling and matching engine integration.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Surveillance.{MatchingEngine, Profile}

  @doc """
  Load all profiles for a specific user.

  Returns a list of profiles with their associated matches loaded.
  """
  @spec load_user_profiles(String.t(), map()) :: [Profile.t()]
  def load_user_profiles(user_id, current_user) do
    query =
      Profile
      |> Ash.Query.new()
      |> Ash.Query.for_read(:user_profiles, %{user_id: user_id})
      |> Ash.Query.load(:matches)

    case Ash.read(query, domain: Api, actor: current_user) do
      {:ok, profiles} -> profiles
      {:error, _} -> []
    end
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
          {sample_filter_tree(), true}
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
        Logger.info("Created surveillance profile: #{profile.name} (ID: #{profile.id})")

        # Reload matching engine profiles
        reload_matching_engine()

        {:ok, profile, has_json_error}

      {:error, error} ->
        {:error, format_error_message(error)}
    end
  end

  @doc """
  Toggle the active status of a profile.
  """
  @spec toggle_profile(String.t(), map()) :: {:ok, Profile.t()} | {:error, String.t()}
  def toggle_profile(profile_id, current_user) do
    case Ash.get(Profile, profile_id, domain: Api, actor: current_user) do
      {:ok, profile} ->
        case Ash.update(profile,
               action: :toggle_active,
               domain: Api,
               actor: current_user
             ) do
          {:ok, updated_profile} ->
            reload_matching_engine()
            {:ok, updated_profile}

          {:error, error} ->
            {:error, "Failed to update profile: #{inspect(error)}"}
        end

      {:error, _} ->
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
            {:error, "Failed to delete profile: #{inspect(error)}"}
        end

      {:error, _} ->
        {:error, "Profile not found"}
    end
  end

  # Private helper functions

  defp reload_matching_engine do
    try do
      MatchingEngine.reload_profiles()
      Logger.info("Reloaded matching engine profiles")
    rescue
      error ->
        Logger.error("Failed to reload matching engine: #{inspect(error)}")
    end
  end

  defp sample_filter_tree do
    %{
      "condition" => "and",
      "rules" => [
        %{
          "field" => "total_value",
          "operator" => "gt",
          "value" => 100_000_000
        },
        %{
          "field" => "solar_system_id",
          "operator" => "in",
          # Jita, Amarr
          "value" => [30_000_142, 30_002_187]
        }
      ]
    }
  end

  defp format_error_message(error) do
    case error do
      %Ash.Error.Invalid{errors: errors} ->
        errors
        |> Enum.map_join(", ", &format_validation_error/1)

      _ ->
        "Failed to create profile: #{inspect(error)}"
    end
  end

  defp format_validation_error(err) do
    case err do
      %{message: msg} -> msg
      %{field: field} -> "#{field} is invalid"
      _ -> inspect(err)
    end
  end
end
