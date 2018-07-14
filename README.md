### G2 Haskell Symbolic Execution Engine
---
##### About
G2 performs lazy symbolic execution of Haskell programs to detect state reachability.
It is capable of generating assertion failure counterexamples and solving for higher-order functions.

---

##### Dependencies
* GHC 8.0.2: https://www.haskell.org/ghc/
* Custom Haskell Standard Library: https://github.com/AntonXue/base-4.9.1.0
* Z3 Theorem Prover: https://github.com/Z3Prover/z3

---
#### Setup:
1) Install GHC 8.0.2 (other GHC 8 versions might also work)
2) Install Z3
3) Pull the Custom Haskell Standard Library (optional)
4) Add a file to the G2 folder, called g2.cfg that contains:
		base = [path to Custom Haskell Standard Library] 

---
#### Command line:

Reachability:

cabal run G2 ./tests/Samples/ ./tests/Samples/Peano.hs add

LiquidHaskell:

cabal run G2 ./tests/Liquid/ -- --liquid ./tests/Liquid/Peano.hs --liquid-func add

Arguments:

--n = number of reduction steps to run

--max-outputs = number of inputs/results to display

--smt = Pass "z3" or "cvc4" to select a solver [Default: Z3]

--time = Set a timeout

---

##### Authors
* Bill Hallahan (Yale)
* Anton Xue (Yale)
* Ranjit Jhala (UCSD)
* Ruzica Piskac (Yale)