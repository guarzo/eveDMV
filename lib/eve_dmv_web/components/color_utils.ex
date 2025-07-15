defmodule EveDmvWeb.Components.ColorUtils do
  @moduledoc """
  Utility functions for consistent color mapping across the application.

  Provides standardized color classes for common UI elements like security levels,
  threat levels, and status indicators.
  """

  # Color mappings for consistent styling
  @security_colors %{
    highsec: "text-green-400",
    lowsec: "text-yellow-400",
    nullsec: "text-red-400",
    wormhole: "text-purple-400"
  }

  @security_bg_colors %{
    highsec: "bg-green-900/20 border-green-700",
    lowsec: "bg-yellow-900/20 border-yellow-700",
    nullsec: "bg-red-900/20 border-red-700",
    wormhole: "bg-purple-900/20 border-purple-700"
  }

  @threat_colors %{
    extreme: "text-red-500",
    very_high: "text-red-400",
    high: "text-orange-400",
    moderate: "text-yellow-400",
    low: "text-green-400",
    minimal: "text-green-500"
  }

  @threat_bg_colors %{
    extreme: "bg-red-900/20 border-red-600",
    very_high: "bg-red-800/20 border-red-500",
    high: "bg-orange-800/20 border-orange-500",
    moderate: "bg-yellow-800/20 border-yellow-500",
    low: "bg-green-800/20 border-green-500",
    minimal: "bg-green-900/20 border-green-600"
  }

  @status_colors %{
    success: "text-green-400",
    warning: "text-yellow-400",
    error: "text-red-400",
    info: "text-blue-400",
    pending: "text-gray-400"
  }

  @status_bg_colors %{
    success: "bg-green-900/20 border-green-700",
    warning: "bg-yellow-900/20 border-yellow-700",
    error: "bg-red-900/20 border-red-700",
    info: "bg-blue-900/20 border-blue-700",
    pending: "bg-gray-900/20 border-gray-700"
  }

  @connection_colors %{
    connected: "text-green-400",
    connecting: "text-yellow-400",
    disconnected: "text-red-400",
    error: "text-red-500"
  }

  @pill_variants %{
    success: "bg-green-900/20 text-green-400 border-green-700",
    warning: "bg-yellow-900/20 text-yellow-400 border-yellow-700",
    error: "bg-red-900/20 text-red-400 border-red-700",
    info: "bg-blue-900/20 text-blue-400 border-blue-700",
    pending: "bg-gray-900/20 text-gray-400 border-gray-700"
  }

  # Default colors
  @default_text_color "text-gray-400"
  @default_bg_color "bg-gray-900/20 border-gray-700"

  @doc """
  Returns consistent color classes for EVE security levels.

  ## Examples

      iex> security_color(:highsec)
      "text-green-400"
      
      iex> security_color(:nullsec)
      "text-red-400"
  """
  def security_color(security_class) do
    Map.get(@security_colors, security_class, @default_text_color)
  end

  @doc """
  Returns consistent background color classes for EVE security levels.
  """
  def security_bg_color(security_class) do
    Map.get(@security_bg_colors, security_class, @default_bg_color)
  end

  @doc """
  Returns consistent color classes for threat levels.

  ## Examples

      iex> threat_color(:extreme)
      "text-red-500"
      
      iex> threat_color(:low)
      "text-green-400"
  """
  def threat_color(threat_level) do
    Map.get(@threat_colors, threat_level, @default_text_color)
  end

  @doc """
  Returns consistent background color classes for threat levels.
  """
  def threat_bg_color(threat_level) do
    Map.get(@threat_bg_colors, threat_level, "bg-gray-800/20 border-gray-600")
  end

  @doc """
  Returns consistent color classes for status indicators.

  ## Examples

      iex> status_color(:success)
      "text-green-400"
      
      iex> status_color(:error)
      "text-red-400"
  """
  def status_color(status) do
    Map.get(@status_colors, status, @default_text_color)
  end

  @doc """
  Returns consistent background color classes for status indicators.
  """
  def status_bg_color(status) do
    Map.get(@status_bg_colors, status, @default_bg_color)
  end

  @doc """
  Returns consistent color classes for ISK values based on magnitude.

  ## Examples

      iex> isk_color(1_000_000_000)
      "text-green-400"
      
      iex> isk_color(100_000)
      "text-gray-400"
  """
  def isk_color(isk_value) when is_number(isk_value) do
    cond do
      # 10B+ ISK
      isk_value >= 10_000_000_000 -> "text-purple-400"
      # 1B+ ISK
      isk_value >= 1_000_000_000 -> "text-green-400"
      # 100M+ ISK
      isk_value >= 100_000_000 -> "text-blue-400"
      # 10M+ ISK
      isk_value >= 10_000_000 -> "text-yellow-400"
      # < 10M ISK
      true -> "text-gray-400"
    end
  end

  def isk_color(isk_value) when is_binary(isk_value) do
    case Integer.parse(isk_value) do
      {num, _} -> isk_color(num)
      :error -> "text-gray-400"
    end
  end

  def isk_color(nil), do: "text-gray-400"
  def isk_color(_invalid), do: "text-gray-400"

  @doc """
  Returns consistent color classes for efficiency percentages.

  ## Examples

      iex> efficiency_color(95)
      "text-green-400"
      
      iex> efficiency_color(30)
      "text-red-400"
  """
  def efficiency_color(efficiency) when is_number(efficiency) do
    cond do
      efficiency >= 80 -> "text-green-400"
      efficiency >= 60 -> "text-yellow-400"
      efficiency >= 40 -> "text-orange-400"
      true -> "text-red-400"
    end
  end

  def efficiency_color(efficiency) when is_binary(efficiency) do
    case Float.parse(efficiency) do
      {num, _} -> efficiency_color(num)
      :error -> "text-gray-400"
    end
  end

  def efficiency_color(nil), do: "text-gray-400"
  def efficiency_color(_invalid), do: "text-gray-400"

  @doc """
  Returns consistent color classes for connection status.

  ## Examples

      iex> connection_color(:connected)
      "text-green-400"
      
      iex> connection_color(:disconnected)
      "text-red-400"
  """
  def connection_color(status) do
    Map.get(@connection_colors, status, @default_text_color)
  end

  @doc """
  Returns consistent pill/badge styling for various states.

  ## Examples

      iex> pill_classes(:success)
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-900/20 text-green-400 border border-green-700"
  """
  def pill_classes(variant) do
    base_classes =
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border"

    variant_classes =
      Map.get(@pill_variants, variant, "bg-gray-900/20 text-gray-400 border-gray-700")

    "#{base_classes} #{variant_classes}"
  end
end
