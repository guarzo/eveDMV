defmodule EveDmv.Api.WormholeOperationsApi do
  @moduledoc """
  Ash API domain for wormhole operations resources.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    resource(EveDmv.Intelligence.HomeDefenseAnalytics)
    resource(EveDmv.Intelligence.Wormhole.FleetComposition)
    resource(EveDmv.Intelligence.Wormhole.Vetting)
  end

  authorization do
    authorize(:when_requested)
  end
end
