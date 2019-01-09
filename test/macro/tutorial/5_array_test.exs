defmodule ExonerateTest.Macro.Tutorial.ArrayTest do
  use ExUnit.Case, async: true

  @moduletag :array

  @moduledoc """
  basic tests from:

  https://json-schema.org/understanding-json-schema/reference/array.html
  Literally conforms to all the tests presented in this document.
  """

  defmodule Array do
    @moduledoc """
    tests from:

    https://json-schema.org/understanding-json-schema/reference/array.html#array

    """
    import Exonerate.Macro

    defschema array: ~s({ "type": "array" })

  end

  describe "basic array type matching" do
    test "an array" do
      assert :ok = ~s([1, 2, 3, 4, 5])
      |> Jason.decode!
      |> Array.array
    end

    test "different types of values are ok" do
      assert :ok = ~s([3, "different", { "types" : "of values" }])
      |> Jason.decode!
      |> Array.array
    end

    test "object doesn't match array" do
      assert  {:mismatch,
        {ExonerateTest.Macro.Tutorial.ArrayTest.Array,
        :array,
        [%{"Not" => "an array"}]}} = Array.array(%{"Not" => "an array"})
    end
  end

  defmodule ListValidation do
    @moduledoc """
    tests from:

    https://json-schema.org/understanding-json-schema/reference/array.html#list-validation

    """
    import Exonerate.Macro

    defschema items: """
    {
      "type": "array",
      "items": {
        "type": "number"
      }
    }
    """

    defschema contains: """
    {
      "type": "array",
      "contains": {
        "type": "number"
      }
    }
    """

  end

  describe "basic array items matching" do
    test "an array of numbers" do
      assert :ok = ~s([1, 2, 3, 4, 5])
      |> Jason.decode!
      |> ListValidation.items
    end

    test "one non-number ruins the party" do
      assert  {:mismatch,
        {ExonerateTest.Macro.Tutorial.ArrayTest.ListValidation,
        :items__items,
        ["3"]}} = ListValidation.items([1, 2, "3", 4, 5])
    end

    test "an empty array passes" do
      assert :ok = ~s([])
      |> Jason.decode!
      |> ListValidation.items
    end
  end

  describe "basic array contains matching" do
    test "a single number is enough to make it pass" do
      assert :ok = ~s(["life", "universe", "everything", 42])
      |> Jason.decode!
      |> ListValidation.contains
    end

    test "it fails with no numbers" do
      assert  {:mismatch,
        {ExonerateTest.Macro.Tutorial.ArrayTest.ListValidation,
        :contains__contains,
        [["life", "universe", "everything", "forty-two"]]}}
        = ListValidation.contains(["life", "universe", "everything", "forty-two"])
    end

    test "all numbers is ok" do
      assert :ok = ~s([1, 2, 3, 4, 5])
      |> Jason.decode!
      |> ListValidation.items
    end
  end

  defmodule TupleValidation do
    @moduledoc """
    tests from:

    https://json-schema.org/understanding-json-schema/reference/array.html#tuple-validation

    """
    import Exonerate.Macro

    defschema tuple: """
    {
      "type": "array",
      "items": [
        {
          "type": "number"
        },
        {
          "type": "string"
        },
        {
          "type": "string",
          "enum": ["Street", "Avenue", "Boulevard"]
        },
        {
          "type": "string",
          "enum": ["NW", "NE", "SW", "SE"]
        }
      ]
    }
    """

    defschema tuple_noadditional: """
    {
      "type": "array",
      "items": [
        {
          "type": "number"
        },
        {
          "type": "string"
        },
        {
          "type": "string",
          "enum": ["Street", "Avenue", "Boulevard"]
        },
        {
          "type": "string",
          "enum": ["NW", "NE", "SW", "SE"]
        }
      ],
      "additionalItems": false
    }
    """
  end

  describe "tuple validation is a thing" do
    test "a single number is enough to make it pass" do
      assert :ok = ~s([1600, "Pennsylvania", "Avenue", "NW"])
      |> Jason.decode!
      |> TupleValidation.tuple
    end

    test "drive is not an acceptable street type" do
      assert  {:mismatch,
        {ExonerateTest.Macro.Tutorial.ArrayTest.TupleValidation,
        :tuple__item_2,
        ["Drive"]}}
        = TupleValidation.tuple([24, "Sussex", "Drive"])
    end

    test "address is missing a street number" do
      assert  {:mismatch,
        {ExonerateTest.Macro.Tutorial.ArrayTest.TupleValidation,
        :tuple__item_0, ["Palais de l'Élysée"]}}
        = TupleValidation.tuple(["Palais de l'Élysée"])
    end

    test "it's ok to not have all the items" do
      assert :ok = ~s([10, "Downing", "Street"])
      |> Jason.decode!
      |> TupleValidation.tuple
    end

    test "it's ok to have extra items" do
      assert :ok = ~s([1600, "Pennsylvania", "Avenue", "NW", "Washington"])
      |> Jason.decode!
      |> TupleValidation.tuple
    end
  end

  describe "tuple validation can happen with additionalProperties" do
    test "the basic still passes" do
      assert :ok = ~s([1600, "Pennsylvania", "Avenue", "NW"])
      |> Jason.decode!
      |> TupleValidation.tuple_noadditional
    end

    test "it is ok to not provide all the items" do
      assert :ok = ~s([1600, "Pennsylvania", "Avenue"])
      |> Jason.decode!
      |> TupleValidation.tuple_noadditional
    end

    test "it is not ok to provide extra items" do
      assert  {:mismatch,
      {ExonerateTest.Macro.Tutorial.ArrayTest.TupleValidation,
      :tuple_noadditional__additional_items, ["Washington"]}}
      = TupleValidation.tuple_noadditional([1600, "Pennsylvania", "Avenue", "NW", "Washington"])
    end
  end
end
