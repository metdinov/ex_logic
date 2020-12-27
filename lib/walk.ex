defprotocol ExLogic.Walk do
  @moduledoc """
  Walk protocol.
  """
  alias ExLogic.Substitution

  @fallback_to_any true

  @spec walk(ExLogic.value(), Substitution.t()) :: ExLogic.value()
  @doc """
  Walks the substitution to find the value associated with `x`.
  If the associated value is a variable, it recursively walks again.
  """
  def walk(x, substitution)
end

defimpl ExLogic.Walk, for: ExLogic.Var do
  alias ExLogic.{Var, Substitution}

  @spec walk(Var.t(), Substitution.t()) :: ExLogic.value()
  def walk(%Var{} = var, s) do
    case Map.fetch(s, var) do
      {:ok, %Var{} = y} -> walk(y, s)
      {:ok, value} -> value
      :error -> var
    end
  end
end

defimpl ExLogic.Walk, for: Any do
  alias ExLogic.Substitution

  @spec walk(any(), Substitution.t()) :: ExLogic.value()
  def walk(value, _substitution) do
    value
  end
end
