defmodule ExLogicTest do
  use ExUnit.Case

  import ExLogic
  alias ExLogic.Var

  doctest ExLogic
  doctest ExLogic.Var

  describe "walk/2 tests" do
    test "when the first argument is not a variable, it returns it" do
      assert ExLogic.walk(:value, %{}) == :value
    end
  end
end
