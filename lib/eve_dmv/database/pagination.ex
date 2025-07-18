defmodule EveDmv.Database.Pagination do
  @moduledoc """
  Pagination utilities for database queries.

  Provides cursor-based and offset-based pagination for large datasets.
  """

  alias EveDmv.Repo

  @default_page_size 50
  @max_page_size 200

  @doc """
  Paginate a query using offset-based pagination.

  ## Examples

      paginate_query(query, page: 2, page_size: 20)
  """
  def paginate_query(query, opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> max(1)

    page_size =
      opts
      |> Keyword.get(:page_size, @default_page_size)
      |> min(@max_page_size)
      |> max(1)

    offset = (page - 1) * page_size

    _paginated_query = """
    #{query}
    LIMIT $1 OFFSET $2
    """

    [page_size, offset]
  end

  @doc """
  Execute a paginated query and return results with metadata.
  """
  def paginated_query(base_query, params, opts \\ []) do
    page = Keyword.get(opts, :page, 1) |> max(1)

    page_size =
      opts
      |> Keyword.get(:page_size, @default_page_size)
      |> min(@max_page_size)
      |> max(1)

    offset = (page - 1) * page_size

    # Get total count
    count_query = "SELECT COUNT(*) FROM (#{base_query}) as counted"
    {:ok, %{rows: [[total_count]]}} = Repo.query(count_query, params)

    # Get paginated results
    paginated_query = """
    #{base_query}
    LIMIT #{page_size} OFFSET #{offset}
    """

    {:ok, %{rows: rows, columns: columns}} = Repo.query(paginated_query, params)

    # Calculate pagination metadata
    total_pages = ceil(total_count / page_size)
    has_next = page < total_pages
    has_prev = page > 1

    %{
      data: rows,
      columns: columns,
      pagination: %{
        page: page,
        page_size: page_size,
        total_count: total_count,
        total_pages: total_pages,
        has_next: has_next,
        has_prev: has_prev,
        next_page: if(has_next, do: page + 1, else: nil),
        prev_page: if(has_prev, do: page - 1, else: nil)
      }
    }
  end

  @doc """
  Cursor-based pagination for real-time data.

  More efficient for large datasets that change frequently.
  """
  def cursor_paginate(query, cursor_field, opts \\ []) do
    cursor = Keyword.get(opts, :cursor)

    limit =
      opts
      |> Keyword.get(:limit, @default_page_size)
      |> min(@max_page_size)

    direction = Keyword.get(opts, :direction, :desc)

    {comparison_op, order_direction} =
      case direction do
        :desc -> {"<", "DESC"}
        :asc -> {">", "ASC"}
      end

    if cursor do
      """
      #{query}
      WHERE #{cursor_field} #{comparison_op} $1
      ORDER BY #{cursor_field} #{order_direction}
      LIMIT #{limit}
      """
    else
      """
      #{query}
      ORDER BY #{cursor_field} #{order_direction}
      LIMIT #{limit}
      """
    end
  end

  @doc """
  Build pagination links for LiveView.
  """
  def build_pagination_links(current_page, total_pages, base_path) do
    # Show up to 5 page links around current page
    start_page = max(1, current_page - 2)
    end_page = min(total_pages, current_page + 2)

    pages =
      start_page..end_page
      |> Enum.map(fn page ->
        %{
          page: page,
          url: "#{base_path}?page=#{page}",
          current?: page == current_page
        }
      end)

    %{
      pages: pages,
      show_first?: start_page > 1,
      show_last?: end_page < total_pages,
      first_url: "#{base_path}?page=1",
      last_url: "#{base_path}?page=#{total_pages}",
      prev_url: if(current_page > 1, do: "#{base_path}?page=#{current_page - 1}"),
      next_url: if(current_page < total_pages, do: "#{base_path}?page=#{current_page + 1}")
    }
  end

  @doc """
  Helper to extract pagination params from LiveView params.
  """
  def parse_pagination_params(params) do
    page =
      case params["page"] do
        nil -> 1
        page_str -> String.to_integer(page_str) |> max(1)
      end

    page_size =
      case params["page_size"] do
        nil -> @default_page_size
        size_str -> String.to_integer(size_str) |> min(@max_page_size) |> max(1)
      end

    %{page: page, page_size: page_size}
  end
end
