defmodule EveDmv.Result do
  alias EveDmv.Error
  @moduledoc """
  Railway-oriented programming result type for EVE DMV.

  Provides functional programming patterns for consistent error handling
  and operation chaining without exceptions.

  ## Usage

      # Create results
      Result.ok("success")                    # {:ok, "success"}
      Result.error(:timeout, "Request timed out")  # {:error, %EveDmv.Error{}}

      # Chain operations
      {:ok, 5}
      |> Result.map(&(&1 * 2))               # {:ok, 10}
      |> Result.flat_map(&divide_by_two/1)    # {:ok, 5}
      |> Result.unwrap_or(0)                 # 5

      # Handle errors
      {:error, error}
      |> Result.map_error(&add_context/1)    # Add context to error
      |> Result.unwrap_or("default")         # "default"
  """


  @type ok(value) :: {:ok, value}
  @type error :: {:error, Error.t()}
  @type t(value) :: ok(value) | error()

  @doc """
  Create a success result.
  """
  @spec ok(term()) :: ok(term())
  def ok(value), do: {:ok, value}

  @doc """
  Create an error result with EveDmv.Error structure.
  """
  @spec error(atom(), String.t(), keyword()) :: error()
  def error(code, message, opts \\ []) do
    {:error, Error.new(code, message, opts)}
  end

  @doc """
  Create an error result from existing error.
  """
  @spec error(Error.t() | term()) :: error()
  def error(%Error{} = error), do: {:error, error}
  def error(other), do: {:error, Error.normalize(other)}

  @doc """
  Map over success values, leave errors unchanged.

  ## Examples

      {:ok, 5} |> Result.map(&(&1 * 2))      # {:ok, 10}
      {:error, err} |> Result.map(&(&1 * 2)) # {:error, err}
  """
  @spec map(t(a), (a -> b)) :: t(b) when a: term(), b: term()
  def map({:ok, value}, fun), do: {:ok, fun.(value)}
  def map({:error, _} = error, _fun), do: error

  @doc """
  FlatMap for chaining operations that return results.

  ## Examples

      {:ok, 5}
      |> Result.flat_map(fn x -> Result.ok(x * 2) end)  # {:ok, 10}

      {:ok, 0}
      |> Result.flat_map(fn x ->
           if x == 0, do: Result.error(:division_by_zero, "Cannot divide by zero"),
                     else: Result.ok(10 / x)
         end)  # {:error, %EveDmv.Error{code: :division_by_zero}}
  """
  @spec flat_map(t(a), (a -> t(b))) :: t(b) when a: term(), b: term()
  def flat_map({:ok, value}, fun), do: fun.(value)
  def flat_map({:error, _} = error, _fun), do: error

  @doc """
  Map over error values, leave success values unchanged.

  Useful for adding context or transforming errors.
  """
  @spec map_error(t(a), (Error.t() -> Error.t())) :: t(a) when a: term()
  def map_error({:ok, _} = success, _fun), do: success
  def map_error({:error, error}, fun), do: {:error, fun.(error)}

  @doc """
  Get value from success result or return default for errors.

  ## Examples

      {:ok, 42} |> Result.unwrap_or(0)       # 42
      {:error, err} |> Result.unwrap_or(0)   # 0
  """
  @spec unwrap_or(t(a), a) :: a when a: term()
  def unwrap_or({:ok, value}, _default), do: value
  def unwrap_or({:error, _}, default), do: default

  @doc """
  Get value from success result or raise exception for errors.

  ## Examples

      {:ok, 42} |> Result.unwrap!()          # 42
      {:error, err} |> Result.unwrap!()      # raises RuntimeError
  """
  @spec unwrap!(t(a)) :: a when a: term()
  def unwrap!({:ok, value}), do: value

  def unwrap!({:error, error}) do
    normalized = Error.normalize(error)
    raise RuntimeError, message: "Result unwrap failed: #{normalized.message}"
  end

  @doc """
  Check if result is a success.
  """
  @spec ok?(t(term())) :: boolean()
  def ok?({:ok, _}), do: true
  def ok?({:error, _}), do: false

  @doc """
  Check if result is an error.
  """
  @spec error?(t(term())) :: boolean()
  def error?({:error, _}), do: true
  def error?({:ok, _}), do: false

  @doc """
  Combine multiple results, returning success only if all succeed.

  ## Examples

      Result.combine([{:ok, 1}, {:ok, 2}, {:ok, 3}])  # {:ok, [1, 2, 3]}
      Result.combine([{:ok, 1}, {:error, err}])       # {:error, err}
  """
  @spec combine([t(a)]) :: t([a]) when a: term()
  def combine(results) do
    reduced_result =
      Enum.reduce_while(results, {:ok, []}, fn
        {:ok, value}, {:ok, acc} ->
          {:cont, {:ok, [value | acc]}}

        {:error, _} = error, _ ->
          {:halt, error}
      end)

    map(reduced_result, &Enum.reverse/1)
  end

  @doc """
  Apply function to result value and collect results.

  Useful for processing lists where each item might fail.
  """
  @spec traverse([a], (a -> t(b))) :: t([b]) when a: term(), b: term()
  def traverse(items, fun) do
    Enum.map(items, fun)
    |> combine()
  end

  @doc """
  Run operation and convert exceptions to errors.

  ## Examples

      Result.safely(fn -> 10 / 0 end)  # {:error, %EveDmv.Error{}}
      Result.safely(fn -> 10 / 2 end)  # {:ok, 5.0}
  """
  @spec safely((-> a)) :: t(a) when a: term()
  def safely(operation) do
    try do
      {:ok, operation.()}
    rescue
      e in RuntimeError ->
        error(:runtime_error, Exception.message(e))

      e ->
        error(:exception, Exception.message(e), details: %{exception_type: e.__struct__})
    catch
      :exit, reason ->
        error(:process_exit, inspect(reason))

      :throw, value ->
        error(:thrown_value, inspect(value))
    end
  end

  @doc """
  Retry operation with exponential backoff on retryable errors.
  """
  @spec retry((-> t(a)), keyword()) :: t(a) when a: term()
  def retry(operation, opts \\ []) do
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    base_delay = Keyword.get(opts, :base_delay, 1000)
    max_delay = Keyword.get(opts, :max_delay, 30_000)

    do_retry(operation, 1, max_attempts, base_delay, max_delay)
  end

  defp do_retry(operation, attempt, max_attempts, base_delay, max_delay) do
    case operation.() do
      {:ok, _} = success ->
        success

      {:error, error} = failure ->
        if attempt < max_attempts and Error.retryable?(error) do
          delay = min(base_delay * :math.pow(2, attempt - 1), max_delay)
          Process.sleep(round(delay))
          do_retry(operation, attempt + 1, max_attempts, base_delay, max_delay)
        else
          failure
        end
    end
  end

  @doc """
  Convert legacy error formats to Result format.
  """
  @spec from_legacy(term()) :: t(term())
  def from_legacy({:ok, value}), do: {:ok, value}
  def from_legacy({:error, reason}), do: {:error, Error.normalize(reason)}
  def from_legacy(:ok), do: {:ok, :ok}
  def from_legacy(:error), do: {:error, Error.new(:generic_error, "Operation failed")}
  def from_legacy(value), do: {:ok, value}

  @doc """
  Convert Result to legacy tuple format.
  """
  @spec to_legacy(t(a)) :: {:ok, a} | {:error, term()} when a: term()
  def to_legacy({:ok, value}), do: {:ok, value}
  def to_legacy({:error, %Error{} = error}), do: {:error, error}

  @doc """
  Tap into success values for side effects without changing the result.

  Useful for logging or other side effects.
  """
  @spec tap(t(a), (a -> term())) :: t(a) when a: term()
  def tap({:ok, value} = result, fun) do
    fun.(value)
    result
  end

  def tap({:error, _} = error, _fun), do: error

  @doc """
  Tap into error values for side effects without changing the result.
  """
  @spec tap_error(t(a), (Error.t() -> term())) :: t(a) when a: term()
  def tap_error({:ok, _} = success, _fun), do: success

  def tap_error({:error, error} = result, fun) do
    fun.(error)
    result
  end
end
