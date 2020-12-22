defmodule ExLogic.GoalsTest do
  use ExUnit.Case

  import ExLogic.Goals
  alias ExLogic.Var

  doctest ExLogic.Goals,
    except: [:moduledoc, call_with_fresh: 2, take: 2, take_all: 1, conj: 2, disj: 2]
end
