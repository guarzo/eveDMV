defmodule EveDmvWeb.SurveillanceLive.Components do
  @moduledoc """
  UI components and helpers for surveillance live view.

  Provides data loading, formatting, and display functions used in the surveillance
  interface templates.
  """

  alias EveDmv.Api
  alias EveDmv.Surveillance.MatchingEngine
  alias EveDmv.Surveillance.ProfileMatch

  require Logger

  # Data Loading Functions

  @doc """
  Load recent profile matches for display.

  Returns the most recent matches within the last 24 hours.
  """
  @spec load_recent_matches() :: [ProfileMatch.t()]
  def load_recent_matches do
    # Reduce query time by limiting results and reducing time window
    case Ash.read(ProfileMatch, action: :recent_matches, input: %{hours: 6}, domain: Api) do
      {:ok, matches} ->
        # Limit to 10 matches for better performance
        Enum.take(matches, 10)

      {:error, error} ->
        Logger.warning("Failed to load recent matches: #{inspect(error)}")
        []
    end
  end

  @doc """
  Get matching engine statistics.

  Returns engine stats with fallback values if the engine is unavailable.
  """
  @spec get_engine_stats() :: map()
  def get_engine_stats do
    MatchingEngine.get_stats()
  rescue
    error ->
      Logger.warning("Failed to get engine stats: #{inspect(error)}")
      %{profiles_loaded: 0, matches_processed: 0}
  end

  @doc """
  Sample filter tree for new profiles.

  Provides a template filter tree structure for users creating new profiles.
  """
  @spec sample_filter_tree() :: %{String.t() => any()}
  def sample_filter_tree do
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

  # View Helper Functions

  @doc """
  Format a filter tree as pretty JSON for display.
  """
  @spec format_filter_tree(map()) :: String.t()
  def format_filter_tree(filter_tree) do
    Jason.encode!(filter_tree, pretty: true)
  end

  @doc """
  Format a datetime for display.
  """
  @spec format_datetime(DateTime.t() | nil) :: String.t()
  def format_datetime(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
      _ -> "Unknown"
    end
  end

  @doc """
  Generate a status badge for profile active state.
  """
  @spec profile_status_badge(boolean()) :: String.t()
  def profile_status_badge(is_active) do
    if is_active do
      "🟢 Active"
    else
      "🔴 Inactive"
    end
  end

  @doc """
  Format a count with appropriate plural/singular form.
  """
  @spec format_count(non_neg_integer(), String.t()) :: String.t()
  def format_count(0, singular), do: "No #{singular}s"
  def format_count(1, singular), do: "1 #{singular}"
  def format_count(count, singular), do: "#{count} #{singular}s"

  @doc """
  Generate CSS classes for profile status.
  """
  @spec profile_status_classes(boolean()) :: String.t()
  def profile_status_classes(is_active) do
    base_classes = "px-2 py-1 rounded-full text-xs font-medium"

    if is_active do
      "#{base_classes} bg-green-100 text-green-800"
    else
      "#{base_classes} bg-red-100 text-red-800"
    end
  end

  @doc """
  Truncate text to a maximum length with ellipsis.
  """
  @spec truncate_text(String.t(), non_neg_integer()) :: String.t()
  def truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length - 3) <> "..."
    end
  end

  def truncate_text(_, _), do: ""
end
