defmodule EveDmv.Config do
  @moduledoc """
  Centralized configuration management for EVE DMV.

  This module provides a unified interface for accessing application configuration
  with sensible defaults and environment variable overrides.
  """

  @doc """
  Get a configuration value with fallback to default.
  """
  @spec get(atom(), atom(), any()) :: any()
  def get(app, key, default \\ nil) do
    Application.get_env(app, key, default)
  end

  @doc """
  Get a nested configuration value.
  """
  @spec get_in([atom()], any()) :: any()
  def get_in(keys, default \\ nil) do
    case keys do
      [app | rest] ->
        app
        |> Application.get_env(List.first(rest), %{})
        |> get_nested(Enum.drop(rest, 1), default)

      [] ->
        default
    end
  end

  defp get_nested(config, [], _default) when is_map(config), do: config
  defp get_nested(config, [key], default) when is_map(config), do: Map.get(config, key, default)

  defp get_nested(config, [key | rest], default) when is_map(config) do
    case Map.get(config, key) do
      nil -> default
      nested -> get_nested(nested, rest, default)
    end
  end

  defp get_nested(_config, _keys, default), do: default
end
