defmodule ExLogicTest do
  use ExUnit.Case
  use ExLogic

  doctest ExLogic, except: [:moduledoc, conj: 1, disj: 1, fresh: 2, conde: 1]
  doctest ExLogic.Var

  describe "walk/2 tests" do
    test "when the first argument is not a variable, it returns it" do
      assert Substitution.walk(:value, %{}) == :value
    end
  end

  describe "conj macro tests" do
    test "expands correctly (doctest)" do
      {x, y} = {Var.new("x"), Var.new("y")}

      g =
        conj do
          Goals.eq(x, :olive)
          Goals.eq(y, x)
        end

      assert g.(Substitution.empty_s()) == [
               %{
                 x => :olive,
                 y => :olive
               }
             ]
    end
  end

  describe "disj macro tests" do
    test "expands correctly (doctest)" do
      x = Var.new("x")

      g =
        disj do
          Goals.eq(x, :olive)
          Goals.eq(x, :oil)
          Goals.eq(x, :garlic)
        end

      assert g.(Substitution.empty_s()) == [
               %{x => :olive},
               %{x => :oil},
               %{x => :garlic}
             ]
    end
  end

  describe "fresh macro tests" do
    test "returns the correct conjunction (doctest)" do
      x = Var.new("x")
      y = Var.new("y")

      g =
        fresh([x, y]) do
          Goals.eq(x, :garlic)
          Goals.eq(y, :oil)
        end

      res = g.(Substitution.empty_s())
      assert [map] = res
      {var_x, value_x} = Enum.fetch!(map, 0)
      {var_y, value_y} = Enum.fetch!(map, 1)
      assert var_x.name == :x
      assert value_x == :garlic
      assert var_y.name == :y
      assert value_y == :oil
    end
  end

  describe "conde macro tests" do
    test "returns the correct disjunction of conjunctions (doctest)" do
      {x, y} = {Var.new("x"), Var.new("y")}

      g =
        conde do
          [Goals.eq(x, :garlic), Goals.eq(y, x)]
          [Goals.eq(y, :oil)]
        end

      assert g.(Substitution.empty_s()) == [
               %{
                 x => :garlic,
                 y => :garlic
               },
               %{y => :oil}
             ]
    end
  end
end
