##
## Primes: Soul of the Integers
## ============================
##
##
##

import ./gmp
import ./core
export core

import ./bitset


# type
#   Factor*[T] = tuple[p: T, e: int]
#   SmallFactor* = Factor[int]


# const Primes1K = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53,
#                   59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113,
#                   127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181,
#                   191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251,
#                   257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317,
#                   331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397,
#                   401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463,
#                   467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557,
#                   563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619,
#                   631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701,
#                   709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787,
#                   797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863,
#                   877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953,
#                   967, 971, 977, 983, 991, 997]


func gcd*(a, b: Integer): Integer {.inline.} =
  ## Greatest common divisor.
  ##
  ## Returns the greatest number dividing both arguments. This is `1` if the numbers are co-prime.
  ##
  # XXX: specialize, gcd_ui
  mpz_gcd(result, a, b)

func extGcd*(a, b: Integer): (Integer, Integer, Integer) {.inline.} =
  ## Extended Euclidean algorithm for greatest common divisor.
  ##
  ## This returns `(g, x, y)` such that `a * x + b * y == g`. `g` is the
  ## GCD, `x` and `y` are known as the Bézout coefficients.
  ##
  runnableExamples:
    let (g, x, y) = extGcd(1020'gmp, 2022'gmp)
    assert 1020 * x + 2022 * y == g

  mpz_gcdext(result[0], result[1], result[2], a, b)

func lcm*(a, b: Integer): Integer {.inline.} =
  ## Least common multiplier.
  ##
  ## Returns the smallest number divisible by both arguments. This is `a * b` if the numbers are co-prime.
  ##
  # XXX: specialize, lcm_ui
  mpz_lcm(result, a, b)


func isPrime*(val: AnyInteger, reps: int = 1): bool =
  ## Checks if the given number is prime.
  ##
  ## This function ignores the sign.
  ##
  ## For large numbers it technically only checks for pseudoprimes with BPSW,
  ## but no pseudoprime that passes this test has ever been found, even though
  ## they're hypothesized to exist.
  ##
  ## `reps` determines how many additional Miller-Rabin rounds to run. (Defaults
  ## to 1.)
  when val is not Integer:
    let val = newInteger(val)
  mpz_probab_prime_p(val, (24 + reps).cint) != 0


func nextPrime*[T: AnyInteger](val: T): T =
  ## Returns the next prime higher than the given number.
  ##
  ## The return value will be the same type as the base number, but if the next
  ## prime does not fit in the type, a defect will be raised.
  runnableExamples:
    assert 100.nextPrime() == 101
    assert 101.nextPrime() == 103
    assert (2^400).nextPrime() == 2^400 + 181

  when T is Integer:
    mpz_nextprime(result, val)
  else:
    var val = newInteger(val)
    mpz_nextprime(val, val)
    result = val.getUnsafe(T)

func setNextPrime*(val: var Integer) {.inline.} =
  ## In-place version of `nextPrime`_.
  mpz_nextprime(val, val)


func prevPrime*[T: AnyInteger](n: T): T =
  ## Returns the previous prime lower than the given number. Negative numbers do
  ## not count.
  ##
  ## This function is a bit of a hack based on `nextPrime`_. I expect it to
  ## be roughly twice as slow.
  ##
  ## Raises an exception if there's no previous prime (e.g. `n <= 2`).
  ##
  runnableExamples:
    assert 100.prevPrime() == 97
    import integers/format
    assert (2^400).prevPrime() == 2^400 - 593

  if n <= 2:
    raise newException(ValueError, "no previous prime")

  when n isnot Integer:
    let n = newInteger(n)

  var k = n.nbits()
  var cand: Integer
  while true:
    cand.assign(n)
    cand -= k
    cand.setNextPrime()
    if cand < n:
      break
    k += k

  var nc: Integer
  while cand < n:
    mpz_nextprime(nc, cand)
    if nc > n:
      return cand.getUnsafe(T)
    swap(nc, cand)


# proc primesBelow*(n: int): seq[int] =
#   result.add(2)

#   let size = (n - 2) shr 1
#   var bitset = Integer.bit(size) - 1

#   var idx = bitset.scanOne() # technically bitset could be 0

#   while idx != -1:

#     let prime = idx * 2 + 3
#     result.add(prime)

#     var pos = (prime * prime - 3) shr 1
#     while pos < size:
#       bitset[pos] = false
#       pos += prime

#     idx = bitset.scanOne(idx + 1)

# func trialDivision*[T](val: sink Integer, upto: T): (Integer, seq[Factor[T]]) =
#   # XXX prime wheeeeeel
#   var p = initInteger(2)
#   while p < upto:
#     let e = val.setDivExp(p)
#     if e != 0:
#       result[1].add( (p.getUnsafe(int), e) )
#     p.setNextPrime()
#   result[0] = val
