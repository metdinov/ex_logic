defmodule ExLogic.SubstitutionTest do
  use ExUnit.Case

  alias ExLogic.Substitution

  doctest ExLogic.Substitution

  describe "walk/2 tests" do
    test "when the first argument is not a variable, it returns it" do
      assert Substitution.walk(:value, %{}) == :value
    end
  end
end
