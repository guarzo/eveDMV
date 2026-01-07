defmodule EveDmv.Core.Validation.ValidatorsTest do
  use ExUnit.Case, async: true

  import EveDmv.Core.Validation.Validators

  describe "validate_string/3" do
    test "accepts valid strings" do
      assert :ok = validate_string(:name, "John")
      assert :ok = validate_string(:name, "John Doe", min: 2, max: 50)
      assert :ok = validate_string(:name, "AB", min: 2)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:name, :required}} = validate_string(:name, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_string(:name, nil, allow_nil: true)
    end

    test "rejects non-string values" do
      assert {:error, {:name, :invalid_type}} = validate_string(:name, 123)
      assert {:error, {:name, :invalid_type}} = validate_string(:name, :atom)
      assert {:error, {:name, :invalid_type}} = validate_string(:name, %{})
    end

    test "rejects strings that are too short" do
      assert {:error, {:name, :too_short}} = validate_string(:name, "J", min: 2)
      assert {:error, {:name, :too_short}} = validate_string(:name, "AB", min: 3)
    end

    test "rejects strings that are too long" do
      assert {:error, {:name, :too_long}} = validate_string(:name, "ABCDEF", max: 5)
      assert {:error, {:name, :too_long}} = validate_string(:name, String.duplicate("x", 256))
    end

    test "rejects empty strings" do
      assert {:error, {:name, :empty}} = validate_string(:name, "")
      assert {:error, {:name, :empty}} = validate_string(:name, "   ")
    end

    test "trims whitespace by default" do
      assert {:error, {:name, :too_short}} = validate_string(:name, "  J  ", min: 2)
    end

    test "respects trim: false option" do
      assert :ok = validate_string(:name, "  J  ", min: 2, trim: false)
    end

    test "uses custom field name in error" do
      assert {:error, {:profile_name, :too_short}} = validate_string(:profile_name, "X", min: 2)
    end
  end

  describe "validate_positive_integer/3" do
    test "accepts positive integers" do
      assert :ok = validate_positive_integer(:id, 1)
      assert :ok = validate_positive_integer(:id, 100)
      assert :ok = validate_positive_integer(:id, 999_999_999)
    end

    test "rejects zero by default" do
      assert {:error, {:id, :must_be_positive}} = validate_positive_integer(:id, 0)
    end

    test "accepts zero when allowed" do
      assert :ok = validate_positive_integer(:id, 0, allow_zero: true)
    end

    test "rejects negative integers" do
      assert {:error, {:id, :must_be_positive}} = validate_positive_integer(:id, -1)
      assert {:error, {:id, :must_be_positive}} = validate_positive_integer(:id, -100)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:id, :required}} = validate_positive_integer(:id, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_positive_integer(:id, nil, allow_nil: true)
    end

    test "rejects non-integer values" do
      assert {:error, {:id, :invalid_type}} = validate_positive_integer(:id, 1.5)
      assert {:error, {:id, :invalid_type}} = validate_positive_integer(:id, "123")
      assert {:error, {:id, :invalid_type}} = validate_positive_integer(:id, :atom)
    end
  end

  describe "validate_non_negative_integer/3" do
    test "accepts zero and positive integers" do
      assert :ok = validate_non_negative_integer(:count, 0)
      assert :ok = validate_non_negative_integer(:count, 1)
      assert :ok = validate_non_negative_integer(:count, 100)
    end

    test "rejects negative integers" do
      assert {:error, {:count, :must_be_non_negative}} = validate_non_negative_integer(:count, -1)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:count, :required}} = validate_non_negative_integer(:count, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_non_negative_integer(:count, nil, allow_nil: true)
    end

    test "rejects non-integer values" do
      assert {:error, {:count, :invalid_type}} = validate_non_negative_integer(:count, 1.5)
    end
  end

  describe "validate_enum/4" do
    test "accepts valid enum values" do
      assert :ok = validate_enum(:status, :active, [:active, :pending, :completed])
      assert :ok = validate_enum(:status, :pending, [:active, :pending, :completed])
    end

    test "rejects invalid enum values" do
      assert {:error, {:status, :invalid_value}} =
               validate_enum(:status, :invalid, [:active, :pending])
    end

    test "rejects nil when not allowed" do
      assert {:error, {:status, :required}} = validate_enum(:status, nil, [:active, :pending])
    end

    test "accepts nil when allowed" do
      assert :ok = validate_enum(:status, nil, [:active, :pending], allow_nil: true)
    end

    test "works with string enums" do
      assert :ok = validate_enum(:type, "character", ["character", "corporation"])

      assert {:error, {:type, :invalid_value}} =
               validate_enum(:type, "invalid", ["character", "corporation"])
    end
  end

  describe "validate_required_keys/3" do
    test "accepts maps with all required keys" do
      assert :ok = validate_required_keys(:data, %{name: "x", type: "y"}, [:name, :type])
      assert :ok = validate_required_keys(:data, %{a: 1, b: 2, c: 3}, [:a, :b])
    end

    test "rejects maps missing required keys" do
      assert {:error, {:data, {:missing_keys, [:type]}}} =
               validate_required_keys(:data, %{name: "x"}, [:name, :type])

      assert {:error, {:data, {:missing_keys, [:b, :c]}}} =
               validate_required_keys(:data, %{a: 1}, [:a, :b, :c])
    end

    test "rejects non-map values" do
      assert {:error, {:data, :invalid_type}} =
               validate_required_keys(:data, "not a map", [:key])

      assert {:error, {:data, :invalid_type}} = validate_required_keys(:data, nil, [:key])
    end

    test "accepts empty required keys list" do
      assert :ok = validate_required_keys(:data, %{}, [])
    end
  end

  describe "validate_list/3" do
    test "accepts valid lists" do
      assert :ok = validate_list(:items, [1, 2, 3])
      assert :ok = validate_list(:items, [])
      assert :ok = validate_list(:items, ["a", "b"])
    end

    test "rejects lists with too few items" do
      assert {:error, {:items, :too_few_items}} = validate_list(:items, [], min: 1)
      assert {:error, {:items, :too_few_items}} = validate_list(:items, [1], min: 2)
    end

    test "rejects lists with too many items" do
      assert {:error, {:items, :too_many_items}} = validate_list(:items, [1, 2, 3], max: 2)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:items, :required}} = validate_list(:items, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_list(:items, nil, allow_nil: true)
    end

    test "rejects non-list values" do
      assert {:error, {:items, :invalid_type}} = validate_list(:items, "not a list")
      assert {:error, {:items, :invalid_type}} = validate_list(:items, %{})
    end
  end

  describe "validate_integer_list/3" do
    test "accepts lists of positive integers" do
      assert :ok = validate_integer_list(:ids, [1, 2, 3])
      assert :ok = validate_integer_list(:ids, [123_456_789])
    end

    test "accepts empty lists by default" do
      assert :ok = validate_integer_list(:ids, [])
    end

    test "rejects lists with non-positive integers" do
      assert {:error, {:ids, :invalid_items}} = validate_integer_list(:ids, [1, -1, 3])
      assert {:error, {:ids, :invalid_items}} = validate_integer_list(:ids, [0])
      assert {:error, {:ids, :invalid_items}} = validate_integer_list(:ids, [1, "2", 3])
    end

    test "rejects lists with too few items" do
      assert {:error, {:ids, :too_few_items}} = validate_integer_list(:ids, [], min: 1)
    end

    test "rejects lists with too many items" do
      assert {:error, {:ids, :too_many_items}} = validate_integer_list(:ids, [1, 2, 3], max: 2)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:ids, :required}} = validate_integer_list(:ids, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_integer_list(:ids, nil, allow_nil: true)
    end
  end

  describe "validate_boolean/3" do
    test "accepts boolean values" do
      assert :ok = validate_boolean(:active, true)
      assert :ok = validate_boolean(:active, false)
    end

    test "rejects non-boolean values" do
      assert {:error, {:active, :invalid_type}} = validate_boolean(:active, "true")
      assert {:error, {:active, :invalid_type}} = validate_boolean(:active, 1)
      assert {:error, {:active, :invalid_type}} = validate_boolean(:active, :yes)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:active, :required}} = validate_boolean(:active, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_boolean(:active, nil, allow_nil: true)
    end
  end

  describe "validate_map/3" do
    test "accepts valid maps" do
      assert :ok = validate_map(:config, %{key: "value"})
      assert :ok = validate_map(:config, %{})
    end

    test "rejects empty maps when not allowed" do
      assert {:error, {:config, :empty}} = validate_map(:config, %{}, allow_empty: false)
    end

    test "rejects non-map values" do
      assert {:error, {:config, :invalid_type}} = validate_map(:config, "not a map")
      assert {:error, {:config, :invalid_type}} = validate_map(:config, [])
    end

    test "rejects nil when not allowed" do
      assert {:error, {:config, :required}} = validate_map(:config, nil)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_map(:config, nil, allow_nil: true)
    end
  end

  describe "validate_in_range/3" do
    test "accepts values within range" do
      assert :ok = validate_in_range(:limit, 50, min: 1, max: 100)
      assert :ok = validate_in_range(:limit, 1, min: 1, max: 100)
      assert :ok = validate_in_range(:limit, 100, min: 1, max: 100)
    end

    test "rejects values below minimum" do
      assert {:error, {:limit, :out_of_range}} = validate_in_range(:limit, 0, min: 1, max: 100)
    end

    test "rejects values above maximum" do
      assert {:error, {:limit, :out_of_range}} = validate_in_range(:limit, 101, min: 1, max: 100)
    end

    test "works with only minimum" do
      assert :ok = validate_in_range(:value, 50, min: 0)
      assert {:error, {:value, :out_of_range}} = validate_in_range(:value, -1, min: 0)
    end

    test "works with only maximum" do
      assert :ok = validate_in_range(:value, 50, max: 100)
      assert {:error, {:value, :out_of_range}} = validate_in_range(:value, 101, max: 100)
    end

    test "works with floats" do
      assert :ok = validate_in_range(:ratio, 0.5, min: 0.0, max: 1.0)

      assert {:error, {:ratio, :out_of_range}} =
               validate_in_range(:ratio, 1.5, min: 0.0, max: 1.0)
    end

    test "rejects nil when not allowed" do
      assert {:error, {:limit, :required}} = validate_in_range(:limit, nil, min: 1, max: 100)
    end

    test "accepts nil when allowed" do
      assert :ok = validate_in_range(:limit, nil, min: 1, max: 100, allow_nil: true)
    end

    test "rejects non-numeric values" do
      assert {:error, {:limit, :invalid_type}} =
               validate_in_range(:limit, "50", min: 1, max: 100)
    end
  end

  describe "validate_all/1" do
    test "returns :ok when all validations pass" do
      result =
        validate_all([
          fn -> validate_string(:name, "John") end,
          fn -> validate_positive_integer(:id, 123) end,
          fn -> validate_enum(:status, :active, [:active, :pending]) end
        ])

      assert :ok = result
    end

    test "returns all errors when validations fail" do
      result =
        validate_all([
          fn -> validate_string(:name, "J", min: 2) end,
          fn -> validate_positive_integer(:id, -1) end,
          fn -> validate_enum(:status, :invalid, [:active, :pending]) end
        ])

      assert {:error, errors} = result
      assert length(errors) == 3
      assert {:name, :too_short} in errors
      assert {:id, :must_be_positive} in errors
      assert {:status, :invalid_value} in errors
    end

    test "returns empty error list as :ok" do
      assert :ok = validate_all([])
    end

    test "collects only failed validations" do
      result =
        validate_all([
          fn -> validate_string(:name, "John") end,
          fn -> validate_positive_integer(:id, -1) end,
          fn -> validate_enum(:status, :active, [:active, :pending]) end
        ])

      assert {:error, [{:id, :must_be_positive}]} = result
    end
  end

  describe "validate_options/3" do
    test "accepts valid options" do
      assert :ok = validate_options(:opts, [limit: 10, offset: 0], [:limit, :offset, :sort])
      assert :ok = validate_options(:opts, [], [:limit, :offset])
    end

    test "rejects invalid option keys" do
      assert {:error, {:opts, {:invalid_keys, [:invalid_key]}}} =
               validate_options(:opts, [invalid_key: true], [:limit, :offset])

      assert {:error, {:opts, {:invalid_keys, [:foo, :bar]}}} =
               validate_options(:opts, [foo: 1, bar: 2], [:limit])
    end

    test "rejects non-keyword list values" do
      assert {:error, {:opts, :invalid_type}} = validate_options(:opts, "not a list", [:limit])
      assert {:error, {:opts, :invalid_type}} = validate_options(:opts, %{limit: 10}, [:limit])
    end
  end

  describe "real-world usage patterns" do
    test "validates surveillance profile creation" do
      profile_data = %{
        name: "My Profile",
        user_id: 12_345,
        entity_type: :character,
        criteria: %{type: :entity}
      }

      result =
        with :ok <- validate_string(:name, profile_data[:name], min: 3, max: 100),
             :ok <- validate_positive_integer(:user_id, profile_data[:user_id]),
             :ok <-
               validate_enum(:entity_type, profile_data[:entity_type], [
                 :character,
                 :corporation,
                 :alliance
               ]),
             :ok <- validate_required_keys(:criteria, profile_data[:criteria], [:type]) do
          :ok
        end

      assert :ok = result
    end

    test "validates killmail query options" do
      opts = [limit: 50, offset: 0, min_value: 1_000_000]

      result =
        with :ok <- validate_in_range(:limit, opts[:limit], min: 1, max: 500, allow_nil: true),
             :ok <- validate_non_negative_integer(:offset, opts[:offset], allow_nil: true),
             :ok <-
               validate_non_negative_integer(:min_value, opts[:min_value], allow_nil: true) do
          :ok
        end

      assert :ok = result
    end

    test "validates character IDs for batch operations" do
      character_ids = [123_456_789, 987_654_321, 555_555_555]

      result = validate_integer_list(:character_ids, character_ids, min: 1, max: 100)

      assert :ok = result
    end
  end
end
