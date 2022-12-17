import unittest
import integers

suite "math":

  test "fib/luc":

    check fibonacci(0'i8) == 0
    check fibonacci(10'gmp) == 55
    check fibonacci(200) == 280571172992510140037611932413038677189525'gmp

    check lucas(0'i8) == 2
    check lucas(10'gmp) == 123
    check lucas(200) == 627376215338105766356982006981782561278127'gmp

    check lucasPair(100) == (lucas(99), lucas(100))
    check fibonacciPair(100) == (fibonacci(99), fibonacci(100))

  test "factorial":

    var k = Integer.one

    for i in 1 .. 100:
      k *= i
      check k == factorial(i)

  test "divexp":

    for i in 2 .. 100:
      let n: Integer = 7^i + 1

      let (q, e) = n.divExp(3)

      check q * 3^e == n
      check not q.divisible(3)
