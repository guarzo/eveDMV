defmodule EveDmv.Core.Utils.Validation do
  @moduledoc """
  Common validation utilities to reduce duplication.

  Part of Sprint 22 Quality Standards - Code Duplication Elimination.
  """

  alias EveDmv.Core.Utils.DateTimeUtils

  @doc """
  Validate character ID format.
  """
  def valid_character_id?(id) when is_integer(id) and id > 0, do: true
  def valid_character_id?(_), do: false

  @doc """
  Validate corporation ID format.
  """
  def valid_corporation_id?(id) when is_integer(id) and id > 0, do: true
  def valid_corporation_id?(_), do: false

  @doc """
  Validate system ID format.
  """
  def valid_system_id?(id) when is_integer(id) and id > 0, do: true
  def valid_system_id?(_), do: false

  @doc """
  Validate ship type ID format.
  """
  def valid_ship_type_id?(id) when is_integer(id) and id > 0, do: true
  def valid_ship_type_id?(_), do: false

  @doc """
  Validate required parameters are present.
  """
  def validate_required(params, required_fields)
      when is_map(params) and is_list(required_fields) do
    missing =
      Enum.filter(required_fields, fn field ->
        value = Map.get(params, field) || Map.get(params, Atom.to_string(field))
        is_nil(value) or value == ""
      end)

    case missing do
      [] -> {:ok, params}
      fields -> {:error, "Missing required fields: #{Enum.join(fields, ", ")}"}
    end
  end

  @doc """
  Validate date range parameters.
  """
  def validate_date_range(start_date, end_date) do
    with {:ok, start_dt} <- parse_date(start_date),
         {:ok, end_dt} <- parse_date(end_date) do
      if DateTimeUtils.compare(start_dt, end_dt) == :lt do
        {:ok, {start_dt, end_dt}}
      else
        {:error, "Start date must be before end date"}
      end
    end
  end

  @doc """
  Parse various date formats into DateTime.
  """
  def parse_date(%DateTime{} = dt), do: {:ok, dt}

  def parse_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, dt, _} ->
        {:ok, dt}

      {:error, _} ->
        case Date.from_iso8601(date_string) do
          {:ok, date} -> {:ok, DateTime.new!(date, ~T[00:00:00], "Etc/UTC")}
          {:error, _} -> {:error, "Invalid date format"}
        end
    end
  end

  def parse_date(_), do: {:error, "Invalid date format"}

  @doc """
  Validate pagination parameters.
  """
  def validate_pagination(params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = Map.get(params, "per_page", "25") |> String.to_integer()

    cond do
      page < 1 -> {:error, "Page must be >= 1"}
      per_page < 1 -> {:error, "Per page must be >= 1"}
      per_page > 100 -> {:error, "Per page must be <= 100"}
      true -> {:ok, %{page: page, per_page: per_page}}
    end
  rescue
    ArgumentError -> {:error, "Invalid pagination parameters"}
  end

  @doc """
  Validate EVE Online killmail structure.
  """
  def validate_killmail_structure(killmail) when is_map(killmail) do
    required_fields = ["killmail_id", "killmail_time", "victim", "attackers"]

    case validate_required(killmail, required_fields) do
      {:ok, _} ->
        victim = Map.get(killmail, "victim", %{})
        attackers = Map.get(killmail, "attackers", [])

        cond do
          not is_map(victim) -> {:error, "Victim must be an object"}
          not is_list(attackers) -> {:error, "Attackers must be an array"}
          Enum.empty?(attackers) -> {:error, "At least one attacker required"}
          true -> {:ok, killmail}
        end

      error ->
        error
    end
  end

  def validate_killmail_structure(_), do: {:error, "Killmail must be an object"}
end
