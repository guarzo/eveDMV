defmodule SQL do
  @moduledoc """
  A simple wrapper module for SQL queries to maintain compatibility.

  This module provides a consistent interface for executing SQL queries
  through Ecto.Adapters.SQL while maintaining backward compatibility
  with existing code that references the SQL module directly.
  """

  alias Ecto.Adapters.SQL, as: EctoSQL

  @doc """
  Execute a SQL query with parameters.

  This is a wrapper around Ecto.Adapters.SQL.query/3 to maintain
  compatibility with existing code.

  ## Examples

      SQL.query(Repo, "SELECT * FROM users WHERE id = $1", [user_id])
  """
  @spec query(module(), String.t(), list()) ::
          {:ok, %{columns: [String.t()], rows: [[term()]], num_rows: non_neg_integer()}}
          | {:error, Exception.t()}
  def query(repo, sql, params) do
    EctoSQL.query(repo, sql, params)
  end

  @doc """
  Execute a SQL query with parameters and raise on error.

  This is a wrapper around Ecto.Adapters.SQL.query!/3 to maintain
  compatibility with existing code.
  """
  @spec query!(module(), String.t(), list()) ::
          %{columns: [String.t()], rows: [[term()]], num_rows: non_neg_integer()}
  def query!(repo, sql, params) do
    EctoSQL.query!(repo, sql, params)
  end
end
