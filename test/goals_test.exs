defmodule ExLogic.GoalsTest do
  use ExUnit.Case

  require ExLogic
  import ExLogic.Goals
  alias ExLogic.Var

  doctest ExLogic.Goals,
    except: [:moduledoc, call_with_fresh: 2, take: 2, take_all: 1, conj: 2, disj: 2, run_goal: 2]

  describe "run_goal/2 tests" do
    test "run_goal/2 works with disjunctions" do
      x = Var.new("x")
      g = ExLogic.disj do
        eq(x, :olive)
        eq(x, :oil)
      end
      results = run_goal(1, g)

      assert length(results) == 1

      [result] = results
      assert Enum.member?(Map.keys(result), x)
      assert result[x] == :olive
    end
  end
end
