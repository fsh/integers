
import unittest

import std/[macros, strformat]

import pkg/integers

# Skip some tests below otherwise it takes too long and
# Nim compiler seems to want to allocate many gigabytes of memory.
# 
template testSigned(op, a, b, ans: untyped): untyped =
  # when abs(a) < 128:
  #   check op(int8(a), newInteger(b)) == ans
  # when a in int16.low .. int16.high:
  #   check op(int16(a), newInteger(b)) == ans
  check op(int32(a), newInteger(b)) == ans
  check op(int64(a), newInteger(b)) == ans
  check op(int(a), newInteger(b)) == ans
  when b in int8.low .. int8.high:
    check op(newInteger(a), int8(b)) == ans
  # when b in int16.low .. int16.high:
  #   check op(newInteger(a), int16(b)) == ans
  # check op(newInteger(a), int32(b)) == ans
  # check op(newInteger(a), int64(b)) == ans
  check op(newInteger(a), int(b)) == ans
  check op(newInteger(a), newInteger(b)) == ans

template testUnsigned(op, a, b, ans: untyped): untyped =
  # when a < 256:
  #   check op(uint8(a), newInteger(b)) == ans
  # when a <= uint16.high:
  #   check op(uint16(a), newInteger(b)) == ans
  check op(uint32(a), newInteger(b)) == ans
  check op(uint64(a), newInteger(b)) == ans
  check op(uint(a), newInteger(b)) == ans
  when int(b) <= int(uint8.high):
    check op(newInteger(a), uint8(b)) == ans
  # when b <= uint16.high:
  #   check op(newInteger(a), uint16(b)) == ans
  # check op(newInteger(a), uint32(b)) == ans
  # check op(newInteger(a), uint64(b)) == ans
  check op(newInteger(a), uint(b)) == ans

template testAllTypes(op, a, b, ans: untyped): untyped =
  testSigned(op, a, b, ans)
  testUnsigned(op, a, b, ans)

suite "integer basics":

  test "init":
    check 3'gmp is Integer
    check 3'gmp == newInteger(3)
    check 3'gmp == newInteger("3")
    check 3'gmp == newInteger("11", 2)
    check 3'gmp == newInteger("0b11")
    check 0x10'gmp == 0b1_0000'gmp

    check newInteger("ff", 16) == 255
    check newInteger("10_000") == 10000

    let x: Integer = 3
    check x is Integer and x == 3

    check 3.toInteger is Integer

  test "sanity":
    let
      zero = Integer.zero
      one = Integer.one
      two = one + one
      three = two + one

    check one + one == two
    check -one + one == zero
    check one - one * two == two - three
    check one < two
    check two <= two
    check two >= one
    check two > one
    check two * three - one == two * two + one
    check three div two == one
    check three mod two == one
    check cmp(one, two) < 0
    check cmp(two, two) == 0
    check abs(-one) == one
    check one != two

  test "formatting":
    let n = 17'gmp

    check $n == "17"
    check &"{n}" == "17"
    check &"{n:x}" == "11"
    check &"{n:b}" == "10001"

    check &"{n:6x}" == "    11"
    check &"{n:06x}" == "000011"
    check &"{n:<6x}" == "11    "

  test "arithmetic type absorption":
    testAllTypes(`+`, 7, 3, 10)
    testAllTypes(`-`, 7, 3, 4)
    testAllTypes(`*`, 7, 3, 21)
    testAllTypes(`div`, 17, 3, 5)
    testAllTypes(`//`, 17, 3, 5)
    testAllTypes(`mod`, 17, 5, 2)
    testAllTypes(`%`, 17, 5, 2)
    testAllTypes(`<`, 2, 1, false)
    testAllTypes(`<`, 1, 2, true)
    testAllTypes(`!=`, 1, 2, true)

  test "fma":
    var n = 2'gmp

    n.addMul(3'gmp, 5'gmp)
    check n == 17
    n.subMul(2'gmp, 5'gmp)
    check n == 7
    n.addMul(-2, 3'gmp)
    check n == 1
    n.subMul(2'gmp, -3)
    check n == 7
    n.subMul(2, 3'gmp)
    check n == 1
    n.addMul(2'gmp, 3)
    check n == 7
    n.subMul(-2, 2'u)
    check n == 11
    n.addMul(2'u8, -2)
    check n == 7


suite "special ops":

  test "magnitude ops":
    testSigned(`==%`, 3, -3, true)
    testSigned(`!=%`, 3, -3, false)
    testSigned(`<%`, 3, -4, true)
    testSigned(`<=%`, 3, -3, true)
    testSigned(`>=%`, -3, -4, false)
    testSigned(`>%`, -3, -4, false)

  test "exponentiation":
    check 2 ^ 10 is Integer
    check 2 ^ 10 == 1024

    testAllTypes(`^`, 2, 96, 0x1_0000_0000_0000_0000_0000_0000'gmp)

    testAllTypes(`^`, 2, 3, 8)

  test "modular":
    let m = 2 ^ 90

    for p in [17, 257, 65537]:
      check powMod(2, 90, p) == m % p
      check powMod(2, 90, p.toInteger) == m % p
      check powMod(2, 90'gmp, p) == m % p
      check powMod(2'gmp, 90, p) == m % p

      check powMod(2, -90, p) * m % p == 1
      check invMod(3, p) * 3 % p == 1
      check invMod(3'gmp, p) * 3 % p == 1

  test "bitops":
    testAllTypes(`&^`, 0xdead, 0xde00, 0x00ad)
    testAllTypes(`&&`, 0xdead, 0xf0f0, 0xd0a0)
    testAllTypes(`&|`, 0xd00d, 0xf520, 0xf52d)

    testAllTypes(`&>>`, 0xabcd, 4, 0xabc)
    testAllTypes(`&<<`, 0xabcd, 4, 0xabcd0)

    check ~0xf0'gmp && 0xfff == 0xf0f

  test "integer access":
    const n = 123_000_000_777_999_001 # 57 bit number

    var bign = newInteger(n)

    check bign.getOr(0'u64) == uint64(n)
    check bign.getOr(0) is int
    check bign.getOr(0) == n

    check bign.getUnsafe(uint64) is uint64
    check bign.getUnsafe(int) == n

    check bign.getOr(-1'i8) == -1
    check bign.getOr(-1'i16) == -1
    check bign.getOr(-1'i32) == -1

    bign.assign(-10)

    check bign.getOr(0'u) == 0
    check bign.getOr(0) == -10

  test "divisible":
    check not (3'gmp).divisible(2)
    check (3'gmp).divisible(3)
    check not (3'gmp).divisible(2'gmp)
    check (3'gmp).divisible(3'gmp)
    check (1070111000^10).divisible(1070111000)

    check (2^64 - 1).divisible(0xffff_ffff)

  test "divMod":
    check divMod(19999, 177) == (19999'gmp div 177, 19999'gmp mod 177)

    check divMod(19999, -17) == (19999'gmp div -17, 19999'gmp mod -17)

  test "assignment ops":
    template impl(T: untyped) =
      var x = newInteger()
      x += T(1)
      check x == 1
      x &^= T(8)
      check x == 9
      x *= T(9)
      check x == 81
      x -= T(70)
      check x == 11
      x %= T(7)
      check x == 4
      x //= T(3)
      check x == 1
      x &|= T(6)
      check x == 7
      x &&= T(4)
      check x == 4

    impl(uint)
    impl(int)
    impl(newInteger)

