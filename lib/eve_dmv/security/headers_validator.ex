defmodule EveDmv.Security.HeadersValidator do
  @moduledoc """
  Validates that security headers are properly configured and enforced.

  This module provides functions to test and validate that the application
  is serving the correct security headers to protect against common web
  vulnerabilities like XSS, clickjacking, and MITM attacks.
  """

  require Logger

  @doc """
  Validate security headers on a given response.

  Returns {:ok, :valid} if all required headers are present and correctly configured,
  or {:error, reasons} with a list of missing or misconfigured headers.
  """
  @spec validate_headers(map()) :: {:ok, :valid} | {:error, [String.t()]}
  def validate_headers(headers) when is_map(headers) do
    errors = []

    errors = validate_hsts(headers, errors)
    errors = validate_frame_options(headers, errors)
    errors = validate_content_type_options(headers, errors)
    errors = validate_xss_protection(headers, errors)
    errors = validate_referrer_policy(headers, errors)
    errors = validate_csp(headers, errors)

    case errors do
      [] -> {:ok, :valid}
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Test security headers by making a request to the application.

  This can be used in tests or health checks to verify headers are working.
  """
  @spec test_security_headers(String.t()) :: {:ok, :valid} | {:error, [String.t()]}
  def test_security_headers(url \\ "http://localhost:4010") do
    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{headers: headers}} ->
        header_map = Map.new(headers, fn {key, value} -> {String.downcase(key), value} end)
        validate_headers(header_map)

      {:error, reason} ->
        {:error, ["Failed to connect to application: #{inspect(reason)}"]}
    end
  end

  @doc """
  Generate a security headers report for monitoring and compliance.
  """
  @spec generate_report(String.t()) :: %{
          required(:status) => :pass | :fail,
          required(:message) => String.t(),
          required(:timestamp) => DateTime.t(),
          required(:url) => String.t(),
          optional(:errors) => [String.t()]
        }
  def generate_report(url \\ "http://localhost:4010") do
    case test_security_headers(url) do
      {:ok, :valid} ->
        %{
          status: :pass,
          message: "All security headers are properly configured",
          timestamp: DateTime.utc_now(),
          url: url
        }

      {:error, errors} ->
        %{
          status: :fail,
          errors: errors,
          message: "Security headers validation failed",
          timestamp: DateTime.utc_now(),
          url: url
        }
    end
  end

  @doc """
  Check if the application is enforcing HTTPS properly.
  """
  @spec validate_https_enforcement(String.t()) :: {:ok, :enforced} | {:error, String.t()}
  def validate_https_enforcement(base_url) do
    http_url = String.replace(base_url, "https://", "http://")

    case HTTPoison.get(http_url, [], follow_redirect: false) do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in [301, 302] ->
        {:ok, :enforced}

      {:ok, %HTTPoison.Response{status_code: 200}} ->
        {:error, "HTTP requests are not being redirected to HTTPS"}

      {:error, reason} ->
        {:error, "Failed to test HTTPS enforcement: #{inspect(reason)}"}
    end
  end

  # Private validation functions

  defp validate_hsts(headers, errors) do
    case Map.get(headers, "strict-transport-security") do
      nil ->
        ["Missing Strict-Transport-Security header" | errors]

      value ->
        if String.contains?(value, "max-age=") do
          errors
        else
          ["Invalid Strict-Transport-Security header: missing max-age" | errors]
        end
    end
  end

  defp validate_frame_options(headers, errors) do
    case Map.get(headers, "x-frame-options") do
      nil ->
        ["Missing X-Frame-Options header" | errors]

      value when value in ["DENY", "SAMEORIGIN"] ->
        errors

      value ->
        ["Invalid X-Frame-Options value: #{value}. Expected DENY or SAMEORIGIN" | errors]
    end
  end

  defp validate_content_type_options(headers, errors) do
    case Map.get(headers, "x-content-type-options") do
      "nosniff" ->
        errors

      nil ->
        ["Missing X-Content-Type-Options header" | errors]

      value ->
        ["Invalid X-Content-Type-Options value: #{value}. Expected nosniff" | errors]
    end
  end

  defp validate_xss_protection(headers, errors) do
    case Map.get(headers, "x-xss-protection") do
      nil ->
        ["Missing X-XSS-Protection header" | errors]

      value when value in ["1; mode=block", "0"] ->
        errors

      value ->
        ["Invalid X-XSS-Protection value: #{value}" | errors]
    end
  end

  defp validate_referrer_policy(headers, errors) do
    case Map.get(headers, "referrer-policy") do
      nil ->
        ["Missing Referrer-Policy header" | errors]

      value
      when value in [
             "no-referrer",
             "no-referrer-when-downgrade",
             "origin",
             "origin-when-cross-origin",
             "same-origin",
             "strict-origin",
             "strict-origin-when-cross-origin",
             "unsafe-url"
           ] ->
        errors

      value ->
        ["Invalid Referrer-Policy value: #{value}" | errors]
    end
  end

  defp validate_csp(headers, errors) do
    case Map.get(headers, "content-security-policy") do
      nil ->
        ["Missing Content-Security-Policy header" | errors]

      value ->
        if String.contains?(value, "default-src") do
          errors
        else
          ["Content-Security-Policy missing default-src directive" | errors]
        end
    end
  end

  @doc """
  Set up periodic security headers validation.

  This should be called during application startup to enable
  periodic validation of security headers.
  """
  @spec setup_periodic_validation(integer()) :: :ok
  def setup_periodic_validation(interval_minutes \\ 60) do
    interval_ms = interval_minutes * 60 * 1000

    spawn(fn ->
      # Wait for app to start
      :timer.sleep(5000)
      periodic_validation_loop(interval_ms)
    end)

    :ok
  end

  defp periodic_validation_loop(interval_ms) do
    try do
      report = generate_report()

      case report.status do
        :pass ->
          Logger.info("Security headers validation passed", %{
            timestamp: report.timestamp
          })

        :fail ->
          Logger.error("Security headers validation failed", %{
            errors: report.errors,
            timestamp: report.timestamp
          })
      end
    rescue
      error ->
        Logger.error("Error during security headers validation", %{
          error: inspect(error)
        })
    end

    :timer.sleep(interval_ms)
    periodic_validation_loop(interval_ms)
  end

  @doc """
  Create a test module for validating security headers in tests.
  """
  defmacro __using__(_opts) do
    quote do
      def test_security_headers do
        EveDmv.Security.HeadersValidator.test_security_headers()
      end

      def validate_response_headers(conn) do
        headers =
          conn.resp_headers
          |> Map.new(fn {key, value} -> {String.downcase(key), value} end)

        EveDmv.Security.HeadersValidator.validate_headers(headers)
      end
    end
  end
end
