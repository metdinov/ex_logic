defmodule ExLogic do
  @moduledoc """
  Implements the basic operations of miniKanren as explained in 'The Reasoned Schemer'.

  Conventions:
    - #s is represented as :succeed
    - #u is represented as :fail
  """

  alias ExLogic.Var

  @type value ::
          atom()
          | number()
          | boolean()
          | String.t()
          | Var.t()
          | tuple()
          | map()
          | [value()]

  @typedoc """
  We represent substitutions using a map of associations:
    %{x => y}

  where the key `x` is a variable and `y` is another variable or
  a value that may contain zero or more variables.
  """
  @type substitution :: %{required(Var.t()) => value()}

  @doc """
  The empty substitution.
  """
  @spec empty_s() :: substitution()
  def empty_s, do: %{}

  @doc """
  Walks the substitution to find the value associated with `x`.
  If the associated value is a variable, it recursively walks again.

  ## Examples

      iex> x = Var.new("x")
      iex> y = Var.new("y")
      iex> ExLogic.walk(x, %{x => y, y => 3})
      3
      iex> ExLogic.walk(:atom, %{})
      :atom
      iex> ExLogic.walk(y, %{x => 6})
      y

  """
  @spec walk(value(), substitution()) :: value()
  def walk(%Var{} = var, s) do
    case Map.fetch(s, var) do
      {:ok, %Var{} = y} -> walk(y, s)
      {:ok, value} -> value
      :error -> var
    end
  end

  def walk(value, _substitution) do
    value
  end

  @doc """
  Extends the substitution by associating the variable `x` with the value `v`.
  If doing so would introduce a cycle, it returns `:error`.

  ## Examples

      iex> {x, y, z} = {Var.new("x"), Var.new("y"), Var.new("z")}
      iex> s = %{z => x, y => z}
      iex> ExLogic.extend_s(x, y, s)
      :error
      iex> s = %{x => y}
      iex> ExLogic.extend_s(y, [z], s)
      {:ok, %{x => y, y => [z]}}

  """
  @spec extend_s(value(), value(), substitution()) :: {:ok, substitution()} | :error
  def extend_s(x, v, s) do
    if occurs?(x, v, s) do
      :error
    else
      {:ok, Map.put(s, x, v)}
    end
  end

  @doc """
  Returns true if the variable `x` occurs in `v` using the substitution `s`,
  false otherwise.

  ## Examples

      iex> x = Var.new("x")
      iex> ExLogic.occurs?(x, x, ExLogic.empty_s)
      true

      iex> y = Var.new("y")
      iex> z = Var.new("z")
      iex> ExLogic.occurs?(y, [z], %{z => y})
      true

  """
  @spec occurs?(Var.t(), value(), substitution()) :: boolean()
  def occurs?(x, v, s) do
    v = walk(v, s)

    case v do
      %Var{} -> v == x
      [h | t] -> occurs?(x, h, s) or occurs?(x, t, s)
      _ -> false
    end
  end

  @doc ~S"""
  Extends the substitution `s` with zero or more associations that would make the values
  `u` and `v` equal (≡).
  It returns `:error` if the values are not unifiable using the given substitution.

  ## Examples

      iex> ExLogic.unify(:foo, :bar, ExLogic.empty_s)
      :error

      iex> x = Var.new("x")
      iex> y = Var.new("y")
      iex> ExLogic.unify([x], y, %{y => [1]})
      {:ok, %{x => 1, y => [1]}}

  """
  @spec unify(value(), value(), substitution()) :: {:ok, substitution()} | :error
  def unify(u, v, s) do
    u = walk(u, s)
    v = walk(v, s)

    cond do
      u == v -> {:ok, s}
      var?(u) -> extend_s(u, v, s)
      var?(v) -> extend_s(v, u, s)
      is_list(u) and is_list(v) -> unify_lists(u, v, s)
      true -> :error
    end
  end

  defp var?(%Var{}), do: true
  defp var?(_), do: false

  defp unify_lists([hu | tu], [hv | tv], s) do
    case unify(hu, hv, s) do
      :error -> :error
      {:ok, s} -> unify(tu, tv, s)
    end
  end

  @doc """
  The _equals_ (≡) goal constructor.
  It returns a goal that succeeds if its arguments unify.

  ## Examples

      iex> x = Var.new("x")
      iex> g = ExLogic.eq(x, [1])
      iex> g.(%{})
      %{x => [1]}
  """
  def eq(u, v) do
    fn s ->
      case unify(u, v, s) do
        {:ok, s} -> [s]
        :error -> []
      end
    end
  end
end
