defmodule EveDmv.Events.GenericEvent do
  @moduledoc """
  Generic event struct for domain events.

  This struct provides a flexible container for domain events that don't
  have their own specific struct definition.
  """

  defstruct [
    :event_type,
    :context,
    :killmail_id,
    :character_id,
    :battle_id,
    :timestamp,
    :data
  ]

  @type t :: %__MODULE__{
          event_type: atom() | nil,
          context: atom() | nil,
          killmail_id: integer() | nil,
          character_id: integer() | nil,
          battle_id: binary() | nil,
          timestamp: DateTime.t() | nil,
          data: map() | nil
        }
end
