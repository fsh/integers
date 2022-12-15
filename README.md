 
 # Integers
 
 

This package simply aims to provide *integers* (also known as "bigints,"
"bignums," "arbitrary precision integers," "true integers," and so on) by
wrapping GMP in a nice ergonomic way for Nim.

## Caveats

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

## Why GMP?

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
