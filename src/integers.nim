
when NimVersion >= "1.7":
  {.doctype: rst.}

## ========
## Integers
## ========
##
## This package simply aims to provide *integers* (also known as "bigints,"
## "bignums," "arbitrary precision integers," "true integers") for Nim by
## wrapping the GMP library in a nice ergonomic way.
##
## See README on `GitHub page <https://github.com/fsh/integers>`_ for raison d'être and caveats.
##
## Basics
## ======
##
## `Integer <integers/core.html#Integer>`_\s can be conveniently written as literals directly in Nim code with
## the postfix `'gmp`. They can also be instantiated via `newInteger <integers/core.html#newInteger>`_. A rich
## set of conversions from string and bytes also exist. The usual suspects like
## `$` and so on will also work.
##

runnableExamples:
  let i = 101'gmp
  assert i is Integer

  # Hexadecimal, binary, and octal also works. Here's a 192-bit prime literal.
  # Note that underscores are ignored.
  assert 0x82aaeef3_975e3407_a98c6c72_f6c872f0_5521d137_91c5f8cd'gmp is Integer

  let x = newInteger(101) # equivalent to 101'gmp
  let y = newInteger("19_000_000_000_000_000") # string conversion
  let z = newInteger("1000101", 2) # second argument is base.

  # Integers can also be constructed from any array of primitive unsigned
  # integers or a series of raw bytes. Numerous options exist for order
  # and interpretation. See documentation under `integers/bytes <integers/bytes.html>`.
  let f = newInteger([255'u8, 1, 2], woMSF)
  assert f == 0xff0102'gmp
  assert f.toBytes(woLSF) == @[2'u8, 1, 255]

  assert $x == "101"

  import std/strformat
  assert &"{z:010b}" == "0001000101"

##
## Arithmetic
## ----------
##
## Ordinary arithmetic operations `+`, `-`, `*`, `div`, `mod` should work as
## expected (`caveat <#divwarn>`_). The same goes for comparison operators,
## `==`, `!=`, `<=`, `<`, and so on.
##
## Most operators can be used with any integer operands. That is, as long as at
## least one operand is an `Integer <integers/core.html#Integer>`_ the other operand can be of type
## `AnyInteger <integers/core.html#AnyInteger>`_ (a GMP `Integer <integers/core.html#Integer>`_ or any primitive fixed-size integer, like
## `int` or `uint8`). This might look like auto-promotion, but in code
## there's specializations to make it more efficient, as GMP often has
## specialized routines for handling fixed-sized arguments.
##
## In general, doing operations the natural way with primitive integers tends to
## be more efficient than forcing everything to be `Integer <integers/core.html#Integer>`_ ahead of time.
## That is, prefer `x + 1`, over `x + 1'gmp`.
##

runnableExamples:
  let five = 5'gmp

  assert five * 5 == 25
  assert 5'u64 + five == 10'i8

  var n = Integer.one

  for i in 1 .. 32:
    n *= i

  assert n == factorial(32)

##
## Exponentiation is implemented as `^`. It works for any combination of
## integer arguments, but the result is always an `Integer`.
##
## Another primitive operation is `divMod` which does the same as `(x div y, x
## mod y)` but more efficiently. See `math and number theory`_ for a lot more.
##
runnableExamples:
  assert 2^1000 == 2^500 * 2^500

  assert divMod(3^100, 40) == (3^100 div 40, 1'gmp)

##
## Comparisons
## -----------
##
## In addition to the normal comparison operators (`==`, `!=`, `<=`, `<`, etc.), there's
## also an equivalent set of *absolute* comparisons, using a suffix ``%``.
##
## - `x ==% y` is equivalent to `abs(x) == abs(y)`
## - `x !=% y` is equivalent to `abs(x) != abs(y)`
## - `x <% y` is equivalent to `abs(x) < abs(y)`
## - `x >=% y` is equivalent to `abs(x) >= abs(y)`
## - ... and so on.
##
## For very simple domain checks there's also a number of
## universal functions that are designed to be as lightweight as humanly
## possible (they guarantee no external function call will be made into the GMP
## library).
##
## - `isZero(AnyInteger): bool`
## - `isNonZero(AnyInteger): bool`
## - `isPositive(AnyInteger): bool`
## - `isNegative(AnyInteger): bool`
## - `isNatural(AnyInteger): bool`: if a number is greater than or equal to 0, i.e. it's non-negative.

runnableExamples:
  assert -1'gmp ==% 1
  assert 2 <% -20

  assert 0.isZero
  assert uint64.one.isNonZero
  assert 10'gmp.isNatural

##
## Mutability
## ==========
##
## For reasons of efficiency, `Integer <integers/core.html#Integer>`_\s are *mutable*.
##
## Every time a new non-zero `Integer <integers/core.html#Integer>`_ is instantiated a heap allocation occurs
## (in GMP), thus it is usually more efficient to re-use variables if possible.
## As such this package provides a cornucopia of in-place and assignment
## operators.
##
## As such there's a lot of in-place and assignment operators provided.
##
## Note that Nim weirdly does not have an assignment operator equivalent of
## `div`, `mod`, `and`, `xor`, etc. So operators have been added to make up for
## this fact.
##
## For example:
##
## - `//` can be used instead of `div`, with `//=` being the assignment operator.
## - `%` can be used instead of `mod`, with `%=` being the assignment operator.
##
## See also `bit operations`_ for more such operator aliases.
##
## The in-place version of unary `-` is `setNegative <integers/core.html#setNegative,mpz_struct>`_.
##
## There is also `addMul` and `subMul` which are trinary operators that does
## fused multiply-and-add or multiply-and-sub. If you are writing something like
## `x += y * z` it is usually more efficient to use `x.addMul(y, z)` instead.
##

runnableExamples:
  var x = 60'gmp

  x.inc # x == 61
  x += 10 # x == 71
  x //= 2
  assert x == 35

  # Equivalent to `x += 2 * 100'gmp`
  x.addMul(2, 100'gmp)

  assert x == 235

  x.setNegative() # Extremely cheap operation.
  assert x == -235

  # Equivalent to `x = 200 - x`.
  x.assign(200 - x)
  assert x == 435

  x %= 10
  assert x == 5

##
## Bit Operations
## ==============
##
## For reasons mentioned in `mutability`_, the bit operators have also been
## given symbolic aliases. These all use ``&`` as a prefix:
##
## - `&&`, `&&=` bitwise AND (`and` can also be used)
## - `&|`, `&|=` bitwise OR (`or` can also be used)
## - `&^`, `&^=` bitwise XOR (`xor` can also be used)
## - `&>>`, `&>>=` shift bits right (`shr` can also be used)
## - `&<<`, `&<<=` shift bits left (`shl` can also be used)
## - `~` does bitwise NOT (`not` can also be used). The in-place version of this is `setNot <integers/bitset.html#setNot,mpz_struct>`_.
##
## I agree this is rather ugly but it's the best I could do within
## the constraints of Nim\ [#ugly]_.
##
## .. note:: Although these operations also work on regular primitive integers,
##   the result is always an `Integer <integers/core.html#Integer>`_ (might change?), so they're not
##   recommended for regular use.
##
runnableExamples:

  assert 0xff &^ 0x0f == 0xf0
  assert 3 &<< 100 == 2^100 * 3

  assert 4^10 &>> 2 == 4^9

  let z = 0xff01'gmp

  assert ~z && 0xff == 0xfe

##
## Bit Sets
## --------
##
## As a *radical convenience*, `Integer <integers/core.html#Integer>`_\s can be treated directly as implementing
## fast dynamic bitsets.
##
## If you think about it, arbitrary precision integers and dynamically sized
## bitsets are usually built upon the same core data structure, but differ only
## in exposed functionality (with the bitsets having a vastly simpler API and
## implementation of course).
##
## As such, `Integer <integers/core.html#Integer>`_\s can be indexed, iterated over, they have a `size` and a `count`,
## and so on.
## The above bit operations can be used to do unions, intersections, et cetera.
##
## The indexing operator `[]` returns `true` or `false` depending on
## whether the given bit is `1` or `0`. Likewise, `[]=` can be used to set
## arbitrary bits.
##
## `count(n)` gives the total number of bits set to 1.
##
## `scanOne(n, [pos])` and `scanZero(n, [pos])` finds the first 1- or 0-bit at or after
## the given position.
##
## `size(n)` (an alias for `nbits(n)`) gives the total number of bits
## required to express the absolute value of `n`.
##
## And finally, iterating over an `Integer <integers/core.html#Integer>`_ will loop over the indices of its
## 1-bits. See XXX for more ## information.

runnableExamples:

  var x = newInteger()

  x[10] = true
  assert x == 1024 # 2^10

  x[2] = true
  x[0] = true
  assert x == 1029 # 2^10 + 2^2 + 2^0
  assert x.count == 3
  assert x.nbits == 11 # == one higher than index of highest 1-bit

  import std/sequtils
  assert items(x).toSeq() == @[0, 2, 10]

  let y = 10'gmp

  assert y.scanOne() == 1
  assert y[1] and not y[0]

##
## Random Numbers
## ==============
##
## This library ties in with the standard Nim library `std/random` [#rng]_ and provides
## functions for generating random `Integer <integers/core.html#Integer>`_\s using the `Rand` state object.
##
## It is not exported by `integers`_ by default.
## `integers/random <integers/random.html>`_ re-exports `std/random`_.
##
runnableExamples:

  import integers/random # also imports std/random

  var rng = initRand(0xdead533d) # leave out argument for time-initialized seed.

  assert rng.randBelow(100) < 100
  assert rng.rand(2^80 .. 3^80) in 2^80 .. 3^80

  var t: Integer
  for _ in 0 ..< 20:
    t &|= rng.randBits(100) # bitwise OR in 100 random bits

  # Extremely likely that t is now all 1-bits.
  assert t.count() == 100
  assert t.nbits() == 100
  assert t == 2^100 - 1

  # Functionality for generating primes.
  import integers/primes
  assert rng.randPrimeBits(100).isPrime() # random ~100-bit prime
  let p = rng.randPrimeBits(100, fixed=true) # random =100-bit prime
  assert p.isPrime() and p.nbits() == 100

##
## Math and Number Theory
## ======================
##
## See `integers/math <integers/math.html>`_.
##
## - `isqrt`, `isqrtRem`: integer square roots.
## - `iroot`, `irootRem`: integer k-roots.
##
## The ``...Rem`` versions return `(result, remainder)`.
##
## - `kronecker`, `jacobi`, `legendre`: number-theoretical calculations related to quadratic residues. See `Wikipedia <https://en.wikipedia.org/wiki/Kronecker_symbol>`_.
##
## - `toOdd`, `setOdd`: divide out factors of `2`
## - `divExp`, `setDivExp`: divide out arbitrary factors
##
## - `factorial`
##
## TODO: `comb` `primorial` `lucas`, ...
##
## Primes and Factors
## ------------------
##
## - `gcd`, `extGcd`: greatest common divisors
## - `lcm`: least common multiplier
## - `isPrime`: primality testing
## - `nextPrime`, `setNextPrime`, `prevPrime`: finding primes
##
## Modular Numbers
## ---------------
##
## TODO
##
## `invMod`, `powMod`, ...
##
## Other Goodies
## =============
##
## Some additional utility functions are exported by `integers/misc`_ which are used internally.
## I consider them universally useful.
##
## `AnyInteger`_ types are imbued with type-level functions `one(T)` and `zero(T)` for
## easing generic programming, as an expression like `T(1)` does not work with object-types.
##
## For primitive integers we also export `unsignedAbs(x)`, `toSigned(x)`, and
## `toUnsigned(x)`. The latter two are simple bitcasts and self-explanatory.
## `unsignedAbs(x)` is functionally equivalent to `abs(x).toUnsigned()` but
## without any risk of integer overflow.
##
## There's a `bitsof(T)` that is a synonym for `8 * sizeof(T)`.
##
runnableExamples:
  func mysteryFunc[T: AnyInteger](x: T): T =
    var x = x
    var g = T.one # T(1) would fail!
    while x > T.one:
      g *= x
      x = x div 2
    return g

  assert mysteryFunc(10'gmp) == 100
  assert mysteryFunc(10'u16) == 100

  let r = int8(-128).unsignedAbs()
  assert r is uint8
  assert r == 128

  assert int16(-1).toUnsigned == 0xffff'u16


## Additional Notes
## ================
##
## Unless otherwise stated, GMP functions are thread safe (unless compiled with
## special flags). Multiple threads can use the same `Integer <integers/core.html#Integer>`_. However, it is
## of course *not* safe for one thread to modify an `Integer <integers/core.html#Integer>`_ while other
## therads are using it. There are no locks.
##
## `Integer <integers/core.html#Integer>`_\s are not safe to be memory-copied (e.g. `memcpy` or similar).
## Doing so will likely lead to a crash. This will never happen accidentally
## though; if you're doing something naughty, you'll know about it.
##
## .. _divwarn:
##
## .. warning:: The semantics of `div` and `mod` on `Integer <integers/core.html#Integer>`_\s use floored division (they round toward
##   negative infinity, like in Python).
##   This is a deliberate choice breaking with Nim's convention
##   of using truncated division (rounding toward zero, like in C).
##
##   When both operands are positive there is no difference between the two.
##
##   But for negative numbers, floored division makes a lot more sense when
##   we consider the modulus (or remainder) operation. Remember that integer division
##   and modulus is strongly related by `n == (n div k) * k + (n mod k)`.
##
##   Under floored division the sign of `mod` matches the sign of its second
##   operand, for example `-1 % 5 == 4`, which is more often the desired result.
##   Whereas under truncated division the sign would propagate as with
##   multiplication: `-1 % 5 == -1`, making it useless for doing modular arithmetic.
##
##   Another reasonable alternative is Euclidean division, which guarantees that
##   the remainder is *always* positive, and rounds the quotient accordingly, but
##   it is technically not as efficient at a low level.
##

## .. [#rng] Even though I personally think it's rather inflexible. Don't get me
##   wrong, xoroshiro128+ is a much better universal RNG than the Mersenne
##   Twister that many languages use, but it vulnerable if it can be put in a
##   state with few bits set. I personally prefer an RNG in the PCG family for
##   non-crypto and ChaCha for cryptographic RNG.
##
## .. [#ugly] The keyword operators are special cased in the language, and there's
##   no way to customize precedence rules. For example, as far as I know,
##   there's no way to make anything share precedence with the constructs `and` or `or`,
##   nor is there a way to make assignment-operator versions of those.
##
##   Originally I experimented with using the less noisy ``:`` as a prefix
##   instead. But then it turns out that they would have lower precedence than
##   comparison operators, which creates its own chaos, as intuitive expressions
##   like `x :& 0xf == 1` wouldn't parse correctly.
##
##   Even so the headache is not over, as `not` now has lower precedence than
##   the ``&..`` operators, so it also needed to be made into a symbolic
##   operator.
##
##   It's a bit of a mess.
##

from ./integers/misc import unsignedAbs, toUnsigned, bitsof
export misc

import ./integers/core
export core

import ./integers/common
export common

import ./integers/modular
export modular

import integers/bitset
export bitset

import ./integers/math
export math

import ./integers/format
export format

import ./integers/bytes
export bytes

import ./integers/primes
export primes

# import ./integers/random
# export random

import ./integers/modular
export modular
