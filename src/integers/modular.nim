
import ./gmp
import ./core
export core


func invMod*(a, m: distinct AnyInteger): Integer {.inline.} =
  ## Inverse of `a` under modulus `m`.
  ##
  ## If returns `0'gmp` if the inverse does not exist.
  ##
  ## See `setInvMod`_ for in-place version.
  ##
  runnableExamples:
    let x = 1000'gmp.invMod(1999)
    assert x * 1000 % 1999 == 1

  # XXX: specialize
  when a isnot Integer:
    let a = newInteger(a)
  when m isnot Integer:
    let m = newInteger(m)
  if mpz_invert(result, a, m) == 0:
    # Failed to invert.
    result.initInteger()

func setInvMod*(a: var Integer, m: Integer) {.inline.} =
  ## Sets `a` to its inverse under modulus `m`.
  ##
  ## If returns `0'gmp` if the inverse does not exist.
  ##
  ## See `invMod`_ for functional version.
  ##
  if mpz_invert(a, a, m) == 0:
    # Failed to invert.
    a.initInteger()

func powMod*(a, exp, m: distinct AnyInteger): Integer {.inline.} =
  ## Returns `a` to the power of `exp` modulus `m`, that is `a^exp (mod m)`.
  ##
  ## Arguments can be of any integer type.
  ##
  ## `exp` can be negative if `a` is invertible (i.e. `gcd(a, m) == 1`).
  ##
  ## See `setPowMod`_ for in-place version.
  ##
  runnableExamples:
    assert powMod(10, 10_000_000_000_000_000_000'gmp, 99) == 1
    assert powMod(10, 10_000_000_000_000_000_001'gmp, 99) == 10

  # XXX: specialize
  when a isnot Integer:
    let a = newInteger(a)
  when m isnot Integer:
    let m = newInteger(m)
  when exp is Integer:
    mpz_powm(result, a, exp, m)
  else:
    mpz_powm_ui(result, a, exp.unsignedAbs().culong(), m)
    when exp is SomeSignedInt:
      if exp < 0:
        result.setInvMod(m)

func setPowMod*(result: var Integer, exp: AnyInteger, m: Integer) {.inline.} =
  ## Raises `a` to the power of `exp` modulus `m`, that is `a = a^exp (mod m)`.
  ##
  ## Arguments `exp` and `m` can be of any integer type.
  ##
  ## `exp` can be negative if `a` is invertible (i.e. `gcd(a, m) == 1`).
  ##
  ## See `powMod`_ for functional version.
  ##
  runnableExamples:
    assert powMod(10, 10_000_000_000_000_000_000'gmp, 99) == 1
    assert powMod(10, 10_000_000_000_000_000_001'gmp, 99) == 10
  when exp is Integer:
    mpz_powm(result, result, exp, m)
  else:
    mpz_powm_ui(result, val, exp.unsignedAbs().culong(), m)
    when exp is SomeSignedInt:
      if exp < 0:
        result.setInvMod(m)



# iterator count[T](start: T): T {.inline.} =
#   var i = start
#   while true:
#     yield i
#     i.inc

# iterator iterPrimes[T](span: Slice[T]): T {.inline.} =
#   for i in span:
#     if i.isPrime():
#       yield i

# type
#   Factor[T] = tuple[p: T, e: int]
#   SmallFactor = Factor[int]

# func trialDivision*(val: sink Integer, upto: int): (Integer, seq[SmallFactor]) =
#   # XXX prime wheeeeeel
#   var p = newInteger(2)
#   while p < upto:
#     let e = val.setDivExp(p)
#     if e != 0:
#       result[1].add( (p.getUnsafe(int), e) )
#     p.setNextPrime()
#   result[0] = val



# proc probPrimitiveRoot*(p: Integer, limit: int = 100): Integer =
#   # AssertNatural(p)
#   # AssertPrime(p)

#   template orderSearch(pi, e: typed) {.dirty.} =
#     let exp = m div pi
#     var v: Integer

#     while true:
#       v.assign(gi)
#       v.setPowMod(exp, p)
#       if v != 1:
#         break
#       gi.inc

#     if e != 1:
#       v.assign(gi)
#       v.setPowMod(m div pi^e, p)

#     result *= v
#     result %= p

#   let m = p - 1
#   let (q, ps) = m.trialDivision(limit)

#   result = newInteger(1)
#   var gi = 2

#   for (pi, e) in ps:
#     orderSearch(pi, e)

#   # result so far has guaranteed order prod(ps)

#   if q != 1:
#     orderSearch(q, 1)
