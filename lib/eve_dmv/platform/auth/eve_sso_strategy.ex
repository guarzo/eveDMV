defmodule EveDmv.Auth.EveSsoStrategy do
  @moduledoc """
  Custom Assent strategy for EVE Online SSO v2.

  Behaves exactly like `Assent.Strategy.OAuth2` for the authorize and
  token-exchange phases, but resolves character identity by **decoding
  the access token JWT** instead of calling the legacy
  `https://esi.evetech.net/verify/` endpoint, which CCP retired.

  The JWT is verified against CCP's public JWKS at
  `https://login.eveonline.com/oauth/jwks`. The resulting user map is
  shaped to match what the legacy `/verify/` endpoint returned
  (`"CharacterID"`, `"CharacterName"`, `"Scopes"`, `"CharacterOwnerHash"`,
  `"ExpiresOn"`) so downstream code in `EveDmv.Users.User` does not need
  to change.

  ## Options

    - `:jwks_module` (test override) — module used to fetch the JWKS.
      Defaults to `EveDmv.Auth.EveSsoJwks`.
  """

  @behaviour Assent.Strategy

  alias Assent.Strategy.OAuth2

  @expected_issuers ["login.eveonline.com", "https://login.eveonline.com"]
  @expected_audience "EVE Online"

  @impl Assent.Strategy
  def authorize_url(config), do: OAuth2.authorize_url(config)

  @impl Assent.Strategy
  def callback(config, params), do: OAuth2.callback(config, params, __MODULE__)

  @doc """
  Resolves the EVE character from the access token JWT instead of calling
  CCP's retired `/verify/` endpoint.

  Invoked by `Assent.Strategy.OAuth2.callback/3` after a successful token
  exchange.
  """
  @spec fetch_user(Keyword.t(), map()) :: {:ok, map()} | {:error, term()}
  def fetch_user(config, %{"access_token" => access_token}) when is_binary(access_token) do
    jwks_module = Keyword.get(config, :jwks_module, EveDmv.Auth.EveSsoJwks)

    with {:ok, keys} <- jwks_module.get_keys(),
         {:ok, claims} <- verify_jwt(access_token, keys, jwks_module, config) do
      build_user_info(claims)
    end
  end

  def fetch_user(_config, token) do
    {:error, "EVE SSO callback returned no access_token: #{inspect(Map.keys(token))}"}
  end

  # ---- internal -----------------------------------------------------------

  defp verify_jwt(token, keys, jwks_module, config) do
    with {:ok, header} <- peek_header(token),
         {:ok, key} <- find_key(header, keys, jwks_module),
         {:ok, jwt} <- Assent.Strategy.verify_jwt(token, key, config),
         :ok <- assert_signature_verified(jwt),
         :ok <- validate_claims(jwt.claims) do
      {:ok, jwt.claims}
    end
  end

  # Decode the JWT header without verifying so we can look up the right key.
  defp peek_header(token) do
    with [encoded_header, _, _] <- String.split(token, "."),
         {:ok, json} <- Base.url_decode64(encoded_header, padding: false),
         {:ok, header} <- Jason.decode(json) do
      {:ok, header}
    else
      _ -> {:error, "Invalid JWT format in EVE SSO access token"}
    end
  end

  defp find_key(%{"kid" => kid}, keys, jwks_module) do
    case Enum.find(keys, &(Map.get(&1, "kid") == kid)) do
      nil ->
        # Possible key rotation: refresh once before giving up.
        case jwks_module.get_keys(refresh?: true) do
          {:ok, refreshed} ->
            case Enum.find(refreshed, &(Map.get(&1, "kid") == kid)) do
              nil -> {:error, "No EVE SSO JWKS key matches kid=#{inspect(kid)}"}
              key -> {:ok, key}
            end

          {:error, _} = err ->
            err
        end

      key ->
        {:ok, key}
    end
  end

  defp find_key(_header, _keys, _jwks_module),
    do: {:error, "EVE SSO access token header missing kid"}

  defp assert_signature_verified(%{verified?: true}), do: :ok
  defp assert_signature_verified(_), do: {:error, "Invalid EVE SSO access token signature"}

  defp validate_claims(claims) do
    with :ok <- validate_issuer(claims),
         :ok <- validate_audience(claims),
         :ok <- validate_expiry(claims) do
      :ok
    end
  end

  defp validate_issuer(%{"iss" => iss}) when is_binary(iss) do
    if iss in @expected_issuers do
      :ok
    else
      {:error, "EVE SSO token issuer #{inspect(iss)} not recognised"}
    end
  end

  defp validate_issuer(_), do: {:error, "EVE SSO token missing iss claim"}

  # CCP's tokens may set `aud` as a string or a list containing the
  # client_id alongside the literal "EVE Online" audience.
  defp validate_audience(%{"aud" => aud}) do
    audiences = List.wrap(aud)

    if @expected_audience in audiences do
      :ok
    else
      {:error, "EVE SSO token audience #{inspect(aud)} does not include \"EVE Online\""}
    end
  end

  defp validate_audience(_), do: {:error, "EVE SSO token missing aud claim"}

  defp validate_expiry(%{"exp" => exp}) when is_integer(exp) do
    if exp > System.system_time(:second) do
      :ok
    else
      {:error, "EVE SSO access token has expired"}
    end
  end

  defp validate_expiry(_), do: {:error, "EVE SSO token missing exp claim"}

  # The `sub` claim is shaped like `"CHARACTER:EVE:91234567"`.
  defp build_user_info(%{"sub" => sub} = claims) when is_binary(sub) do
    case parse_character_id(sub) do
      {:ok, character_id} ->
        {:ok,
         %{
           "CharacterID" => character_id,
           "CharacterName" => Map.get(claims, "name"),
           "Scopes" => normalize_scopes(Map.get(claims, "scp")),
           "CharacterOwnerHash" => Map.get(claims, "owner"),
           "ExpiresOn" => Map.get(claims, "exp")
         }}

      :error ->
        {:error, "Unrecognised EVE SSO sub claim: #{inspect(sub)}"}
    end
  end

  defp build_user_info(_), do: {:error, "EVE SSO token missing sub claim"}

  defp parse_character_id("CHARACTER:EVE:" <> id), do: parse_integer(id)
  defp parse_character_id(_), do: :error

  defp parse_integer(str) do
    case Integer.parse(str) do
      {int, ""} -> {:ok, int}
      _ -> :error
    end
  end

  defp normalize_scopes(nil), do: ""
  defp normalize_scopes(scopes) when is_binary(scopes), do: scopes
  defp normalize_scopes(scopes) when is_list(scopes), do: Enum.join(scopes, " ")
end
