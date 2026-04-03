/**
 * This is an automatically generated file
 * @name Hello world
 * @kind problem
 * @problem.severity warning
 * @id java/example/hello-world
 */

import tutorial

predicate isSouthern(Person p) { p.getLocation() = "south" }

class Southerner extends Person {
  /* the characteristic predicate */
  Southerner() { isSouthern(this) }
}

class Child extends Person {
  /* the characteristic predicate */
  Child() { this.getAge() < 10 }

  /* a member predicate */
  override predicate isAllowedIn(string region) { region = this.getLocation() }
}

predicate isBald(Person p) {
  not exists (string c | p.getHairColor() = c)
}

from Southerner s
where not s instanceof Child and isBald(s)
select s, s.getAge(), parentOf(s)