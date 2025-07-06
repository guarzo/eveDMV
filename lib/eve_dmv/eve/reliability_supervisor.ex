defmodule EveDmv.Eve.ReliabilitySupervisor do
  @moduledoc """
  Supervisor for ESI reliability components.

  Manages circuit breakers and other reliability infrastructure
  for the ESI client components.
  """

  use Supervisor
  require Logger
  alias EveDmv.Eve.{CircuitBreaker, ReliabilityConfig}

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Validate configuration on startup
    case ReliabilityConfig.validate_config() do
      :ok ->
        Logger.info("ESI reliability configuration validated successfully")

      {:error, reason} ->
        Logger.error("ESI reliability configuration validation failed: #{reason}")
        # Continue anyway with defaults
    end

    children = [
      # Registry for circuit breakers
      {Registry, keys: :unique, name: EveDmv.Registry},

      # Circuit breakers for different services
      circuit_breaker_spec(:esi_api, ReliabilityConfig.get_circuit_breaker_config(:esi_api)),
      circuit_breaker_spec(
        :esi_character,
        ReliabilityConfig.get_circuit_breaker_config(:esi_character)
      ),
      circuit_breaker_spec(
        :esi_corporation,
        ReliabilityConfig.get_circuit_breaker_config(:esi_corporation)
      ),
      circuit_breaker_spec(
        :esi_universe,
        ReliabilityConfig.get_circuit_breaker_config(:esi_universe)
      ),
      circuit_breaker_spec(
        :janice_api,
        ReliabilityConfig.get_circuit_breaker_config(:janice_api)
      ),
      circuit_breaker_spec(
        :mutamarket_api,
        ReliabilityConfig.get_circuit_breaker_config(:mutamarket_api)
      )
    ]

    # Only start circuit breakers if they're enabled
    enabled_children =
      Enum.filter(children, fn child ->
        case child do
          %{start: {CircuitBreaker, opts}} ->
            service_name = Keyword.get(opts, :service_name)
            ReliabilityConfig.circuit_breaker_enabled?(service_name)

          _ ->
            true
        end
      end)

    Supervisor.init(enabled_children, strategy: :one_for_one)
  end

  defp circuit_breaker_spec(service_name, config) do
    Supervisor.child_spec(
      {CircuitBreaker,
       [
         service_name: service_name,
         failure_threshold: config.failure_threshold,
         recovery_timeout: config.recovery_timeout,
         success_threshold: config.success_threshold,
         timeout: ReliabilityConfig.get_timeout(service_name)
       ]},
      id: "circuit_breaker_#{service_name}"
    )
  end
end
