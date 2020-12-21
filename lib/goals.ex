defmodule ExLogic.Goals do
  @moduledoc """
  Implements various goals to be used by `run` and `run_all`.
  Goals are functions that expect a substitution and return a stream
  of substitutions.

    Conventions:
    - #s is represented as succeed/0
    - #u is represented as fail/0
  """

  import ExLogic

  @type stream :: maybe_improper_list(ExLogic.substitution(), stream) | suspension()

  @type suspension :: (() -> stream())

  @type goal :: (ExLogic.substitution() -> stream())

  @doc """
  The goal that always succeeds.

  ## Examples

      iex> x = ExLogic.Var.new("x")
      iex> g = ExLogic.succeed
      iex> g.(%{x => :olive})
      [%{x => :olive}]

  """
  @spec succeed() :: goal()
  def succeed do
    fn s -> [s] end
  end

  @doc """
  The goal that always fails.

  ## Examples

      iex> x = ExLogic.Var.new("x")
      iex> g = ExLogic.fail
      iex> g.(%{x => :olive})
      []

  """
  @spec fail() :: goal()
  def fail do
    fn _ -> [] end
  end

  @doc """
  The _equals_ (≡) goal constructor.
  It returns a goal that succeeds if its arguments unify.

  ## Examples

      iex> x = ExLogic.Var.new("x")
      iex> g = ExLogic.eq(x, [1])
      iex> g.(%{})
      [%{x => [1]}]
  """
  @spec eq(ExLogic.value(), ExLogic.value()) :: goal()
  def eq(u, v) do
    fn s ->
      case unify(u, v, s) do
        {:ok, s} -> [s]
        :error -> []
      end
    end
  end

  @doc """
  The logic disjunction goal. Succeeds when `g1` or `g2` succeeds.

  ## Examples

      iex> x = ExLogic.Var.new("x")
      iex> g1 = eq(x, :olive)
      iex> g2 = eq(x, :oil)
      iex> disj(g1, g2)
      [
        %{#ExLogic.Var<name: "x", ...> => :olive},
        %{#ExLogic.Var<name: "x", ...> => :oil}
      ]

  """
  @spec disj(goal(), goal()) :: goal()
  def disj(g1, g2) do
    fn s ->
      append_stream(g1.(s), g2.(s))
    end
  end

  @spec append_stream(stream(), stream()) :: stream()
  defp append_stream([], stream2) do
    stream2
  end

  defp append_stream(suspension, stream2) when is_function(suspension) do
    fn -> append_stream(suspension.(), stream2) end
  end

  defp append_stream([h | t], stream2) do
    [h | append_stream(t, stream2)]
  end

  @doc """
  The logic conjunction goal. Succeeds when `g1` and `g2` succeed.

  ## Examples

      iex> x = ExLogic.Var.new("x")
      iex> g1 = eq(x, :olive)
      iex> g2 = eq(x, :oil)
      iex> disj(g1, g2)
      []

  """
  @spec conj(goal(), goal()) :: goal()
  def conj(g1, g2) do
    fn s ->
      append_map(g2, g1.(s))
    end
  end

  @spec append_map(goal(), stream()) :: stream()
  defp append_map(_g, []) do
    []
  end

  defp append_map(g, suspension) when is_function(suspension) do
    fn -> append_map(g, suspension.()) end
  end

  defp append_map(g, [h | t]) do
    append_stream(g.(h), append_map(g, t))
  end
end
