defmodule ExLogic.Goals do
  @moduledoc """
  Implements various goals to be used by `run` and `run_all`.
  Goals are functions that expect a substitution and return a stream
  of substitutions.

    Conventions:
    - #s is represented as succeed/0
    - #u is represented as fail/0
  """

  alias ExLogic.{Substitution, Var}

  @type stream :: maybe_improper_list(Substitution.t(), stream) | suspension()

  @type suspension :: (() -> stream())

  @type goal :: (Substitution.t() -> stream())

  @doc """
  The goal that always succeeds.

  ## Examples

      iex> x = Var.new("x")
      iex> g = succeed()
      iex> result = g.(%{x => :olive})
      iex> result == [%{x => :olive}]
      true

  """
  @spec succeed() :: goal()
  def succeed do
    fn s -> [s] end
  end

  @doc """
  The goal that always fails.

  ## Examples

      iex> x = Var.new("x")
      iex> g = fail()
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

      iex> x = Var.new("x")
      iex> g = eq(x, [1])
      iex> g.(%{}) == [%{x => [1]}]
      true

  """
  @spec eq(ExLogic.value(), ExLogic.value()) :: goal()
  def eq(u, v) do
    fn s ->
      case Substitution.unify(u, v, s) do
        {:ok, s} -> [s]
        :error -> []
      end
    end
  end

  @doc """
  The logic disjunction goal. Succeeds when `g1` or `g2` succeeds.

  ## Examples

      iex> x = Var.new("x")
      iex> g1 = eq(x, :olive)
      iex> g2 = eq(x, :oil)
      iex> g = disj(g1, g2)
      iex> g.(Substitution.empty_s())
      [
        %{#Var<name: "x", ...> => :olive},
        %{#Var<name: "x", ...> => :oil}
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

      iex> x = Var.new("x")
      iex> g1 = eq(x, :olive)
      iex> g2 = eq(x, :oil)
      iex> g = conj(g1, g2)
      iex> g.(Substitution.empty_s())
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

  @doc """
  Takes a name and a function that takes a `%Var{}` and produces a goal.
  Returns a goal that has access to the variable created.

  ## Examples

      iex> f = fn fruit -> eq(:plum, fruit) end
      iex> g = call_with_fresh("kiwi", f)
      iex> g.(ExLogic.Substitution.empty_s)
      [%{#Var<name: "kiwi", ...> => :plum}]

  """
  @spec call_with_fresh(name :: String.t(), f :: (Var.t() -> goal())) :: goal()
  def call_with_fresh(name, f) do
    fn s ->
      g = f.(Var.new(name))
      g.(s)
    end
  end

  @doc """
  Takes a value `v` and produces a function that takes a substitution and reifies `v`
  using the given substitution.

  ## Examples

      iex> x = Var.new("x")
      iex> rf = reify(x)
      iex> g = disj(eq(x, :olive), eq(x, :oil))
      iex> Enum.map(g.(ExLogic.Substitution.empty_s), rf)
      [:olive, :oil]
  """
  @spec reify(ExLogic.value()) :: (Substitution.t() -> Substitution.t())
  def reify(v) do
    fn s ->
      v = Substitution.walk_all(v, s)
      r = reify_s(v, Substitution.empty_s())
      Substitution.walk_all(v, r)
    end
  end

  @doc """
  Takes a value and a substitution and produces a substitution of reified names.

  ## Examples

      iex> x = Var.new("x")
      iex> result = reify_s(x, %{x => :pear})
      iex> result == %{x => :pear}
      true

  """
  @spec reify_s(ExLogic.value(), Substitution.t()) :: Substitution.t()
  def reify_s(v, s) do
    case Substitution.walk(v, s) do
      %Var{} = v -> Map.put(s, v, reify_name(map_size(s)))
      [h | t] -> reify_s(t, reify_s(h, s))
      _ -> s
    end
  end

  @spec reify_name(non_neg_integer()) :: String.t()
  defp reify_name(n), do: "_#{n}"

  @doc """
  Takes `n` elements from a stream.

  ## Examples

      iex> x = Var.new("x")
      iex> take(1, [%{x => :olive}, %{x => :oil}])
      [%{#Var<name: "x", ...> => :olive}]

      iex> take(2, [%{x => :olive}, %{x => :oil}])
      [
        %{#Var<name: "x", ...> => :olive},
        %{#Var<name: "x", ...> => :oil}
      ]

  """
  @spec take(non_neg_integer(), stream()) :: [Substitution.t()]
  def take(0, _stream) do
    []
  end

  def take(_n, []) do
    []
  end

  def take(n, stream) when n >= 1 do
    case stream do
      suspension when is_function(suspension) -> take(n, suspension.())
      [h | t] -> [h | take(n - 1, t)]
    end
  end

  @doc """
  Takes all elements from a stream.

  ## Examples

      iex> x = Var.new("x")
      iex> take_all([%{x => :olive}, %{x => :oil}])
      [
        %{#Var<name: "x", ...> => :olive},
        %{#Var<name: "x", ...> => :oil}
      ]

  """
  @spec take_all(stream()) :: [Substitution.t()]
  def take_all(stream), do: take(length(stream), stream)

  @doc """
  Returns the list of `n` substitutions that would make goal `g` succeed.

  ## Examples

      iex> x = Var.new("x")
      iex> g = disj(eq(x, :olive), eq(x, :oil))
      iex> run_goal(1, g)
      [%{#ExLogic.Var<name: "x", ...> => :olive}]

  """
  @spec run_goal(non_neg_integer(), goal()) :: [ExLogic.value()]
  def run_goal(n, g) do
    take(n, g.(Substitution.empty_s()))
  end

  @doc """
  Returns ALL substitutions that would make goal `g` succeed.

  ## Examples

      iex> x = Var.new("x")
      iex> g = disj(eq(x, :olive), eq(x, :oil))
      iex> run_all(g)
      [
        %{#ExLogic.Var<name: "x", ...> => :olive},
        %{#ExLogic.Var<name: "x", ...> => :oil}
      ]

  """
  @spec run_all((any -> any)) :: [%{optional(ExLogic.Var.t()) => any}]
  def run_all(g) do
    take_all(g.(Substitution.empty_s()))
  end
end
