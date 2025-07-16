defmodule EveDmv.Contexts.BoundedContext do
  alias __MODULE__, as: BoundedContext
  alias EveDmv.Infrastructure.EventBus

  @moduledoc """
  Base behaviour for bounded contexts in the EVE DMV system.

  Defines the contract for context management, event handling,
  and anti-corruption layers.
  """

  @doc """
  Called when the context is starting up.
  Should return a specification for starting child processes.
  """
  @callback child_spec(opts :: keyword()) :: Supervisor.child_spec()
  @doc """
  Called to initialize the context's event subscriptions.
  Should return a list of {event_type, handler} tuples.
  """
  @callback event_subscriptions() :: [{atom(), (struct() -> any())}]
  @doc """
  Called to validate that the context can handle a specific command.
  """
  @callback can_handle?(command :: struct()) :: boolean()
  @doc """
  Called to get the context's public API module.
  """
  @callback api_module() :: module()
  @optional_callbacks [child_spec: 1, event_subscriptions: 0, can_handle?: 1]
  defmacro __using__(opts) do
    context_name = Keyword.get(opts, :name) || raise "Context name required"

    quote do
      @behaviour EveDmv.Contexts.BoundedContext
      @context_name unquote(context_name)
      unquote(inject_bounded_context_functions())
    end
  end

  defp inject_bounded_context_functions do
    quote do
      unquote(inject_imports_and_aliases())
      unquote(inject_context_functions())
      unquote(inject_overridables())
    end
  end

  defp inject_imports_and_aliases do
    quote do
    end
  end

  defp inject_context_functions do
    quote do
      def context_name, do: @context_name
      def api_module, do: BoundedContext.build_api_module(__MODULE__)
      def can_handle?(_command), do: true
      def child_spec(opts), do: BoundedContext.build_child_spec(__MODULE__, opts)
    end
  end

  defp inject_overridables do
    quote do
      defoverridable can_handle?: 1, child_spec: 1
    end
  end

  @doc false
  def build_api_module(module) do
    module
    |> Module.split()
    |> List.replace_at(-1, "Api")
    |> Module.safe_concat()
  end

  @doc false
  def build_child_spec(module, opts) do
    %{
      id: module,
      start: {module, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Define a public API function for the bounded context.
  """
  defmacro defapi(name, do: body) do
    quote do
      def unquote(name), do: unquote(body)
    end
  end

  @doc """
  Define a command handler for the bounded context.
  """
  defmacro defcommand(command_type, do: body) do
    quote do
      def handle_command(%unquote(command_type){} = command) do
        unquote(body)
      end
    end
  end

  @doc """
  Define an event handler for the bounded context.
  """
  defmacro defevent(event_type, do: body) do
    quote do
      def handle_event(%unquote(event_type){} = event) do
        unquote(body)
      end
    end
  end

  @doc """
  Helper to publish events from within a context.
  """
  def publish_event(event) do
    EventBus.publish(event)
  end

  @doc """
  Helper to create anti-corruption layer functions.
  """
  defmacro translate(from_type, _to_type, do: body) do
    quote do
      def translate(%unquote(from_type){} = source) do
        unquote(body)
      end
    end
  end

  @doc """
  Helper to validate commands before processing.
  """
  def validate_command(command, validations) do
    Enum.reduce_while(validations, {:ok, command}, fn validation, {:ok, cmd} ->
      case validation.(cmd) do
        :ok -> {:cont, {:ok, cmd}}
        {:ok, updated_cmd} -> {:cont, {:ok, updated_cmd}}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Helper to apply business rules.
  """
  def apply_business_rule(state, rule) when is_function(rule, 1) do
    rule.(state)
  end

  @doc """
  Helper to create consistent error responses.
  """
  def context_error(reason, details \\ %{}) do
    {:error,
     %{
       type: :context_error,
       reason: reason,
       details: details,
       context: __MODULE__
     }}
  end
end
