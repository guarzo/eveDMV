defmodule EveDmv.Killmails.DatabaseInserter do
  @moduledoc """
  Handles bulk database insertion operations for killmail data.

  Provides efficient bulk insertion methods for raw killmails, enriched killmails,
  and participants using Ash bulk operations with proper error handling, logging,
  and circuit breaker protection to prevent cascade failures during database issues.

  ## Circuit Breaker

  The circuit breaker prevents database overload during failure scenarios:
  - Opens after 5 consecutive failures
  - Resets after 60 seconds in open state
  - Half-open state allows one test request

  Use `get_circuit_status/0` to check current state.
  """

  use GenServer

  alias EveDmv.Api
  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Killmails.Participant

  require Logger

  # Circuit breaker configuration
  @failure_threshold 5
  @reset_timeout_ms 60_000
  @half_open_success_threshold 2

  # Circuit states
  @circuit_closed :closed
  @circuit_open :open
  @circuit_half_open :half_open

  defmodule CircuitState do
    @moduledoc false
    defstruct [
      :state,
      :failure_count,
      :last_failure,
      :opened_at,
      :success_count_since_half_open
    ]
  end

  # Client API for circuit breaker

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the current circuit breaker status.
  """
  @spec get_circuit_status() :: map()
  def get_circuit_status do
    GenServer.call(__MODULE__, :get_status)
  catch
    :exit, _ ->
      # If GenServer not running, assume closed
      %{state: :closed, failure_count: 0}
  end

  @doc """
  Manually reset the circuit breaker (admin operation).
  """
  @spec reset_circuit() :: :ok
  def reset_circuit do
    GenServer.call(__MODULE__, :reset)
  catch
    :exit, _ -> :ok
  end

  # GenServer callbacks

  @impl GenServer
  def init(_opts) do
    state = %CircuitState{
      state: @circuit_closed,
      failure_count: 0,
      last_failure: nil,
      opened_at: nil,
      success_count_since_half_open: 0
    }

    Logger.info("DatabaseInserter circuit breaker initialized (closed state)")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(:get_status, _from, state) do
    status = %{
      state: state.state,
      failure_count: state.failure_count,
      last_failure: state.last_failure,
      opened_at: state.opened_at
    }

    {:reply, status, state}
  end

  @impl GenServer
  def handle_call(:reset, _from, _state) do
    Logger.info("Circuit breaker manually reset")

    new_state = %CircuitState{
      state: @circuit_closed,
      failure_count: 0,
      last_failure: nil,
      opened_at: nil,
      success_count_since_half_open: 0
    }

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:check_circuit, _from, state) do
    {result, new_state} = do_check_circuit(state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call(:record_success, _from, state) do
    new_state = do_record_success(state)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call(:record_failure, _from, state) do
    new_state = do_record_failure(state, self())
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_info(:try_half_open, state) do
    if state.state == @circuit_open do
      Logger.info("Circuit breaker transitioning to half-open state")
      {:noreply, %{state | state: @circuit_half_open, success_count_since_half_open: 0}}
    else
      {:noreply, state}
    end
  end

  # Private circuit breaker logic

  defp do_check_circuit(%{state: @circuit_closed} = state), do: {:ok, state}

  defp do_check_circuit(%{state: @circuit_open, opened_at: opened_at} = state) do
    elapsed = DateTime.diff(DateTime.utc_now(), opened_at, :millisecond)

    if elapsed >= @reset_timeout_ms do
      Logger.info("Circuit breaker timeout elapsed, transitioning to half-open")
      {:ok, %{state | state: @circuit_half_open, success_count_since_half_open: 0}}
    else
      remaining_ms = @reset_timeout_ms - elapsed
      {:error, {:circuit_open, remaining_ms}}
    end
  end

  defp do_check_circuit(%{state: @circuit_half_open} = state), do: {:ok, state}

  defp do_record_success(%{state: @circuit_half_open} = state) do
    new_count = state.success_count_since_half_open + 1

    if new_count >= @half_open_success_threshold do
      Logger.info("Circuit breaker closing after successful half-open tests")

      %CircuitState{
        state: @circuit_closed,
        failure_count: 0,
        last_failure: nil,
        opened_at: nil,
        success_count_since_half_open: 0
      }
    else
      %{state | success_count_since_half_open: new_count}
    end
  end

  defp do_record_success(%{state: @circuit_closed} = state) do
    # Reset failure count on success
    %{state | failure_count: 0}
  end

  defp do_record_success(state), do: state

  defp do_record_failure(%{state: @circuit_closed, failure_count: count} = state, pid) do
    new_count = count + 1
    now = DateTime.utc_now()

    if new_count >= @failure_threshold do
      Logger.warning("Circuit breaker OPENING after #{new_count} consecutive failures")

      emit_circuit_breaker_telemetry(:opened, new_count)
      schedule_half_open_transition(pid)

      %{state | state: @circuit_open, failure_count: new_count, last_failure: now, opened_at: now}
    else
      %{state | failure_count: new_count, last_failure: now}
    end
  end

  defp do_record_failure(%{state: @circuit_half_open} = state, pid) do
    Logger.warning("Circuit breaker reopening after failed half-open test")
    emit_circuit_breaker_telemetry(:reopened, state.failure_count + 1)
    schedule_half_open_transition(pid)

    now = DateTime.utc_now()
    %{state | state: @circuit_open, failure_count: state.failure_count + 1, opened_at: now}
  end

  defp do_record_failure(state, _pid), do: state

  defp schedule_half_open_transition(pid) do
    Process.send_after(pid, :try_half_open, @reset_timeout_ms)
  end

  defp emit_circuit_breaker_telemetry(event, failure_count) do
    :telemetry.execute(
      [:eve_dmv, :pipeline, :circuit_breaker],
      %{failure_count: failure_count},
      %{event: event}
    )
  end

  # Circuit breaker helper functions with intentional fail-open behavior.
  # If the GenServer is unavailable (crashed, not started, etc.), these functions
  # return :ok to allow database operations to proceed. This prevents the circuit
  # breaker infrastructure from becoming a single point of failure - database
  # insertions should not fail just because the circuit breaker process is down.
  defp check_circuit do
    GenServer.call(__MODULE__, :check_circuit)
  catch
    :exit, _ -> :ok
  end

  defp record_success do
    GenServer.call(__MODULE__, :record_success)
  catch
    :exit, _ -> :ok
  end

  defp record_failure do
    GenServer.call(__MODULE__, :record_failure)
  catch
    :exit, _ -> :ok
  end

  @doc """
  Insert raw killmail records using bulk operations.

  Uses Ash.bulk_create for efficient insertion with error collection
  and partial success handling. Protected by circuit breaker.
  """
  @spec insert_raw_killmails([map()]) :: :ok | :error | {:error, :circuit_open}
  def insert_raw_killmails(raw_changesets) do
    # Check circuit breaker first
    case check_circuit() do
      {:error, {:circuit_open, remaining_ms}} ->
        Logger.warning(
          "Circuit breaker OPEN - skipping #{length(raw_changesets)} raw killmails " <>
            "(resets in #{div(remaining_ms, 1000)}s)"
        )

        {:error, :circuit_open}

      :ok ->
        do_insert_raw_killmails(raw_changesets)
    end
  end

  defp do_insert_raw_killmails(raw_changesets) do
    Logger.debug("Inserting #{length(raw_changesets)} raw killmails using bulk operation")

    # Deduplicate by killmail_id to prevent constraint violations in batch
    unique_changesets = deduplicate_killmails(raw_changesets)

    if length(unique_changesets) < length(raw_changesets) do
      Logger.debug(
        "Deduplicated #{length(raw_changesets)} -> #{length(unique_changesets)} raw killmails"
      )
    end

    # Use Ash bulk operation for much better performance
    case Ash.bulk_create(unique_changesets, KillmailRaw, :ingest_from_source,
           domain: Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} ->
        record_success()
        success_count = length(unique_changesets)
        Logger.debug("Successfully bulk inserted #{success_count} raw killmails")
        :ok

      %Ash.BulkResult{status: :partial_success} = result ->
        # Partial success still counts as success for circuit breaker
        record_success()
        handle_partial_success(result, raw_changesets, "raw killmail")

      %Ash.BulkResult{status: :error} = result ->
        record_failure()
        handle_bulk_error(result, "raw killmail")

      other ->
        record_failure()
        Logger.error("Unexpected bulk insert result: #{inspect(other)}")
        :error
    end
  end

  @doc """
  Insert participant records using bulk operations.

  Handles flattening of participant lists, validation filtering,
  and bulk insertion with comprehensive error handling. Protected by circuit breaker.
  """
  @spec insert_participants([list()] | list()) :: :ok | :error | {:error, :circuit_open}
  def insert_participants(participants_lists) when is_list(participants_lists) do
    # Check circuit breaker first
    case check_circuit() do
      {:error, {:circuit_open, remaining_ms}} ->
        participant_count =
          participants_lists
          |> Enum.filter(&(&1 != nil))
          |> List.flatten()
          |> length()

        Logger.warning(
          "Circuit breaker OPEN - skipping #{participant_count} participants " <>
            "(resets in #{div(remaining_ms, 1000)}s)"
        )

        {:error, :circuit_open}

      :ok ->
        do_insert_participants(participants_lists)
    end
  end

  defp do_insert_participants(participants_lists) do
    # Filter out any nil values before flattening
    valid_lists = Enum.filter(participants_lists, &(&1 != nil))
    participants = List.flatten(valid_lists)
    Logger.debug("Inserting #{length(participants)} participants using bulk operation")

    # Filter out any invalid participants before bulk operation
    valid_participants = Enum.filter(participants, &valid_participant?/1)

    if Enum.empty?(valid_participants) do
      Logger.debug("No valid participants to insert")
      :ok
    else
      # Deduplicate participants to prevent constraint violations in batch
      unique_participants = deduplicate_participants(valid_participants)

      if length(unique_participants) < length(valid_participants) do
        Logger.debug(
          "Deduplicated #{length(valid_participants)} -> #{length(unique_participants)} participants"
        )
      end

      perform_participant_bulk_insert(participants, unique_participants)
    end
  end

  @doc """
  Validate that a participant record has required fields.
  """
  @spec valid_participant?(map()) :: boolean()
  def valid_participant?(participant) when is_map(participant) do
    required_fields = [:killmail_id, :killmail_time, :ship_type_id]

    Enum.all?(required_fields, fn field ->
      value = Map.get(participant, field)
      not is_nil(value) and value != ""
    end)
  end

  def valid_participant?(_), do: false

  # Private helper functions

  defp perform_participant_bulk_insert(all_participants, valid_participants) do
    case Ash.bulk_create(valid_participants, Participant, :create,
           domain: Api,
           return_records?: false,
           return_errors?: true,
           stop_on_error?: false
         ) do
      %Ash.BulkResult{status: :success} ->
        record_success()
        handle_participant_success(all_participants, valid_participants)

      %Ash.BulkResult{status: :partial_success} = result ->
        # Partial success still counts as success for circuit breaker
        record_success()
        handle_participant_partial_success(result, valid_participants)

      %Ash.BulkResult{status: :error} = result ->
        record_failure()
        handle_bulk_error(result, "participant")
    end
  end

  defp handle_participant_success(all_participants, unique_participants) do
    success_count = length(unique_participants)
    skipped_count = length(all_participants) - length(unique_participants)

    if skipped_count > 0 do
      Logger.info(
        "Successfully bulk inserted #{success_count} participants, skipped #{skipped_count} invalid/duplicate"
      )
    else
      Logger.debug("Successfully bulk inserted #{success_count} participants")
    end

    :ok
  end

  defp handle_participant_partial_success(result, valid_participants) do
    error_count = length(result.errors)
    success_count = length(valid_participants) - error_count

    Logger.warning(
      "Bulk participant insert partially successful: #{success_count} succeeded, #{error_count} failed"
    )

    # Log first few errors for debugging
    result.errors
    |> Enum.take(3)
    |> Enum.each(fn error ->
      Logger.error("Participant bulk insert error: #{inspect(error)}")
    end)

    # Consider partial success as ok for pipeline resilience
    :ok
  end

  defp handle_partial_success(result, changesets, entity_type) do
    error_count = length(result.errors)
    success_count = length(changesets) - error_count

    Logger.warning(
      "#{String.capitalize(entity_type)} bulk insert partially successful: #{success_count} succeeded, #{error_count} failed"
    )

    # Log first few errors for debugging
    result.errors
    |> Enum.take(3)
    |> Enum.each(fn error ->
      Logger.error("#{String.capitalize(entity_type)} bulk insert error: #{inspect(error)}")
    end)

    # Consider partial success as ok for pipeline resilience
    :ok
  end

  defp handle_bulk_error(result, entity_type) do
    Logger.error("#{String.capitalize(entity_type)} bulk insert failed completely")

    result.errors
    |> Enum.take(5)
    |> Enum.each(fn error ->
      Logger.error("#{String.capitalize(entity_type)} bulk insert error: #{inspect(error)}")
    end)

    :error
  end

  # Deduplication helpers

  defp deduplicate_killmails(raw_changesets) do
    Enum.uniq_by(raw_changesets, fn changeset ->
      # Deduplicate by killmail_id to prevent constraint violations
      Map.get(changeset, :killmail_id)
    end)
  end

  defp deduplicate_participants(participants) do
    Enum.uniq_by(participants, fn participant ->
      # Deduplicate by unique combination that matches the actual constraint:
      # unique_participant_per_killmail: [:killmail_id, :killmail_time, :character_id, :ship_type_id]
      {
        Map.get(participant, :killmail_id),
        Map.get(participant, :killmail_time),
        Map.get(participant, :character_id),
        Map.get(participant, :ship_type_id)
      }
    end)
  end
end
