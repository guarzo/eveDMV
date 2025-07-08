defmodule EveDmv.Domains.Intelligence do
  use Ash.Domain,
  @moduledoc """
  Intelligence domain for specialized tactical intelligence analysis.
  Contains advanced intelligence resources that are used less frequently
  than the core CharacterStats resource which remains in the main API.
  """

    otp_app: :eve_dmv

  resources do
    # Advanced intelligence data
    resource(EveDmv.Intelligence.ChainAnalysis.ChainTopology)
    resource(EveDmv.Intelligence.SystemInhabitant)
    resource(EveDmv.Intelligence.ChainAnalysis.ChainConnection)
    resource(EveDmv.Intelligence.Wormhole.Vetting)
    resource(EveDmv.Intelligence.HomeDefenseAnalytics)
    resource(EveDmv.Intelligence.Wormhole.FleetComposition)
    resource(EveDmv.Intelligence.MemberActivityIntelligence)
  end

  authorization do
    authorize(:when_requested)
  end
end
