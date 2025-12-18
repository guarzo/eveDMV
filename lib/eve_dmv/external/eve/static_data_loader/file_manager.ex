defmodule EveDmv.Eve.StaticDataLoader.FileManager do
  @moduledoc """
  Manages EVE SDE file downloads and caching.

  Downloads the official CCP Static Data Export in JSONL format from CCP's developer portal.
  Uses ZIP compression and contains all static data files.

  ## CCP SDE

  Downloads the official JSONL format from CCP's developer portal.
  Uses ZIP compression and contains all static data files.
  """

  alias EveDmv.Eve.StaticDataLoader.CcpSdeClient

  require Logger

  # CCP JSONL file mappings
  # These are the paths within the extracted SDE ZIP
  @ccp_files %{
    item_types: "types.jsonl",
    item_groups: "groups.jsonl",
    item_categories: "categories.jsonl",
    solar_systems: "mapSolarSystems.jsonl",
    regions: "mapRegions.jsonl",
    constellations: "mapConstellations.jsonl"
  }

  @doc """
  Gets the path to the static data directory.
  """
  def get_data_directory do
    Path.join([:code.priv_dir(:eve_dmv), "static_data"])
  end

  @doc """
  Gets the mapping of required file types to filenames.
  """
  def get_required_files, do: @ccp_files

  @doc """
  Gets the file mapping for the CCP source.
  """
  @spec get_files_for_source() :: map()
  def get_files_for_source, do: @ccp_files

  @doc """
  Ensures SDE files are available.

  Downloads and extracts the CCP SDE ZIP archive if necessary.

  ## Parameters

  - `required_keys` - List of file types needed (e.g., `[:item_types, :item_groups]`)

  ## Returns

  - `{:ok, %{source: :ccp, file_paths: map()}}` on success
  - `{:error, reason}` on failure
  """
  @spec ensure_sde_files(list(atom())) :: {:ok, map()} | {:error, term()}
  def ensure_sde_files(required_keys) do
    Logger.info("Ensuring SDE files from CCP")
    ensure_ccp_files(required_keys)
  end

  @doc """
  Ensures CCP SDE JSONL files are available.

  Downloads and extracts the CCP SDE ZIP archive if necessary.

  ## Returns

  - `{:ok, %{source: :ccp, file_paths: map(), extracted_dir: String.t()}}` on success
  - `{:error, reason}` on failure
  """
  @spec ensure_ccp_files(list(atom())) :: {:ok, map()} | {:error, term()}
  def ensure_ccp_files(required_keys) do
    data_dir = get_data_directory()
    ccp_dir = Path.join(data_dir, "ccp_sde")
    extracted_dir = Path.join(ccp_dir, "extracted")

    # Check if we already have extracted files
    required_files = Map.take(@ccp_files, required_keys)

    case find_ccp_files(extracted_dir, required_files) do
      {:ok, file_paths} ->
        Logger.info("CCP SDE files already available")
        {:ok, %{source: :ccp, file_paths: file_paths, extracted_dir: extracted_dir}}

      {:error, :missing_files} ->
        Logger.info("CCP SDE files not found, downloading...")
        download_and_extract_ccp_sde(ccp_dir, required_keys)
    end
  end

  @doc """
  Downloads and extracts the CCP SDE archive.

  ## Parameters

  - `ccp_dir` - Directory to store the CCP SDE files
  - `required_keys` - List of file types needed

  ## Returns

  - `{:ok, %{source: :ccp, file_paths: map(), extracted_dir: String.t()}}` on success
  - `{:error, reason}` on failure
  """
  @spec download_and_extract_ccp_sde(String.t(), list(atom())) :: {:ok, map()} | {:error, term()}
  def download_and_extract_ccp_sde(ccp_dir, required_keys) do
    File.mkdir_p!(ccp_dir)

    with {:ok, result} <- CcpSdeClient.download_and_extract(ccp_dir) do
      Logger.info("CCP SDE downloaded and extracted to: #{result.extracted_dir}")

      # Find the required files in the extracted directory
      required_files = Map.take(@ccp_files, required_keys)

      case find_ccp_files(result.extracted_dir, required_files) do
        {:ok, file_paths} ->
          {:ok, %{source: :ccp, file_paths: file_paths, extracted_dir: result.extracted_dir}}

        {:error, :missing_files} ->
          {:error, "Required SDE files not found after extraction"}
      end
    end
  end

  @doc """
  Clears the static data cache by removing all SDE files.
  """
  def clear_cache do
    data_dir = get_data_directory()
    ccp_dir = Path.join(data_dir, "ccp_sde")

    if File.exists?(ccp_dir) do
      case File.rm_rf(ccp_dir) do
        {:ok, _files} ->
          Logger.info("Cleared SDE cache")
          :ok

        {:error, reason} ->
          Logger.error("Failed to clear cache: #{inspect(reason)}")
          {:error, reason}
      end
    else
      :ok
    end
  end

  @doc """
  Gets information about CCP SDE cache.
  """
  @spec get_cache_info() :: map()
  def get_cache_info do
    data_dir = get_data_directory()
    ccp_dir = Path.join(data_dir, "ccp_sde")
    extracted_dir = Path.join(ccp_dir, "extracted")

    if File.exists?(extracted_dir) do
      # Find all JSONL files recursively
      files =
        Path.wildcard(Path.join([extracted_dir, "**", "*.jsonl"]))
        |> Enum.map(fn path ->
          stat = File.stat!(path)

          %{
            name: Path.basename(path),
            path: path,
            size: stat.size,
            modified: stat.mtime
          }
        end)

      %{
        source: :ccp,
        directory: ccp_dir,
        extracted_dir: extracted_dir,
        files: files,
        total_size: Enum.sum(Enum.map(files, & &1.size))
      }
    else
      %{
        source: :ccp,
        directory: ccp_dir,
        extracted_dir: extracted_dir,
        files: [],
        total_size: 0
      }
    end
  end

  # Private CCP functions

  defp find_ccp_files(extracted_dir, required_files) do
    if File.exists?(extracted_dir) do
      file_paths =
        Enum.reduce_while(required_files, {:ok, %{}}, fn {key, filename}, {:ok, acc} ->
          case Path.wildcard(Path.join([extracted_dir, "**", filename])) do
            [path | _] ->
              {:cont, {:ok, Map.put(acc, key, path)}}

            [] ->
              Logger.debug("Missing CCP file: #{filename}")
              {:halt, {:error, :missing_files}}
          end
        end)

      case file_paths do
        {:ok, paths} when map_size(paths) == map_size(required_files) ->
          {:ok, paths}

        _ ->
          {:error, :missing_files}
      end
    else
      {:error, :missing_files}
    end
  end
end
