defmodule EveDmv.Domains.Analytics do
  @moduledoc """
  Analytics domain for player and ship statistics.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    # Analytics resources
    resource(EveDmv.Analytics.PlayerStats)
    resource(EveDmv.Analytics.ShipStats)
  end

  authorization do
    authorize(:when_requested)
  end
end
