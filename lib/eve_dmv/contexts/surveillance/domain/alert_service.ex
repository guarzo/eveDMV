defmodule EveDmv.Contexts.Surveillance.Domain.AlertService do
  @moduledoc """
  Alert generation and management service for surveillance matches.

  Handles the creation, prioritization, and lifecycle management of alerts
  generated from surveillance profile matches.
  """

  use GenServer
  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Contexts.Surveillance.Infrastructure.{ProfileRepository, MatchCache}
  alias EveDmv.Contexts.Surveillance.Domain.NotificationService
  alias EveDmv.DomainEvents.{SurveillanceMatch, SurveillanceAlert}
  alias EveDmv.Infrastructure.EventBus

  require Logger

  # Alert priority levels
  @priority_critical 1
  @priority_high 2
  @priority_medium 3
  @priority_low 4

  # Alert states
  @state_new "new"
  @state_acknowledged "acknowledged"
  @state_investigating "investigating"
  @state_resolved "resolved"
  @state_false_positive "false_positive"

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Process a surveillance match and generate appropriate alerts.
  """
  def process_match(match) do
    GenServer.cast(__MODULE__, {:process_match, match})
  end

  @doc """
  Get recent alerts with filtering options.
  """
  def get_recent_alerts(opts \\ []) do
    GenServer.call(__MODULE__, {:get_recent_alerts, opts})
  end

  @doc """
  Get alert details by ID.
  """
  def get_alert(alert_id) do
    GenServer.call(__MODULE__, {:get_alert, alert_id})
  end

  @doc """
  Update alert state (acknowledge, resolve, etc.).
  """
  def update_alert_state(alert_id, new_state, user_id, notes \\ nil) do
    GenServer.call(__MODULE__, {:update_alert_state, alert_id, new_state, user_id, notes})
  end

  @doc """
  Get alert statistics and metrics.
  """
  def get_alert_metrics(time_range \\ :last_24h) do
    GenServer.call(__MODULE__, {:get_alert_metrics, time_range})
  end

  @doc """
  Bulk acknowledge alerts by criteria.
  """
  def bulk_acknowledge_alerts(criteria, user_id) do
    GenServer.call(__MODULE__, {:bulk_acknowledge_alerts, criteria, user_id})
  end

  # GenServer implementation

  @impl GenServer
  def init(opts) do
    # Subscribe to surveillance match events
    EventBus.subscribe(:surveillance_match, self())

    state = %{
      # alert_id -> alert_data
      alerts: %{},
      alert_counters: %{
        total: 0,
        new: 0,
        acknowledged: 0,
        resolved: 0
      },
      # Ordered list of recent alert IDs
      recent_alerts: [],
      metrics_cache: %{},
      last_cleanup: DateTime.utc_now()
    }

    # Schedule periodic cleanup
    # Every minute
    Process.send_after(self(), :cleanup_old_alerts, 60_000)

    Logger.info("AlertService started")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:process_match, match}, state) do
    # Generate alert from match
    alert = generate_alert_from_match(match)

    # Store alert
    new_alerts = Map.put(state.alerts, alert.id, alert)

    # Update counters
    new_counters = %{
      state.alert_counters
      | total: state.alert_counters.total + 1,
        new: state.alert_counters.new + 1
    }

    # Add to recent alerts (keep last 1000)
    new_recent = [alert.id | Enum.take(state.recent_alerts, 999)]

    # Publish alert event
    EventBus.publish(%SurveillanceAlert{
      alert_id: alert.id,
      alert_type: alert.alert_type,
      priority: alert.priority,
      profile_id: match.profile_id,
      match_data: %{match_id: match.id},
      timestamp: alert.created_at
    })

    # Trigger notification if appropriate
    if should_trigger_notification?(alert) do
      NotificationService.send_alert_notification(alert)
    end

    new_state = %{
      state
      | alerts: new_alerts,
        alert_counters: new_counters,
        recent_alerts: new_recent
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call({:get_recent_alerts, opts}, _from, state) do
    limit = Keyword.get(opts, :limit, 50)
    priority_filter = Keyword.get(opts, :priority)
    state_filter = Keyword.get(opts, :state)
    profile_id_filter = Keyword.get(opts, :profile_id)

    filtered_alerts =
      state.recent_alerts
      # Take more to account for filtering
      |> Enum.take(limit * 2)
      |> Enum.map(&Map.get(state.alerts, &1))
      |> Enum.filter(&filter_alert(&1, priority_filter, state_filter, profile_id_filter))
      |> Enum.take(limit)

    {:reply, {:ok, filtered_alerts}, state}
  end

  @impl GenServer
  def handle_call({:get_alert, alert_id}, _from, state) do
    case Map.get(state.alerts, alert_id) do
      nil -> {:reply, {:error, :alert_not_found}, state}
      alert -> {:reply, {:ok, alert}, state}
    end
  end

  @impl GenServer
  def handle_call({:update_alert_state, alert_id, new_state, user_id, notes}, _from, state) do
    case Map.get(state.alerts, alert_id) do
      nil ->
        {:reply, {:error, :alert_not_found}, state}

      alert ->
        updated_alert = update_alert_state_internal(alert, new_state, user_id, notes)
        new_alerts = Map.put(state.alerts, alert_id, updated_alert)

        # Update counters
        new_counters = update_state_counters(state.alert_counters, alert.state, new_state)

        new_state = %{
          state
          | alerts: new_alerts,
            alert_counters: new_counters
        }

        Logger.info("Updated alert #{alert_id} state: #{alert.state} -> #{new_state}")

        {:reply, {:ok, updated_alert}, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_alert_metrics, time_range}, _from, state) do
    metrics = calculate_alert_metrics(state, time_range)
    {:reply, {:ok, metrics}, state}
  end

  @impl GenServer
  def handle_call({:bulk_acknowledge_alerts, criteria, user_id}, _from, state) do
    matching_alerts = find_alerts_by_criteria(state.alerts, criteria)

    {updated_alerts, count} =
      Enum.reduce(matching_alerts, {state.alerts, 0}, fn {alert_id, alert},
                                                         {alerts_acc, count_acc} ->
        if alert.state == @state_new do
          updated_alert =
            update_alert_state_internal(alert, @state_acknowledged, user_id, "Bulk acknowledged")

          {Map.put(alerts_acc, alert_id, updated_alert), count_acc + 1}
        else
          {alerts_acc, count_acc}
        end
      end)

    new_counters = %{
      state.alert_counters
      | new: state.alert_counters.new - count,
        acknowledged: state.alert_counters.acknowledged + count
    }

    new_state = %{
      state
      | alerts: updated_alerts,
        alert_counters: new_counters
    }

    Logger.info("Bulk acknowledged #{count} alerts")

    {:reply, {:ok, count}, new_state}
  end

  @impl GenServer
  def handle_info(:cleanup_old_alerts, state) do
    # Remove alerts older than 30 days to prevent memory growth
    current_time = DateTime.utc_now()
    cutoff_time = DateTime.add(current_time, -30 * 24 * 3600, :second)

    {remaining_alerts, removed_count} =
      Enum.reduce(state.alerts, {%{}, 0}, fn {alert_id, alert}, {acc_alerts, acc_count} ->
        if DateTime.compare(alert.created_at, cutoff_time) == :gt do
          {Map.put(acc_alerts, alert_id, alert), acc_count}
        else
          {acc_alerts, acc_count + 1}
        end
      end)

    # Update recent alerts list to remove cleaned up alerts
    remaining_alert_ids = MapSet.new(Map.keys(remaining_alerts))
    new_recent_alerts = Enum.filter(state.recent_alerts, &MapSet.member?(remaining_alert_ids, &1))

    if removed_count > 0 do
      Logger.info("Cleaned up #{removed_count} old alerts")
    end

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_old_alerts, 60_000)

    new_state = %{
      state
      | alerts: remaining_alerts,
        recent_alerts: new_recent_alerts,
        last_cleanup: DateTime.utc_now()
    }

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_info({:event, %SurveillanceMatch{} = match_event}, state) do
    # Convert match event to match structure and process
    match = %{
      id: match_event.match_id,
      profile_id: match_event.profile_id,
      killmail_id: match_event.killmail_id,
      matched_criteria: match_event.matched_criteria,
      confidence_score: match_event.confidence_score,
      timestamp: match_event.timestamp
    }

    handle_cast({:process_match, match}, state)
  end

  @impl GenServer
  def handle_info(_message, state) do
    {:noreply, state}
  end

  # Private functions

  defp generate_alert_from_match(match) do
    # Determine alert priority based on match characteristics
    priority = determine_alert_priority(match)

    # Determine alert type
    alert_type = determine_alert_type(match)

    # Generate unique alert ID
    alert_id = generate_alert_id()

    %{
      id: alert_id,
      match_id: match.id,
      profile_id: match.profile_id,
      killmail_id: match.killmail_id,
      priority: priority,
      alert_type: alert_type,
      state: @state_new,
      confidence_score: match.confidence_score,
      matched_criteria: match.matched_criteria,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      acknowledged_by: nil,
      acknowledged_at: nil,
      resolved_by: nil,
      resolved_at: nil,
      notes: [],
      metadata: extract_alert_metadata(match)
    }
  end

  defp determine_alert_priority(match) do
    # Priority based on confidence score and criteria type
    base_priority =
      cond do
        match.confidence_score >= 0.9 -> @priority_critical
        match.confidence_score >= 0.7 -> @priority_high
        match.confidence_score >= 0.5 -> @priority_medium
        true -> @priority_low
      end

    # Adjust based on matched criteria importance
    criteria_adjustment =
      Enum.reduce(match.matched_criteria, 0, fn criterion, acc ->
        case criterion.type do
          # Higher priority for victim matches
          :victim -> acc - 1
          # Highest priority
          :high_value_target -> acc - 2
          _ -> acc
        end
      end)

    max(@priority_critical, base_priority + criteria_adjustment)
  end

  defp determine_alert_type(match) do
    # Determine alert type based on what was matched
    cond do
      Enum.any?(match.matched_criteria, &(&1.type == :victim)) ->
        :target_killed

      Enum.any?(match.matched_criteria, &(&1.type in [:attacker, :attacker_corporation])) ->
        :target_active

      Enum.any?(match.matched_criteria, &(&1.type == :system)) ->
        :location_activity

      true ->
        :general_match
    end
  end

  defp extract_alert_metadata(match) do
    %{
      match_timestamp: match.timestamp,
      criteria_count: length(match.matched_criteria),
      has_victim_match: Enum.any?(match.matched_criteria, &(&1.type == :victim)),
      has_attacker_match:
        Enum.any?(
          match.matched_criteria,
          &(&1.type in [:attacker, :attacker_corporation, :attacker_alliance])
        )
    }
  end

  defp should_trigger_notification?(alert) do
    # Trigger notifications for critical and high priority alerts
    alert.priority in [@priority_critical, @priority_high]
  end

  defp update_alert_state_internal(alert, new_state, user_id, notes) do
    current_time = DateTime.utc_now()

    base_alert = %{
      alert
      | state: new_state,
        updated_at: current_time
    }

    # Add state-specific fields
    alert_with_state =
      case new_state do
        @state_acknowledged ->
          %{base_alert | acknowledged_by: user_id, acknowledged_at: current_time}

        @state_resolved ->
          %{base_alert | resolved_by: user_id, resolved_at: current_time}

        _ ->
          base_alert
      end

    # Add notes if provided
    final_alert =
      if notes do
        note_entry = %{
          user_id: user_id,
          timestamp: current_time,
          content: notes,
          action: new_state
        }

        %{alert_with_state | notes: [note_entry | alert.notes]}
      else
        alert_with_state
      end

    final_alert
  end

  defp update_state_counters(counters, old_state, new_state) do
    # Decrement old state counter
    decremented =
      case old_state do
        @state_new -> %{counters | new: max(0, counters.new - 1)}
        @state_acknowledged -> %{counters | acknowledged: max(0, counters.acknowledged - 1)}
        @state_resolved -> %{counters | resolved: max(0, counters.resolved - 1)}
        _ -> counters
      end

    # Increment new state counter
    case new_state do
      @state_new -> %{decremented | new: decremented.new + 1}
      @state_acknowledged -> %{decremented | acknowledged: decremented.acknowledged + 1}
      @state_resolved -> %{decremented | resolved: decremented.resolved + 1}
      _ -> decremented
    end
  end

  defp filter_alert(alert, priority_filter, state_filter, profile_id_filter) do
    priority_match = is_nil(priority_filter) or alert.priority == priority_filter
    state_match = is_nil(state_filter) or alert.state == state_filter
    profile_match = is_nil(profile_id_filter) or alert.profile_id == profile_id_filter

    priority_match and state_match and profile_match
  end

  defp find_alerts_by_criteria(alerts, criteria) do
    Enum.filter(alerts, fn {_alert_id, alert} ->
      Enum.all?(criteria, fn {key, value} ->
        Map.get(alert, key) == value
      end)
    end)
  end

  defp calculate_alert_metrics(state, time_range) do
    current_time = DateTime.utc_now()

    cutoff_time =
      case time_range do
        :last_hour -> DateTime.add(current_time, -3600, :second)
        :last_24h -> DateTime.add(current_time, -24 * 3600, :second)
        :last_7d -> DateTime.add(current_time, -7 * 24 * 3600, :second)
        :last_30d -> DateTime.add(current_time, -30 * 24 * 3600, :second)
      end

    recent_alerts =
      state.alerts
      |> Map.values()
      |> Enum.filter(&(DateTime.compare(&1.created_at, cutoff_time) == :gt))

    priority_distribution =
      recent_alerts
      |> Enum.group_by(& &1.priority)
      |> Map.new(fn {priority, alerts} -> {priority, length(alerts)} end)

    state_distribution =
      recent_alerts
      |> Enum.group_by(& &1.state)
      |> Map.new(fn {state, alerts} -> {state, length(alerts)} end)

    type_distribution =
      recent_alerts
      |> Enum.group_by(& &1.alert_type)
      |> Map.new(fn {type, alerts} -> {type, length(alerts)} end)

    %{
      time_range: time_range,
      total_alerts: length(recent_alerts),
      priority_distribution: priority_distribution,
      state_distribution: state_distribution,
      type_distribution: type_distribution,
      average_confidence:
        if(length(recent_alerts) > 0,
          do: Enum.sum(Enum.map(recent_alerts, & &1.confidence_score)) / length(recent_alerts),
          else: 0
        ),
      current_counters: state.alert_counters
    }
  end

  defp generate_alert_id do
    random_bytes = :crypto.strong_rand_bytes(16)
    Base.encode16(random_bytes, case: :lower)
  end
end
