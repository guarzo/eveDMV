defmodule EveDmvWeb.Components.Icons do
  @moduledoc """
  SVG icon components for the EVE DMV application.

  Provides centralized icon management with consistent styling.
  """

  use Phoenix.Component

  @doc """
  Renders a search icon.
  """
  def search_icon(assigns) do
    assigns = assign_new(assigns, :class, fn -> "w-5 h-5 text-gray-400" end)

    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
    </svg>
    """
  end

  @doc """
  Renders an email icon.
  """
  def email_icon(assigns) do
    assigns = assign_new(assigns, :class, fn -> "w-5 h-5 text-gray-400" end)

    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.207" />
    </svg>
    """
  end

  @doc """
  Renders a user icon.
  """
  def user_icon(assigns) do
    assigns = assign_new(assigns, :class, fn -> "w-5 h-5 text-gray-400" end)

    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
    </svg>
    """
  end

  @doc """
  Renders an icon based on the icon type.

  ## Examples

      <.icon type={:search} />
      <.icon type={:email} class="w-4 h-4" />
  """
  attr(:type, :atom, required: true)
  attr(:class, :string, default: "w-5 h-5 text-gray-400")

  def icon(%{type: :search} = assigns), do: search_icon(assigns)
  def icon(%{type: :email} = assigns), do: email_icon(assigns)
  def icon(%{type: :user} = assigns), do: user_icon(assigns)
  def icon(assigns), do: ~H""
end
