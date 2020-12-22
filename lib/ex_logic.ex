defmodule ExLogic do
  @moduledoc """
  Implements the basic operations of miniKanren as explained in 'The Reasoned Schemer'.
  """

  alias ExLogic.{Goals, Substitution, Var}

  @type value ::
          atom()
          | number()
          | boolean()
          | String.t()
          | Var.t()
          | tuple()
          | map()
          | [value()]

  @doc """
  Takes a list of goals and performs an expansion with `ExLogic.Goals.disj/2`.

  ## Examples

      iex> x = Var.new("x")
      iex> g = disj do
      ...>   Goals.eq(x, :olive)
      ...>   Goals.eq(x, :oil)
      ...>   Goals.eq(x, :garlic)
      ...> end
      iex> g.(Substitution.empty_s)
      [
        %{#ExLogic.Var<name: "x", ...> => :garlic},
        %{#ExLogic.Var<name: "x", ...> => :olive},
        %{#ExLogic.Var<name: "x", ...> => :oil}
      ]

  """
  defmacro disj(do: body) do
    apply_goal(:disj, body)
  end

  @doc """
  Takes a list of goals and performs an expansion with `ExLogic.Goals.conj/2`.

  ## Examples

      iex> {x, y} = {Var.new("x"), Var.new("y")}
      iex> g = conj do
      ...>   Goals.eq(x, :olive)
      ...>   Goals.eq(y, x)
      ...> end
      iex> g.(Substitution.empty_s)
      [
        %{
          #ExLogic.Var<name: "x", ...> => :olive,
          #ExLogic.Var<name: "y", ...> => :olive
        }
      ]

  """
  defmacro conj(do: body) do
    apply_goal(:conj, body)
  end

  @spec apply_goal(atom(), term()) :: Macro.t()
  defp apply_goal(goal, body) do
    case body do
      {:__block__, _, [g]} ->
        quote do
          unquote(g)
        end

      {:__block__, _, [h | t]} ->
        next = {:__block__, [], t}

        quote do
          apply(ExLogic.Goals, unquote(goal), [
            unquote(h),
            ExLogic.unquote(goal)(do: unquote(next))
          ])
        end

      v ->
        quote do
          unquote(v)
        end
    end
  end

  @doc """
  Takes a list of variables and a list of goals.
  It creates fresh variables and returns the conjunction of the list of goals.

  The following expression:

      fresh([x, y, z]) do
        Goals.eq(x, :olive)
        Goals.eq(y, :oil)
        Goals.eq(z, :garlic)
      end

  is equivalent to:

      alias ExLogic.Goals

      Goals.call_with_fresh fn x ->
        Goals.call_with_fresh fn y ->
          Goals.call_with_fresh fn z ->
            conj do
              Goals.eq(x, :olive)
              Goals.eq(y, :oil)
              Goals.eq(z, :garlic)
            end
          end
        end
      end

  ## Examples

      iex> g = fresh([x, y]) do
      ...>   Goals.eq(x, :garlic)
      ...>   Goals.eq(y, :oil)
      ...> end
      iex> g.(Substitution.empty)
      [%{#ExLogic.Var<name: :x, ...> => :garlic, #ExLogic.Var<name: :y, ...> => :oil}]

  """
  defmacro fresh([], goals) do
    quote do
      ExLogic.conj(unquote(goals))
    end
  end

  defmacro fresh([h | t], goals) do
    {name, _, _} = h

    quote do
      ExLogic.Goals.call_with_fresh(unquote(name), fn unquote(h) ->
        ExLogic.fresh(unquote(t), unquote(goals))
      end)
    end
  end
end
