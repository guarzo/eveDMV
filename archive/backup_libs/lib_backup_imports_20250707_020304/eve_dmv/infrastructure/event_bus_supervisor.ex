defmodule EveDmv.Infrastructure.EventBusSupervisor do
  use Supervisor
  @moduledoc """
  Supervisor for the domain event infrastructure.

  Manages the event bus and related processes for reliable
  event delivery between bounded contexts.
  """


  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Event bus process
      {EveDmv.Infrastructure.EventBus, []}

      # Event store (for event sourcing if needed in future)
      # {EveDmv.Infrastructure.EventStore, []},

      # Event projections supervisor (for read models)
      # {EveDmv.Infrastructure.ProjectionsSupervisor, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
