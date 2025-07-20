defmodule EveDmv.Api.SurveillanceApi do
  @moduledoc """
  Ash API for surveillance-related resources.

  This sub-API handles all surveillance functionality including profiles,
  matches, and notifications to reduce dependencies in the main API.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    resource(EveDmv.Surveillance.Profile)
    resource(EveDmv.Surveillance.ProfileMatch)
    resource(EveDmv.Surveillance.Notification)
  end

  authorization do
    authorize(:when_requested)
  end
end
