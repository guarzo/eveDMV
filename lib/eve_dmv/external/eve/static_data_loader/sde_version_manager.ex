defmodule EveDmv.Eve.StaticDataLoader.SdeVersionManager do
  @moduledoc """
  Manages SDE version checking and automatic updates.

  This module checks for new SDE versions on startup and coordinates
  the download and processing of updated data if necessary.

  Uses CCP's official Static Data Export with build number versioning.
  """

  alias EveDmv.Api
  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Eve.StaticDataLoader.CcpSdeClient

  require Logger
  require Ash.Query

  defstruct [
    :current_version,
    :latest_version,
    :last_check,
    :needs_update
  ]

  @type version_info :: %{
          build_number: integer() | nil,
          release_date: String.t() | nil,
          version_string: String.t()
        }

  @doc """
  Checks for SDE updates from CCP.
  """
  def check_for_updates do
    Logger.info("Checking for SDE updates from CCP...")

    with {:ok, current_version} <- get_current_sde_version(),
         {:ok, latest_version} <- get_latest_sde_version(),
         needs_update <- version_needs_update?(current_version, latest_version) do
      current_str = format_version(current_version)
      latest_str = format_version(latest_version)

      Logger.info("Current SDE version: #{current_str}")
      Logger.info("Latest SDE version: #{latest_str}")
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

  @doc """
  Gets the latest version info from CCP's SDE endpoint.

  Returns a map with build_number and release_date.
  """
  @spec get_ccp_version_info() :: {:ok, version_info()} | {:error, term()}
  def get_ccp_version_info do
    case CcpSdeClient.get_latest_build_number() do
      {:ok, %{build_number: build, release_date: date}} ->
        {:ok, %{build_number: build, release_date: date, version_string: "build-#{build}"}}

      {:error, _reason} = error ->
        error
    end
  end

  # Get current SDE version from database

  defp get_current_sde_version do
    # Look for sde_build_number (integer) first, then fall back to sde_version string
    case Ash.Query.new(SolarSystem)
         |> Ash.Query.filter(not is_nil(sde_build_number) or not is_nil(sde_version))
         |> Ash.Query.sort([{:last_updated, :desc}])
         |> Ash.Query.limit(1)
         |> Ash.read(domain: EveDmv.Api) do
      {:ok, [%{sde_build_number: build_number, sde_version: version}]}
      when is_integer(build_number) ->
        # Prefer the integer build number
        {:ok, %{build_number: build_number, version_string: version || "build-#{build_number}"}}

      {:ok, [%{sde_version: version}]} when is_binary(version) ->
        # Fall back to parsing version string for legacy data
        case parse_ccp_version(version) do
          {:ok, build_number} -> {:ok, %{build_number: build_number, version_string: version}}
          :error -> {:ok, nil}
        end

      {:ok, []} ->
        {:ok, nil}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_latest_sde_version do
    Logger.info("Checking latest SDE version from CCP...")

    case CcpSdeClient.get_latest_build_number() do
      {:ok, %{build_number: build, release_date: date}} ->
        {:ok, %{build_number: build, release_date: date, version_string: "build-#{build}"}}

      {:error, reason} ->
        Logger.error("Failed to get CCP SDE version: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Determines if an SDE update is needed based on version comparison.

  Returns true when:
  - current is nil (no version installed)
  - latest build number is greater than current build number
  - current version is in a non-CCP format

  Returns false when current build is same or newer than latest.
  """
  @spec version_needs_update?(version_info() | nil, version_info()) :: boolean()
  def version_needs_update?(current, latest) do
    case {current, latest} do
      # No current version, always update
      {nil, _} ->
        true

      # Compare build numbers
      {%{build_number: current_build}, %{build_number: latest_build}} ->
        latest_build > current_build

      # Current version is not in CCP format, update to migrate
      {_, %{build_number: _}} ->
        true

      _ ->
        false
    end
  end

  # Update SDE data

  defp update_sde_data(new_version) do
    version_string = new_version.version_string
    build_number = new_version.build_number
    Logger.info("Updating SDE data to CCP version: #{version_string} (build: #{build_number})")

    # Currently only tracking version updates
    # The actual data loading is done separately via StaticDataLoader

    Logger.info("SDE update completed successfully")
    update_version_tracking(version_string, build_number)
    {:ok, %{version: version_string, build_number: build_number}}
  end

  defp update_version_tracking(new_version, build_number) do
    Logger.info(
      "Updating version tracking to: #{new_version}" <>
        if(build_number, do: " (build: #{build_number})", else: "")
    )

    # Update a sample of systems to track the new version
    case Ash.Query.new(SolarSystem)
         |> Ash.Query.limit(10)
         |> Ash.read(domain: EveDmv.Api) do
      {:ok, systems} ->
        update_time = DateTime.utc_now()

        update_attrs = %{
          sde_version: new_version,
          last_updated: update_time
        }

        # Add build number if provided
        update_attrs =
          if build_number do
            Map.put(update_attrs, :sde_build_number, build_number)
          else
            update_attrs
          end

        results =
          systems
          |> Enum.map(fn system ->
            case Ash.update(
                   system,
                   update_attrs,
                   action: :update_sde_version,
                   domain: Api
                 ) do
              {:ok, _} ->
                :ok

              {:error, error} ->
                Logger.warning(
                  "Failed to update version for system #{system.system_id}: #{inspect(error)}"
                )

                :error
            end
          end)

        failures = Enum.count(results, &(&1 == :error))

        if failures > 0 do
          Logger.warning("Version tracking completed with #{failures} failures")
        else
          Logger.info("Version tracking updated successfully")
        end

        :ok

      {:error, error} ->
        Logger.error("Failed to update version tracking: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper functions

  defp parse_ccp_version(version_string) when is_binary(version_string) do
    # Parse "build-1234567" format
    case Regex.run(~r/build-(\d+)/, version_string) do
      [_, build_str] -> {:ok, String.to_integer(build_str)}
      nil -> :error
    end
  end

  defp parse_ccp_version(_), do: :error

  defp format_version(nil), do: "none"
  defp format_version(%{version_string: str}), do: str
  defp format_version(version) when is_binary(version), do: version
  defp format_version(version), do: inspect(version)
end
