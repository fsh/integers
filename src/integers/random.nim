
import std/random
export random

import ./gmp
import ./misc

import ./core
export core

import ./bitset
import ./bytes
import ./primes


proc setRandBits*(rng: var Rand, dest: var Integer, bits: int) =
  ## In-place version of `randBits`_.
  if bits < 0:
    raise newException(ValueError, "`bits` cannot be negative")
  if bits == 0:
    dest = 0
    return

  var bits = bits
  let nwords = (bits + 63) div 64
  var data = newSeqOfCap[uint64](nwords)

  while bits >= 64:
    data.add(rng.next())
    bits -= 64
  if bits > 0:
    data.add(rng.next() shr (64 - bits))

  dest = newInteger(data, woLSF)

proc randBits*(rng: var Rand, bits: int): Integer =
  ## Generate `bits` number of random bits and interpret this as an `Integer`_.
  ##
  rng.setRandBits(result, bits)


proc randBelow*(rng: var Rand, val: Integer): Integer =
  ## Random `Integer`_ less than the given number.
  if val <= 0:
    raise newException(ValueError, "need a positive argument")

  let bits = val.nbits()

  while true:
    rng.setRandBits(result, bits)
    if result < val:
      break

proc randPrimeBits*(rng: var Rand, bits: int, fixed: bool = false): Integer =
  ## Generate a random prime number with the given number of bits.
  ##
  ## If `fixed` is true the return value is guaranteed to be exactly `bits` in
  ## length, meaning the bit at index `bits-1` is always 1. Otherwise
  ## the upper bits are random.
  rng.setRandBits(result, bits)
  if fixed:
    result[bits-1] = true
  result.setNextPrime()

func randGermainPrime*(rng: var Rand, bits: int, fixed: bool = false): Integer =
  ## Generates a random Sophie Germain prime with the given number of bits.
  ##
  ## Sophie Germain primes means that `(p - 1) div 2` is also prime.
  ##
  ## If `fixed` is true the return value is guaranteed to be exactly `bits` in
  ## length, meaning the bit at index `bits-1` is always 1. Otherwise
  ## the upper bits are random.
  runnableExamples:

    import integers
    var rng = initRand(1)

    let p = rng.randGermainPrime(20, fixed=true)
    assert p.nbits() == 20
    assert p.isPrime()
    assert ((p - 1) // 2).isPrime()

  if bits <= 3:
    raise newException(ValueError, "`bits` needs to be at least 3")

  while true:
    let q = rng.randPrimeBits(bits - 1, fixed)
    let p = (q &<< 1) + 1
    if p.isPrime():
      return p
