defmodule EveDmv.Eve.StaticDataLoader.FileManager do
  @moduledoc """
  Manages EVE SDE file downloads and caching.

  Handles downloading CSV files from fuzzwork.co.uk, decompressing bz2 archives,
  and maintaining a local cache of SDE data files.
  """

  require Logger

  @required_files %{
    item_types: "invTypes.csv",
    item_groups: "invGroups.csv",
    item_categories: "invCategories.csv",
    solar_systems: "mapSolarSystems.csv",
    regions: "mapRegions.csv",
    constellations: "mapConstellations.csv"
  }

  @doc """
  Ensures all required CSV files exist, downloading if necessary.
  """
  @spec ensure_csv_files(list(atom())) :: {:ok, map()} | {:error, term()}
  def ensure_csv_files(required_keys) do
    data_dir = get_data_directory()
    File.mkdir_p!(data_dir)

    required_files = Map.take(@required_files, required_keys)
    missing_files = get_missing_files(data_dir, required_files)

    case missing_files do
      [] ->
        {:ok, get_file_paths(data_dir, required_files)}

      missing ->
        Logger.info("Missing CSV files: #{inspect(missing)}")

        case download_files(missing, data_dir) do
          :ok -> {:ok, get_file_paths(data_dir, required_files)}
          error -> error
        end
    end
  end

  @doc """
  Gets the path to the static data directory.
  """
  def get_data_directory do
    Path.join([:code.priv_dir(:eve_dmv), "static_data"])
  end

  @doc """
  Gets the mapping of required file types to filenames.
  """
  def get_required_files, do: @required_files

  @doc """
  Checks which files are missing from the data directory.
  """
  def get_missing_files(data_dir, required_files) do
    required_files
    |> Map.values()
    |> Enum.reject(fn file_name ->
      data_dir
      |> Path.join(file_name)
      |> File.exists?()
    end)
  end

  @doc """
  Gets full paths for all required files.
  """
  def get_file_paths(data_dir, required_files) do
    required_files
    |> Enum.into(%{}, fn {key, filename} ->
      {key, Path.join(data_dir, filename)}
    end)
  end

  @doc """
  Downloads missing files from fuzzwork.co.uk.
  """
  def download_files(file_names, data_dir) do
    Logger.info("Downloading missing CSV files from fuzzwork.co.uk")

    results =
      file_names
      |> Enum.map(&download_single_file(&1, data_dir))

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> :ok
      error -> error
    end
  end

  @doc """
  Downloads a single file from fuzzwork.co.uk.
  """
  def download_single_file(file_name, data_dir) do
    url = "https://www.fuzzwork.co.uk/dump/latest/#{file_name}.bz2"
    output_path = Path.join(data_dir, file_name)

    Logger.info("Downloading #{file_name} from #{url}")

    with {:ok, compressed_data} <- download_file(url),
         {:ok, decompressed} <- decompress_bz2(compressed_data),
         :ok <- File.write(output_path, decompressed) do
      Logger.info("Successfully downloaded and saved #{file_name}")
      :ok
    else
      error ->
        Logger.error("Failed to download #{file_name}: #{inspect(error)}")
        {:error, "Failed to download #{file_name}: #{inspect(error)}"}
    end
  end

  @doc """
  Clears the static data cache by removing all CSV files.
  """
  def clear_cache do
    data_dir = get_data_directory()

    if File.exists?(data_dir) do
      case File.rm_rf(data_dir) do
        {:ok, _} ->
          Logger.info("Cleared static data cache")
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
  Gets information about cached files.
  """
  def get_cache_info do
    data_dir = get_data_directory()

    if File.exists?(data_dir) do
      files =
        File.ls!(data_dir)
        |> Enum.filter(&String.ends_with?(&1, ".csv"))
        |> Enum.map(fn file ->
          path = Path.join(data_dir, file)
          stat = File.stat!(path)

          %{
            name: file,
            size: stat.size,
            modified: stat.mtime
          }
        end)

      %{
        directory: data_dir,
        files: files,
        total_size: Enum.sum(Enum.map(files, & &1.size))
      }
    else
      %{
        directory: data_dir,
        files: [],
        total_size: 0
      }
    end
  end

  # Private functions

  defp download_file(url) do
    case url
         |> Finch.build(:get)
         |> Finch.request(EveDmv.Finch, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decompress_bz2(compressed_data) do
    decompressed = Bzip2.decompress!(compressed_data)
    {:ok, decompressed}
  rescue
    error ->
      Logger.error("bzip2 decompression failed: #{inspect(error)}")
      {:error, "bzip2 decompression failed: #{inspect(error)}"}
  end
end
