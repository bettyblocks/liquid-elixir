defmodule Liquid.NimbleParser do
  @moduledoc """
  Transform a valid liquid markup in an AST to be executed by `render`
  """
  # TODO: Find methods to split this module
  import NimbleParsec

  alias Liquid.Combinators.General

  liquid_variable =
    General.start_variable()
    |> concat(parsec(:variable_name))
    |> concat(General.end_variable())
    |> tag(:variable)
    |> optional(parsec(:__parse__))

  defparsec(:liquid_variable, liquid_variable)
  defparsec(:variable_name, General.variable_name())
  defparsec(:start_tag, General.start_tag())
  defparsec(:end_tag, General.end_tag())

  ################################        Tags              ###########################

  assign =
    empty()
    |> parsec(:start_tag)
    |> concat(ignore(string("assign")))
    |> concat(parsec(:variable_name))
    |> concat(ignore(string("=")))
    |> concat(parsec(:value))
    |> concat(parsec(:end_tag))
    |> tag(:assign)
    |> optional(parsec(:__parse__))

  defparsec(:assign, assign)

  decrement =
    empty()
    |> parsec(:start_tag)
    |> string("decrement")
    |> concat(parsec(:variable_name))
    |> concat(parsec(:end_tag))
    |> tag(:decrement)
    |> optional(parsec(:__parse__))

  defparsec(:decrement, decrement)

  increment =
    empty()
    |> parsec(:start_tag)
    |> string("increment")
    |> concat(parsec(:variable_name))
    |> concat(parsec(:end_tag))
    |> tag(:increment)
    |> optional(parsec(:__parse__))

  defparsec(:increment, increment)

  ################################           raw          ###########################

  raw_tag =
    string("raw")
    |> ignore()

  raw_end_tag =
    string("endraw")
    |> ignore()

  open_tag_raw =
    empty()
    |> parsec(:start_tag)
    |> concat(raw_tag)
    |> concat(parsec(:end_tag))

  defparsec(:open_tag_raw, open_tag_raw)

  close_tag_raw =
    empty()
    |> parsec(:start_tag)
    |> concat(raw_end_tag)
    |> concat(parsec(:end_tag))

  defparsec(:close_tag_raw, close_tag_raw)

  not_close_tag_raw =
    empty()
    |> ignore(utf8_char([]))
    |> parsec(:raw_text)

  defparsecp(:not_close_tag_raw, not_close_tag_raw)

  raw_text =
    empty()
    |> repeat_until(utf8_char([]), [
      string(General.codepoints().start_tag)
    ])
    |> choice([parsec(:close_tag_raw), parsec(:not_close_tag_raw)])
    |> tag(:raw_text)

  defparsec(:raw_text, raw_text)

  raw =
    empty()
    |> parsec(:open_tag_raw)
    |> concat(parsec(:raw_text))
    |> tag(:raw)
    |> optional(parsec(:__parse__))

  defparsec(:raw, raw)
  ##############################           raw            ###########################

  ###############################        comment          ###########################
  not_end_comment =
    empty()
    |> ignore(utf8_char([]))
    |> parsec(:comment_content)

  defparsecp(:not_end_comment, not_end_comment)

  end_comment =
    empty()
    |> parsec(:start_tag)
    |> ignore(string("endcomment"))
    |> concat(parsec(:end_tag))

  defparsecp(:end_comment, end_comment)

  comment_content =
    empty()
    |> repeat_until(utf8_char([]), [
      string(General.codepoints().start_tag)
    ])
    |> choice([parsec(:end_comment), parsec(:not_end_comment)])

  defparsecp(:comment_content, comment_content)

  comment =
    empty()
    |> parsec(:start_tag)
    |> ignore(string("comment"))
    |> concat(parsec(:end_tag))
    |> ignore(parsec(:comment_content))
    |> optional(parsec(:__parse__))

  defparsec(:comment, comment)

  ################################        comment          ###########################

  defparsec(
    :liquid_tag,
    choice([
      assign,
      decrement,
      increment,
      parsec(:raw),
      comment
    ])
  )

  ################################ end Tags #######################################

  ################################## Lexical Tokens ###############################

  # Token ::
  #   - Punctuator
  #   - IntValue
  #   - FloatValue
  #   - StringValue

  # Punctuator :: one of ! $ ( ) ... : = @ [ ] { | }
  # Note: No `punctuator` combinator(s) defined; these characters are matched
  #       explicitly with `ascii_char/1` in other combinators.

  # NegativeSign :: -
  negative_sign = ascii_char([?-])

  # Digit :: one of 0 1 2 3 4 5 6 7 8 9
  digit = ascii_char([?0..?9])

  # NonZeroDigit :: Digit but not `0`
  non_zero_digit = ascii_char([?1..?9])

  # IntegerPart ::
  #   - NegativeSign? 0
  #   - NegativeSign? NonZeroDigit Digit*
  integer_part =
    empty()
    |> optional(negative_sign)
    |> choice([
      ascii_char([?0]),
      non_zero_digit |> repeat(digit)
    ])

  # IntValue :: IntegerPart
  int_value =
    empty()
    |> concat(integer_part)
    |> reduce({List, :to_integer, []})

  # FractionalPart :: . Digit+
  fractional_part =
    empty()
    |> ascii_char([?.])
    |> times(digit, min: 1)

  # ExponentIndicator :: one of `e` `E`
  exponent_indicator = ascii_char([?e, ?E])

  # Sign :: one of + -
  sign = ascii_char([?+, ?-])

  # ExponentPart :: ExponentIndicator Sign? Digit+
  exponent_part =
    exponent_indicator
    |> optional(sign)
    |> times(digit, min: 1)

  # FloatValue ::
  #   - IntegerPart FractionalPart
  #   - IntegerPart ExponentPart
  #   - IntegerPart FractionalPart ExponentPart
  float_value =
    empty()
    |> choice([
      integer_part |> concat(fractional_part) |> concat(exponent_part),
      integer_part |> concat(fractional_part)
    ])
    |> reduce({List, :to_float, []})

  # StringValue ::
  #   - `"` StringCharacter* `"`
  string_value =
    empty()
    |> ignore(ascii_char([?"]))
    |> repeat_until(utf8_char([]), [utf8_char([?"])])
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})

  # BooleanValue : one of `true` `false`
  boolean_value =
    choice([
      string("true"),
      string("false")
    ])

  # NullValue : `nil`
  null_value = string("nil")

  # Value[Const] :
  #   - IntValue
  #   - FloatValue
  #   - StringValue
  #   - BooleanValue
  #   - NullValue
  #   - ListValue[?Const]
  value =
    General.ignore_whitespaces()
    |> choice([
        float_value,
        int_value,
        string_value,
        boolean_value,
        null_value,
        parsec(:list_value)
    ])
    |> concat(General.ignore_whitespaces())
    |> unwrap_and_tag(:value)

  defparsec(:value, value)

  # ListValue[Const] :
  #   - [ ]
  #   - [ Value[?Const]+ ]
  list_value =
    choice([
      ascii_char([?[])
      |> ascii_char([?]]),
      ascii_char([?[])
      |> times(parsec(:value), min: 1)
      |> ascii_char([?]])
    ])

  defparsec(:list_value, list_value)

  #################################### End lexical Tokens #####################################

  ########################################### Parser ##########################################

  defparsec(
    :__parse__,
    General.literal()
    |> optional(choice([parsec(:liquid_tag), parsec(:liquid_variable)]))
  )

  @doc """
  Valid and parse liquid markup.
  """
  @spec parse(String.t()) :: {:ok | :error, any()}
  def parse(""), do: {:ok, ""}

  def parse(markup) do
    case __parse__(markup) do
      {:ok, template, "", _, _, _} ->
        {:ok, template}

      {:ok, _, rest, _, _, _} ->
        {:error, "Error parsing: #{rest}"}
    end
  end
end
