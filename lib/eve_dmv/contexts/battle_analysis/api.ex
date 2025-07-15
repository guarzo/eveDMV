defmodule EveDmv.Contexts.BattleAnalysis.Api do
  @moduledoc """
  Ash API domain for battle analysis resources.

  This domain manages resources related to combat log analysis,
  ship fittings, and battle correlation functionality.
  """

  use Ash.Domain,
    otp_app: :eve_dmv

  resources do
    resource(EveDmv.Contexts.BattleAnalysis.Resources.CombatLog)
    resource(EveDmv.Contexts.BattleAnalysis.Resources.ShipFitting)
  end

  # Authorization configuration
  authorization do
    authorize(:when_requested)
  end
end
