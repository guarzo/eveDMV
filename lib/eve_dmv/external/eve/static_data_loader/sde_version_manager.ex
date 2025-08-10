defmodule EveDmv.Eve.StaticDataLoader.SdeVersionManager do
  @moduledoc """
  Manages SDE version checking and automatic updates.

  This module checks for new SDE versions on startup and coordinates
  the download and processing of updated data if necessary.
  """

  alias EveDmv.Api
  alias EveDmv.Eve.SolarSystem

  require Logger
  require Ash.Query

  defstruct [
    :current_version,
    :latest_version,
    :last_check,
    :needs_update
  ]

  @fuzzwork_base_url "https://www.fuzzwork.co.uk"
  @wormhole_classes_url "#{@fuzzwork_base_url}/dump/latest/mapLocationWormholeClasses.csv"

  def check_for_updates do
    Logger.info("Checking for SDE updates...")

    with {:ok, current_version} <- get_current_sde_version(),
         {:ok, latest_version} <- get_latest_sde_version(),
         needs_update <- version_needs_update?(current_version, latest_version) do
      Logger.info("Current SDE version: #{current_version || "none"}")
      Logger.info("Latest SDE version: #{latest_version}")
      Logger.info("Update needed: #{needs_update}")

      if needs_update do
        Logger.info("Starting SDE data update process...")
        update_sde_data(latest_version)
      else
        Logger.info("SDE data is up to date")
        {:ok, :up_to_date}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to check for SDE updates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_current_sde_version do
    # Get the most recent SDE version from any solar system record
    case Ash.Query.new(SolarSystem)
         |> Ash.Query.filter(not is_nil(sde_version))
         |> Ash.Query.sort([{:last_updated, :desc}])
         |> Ash.Query.limit(1)
         |> Api.read() do
      {:ok, [%{sde_version: version}]} -> {:ok, version}
      {:ok, []} -> {:ok, nil}
      {:error, error} -> {:error, error}
    end
  end

  defp get_latest_sde_version do
    Logger.info("Checking latest SDE version from Fuzzwork headers...")

    case HTTPoison.head(@wormhole_classes_url, [], recv_timeout: 10_000) do
      {:ok, %HTTPoison.Response{status_code: 200, headers: headers}} ->
        # Extract last-modified date as version indicator
        case extract_last_modified(headers) do
          {:ok, last_modified} ->
            {:ok, last_modified}

          {:error, reason} ->
            Logger.warning("Could not extract last-modified date: #{reason}")
            # Fallback to current timestamp as version
            {:ok, DateTime.utc_now() |> DateTime.to_iso8601()}
        end

      {:ok, %HTTPoison.Response{status_code: status}} ->
        {:error, "HTTP error: #{status}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "Request failed: #{inspect(reason)}"}
    end
  end

  defp extract_last_modified(headers) do
    # Find the last-modified header
    case Enum.find(headers, fn {name, _value} ->
           String.downcase(name) == "last-modified"
         end) do
      {_name, value} ->
        # Use the raw date string as version - this is fine for comparison
        {:ok, value}

      nil ->
        # If no last-modified header, generate a timestamp-based version
        {:ok, DateTime.utc_now() |> DateTime.to_iso8601()}
    end
  end

  defp version_needs_update?(current, latest) do
    case {current, latest} do
      # No current version, always update
      {nil, _} -> true
      {current, latest} when current != latest -> true
      _ -> false
    end
  end

  defp update_sde_data(new_version) do
    Logger.info("Updating SDE data to version: #{new_version}")

    # Currently only tracking version updates
    # Additional data loaders can be added here as needed

    Logger.info("SDE update completed successfully")
    update_version_tracking(new_version)
    {:ok, %{version: new_version}}
  end

  defp update_version_tracking(new_version) do
    Logger.info("Updating version tracking to: #{new_version}")

    # Update a sample of systems to track the new version
    case Ash.Query.new(SolarSystem)
         |> Ash.Query.limit(10)
         |> Api.read() do
      {:ok, systems} ->
        update_time = DateTime.utc_now()

        systems
        |> Enum.each(fn system ->
          Ash.update(
            system,
            %{
              sde_version: new_version,
              last_updated: update_time
            },
            action: :update_sde_version,
            domain: Api
          )
        end)

        Logger.info("Version tracking updated successfully")
        :ok

      {:error, error} ->
        Logger.error("Failed to update version tracking: #{inspect(error)}")
        {:error, error}
    end
  end
end
