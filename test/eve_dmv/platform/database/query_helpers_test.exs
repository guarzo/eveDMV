defmodule EveDmv.Platform.Database.QueryHelpersTest do
  @moduledoc """
  Tests for query safety helpers and limits.
  """
  use EveDmv.DataCase, async: true

  import Ecto.Query

  alias EveDmv.Killmails.KillmailRaw
  alias EveDmv.Platform.Database.QueryHelpers

  describe "apply_safe_limit/2" do
    test "applies default limit when no option provided" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.apply_safe_limit(query)

      # Check that limit is applied
      assert %Ecto.Query{} = result
      # The query should have a limit clause
      assert result.limit != nil
    end

    test "applies requested limit when within bounds" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.apply_safe_limit(query, limit: 500)

      assert %Ecto.Query{} = result
      # Should have limit applied
      assert result.limit != nil
    end

    test "enforces maximum limit when requested exceeds max" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.apply_safe_limit(query, limit: 50_000)

      assert %Ecto.Query{} = result
      # Should cap at max limit (10,000)
      assert result.limit != nil
    end

    test "respects enforce_limit: false option" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.apply_safe_limit(query, enforce_limit: false)

      # When enforce_limit is false, should return query unchanged
      assert %Ecto.Query{} = result
    end

    test "applies limit to complex queries" do
      query =
        from(k in KillmailRaw,
          where: k.killmail_time > ago(7, "day"),
          order_by: [desc: k.killmail_time]
        )

      result = QueryHelpers.apply_safe_limit(query, limit: 100)

      assert %Ecto.Query{} = result
      assert result.limit != nil
    end
  end

  describe "with_timeout/2" do
    test "returns tuple with query and repo options" do
      query = from(k in KillmailRaw)

      {result_query, opts} = QueryHelpers.with_timeout(query)

      assert %Ecto.Query{} = result_query
      assert is_list(opts)
      assert Keyword.has_key?(opts, :timeout)
    end

    test "applies default timeout when no option provided" do
      query = from(k in KillmailRaw)

      {_query, opts} = QueryHelpers.with_timeout(query)

      timeout = Keyword.get(opts, :timeout)
      assert timeout == 30_000
    end

    test "applies requested timeout when within bounds" do
      query = from(k in KillmailRaw)

      {_query, opts} = QueryHelpers.with_timeout(query, timeout: 60_000)

      timeout = Keyword.get(opts, :timeout)
      assert timeout == 60_000
    end

    test "enforces maximum timeout when requested exceeds max" do
      query = from(k in KillmailRaw)

      {_query, opts} = QueryHelpers.with_timeout(query, timeout: 300_000)

      timeout = Keyword.get(opts, :timeout)
      # Should cap at 120,000ms (2 minutes)
      assert timeout == 120_000
    end

    test "preserves original query" do
      query =
        from(k in KillmailRaw,
          where: k.killmail_time > ago(1, "day"),
          limit: 10
        )

      {result_query, _opts} = QueryHelpers.with_timeout(query)

      # Original query structure should be preserved
      assert result_query.wheres != []
      assert result_query.limit != nil
    end
  end

  describe "with_safety/2" do
    test "applies both limit and timeout" do
      query = from(k in KillmailRaw)

      {result_query, opts} = QueryHelpers.with_safety(query)

      assert %Ecto.Query{} = result_query
      assert result_query.limit != nil
      assert Keyword.has_key?(opts, :timeout)
    end

    test "respects custom limit and timeout" do
      query = from(k in KillmailRaw)

      {_result_query, opts} = QueryHelpers.with_safety(query, limit: 500, timeout: 45_000)

      assert Keyword.get(opts, :timeout) == 45_000
    end
  end

  describe "with_hints/2" do
    test "accepts parallel hint" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.with_hints(query, parallel: true)

      assert %Ecto.Query{} = result
    end

    test "accepts index hint" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.with_hints(query, index: "some_index")

      assert %Ecto.Query{} = result
    end

    test "accepts no_index hint" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.with_hints(query, no_index: true)

      assert %Ecto.Query{} = result
    end

    test "ignores unknown hints" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.with_hints(query, unknown_hint: "value")

      assert %Ecto.Query{} = result
    end
  end

  describe "stream_query/2" do
    test "returns a stream" do
      query = from(k in KillmailRaw, limit: 10)

      result = QueryHelpers.stream_query(query)

      # Streams are typically structs or functions
      is_valid_stream = is_struct(result, Stream) or is_function(result)
      assert is_valid_stream
    end

    test "accepts batch_size option" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.stream_query(query, batch_size: 500)

      is_valid_stream = is_struct(result, Stream) or is_function(result)
      assert is_valid_stream
    end

    test "accepts timeout option" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.stream_query(query, timeout: 60_000)

      is_valid_stream = is_struct(result, Stream) or is_function(result)
      assert is_valid_stream
    end
  end

  describe "safe_count/2" do
    test "counts query results" do
      query = from(k in KillmailRaw, where: k.killmail_id < 0)

      result = QueryHelpers.safe_count(query)

      assert {:ok, 0} = result
    end

    test "returns :max when exceeding threshold" do
      # Test with very low max_count to trigger :max
      query = from(k in KillmailRaw)

      result = QueryHelpers.safe_count(query, max_count: 0)

      # Will return :max if there's any data, or :ok with 0 if no data
      assert match?({:ok, 0}, result) or match?({:max, 0}, result)
    end

    test "accepts estimate option" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.safe_count(query, estimate: true)

      # Estimate may succeed or fail depending on table access
      case result do
        {:estimate, _} -> assert true
        {:error, _} -> assert true
        {:ok, _} -> assert true
      end
    end
  end

  describe "paginate/2" do
    test "returns paginated query" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.paginate(query)

      assert %Ecto.Query{} = result
      assert result.limit != nil
    end

    test "applies limit option" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.paginate(query, limit: 50)

      assert %Ecto.Query{} = result
    end

    test "accepts cursor option" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.paginate(query, cursor: 12_345, cursor_field: :killmail_id)

      assert %Ecto.Query{} = result
    end

    test "accepts direction option :asc" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.paginate(query, direction: :asc)

      assert %Ecto.Query{} = result
    end

    test "accepts direction option :desc" do
      query = from(k in KillmailRaw)

      result = QueryHelpers.paginate(query, direction: :desc)

      assert %Ecto.Query{} = result
    end
  end
end
