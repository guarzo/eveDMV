defmodule EveDmvWeb.SurveillanceLive.ExportImportService do
  @moduledoc """
  Service for export and import operations for surveillance profiles.

  Handles exporting profiles to JSON format and importing
  profiles from JSON data with validation and error handling.
  """

  require Logger

    alias EveDmv.Surveillance.MatchingEngine
  alias EveDmv.Api
  alias EveDmv.Surveillance.Profile

  @doc """
  Export surveillance profiles to JSON format.
  """
  @spec export_profiles_json([String.t()], map()) :: map()
  def export_profiles_json(profile_ids, actor) do
    profiles =
      profile_ids
      |> Enum.reduce([], fn profile_id, acc ->
        case Ash.get(Profile, profile_id, domain: Api, actor: actor) do
          {:ok, profile} ->
            exported = %{
              "name" => profile.name,
              "description" => profile.description,
              "filter_tree" => profile.filter_tree,
              "is_active" => profile.is_active,
              "notification_settings" => profile.notification_settings
            }

            [exported | acc]

          {:error, error} ->
            Logger.warning("Failed to export profile #{profile_id}: #{inspect(error)}")
            acc
        end
      end)
      |> Enum.reverse()

    %{
      "version" => "1.0",
      "exported_at" => DateTime.utc_now(),
      "profiles" => profiles
    }
  end

  @doc """
  Import surveillance profiles from JSON data.
  """
  @spec import_profiles_from_json(String.t(), String.t(), map()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def import_profiles_from_json(json_data, user_id, current_user) do
    case Jason.decode(json_data) do
      {:ok, %{"profiles" => profiles}} when is_list(profiles) ->
        results = %{success: 0, failed: 0}

        final_results =
          Enum.reduce(profiles, results, fn profile_data, acc ->
            profile_params = %{
              name: Map.get(profile_data, "name", "Imported Profile"),
              description: Map.get(profile_data, "description", ""),
              filter_tree: Map.get(profile_data, "filter_tree", %{}),
              is_active: Map.get(profile_data, "is_active", true),
              notification_settings: Map.get(profile_data, "notification_settings", %{}),
              user_id: user_id
            }

            case Ash.create(Profile, profile_params, domain: Api, actor: current_user) do
              {:ok, _} ->
                %{acc | success: acc.success + 1}

              {:error, error} ->
                Logger.warning("Failed to import profile: #{inspect(error)}")
                %{acc | failed: acc.failed + 1}
            end
          end)

        if final_results.success > 0 do
          reload_matching_engine()
        end

        {:ok, final_results.success}

      {:ok, _} ->
        {:error, "Invalid JSON format - expected profiles array"}

      {:error, error} ->
        Logger.warning("Failed to parse JSON: #{inspect(error)}")
        {:error, "Invalid JSON format"}
    end
  end

  @doc """
  Generate a filename for profile export based on current date.
  """
  @spec generate_export_filename() :: String.t()
  def generate_export_filename do
    "surveillance_profiles_#{Date.utc_today()}.json"
  end

  @doc """
  Prepare export data for download event.

  Returns a map suitable for Phoenix LiveView push_event/2.
  """
  @spec prepare_download_event(map()) :: map()
  def prepare_download_event(export_data) do
    %{
      filename: generate_export_filename(),
      content: Jason.encode!(export_data, pretty: true),
      mimetype: "application/json"
    }
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
