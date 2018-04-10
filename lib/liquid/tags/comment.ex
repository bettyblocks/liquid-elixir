defmodule Liquid.Comment do
  @moduledoc """
  Allows you to leave un-rendered code inside a Liquid template.
  Any text within the opening and closing comment blocks will not be output,
  and any Liquid code within will not be executed
  Input:
  ```
    Anything you put between {% comment %} and {% endcomment %} tags
    is turned into a comment.
  ```
  Output:
  ```
    Anything you put between  tags
    is turned into a comment
  ```
  """
  alias Liquid.{Block, Context, Template}

  @doc """
  Implementation of Comment parse operations
  """

  @spec parse(%Block{}, %Template{}) :: {%Block{}, %Template{}}
  def parse(%Block{} = block, %Template{} = template),
    do: {%{block | blank: true, strict: false}, template}

  @doc """
  Implementation of Comment render operations
  """
  @spec render(list(), %Block{}, %Context{}) :: {list(), %Context{}}
  def render(output, %Block{}, context), do: {output, context}
end
