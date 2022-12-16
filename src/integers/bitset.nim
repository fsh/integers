
import ./gmp
import ./core
export core

import misc

template imm_op_promote(name, op: untyped): untyped =
  proc name*(x: var Integer, y: AnyInteger) {.inline.} =
    # XXX: we could specialize this manually, by performing the bitop against
    # the first limb...?
    when y isnot Integer:
      let y = newInteger(y)
    op(x, x, y)

imm_op_promote(`&&=`, mpz_and)
imm_op_promote(`&|=`, mpz_ior)
imm_op_promote(`&^=`, mpz_xor)

template comm_op_promote(name, op: untyped): untyped =
  proc name*(x, y: distinct AnyInteger): Integer {.inline.} =
    # XXX: we could specialize this manually, by performing the bitop against
    # the first limb...?
    when x isnot Integer:
      let x = newInteger(x)
    when y isnot Integer:
      let y = newInteger(y)
    op(result, x, y)

comm_op_promote(`&&`, mpz_and)
comm_op_promote(`&|`, mpz_ior)
comm_op_promote(`&^`, mpz_xor)

comm_op_promote(`and`, mpz_and)
comm_op_promote(`or`, mpz_ior)
comm_op_promote(`xor`, mpz_xor)

template op_bitshift(op1, op2, immop, op_gmp: untyped): untyped =
  func op1*(val: Integer, n: SomeUnsignedInt): Integer {.inline.} =
    op_gmp(result, val, mp_bitcnt_t(n))
  func op2*(val: Integer, n: SomeUnsignedInt): Integer {.inline.} =
    op_gmp(result, val, mp_bitcnt_t(n))
  func immop*(val: var Integer, n: SomeUnsignedInt) {.inline.} =
    op_gmp(val, val, mp_bitcnt_t(n))

op_bitshift(`shr`, `&>>`, `&>>=`, mpz_tdiv_q_2exp)
op_bitshift(`shl`, `&<<`, `&<<=`, mpz_mul_2exp)



func nbits*(val: Integer): int {.inline.} =
  ## Returns the number of bits needed to represent the absolute value of the
  ## given integer.
  ##
  ## Returns 0 in the special case of zero.
  ##
  ## Equivalent to `floor(log2(n)) + 1` for positive numbers.
  ##
  ## Equivalent to Python's `int.bit_length()`.
  ##
  runnableExamples:
    assert nbits(10'gmp) == 4
    assert nbits(0'gmp) == 0 # special case
    assert nbits(1'gmp) == 1
    assert nbits(255'gmp) == 8
    assert nbits(256'gmp) == 9

  if val.isZero: 0 else: val.mpz_sizeinbase(2).int


func size*(val: Integer): int {.inline.} =
  ## Alias for `nbits`_.
  nbits(val)


func count*(val: Integer): int {.inline.} =
  ## Returns the number of 1-bits set.
  ##
  ## Also known as "popcount" or "Hamming weight."
  runnableExamples:
    assert count(10'gmp) == 2
    assert count(0'gmp) == 0
    assert count(256'gmp) == 1

  mpz_popcount(val).uint.toSigned()


func bit*(_: typedesc[Integer], idx: SomeInteger): Integer {.inline.} =
  ## Returns an `Integer <core.html#Integer>`_ consisting of a single 1-bit at the given index.
  mpz_setbit(result, mp_bitcnt_t(idx))


func `~`*(val: Integer): Integer {.inline.} =
  ## Bitwise NOT.
  ##
  ## Note that this is equivalent to `-(x+1)` as GMP integers' behave
  ## as if they are two's-complement of infinite size.
  ##
  mpz_com(result, val)

func `not`*(n: Integer): Integer {.inline.} =
  ## Alias for `~`_.
  ~n

func setNot*(n: var Integer) {.inline.} =
  ## In-place bitwise NOT operation.
  mpz_com(n, n)


proc scanOne*(val: Integer, start: int = 0): int =
  ## Returns the index of first 1-bit on or after the given optional index
  ## (defaults to 0).
  ##
  ## Indices run from least significant to most significant.
  ##
  ## Returns -1 if no bits are set after the given index.
  ##
  ## Note that negative numbers behave as if they have an infinite number of 1-bits.
  ##
  runnableExamples:
    assert 11.scanOne() == 0
    assert 8.scanOne() == 3
    assert 4.scanOne(3) == -1
    assert (-2).scanOne(100) == 100 # 0b..∞..11111110

  mpz_scan1(val, start.mp_bitcnt_t()).uint.toSigned()

proc scanZero*(val: Integer, start: int = 0): int =
  ## Returns the index of first 0-bit on or after the given optional index
  ## (defaults to 0).
  ##
  ## Indices run from least significant to most significant.
  ##
  ## Returns -1 if all bits are set after the given index (can only happen with negative numbers).
  ##
  runnableExamples:
    assert 11.scanZero() == 2
    assert 8.scanZero(1) == 1
    assert (-1).scanZero() == -1

  mpz_scan0(val, start.mp_bitcnt_t()).uint.toSigned()


func `[]`*(val: Integer, idx: int): bool {.inline.} =
  ## Returns the state of the bit at the given index as a boolean.
  ##
  ## Uses two's-complement semantics.
  ##
  mpz_tstbit(val, mp_bitcnt_t(idx)).bool


func `[]=`*(n: var Integer, idx: int, bit: bool) {.inline.} =
  ## Sets the bit of `n` at the given index `idx` to 0 (false) or 1 (true).
  if bit:
    mpz_setbit(n, mp_bitcnt_t(idx))
  else:
    mpz_clrbit(n, mp_bitcnt_t(idx))


func `[]=`*(n: var Integer, idx: int, bit: static[bool]) {.inline.} =
  ## Sets the bit of `n` at the given index `idx` to 0 (false) or 1 (true).
  when bit:
    mpz_setbit(n, mp_bitcnt_t(idx))
  else:
    mpz_clrbit(n, mp_bitcnt_t(idx))



iterator items*(n: Integer): int {.inline.} =
  ## Iterates over the positions of 1-bits in the given `Integer <core.html#Integer>`_ `n`, going
  ## from least significant to most significant.
  ##
  ## For example `for i in 10'gmp` would repeat the loop body twice, first with
  ## `i=1` followed by `i=3`, as `10 = 2^1 + 2^3`.
  ##
  ## .. note:: Giving a negative number yielsds an *infinte loop* of ever-increasing indices,
  ##   negative numbers act as if they're two's-complement of infinite size.
  ##
  var idx = n.scanOne()
  while idx != -1:
    yield idx
    idx = n.scanOne(idx + 1)
