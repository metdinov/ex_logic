defmodule ExLogicTest do
  use ExUnit.Case
  doctest ExLogic

  test "greets the world" do
    assert ExLogic.hello() == :world
  end
end
