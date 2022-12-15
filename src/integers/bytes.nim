## Conversion Between Integers and Bytes
## =====================================

import ./gmp
import ./core
export core
import ./bitset

type
  WordOrder* = enum
    ## An integer in `woLSF` (least-significant first) order means the least-significant digit comes first,
    ## and vice versa for `woMSF` (most-significant first).
    ##
    ## For example the current year is `2202` with `woLSF` word order, using digits in base-10.
    ##
    ## "Word" here means "a digit in base `2^8`, `2^16`, `2^32`, etc.", represented by an `uint8`, `uint16`, etc.
    ##
    woLSF = -1,
    woMSF = 1

  Endianness* = enum
    ## The endianness of each byte within a word (if a word is larger than a byte).
    ##
    eLE = -1,
    eNative = 0
    eBE = 1,


proc newInteger*[T: SomeUnsignedInt](
  words: openArray[T],
  order: WordOrder = woMSF,
  endianness: Endianness = eNative,
  nails: int = 0): Integer =
  ## Given a sequence of *words* (digits in the form of a primitive unsigned
  ## type), interpret it as representing a number.
  ##
  ## - `order` determines if `words[0]` is the least significant or most significant digit.
  ##
  ## - `endianness` determines how to interpret the endianness of each word. It
  ##   makes no sense to have this be anything other than `eNative` unless you're
  ##   doing some fancy trick.
  ##
  ## - `nails` specifies how many of the upper bits to *ignore* of each word.
  ##   Essentially this means the words are taken to be in base `2^(bitsof(T) -
  ##   nails)`.
  runnableExamples:
    let x = newInteger([0xff01'u16, 0x03cc], woLSF)
    assert x == 0x03ccff01

    let y = newInteger([1'u8, 2, 3], nails=2) # base-64 interpretation!
    assert y == 1 * 64*64 + 2 * 64 + 3

  let size = sizeof(T)
  assert nails >= 0 and nails < size * 8, "invalid nail size"

  mpz_import(result, words.len.csize_t(), order.cint(),
             size.csize_t(),
             endianness.cint(),
             nails.csize_t(),
             words[0].unsafeAddr)

proc toSeq*(
  val: Integer,
  T: typedesc[SomeUnsignedInt],
  order: WordOrder = woMSF,
  endianness: Endianness = eNative,
  nails: int = 0): seq[T] =
  ## Given an integer, efficiently serialize it to a sequence of *words* of the
  ## given type `T` (digits in the form of a primitive unsigned type).
  ##
  ## - `order` determines if `result[0]` is the least significant or most significant digit.
  ##
  ## - `endianness` determines how to store the endianness of each word. It
  ##   makes no sense to have this be anything other than `eNative` unless you're
  ##   doing some fancy trick.
  ##
  ## - `nails` specifies how many of the upper bits to *ignore* of each word.
  ##   Essentially this means the output will be in base `2^(bitsof(T) -
  ##   nails)` instead of covering the full type `T`.
  ##
  runnableExamples:
    let x = 0xdead01'gmp

    assert x.toSeq(uint16) == @[ 0xde'u16, 0xad01 ]
    assert x.toSeq(uint8, woLSF) == @[ 0x01'u8, 0xad, 0xde ]

    # Binary!
    assert 26'gmp.toSeq(uint8, woLSF, nails=7) == @[ 0'u8, 1, 0, 1, 1 ]

    let y = newInteger([1'u8, 2, 3], nails=2) # base-64 interpretation!
    assert y == 1 * 64*64 + 2 * 64 + 3

  let size = sizeof(T)
  assert nails >= 0 and nails < size * 8, "invalid nail size"
  let bpw = size * 8 - nails
  let words = (val.nbits + bpw - 1) div bpw
  result.setLen(words)

  var realcnt: csize_t
  discard mpz_export(result[0].addr,
                      realcnt.addr,
                      order.cint(),
                      size.csize_t(),
                      endianness.cint(),
                      nails.csize_t(),
                      val)

  result.setLen(realcnt.int())

proc toBytes*(val: Integer, order: WordOrder = woMSF): seq[uint8] =
  ## Shorthand for converting to a sequence of bytes.
  val.toSeq(uint8, order)
