defmodule EveDmv.Market.RateLimiter do
  @moduledoc """
  Token bucket rate limiter for external API calls.

  This module provides rate limiting functionality using a token bucket algorithm
  to prevent hitting API rate limits.
  """

  use GenServer
  require Logger

  @default_max_tokens 10
  # tokens per second
  @default_refill_rate 1
  # milliseconds
  @default_refill_interval 1000

  # Client API

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Acquire tokens from the bucket. Blocks if insufficient tokens available.

  Options:
    - tokens: number of tokens to acquire (default: 1)
    - timeout: max time to wait in ms (default: 5000)
  """
  def acquire(server \\ __MODULE__, opts \\ []) do
    tokens = Keyword.get(opts, :tokens, 1)
    timeout = Keyword.get(opts, :timeout, 5000)

    GenServer.call(server, {:acquire, tokens}, timeout)
  end

  @doc """
  Try to acquire tokens without blocking.
  Returns {:ok, remaining_tokens} or {:error, :insufficient_tokens}
  """
  def try_acquire(server \\ __MODULE__, tokens \\ 1) do
    GenServer.call(server, {:try_acquire, tokens})
  end

  @doc """
  Get current bucket state.
  """
  def get_state(server \\ __MODULE__) do
    GenServer.call(server, :get_state)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    max_tokens = Keyword.get(opts, :max_tokens, @default_max_tokens)
    refill_rate = Keyword.get(opts, :refill_rate, @default_refill_rate)
    refill_interval = Keyword.get(opts, :refill_interval, @default_refill_interval)

    state = %{
      max_tokens: max_tokens,
      current_tokens: max_tokens,
      refill_rate: refill_rate,
      refill_interval: refill_interval,
      waiting_queue: :queue.new(),
      last_refill: System.monotonic_time(:millisecond)
    }

    # Schedule periodic refill
    schedule_refill(state.refill_interval)

    {:ok, state}
  end

  @impl true
  def handle_call({:acquire, tokens}, from, state) do
    state = refill_tokens(state)

    if state.current_tokens >= tokens do
      # Sufficient tokens available
      new_state = %{state | current_tokens: state.current_tokens - tokens}
      {:reply, {:ok, new_state.current_tokens}, new_state}
    else
      # Queue the request
      new_queue =
        :queue.in({from, tokens, System.monotonic_time(:millisecond)}, state.waiting_queue)

      {:noreply, %{state | waiting_queue: new_queue}}
    end
  end

  @impl true
  def handle_call({:try_acquire, tokens}, _from, state) do
    state = refill_tokens(state)

    if state.current_tokens >= tokens do
      new_state = %{state | current_tokens: state.current_tokens - tokens}
      {:reply, {:ok, new_state.current_tokens}, new_state}
    else
      {:reply, {:error, :insufficient_tokens}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    state = refill_tokens(state)

    reply = %{
      current_tokens: state.current_tokens,
      max_tokens: state.max_tokens,
      refill_rate: state.refill_rate,
      queue_length: :queue.len(state.waiting_queue)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_info(:refill, state) do
    state = refill_tokens(state)
    state = process_waiting_queue(state)

    # Schedule next refill
    schedule_refill(state.refill_interval)

    {:noreply, state}
  end

  @impl true
  def handle_info({:timeout, from}, state) do
    # Remove timed out request from queue
    new_queue =
      :queue.filter(
        fn {req_from, _, _} -> req_from != from end,
        state.waiting_queue
      )

    GenServer.reply(from, {:error, :timeout})
    {:noreply, %{state | waiting_queue: new_queue}}
  end

  # Private functions

  defp refill_tokens(state) do
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.last_refill
    tokens_to_add = elapsed / 1000 * state.refill_rate

    new_tokens =
      min(
        state.current_tokens + tokens_to_add,
        state.max_tokens
      )

    %{state | current_tokens: new_tokens, last_refill: now}
  end

  defp process_waiting_queue(state) do
    case :queue.out(state.waiting_queue) do
      {{:value, {from, tokens, enqueued_at}}, rest_queue} ->
        # Check if request has timed out
        if System.monotonic_time(:millisecond) - enqueued_at > 5000 do
          GenServer.reply(from, {:error, :timeout})
          process_waiting_queue(%{state | waiting_queue: rest_queue})
        else
          if state.current_tokens >= tokens do
            # Can fulfill this request
            GenServer.reply(from, {:ok, state.current_tokens - tokens})

            new_state = %{
              state
              | current_tokens: state.current_tokens - tokens,
                waiting_queue: rest_queue
            }

            process_waiting_queue(new_state)
          else
            # Still not enough tokens
            state
          end
        end

      {:empty, _} ->
        state
    end
  end

  defp schedule_refill(interval) do
    Process.send_after(self(), :refill, interval)
  end
end
