defmodule EveDmv.Ash.Notifiers.TelemetryNotifier do
  @moduledoc """
  Emits telemetry events for Ash resource operations.

  Enables monitoring of resource operations without instrumenting
  individual service calls. Integrates with the existing OpenTelemetry
  setup for observability.

  ## Telemetry Events

  The following events are emitted:

  - `[:eve_dmv, :ash, :resource, :create]` - Resource created
  - `[:eve_dmv, :ash, :resource, :update]` - Resource updated
  - `[:eve_dmv, :ash, :resource, :destroy]` - Resource destroyed
  - `[:eve_dmv, :ash, :resource, :read]` - Resource read (if notifiers configured for reads)

  ## Measurements

  - `count: 1` - Increment counter for each operation

  ## Metadata

  - `resource` - The resource name (underscore format)
  - `action` - The action name
  - `id` - The resource ID (if available)

  ## Usage in Resources

      use Ash.Resource,
        notifiers: [EveDmv.Ash.Notifiers.TelemetryNotifier]

  ## Metrics Handler Setup

  To capture these events, add a handler in your telemetry setup:

      :telemetry.attach_many(
        "ash-resource-metrics",
        [
          [:eve_dmv, :ash, :resource, :create],
          [:eve_dmv, :ash, :resource, :update],
          [:eve_dmv, :ash, :resource, :destroy]
        ],
        &MyApp.Telemetry.handle_resource_event/4,
        nil
      )
  """

  use Ash.Notifier

  require Logger

  @impl Ash.Notifier
  def notify(%Ash.Notifier.Notification{} = notification) do
    %{resource: resource, action: action, data: data} = notification

    resource_name = extract_resource_name(resource)
    action_type = action.type
    action_name = action.name
    record_id = Map.get(data, :id)

    :telemetry.execute(
      [:eve_dmv, :ash, :resource, action_type],
      %{count: 1},
      %{
        resource: resource_name,
        action: action_name,
        id: record_id
      }
    )

    Logger.debug("TelemetryNotifier: #{action_type} on #{resource_name} (action: #{action_name})")

    :ok
  end

  @spec extract_resource_name(module()) :: String.t()
  defp extract_resource_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
