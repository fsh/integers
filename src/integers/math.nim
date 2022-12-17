import std/[bitops, strformat]

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


proc setOdd*(n: var Integer): int =
  ## In-place version of `toOdd`_.
  let e = n.scanOne()
  if e == -1:
    0
  else:
    mpz_tdiv_q_2exp(n, n, mp_bitcnt_t(e))
    e

proc toOdd*(n: sink Integer): (Integer, int) =
  ## Returns `(q, k)` where `q` is the largest odd factor of `n` and `k` is the highest power of 2 which divides `n`.
  ##
  ## Equivalently, shifts `n` right until it is odd, and then returns this
  ## number (`q`) as well as the number of bits shifted.
  ##
  ## No-op for zero.
  let k = n.setOdd()
  (n, k)

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

proc setDivExp*(n: var Integer, s: AnyInteger | static[int]): int =
  ## In-place version of `divExp`_.
  when (s is static[int]) and (s == 2):
    n.setOdd()
  elif s is Integer:
    while mpz_divisible_p(n, s) != 0:
      mpz_divexact(n, n, s)
      inc result
  else:
    when s is SomeSignedInt:
      let s = s.unsignedAbs()
    while mpz_divisible_ui_p(n, s) != 0:
      mpz_divexact_ui(n, n, s)
      inc result

func divExp*(n: sink Integer, s: AnyInteger | static[int]): (Integer, int) =
  ## Factors an integer `n` into `q * s^k` where `q` is not divisible by `s`.
  ## Returns `(q, k)`.
  ##
  ## That is, it "factors out" `s` of `n`, and returns the remaining factor as well as how many factors of `s` was present.
  ##
  ## This is intended to be more efficient than dividing out manually.
  ##
  ## (In Sage this is called `val_unit()`, using p-adic terminology.)
  ##
  runnableExamples:
    let n = 17^3 * 1900
    assert n is Integer

    assert n.divExp(17) == (1900'gmp, 3)
    assert n.divExp(2) == (17^3 * 475, 2)

  let k = n.setDivExp(s)
  (n, k)


func isqrt*(val: Integer): Integer {.inline.} =
  ## Returns the square root of `n`, rounded down to an integer.
  runnableExamples:
    assert 17'gmp.isqrt() == 4
  mpz_sqrt(result, val)

func iroot*(n: Integer, k: SomeUnsignedInt): Integer {.inline.} =
  ## Returns the `k`\ th root of `n`, rounded down to an integer.
  runnableExamples:
    assert 34'gmp.iroot(3) == 3
  discard mpz_root(result, n, culong(k))

func isqrtRem*(val: Integer): (Integer, Integer) {.inline.} =
  ## Like `isqrt`_ but also returns the remainder.
  ##
  ## Invariant: `n == root * root + remainder`.
  runnableExamples:
    assert 17'gmp.isqrtRem() == (4'gmp, 1'gmp)

  mpz_sqrtrem(result[0], result[1], val)

func irootRem*(n: Integer, k: SomeUnsignedInt): (Integer, Integer) {.inline.} =
  ## Like `iroot`_ but also returns the remainder.
  ##
  ## Invariant: `n == root^k + remainder`.
  runnableExamples:
    assert 34'gmp.irootRem(3) == (3'gmp, 7'gmp)

  mpz_rootrem(result[0], result[1], n, culong(k))


func kronecker*(a, b: distinct AnyInteger): int =
  ## Returns the Kronecker/Jacobi/Legendre-symbol of `(a|b)`.
  ##
  ## The return value is one of `{-1, 0, 1}`.
  ##
  ## - When `b` is an odd prime and `a` is not zero:
  ##
  ##   `a` is a quadratic residue modulo `b` *if and only if* `kronecker(a,b) == 1`.
  ##
  ## - When `b` is an odd composite:
  ##
  ##   `a` is *not* a quadratic residue if `kronecker(a,b) == -1`. Otherwise the result is inconclusive.
  ##
  ## - When `b` is even:
  ##
  ##   See `Wikipedia <https://en.wikipedia.org/wiki/Kronecker_symbol>`_ for more information.
  ##
  runnableExamples:
    let p = 257'gmp # a prime

    assert kronecker(17*17 % p, p) == 1 # obviously a quadratic residue
    assert kronecker(3, p) == -1 # 3 is not a quadratic residue modulo 257

  when a is Integer:
    when b is SomeUnsignedInt:
      mpz_kronecker_ui(a, culong(b))
    elif b is SomeSignedInt:
      mpz_kronecker_si(a, clong(b))
    else: # Integer
      mpz_jacobi(a, b).int
  else:
    when b isnot Integer:
      let b = newInteger(b)
    when a is SomeUnsignedInt:
      mpz_ui_kronecker(culong(a), b)
    else: # SomeSignedInt
      mpz_si_kronecker(clong(a), b)

func legendre*(a, b: distinct AnyInteger): int =
  ## Alias for `kronecker`_, as it is merely an extension of the Jacobi symbol which is an extension of the Legendre symbol.
  kronecker(a, b)

func jacobi*(a, b: distinct AnyInteger): int =
  ## Alias for `kronecker`_, as it is merely an extension of the Jacobi symbol.
  kronecker(a, b)


template requireUiArg(k: untyped): untyped =
  block:
    let kk {.inject.} = k # work-around for &"format"
    when kk is Integer:
      k.getOrDo(uint64):
        raise newException(ValueError, &"domain error: {kk} does not fit in an uint64")
    elif kk isnot SomeUnsignedInt:
      if kk < 0:
        raise newException(ValueError, &"domain error: {kk} is negative")
      else:
        kk.toUnsigned()



func factorial*(n: AnyInteger): Integer =
  ## Returns `n!` (= `n * (n-1) * (n-2) * ... * 2 * 1`).
  ##
  runnableExamples:
    assert factorial(6) == 6 * 5 * 4 * 3 * 2 * 1

  let n = requireUiArg(n)
  mpz_fac_ui(result, n.culong())

func factorial*(n: AnyInteger, m: SomeInteger): Integer =
  ## Returns the multifactorial `n * (n - m) * (n - 2*m) * ... * (n - (n//m)*m)`.
  ##
  runnableExamples:
    assert factorial(10, 3) == 10 * 7 * 4 * 1
    assert factorial(20, 5) == 20 * 15 * 10 * 5

  let n = requireUiArg(n)
  when m isnot SomeUnsignedInt:
    doAssert m >= 0, "domain error for factorial() function: requires non-negative arguments"
    let m = m.toUnsigned()

  mpz_mfac_uiui(result, n.culong(), m.culong())

func binomial*(n, k: distinct AnyInteger): Integer =
  ## Returns the binomial coefficient `n` over `k`.
  ##
  ## Equivalent to `n! / (k! * (n-k)!)`.
  ##
  ## Also called `comb` or `combinations` in some languages.
  runnableExamples:
    assert binomial(10, 2) == 45
    assert binomial(1000, 60) == factorial(1000) div (factorial(60) * factorial(940))

  let k = requireUiArg(k)

  when n is Integer:
    mpz_bin_ui(result, n, culong(k))
  elif n isnot SomeUnsignedInt:
    doAssert n >= 0, "domain error for binomial() function: requires non-negative arguments"
    let n = n.toUnsigned()
    mpz_bin_uiui(result, culong(n), culong(k))


func setFibonacci*(res: var Integer, k: AnyInteger) {.inline.} =
  ## In-place version of `fibonacci`_.
  let k = requireUiArg(k)
  mpz_fib_ui(res, culong(k))

func fibonacci*(k: AnyInteger): Integer =
  ## Returns the `k`\th Fibonacci number.
  ##
  ## See `fibonacciPair`_ for getting two consecutive Fibonacci numbers if you want to
  ## iterate to generate more. It is faster than calling `fibonacci`_ twice.
  ##
  ## Fibonacci numbers (and the closely related but less well known Lucas numbers) have a wide variety
  ## of applications, see `Wikipedia <https://en.wikipedia.org/wiki/Fibonacci_number>`_ for more.
  ##
  runnableExamples:
    assert fibonacci(210) + fibonacci(212) == lucas(211)
    assert fibonacci(101) + fibonacci(102) == fibonacci(103)

  result.setFibonacci(k)

func setFibonacciPair*(prev, this: var Integer; k: AnyInteger) {.inline.} =
  ## In-place version of `fibonacciPair`_.
  let k = requireUiArg(k)
  mpz_fib2_ui(this, prev, culong(k))

func fibonacciPair*(k: AnyInteger): (Integer, Integer) =
  ## Returns the `(k-1)`\th and `k`\th Fibonacci numbers as a tuple, in that order.
  ##
  ## This is faster than calling `fibonacci`_ twice.
  ##
  ## Fibonacci numbers (and the closely related but less well known Lucas numbers) have a wide variety
  ## of applications, see `Wikipedia <https://en.wikipedia.org/wiki/Fibonacci_number>`_ for more.
  ##
  runnableExamples:
    var (a, b) = fibonacciPair(500)

    for i in 500 .. 510:
      assert b == fibonacci(i)
      swap(a, b)
      b += a

  setFibonacciPair(result[0], result[1], k)

func setLucas*(res: var Integer, k: AnyInteger) {.inline.} =
  ## In-place version of `lucas`_.
  let k = requireUiArg(k)
  mpz_lucnum_ui(res, culong(k))

func lucas*(k: AnyInteger): Integer =
  ## Returns the `k`\th Lucas number.
  ##
  ## See `lucasPair`_ for getting two consecutive Lucas numbers if you want to
  ## iterate to generate more. It is faster than calling `lucas`_ twice.
  ##
  ## Lucas numbers are closely related to the Fibonacci numbers, see `Wikipedia <https://en.wikipedia.org/wiki/Lucas_number>`_ for more.
  ##
  runnableExamples:
    assert lucas(1000) == fibonacci(999) + fibonacci(1001)
    assert lucas(101) + lucas(102) == lucas(103)

  result.setLucas(k)

func setLucasPair*(prev, this: var Integer; k: AnyInteger) {.inline.} =
  ## In-place version of `lucasPair`_.
  let k = requireUiArg(k)
  mpz_lucnum2_ui(this, prev, culong(k))

func lucasPair*(k: AnyInteger): (Integer, Integer) =
  ## Returns the `(k-1)`\th and `k`\th Lucas numbers as a tuple, in that order.
  ##
  ## This is faster than calling `lucas`_ twice.
  ##
  ## Lucas numbers are closely related to the Fibonacci numbers, see `Wikipedia <https://en.wikipedia.org/wiki/Lucas_number>`_ for more.
  ##
  runnableExamples:
    var (a, b) = lucasPair(500)

    for i in 500 .. 510:
      assert b == lucas(i)
      swap(a, b)
      b += a

  setLucasPair(result[0], result[1], k)

func setPrimorial*(res: var Integer, n: AnyInteger) {.inline.} =
  ## In-place version of `primorial`_
  let n = requireUiArg(n)
  mpz_primorial_ui(res, culong(n))


func primorial*(n: AnyInteger): Integer =
  ## Returns the primorial of `n`. That is, the product of all primes less than
  ## or equal to `n`.
  ##
  runnableExamples:
    assert primorial(30) == 2 * 3 * 5 * 7 * 11 * 13 * 17 * 19 * 23 * 29

  result.setPrimorial(n)
