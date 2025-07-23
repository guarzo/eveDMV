defmodule EveDmvWeb.Components.CssUtils do
  @moduledoc """
  Common CSS utility classes to reduce repetition across templates.
  """

  @doc """
  Small gray text for secondary information.
  """
  def small_gray_text, do: "text-sm text-gray-400"

  @doc """
  Muted text for less important information.
  """
  def muted_text, do: "text-sm text-gray-500"

  @doc """
  Standard card styling for content containers.
  """
  def card_classes, do: "bg-gray-800 border border-gray-700 rounded-lg p-4"

  @doc """
  Button base classes for consistency.
  """
  def button_base, do: "px-4 py-2 rounded-md font-medium transition-colors"

  @doc """
  Primary button styling.
  """
  def primary_button, do: "#{button_base()} bg-blue-600 hover:bg-blue-700 text-white"

  @doc """
  Secondary button styling.
  """
  def secondary_button, do: "#{button_base()} bg-gray-600 hover:bg-gray-700 text-white"

  @doc """
  Input field base styling.
  """
  def input_base, do: "block w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded-md text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
end
