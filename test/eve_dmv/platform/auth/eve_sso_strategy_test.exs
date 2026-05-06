defmodule EveDmv.Auth.EveSsoStrategyTest do
  @moduledoc """
  Unit tests for `EveDmv.Auth.EveSsoStrategy`, which replaces the retired
  `https://esi.evetech.net/verify/` endpoint with a JWT-based identity
  check against CCP's published JWKS.

  Tokens are signed with a locally generated RSA key, the matching
  public JWK is served through a stub JWKS module, and we confirm the
  strategy:

    * returns the legacy `/verify/`-shaped user info on the happy path
    * rejects missing/invalid signatures
    * rejects unexpected issuer/audience/expiry/sub claims
    * triggers a JWKS refresh when the `kid` is unknown
  """

  use ExUnit.Case, async: true

  alias EveDmv.Auth.EveSsoStrategy

  defmodule JwksStub do
    @moduledoc false
    # Test-only JWKS module. The keys (and a refreshed key list, if any)
    # are stashed in a per-test Agent whose pid is read from the Logger
    # metadata so we don't have to thread it through the strategy API.
    use Agent

    def start_link(initial: initial, refreshed: refreshed) do
      Agent.start_link(fn -> %{initial: initial, refreshed: refreshed, calls: []} end)
    end

    def calls(agent), do: Agent.get(agent, & &1.calls)

    def install(agent), do: Process.put(__MODULE__, agent)

    def get_keys(opts \\ []) do
      refresh? = Keyword.get(opts, :refresh?, false)
      agent = Process.get(__MODULE__) || raise "JwksStub not installed for this test"

      keys =
        Agent.get_and_update(agent, fn state ->
          new = %{state | calls: state.calls ++ [refresh?]}
          keys = if refresh?, do: state.refreshed, else: state.initial
          {keys, new}
        end)

      {:ok, keys}
    end
  end

  @character_id 91_234_567
  @character_name "Test Pilot"
  @owner_hash "abcdefg1234567890"
  @kid "test-kid-1"

  setup do
    {private_jwk, public_jwk} = generate_jwk(@kid)
    {:ok, private_jwk: private_jwk, public_jwk: public_jwk}
  end

  describe "fetch_user/2 - happy path" do
    test "returns legacy /verify/-shaped user info from a valid JWT", %{
      private_jwk: private,
      public_jwk: public
    } do
      install_jwks(initial: [public])
      token = sign_token(private, base_claims())

      assert {:ok, user_info} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert user_info["CharacterID"] == @character_id
      assert user_info["CharacterName"] == @character_name
      assert user_info["CharacterOwnerHash"] == @owner_hash
      assert user_info["Scopes"] == "publicData esi-killmails.read_killmails.v1"
      assert is_integer(user_info["ExpiresOn"])
    end

    test "accepts list-shaped audience containing \"EVE Online\"", %{
      private_jwk: private,
      public_jwk: public
    } do
      install_jwks(initial: [public])
      token = sign_token(private, Map.put(base_claims(), "aud", ["EVE Online", "client-id"]))

      assert {:ok, _} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})
    end

    test "joins list-shaped scp claim into a space-separated string", %{
      private_jwk: private,
      public_jwk: public
    } do
      install_jwks(initial: [public])
      claims = Map.put(base_claims(), "scp", ["publicData", "esi-killmails.read_killmails.v1"])
      token = sign_token(private, claims)

      assert {:ok, %{"Scopes" => "publicData esi-killmails.read_killmails.v1"}} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})
    end
  end

  describe "fetch_user/2 - validation failures" do
    test "rejects token signed with a different key", %{public_jwk: public} do
      install_jwks(initial: [public])
      {other_private, _} = generate_jwk(@kid)
      token = sign_token(other_private, base_claims())

      assert {:error, message} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert message =~ "Invalid EVE SSO access token signature"
    end

    test "rejects token with unexpected issuer", %{private_jwk: private, public_jwk: public} do
      install_jwks(initial: [public])
      token = sign_token(private, Map.put(base_claims(), "iss", "https://evil.example.com"))

      assert {:error, message} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert message =~ "issuer"
    end

    test "rejects token with audience missing \"EVE Online\"", %{
      private_jwk: private,
      public_jwk: public
    } do
      install_jwks(initial: [public])
      token = sign_token(private, Map.put(base_claims(), "aud", ["other-client-id"]))

      assert {:error, message} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert message =~ "audience"
    end

    test "rejects expired token", %{private_jwk: private, public_jwk: public} do
      install_jwks(initial: [public])
      claims = Map.put(base_claims(), "exp", System.system_time(:second) - 60)
      token = sign_token(private, claims)

      assert {:error, "EVE SSO access token has expired"} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})
    end

    test "rejects token with unparseable sub claim", %{private_jwk: private, public_jwk: public} do
      install_jwks(initial: [public])
      token = sign_token(private, Map.put(base_claims(), "sub", "ALLIANCE:EVE:1234"))

      assert {:error, message} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert message =~ "sub"
    end

    test "fails cleanly when the access_token field is missing" do
      install_jwks(initial: [])

      assert {:error, message} =
               EveSsoStrategy.fetch_user(test_config(), %{"refresh_token" => "x"})

      assert message =~ "no access_token"
    end
  end

  describe "fetch_user/2 - JWKS refresh on unknown kid" do
    test "refreshes JWKS once when initial key list misses the token's kid", %{
      private_jwk: private,
      public_jwk: public
    } do
      agent = install_jwks(initial: [], refreshed: [public])
      token = sign_token(private, base_claims())

      assert {:ok, _} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert JwksStub.calls(agent) == [false, true]
    end

    test "returns an error when the kid is missing even after refresh", %{
      private_jwk: private
    } do
      install_jwks(initial: [], refreshed: [])
      token = sign_token(private, base_claims())

      assert {:error, message} =
               EveSsoStrategy.fetch_user(test_config(), %{"access_token" => token})

      assert message =~ "No EVE SSO JWKS key matches"
    end
  end

  # ---- helpers ------------------------------------------------------------

  defp install_jwks(opts) do
    initial = Keyword.fetch!(opts, :initial)
    refreshed = Keyword.get(opts, :refreshed, initial)
    {:ok, agent} = JwksStub.start_link(initial: initial, refreshed: refreshed)
    JwksStub.install(agent)
    agent
  end

  defp test_config,
    do: [
      jwks_module: JwksStub,
      json_library: Jason,
      jwt_adapter: Assent.JWTAdapter.AssentJWT
    ]

  defp base_claims do
    %{
      "iss" => "login.eveonline.com",
      "aud" => "EVE Online",
      "sub" => "CHARACTER:EVE:#{@character_id}",
      "name" => @character_name,
      "owner" => @owner_hash,
      "scp" => "publicData esi-killmails.read_killmails.v1",
      "exp" => System.system_time(:second) + 1200,
      "iat" => System.system_time(:second)
    }
  end

  defp generate_jwk(kid) do
    rsa = JOSE.JWK.generate_key({:rsa, 2048})
    {_, public_map} = JOSE.JWK.to_public_map(rsa)
    public = Map.merge(public_map, %{"kid" => kid, "alg" => "RS256", "use" => "sig"})
    # Hand the private JWK back as a JOSE.JWK struct so we can sign with it directly.
    {%{"jose_jwk" => rsa, "kid" => kid}, public}
  end

  defp sign_token(%{"jose_jwk" => rsa, "kid" => kid}, claims) do
    {_, token} =
      rsa
      |> JOSE.JWT.sign(%{"alg" => "RS256", "kid" => kid, "typ" => "JWT"}, claims)
      |> JOSE.JWS.compact()

    token
  end
end
