defmodule Fluid.Conditions do
  alias Fluid.Condition, as: Cond
  alias Fluid.Variables, as: Vars
  alias Fluid.Context, as: Context

  def create([h|t]=list) do
    head = create(h)
    create(head, t)
  end

  def create(condition, []), do: condition
  def create(condition, [join, right|t]) when join == "and" or join == "or" do
    right = create(right)
     join = join |> String.strip |> binary_to_atom(:utf8)
    join(join, condition, right)
  end

  def create({ left, operator, right }) do
    left = Vars.create(left)
    right = Vars.create(right)
    operator = binary_to_atom(operator, :utf8)
    Cond[left: left, operator: operator, right: right]
  end

  def create(<<left::binary>>) do
    left = Vars.create(left)
    Cond[left: left]
  end

  def join(operator, condition, { _, _, _ }=right), do: join(operator, condition, right |> create)
  def join(operator, condition, Cond[]=right) do
    right.child_condition(condition).child_operator(operator)
  end

  def evaluate(Cond[left: left, right: nil]=condition, Context[]=context//Context[]) do
    { current, context } = Vars.lookup(left, context)
    eval_child(!!current, condition.child_operator, condition.child_condition, context)
  end

  def evaluate(Cond[left: left, right: right, operator: operator]=condition, Context[]=context//Context[]) do
    { left, context } = Vars.lookup(left, context)
    { right, context } = Vars.lookup(right, context)
    current = eval_operator(left, operator, right)
    eval_child(!!current, condition.child_operator, condition.child_condition, context)
  end

  defp eval_child(current, nil, nil, _), do: current

  defp eval_child(current, :and, condition, context) do
    current and evaluate(condition, context)
  end

  defp eval_child(current, :or, condition, context) do
    current or evaluate(condition, context)
  end

  defp eval_operator(left, operator, right) when (nil?(left) xor nil?(right)) and operator in [:>=, :>, :<, :<=], do: false
  defp eval_operator(left, operator, right) do
    case operator do
      :== -> left == right
      :>= -> left >= right
      :>  -> left >  right
      :<= -> left <= right
      :<  -> left <  right
      :!= -> left != right
      :<> -> left != right
      :contains -> contains(left, right)
    end
  end

  defp contains(nil, right), do: false
  defp contains(right, nil), do: false
  defp contains(<<left::binary>>, <<right::binary>>), do: contains(left |> binary_to_list, right |> binary_to_list)
  defp contains(left, <<right::binary>>) when is_list(left), do: contains(left, right |> binary_to_list)
  defp contains(<<left::binary>>, right) when is_list(right), do: contains(left |> binary_to_list, right)
  defp contains(left, right) when is_list(left) and !is_list(right), do: contains(left, [right])
  defp contains(left, right) when is_list(right) and is_list(left), do: :string.rstr(left, right) > 0
end
