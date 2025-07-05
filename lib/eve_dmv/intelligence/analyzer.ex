defmodule EveDmv.Intelligence.Analyzer do
  @moduledoc """
  Behaviour contract for intelligence analyzers with standardized telemetry and logging.

  This behaviour defines a consistent interface for all intelligence analysis modules,
  ensuring proper error handling, telemetry instrumentation, and logging patterns.
  """

  @type analysis_result :: {:ok, term()} | {:error, term()}
  @type analysis_options :: map()

  @doc """
  Analyze the given entity (character, corporation, etc.) and return analysis results.

  Implementations should:
  - Include proper telemetry events for start/stop/exception
  - Log analysis progress and errors appropriately
  - Return standardized {:ok, result} | {:error, reason} tuples
  - Handle caching internally if needed
  """
  @callback analyze(entity_id :: integer(), opts :: analysis_options()) :: analysis_result()

  @doc """
  Invalidate cached analysis data for the given entity.

  Should clear all relevant cache entries for the entity to force fresh analysis.
  """
  @callback invalidate_cache(entity_id :: integer()) :: :ok

  @doc """
  Get the analysis type identifier for telemetry and logging.

  Should return a consistent atom identifier (e.g., :character, :corporation, :threat).
  """
  @callback analysis_type() :: atom()

  @doc """
  Validate that the given entity ID and options are suitable for analysis.

  Should perform basic validation before expensive analysis operations.
  """
  @callback validate_params(entity_id :: integer(), opts :: analysis_options()) ::
              :ok | {:error, String.t()}

  @optional_callbacks [validate_params: 2]

  defmacro __using__(_opts) do
    quote do
      @behaviour EveDmv.Intelligence.Analyzer

      require Logger
      alias EveDmv.Intelligence.Analyzer

      @doc """
      Wrapper function that provides standardized telemetry and logging around analysis.
      """
      def analyze_with_telemetry(entity_id, opts \\ %{}) do
        analysis_type = analysis_type()

        metadata = %{
          entity_id: entity_id,
          analysis_type: analysis_type,
          opts: opts
        }

        :telemetry.span(
          [:eve_dmv, :intelligence, :analysis],
          metadata,
          fn ->
            Logger.info("Starting #{analysis_type} analysis for entity #{entity_id}")

            start_time = System.monotonic_time()

            result =
              case validate_analysis_params(entity_id, opts) do
                :ok ->
                  analyze(entity_id, opts)

                {:error, reason} = error ->
                  Logger.warning(
                    "Analysis validation failed for #{analysis_type} #{entity_id}: #{reason}"
                  )

                  error
              end

            duration_ms = System.monotonic_time() - start_time
            duration_ms = System.convert_time_unit(duration_ms, :native, :millisecond)

            case result do
              {:ok, analysis_result} ->
                Logger.info(
                  "Completed #{analysis_type} analysis for entity #{entity_id} in #{duration_ms}ms"
                )

                {result, Map.put(metadata, :duration_ms, duration_ms)}

              {:error, reason} ->
                Logger.error(
                  "Failed #{analysis_type} analysis for entity #{entity_id} after #{duration_ms}ms: #{inspect(reason)}"
                )

                {result, Map.merge(metadata, %{duration_ms: duration_ms, error: reason})}
            end
          end
        )
      end

      @doc """
      Validate analysis parameters with optional custom validation.
      """
      def validate_analysis_params(entity_id, opts) do
        cond do
          not is_integer(entity_id) or entity_id <= 0 ->
            {:error, "Invalid entity_id: must be positive integer"}

          not is_map(opts) ->
            {:error, "Invalid opts: must be a map"}

          function_exported?(__MODULE__, :validate_params, 2) ->
            validate_params(entity_id, opts)

          true ->
            :ok
        end
      end

      @doc """
      Standardized cache invalidation with logging.
      """
      def invalidate_cache_with_logging(entity_id) do
        analysis_type = analysis_type()
        Logger.debug("Invalidating #{analysis_type} cache for entity #{entity_id}")

        :telemetry.execute(
          [:eve_dmv, :intelligence, :cache_invalidation],
          %{count: 1},
          %{entity_id: entity_id, analysis_type: analysis_type}
        )

        invalidate_cache(entity_id)
      end

      # Default implementations that can be overridden
      def analyze(_entity_id, _opts) do
        {:error, "analyze/2 not implemented"}
      end

      def invalidate_cache(_entity_id) do
        Logger.debug("invalidate_cache/1 not implemented")
        :ok
      end

      def analysis_type do
        :generic
      end

      # Make functions overridable
      defoverridable analyze: 2, invalidate_cache: 1, analysis_type: 0
    end
  end
end
