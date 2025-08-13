defmodule EveDmv.Core.Contracts.RepositoryBehaviour do
  @moduledoc """
  Behaviour for repository implementations.
  Ensures consistent interface across all repositories.
  """

  @callback get(id :: integer()) :: {:ok, struct()} | {:error, term()}
  @callback get!(id :: integer()) :: struct() | no_return()
  @callback list(opts :: keyword()) :: {:ok, [struct()]} | {:error, term()}
  @callback create(attrs :: map()) :: {:ok, struct()} | {:error, term()}
  @callback update(struct(), attrs :: map()) :: {:ok, struct()} | {:error, term()}
  @callback delete(struct()) :: {:ok, struct()} | {:error, term()}
  @callback count(opts :: keyword()) :: {:ok, integer()} | {:error, term()}
  @callback exists?(opts :: keyword()) :: boolean()
  @callback stream(opts :: keyword()) :: Enumerable.t()

  @doc """
  Provides default implementations for common repository functions
  """
  defmacro __using__(opts) do
    resource = Keyword.fetch!(opts, :resource)

    # Pre-expand the macro calls outside the quote block
    get_fns = __MODULE__.define_get_functions()
    list_fns = __MODULE__.define_list_functions()
    write_fns = __MODULE__.define_write_functions()
    query_fns = __MODULE__.define_query_functions()
    helper_fns = __MODULE__.define_helper_functions()

    quote do
      @behaviour EveDmv.Core.Contracts.RepositoryBehaviour
      @resource unquote(resource)

      alias EveDmv.Api
      alias EveDmv.Core.Contracts.RepositoryBehaviour
      import Ash.Query

      unquote(get_fns)
      unquote(list_fns)
      unquote(write_fns)
      unquote(query_fns)
      unquote(helper_fns)
    end
  end

  @doc false
  def define_get_functions do
    quote do
      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def get(id) do
        case Ash.get(@resource, id, domain: EveDmv.Api) do
          {:ok, record} -> {:ok, record}
          {:error, error} -> {:error, error}
        end
      end

      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def get!(id) do
        case get(id) do
          {:ok, record} -> record
          {:error, error} -> raise "Failed to get #{@resource} with id #{id}: #{inspect(error)}"
        end
      end
    end
  end

  @doc false
  def define_list_functions do
    quote do
      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def list(opts \\ []) do
        @resource
        |> new()
        |> apply_filters(Keyword.get(opts, :filters, []))
        |> apply_sorting(Keyword.get(opts, :sort, []))
        |> apply_limit(Keyword.get(opts, :limit))
        |> apply_offset(Keyword.get(opts, :offset))
        |> Ash.read(domain: EveDmv.Api)
      end

      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def stream(opts \\ []) do
        @resource
        |> new()
        |> apply_filters(Keyword.get(opts, :filters, []))
        |> apply_sorting(Keyword.get(opts, :sort, []))
        |> Ash.read!(domain: EveDmv.Api)
        |> Stream.chunk_every(Keyword.get(opts, :batch_size, 1000))
      end
    end
  end

  @doc false
  def define_write_functions do
    quote do
      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def create(attrs) do
        changeset = Ash.Changeset.for_create(@resource, :create, attrs)
        Ash.create(changeset, [], domain: EveDmv.Api)
      end

      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def update(record, attrs) do
        changeset = Ash.Changeset.for_update(record, :update, attrs)
        Ash.update(changeset, [], domain: EveDmv.Api)
      end

      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def delete(record) do
        Ash.destroy(record, domain: EveDmv.Api)
      end
    end
  end

  @doc false
  def define_query_functions do
    quote do
      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def count(opts \\ []) do
        filtered_query =
          @resource
          |> new()
          |> apply_filters(Keyword.get(opts, :filters, []))

        case Ash.count(filtered_query, domain: EveDmv.Api) do
          {:ok, count} -> {:ok, count}
          {:error, error} -> {:error, error}
        end
      end

      @impl EveDmv.Core.Contracts.RepositoryBehaviour
      def exists?(opts \\ []) do
        case count(opts) do
          {:ok, count} -> count > 0
          {:error, _} -> false
        end
      end
    end
  end

  @doc false
  def define_helper_functions do
    quote do
      # Helper functions that can be overridden
      defp apply_filters(query, []), do: query

      defp apply_filters(query, filters) do
        Enum.reduce(filters, query, fn {field, value}, q ->
          # Dynamic field filtering using Ash.Query.filter
          filter(q, [{field, value}])
        end)
      end

      defp apply_sorting(query, []), do: query

      defp apply_sorting(query, sort_fields) do
        sort(query, sort_fields)
      end

      defp apply_limit(query, nil), do: query
      defp apply_limit(query, limit_value), do: limit(query, limit_value)

      defp apply_offset(query, nil), do: query
      defp apply_offset(query, offset_value), do: offset(query, offset_value)

      defoverridable apply_filters: 2,
                     apply_sorting: 2,
                     apply_limit: 2,
                     apply_offset: 2
    end
  end
end
