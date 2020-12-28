defprotocol ExLogic.Walk do
  @moduledoc """
  Walk protocol.
  """
  alias ExLogic.Substitution

  @fallback_to_any true

  @spec walk(ExLogic.value(), Substitution.t()) :: ExLogic.value()
  @doc """
  Walks the substitution to find the value associated with the value `x`.
  If the associated value is a variable, it recursively walks again.
  """
  def walk(x, substitution)

  @fallback_to_any true

  @spec walk_all(ExLogic.value(), Substitution.t()) :: ExLogic.value()
  @doc """
  Recursively walks the substitution and produces a value in which
  every variable is fresh.
  """
  def walk_all(value, substitution)
end

defimpl ExLogic.Walk, for: Any do
  alias ExLogic.{Var, Walk}

  def walk(%Var{} = var, substitution) do
    case Map.fetch(substitution, var) do
      {:ok, value} -> Walk.walk(value, substitution)
      :error -> var
    end
  end

  def walk(value, _substitution), do: value

  def walk_all(value, _substitution), do: value
end

defimpl ExLogic.Walk, for: List do
  alias ExLogic.Walk
  defdelegate walk(x, s), to: ExLogic.Walk.Any

  def walk_all([h | t], substitution) do
    # TODO: make tail recursive version
    [Walk.walk_all(h, substitution) | Walk.walk_all(t, substitution)]
  end

  def walk_all([], _substitution), do: []
end

defimpl ExLogic.Walk, for: Map do
  defdelegate walk(x, s), to: ExLogic.Walk.Any

  def walk_all(value, substitution) when is_map(value) do
    Map.fetch!(substitution, value)
  end
end
