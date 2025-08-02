defmodule EveDmv.Contexts.FleetOperations.Domain do
  @moduledoc """
  Ash domain for Fleet Operations resources.

  Manages fleet doctrines and related fleet management functionality.
  """
  """

  use Ash.Domain, otp_app: :eve_dmv

  resources do
    resource(EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine)
  end

  authorization do
    authorize(:when_requested)
  end
end
