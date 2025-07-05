defmodule EveDmvWeb.SurveillanceLive.ImportExport do
  @moduledoc """
  Handles import and export operations for surveillance profiles.

  Provides functions for exporting profiles to JSON format and importing
  profiles from JSON data with validation and error handling.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Surveillance.Profile

  @doc """
  Export surveillance profiles to JSON format.

  Takes a list of profile IDs and exports them to a structured JSON format
  suitable for backup or sharing between users.
  """
  @spec export_profiles_json([String.t()], map()) :: map()
  def export_profiles_json(profile_ids, actor) do
    profiles =
      Enum.reduce(profile_ids, [], fn profile_id, acc ->
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

  Parses JSON data and creates new profiles for the specified user.
  Returns the number of successfully imported profiles.
  """
  @spec import_profiles_from_json(String.t(), String.t(), map()) ::
          {:ok, non_neg_integer()} | {:error, String.t()}
  def import_profiles_from_json(json_data, user_id, actor) do
    case Jason.decode(json_data) do
      {:ok, %{"profiles" => profiles}} when is_list(profiles) ->
        imported_count =
          Enum.reduce(profiles, 0, fn profile_data, count ->
            profile_attrs = %{
              name: profile_data["name"] || "Imported Profile",
              description: profile_data["description"] || "",
              filter_tree: profile_data["filter_tree"] || sample_filter_tree(),
              is_active: profile_data["is_active"] || false,
              notification_settings: profile_data["notification_settings"] || %{},
              user_id: user_id
            }

            case Ash.create(Profile, profile_attrs, domain: Api, actor: actor) do
              {:ok, profile} ->
                Logger.info("Successfully imported profile: #{profile.name}")
                count + 1

              {:error, error} ->
                Logger.warning(
                  "Failed to import profile #{profile_data["name"]}: #{inspect(error)}"
                )

                count
            end
          end)

        {:ok, imported_count}

      {:ok, _} ->
        {:error, "Invalid format: missing profiles array"}

      {:error, _} ->
        {:error, "Invalid JSON data"}
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

  # Private helper functions

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
end
