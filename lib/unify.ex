defprotocol ExLogic.Unify do
  @moduledoc """
  Unification protocol.
  """
  alias ExLogic.Substitution

  @spec unify(any(), any(), Substitution.t()) :: {:ok, ExLogic.Substitution.t()} | :error
  def unify(u, v, s)
end

defimpl ExLogic.Unify, for: List do
  alias ExLogic.Substitution

  @spec unify(list(), list(), Substitution.t()) :: {:ok, Substitution.t()} | :error
  def unify([hu | tu] = u, [hv | tv] = v, s)
      when is_list(u)
      when is_list(v)
      when length(u) == length(v) do
    case Substitution.unify(hu, hv, s) do
      :error -> :error
      {:ok, s} -> Substitution.unify(tu, tv, s)
    end
  end

  def unify(_u, _v, _s) do
    :error
  end
end

defimpl ExLogic.Unify, for: Tuple do
  alias ExLogic.Substitution

  @spec unify(tuple(), tuple(), Substitution.t()) :: {:ok, Substitution.t()} | :error
  def unify(u, v, s) when is_tuple(v) do
    u = Tuple.to_list(u)
    v = Tuple.to_list(v)
    Substitution.unify(u, v, s)
  end

  def unify(_u, _v, _s) do
    :error
  end
end

defimpl ExLogic.Unify, for: Map do
  alias ExLogic.Substitution

  @spec unify(map(), map(), Substitution.t()) :: {:ok, Substitution.t()} | :error
  def unify(u, v, s)
      when is_map(u)
      when is_map(v)
      when map_size(u) == map_size(v) do
    [kf | _kt] = Map.keys(u)

    if vf = Map.get(v, kf) do
      case Substitution.unify(Map.get(u, kf), vf, s) do
        :error -> :error
        {:ok, s} -> Substitution.unify(Map.delete(u, kf), Map.delete(v, kf), s)
      end
    else
      :error
    end
  end

  def unify(_u, _v, _s) do
    :error
  end
end

defimpl ExLogic.Unify, for: Any do
  @spec unify(any(), any(), Substitution.t()) :: :error

  def unify(_u, _v, _s) do
    :error
  end
end
