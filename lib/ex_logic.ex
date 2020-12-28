defmodule ExLogic do
  @moduledoc """
  Implements the basic operations of miniKanren as explained in 'The Reasoned Schemer'.
  """

  @type value ::
          atom()
          | number()
          | boolean()
          | String.t()
          | Var.t()
          | tuple()
          | map()
          | [value()]

  defmacro __using__(opts) do
    quote do
      import ExLogic, unquote(opts)
      import ExLogic.Goals, only: [eq: 2]
      import ExLogic.Substitution, only: [empty_s: 0]
    end
  end

  @doc """
  Takes a list of goals and performs an expansion with `ExLogic.Goals.disj/2`.

  ## Examples

      iex> x = Var.new("x")
      iex> g = disj do
      ...>   eq(x, :olive)
      ...>   eq(x, :oil)
      ...>   eq(x, :garlic)
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

  defmacro disj([]) do
    quote do
      ExLogic.Goals.succeed()
    end
  end

  defmacro disj(goals) do
    quote do
      Enum.reduce(unquote(goals), &ExLogic.Goals.disj/2)
    end
  end

  @doc """
  Takes a list of goals and performs an expansion with `ExLogic.Goals.conj/2`.

  ## Examples

      iex> {x, y} = {Var.new("x"), Var.new("y")}
      iex> g = conj do
      ...>   eq(x, :olive)
      ...>   eq(y, x)
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

  defmacro conj([]) do
    quote do
      ExLogic.Goals.succeed()
    end
  end

  defmacro conj(goals) do
    quote do
      Enum.reduce(unquote(goals), &ExLogic.Goals.conj/2)
    end
  end

  @spec apply_goal(atom(), term()) :: Macro.t()
  defp apply_goal(goal, body) do
    case body do
      {:__block__, _, [g]} ->
        quote do
          unquote(g)
        end

      {:__block__, _, [h | t]} ->
        next_block = make_block(t)

        quote do
          apply(ExLogic.Goals, unquote(goal), [
            unquote(h),
            ExLogic.unquote(goal)(do: unquote(next_block))
          ])
        end

      g ->
        quote do
          unquote(g)
        end
    end
  end

  @spec make_block(term()) :: tuple()
  defp make_block(v) do
    {:__block__, [], v}
  end

  @doc """
  Takes a list of variables and a list of goals.
  It creates fresh variables and returns the conjunction of the list of goals.

  The following expression:

      fresh([x, y, z]) do
        eq(x, :olive)
        eq(y, :oil)
        eq(z, :garlic)
      end

  is equivalent to:

      Goals.call_with_fresh fn x ->
        Goals.call_with_fresh fn y ->
          Goals.call_with_fresh fn z ->
            conj do
              eq(x, :olive)
              eq(y, :oil)
              eq(z, :garlic)
            end
          end
        end
      end

  ## Examples

      iex> g = fresh([x, y]) do
      ...>   eq(x, :garlic)
      ...>   eq(y, :oil)
      ...> end
      iex> g.(Substitution.empty_s)
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

  @doc """
  Takes a list of lists goals. It performs a disjunction of the conjunctions.

  The following expression:

      conde do
        [eq(x, :olive), eq(y, :oil)]
        [eq(x, y)]
      end

  is equivalent to:

      disj do
        conj do
          eq(x, :olive)
          eq(y, :oil)
        end
        conj do
          eq(x, y)
        end
      end

  ## Examples

      iex> {x, y} = {Var.new("x"), Var.new("y")}
      iex> g = conde do
      ...>   [eq(x, :garlic), eq(y, x)]
      ...>   [eq(y, :oil)]
      ...> end
      iex> g.(Substitution.empty)
      [
        %{
          #ExLogic.Var<name: "x", ...> => :garlic,
          #ExLogic.Var<name: "y", ...> => :garlic
        },
        %{#ExLogic.Var<name: "y", ...> => :oil}
      ]

  """
  defmacro conde(do: body) do
    case body do
      {:__block__, _, [gs]} ->
        conj_block = make_block(gs)

        quote do
          ExLogic.conj(do: unquote(conj_block))
        end

      {:__block__, _, [h | t]} ->
        next_block = make_block(t)
        conj_block = make_block(h)

        quote do
          ExLogic.Goals.disj(
            ExLogic.conj(do: unquote(conj_block)),
            ExLogic.conde(do: unquote(next_block))
          )
        end

      gs ->
        conj_block = make_block(gs)

        quote do
          ExLogic.conj(do: unquote(conj_block))
        end
    end
  end

  @doc """
  Takes a number `n`, a list of variables and a list of goals.
  It takes the `conj` of the goals given and returns a list of the first `n` reifications
  of the variables.
  If no unification is possible, an empty list is returned.

  ## Examples

      iex> run(2, [x, y]) do
      ...>   disj do
      ...>    eq(x, :olive)
      ...>    eq(y, :oil)
      ...>   end
      ...> end
      [[:olive, "_0"], ["_0", :oil]]

      iex> run(1, [x, y]) do
      ...>   eq(x, :olive)
      ...>   eq(y, x)
      ...> end
      [[:olive, :olive]]

  """
  defmacro run(n, vars, do: body) when is_list(vars) do
    goals = inject_out_goal(vars, body)

    quote do
      out_var = ExLogic.Var.new()
      reifier = ExLogic.Goals.reify(out_var)

      fresh(unquote(vars), do: unquote(goals))
      |> ExLogic.Goals.run_goal(unquote(n))
      |> Enum.map(reifier)
    end
  end

  @spec inject_out_goal(Macro.t(), Macro.t()) :: Macro.t()
  defp inject_out_goal(q_vars, {:__block__, meta, gs}) do
    out_goal =
      quote do
        ExLogic.Goals.eq(unquote({:out_var, [], __MODULE__}), unquote(q_vars))
      end

    {:__block__, meta, [out_goal | gs]}
  end

  defp inject_out_goal(q_vars, goal) do
    out_goal =
      quote do
        ExLogic.Goals.eq(unquote({:out_var, [], __MODULE__}), unquote(q_vars))
      end

    {:__block__, [], [out_goal, goal]}
  end

  @doc """
  Like `run/3` except it returns **all** posible reifications for the goals given.

  ## Examples

      iex> run_all([x, y]) do
      ...>  disj do
      ...>    eq(x, :olive)
      ...>    eq(x, :oil)
      ...>  end
      ...>  eq(y, :garlic)
      ...> end
      [[:olive, :garlic], [:oil, :garlic]]

  """
  defmacro run_all(vars, do: body) when is_list(vars) do
    goals = inject_out_goal(vars, body)

    quote do
      out_var = ExLogic.Var.new()
      reifier = ExLogic.Goals.reify(out_var)

      fresh(unquote(vars), do: unquote(goals))
      |> ExLogic.Goals.run_all()
      |> Enum.map(reifier)
    end
  end
end
