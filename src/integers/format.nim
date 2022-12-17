
import std/[strformat, strutils]

import ./gmp
import ./misc
import ./core
export core

proc `$`*(n: Integer, base: int = 10): string =
  ## Renders the integer as a string.
  ##
  ## Optinally also takes a `base` argument.
  assert base in 2..62 or base in -36 .. -2, "base must be in `2 .. 62 or -36 .. -2`"
  result = newString(mpz_sizeinbase(n, base.cint) + 1)
  discard mpz_get_str(result.cstring, base.cint, n)
  result.shrinkToC()

proc charToBase(ch: char): int =
  case ch:
    of '\0', 'd', 'D': 10
    of 'x', 'X': 16
    of 'o', 'O': 8
    of 'b', 'B': 2
    of 'a', 'A': 36
    of 't', 'T': 62
    else:
      raise newException(ValueError, "invalid base char: " & ch)

proc formatInteger*(n: sink Integer, fmt: string): string =
  let spec = fmt.parseStandardFormatSpecifier()
  let base = charToBase(spec.typ)

  let negative = n.isNegative()
  let has_sign = negative or spec.sign != '-'

  n.setAbs()
  var s_num = newString(mpz_sizeinbase(n, base.cint) + 1)
  discard mpz_get_str(s_num.cstring, base.cint, n)
  s_num.shrinkToC()

  assert s_num.len > 0

  let p_sign = if negative: "-"
               elif spec.sign != '-': $spec.sign
               else: ""
  let p_alt = if spec.alternateForm and spec.typ != '\0': '0' & spec.typ
              else: ""
  let p_pad = if spec.padWithZero: repeat('0', (spec.minimumWidth - s_num.len - p_sign.len - p_alt.len).max(0))
              else: ""
  let align = if spec.align == '\0': '>' else: spec.align

  join([p_sign, p_alt, p_pad, s_num]).alignString(spec.minimumWidth, align, spec.fill)

proc formatValue*(output: var string, n: sink Integer, fmt: string) =
  if fmt.len == 0:
    output.add $n
    return

  output.add formatInteger(n, fmt)

