defmodule ExLogic.SubstitutionTest do
  @moduledoc false
  use ExUnit.Case

  import ExLogic.Substitution
  alias ExLogic.{Var, Walk}

  doctest ExLogic.Substitution, except: [unify: 3]

  describe "walk/2 tests" do
    test "when the first argument is not a variable, it returns it" do
      assert Walk.walk(:value, %{}) == :value
    end

    test "when the first argument is a variable, it walks it recursively" do
      x = Var.new("x")
      y = Var.new("y")
      result = Walk.walk(x, %{x => y, y => 3})
      assert result == 3

      result = Walk.walk(y, %{x => 6})
      result == y
    end
  end

  describe "unify/3 tests" do
    test "returns error on non-unifiable values (doctest)" do
      assert unify(:foo, :bar, empty_s()) == :error
    end

    test "extends the substitution correctly on unifiable values (doctest)" do
      x = Var.new("x")
      y = Var.new("y")

      result = unify([x], y, %{y => [1]})
      assert result == {:ok, %{x => 1, y => [1]}}
    end
  end
end
