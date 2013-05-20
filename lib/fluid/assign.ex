defmodule Fluid.Assign do
  alias Fluid.Variables, as: Variables
  alias Fluid.Tag, as: Tag
  alias Fluid.Context, as: Context

  def syntax, do: %r/([\w\-]+)\s*=\s*(.*)\s*/

  def render(output, Tag[markup: markup], Context[]=context) do
    [[ to, from ]] = Regex.scan(syntax, markup)
    to_atom  = to |> binary_to_atom(:utf8)
    variable = Variables.create(from)
    { from_value, context } = Variables.lookup(variable, context)
    context = context.assigns |> Dict.put(to_atom, from_value) |> context.assigns
    { output, context }
  end
end
