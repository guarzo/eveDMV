defmodule EveDmv.Admin.Bootstrap do
  @moduledoc """
  Handles automatic admin bootstrapping from environment variables.

  This module provides functionality to automatically promote users to admin
  status based on environment variables during application startup.

  Environment variables supported:
  - `ADMIN_BOOTSTRAP_CHARACTERS`: Comma-separated list of character names to promote
  - `ADMIN_BOOTSTRAP_CHARACTER_IDS`: Comma-separated list of character IDs to promote

  Example:
  ```bash
  ADMIN_BOOTSTRAP_CHARACTERS="John Doe,Jane Smith"
  ADMIN_BOOTSTRAP_CHARACTER_IDS="123456789,987654321"
  ```
  """

  require Logger
  alias EveDmv.Admin

  @doc """
  Bootstrap admin users from environment variables.

  This function should be called during application startup to automatically
  promote specified users to admin status.

  Returns a summary of the bootstrapping process.
  """
  def bootstrap_from_env do
    Logger.info("Starting admin bootstrapping from environment variables...")

    character_names = get_character_names_from_env()
    character_ids = get_character_ids_from_env()

    results = %{
      character_names: process_character_names(character_names),
      character_ids: process_character_ids(character_ids),
      total_processed: length(character_names) + length(character_ids)
    }

    log_bootstrap_results(results)
    results
  end

  @doc """
  Check if admin bootstrapping is configured via environment variables.
  """
  def bootstrap_configured? do
    character_names = get_character_names_from_env()
    character_ids = get_character_ids_from_env()

    length(character_names) > 0 || length(character_ids) > 0
  end

  # Private functions

  defp get_character_names_from_env do
    case System.get_env("ADMIN_BOOTSTRAP_CHARACTERS") do
      nil ->
        []

      "" ->
        []

      names_string ->
        names_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
    end
  end

  defp get_character_ids_from_env do
    case System.get_env("ADMIN_BOOTSTRAP_CHARACTER_IDS") do
      nil ->
        []

      "" ->
        []

      ids_string ->
        ids_string
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&parse_character_id/1)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp parse_character_id(id_string) do
    case Integer.parse(id_string) do
      {id, ""} when id > 0 ->
        id

      _ ->
        Logger.warning("Invalid character ID in ADMIN_BOOTSTRAP_CHARACTER_IDS: #{id_string}")
        nil
    end
  end

  defp process_character_names(character_names) do
    Enum.map(character_names, fn name ->
      case Admin.promote_user_to_admin(name) do
        {:ok, user} ->
          Logger.info(
            "✅ Successfully promoted #{user.eve_character_name} (ID: #{user.eve_character_id}) to admin"
          )

          {:ok, user}

        {:error, :user_not_found} ->
          Logger.warning(
            "❌ Character '#{name}' not found - user must log in at least once before admin promotion"
          )

          {:error, :user_not_found, name}

        {:error, reason} ->
          Logger.error("❌ Failed to promote '#{name}' to admin: #{inspect(reason)}")
          {:error, reason, name}
      end
    end)
  end

  defp process_character_ids(character_ids) do
    Enum.map(character_ids, fn id ->
      case Admin.promote_user_to_admin(id) do
        {:ok, user} ->
          Logger.info(
            "✅ Successfully promoted #{user.eve_character_name} (ID: #{user.eve_character_id}) to admin"
          )

          {:ok, user}

        {:error, :user_not_found} ->
          Logger.warning(
            "❌ Character ID #{id} not found - user must log in at least once before admin promotion"
          )

          {:error, :user_not_found, id}

        {:error, reason} ->
          Logger.error("❌ Failed to promote character ID #{id} to admin: #{inspect(reason)}")
          {:error, reason, id}
      end
    end)
  end

  defp log_bootstrap_results(results) do
    total_success = count_successful_results(results)
    total_errors = results.total_processed - total_success

    if results.total_processed == 0 do
      Logger.info("No admin bootstrap configuration found in environment variables")
    else
      Logger.info(
        "Admin bootstrap completed: #{total_success} successful, #{total_errors} failed"
      )

      if total_errors > 0 do
        Logger.warning(
          "Some admin promotions failed. Users must log in via EVE SSO at least once before they can be promoted to admin."
        )
      end
    end
  end

  defp count_successful_results(results) do
    successful_names =
      Enum.count(results.character_names, fn
        {:ok, _} -> true
        _ -> false
      end)

    successful_ids =
      Enum.count(results.character_ids, fn
        {:ok, _} -> true
        _ -> false
      end)

    successful_names + successful_ids
  end
end
