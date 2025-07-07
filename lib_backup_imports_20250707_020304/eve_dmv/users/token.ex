defmodule EveDmv.Users.Token do
  use Ash.Resource,
  @moduledoc """
  AshAuthentication token resource for managing user session tokens.

  This resource is automatically used by AshAuthentication to store
  and manage authentication tokens for users.
  """

    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(EveDmv.Repo)
  end

  # The token resource automatically defines the necessary attributes and actions
  # required by AshAuthentication
end
