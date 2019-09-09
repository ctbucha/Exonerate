defmodule ExonerateTest.Tutorial.NullTest do
  use ExUnit.Case, async: true

  @moduletag :null

  @moduledoc """
  basic tests from:

  https://json-schema.org/understanding-json-schema/reference/null.html
  Literally conforms to all the tests presented in this document.
  """

  defmodule Null do
    @moduledoc """
    tests from:

    https://json-schema.org/understanding-json-schema/null.html#null
    """
    import Exonerate

    defschema null: ~s({ "type": "null" })
  end

  describe "the null test" do

    test "only matches true nulls" do
      assert :ok = Null.null(nil)
    end

    test "doesn't match not quite bools" do
      assert  {:mismatch, {"#", false}} == Null.null(false)
      assert  {:mismatch, {"#", 0}} == Null.null(0)
      assert  {:mismatch, {"#", ""}} == Null.null("")
    end
  end
end

