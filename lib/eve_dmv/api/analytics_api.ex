defmodule EveDmv.Api.AnalyticsApi do
  @moduledoc """
  Ash API for analytics-related resources.

  This sub-API handles all analytics functionality including ship stats
  and player stats to reduce dependencies in the main API.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    resource(EveDmv.Analytics.ShipStats)
    resource(EveDmv.Analytics.PlayerStats)
  end

  authorization do
    authorize(:when_requested)
  end
end
