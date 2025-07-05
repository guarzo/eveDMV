defmodule EveDmvWeb.SurveillanceLive.ViewHelpers do
  @moduledoc """
  View helper functions for surveillance live view templates.

  Provides formatting and display functions used in the surveillance
  interface templates.
  """

  @doc """
  Format a filter tree as pretty JSON for display.
  """
  @spec format_filter_tree(map()) :: String.t()
  def format_filter_tree(filter_tree) do
    Jason.encode!(filter_tree, pretty: true)
  end

  @doc """
  Format a datetime for display.
  """
  @spec format_datetime(DateTime.t() | nil) :: String.t()
  def format_datetime(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
      _ -> "Unknown"
    end
  end

  @doc """
  Generate a status badge for profile active state.
  """
  @spec profile_status_badge(boolean()) :: String.t()
  def profile_status_badge(is_active) do
    if is_active do
      "🟢 Active"
    else
      "🔴 Inactive"
    end
  end

  @doc """
  Format a count with appropriate plural/singular form.
  """
  @spec format_count(non_neg_integer(), String.t()) :: String.t()
  def format_count(0, singular), do: "No #{singular}s"
  def format_count(1, singular), do: "1 #{singular}"
  def format_count(count, singular), do: "#{count} #{singular}s"

  @doc """
  Generate CSS classes for profile status.
  """
  @spec profile_status_classes(boolean()) :: String.t()
  def profile_status_classes(is_active) do
    base_classes = "px-2 py-1 rounded-full text-xs font-medium"

    if is_active do
      "#{base_classes} bg-green-100 text-green-800"
    else
      "#{base_classes} bg-red-100 text-red-800"
    end
  end

  @doc """
  Truncate text to a maximum length with ellipsis.
  """
  @spec truncate_text(String.t(), non_neg_integer()) :: String.t()
  def truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      String.slice(text, 0, max_length - 3) <> "..."
    end
  end

  def truncate_text(_, _), do: ""
end
