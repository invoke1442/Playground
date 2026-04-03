/**
 * This is an automatically generated file
 * @name Hello world
 * @kind metric
 * @id java/example/hello-world
 * @severity severe
 */

import tutorial

from Person p
where p.getHeight() > 150 and not p.getHairColor() = "blond" and exists(string c | p.getHairColor() = c) and p.getAge() >= 30 and p.getLocation() = "east" and ((p.getHairColor() = "black") or (p.getHairColor() = "brown")) and not ((p.getHeight() > 180) and (p.getHeight() < 190)) and exists(Person someone | someone.getAge() > p.getAge()) and p != max(Person tmp | | tmp order by tmp.getHeight()) and p.getHeight() < avg(Person tmp |  | tmp.getHeight()) and p.getAge() >= max(Person tmp | tmp.getLocation() = "east" | tmp.getAge())
select p, p.getAge() as age, p.getHairColor() as hair_color, p.getHeight() as height, p.getLocation() as location
