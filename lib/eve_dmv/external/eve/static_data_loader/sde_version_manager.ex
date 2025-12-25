defmodule EveDmv.Eve.StaticDataLoader.SdeVersionManager do
  @moduledoc """
  Manages SDE version checking and automatic updates.

  This module checks for new SDE versions on startup and coordinates
  the download and processing of updated data if necessary.

  Uses CCP's official Static Data Export with build number versioning.
  """

  alias EveDmv.Eve.SolarSystem
  alias EveDmv.Eve.StaticDataLoader
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

      {:ok, _} ->
        # Handle records with unexpected shapes or types
        {:ok, nil}

      {:error, error} ->
        {:error, error}
    end
  end

  defp get_latest_sde_version do
    Logger.info("Checking latest SDE version from CCP...")

    case get_ccp_version_info() do
      {:ok, _version_info} = result ->
        result

      {:error, reason} = error ->
        Logger.error("Failed to get CCP SDE version: #{inspect(reason)}")
        error
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

    Logger.info("=" <> String.duplicate("=", 59))
    Logger.info("📥 STARTING SDE DATA UPDATE")
    Logger.info("   Target version: #{version_string} (build: #{build_number})")
    Logger.info("=" <> String.duplicate("=", 59))

    # Actually load the SDE data
    case StaticDataLoader.load_all_static_data() do
      {:ok, %{item_types: item_count, solar_systems: system_count}} ->
        Logger.info("=" <> String.duplicate("=", 59))
        Logger.info("✅ SDE UPDATE COMPLETED SUCCESSFULLY")
        Logger.info("   Version: #{version_string}")
        Logger.info("   Item types loaded: #{item_count}")
        Logger.info("   Solar systems loaded: #{system_count}")
        Logger.info("=" <> String.duplicate("=", 59))

        {:ok,
         %{
           version: version_string,
           build_number: build_number,
           item_types: item_count,
           solar_systems: system_count
         }}

      {:error, reason} ->
        Logger.error("=" <> String.duplicate("=", 59))
        Logger.error("❌ SDE UPDATE FAILED")
        Logger.error("   Target version: #{version_string}")
        Logger.error("   Error: #{inspect(reason)}")
        Logger.error("=" <> String.duplicate("=", 59))

        {:error, reason}
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
