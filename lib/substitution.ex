defmodule ExLogic.Substitution do
  @moduledoc """
  We represent substitutions using a map of associations:
    %{x => y}

  where the key `x` is a variable and `y` is another variable or
  a value that may contain zero or more variables.
  """

  alias __MODULE__
  alias ExLogic.{Var, Unify, Walk}
  @type t :: %{required(Var.t()) => ExLogic.ExLogic.value()}

  @doc """
  The empty substitution.
  """
  @spec empty_s() :: Substitution.t()
  def empty_s, do: %{}

  @doc """
  Recursively walks the substitution `r` and produces a value in which
  every variable is fresh.
  """
  @spec walk_all(ExLogic.value(), Substitution.t()) :: ExLogic.value()
  def walk_all(v, r) do
    case Walk.walk(v, r) do
      # TODO: make tail recursive version
      [h | t] -> [walk_all(h, r) | walk_all(t, r)]
      v -> v
    end
  end

  @doc """
  Extends the substitution by associating the variable `x` with the value `v`.
  If doing so would introduce a cycle, it returns `:error`.

  ## Examples

      iex> {x, y, z} = {Var.new("x"), Var.new("y"), Var.new("z")}
      iex> s = %{z => x, y => z}
      iex> extend_s(x, y, s)
      :error
      iex> s = %{x => y}
      iex> extend_s(y, [z], s)
      {:ok, %{x => y, y => [z]}}

  """
  @spec extend_s(ExLogic.value(), ExLogic.value(), Substitution.t()) ::
          {:ok, Substitution.t()} | :error
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
      iex> occurs?(x, x, empty_s())
      true

      iex> y = Var.new("y")
      iex> z = Var.new("z")
      iex> occurs?(y, [z], %{z => y})
      true

  """
  @spec occurs?(Var.t(), ExLogic.value(), Substitution.t()) :: boolean()
  def occurs?(x, v, s) do
    v = Walk.walk(v, s)

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

      iex> unify(:foo, :bar, empty_s())
      :error

      iex> x = Var.new("x")
      iex> y = Var.new("y")
      iex> unify([x], y, %{y => [1]})
      {:ok, %{x => 1, y => [1]}}

  """
  @spec unify(ExLogic.value(), ExLogic.value(), Substitution.t()) ::
          {:ok, Substitution.t()} | :error
  def unify(u, v, s) do
    u = Walk.walk(u, s)
    v = Walk.walk(v, s)

    cond do
      u === v -> {:ok, s}
      var?(u) -> extend_s(u, v, s)
      var?(v) -> extend_s(v, u, s)
      true -> Unify.unify(u, v, s)
    end
  end

  defp var?(%Var{}), do: true
  defp var?(_), do: false
end
