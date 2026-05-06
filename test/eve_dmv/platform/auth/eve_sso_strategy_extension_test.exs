defmodule EveDmv.Auth.EveSsoStrategyExtensionTest do
  @moduledoc """
  Regression test: the `EveSsoStrategyExtension` must replace the
  `:eve_sso` strategy's default `Assent.Strategy.OAuth2` with our custom
  JWT-based `EveDmv.Auth.EveSsoStrategy`. If the extension is ever
  removed (or the strategy's transformer ordering changes), this test
  fails fast instead of silently bringing back the retired
  `https://esi.evetech.net/verify/` HTTP call.
  """

  use ExUnit.Case, async: true

  alias AshAuthentication.Info
  alias EveDmv.Auth.EveSsoStrategy

  test "the :eve_sso strategy uses the custom JWT-based Assent strategy" do
    assert {:ok, strategy} = Info.strategy(EveDmv.Users.User, :eve_sso)
    assert strategy.assent_strategy == EveSsoStrategy
  end

  test "user_url is a deliberately invalid placeholder so regressions are loud" do
    assert {:ok, strategy} = Info.strategy(EveDmv.Users.User, :eve_sso)
    url = strategy.user_url
    assert is_binary(url)
    assert url =~ "invalid"
    assert url =~ "placeholder"
    refute url =~ "esi.evetech.net"
    refute url =~ "login.eveonline.com"
  end
end
