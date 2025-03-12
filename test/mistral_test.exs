defmodule MistralTest do
  use ExUnit.Case
  doctest Mistral

  test "greets the world" do
    assert Mistral.hello() == :world
  end
end
