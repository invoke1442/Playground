/**
 * This is an automatically generated file
 * @name Hello world
 * @kind problem
 * @problem.severity warning
 * @id java/example/hello-world
 */

import tutorial

Person relativeOf(Person p) {
  parentOf*(result) = parentOf*(p) and result != p
}

from Person p
where p = relativeOf("King Basil") and not p.isDeceased()
select p, p.getLocation(), p.getAge()