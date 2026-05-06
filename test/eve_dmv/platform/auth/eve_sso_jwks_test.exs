defmodule EveDmv.Auth.EveSsoJwksTest do
  @moduledoc """
  Tests for the EVE SSO JWKS cache. Covers cold-start, TTL hits,
  refresh-driven re-fetch, and the stale-fallback path that protects
  logins from transient JWKS upstream failures.

  These tests touch `:persistent_term`, which is global state shared
  across the whole VM. The suite is therefore `async: false` and
  resets the cache around each case.
  """

  use ExUnit.Case, async: false

  alias Assent.HTTPAdapter.HTTPResponse
  alias EveDmv.Auth.EveSsoJwks

  setup do
    EveSsoJwks.reset_cache()
    on_exit(&EveSsoJwks.reset_cache/0)
    :ok
  end

  describe "get_keys/1" do
    test "fetches and caches on cold start" do
      keys = [%{"kid" => "k1"}]
      {fun, calls} = stub([{:ok, keys}, {:ok, keys}])

      assert {:ok, ^keys} = EveSsoJwks.get_keys(http_request_fun: fun)
      assert calls.() == 1

      # Second call hits the cache, no extra fetch
      assert {:ok, ^keys} = EveSsoJwks.get_keys(http_request_fun: fun)
      assert calls.() == 1
    end

    test "refresh? bypasses TTL and re-fetches" do
      first = [%{"kid" => "k1"}]
      second = [%{"kid" => "k2"}]
      {fun, calls} = stub([{:ok, first}, {:ok, second}])

      assert {:ok, ^first} = EveSsoJwks.get_keys(http_request_fun: fun)
      assert {:ok, ^second} = EveSsoJwks.get_keys(refresh?: true, http_request_fun: fun)
      assert calls.() == 2
    end

    test "falls back to stale cache when refresh fails" do
      first = [%{"kid" => "k1"}]
      {fun, calls} = stub([{:ok, first}, {:error, :timeout}])

      assert {:ok, ^first} = EveSsoJwks.get_keys(http_request_fun: fun)

      # Refresh fails upstream, but we still get the previously cached keys.
      assert {:ok, ^first} = EveSsoJwks.get_keys(refresh?: true, http_request_fun: fun)
      assert calls.() == 2
    end

    test "cold-start fetch failure surfaces as an error" do
      {fun, _calls} = stub([{:error, :nxdomain}])

      assert {:error, :nxdomain} = EveSsoJwks.get_keys(http_request_fun: fun)
    end

    test "non-200 cold-start response surfaces as an error" do
      raw = {:ok, %HTTPResponse{status: 500, body: "server explosion"}}
      {fun, _calls} = stub_raw([raw])

      assert {:error, message} = EveSsoJwks.get_keys(http_request_fun: fun)
      assert message =~ "status 500"
    end
  end

  # ---- helpers ------------------------------------------------------------

  # `responses` is a list of `{:ok, [keys]}` or `{:error, reason}` tuples.
  # The returned function pops the next response on each call and the
  # `calls` callback returns how many times it has been invoked.
  defp stub(responses) do
    raw = Enum.map(responses, &to_http_response/1)
    stub_raw(raw)
  end

  defp stub_raw(raw_responses) do
    {:ok, agent} = Agent.start_link(fn -> {0, raw_responses} end)

    fun = fn ->
      Agent.get_and_update(agent, fn {n, [head | rest]} -> {head, {n + 1, rest}} end)
    end

    calls = fn -> Agent.get(agent, fn {n, _} -> n end) end
    {fun, calls}
  end

  defp to_http_response({:ok, keys}),
    do: {:ok, %HTTPResponse{status: 200, body: %{"keys" => keys}}}

  defp to_http_response({:error, _} = err), do: err
end
