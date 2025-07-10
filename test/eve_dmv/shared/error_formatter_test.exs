defmodule EveDmv.Shared.ErrorFormatterTest do
  use ExUnit.Case, async: true

  alias EveDmv.Shared.ErrorFormatter

  describe "format_error/1" do
    test "formats Ecto.Changeset errors" do
      # Create a mock changeset with errors
      changeset = %Ecto.Changeset{
        errors: [
          name: {"can't be blank", [validation: :required]},
          email: {"has invalid format", [validation: :format]}
        ],
        valid?: false
      }

      result = ErrorFormatter.format_error({:error, changeset})

      assert {:error, message} = result
      assert is_binary(message)
      assert message =~ "name: can't be blank"
      assert message =~ "email: has invalid format"
    end

    test "formats binary error reasons" do
      result = ErrorFormatter.format_error({:error, "Something went wrong"})

      assert result == {:error, "Something went wrong"}
    end

    test "formats map errors with message field" do
      error = %{message: "Custom error message"}
      result = ErrorFormatter.format_error({:error, error})

      assert result == {:error, "Custom error message"}
    end

    test "formats other error types with inspect" do
      result = ErrorFormatter.format_error({:error, :invalid_operation})

      assert result == {:error, ":invalid_operation"}
    end

    test "formats complex error structures" do
      error = {:complex, :error, ["details"]}
      result = ErrorFormatter.format_error({:error, error})

      assert {:error, message} = result
      assert message =~ "{:complex, :error, [\"details\"]}"
    end

    test "handles unexpected input formats" do
      result = ErrorFormatter.format_error("not an error tuple")

      assert result == {:error, "An unexpected error occurred"}
    end

    test "handles nil input" do
      result = ErrorFormatter.format_error(nil)

      assert result == {:error, "An unexpected error occurred"}
    end

    test "handles error tuples with nil reason" do
      result = ErrorFormatter.format_error({:error, nil})

      assert result == {:error, "nil"}
    end
  end

  describe "changeset error formatting integration" do
    test "formats changeset with interpolated values" do
      # Create a changeset with interpolated error message
      changeset = %Ecto.Changeset{
        errors: [
          age: {"must be greater than %{count}", [count: 18, validation: :number]}
        ],
        valid?: false
      }

      result = ErrorFormatter.format_error({:error, changeset})

      assert {:error, message} = result
      assert message =~ "age: must be greater than 18"
    end

    test "formats changeset with multiple errors for same field" do
      changeset = %Ecto.Changeset{
        errors: [
          password: {"is too short", [validation: :length]},
          password: {"must contain special characters", [validation: :format]}
        ],
        valid?: false
      }

      result = ErrorFormatter.format_error({:error, changeset})

      assert {:error, message} = result
      assert message =~ "password:"
      # Should contain both error messages
      assert String.contains?(message, "is too short") or
               String.contains?(message, "must contain special characters")
    end

    test "formats empty changeset errors" do
      changeset = %Ecto.Changeset{
        errors: [],
        valid?: false
      }

      result = ErrorFormatter.format_error({:error, changeset})

      assert {:error, ""} = result
    end
  end

  describe "error type classification" do
    test "correctly identifies different error patterns" do
      # Test various error patterns that might be encountered
      test_cases = [
        {{:error, "string error"}, "string error"},
        {{:error, :atom_error}, ":atom_error"},
        {{:error, %{message: "map with message"}}, "map with message"},
        {{:error, %{other: "field"}}, "%{other: \"field\"}"},
        {"unexpected format", "An unexpected error occurred"}
      ]

      Enum.each(test_cases, fn {input, expected_message} ->
        {:error, actual_message} = ErrorFormatter.format_error(input)

        assert actual_message == expected_message,
               "Expected #{inspect(expected_message)} but got #{inspect(actual_message)} for input #{inspect(input)}"
      end)
    end
  end
end
