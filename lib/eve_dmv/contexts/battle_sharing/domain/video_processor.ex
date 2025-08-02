defmodule EveDmv.Contexts.BattleSharing.Domain.VideoProcessor do
  @moduledoc """
  Video processing and validation module for battle reports.

  This module handles comprehensive video URL validation, metadata extraction, and embed
  generation for supported video platforms. It was extracted from the BattleCurator to
  improve modularity and provide focused video processing capabilities.

  ## Supported Platforms

  - **YouTube**: Full support including youtube.com, youtu.be, and m.youtube.com domains
  - **Twitch**: Support for Twitch videos and VODs with proper embed generation
  - **Extensible**: Framework designed for easy addition of new video platforms

  ## Key Features

  - **URL Validation**: Comprehensive validation of video URLs across platforms
  - **Video ID Extraction**: Robust regex-based extraction of video IDs
  - **Embed Generation**: Automatic generation of embed URLs for web integration
  - **Thumbnail Generation**: Platform-specific thumbnail URL generation
  - **Metadata Processing**: Basic metadata extraction with framework for enhancement

  ## Usage

      # Validate multiple video URLs
      processed_videos = VideoProcessor.validate_video_urls([
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://www.twitch.tv/videos/123456789"
      ])

      # Validate single URL with detailed metadata
      case VideoProcessor.validate_single_video_url(url) do
        {:ok, video_data} ->
          # Use video_data.embed_url, video_data.thumbnail_url, etc.
        {:error, reason} ->
          # Handle validation error
      end

      # Platform detection
      {:ok, :youtube} = VideoProcessor.detect_video_platform("https://youtu.be/dQw4w9WgXcQ")

  ## Implementation Details

  - Uses robust regex patterns for video ID extraction
  - Supports multiple URL formats per platform
  - Generates platform-appropriate embed URLs
  - Handles domain configuration for Twitch embeds
  - Provides clear error messages for unsupported formats

  ## Extension Points

  The module is designed for easy extension:
  - Add new platforms by updating `@supported_platforms`
  - Define platform-specific regex patterns
  - Implement platform-specific thumbnail generation
  - Enhance metadata extraction with API integrations
  """
  """

  require Logger

  # Supported video platforms
  @supported_platforms %{
    youtube: %{
      domains: ["youtube.com", "youtu.be", "m.youtube.com"],
      regex: ~r/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9-]{11})/,
      embed_template: "https://www.youtube.com/embed/{video_id}"
    },
    twitch: %{
      domains: ["twitch.tv", "m.twitch.tv"],
      regex: ~r/twitch\.tv\/videos\/(\d+)|twitch\.tv\/(\w+)\/v\/(\d+)/,
      embed_template: "https://player.twitch.tv/?video={video_id}&parent={domain}"
    }
  }

  @doc """
  Validate a list of video URLs and process their metadata.
  """
  def validate_video_urls(video_urls) when is_list(video_urls) do
    video_urls
    |> Enum.map(&validate_single_video_url/1)
    |> Enum.filter(&match?({:ok, _}, &1))
    |> Enum.map(&elem(&1, 1))
  end

  @doc """
  Validate a single video URL and extract metadata.
  """
  def validate_single_video_url(url) when is_binary(url) do
    url = String.trim(url)

    case detect_video_platform(url) do
      {:ok, platform} ->
        case extract_video_id(url, platform) do
          {:ok, video_id} ->
            metadata = fetch_video_metadata(url, platform, video_id)
            embed_url = generate_embed_url(platform, video_id)
            thumbnail_url = generate_thumbnail_url(platform, video_id)

            {:ok,
             %{
               original_url: url,
               platform: platform,
               video_id: video_id,
               embed_url: embed_url,
               thumbnail_url: thumbnail_url,
               metadata: metadata
             }}

          {:error, reason} ->
            {:error, "Invalid video ID: #{reason}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detect the video platform from a URL.
  """
  def detect_video_platform(url) do
    url_lower = String.downcase(url)

    platform =
      @supported_platforms
      |> Enum.find(fn {_platform, config} ->
        Enum.any?(config.domains, &String.contains?(url_lower, &1))
      end)

    case platform do
      {platform_name, _config} -> {:ok, platform_name}
      nil -> {:error, "Unsupported video platform"}
    end
  end

  @doc """
  Extract video ID from URL based on platform.
  """
  def extract_video_id(url, platform) do
    case Map.get(@supported_platforms, platform) do
      %{regex: regex} ->
        case Regex.run(regex, url) do
          [_, video_id | _] -> {:ok, video_id}
          _ -> {:error, "Could not extract video ID"}
        end

      nil ->
        {:error, "Unsupported platform: #{platform}"}
    end
  end

  @doc """
  Generate embed URL for a video.
  """
  def generate_embed_url(platform, video_id) do
    case Map.get(@supported_platforms, platform) do
      %{embed_template: template} ->
        template
        |> String.replace("{video_id}", video_id)
        |> String.replace("{domain}", get_domain())

      nil ->
        nil
    end
  end

  @doc """
  Generate thumbnail URL for a video.
  """
  def generate_thumbnail_url(:youtube, video_id) do
    "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
  end

  def generate_thumbnail_url(:twitch, video_id) do
    "https://static-cdn.jtvnw.net/cf_vods/#{video_id}/thumb/thumb0-1920x1080.jpg"
  end

  def generate_thumbnail_url(_platform, _video_id), do: nil

  # Private helper functions

  defp fetch_video_metadata(_url, platform, video_id) do
    # Basic metadata - could be enhanced with actual API calls
    %{
      platform: platform,
      video_id: video_id,
      fetched_at: DateTime.utc_now(),
      status: :basic_metadata
    }
  end

  defp get_domain do
    # This should come from application configuration
    System.get_env("APP_DOMAIN", "localhost")
  end
end
