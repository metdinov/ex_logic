defmodule ExLogicTest do
  use ExUnit.Case
  use ExLogic

  doctest ExLogic, except: [:moduledoc, conj: 1, disj: 1, fresh: 2, conde: 1]
  doctest ExLogic.Var
end
