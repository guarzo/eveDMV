defmodule EveDmv.Api.WormholeOperationsApi do
  @moduledoc """
  Ash API domain for wormhole operations resources.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    resource(EveDmv.Intelligence.HomeDefenseAnalytics)
    resource(EveDmv.Contexts.WormholeOperations.Domain.Wormhole.WhFleetComposition)
    resource(EveDmv.Contexts.WormholeOperations.Domain.Wormhole.WhVetting)
  end

  authorization do
    authorize(:when_requested)
  end
end
