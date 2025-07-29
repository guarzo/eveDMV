defmodule EveDmv.Contexts.CombatAnalysis.Domain.BattleSharingService do
  @moduledoc """
  Service for creating and managing shareable battle reports.

  Provides battle report creation, video integration, community curation,
  and sharing functionality.
  """

  use GenServer

  alias EveDmv.Shared.Infrastructure.UnifiedCache

  require Logger

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Create a shareable battle report.
  """
  def create_battle_report(battle_id, creator_id, options \\ []) do
    GenServer.call(__MODULE__, {:create_battle_report, battle_id, creator_id, options})
  end

  @doc """
  Rate a battle report.
  """
  def rate_battle_report(report_id, user_id, rating) do
    GenServer.call(__MODULE__, {:rate_battle_report, report_id, user_id, rating})
  end

  @doc """
  Evaluate if a battle is worth sharing.
  """
  def evaluate_battle_for_sharing(battle_id) do
    GenServer.cast(__MODULE__, {:evaluate_battle_for_sharing, battle_id})
  end

  @doc """
  Get all battle reports for a specific battle.
  """
  def get_battle_reports(battle_id) do
    GenServer.call(__MODULE__, {:get_battle_reports, battle_id})
  end

  # GenServer implementation

  @impl GenServer
  def init(_opts) do
    state = %{
      reports_created: 0,
      ratings_processed: 0
    }

    Logger.info("BattleSharingService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_call({:create_battle_report, battle_id, creator_id, options}, _from, state) do
    case create_battle_report_impl(battle_id, creator_id, options) do
      {:ok, report} ->
        {:reply, {:ok, report}, %{state | reports_created: state.reports_created + 1}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:rate_battle_report, report_id, user_id, rating}, _from, state) do
    case rate_battle_report_impl(report_id, user_id, rating) do
      {:ok, updated_report} ->
        {:reply, {:ok, updated_report}, %{state | ratings_processed: state.ratings_processed + 1}}

      error ->
        {:reply, error, state}
    end
  end

  @impl GenServer
  def handle_call({:get_battle_reports, battle_id}, _from, state) do
    reports = fetch_battle_reports(battle_id)
    {:reply, {:ok, reports}, state}
  end

  @impl GenServer
  def handle_call(:health_check, _from, state) do
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:evaluate_battle_for_sharing, battle_id}, state) do
    # Asynchronously evaluate battle for automatic sharing
    Task.start(fn ->
      case should_auto_share_battle?(battle_id) do
        true ->
          Logger.info("Battle #{battle_id} recommended for sharing")

        # Could automatically create featured battle report
        false ->
          Logger.debug("Battle #{battle_id} not recommended for sharing")
      end
    end)

    {:noreply, state}
  end

  # Private functions

  defp create_battle_report_impl(battle_id, creator_id, options) do
    try do
      # Get battle data
      case get_battle_data(battle_id) do
        {:ok, battle_data} ->
          report_data = %{
            id: generate_report_id(),
            battle_id: battle_id,
            creator_id: creator_id,
            title: Keyword.get(options, :title, generate_default_title(battle_data)),
            description: Keyword.get(options, :description, ""),
            video_urls: Keyword.get(options, :video_urls, []),
            visibility: Keyword.get(options, :visibility, :public),
            created_at: DateTime.utc_now(),
            rating: 0.0,
            rating_count: 0,
            view_count: 0,
            share_url: generate_share_url(battle_id)
          }

          # Cache the report
          cache_key = {:battle_report, report_data.id}
          # 1 hour
          UnifiedCache.cache_combat_analysis(cache_key, report_data, 3600)

          {:ok, report_data}

        error ->
          error
      end
    rescue
      e ->
        Logger.error("Failed to create battle report: #{inspect(e)}")
        {:error, :creation_failed}
    end
  end

  defp rate_battle_report_impl(report_id, _user_id, rating) do
    try do
      # Validate rating
      if rating < 1 or rating > 5 do
        {:error, :invalid_rating}
      else
        case get_battle_report(report_id) do
          {:ok, report} ->
            # Update rating (simplified implementation)
            new_rating_count = report.rating_count + 1
            new_total_rating = report.rating * report.rating_count + rating
            new_average_rating = new_total_rating / new_rating_count

            updated_report = %{
              report
              | rating: Float.round(new_average_rating, 2),
                rating_count: new_rating_count
            }

            # Update cache
            cache_key = {:battle_report, report_id}
            UnifiedCache.cache_combat_analysis(cache_key, updated_report, 3600)

            {:ok, updated_report}

          error ->
            error
        end
      end
    rescue
      e ->
        Logger.error("Failed to rate battle report: #{inspect(e)}")
        {:error, :rating_failed}
    end
  end

  defp should_auto_share_battle?(battle_id) do
    case get_battle_data(battle_id) do
      {:ok, battle_data} ->
        # Criteria for auto-sharing
        participant_count = battle_data[:participant_count] || 0
        total_value = battle_data[:total_value] || 0

        # 1B ISK
        participant_count >= 50 and total_value >= 1_000_000_000

      _ ->
        false
    end
  end

  defp get_battle_data(battle_id) do
    # Get battle data from cache or repository
    cache_key = {:battle, battle_id}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, battle_data} ->
        {:ok, battle_data}

      {:error, :not_found} ->
        # Would query database for battle data
        {:error, :battle_not_found}
    end
  end

  defp get_battle_report(report_id) do
    cache_key = {:battle_report, report_id}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, report} ->
        {:ok, report}

      {:error, :not_found} ->
        {:error, :report_not_found}
    end
  end

  defp generate_report_id() do
    # Generate a proper UUID for battle report ID
    timestamp = System.system_time(:second)
    uuid_bytes = :crypto.strong_rand_bytes(8)
    uuid_suffix = Base.encode16(uuid_bytes, case: :lower)
    "report_#{timestamp}_#{uuid_suffix}"
  end

  defp generate_default_title(battle_data) do
    system_id = battle_data[:system_id] || battle_data.system_id
    participant_count = battle_data[:participant_count] || 0

    "Battle in System #{system_id} - #{participant_count} Participants"
  end

  defp generate_share_url(battle_id) do
    "https://evedmv.com/battles/#{battle_id}/share"
  end

  defp fetch_battle_reports(battle_id) do
    # Fetch all reports for a specific battle
    # In a real implementation, this would query the database
    cache_key = {:battle_reports, battle_id}

    case UnifiedCache.get_combat_analysis(cache_key) do
      {:ok, reports} ->
        reports

      {:error, :not_found} ->
        # Would query database for battle reports
        []
    end
  end
end
