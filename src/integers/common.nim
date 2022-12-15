## Some common functionality that is missing with Nim's primitive integers.

import ./core
export core

func zero*[T: AnyInteger](_: typedesc[T]): auto {.inline.} =
  ## The given type's representation of the additive unity `0`.
  when T is Integer:
    newInteger()
  else:
    T(0)

func one*[T: AnyInteger](_: typedesc[T]): auto {.inline.} =
  ## The given type's representation of multiplicative unity `1`.
  when T is Integer:
    newInteger(1)
  else:
    T(1)

