defmodule EveDmv.Pagination.CursorPaginator do
  @moduledoc """
  Sprint 15A: High-performance cursor-based pagination for large datasets.

  Provides stable, efficient pagination that scales to millions of records
  without OFFSET performance degradation. Uses cursor-based pagination
  with proper ordering and memory bounds.
  """

  alias EveDmv.Repo
  import Ecto.Query

  @default_page_size 50
  @max_page_size 1000

  defstruct [
    :query,
    :cursor_fields,
    :page_size,
    :after_cursor,
    :before_cursor,
    :has_next_page,
    :has_previous_page,
    :edges,
    :total_count
  ]

  @doc """
  Create a new cursor paginator.

  Options:
  - :cursor_fields - List of fields to use for cursor (default: [:id])
  - :page_size - Number of items per page (default: 50, max: 1000)
  - :after - Cursor to get items after
  - :before - Cursor to get items before
  - :include_total - Whether to count total items (expensive, default: false)
  """
  def new(query, opts \\ []) do
    cursor_fields = Keyword.get(opts, :cursor_fields, [:id])
    page_size = min(Keyword.get(opts, :page_size, @default_page_size), @max_page_size)

    %__MODULE__{
      query: query,
      cursor_fields: cursor_fields,
      page_size: page_size,
      after_cursor: Keyword.get(opts, :after),
      before_cursor: Keyword.get(opts, :before),
      has_next_page: false,
      has_previous_page: false,
      edges: [],
      total_count: if(Keyword.get(opts, :include_total, false), do: count_total(query), else: nil)
    }
  end

  @doc """
  Execute the paginated query and return results.
  """
  def paginate(%__MODULE__{} = paginator) do
    # Build the paginated query
    paginated_query = build_paginated_query(paginator)

    # Execute and get one extra record to check for next page
    limit = paginator.page_size + 1
    results = paginated_query |> limit(^limit) |> Repo.all()

    # Check if we have more results
    {items, has_next} =
      if length(results) > paginator.page_size do
        {Enum.take(results, paginator.page_size), true}
      else
        {results, false}
      end

    # Create edges with cursors
    edges = Enum.map(items, &create_edge(&1, paginator.cursor_fields))

    # Determine cursor values
    {start_cursor, end_cursor} =
      case edges do
        [] -> {nil, nil}
        _ -> {List.first(edges).cursor, List.last(edges).cursor}
      end

    %{
      paginator
      | edges: edges,
        has_next_page: has_next,
        has_previous_page: paginator.after_cursor != nil,
        after_cursor: end_cursor,
        before_cursor: start_cursor
    }
  end

  @doc """
  Get the next page using the current end cursor.
  """
  def next_page(%__MODULE__{} = paginator) do
    if paginator.has_next_page and paginator.after_cursor do
      new(paginator.query,
        cursor_fields: paginator.cursor_fields,
        page_size: paginator.page_size,
        after: paginator.after_cursor
      )
      |> paginate()
    else
      paginator
    end
  end

  @doc """
  Get the previous page using the current start cursor.
  """
  def previous_page(%__MODULE__{} = paginator) do
    if paginator.has_previous_page and paginator.before_cursor do
      new(paginator.query,
        cursor_fields: paginator.cursor_fields,
        page_size: paginator.page_size,
        before: paginator.before_cursor
      )
      |> paginate()
    else
      paginator
    end
  end

  @doc """
  Convert paginator results to a map suitable for JSON/API responses.
  """
  def to_map(%__MODULE__{} = paginator) do
    %{
      data: Enum.map(paginator.edges, & &1.node),
      page_info: %{
        has_next_page: paginator.has_next_page,
        has_previous_page: paginator.has_previous_page,
        start_cursor: paginator.before_cursor,
        end_cursor: paginator.after_cursor,
        page_size: paginator.page_size
      },
      total_count: paginator.total_count
    }
  end

  # Private functions

  defp build_paginated_query(%__MODULE__{} = paginator) do
    query = paginator.query

    # Add cursor conditions
    query =
      case {paginator.after_cursor, paginator.before_cursor} do
        {nil, nil} ->
          # First page
          query

        {after_cursor, nil} ->
          # Forward pagination
          add_after_condition(query, paginator.cursor_fields, after_cursor)

        {nil, before_cursor} ->
          # Backward pagination
          add_before_condition(query, paginator.cursor_fields, before_cursor)

        {after_cursor, before_cursor} ->
          # Range query (between cursors)
          query
          |> add_after_condition(paginator.cursor_fields, after_cursor)
          |> add_before_condition(paginator.cursor_fields, before_cursor)
      end

    # Add ordering
    add_ordering(query, paginator.cursor_fields)
  end

  defp add_after_condition(query, cursor_fields, cursor) do
    case decode_cursor(cursor) do
      {:ok, values} ->
        add_cursor_where(query, cursor_fields, values, :gt)

      {:error, _} ->
        query
    end
  end

  defp add_before_condition(query, cursor_fields, cursor) do
    case decode_cursor(cursor) do
      {:ok, values} ->
        add_cursor_where(query, cursor_fields, values, :lt)

      {:error, _} ->
        query
    end
  end

  defp add_cursor_where(query, [field], [value], operator) do
    # Single field cursor
    condition = apply_operator(field, operator, value)
    where(query, [r], ^condition)
  end

  defp add_cursor_where(query, fields, values, operator) when length(fields) == length(values) do
    # Multi-field cursor - build composite where condition
    Enum.zip(fields, values)
    |> Enum.reduce(query, fn {field, value}, acc_query ->
      condition = apply_operator(field, operator, value)
      where(acc_query, [r], ^condition)
    end)
  end

  defp apply_operator(field, :gt, value), do: dynamic([r], field(r, ^field) > ^value)
  defp apply_operator(field, :lt, value), do: dynamic([r], field(r, ^field) < ^value)

  defp add_ordering(query, cursor_fields) do
    # Add ORDER BY for all cursor fields to ensure stable pagination
    Enum.reduce(cursor_fields, query, fn field, acc_query ->
      order_by(acc_query, [r], asc: field(r, ^field))
    end)
  end

  defp create_edge(node, cursor_fields) do
    cursor_values = extract_cursor_values(node, cursor_fields)
    cursor = encode_cursor(cursor_values)

    %{
      node: node,
      cursor: cursor
    }
  end

  defp extract_cursor_values(node, cursor_fields) do
    Enum.map(cursor_fields, fn field ->
      Map.get(node, field) || Map.get(node, to_string(field))
    end)
  end

  defp encode_cursor(values) do
    values
    |> :erlang.term_to_binary()
    |> Base.url_encode64(padding: false)
  end

  defp decode_cursor(cursor) when is_binary(cursor) do
    try do
      values =
        cursor
        |> Base.url_decode64!(padding: false)
        |> :erlang.binary_to_term([:safe])

      {:ok, values}
    rescue
      _ -> {:error, :invalid_cursor}
    end
  end

  defp decode_cursor(_), do: {:error, :invalid_cursor}

  defp count_total(query) do
    # Count query without limit/offset
    query
    |> exclude(:order_by)
    |> exclude(:limit)
    |> exclude(:offset)
    |> select([r], count())
    |> Repo.one()
  end

  # Convenience functions for common use cases

  @doc """
  Paginate killmails with time-based cursor.
  """
  def paginate_killmails(opts \\ []) do
    from(k in "killmails_raw",
      select: %{
        id: k.killmail_id,
        killmail_id: k.killmail_id,
        killmail_time: k.killmail_time,
        solar_system_id: k.solar_system_id,
        victim_corporation_id: k.victim_corporation_id,
        total_value: k.total_value
      }
    )
    |> new(Keyword.merge([cursor_fields: [:killmail_time, :killmail_id]], opts))
    |> paginate()
  end

  @doc """
  Paginate corporation members with activity-based cursor.
  """
  def paginate_corporation_members(corporation_id, opts \\ []) do
    from(cms in "corporation_member_summary",
      where: cms.corporation_id == ^corporation_id,
      select: %{
        character_id: cms.character_id,
        character_name: cms.character_name,
        total_killmails: cms.total_killmails,
        kills: cms.kills,
        losses: cms.losses,
        last_seen: cms.last_seen,
        activity_rank: cms.activity_rank
      }
    )
    |> new(Keyword.merge([cursor_fields: [:activity_rank, :character_id]], opts))
    |> paginate()
  end

  @doc """
  Paginate character activity with time-based cursor.
  """
  def paginate_character_activity(character_id, opts \\ []) do
    from(p in "participants",
      join: k in "killmails_raw",
      on: p.killmail_id == k.killmail_id,
      where: p.character_id == ^character_id,
      select: %{
        killmail_id: p.killmail_id,
        killmail_time: k.killmail_time,
        is_victim: p.is_victim,
        ship_type_id: p.ship_type_id,
        solar_system_id: k.solar_system_id,
        total_value: k.total_value
      }
    )
    |> new(Keyword.merge([cursor_fields: [:killmail_time, :killmail_id]], opts))
    |> paginate()
  end

  @doc """
  Create pagination metadata for LiveView assigns.
  """
  def pagination_assigns(%__MODULE__{} = paginator) do
    %{
      items: Enum.map(paginator.edges, & &1.node),
      has_next_page: paginator.has_next_page,
      has_previous_page: paginator.has_previous_page,
      page_size: paginator.page_size,
      total_count: paginator.total_count,
      next_cursor: if(paginator.has_next_page, do: paginator.after_cursor),
      prev_cursor: if(paginator.has_previous_page, do: paginator.before_cursor)
    }
  end
end
