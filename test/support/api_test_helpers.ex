defmodule EveDmv.ApiTestHelpers do
  @moduledoc """
  Helper functions for testing API endpoints.

  Provides utilities for:
  - Creating and authenticating with API keys
  - Authenticating with user sessions
  - Common response assertions
  - JSON response parsing
  """

  import Phoenix.ConnTest, only: [build_conn: 0]
  import Plug.Conn

  alias EveDmv.Security.ApiAuthentication

  # =============================================================================
  # Connection Builders
  # =============================================================================

  @doc """
  Build a connection with a valid API key authentication header.

  ## Options
  - `:permissions` - List of permissions for the API key (default: [])
  - `:character_id` - Character ID to associate with the key (default: random)
  - `:name` - Name for the API key (default: "test_api_key")

  ## Examples

      conn = authenticated_api_conn()
      conn = authenticated_api_conn(permissions: ["read:battles", "write:battles"])
  """
  @spec authenticated_api_conn(keyword()) :: Plug.Conn.t()
  def authenticated_api_conn(opts \\ []) do
    permissions = Keyword.get(opts, :permissions, [])
    character_id = Keyword.get(opts, :character_id, Enum.random(90_000_000..99_999_999))
    name = Keyword.get(opts, :name, "test_api_key")

    {:ok, api_key} = ApiAuthentication.create_api_key(character_id, name, permissions)

    build_conn()
    |> put_req_header("authorization", "Bearer #{api_key.api_key}")
    |> put_req_header("content-type", "application/json")
  end

  @doc """
  Build a connection with a specific API key.

  Accepts either a string API key or an API key record map.
  Useful when you need to reuse the same API key across multiple requests.
  """
  @spec conn_with_api_key(String.t() | map()) :: Plug.Conn.t()
  def conn_with_api_key(api_key)

  def conn_with_api_key(api_key) when is_binary(api_key) do
    build_conn()
    |> put_req_header("authorization", "Bearer #{api_key}")
    |> put_req_header("content-type", "application/json")
  end

  def conn_with_api_key(%{api_key: api_key}) do
    conn_with_api_key(api_key)
  end

  @doc """
  Build a connection authenticated with a user session.

  ## Options
  - `:user` - The user map/struct to authenticate as
  - `:character_id` - Character ID if no user provided (creates minimal session)
  """
  @spec authenticated_user_conn(keyword()) :: Plug.Conn.t()
  def authenticated_user_conn(opts \\ []) do
    conn = build_conn()

    case Keyword.get(opts, :user) do
      nil ->
        character_id = Keyword.get(opts, :character_id, Enum.random(90_000_000..99_999_999))
        # Use a fake user_id based on character_id for routes that check current_user_id
        fake_user_id = character_id

        conn
        |> init_test_session(%{})
        |> put_session(:eve_character_id, character_id)
        |> put_session(:eve_character_name, "Test Character #{character_id}")
        |> put_session(:current_user_id, fake_user_id)

      user ->
        conn
        |> init_test_session(%{})
        |> put_session(:eve_character_id, user.eve_character_id)
        |> put_session(:eve_character_name, user.eve_character_name)
        |> put_session(:current_user_id, user.id)
    end
  end

  @doc """
  Build a plain JSON API connection without authentication.
  """
  @spec json_conn() :: Plug.Conn.t()
  def json_conn do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
  end

  # =============================================================================
  # API Key Management
  # =============================================================================

  @doc """
  Create a test API key.

  Returns `{:ok, api_key_record}` with the full API key record.
  """
  @spec create_test_api_key(keyword()) :: {:ok, map()} | {:error, term()}
  def create_test_api_key(opts \\ []) do
    character_id = Keyword.get(opts, :character_id, Enum.random(90_000_000..99_999_999))
    name = Keyword.get(opts, :name, "test_api_key_#{System.unique_integer([:positive])}")
    permissions = Keyword.get(opts, :permissions, [])
    expires_at = Keyword.get(opts, :expires_at)

    ApiAuthentication.create_api_key(character_id, name, permissions, expires_at)
  end

  @doc """
  Create a test API key, raising on failure.
  """
  @spec create_test_api_key!(keyword()) :: map()
  def create_test_api_key!(opts \\ []) do
    case create_test_api_key(opts) do
      {:ok, api_key} -> api_key
      {:error, reason} -> raise "Failed to create test API key: #{inspect(reason)}"
    end
  end

  @doc """
  Create an expired API key for testing expiration handling.
  """
  @spec create_expired_api_key!(keyword()) :: map()
  def create_expired_api_key!(opts \\ []) do
    expires_at = DateTime.add(DateTime.utc_now(), -3600, :second)
    create_test_api_key!(Keyword.put(opts, :expires_at, expires_at))
  end

  # =============================================================================
  # Response Helpers
  # =============================================================================

  @doc """
  Parse a JSON response body.

  Returns the decoded JSON as a map with string keys.
  """
  @spec json_response_body(Plug.Conn.t()) :: map() | list()
  def json_response_body(conn) do
    conn.resp_body
    |> Jason.decode!()
  end

  @doc """
  Parse a JSON response body with atom keys.

  Uses `keys: :atoms!` to only create atoms from existing atoms.
  """
  @spec json_response_body_atoms(Plug.Conn.t()) :: map() | list()
  def json_response_body_atoms(conn) do
    conn.resp_body
    |> Jason.decode!(keys: :atoms!)
  end

  @doc """
  Get a specific field from a JSON response.
  """
  @spec get_response_field(Plug.Conn.t(), String.t() | atom()) :: term()
  def get_response_field(conn, field) when is_atom(field) do
    get_response_field(conn, to_string(field))
  end

  def get_response_field(conn, field) when is_binary(field) do
    conn
    |> json_response_body()
    |> Map.get(field)
  end

  # =============================================================================
  # Assertions
  # =============================================================================

  @doc """
  Assert that the response has a specific status code.
  """
  @spec assert_status(Plug.Conn.t(), integer()) :: Plug.Conn.t()
  def assert_status(conn, expected_status) do
    actual_status = conn.status

    if actual_status != expected_status do
      body = try_decode_body(conn)

      raise ExUnit.AssertionError,
        message: """
        Expected status #{expected_status}, got #{actual_status}
        Response body: #{inspect(body, pretty: true)}
        """
    end

    conn
  end

  @doc """
  Assert that the response contains an error with specific message.
  """
  @spec assert_error_response(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def assert_error_response(conn, expected_message) do
    body = json_response_body(conn)
    actual_message = Map.get(body, "message") || Map.get(body, "error")

    if actual_message != expected_message do
      raise ExUnit.AssertionError,
        message: """
        Expected error message "#{expected_message}", got "#{actual_message}"
        Full response: #{inspect(body, pretty: true)}
        """
    end

    conn
  end

  @doc """
  Assert that the response is a successful JSON response with data.
  """
  @spec assert_success_response(Plug.Conn.t()) :: map()
  def assert_success_response(conn) do
    assert_status(conn, 200)
    json_response_body(conn)
  end

  @doc """
  Assert that the response is a 201 Created response.
  """
  @spec assert_created_response(Plug.Conn.t()) :: map()
  def assert_created_response(conn) do
    assert_status(conn, 201)
    json_response_body(conn)
  end

  @doc """
  Assert that the response is an unauthorized (401) response.
  """
  @spec assert_unauthorized_response(Plug.Conn.t()) :: Plug.Conn.t()
  def assert_unauthorized_response(conn) do
    assert_status(conn, 401)
  end

  @doc """
  Assert that the response is a forbidden (403) response.
  """
  @spec assert_forbidden_response(Plug.Conn.t()) :: Plug.Conn.t()
  def assert_forbidden_response(conn) do
    assert_status(conn, 403)
  end

  @doc """
  Assert that the response is a not found (404) response.
  """
  @spec assert_not_found_response(Plug.Conn.t()) :: Plug.Conn.t()
  def assert_not_found_response(conn) do
    assert_status(conn, 404)
  end

  @doc """
  Assert that the response contains specific fields.
  """
  @spec assert_response_contains(Plug.Conn.t(), [atom() | String.t()]) :: map()
  def assert_response_contains(conn, fields) do
    body = json_response_body(conn)

    missing_fields =
      fields
      |> Enum.map(&to_string/1)
      |> Enum.reject(&Map.has_key?(body, &1))

    if missing_fields != [] do
      raise ExUnit.AssertionError,
        message: """
        Response missing expected fields: #{inspect(missing_fields)}
        Available fields: #{inspect(Map.keys(body))}
        """
    end

    body
  end

  @doc """
  Assert that a list response has the expected count.
  """
  @spec assert_list_count(Plug.Conn.t(), integer()) :: list()
  def assert_list_count(conn, expected_count) do
    body = json_response_body(conn)

    list =
      case body do
        %{"data" => data} when is_list(data) -> data
        data when is_list(data) -> data
        _ -> raise "Response is not a list or {data: list} structure"
      end

    actual_count = length(list)

    if actual_count != expected_count do
      raise ExUnit.AssertionError,
        message: "Expected #{expected_count} items, got #{actual_count}"
    end

    list
  end

  # =============================================================================
  # Request Helpers
  # =============================================================================

  @doc """
  Encode a map as JSON for request body.
  """
  @spec encode_body(map()) :: String.t()
  def encode_body(data), do: Jason.encode!(data)

  @doc """
  Build query params string from a map.
  """
  @spec build_query_params(map()) :: String.t()
  def build_query_params(params) when map_size(params) == 0, do: ""

  def build_query_params(params) do
    "?" <> URI.encode_query(params)
  end

  # =============================================================================
  # Private Helpers
  # =============================================================================

  defp try_decode_body(conn) do
    case Jason.decode(conn.resp_body || "") do
      {:ok, body} -> body
      {:error, _} -> conn.resp_body
    end
  end

  defp init_test_session(conn, session) do
    conn
    |> Plug.Conn.put_private(:plug_session, session)
    |> Plug.Conn.put_private(:plug_session_fetch, :done)
  end
end
