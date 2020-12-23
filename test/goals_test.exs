defmodule ExLogic.GoalsTest do
  use ExUnit.Case

  require ExLogic
  import ExLogic.Goals
  alias ExLogic.{Substitution, Var}

  doctest ExLogic.Goals,
    except: [
      :moduledoc,
      call_with_fresh: 2,
      take: 2,
      take_all: 1,
      disj: 2,
      run_goal: 2,
      run_all: 1
    ]

  describe "run_goal/2 tests" do
    test "run_goal/2 works with disjunctions" do
      x = Var.new("x")

      goal =
        ExLogic.disj do
          eq(x, :olive)
          eq(x, :oil)
        end

      results = run_goal(1, goal)

      assert length(results) == 1

      [result] = results
      assert Enum.member?(Map.keys(result), x)
      assert result[x] == :olive
    end

    test "run_goal/2 works with conjunctions" do
      x = Var.new("x")

      goal =
        ExLogic.conj do
          eq(x, :olive)
          eq(x, :oil)
        end

      results = run_goal(1, goal)
      assert Enum.empty?(results)
    end

    test "run_goal/2 can return multiple results" do
      x = Var.new("x")
      y = Var.new("y")

      goal =
        ExLogic.disj do
          eq(x, :olive)
          eq(y, :oil)
        end

      results = run_goal(2, goal)

      assert length(results) == 2

      [result1, result2] = results
      assert result1[x] == :olive
      assert result2[y] == :oil
    end
  end

  describe "run_all/1 tests" do
    test "run_all/1 works with disjunctions" do
      x = Var.new("x")

      goal =
        ExLogic.disj do
          eq(x, :olive)
          eq(x, :oil)
        end

      results = run_all(goal)

      assert length(results) == 2

      [result1, result2] = results
      assert Enum.member?(Map.keys(result1), x)
      assert Enum.member?(Map.keys(result2), x)
      assert result1[x] == :olive
      assert result2[x] == :oil
    end

    test "run_all/1 works with conjunctions" do
      x = Var.new("x")

      goal =
        ExLogic.conj do
          eq(x, :olive)
          eq(x, :oil)
        end

      results = run_all(goal)
      assert Enum.empty?(results)
    end
  end

  describe "call_with_fresh/2 tests" do
    test "can construct a goal with call_with_fresh/2" do
      fun = fn fruit -> eq(:plum, fruit) end
      goal = call_with_fresh("kiwi", fun)
      results = goal.(Substitution.empty_s())

      assert length(results) == 1
      [result] = results

      assert assert Enum.member?(Map.values(result), :plum)
    end
  end

  describe "take/2 tests" do
    test "takes the appropiate amount (doctest)" do
      x = Var.new("x")
      stream = [%{x => :olive}, %{x => :oil}]

      result = take(1, stream)
      assert result == [%{x => :olive}]

      result = take(2, stream)
      assert result == stream
    end
  end

  describe "take_all/1 tests" do
    test "takes all (doctest)" do
      x = Var.new("x")
      stream = [%{x => :olive}, %{x => :oil}]

      assert take_all(stream) == stream
    end
  end

  describe "disj/2 tests" do
    test "performs a correct disjunction (doctest)" do
      x = Var.new("x")
      g1 = eq(x, :olive)
      g2 = eq(x, :oil)

      g = disj(g1, g2)

      assert g.(Substitution.empty_s()) == [
               %{x => :olive},
               %{x => :oil}
             ]
    end
  end
end
