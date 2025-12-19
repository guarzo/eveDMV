defmodule EveDmvWeb.ErrorJSONTest do
  @moduledoc """
  Tests for the ErrorJSON module.

  Tests error rendering for JSON API responses.
  """
  use EveDmvWeb.ConnCase, async: true

  alias EveDmvWeb.ErrorJSON

  describe "render/2 for standard error codes" do
    test "renders 404" do
      result = ErrorJSON.render("404.json", %{})

      assert result == %{errors: %{detail: "Not Found"}}
    end

    test "renders 500" do
      result = ErrorJSON.render("500.json", %{})

      assert result == %{errors: %{detail: "Internal Server Error"}}
    end

    test "renders 400" do
      result = ErrorJSON.render("400.json", %{})

      assert result == %{errors: %{detail: "Bad Request"}}
    end

    test "renders 401" do
      result = ErrorJSON.render("401.json", %{})

      assert result == %{errors: %{detail: "Unauthorized"}}
    end

    test "renders 403" do
      result = ErrorJSON.render("403.json", %{})

      assert result == %{errors: %{detail: "Forbidden"}}
    end

    test "renders 405" do
      result = ErrorJSON.render("405.json", %{})

      assert result == %{errors: %{detail: "Method Not Allowed"}}
    end

    test "renders 422" do
      result = ErrorJSON.render("422.json", %{})

      # RFC 9110 updated the status text from "Unprocessable Entity" to "Unprocessable Content"
      assert result == %{errors: %{detail: "Unprocessable Content"}}
    end

    test "renders 429" do
      result = ErrorJSON.render("429.json", %{})

      assert result == %{errors: %{detail: "Too Many Requests"}}
    end

    test "renders 502" do
      result = ErrorJSON.render("502.json", %{})

      assert result == %{errors: %{detail: "Bad Gateway"}}
    end

    test "renders 503" do
      result = ErrorJSON.render("503.json", %{})

      assert result == %{errors: %{detail: "Service Unavailable"}}
    end

    test "renders 504" do
      result = ErrorJSON.render("504.json", %{})

      assert result == %{errors: %{detail: "Gateway Timeout"}}
    end
  end

  describe "render/2 structure" do
    test "always returns a map with errors key" do
      templates = ["400.json", "401.json", "404.json", "500.json"]

      Enum.each(templates, fn template ->
        result = ErrorJSON.render(template, %{})

        assert is_map(result)
        assert Map.has_key?(result, :errors)
        assert is_map(result.errors)
        assert Map.has_key?(result.errors, :detail)
        assert is_binary(result.errors.detail)
      end)
    end

    test "error detail is always a non-empty string" do
      templates = ["400.json", "404.json", "500.json"]

      Enum.each(templates, fn template ->
        result = ErrorJSON.render(template, %{})

        assert String.length(result.errors.detail) > 0
      end)
    end
  end

  describe "render/2 with assigns" do
    test "ignores additional assigns" do
      assigns = %{
        conn: %{},
        some_data: "ignored",
        more_data: 123
      }

      result = ErrorJSON.render("404.json", assigns)

      # Should still return standard error format
      assert result == %{errors: %{detail: "Not Found"}}
    end
  end

  describe "error code consistency" do
    test "4xx errors are client errors" do
      client_error_codes = [400, 401, 403, 404, 405, 422, 429]

      Enum.each(client_error_codes, fn code ->
        template = "#{code}.json"
        result = ErrorJSON.render(template, %{})

        # Client errors should have meaningful messages
        assert String.length(result.errors.detail) > 0
        refute String.contains?(result.errors.detail, "Internal")
      end)
    end

    test "5xx errors are server errors" do
      server_error_codes = [500, 502, 503, 504]

      Enum.each(server_error_codes, fn code ->
        template = "#{code}.json"
        result = ErrorJSON.render(template, %{})

        # Server errors should have meaningful messages
        assert String.length(result.errors.detail) > 0
      end)
    end
  end

  describe "render/2 error message content" do
    test "404 message indicates resource not found" do
      result = ErrorJSON.render("404.json", %{})

      assert String.contains?(result.errors.detail, "Not Found")
    end

    test "401 message indicates authentication issue" do
      result = ErrorJSON.render("401.json", %{})

      assert String.contains?(result.errors.detail, "Unauthorized")
    end

    test "403 message indicates access denied" do
      result = ErrorJSON.render("403.json", %{})

      assert String.contains?(result.errors.detail, "Forbidden")
    end

    test "500 message indicates server error" do
      result = ErrorJSON.render("500.json", %{})

      assert String.contains?(result.errors.detail, "Internal Server Error")
    end
  end

  describe "JSON serialization" do
    test "error response is JSON serializable" do
      result = ErrorJSON.render("404.json", %{})

      # Ensure it can be encoded to JSON without errors
      {:ok, json} = Jason.encode(result)
      assert is_binary(json)

      # And decoded back
      {:ok, decoded} = Jason.decode(json)
      assert decoded["errors"]["detail"] == "Not Found"
    end

    test "all standard errors are JSON serializable" do
      templates = ["400.json", "401.json", "403.json", "404.json", "500.json"]

      Enum.each(templates, fn template ->
        result = ErrorJSON.render(template, %{})

        assert {:ok, _json} = Jason.encode(result)
      end)
    end
  end
end
