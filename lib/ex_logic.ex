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
        next_block = make_block(t)

        quote do
          apply(ExLogic.Goals, unquote(goal), [
            unquote(h),
            ExLogic.unquote(goal)(do: unquote(next_block))
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
        [Goals.eq(x, :olive), Goals.eq(y, :oil)]
        [Goals.eq(x, y)]
      end

  is equivalent to:

      disj do
        conj do
          Goals.eq(x, :olive)
          Goals.eq(y, :oil)
        end
        conj do
          Goals.eq(x, y)
        end
      end

  ## Examples

      iex> {x, y} = {Var.new("x"), Var.new("y")}
      iex> g = conde do
      ...>   [Goals.eq(x, :garlic), Goals.eq(y, x)]
      ...>   [Goals.eq(y, :oil)]
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

  @spec make_block(term()) :: tuple()
  defp make_block(v) do
    {:__block__, [], v}
  end

  @doc """
  Takes a number n, a list of variables and a list of goals.
  Calls fresh on the list of variables and goals, then runs the resulting goal
  to obtain n substitutions that make it succeed; finally, it returns the
  values of those substitutions.

  ## Examples

      iex> run(1, [x,y]) do
      ...>   Goals.eq(x, :olive)
      ...>   Goals.eq(y, :oil)
      ...> end
      [[:olive], [:oil]]

      iex> run(1, [x]) do
      ...>   disj do
      ...>     Goals.eq(x, :olive)
      ...>     Goals.eq(x, :oil))
      ...>   end
      ...> end
      [[:olive]]

  """
  defmacro run(n, vars, goals) do
    quote do
      g = ExLogic.fresh(unquote(vars), unquote(goals))

      Goals.run_goal(unquote(n), g)
      |> names_from_substitutions()
    end
  end

  @doc """
  Same as run, except ALL values of the substitutions that make the
  resulting goal succeed are returned.

  ## Examples

      iex> run_all([x, y])
      ...>  disj do
      ...>    Goals.eq(x, :olive)
      ...>    Goals.eq(y, :oil))
      ...>  end
      ...> end
      [[:olive], [:oil]]
  """
  defmacro run_all(vars, goals) do
    quote do
      ExLogic.fresh(unquote(vars), unquote(goals))
      |> Goals.run_all()
      |> names_from_substitutions()
    end
  end

  def names_from_substitutions(substitutions) do
    reified_vars =
      Enum.map(substitutions, fn s -> Enum.map(Map.keys(s), fn var -> Goals.reify(var) end) end)
      |> List.flatten()
      |> MapSet.new()
      |> MapSet.to_list()

    Enum.map(reified_vars, fn var -> Enum.map(substitutions, var) end)
    |> Enum.map(fn names ->
      Enum.reject(names, fn name -> not valid?(name) end)
      |> MapSet.new()
      |> MapSet.to_list()
    end)
  end

  def valid?(name) when is_binary(name) do
    not String.starts_with?(name, "_")
  end

  def valid?(_name) do
    true
  end
end
