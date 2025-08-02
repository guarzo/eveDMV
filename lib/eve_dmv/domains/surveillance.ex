defmodule EveDmv.Domains.Surveillance do
  @moduledoc """
  Surveillance domain for profiles, matches, and notifications.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    # Surveillance profiles
    resource(EveDmv.Surveillance.Profile)
    resource(EveDmv.Surveillance.ProfileMatch)
    resource(EveDmv.Surveillance.Notification)
  end

  authorization do
    authorize(:when_requested)
  end
end
