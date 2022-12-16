 
# Integers
 
This package simply aims to provide *integers* (also known as "bigints,"
"bignums," "arbitrary precision integers," "true integers," and so on) by
wrapping GMP in a nice ergonomic way for Nim.

See the [generated documentation](https://fsh.github.io/integers/integers.html)
for the most up-to-date and complete information. Some parts of it has been
copied below, *but this README is incomplete*.


## Basics

`Integers` can be conveniently written as literals directly in Nim code with
the postfix `'gmp`. They can also be instantiated via `newInteger`. A rich
set of conversions from string and bytes also exist. The usual suspects like
`$` and so on will also work.


``` nim

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
  # and interpretation. See documentation under `integers/bytes`.
  let f = newInteger([255'u8, 1, 2], woMSF)
  assert f == 0xff0102'gmp
  assert f.toBytes(woLSF) == @[2'u8, 1, 255]

  assert $x == "101"

  import std/strformat
  assert &"{z:010b}" == "0001000101"
```


### Arithmetic

Ordinary arithmetic operations `+`, `-`, `*`, `div`, `mod` should work as
expected. The same goes for comparison operators, `==`, `!=`, `<=`, `<`, and
so on.

Most operators can be used with any integer operands. That is, as long as at
least one operand is an `Integer` the other operand can be of type
`AnyInteger` (a GMP `Integer` or any primitive fixed-size integer, like
`int` or `uint8`). This might look like auto-promotion, but in code
there's specializations to make it more efficient, as GMP often has
specialized routines for handling fixed-sized arguments.

In general, doing operations the natural way with primitive integers tends to
be more efficient than forcing everything to be `Integer` ahead of time.
That is, prefer `x + 1`, over `x + 1'gmp`.

```nim


  let five = 5'gmp

  assert five * 5 == 25
  assert 5'u64 + five == 10'i8

  var n = Integer.one

  for i in 1 .. 32:
    n *= i

  assert n == factorial(32)

```


Exponentiation is implemented as `^`. It works for any combination of
integer arguments, but the result is always an `Integer`.

Another primitive operation is `divMod` which does the same as `(x div y, x
mod y)` but more efficiently. See `math and number theory` for a lot more.

``` nim


  assert 2^1000 == 2^500 * 2^500

  assert divMod(3^100, 40) == (3^100 div 40, 1'gmp)

```

### Comparisons

In addition to the normal comparison operators (`==`, `!=`, `<=`, `<`, etc.), there's
also an equivalent set of *absolute* comparisons, using a suffix ``%``.

- `x ==% y` is equivalent to `abs(x) == abs(y)`
- `x !=% y` is equivalent to `abs(x) != abs(y)`
- `x <% y` is equivalent to `abs(x) < abs(y)`
- `x >=% y` is equivalent to `abs(x) >= abs(y)`
- ... and so on.

For very simple domain checks there's also a number of
universal functions that are designed to be as lightweight as humanly
possible (they guarantee no external function call will be made into the GMP
library).

- `isZero(AnyInteger): bool`
- `isNonZero(AnyInteger): bool`
- `isPositive(AnyInteger): bool`
- `isNegative(AnyInteger): bool`
- `isNatural(AnyInteger): bool`: if a number is greater than or equal to 0, i.e. it's non-negative.

``` nim

  assert -1'gmp ==% 1
  assert 2 <% -20

  assert 0.isZero
  assert uint64.one.isNonZero
  assert 10'gmp.isNatural

```

## Mutability

For reasons of efficiency, `Integer`s are *mutable*.

Every time a new non-zero `Integer` is instantiated a heap allocation occurs
(in GMP), thus it is usually more efficient to re-use variables if possible.
As such this package provides a cornucopia of in-place and assignment
operators.

As such there's a lot of in-place and assignment operators provided.

Note that Nim weirdly does not have an assignment operator equivalent of
`div`, `mod`, `and`, `xor`, etc. So operators have been added to make up for
this fact.

For example:

- `//` can be used instead of `div`, with `//=` being the assignment operator.
- `%` can be used instead of `mod`, with `%=` being the assignment operator.

See also `bit operations` for more such operator aliases.

The in-place version of unary `-` is `setNegative`.

There is also `addMul` and `subMul` which are trinary operators that does
fused multiply-and-add or multiply-and-sub. If you are writing something like
`x += y * z` it is usually more efficient to use `x.addMul(y, z)` instead.

``` nim

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
```


## Bit Operations

For reasons mentioned in `mutability`, the bit operators have also been
given symbolic aliases. These all use ``&`` as a prefix:

- `&&`, `&&=` bitwise AND (`and` can also be used)
- `&|`, `&|=` bitwise OR (`or` can also be used)
- `&^`, `&^=` bitwise XOR (`xor` can also be used)
- `&>>`, `&>>=` shift bits right (`shr` can also be used)
- `&<<`, `&<<=` shift bits left (`shl` can also be used)
- `~` does bitwise NOT (`not` can also be used). The in-place version of this is `setNot`.

*I agree this is rather ugly but it's the best I could do within
Nim. The keyword operators are special cased in the language, and there's
no way to customize precedence rules. (For example, as far as I know,
there's no way to make anything have the same precedence as `and` or `or`,
nor to make assignment-operator versions of those.)*

*Originally I experimented with using the less noisy ``:`` as a prefix
instead. But then it turns out that they would have lower precedence than
comparison operators, which creates its own chaos, as intuitive expressions
like `x :& 0xf == 1` wouldn't parse correctly.*

*Even so the headache is not over, as `not` now has lower precedence than
the ``&..`` operators, so it also needed to be made into a symbolic
operator.*

*It's a bit of a mess.*

*Although these operations also work on regular primitive integers,
the result is always an `Integer` (might change?), so they're not
recommended for regular use.*

``` nim

  assert 0xff &^ 0x0f == 0xf0
  assert 3 &<< 100 == 2^100 * 3

  assert 4^10 &>> 2 == 4^9

  let z = 0xff01'gmp

  assert ~z && 0xff == 0xfe

```

### Bit Sets


As a *radical convenience*, `Integer`s can be treated directly as implementing
fast dynamic bitsets.

If you think about it, arbitrary precision integers and dynamically sized
bitsets are usually built upon the same core data structure, but differ only
in exposed functionality (with the bitsets having a vastly simpler API and
implementation of course).

As such, `Integer`s can be indexed, iterated over, they have a `size` and a `count`,
and so on.
The above bit operations can be used to do unions, intersections, et cetera.

The indexing operator `[]` returns `true` or `false` depending on
whether the given bit is `1` or `0`. Likewise, `[]=` can be used to set
arbitrary bits.

`count(n)` gives the total number of bits set to 1.

`scanOne(n, [pos])` and `scanZero(n, [pos])` finds the first 1- or 0-bit at or after
the given position.

`size(n)` (an alias for `nbits(n)`) gives the total number of bits
required to express the absolute value of `n`.

And finally, iterating over an `Integer` will loop over the indices of its
1-bits. See XXX for more ## information.

``` nim

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

```

## And So On...


Again, see the [generated documentation](https://fsh.github.io/integers/integers.html) for
more information.


### Caveats

- The biggest caveat currently is that this is *entirely untested on Windows,
  OSX, and 32-bit platforms (any OS)*. It will probably work on OSX, but it's
  likely to fail on Windows without some modifications. Feedback is desired.

- There's an underlying assumption that GMP is compiled with "nails" set to 0.
  I think this is true for GMP distributed on all modern platforms.

- I also take some shortcuts and skip out on explicitly calling `mpz_init` most
  of the time, assuming that Nim's zero-initialization and `mpz_init` are
  equivalent. As far as I know this is true in all GMP versions I've seen on all
  relevant platforms. However if it turns out this breaks functionality on a
  major platform, do file a bug report.

- There's a more serious assumption that `sizeof(mp_limb_t) == sizeof(uint)`
  (i.e. that the limb-size matches Nim's default int size), which might
  practically break on some platforms. However, it should be easy to fix if
  someone can show me how to "import" a pure `typedef` from a header file in
  Nim.

### Why GMP?

Unfortunately there is just no beating GMP when it comes to performance. It
is the unequivocal gold standard.

All "home-made" or "from scratch" integer implementations by hobbyists, such
as Nim's official `bigints` (and even Python's built-in `int`) are *laughably
slow* compared to GMP, often on the order of magnitudes.

Alternative projects such as `libtomath` come much closer, but are still not
quite as optimized as GMP.

The reason projects shy away from GMP is two-fold:

- The "serious" reason is that GMP is dual-licensed with LGPLv3 and GPLv2,
  and many consider even the LGPL too restrictive or convoluted (e.g. static
  linking can be problematic), so this makes it simply a no-go for many
  projects.

- The less practical reason is that implementing one's own arbitrary
  precision integers from scratch is (at the onset) a very attractive and
  exciting project for many programmers, so it is a common mind trap to fall
  into.

The first reason is unavoidable and unfortunate. The second reason is very
*understandable* (I feel the same pull), although it is incredibly
frustrating when I'm stuck with these cowboy implemenations as a user.

Since I am of the opinion that (big) integers is a *core* data type that
should be universally available, thus also implicitly demanding it should be
*as efficient as humanly possible*, I'm always going to bite the bullet on
the (L)GPL license.
