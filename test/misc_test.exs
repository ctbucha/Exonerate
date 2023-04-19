defmodule ExonerateTest.MiscTest do
  use ExUnit.Case, async: true

  require Exonerate

  Exonerate.function_from_string(:def, :utf8_string, ~s({"type": "string"}))

  Exonerate.function_from_string(
    :def,
    :non_utf8_string,
    ~s({"type": "string", "format": "binary"})
  )

  Exonerate.function_from_string(:def, :utf8_length, """
  {
    "type": "string",
    "minLength": 2,
    "maxLength": 3
  }
  """)

  Exonerate.function_from_string(
    :def,
    :non_utf8_length,
    """
    {
      "type": "string",
      "format": "binary",
      "minLength": 8,
      "maxLength": 12
    }
    """
  )

  describe "for the `string` type" do
    test "non-UTF8 string is rejected when no format is set" do
      assert :ok == utf8_string("foo 🐛")
      assert {:error, _} = utf8_string(<<255>>)
    end

    test "non-UTF8 string is accepted when format is `binary`" do
      assert :ok == non_utf8_string("foo 🐛")
      assert :ok == non_utf8_string(<<255>>)
    end

    test "string minLength and maxLength are interpreted as graphemes when no format is set" do
      assert {:error, _} = utf8_length("🐛")
      assert :ok == utf8_length("🐛🐛")
      assert :ok == utf8_length("🐛🐛🐛")
      assert {:error, _} = utf8_length("🐛🐛🐛🐛")

      assert {:error, _} = utf8_length("a")
      assert :ok == utf8_length("aa")
      assert :ok == utf8_length("aaa")
      assert {:error, _} = utf8_length("aaaa")
    end

    test "string minLength and maxLength are interpreted as bytes when `binary`" do
      assert {:error, _} = non_utf8_length("🐛")
      assert :ok == non_utf8_length("🐛🐛")
      assert :ok == non_utf8_length("🐛🐛🐛")
      assert {:error, _} = non_utf8_length("🐛🐛🐛🐛")

      assert {:error, _} = non_utf8_length("aaaa")
      assert :ok == non_utf8_length("aaaaaaaa")
      assert :ok == non_utf8_length("aaaaaaaaaaaa")
      assert {:error, _} = non_utf8_length("aaaaaaaaaaaaaaaa")
    end
  end

  Exonerate.function_from_string(
    :def,
    :minitems_contains,
    """
    {
      "minItems": 2,
      "contains": {"const": "foo"}
    }
    """
  )

  describe "array with minItems AND contains" do
    test "doesn't contain enough items" do
      assert {:error, _} = minitems_contains(["foo"])
    end

    test "dosn't contain the right item" do
      assert {:error, _} = minitems_contains(["bar", "baz"])
    end

    test "doesn't contain either the right item or enough items" do
      assert {:error, _} = minitems_contains(["bar"])
    end

    test "contains the right item and enough items" do
      assert :ok == minitems_contains(["foo", "bar"])
    end
  end

  test "items + contains/mincontains"
end
