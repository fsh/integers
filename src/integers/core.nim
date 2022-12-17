## Core Integer Functionality
## ==========================
##
## Defines the types, initialization, and most of the basic arithmetic.
##

import ./misc
import ./gmp



const ALLOW_IMPLICIT_PROMOTE = true ## Turns on implicit conversion from primitive integers to GMP Integer.
# const VERIFY_PRIMES = true



type
  Integer* = ## Represents an arbitrary precision integer.
    ##
    ## Essentially just an alias for GMP's
    ## signed-magnitude implementation.
    ##
    ## These are meant to be allocated on the stack, roughly 16 bytes in size on
    ## 64-bit platforms. They use a `byref` pragma, so no need to indicate
    ## passing by pointer anywhere. They contain a pointer to heap memory
    ## managed by GMP for the limbs, so actually copying the memory is
    ## dangerous.
    mpz_struct

  AnyInteger* = ## Like `SomeInteger` but also covers the `Integer`_ case.
    SomeInteger | Integer

# ::: INITIALIZATION :::

proc initInteger*(res: var Integer) {.inline.} =
  ## Sets `res` to the `Integer`_ `0`.
  mpz_init(res)

proc newInteger*(): Integer {.inline.} =
  ## Returns the `Integer`_ `0`.
  mpz_init(result)

proc newInteger*(val: SomeInteger): Integer {.inline.} =
  ## Promotes a primitive integer to an `Integer`_.
  when val is SomeSignedInt:
    mpz_init_set_si(result, val.clong)
  else:
    mpz_init_set_ui(result, val.culong)

proc newInteger*(str: string, base: int = 0): Integer {.inline.} =
  ## Parses the string as an `Integer`_.
  ##
  ## If `base` is 0 (the default) the base is auto-detected
  ## by checking for prefixes `"0x"`, `"0b"`, `"0o"`.
  ##
  ## Underscores can be used to separate digits.
  discard mpz_init_set_str(result, str.remove('_').cstring, base.cint)

proc newInteger*(val: Integer): Integer {.inline.} =
  ## Makes a fresh copy of the given `Integer`_.
  mpz_set(result, val)


when ALLOW_IMPLICIT_PROMOTE:
  converter toInteger*(x: SomeInteger): Integer {.inline.} =
    ## Any machine integer is implicitly convertible to an Integer (but most
    ## operations should have their own specialization).
    newInteger(x)


proc `'gmp`*(nstr: string): Integer {.inline.} =
  ## Allows for literal GMP integers, e.g. `16'gmp` and `0xff'gmp`.
  ##
  ## Prefix for base is auto-detected.
  newInteger(nstr)

# ::: FAST DOMAIN :::

func isZero*(val: AnyInteger): bool {.inline.} =
  ## Is the number zero?
  when val is Integer:
    val.mp_size == 0
  else:
    val == 0

func isNonZero*(val: AnyInteger): bool {.inline.} =
  ## Is the number non-zero?
  when val is Integer:
    val.mp_size != 0
  else:
    val != 0

func isNatural*(val: AnyInteger): bool {.inline.} =
  ## Is the number non-negative?
  when val is Integer:
    val.mp_size >= 0
  elif val is SomeUnsignedInt:
    true
  else:
    val >= 0

func isPositive*(val: AnyInteger): bool {.inline.} =
  ## Is the number positive?
  when val is Integer:
    val.mp_size > 0
  else:
    val > 0

func isNegative*(val: AnyInteger): bool {.inline.} =
  ## Is the number negative?
  when val is Integer:
    val.mp_size < 0
  elif val is SomeUnsignedInt:
    false
  else:
    val < 0

# :::

func assign*(result: var Integer, src: AnyInteger) {.inline.} =
  ## Assigns a value to a mutable Integer in-place.
  when src is Integer:
    mpz_set(result, src)
  elif src is SomeSignedInt:
    mpz_init_set_si(result, src.clong())
  else:
    mpz_init_set_ui(result, src.culong())


# ::: NIM-STYLE OPERATIONS :::

func inc*(n: var Integer) {.inline.} =
  ## Increase the number by 1.
  mpz_add_ui(n, n, culong(1))

func dec*(n: var Integer) {.inline.} =
  ## Decrease the number by 1.
  mpz_sub_ui(n, n, culong(1))

func succ*(n: Integer): Integer {.inline.} =
  ## Returns `n + 1`.
  runnableExamples:
    assert 10'gmp.succ == 11
  mpz_add_ui(result, n, culong(1))

func pred*(n: Integer): Integer {.inline.} =
  ## Returns `n - 1`.
  runnableExamples:
    assert 10'gmp.pred == 9
  mpz_sub_ui(result, n, culong(1))

# ::: COMPARISONS :::

template toUi(x: SomeSignedInt): untyped =
  x.unsignedAbs().culong()

template op_split2(op_si, op_ui: untyped; r, i: typed): untyped =
  when i is SomeSignedInt:
    op_si(r, i.clong())
  else:
    op_ui(r, i.culong())

func cmp*(a: Integer, b: AnyInteger): int {.inline.} =
  ## Returns a positive value if `a > b`, negative if `a < b`, and 0 if equal.
  when b is Integer:
    mpz_cmp(a, b).int
  else:
    op_split2(mpz_cmp_si, mpz_cmp_ui, a, b).int

func cmp*(a: SomeInteger, b: Integer): int {.inline.} =
  -cmp(b, a)

func cmpAbs*(a, b: distinct AnyInteger): int {.inline.} =
  ## Like `cmp` but compares absolute values.
  when a is Integer:
    when b is Integer:
      mpz_cmpabs(a, b).int
    elif b is SomeUnsignedInt:
      mpz_cmpabs_ui(a, b.culong()).int
    else:
      mpz_cmpabs_ui(a, b.toUi()).int
  elif b is Integer:
    -cmpAbs(b, a)
  # Neither is Integer
  else:
    cmp(a.unsignedAbs(), b.unsignedAbs())

template op_cmp(op, uop: untyped): untyped =
  func op*(a: SomeInteger, b: Integer): bool {.inline.} = op(cmp(a, b), 0)
  func uop*(a: SomeInteger, b: Integer): bool {.inline.} = op(cmpAbs(a, b), 0)
  func op*(a: Integer, b: SomeInteger): bool {.inline.} = op(cmp(a, b), 0)
  func uop*(a: Integer, b: SomeInteger): bool {.inline.} = op(cmpAbs(a, b), 0)
  func op*(a: Integer, b: Integer): bool {.inline.} = op(cmp(a, b), 0)
  func uop*(a: Integer, b: Integer): bool {.inline.} = op(cmpAbs(a, b), 0)

op_cmp(`==`, `==%`)
op_cmp(`!=`, `!=%`)
op_cmp(`<`, `<%`)
op_cmp(`<=`, `<=%`)
op_cmp(`>`, `>%`)
op_cmp(`>=`, `>=%`)


# ::: UNARY :::

func `-`*(a: sink Integer): Integer {.inline.} =
  ## Negates the number.
  result = a
  result.mp_size = -result.mp_size

func setNegative*(val: var Integer) {.inline.} =
  ## In-place change the sign of value.
  val.mp_size = -val.mp_size

func setAbs*(n: var Integer) {.inline.} =
  ## In-place version of `abs`_.
  n.mp_size = n.mp_size.abs

func abs*(n: sink Integer): Integer {.inline.} =
  ## Returns the absolute value of `n`.
  n.setAbs()
  n

# ::: ARITHMETIC :::

template si_split(op_neg, op_pos, r, x: untyped; i: SomeSignedInt): untyped =
  mixin toUi
  if i < 0:
    op_neg(r, x, i.toUi())
  else:
    op_pos(r, x, i.toUi())

template imm_op(name, op: untyped): untyped =
  proc name*(x: var Integer, y: Integer) {.inline.} =
    op(x, x, y)

template imm_op_ui_alt(name, op, op_ui, op_alt_ui: untyped): untyped =
  imm_op(name, op)
  proc name*(x: var Integer, i: SomeInteger) {.inline.} =
    when i is SomeUnsignedInt:
      op_ui(x, x, i.culong())
    else:
      si_split(op_alt_ui, op_ui, x, x, i)

template imm_op_ui_si(name, op, op_ui, op_si: untyped): untyped =
  imm_op(name, op)
  proc name*(x: var Integer, i: SomeInteger) {.inline.} =
    when i is SomeUnsignedInt:
      op_ui(x, x, i.culong())
    else:
      op_si(x, x, i.clong())

template imm_op_qr_ui(name, op, op_fui, op_cui: untyped; neg: static[bool]): untyped =
  imm_op(name, op)
  proc name*(result: var Integer, i: SomeInteger) {.inline.} =
    when i is SomeUnsignedInt:
      discard op_fui(result, result, i.culong())
    else:
      if i < 0:
        discard op_cui(result, result, i.toUi())
        when neg:
          result.setNegative()
      else:
        discard op_fui(result, result, i.toUi())

imm_op_ui_alt(`+=`, mpz_add, mpz_add_ui, mpz_sub_ui)
imm_op_ui_alt(`-=`, mpz_sub, mpz_sub_ui, mpz_add_ui)
imm_op_ui_si(`*=`, mpz_mul, mpz_mul_ui, mpz_mul_si)
imm_op_qr_ui(`//=`, mpz_fdiv_q, mpz_fdiv_q_ui, mpz_cdiv_q_ui, true)
imm_op_qr_ui(`%=`, mpz_fdiv_r, mpz_fdiv_r_ui, mpz_cdiv_r_ui, true)

template op_big(name, op: untyped): untyped =
  proc name*(x, y: Integer): Integer {.inline.} =
    op(result, x, y)

op_big(`+`, mpz_add)
op_big(`*`, mpz_mul)
op_big(`-`, mpz_sub)
op_big(`//`, mpz_fdiv_q)
op_big(`div`, mpz_fdiv_q)
op_big(`%`, mpz_fdiv_r)
op_big(`mod`, mpz_fdiv_r)

import std/macros

macro commutative(op, x, i, body: untyped): untyped =
  quote:
    proc `op`*(`i`: SomeInteger, `x`: Integer): Integer {.inline.} =
      `body`
    proc `op`*(`x`: Integer, `i`: SomeInteger): Integer {.inline.} =
      `body`

commutative(`+`, x, i):
  when i is SomeUnsignedInt:
    mpz_add_ui(result, x, i.culong())
  else:
    si_split(mpz_sub_ui, mpz_add_ui, result, x, i)

commutative(`*`, x, i):
  when i is SomeUnsignedInt:
    mpz_mul_ui(result, x, i.culong())
  else:
    mpz_mul_si(result, x, i.clong())

proc `-`*(x: Integer, i: SomeInteger): Integer {.inline.} =
  when i is SomeUnsignedInt:
    mpz_sub_ui(result, x, i.culong())
  else:
    si_split(mpz_add_ui, mpz_sub_ui, result, x, i)

proc `-`*(i: SomeInteger, x: Integer): Integer {.inline.} =
  when i is SomeUnsignedInt:
    mpz_ui_sub(result, i.culong(), x)
  else:
    si_split(mpz_add_ui, mpz_sub_ui, result, x, i)
    result.setNegative()

template noncomm_op_qr_ui(name, op_full, op_fui, op_cui: untyped; neg: static[bool]): untyped =
  proc name*(x: Integer, i: SomeInteger): Integer {.inline.} =
    when i is SomeUnsignedInt:
      discard op_fui(result, x, i.culong())
    else:
      if i < 0:
        discard op_cui(result, x, i.toUi())
        when neg:
          result.setNegative()
      else:
        discard op_fui(result, x, i.toUi())

  proc name*(i: SomeInteger, x: Integer): Integer {.inline.} =
    # XXX: specialize this further by using a check on the size of second
    # operand?
    let i = newInteger(i)
    op_full(result, i, x)

noncomm_op_qr_ui(`//`, mpz_fdiv_q, mpz_fdiv_q_ui, mpz_cdiv_q_ui, true)
noncomm_op_qr_ui(`div`, mpz_fdiv_q, mpz_fdiv_q_ui, mpz_cdiv_q_ui, true)
noncomm_op_qr_ui(`%`, mpz_fdiv_r, mpz_fdiv_r_ui, mpz_cdiv_r_ui, false)
noncomm_op_qr_ui(`mod`, mpz_fdiv_r, mpz_fdiv_r_ui, mpz_cdiv_r_ui, false)

# ::: FUSED ADD/SUB-MUL :::

template op_fma(name, op, op_ui, op_neg_ui: untyped): untyped =
  func name*(dest: var Integer; x, y: distinct AnyInteger) {.inline.} =
    when x is Integer:
      # Normal case: x is big, switch on size of y.
      when y is Integer:
        op(dest, x, y)
      elif y is SomeUnsignedInt:
        op_ui(dest, x, y.culong())
      else:
        si_split(op_neg_ui, op_ui, dest, x, y)
    elif y is Integer:
      # y is big, but x is small.
      name(dest, y, x)
    else:
      # Both are small.
      name(dest, x.toInteger, y)

op_fma(addMul, mpz_addmul, mpz_addmul_ui, mpz_submul_ui)
op_fma(subMul, mpz_submul, mpz_submul_ui, mpz_addmul_ui)

# ::: EXPONENTIATION :::

func `^`*(val, exp: distinct AnyInteger): Integer {.inline.} =
  when exp is SomeUnsignedInt:
    let exp = exp.culong()
  else:
    if exp < 0:
      raise newException(ValueError, "cannot use negative exponents with integers")
    when exp is Integer:
      if exp.mp_size > 1:
        raise newException(ValueError, "exponent too big!")
      let exp = exp.getUnsafe(culong)
    else: # Signed
      let exp = exp.toUi()
  when val is Integer:
    mpz_pow_ui(result, val, exp)
  elif val is SomeUnsignedInt:
    let val = val.culong
    mpz_ui_pow_ui(result, val, exp)
  elif val is SomeSignedInt:
    let absval = val.unsignedAbs().culong
    mpz_ui_pow_ui(result, absval, exp)
    # Negative numbers to odd power are negative.
    if val < 0 and (exp and 1) == 1:
      result.mp_size = -result.mp_size

# ::: CONVERSION :::

proc getUnsafe*(val: Integer, T: typedesc): T {.inline.} =
  ## Forces the integer to the given type.
  ##
  ## If the integer does not fit, something undefined will happen. The result
  ## might be wrong or an exception might be raised.
  ##
  when T is Integer:
    val
  elif T is SomeSignedInt:
    T(mpz_get_si(val))
  elif T is SomeUnsignedInt:
    T(mpz_get_ui(val))


proc getOr*[T: AnyInteger](val: Integer, defval: T): T {.inline.} =
  ## Given a default value of type `T`, attempt to convert the `Integer`_ `val`
  ## to this type and return it. If unsuccessful, the default value will be
  ## returned.
  ##
  runnableExamples:
    let x = 0x123'gmp

    assert x.getOr(0'u64) is uint64
    assert x.getOr(0'u64) == 0x123

    assert x.getOr(0'u8) == 0 # fails

  when T is Integer:
    val
  elif T is SomeUnsignedInt:
    if mpz_fits_ulong_p(val) == 0:
      defval
    else:
      let r = mpz_get_ui(val).uint64
      when sizeof(T) < sizeof(uint64):
        if r > T.high:
          defval
        else:
          T(r)
      else:
        T(r)
  elif T is SomeSignedInt:
    if mpz_fits_slong_p(val) == 0:
      defval
    else:
      let r = mpz_get_si(val).int64
      when sizeof(T) < sizeof(int64):
        if r < T.low or r > T.high:
          defval
        else:
          T(r)
      else:
        T(r)
  else:
    {. error "logic error" .}


template getOrDo*(val: Integer, T: typedesc, excbody: untyped): untyped =
  ## Tries to convert the `Integer`_ `val` to the given type `T`. If successful, it
  ## evaluates to this value.
  ##
  ## If it fails, the given code will execute instead. The code must either
  ## evaluate to a `T` itself, or be of type no-return (e.g. throw an
  ## exception).
  ##
  ## This macro mainly exists because Nim's support for ergonomic `Option[T]`-style
  ## programming is in a state of disgrace.
  ##
  when T is Integer:
    val
  elif T is SomeSignedInt:
    if mpz_fits_slong_p(val) == 0:
      excbody
    else:
      let r = mpz_get_si(val).int64
      when sizeof(T) < sizeof(int64):
        if r < T.low or r > T.high:
          excbody
        else:
          T(r)
      else:
        T(r)
  elif T is SomeUnsignedInt:
    if mpz_fits_ulong_p(val) == 0:
      excbody
    else:
      let r = mpz_get_ui(val).uint64
      when sizeof(T) < sizeof(uint64):
        if r > T.high:
          excbody
        else:
          T(r)
      else:
        T(r)
  else:
    {. error "logic error" .}


# proc neg_mut(a: var Integer) = mpz_neg(a, a)


func setDivMod*(dest_q, dest_r: var Integer; src_q, src_r: Integer) {.inline.} =
  ## In-place `divMod`_.
  mpz_fdiv_qr(dest_q, dest_r, src_q, src_r)

func divMod*(a: sink Integer, b: sink Integer): (Integer, Integer) {.inline.} =
  ## Returns `(a div b, a mod b)`.
  ##
  ## More efficient than calculating both expressions directly.
  ##
  mpz_fdiv_qr(a, b, a, b)
  (a, b)
