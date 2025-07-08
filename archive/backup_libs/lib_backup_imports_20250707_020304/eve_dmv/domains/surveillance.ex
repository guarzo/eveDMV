defmodule EveDmv.Domains.Surveillance do
  use Ash.Domain,
  @moduledoc """
  Surveillance domain for profiles, matches, and notifications.
  """

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
