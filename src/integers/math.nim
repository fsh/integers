import std/bitops

import ./gmp
import ./core
export core

import ./misc
import ./bitset

func scaledTo*(val: Integer, T: typedesc): T =
  ## Interprets the integer as a fraction `val / 2^val.nbits()`, truncate this
  ## value to one that can be expressed with `x / 2^bitsof(T)`, and then
  ## return this `x`.
  ##
  ## Or, another way to think about it: we consider the leading bits of the
  ## number `val` and shift them so that the most significant bit becomes the
  ## most significant bit that `T` can hold, and then truncate all the bits that
  ## exceed what `T` can hold.
  ##
  ## If `T` is a signed type, the first bit will be used for the sign. Otherwise
  ## the sign of `val` is ignored.
  ##
  ## Use cases involve integer division algorithms where we usually only need
  ## the leading bits to figure out the exact quotient.
  ##
  runnableExamples:
    assert (0xabcd'gmp).scaledTo(uint8) == 0xab'u8
    assert (0xab'gmp).scaledTo(uint32) == 0xab000000'u32

  if val.mp_size == 0:
    return 0

  static:
    assert bitsof(mp_limb_t) >= bitsof(T)

  let lt = cast[ptr UncheckedArray[mp_limb_t]](val.mp_d)[val.mp_size.abs - 1]

  var scaled = lt shl lt.countLeadingZeroBits()
  when 64 > bitsof(T):
    scaled = scaled shr (64 - bitsof(T))

  when T is SomeUnsignedInt:
    return T(scaled)
  else:
    let ltt = T(scaled shr 1)
    return if val.isNatural: ltt else: -ltt



proc toOdd*(n: Integer): (Integer, int) =
  ## Returns `(q, k)` where `q` is the largest odd factor of `n` and `k` is the highest power of 2 which divides `n`.
  ##
  ## Equivalently, shifts `n` right until it is odd, and then returns this
  ## number (`q`) as well as the number of bits shifted.
  ##
  ## No-op for zero.
  let e = n.scanOne()
  if e == -1:
    (n, 0)
  else:
    (n shr e.uint, e)

func divisible*(val: Integer, n: AnyInteger): bool =
  ## Returns `true` if the first argument is divisble by the second.
  ##
  ## More efficient than actually dividing and checking the remainder.
  ##
  when n is Integer:
    return mpz_divisible_p(val, n) != 0
  else:
    when n is SomeSignedInt:
      # We don't care about negative numbers.
      let n = n.unsignedAbs()
    return mpz_divisible_ui_p(val, n.culong()) != 0

proc setDivExp*(val: var Integer, n: AnyInteger): int =
  when n is Integer:
    while mpz_divisible_p(val, n) != 0:
      mpz_divexact(val, val, n)
      inc result
  else:
    when n is SomeSignedInt:
      let n = n.unsignedAbs()
    while mpz_divisible_ui_p(val, n) != 0:
      mpz_divexact_ui(val, val, n)
      inc result


func isqrt*(val: Integer): Integer {.inline.} =
  mpz_sqrt(result, val)

func iroot*(val: Integer, n: SomeUnsignedInt): Integer {.inline.} =
  mpz_root(result, val, n.culong)

func isqrtRem*(val: Integer): (Integer, Integer) {.inline.} =
  mpz_sqrtrem(result[0], result[1], val)

func isqrtRem*(val: Integer, n: SomeUnsignedInt): (Integer, Integer) {.inline.} =
  mpz_rootrem(result[0], result[1], val, n.culong)


func factorial*(n: AnyInteger): Integer =
  ## Returns `n!` (= `n * (n-1) * (n-2) * ... * 2 * 1`).
  ##
  runnableExamples:
    assert factorial(6) == 6 * 5 * 4 * 3 * 2 * 1

  when n is Integer:
    let n = n.getOr(uint64):
      raise newException(ValueError, "domain error for factorial() function")
  elif n isnot SomeUnsignedInt:
    doAssert n >= 0, "domain error for factorial() function: requires non-negative argument"
    let n = n.toUnsigned()

  mpz_fac_ui(result, n.culong())

func factorial*(n: AnyInteger, m: SomeInteger): Integer =
  ## Returns the multifactorial `n * (n - m) * (n - 2*m) * ... * (n - (n//m)*m)`.
  ##
  runnableExamples:
    assert factorial(10, 3) == 10 * 7 * 4 * 1
    assert factorial(20, 5) == 20 * 15 * 10 * 5
  when n is Integer:
    let n = n.getOr(uint64):
      raise newException(ValueError, "domain error for factorial() function")
  elif n isnot SomeUnsignedInt:
    doAssert n >= 0, "domain error for factorial() function: requires non-negative arguments"
    let n = n.toUnsigned()
  when m isnot SomeUnsignedInt:
    doAssert m >= 0, "domain error for factorial() function: requires non-negative arguments"
    let m = m.toUnsigned()

  mpz_mfac_uiui(result, n.culong(), m.culong())
