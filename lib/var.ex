defmodule ExLogic.Var do
  @moduledoc """
  Logic variables.
  """

  alias __MODULE__

  @derive {Inspect, only: [:name]}
  @enforce_keys [:name, :__ref__]
  defstruct [:name, :__ref__]

  @type t :: %Var{name: String.t(), __ref__: reference()}

  @doc """
  Returns a new variable with the given (optional) name.

  ## Example

    iex> Var.new("x")
    #ExLogic.Var<name: "x", ...>
  """
  @spec new(name :: String.t()) :: Var.t()
  def new(name \\ "unnamed") when is_binary(name) do
    %Var{name: name, __ref__: make_ref()}
  end
end
