/**
 * @name min_java_test
 * @kind problem
 */

import java

from Method m
where m.getName() = "toString"
select m, "test"
