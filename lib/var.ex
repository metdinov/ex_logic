defmodule ExLogic.Var do
  @moduledoc """
  Logic variables.
  """

  @derive {Inspect, only: [:name]}
  @enforce_keys [:name, :__id__]
  defstruct [:name, :__id__]

  @type t :: %ExLogic.Var{name: String.t() | atom(), __id__: binary()}

  @doc """
  Returns a new variable with the given (optional) name.

  ## Example

    iex> ExLogic.Var.new(:x)
    #ExLogic.Var<name: :x, ...>

    iex> ExLogic.Var.new()
    #ExLogic.Var<name: "unnamed", ...>
  """
  @spec new(name :: String.t()) :: ExLogic.Var.t()
  def new(name \\ "unnamed") when is_binary(name) or is_atom(name) do
    %ExLogic.Var{name: name, __id__: UUID.uuid1()}
  end
end
