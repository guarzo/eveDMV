defmodule EveDmv.Eve.StaticDataLoader.CcpSdeClient do
  @moduledoc """
  Client for downloading EVE Online Static Data Export directly from CCP.

  Uses the official SDE endpoints:
  - Latest version: developers.eveonline.com/static-data/eve-online-static-data-latest-jsonl.zip
  - Version info: developers.eveonline.com/static-data/tranquility/latest.jsonl

  Features:
  - HTTP client with proper User-Agent header
  - Progress reporting for large downloads (~500MB)
  - ETag/Last-Modified support for caching
  - Automatic retry with exponential backoff
  - Download timeout of 30 minutes for large files
  """

  require Logger

  @base_url "https://developers.eveonline.com/static-data"
  @version_url "#{@base_url}/tranquility/latest.jsonl"
  @latest_jsonl_url "#{@base_url}/eve-online-static-data-latest-jsonl.zip"

  @user_agent "EveDmv/1.0 (https://github.com/eve-dmv; contact@example.com)"

  # 30 minutes for large downloads
  @download_timeout 30 * 60 * 1_000

  # Retry configuration
  @max_retries 3
  @base_delay_ms 1_000

  @required_sde_files [
    "types.jsonl",
    "groups.jsonl",
    "categories.jsonl",
    "mapSolarSystems.jsonl",
    "mapRegions.jsonl",
    "mapConstellations.jsonl"
  ]

  @type version_info :: %{
          build_number: integer(),
          release_date: String.t()
        }

  @type download_result :: {:ok, binary()} | {:error, term()}

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Fetches the latest SDE build number and release date from CCP.

  Returns:
  - `{:ok, %{build_number: integer, release_date: String.t}}` on success
  - `{:error, reason}` on failure
  """
  @spec get_latest_build_number() :: {:ok, version_info()} | {:error, term()}
  def get_latest_build_number do
    Logger.info("Fetching latest SDE version info from CCP...")

    with {:ok, body} <- fetch_with_retry(@version_url),
         {:ok, version_info} <- parse_version_info(body) do
      Logger.info(
        "Latest SDE: build #{version_info.build_number}, released #{version_info.release_date}"
      )

      {:ok, version_info}
    end
  end

  @doc """
  Downloads the SDE archive to the specified directory.

  Options:
  - `:progress_callback` - Function called with progress updates `fn(bytes_downloaded, total_bytes) -> :ok end`
  - `:etag` - If provided, returns `:not_modified` if the server's ETag matches

  Returns:
  - `{:ok, archive_path}` on success
  - `{:ok, :not_modified}` if ETag matches
  - `{:error, reason}` on failure
  """
  @spec download_sde_archive(String.t(), keyword()) ::
          {:ok, String.t()} | {:ok, :not_modified} | {:error, term()}
  def download_sde_archive(output_dir, opts \\ []) do
    File.mkdir_p!(output_dir)
    archive_path = Path.join(output_dir, "eve-sde-latest.zip")

    Logger.info("Downloading SDE archive from CCP...")
    Logger.info("Destination: #{archive_path}")

    headers = build_download_headers(opts)

    case download_large_file(@latest_jsonl_url, archive_path, headers, opts) do
      {:ok, :downloaded} ->
        Logger.info("SDE archive downloaded successfully")
        {:ok, archive_path}

      {:ok, :not_modified} ->
        Logger.info("SDE archive not modified (ETag match)")
        {:ok, :not_modified}

      {:error, reason} = error ->
        Logger.error("Failed to download SDE archive: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Extracts the SDE archive to the specified directory.

  Returns:
  - `{:ok, extracted_dir}` on success
  - `{:error, reason}` on failure
  """
  @spec extract_archive(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def extract_archive(archive_path, output_dir) do
    Logger.info("Extracting SDE archive...")
    Logger.info("Source: #{archive_path}")
    Logger.info("Destination: #{output_dir}")

    File.mkdir_p!(output_dir)

    case :zip.unzip(String.to_charlist(archive_path), [{:cwd, String.to_charlist(output_dir)}]) do
      {:ok, _files} ->
        Logger.info("SDE archive extracted successfully")
        {:ok, output_dir}

      {:error, reason} ->
        Logger.error("Failed to extract SDE archive: #{inspect(reason)}")
        {:error, {:extraction_failed, reason}}
    end
  end

  @doc """
  Validates that all required SDE files exist in the extracted directory.

  Returns:
  - `{:ok, file_paths}` with a map of file type to path
  - `{:error, {:missing_files, list}}` if files are missing
  """
  @spec validate_required_files(String.t()) :: {:ok, map()} | {:error, term()}
  def validate_required_files(extracted_dir) do
    Logger.info("Validating required SDE files...")

    {found, missing} =
      @required_sde_files
      |> Enum.reduce({%{}, []}, fn filename, {found_acc, missing_acc} ->
        path = find_file_in_directory(extracted_dir, filename)

        if path do
          key = filename_to_key(filename)
          {Map.put(found_acc, key, path), missing_acc}
        else
          {found_acc, [filename | missing_acc]}
        end
      end)

    case missing do
      [] ->
        Logger.info("All #{map_size(found)} required SDE files found")
        {:ok, found}

      files ->
        Logger.error("Missing required SDE files: #{inspect(files)}")
        {:error, {:missing_files, files}}
    end
  end

  @doc """
  Downloads and extracts the SDE archive in one operation.

  This is a convenience function that combines download, extract, and validate.

  Returns:
  - `{:ok, %{archive_path: String.t, extracted_dir: String.t, file_paths: map}}` on success
  - `{:error, reason}` on failure
  """
  @spec download_and_extract(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def download_and_extract(base_dir, opts \\ []) do
    archive_dir = Path.join(base_dir, "archives")
    extracted_dir = Path.join(base_dir, "extracted")

    with {:ok, archive_path} <- download_sde_archive(archive_dir, opts),
         {:ok, _} <- extract_archive(archive_path, extracted_dir),
         {:ok, file_paths} <- validate_required_files(extracted_dir) do
      {:ok,
       %{
         archive_path: archive_path,
         extracted_dir: extracted_dir,
         file_paths: file_paths
       }}
    end
  end

  @doc """
  Gets the list of required SDE files.
  """
  @spec required_files() :: [String.t()]
  def required_files, do: @required_sde_files

  @doc """
  Gets the URL for the latest JSONL SDE archive.
  """
  @spec latest_archive_url() :: String.t()
  def latest_archive_url, do: @latest_jsonl_url

  @doc """
  Gets the URL for version info.
  """
  @spec version_url() :: String.t()
  def version_url, do: @version_url

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp fetch_with_retry(url, attempt \\ 1) do
    headers = [{"User-Agent", @user_agent}]

    case Finch.build(:get, url, headers)
         |> Finch.request(EveDmv.Finch, receive_timeout: 30_000) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status}} when status in [500, 502, 503, 504] and attempt <= @max_retries ->
        delay = (@base_delay_ms * :math.pow(2, attempt - 1)) |> round()

        Logger.warning(
          "Server error #{status}, retrying in #{delay}ms (attempt #{attempt}/#{@max_retries})"
        )

        Process.sleep(delay)
        fetch_with_retry(url, attempt + 1)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} when attempt <= @max_retries ->
        delay = (@base_delay_ms * :math.pow(2, attempt - 1)) |> round()

        Logger.warning(
          "Request failed: #{inspect(reason)}, retrying in #{delay}ms (attempt #{attempt}/#{@max_retries})"
        )

        Process.sleep(delay)
        fetch_with_retry(url, attempt + 1)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_version_info(body) when is_binary(body) do
    # The response is a single JSONL line
    case Jason.decode(body) do
      {:ok, %{"buildNumber" => build_number, "releaseDate" => release_date}} ->
        {:ok, %{build_number: build_number, release_date: release_date}}

      {:ok, data} ->
        Logger.error("Unexpected version info format: #{inspect(data)}")
        {:error, :invalid_version_format}

      {:error, reason} ->
        Logger.error("Failed to parse version info JSON: #{inspect(reason)}")
        {:error, {:json_parse_error, reason}}
    end
  end

  defp build_download_headers(opts) do
    headers = [{"User-Agent", @user_agent}]

    case Keyword.get(opts, :etag) do
      nil -> headers
      etag -> [{"If-None-Match", etag} | headers]
    end
  end

  defp download_large_file(url, output_path, headers, opts) do
    progress_callback = Keyword.get(opts, :progress_callback)
    request = Finch.build(:get, url, headers)

    # State for the streaming handler
    initial_state = %{
      status: nil,
      content_length: nil,
      bytes_downloaded: 0,
      file: nil,
      error: nil
    }

    # Open file for writing before starting the stream
    case File.open(output_path, [:write, :binary]) do
      {:ok, file} ->
        try do
          stream_result =
            Finch.stream_while(
              request,
              EveDmv.Finch,
              %{initial_state | file: file},
              fn
                {:status, status}, state ->
                  handle_stream_status(status, state)

                {:headers, response_headers}, state ->
                  handle_stream_headers(response_headers, state)

                {:data, chunk}, state ->
                  handle_stream_data(chunk, state, progress_callback)
              end,
              receive_timeout: @download_timeout
            )

          case stream_result do
            {:ok, %{status: 200}} ->
              {:ok, :downloaded}

            {:ok, %{status: 304}} ->
              # Clean up the empty file for 304 responses
              File.rm(output_path)
              {:ok, :not_modified}

            {:ok, %{status: status}} ->
              File.rm(output_path)
              {:error, {:http_error, status}}

            {:ok, %{error: error}} when error != nil ->
              File.rm(output_path)
              {:error, error}

            {:error, reason} ->
              File.rm(output_path)
              {:error, reason}
          end
        after
          File.close(file)
        end

      {:error, reason} ->
        {:error, {:file_open_error, reason}}
    end
  end

  defp handle_stream_status(status, state) do
    case status do
      200 ->
        {:cont, %{state | status: status}}

      304 ->
        # For 304 Not Modified, we still continue to get the final state
        {:cont, %{state | status: status}}

      _other ->
        # For other status codes, continue to capture the status but we'll handle it after
        {:cont, %{state | status: status}}
    end
  end

  defp handle_stream_headers(response_headers, state) do
    content_length = get_content_length(response_headers)
    {:cont, %{state | content_length: content_length}}
  end

  defp handle_stream_data(_chunk, %{status: status} = state, _progress_callback)
       when status != 200 do
    # Don't write data for non-200 responses
    {:cont, state}
  end

  defp handle_stream_data(chunk, state, progress_callback) do
    case IO.binwrite(state.file, chunk) do
      :ok ->
        new_bytes_downloaded = state.bytes_downloaded + byte_size(chunk)

        # Call progress callback with incremental update
        if progress_callback do
          progress_callback.(new_bytes_downloaded, state.content_length)
        end

        {:cont, %{state | bytes_downloaded: new_bytes_downloaded}}

      {:error, reason} ->
        {:halt, %{state | error: {:write_error, reason}}}
    end
  end

  defp get_content_length(headers) do
    case Enum.find(headers, fn {name, _} -> String.downcase(name) == "content-length" end) do
      {_, value} -> String.to_integer(value)
      nil -> nil
    end
  end

  defp find_file_in_directory(dir, filename) do
    # Search recursively for the file
    case Path.wildcard(Path.join([dir, "**", filename])) do
      [path | _] -> path
      [] -> nil
    end
  end

  defp filename_to_key(filename) do
    case filename do
      "types.jsonl" ->
        :item_types

      "groups.jsonl" ->
        :item_groups

      "categories.jsonl" ->
        :item_categories

      "mapSolarSystems.jsonl" ->
        :solar_systems

      "mapRegions.jsonl" ->
        :regions

      "mapConstellations.jsonl" ->
        :constellations

      # Optional SDE file - not in @required_sde_files because the application
      # can function without stargate data. Used for enhanced system connectivity
      # analysis when available. See parse_stargates/1 in JsonlParser.
      "mapStargates.jsonl" ->
        :stargates

      # For unknown files, try to use an existing atom or fall back to unknown
      other ->
        key = String.replace(other, ".jsonl", "")

        try do
          String.to_existing_atom(key)
        rescue
          ArgumentError ->
            Logger.warning(
              "Unrecognized SDE file encountered: #{inspect(other)} (derived key: #{inspect(key)}). " <>
                "Returning :unknown_file. If this file is needed, add it to @required_sde_files " <>
                "and filename_to_key/1."
            )

            :unknown_file
        end
    end
  end
end
