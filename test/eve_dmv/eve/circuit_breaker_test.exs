defmodule EveDmv.Eve.CircuitBreakerTest do
  use EveDmv.DataCase, async: false

  alias EveDmv.Eve.CircuitBreaker

  describe "circuit breaker functionality" do
    @describetag :skip
    test "opens circuit after failure threshold" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Start circuit breaker for this service
      {:ok, _pid} = CircuitBreaker.start_link(service_name: service, failure_threshold: 5)

      # Simulate failures to trigger circuit breaker
      for _i <- 1..5 do
        assert {:error, _} =
                 CircuitBreaker.call(service, fn ->
                   raise "simulated failure"
                 end)
      end

      # Circuit should now be open
      assert {:error, :circuit_open} =
               CircuitBreaker.call(service, fn ->
                 {:ok, :success}
               end)

      # Verify state
      assert CircuitBreaker.get_state(service) == :open
    end

    test "closes circuit after successful recovery" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Start with short recovery timeout for testing
      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 5,
          recovery_timeout: 100,
          success_threshold: 3
        )

      # Open the circuit
      for _i <- 1..5 do
        CircuitBreaker.call(service, fn -> raise "failure" end)
      end

      # Verify circuit is open
      assert CircuitBreaker.get_state(service) == :open

      # Wait for recovery timeout
      :timer.sleep(150)

      # Circuit should be half-open now, allowing test calls
      # Make successful calls to close the circuit
      for _i <- 1..3 do
        assert {:ok, :success} = CircuitBreaker.call(service, fn -> :success end)
      end

      # Circuit should now be closed
      assert CircuitBreaker.get_state(service) == :closed
    end

    test "tracks metrics correctly" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} = CircuitBreaker.start_link(service_name: service)

      # Execute some successful and failed requests
      CircuitBreaker.call(service, fn -> :success end)
      CircuitBreaker.call(service, fn -> raise "failure" end)
      CircuitBreaker.call(service, fn -> :success end)
      CircuitBreaker.call(service, fn -> raise "another failure" end)

      stats = CircuitBreaker.get_stats(service)

      assert stats.success_count >= 0
      assert stats.failure_count == 2
      assert stats.service_name == service
      assert stats.state in [:closed, :open, :half_open]
    end

    test "respects timeout configuration" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          timeout: 100
        )

      # Function that takes too long
      result =
        CircuitBreaker.call(
          service,
          fn ->
            :timer.sleep(200)
            :should_timeout
          end,
          timeout: 100
        )

      assert {:error, :timeout} = result

      # Should count as a failure
      stats = CircuitBreaker.get_stats(service)
      assert stats.failure_count >= 1
    end

    test "resets circuit breaker state" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3
        )

      # Cause some failures
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> raise "failure" end)
      end

      # Circuit should be open
      assert CircuitBreaker.get_state(service) == :open

      # Reset the circuit
      assert :ok = CircuitBreaker.reset(service)

      # Circuit should be closed
      assert CircuitBreaker.get_state(service) == :closed

      # Stats should be reset
      stats = CircuitBreaker.get_stats(service)
      assert stats.failure_count == 0
      assert stats.success_count == 0
    end

    test "handles half-open state correctly" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          recovery_timeout: 100,
          success_threshold: 2
        )

      # Open the circuit
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> raise "failure" end)
      end

      # Wait for half-open state
      :timer.sleep(150)

      # First successful call in half-open state
      assert {:ok, :success} = CircuitBreaker.call(service, fn -> :success end)

      # Should still be half-open (need 2 successes)
      stats = CircuitBreaker.get_stats(service)
      assert stats.state == :half_open
      assert stats.success_count == 1

      # Second successful call should close the circuit
      assert {:ok, :success} = CircuitBreaker.call(service, fn -> :success end)

      assert CircuitBreaker.get_state(service) == :closed
    end

    test "returns to open state on failure during half-open" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          recovery_timeout: 100
        )

      # Open the circuit
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> raise "failure" end)
      end

      # Wait for half-open state
      :timer.sleep(150)

      # Fail during half-open state
      CircuitBreaker.call(service, fn -> raise "recovery failure" end)

      # Should immediately return to open state
      assert CircuitBreaker.get_state(service) == :open
      assert {:error, :circuit_open} = CircuitBreaker.call(service, fn -> :success end)
    end

    test "works without explicit start_link" do
      service = "unstarted_service_#{System.unique_integer([:positive])}"

      # Should default to closed state
      assert CircuitBreaker.get_state(service) == :closed

      # Should allow calls
      assert {:ok, :success} = CircuitBreaker.call(service, fn -> :success end)

      # Should return default stats
      stats = CircuitBreaker.get_stats(service)
      assert stats.state == :closed
      assert stats.failure_count == 0
      assert stats.success_count == 0
    end

    test "handles exceptions and returns" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} = CircuitBreaker.start_link(service_name: service)

      # Test with exception
      exception_result =
        CircuitBreaker.call(service, fn ->
          raise ArgumentError, "test error"
        end)

      assert {:error, {:error, %ArgumentError{message: "test error"}}} = exception_result

      # Test with throw
      throw_result =
        CircuitBreaker.call(service, fn ->
          throw(:test_throw)
        end)

      assert {:error, {:throw, :test_throw}} = throw_result

      # Test with exit
      exit_result =
        CircuitBreaker.call(service, fn ->
          exit(:test_exit)
        end)

      assert {:error, {:exit, :test_exit}} = exit_result
    end

    test "prevents cascading failures" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3
        )

      # Simulate a failing service
      failing_service = fn ->
        :timer.sleep(50)
        raise "Service unavailable"
      end

      # Time the failures
      {time_with_breaker, _} =
        :timer.tc(fn ->
          # First 3 calls will fail and open the circuit
          for _i <- 1..3 do
            CircuitBreaker.call(service, failing_service)
          end

          # Next 10 calls should fail fast
          for _i <- 1..10 do
            CircuitBreaker.call(service, failing_service)
          end
        end)

      # Time without breaker (would be ~650ms for 13 calls at 50ms each)
      # With breaker, should be ~150ms (3 calls) + instant for the rest
      # Less than 300ms
      assert time_with_breaker < 300_000
    end
  end

  describe "configuration" do
    test "uses default configuration when not specified" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} = CircuitBreaker.start_link(service_name: service)

      stats = CircuitBreaker.get_stats(service)

      assert stats.failure_threshold == 5
      assert stats.recovery_timeout == 30_000
      assert stats.success_threshold == 3
    end

    test "accepts custom configuration" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 10,
          recovery_timeout: 60_000,
          success_threshold: 5,
          timeout: 5_000
        )

      stats = CircuitBreaker.get_stats(service)

      assert stats.failure_threshold == 10
      assert stats.recovery_timeout == 60_000
      assert stats.success_threshold == 5
    end
  end

  describe "error classifier" do
    test "default classifier treats all errors as failures" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3
        )

      # All errors should count as failures with default classifier
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> {:error, :some_error} end)
      end

      # Circuit should be open
      assert CircuitBreaker.get_state(service) == :open
    end

    test "custom classifier at init excludes certain errors from failure count" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Classifier that only treats :server_error as a failure
      classifier = fn
        :server_error -> true
        _ -> false
      end

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          error_classifier: classifier
        )

      # Client errors should not count as failures
      for _i <- 1..5 do
        CircuitBreaker.call(service, fn -> {:error, :client_error} end)
      end

      # Circuit should still be closed since client errors don't count
      assert CircuitBreaker.get_state(service) == :closed

      # Server errors should count
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> {:error, :server_error} end)
      end

      # Now circuit should be open
      assert CircuitBreaker.get_state(service) == :open
    end

    test "custom classifier per call overrides instance classifier" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Instance classifier that counts all errors
      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          error_classifier: fn _error -> true end
        )

      # Per-call classifier that ignores all errors
      call_classifier = fn _error -> false end

      # These errors should not count due to call-level classifier
      for _i <- 1..5 do
        CircuitBreaker.call(service, fn -> {:error, :ignored} end,
          error_classifier: call_classifier
        )
      end

      # Circuit should still be closed
      assert CircuitBreaker.get_state(service) == :closed

      # Verify stats show no failures
      stats = CircuitBreaker.get_stats(service)
      assert stats.failure_count == 0
    end

    test "error still returned even when not counted as failure" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Classifier that ignores all errors
      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          error_classifier: fn _error -> false end
        )

      # Error should be returned but not counted
      result = CircuitBreaker.call(service, fn -> {:error, :my_error} end)

      assert {:error, :my_error} = result

      # Failure count should be 0
      stats = CircuitBreaker.get_stats(service)
      assert stats.failure_count == 0
    end

    test "exceptions always count as failures regardless of classifier" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Classifier that tries to ignore all errors
      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          error_classifier: fn _error -> false end
        )

      # Exceptions should still count as failures (infrastructure issues)
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> raise "exception" end)
      end

      # Circuit should be open because exceptions bypass the classifier
      assert CircuitBreaker.get_state(service) == :open
    end

    test "timeouts always count as failures regardless of classifier" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Classifier that tries to ignore all errors
      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          error_classifier: fn _error -> false end
        )

      # Timeouts should still count as failures
      for _i <- 1..3 do
        CircuitBreaker.call(
          service,
          fn ->
            :timer.sleep(200)
            :should_timeout
          end,
          timeout: 50
        )
      end

      # Circuit should be open because timeouts bypass the classifier
      assert CircuitBreaker.get_state(service) == :open
    end

    test "classifier can be used for HTTP status-based filtering" do
      service = "test_service_#{System.unique_integer([:positive])}"

      # Only count 5xx errors as failures, not 4xx
      http_classifier = fn
        {:http_error, status} when status >= 500 -> true
        {:http_error, _status} -> false
        _ -> true
      end

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 3,
          error_classifier: http_classifier
        )

      # 4xx errors should not count
      for _i <- 1..5 do
        CircuitBreaker.call(service, fn -> {:error, {:http_error, 404}} end)
      end

      assert CircuitBreaker.get_state(service) == :closed

      # 5xx errors should count
      for _i <- 1..3 do
        CircuitBreaker.call(service, fn -> {:error, {:http_error, 503}} end)
      end

      assert CircuitBreaker.get_state(service) == :open
    end
  end

  describe "concurrent access" do
    @describetag :skip
    test "handles concurrent calls correctly" do
      service = "test_service_#{System.unique_integer([:positive])}"

      {:ok, _pid} =
        CircuitBreaker.start_link(
          service_name: service,
          failure_threshold: 50
        )

      # Launch concurrent tasks
      tasks =
        for i <- 1..100 do
          Task.async(fn ->
            result =
              CircuitBreaker.call(service, fn ->
                # Mix of success and failure
                if rem(i, 3) == 0 do
                  raise "concurrent failure"
                else
                  :success
                end
              end)

            case result do
              {:ok, :success} -> :success
              {:error, _} -> :failure
            end
          end)
        end

      # Wait for all tasks
      results = Task.await_many(tasks)

      # Should have handled all calls
      assert length(results) == 100

      # Check final state is consistent
      stats = CircuitBreaker.get_stats(service)
      assert is_integer(stats.failure_count)
      assert is_integer(stats.success_count)
    end
  end
end
