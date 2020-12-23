defmodule ExLogicTest do
  use ExUnit.Case

  import ExLogic
  alias ExLogic.{Goals, Substitution, Var}

  doctest ExLogic, except: [:moduledoc, conj: 1, disj: 1, fresh: 2, conde: 1]
  doctest ExLogic.Var

  describe "walk/2 tests" do
    test "when the first argument is not a variable, it returns it" do
      assert Substitution.walk(:value, %{}) == :value
    end
  end
end
