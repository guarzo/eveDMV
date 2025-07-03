defmodule HTTPoisonMock do
  @moduledoc """
  HTTPoison mock for testing SSE (Server-Sent Events) producers and API calls.
  
  This mock module provides standardized response helpers for testing HTTP interactions
  in EVE DMV, particularly for the killmail pipeline's SSE producer and external API
  integrations with services like ESI, Janice, and Mutamarket.
  
  ## Usage
  
  In your test, set up expectations using Mox:
  
      test "handles successful SSE stream" do
        HTTPoisonMock
        |> expect(:get!, fn _url, _headers, _opts ->
          %HTTPoison.Response{
            status_code: 200,
            headers: [{"content-type", "text/event-stream"}],
            body: HTTPoisonMock.sse_stream_body()
          }
        end)
        
        # Test your SSE consumer
      end
  """

  @doc """
  Generate a mock SSE stream body with killmail events.
  """
  def sse_stream_body do
    """
    event: keepalive
    data: {}

    event: killmail
    data: #{mock_killmail_json()}

    event: killmail  
    data: #{mock_killmail_json()}
    """
  end

  @doc """
  Generate mock killmail JSON data for testing.
  """
  def mock_killmail_json do
    Jason.encode!(%{
      "killmail_id" => 12345,
      "killmail_time" => "2025-01-01T00:00:00Z",
      "killmail_hash" => "abc123def456",
      "solar_system_id" => 30000142,
      "victim" => %{
        "character_id" => 95465499,
        "corporation_id" => 1000001,
        "alliance_id" => 99005065,
        "ship_type_id" => 671,
        "damage_taken" => 1000
      },
      "attackers" => [
        %{
          "character_id" => 95465500,
          "corporation_id" => 1000002,
          "ship_type_id" => 17918,
          "weapon_type_id" => 2456,
          "damage_done" => 1000,
          "final_blow" => true
        }
      ]
    })
  end

  @doc """
  Generate mock ESI API response for character info.
  """
  def mock_esi_character_response(character_id \\ 95465499) do
    %HTTPoison.Response{
      status_code: 200,
      headers: [{"content-type", "application/json"}],
      body: Jason.encode!(%{
        "character_id" => character_id,
        "name" => "Test Character",
        "corporation_id" => 1000001,
        "alliance_id" => 99005065,
        "birthday" => "2010-01-01T00:00:00Z"
      })
    }
  end

  @doc """
  Generate mock ESI error response.
  """
  def mock_esi_error_response(status_code \\ 404) do
    %HTTPoison.Response{
      status_code: status_code,
      headers: [{"content-type", "application/json"}],
      body: Jason.encode!(%{
        "error" => "not found"
      })
    }
  end

  @doc """
  Generate mock Janice price check response.
  """
  def mock_janice_response do
    %HTTPoison.Response{
      status_code: 200,
      headers: [{"content-type", "application/json"}],
      body: Jason.encode!(%{
        "671" => %{
          "average" => 15000000.0,
          "highest" => 16000000.0,
          "lowest" => 14000000.0,
          "percentile" => 15500000.0
        }
      })
    }
  end

  @doc """
  Generate timeout error for testing circuit breaker behavior.
  """
  def mock_timeout_error do
    {:error, %HTTPoison.Error{reason: :timeout}}
  end

  @doc """
  Generate connection error for testing fallback behavior.
  """
  def mock_connection_error do
    {:error, %HTTPoison.Error{reason: :connect_timeout}}
  end
end
