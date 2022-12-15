## Miscellaneous utility routines missing from the Nim standard library.

import std/[algorithm, sequtils, bitops, strutils]


func remove*(str: sink string, ch: char): string =
  ## Remove a given char from a string.
  ##
  runnableExamples:
    assert "test".remove('t') == "es"

  var t = str.find(ch)
  if t == -1:
    return str

  result = str
  for s in t + 1 ..< str.len:
    if result[s] != ch:
      result[t] = result[s]
      t.inc

  result.setLen(t)


func shrinkToC*(str: var string) =
  ## Shrink a string's length so it is one less than the first NUL-byte
  ## (`\x00`). Is a no-op if no the string contains no such byte.
  ##
  let nl = str.find(0.char)
  if nl >= 0:
    str.setLen(nl)


iterator permutations*[T,U](v: HSlice[T,U]): seq[T] {.inline.} =
  ## Iterator over all permutations of a slice, yielding sequences.
  ##
  runnableExamples:
    import std/sugar

    let ps = collect:
      for v in (1 .. 4).permutations():
        v

    # `ps` now contains all permutations of {1,2,3,4} as sequences.
    assert ps is seq[seq[int]] and ps.len == 4*3*2
    assert @[4,1,2,3] in ps
    assert @[2,3,1,4] in ps
    assert @[1,2,3,4] in ps

  var ixs = v.toSeq()
  while true:
    yield ixs
    if not ixs.nextPermutation():
      break

iterator permutations*(v: string): string {.inline.} =
  ## Iterator over all permutations of a string, yielding strings.
  ##
  runnableExamples:
    import std/sugar

    let ps = collect:
      for v in "world".permutations():
        v

    # ps1 has 5! elements.
    assert ps.len == 5 * 4 * 3 * 2 * 1
    # ps1 contains all permuated strings of "world"
    assert "rldwo" in ps and "oldwr" in ps and "world" in ps

  var res = newString(v.len)

  for ix in (0 ..< v.len).permutations():
    for (i, j) in pairs(ix):
      res[i] = v[j]
    yield res


iterator permutations*[T](v: openArray[T]): seq[T] {.inline.} =
  ## Iterator over all permutations of a sequence, yielding sequences.
  ##
  runnableExamples:
    import std/sugar

    let ps = collect:
      for v in permutations(@["x", "y", "ZZ"]):
        v

    # ps has 3! elements.
    assert ps.len == 6
    # ps contains all permuated sequences.
    assert @["x", "ZZ", "y"] in ps
    assert @["y", "x", "ZZ"] in ps
    assert @["ZZ", "x", "y"] in ps
    # etc.

  var res = newSeq[T](v.len)

  for ix in (0 ..< v.len).permutations():
    for (i, j) in pairs(ix):
      res[i] = v[j]
    yield res


template uconv(stype, utype: typedesc): untyped =
  template toUnsigned*(x: stype): utype =
    ## Given an signed integer, bitcasts it to the equivalent unsigned type.
    ##
    ## toUnsigned() is in private/bitops and not exported by the standard library. Shame.
    cast[utype](x)
  template toSigned*(x: utype): stype =
    ## Given an unsigned integer, bitcasts it to the equivalent signed type.
    cast[stype](x)
  func unsignedAbs*(x: stype): utype =
    ## Takes the absolute value and bitcasts this value to the type's unsigned
    ## equivalent.
    ##
    ## This will not overflow, even if `x` is `typeof(x).low`.
    if x >= 0: x.toUnsigned() else: x.toUnsigned().bitnot + 1

uconv(int8, uint8)
uconv(int16, uint16)
uconv(int32, uint32)
uconv(int64, uint64)
uconv(int, uint)

func unsignedAbs*[T: SomeUnsignedInt](x: T): T {.inline.} =
  ## In the case of unsigned types, this is a no-op.
  x

template bitsof*(ty: typedesc): auto =
  ## Alias for sizeof(T) * 8.
  sizeof(ty) * 8


