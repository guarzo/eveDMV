defmodule EveDmvWeb.SurveillanceLive.DataLoader do
  @moduledoc """
  Handles data loading operations for surveillance live view.

  Provides functions for loading matches, stats, and other data
  required by the surveillance interface.
  """

  require Logger

  alias EveDmv.Api
  alias EveDmv.Surveillance.{MatchingEngine, ProfileMatch}

  @doc """
  Load recent profile matches for display.

  Returns the most recent matches within the last 24 hours.
  """
  @spec load_recent_matches() :: [ProfileMatch.t()]
  def load_recent_matches do
    case Ash.read(ProfileMatch, action: :recent_matches, input: %{hours: 24}, domain: Api) do
      {:ok, matches} ->
        Enum.take(matches, 20)

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
  @spec sample_filter_tree() :: map()
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
end
