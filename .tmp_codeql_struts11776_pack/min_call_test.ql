/**
 * @name min_call_test
 * @kind problem
 * @id java/min-call-test
 * @problem.severity warning
 */

import java

from MethodCall call
where call.getMethod().hasName("toString")
select call, "call"
