/**
 * @name Equality and inequality coexistence verification
 */
from int witnessEq, int witnessNeA, int witnessNeB
where
  [1 .. 2] = [1 .. 2] and
  [1 .. 2] != [1 .. 2] and
  witnessEq = 1 and
  witnessNeA = 1 and witnessNeB = 2
select witnessEq, witnessNeA, witnessNeB,
  "For A=[1..2], B=[1..2], both A=B and A!=B are true under set semantics"
