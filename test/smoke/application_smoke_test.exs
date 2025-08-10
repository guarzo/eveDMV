defmodule EveDmv.Smoke.ApplicationSmokeTest do
  use ExUnit.Case, async: true

  describe "application startup" do
    test "application starts successfully" do
      assert Application.started_applications()
             |> Enum.map(&elem(&1, 0))
             |> Enum.member?(:eve_dmv)
    end

    test "repo is started" do
      assert Process.whereis(EveDmv.Repo) != nil
    end

    test "endpoint is started" do
      assert Process.whereis(EveDmvWeb.Endpoint) != nil
    end

    test "pubsub is started" do
      assert Process.whereis(EveDmv.PubSub) != nil
    end
  end

  describe "critical processes" do
    test "telemetry supervisor is running" do
      assert Process.whereis(EveDmvWeb.Telemetry) != nil
    end

    test "cache supervisor is running" do
      # Cache might be in different locations after reorganization
      cache_processes = [
        Process.whereis(EveDmv.Shared.Infrastructure.UnifiedCache),
        Process.whereis(EveDmv.Eve.EsiCache),
        Process.whereis(EveDmv.Platform.Cache.StaticDataCache),
        Process.whereis(EveDmv.Platform.Cache.QueryCache)
      ]

      assert Enum.any?(cache_processes, &(&1 != nil)), "No cache process found"
    end
  end

  describe "configuration" do
    test "database configuration is set" do
      config = Application.get_env(:eve_dmv, EveDmv.Repo)
      assert config != nil
      assert Keyword.get(config, :database) != nil || Keyword.get(config, :url) != nil
    end

    test "endpoint configuration is set" do
      config = Application.get_env(:eve_dmv, EveDmvWeb.Endpoint)
      assert config != nil
      assert Keyword.get(config, :url) != nil
    end

    test "environment is properly set" do
      assert Mix.env() in [:dev, :test, :prod]
    end
  end
end
