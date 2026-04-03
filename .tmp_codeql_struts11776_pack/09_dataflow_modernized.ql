/**
 * @name 09_dataflow_modernized
 * @description Modernized learning version of the old Struts CVE-2018-11776 data flow query
 * @kind path-problem
 * @id java/struts-cve-2018-11776-learning-modernized
 * @problem.severity warning
 */

import java
import semmle.code.java.dataflow.DataFlow

predicate isOgnlSink(DataFlow::Node sink) {
  exists(Method m, MethodCall ma |
    m.getName() = "compileAndExecute" and
    ma.getMethod() = m and
    sink = DataFlow::exprNode(ma.getArgument(0))
  )
}

predicate isActionProxySource(DataFlow::Node source) {
  exists(Method m, Method n, MethodCall ma |
    m.getName() = "getNamespace" and
    m.getDeclaringType().getName() = "ActionProxy" and
    n.overrides*(m) and
    ma.getMethod() = n and
    source = DataFlow::exprNode(ma)
  )
}

module OgnlConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node source) {
    isActionProxySource(source)
  }

  predicate isSink(DataFlow::Node sink) {
    isOgnlSink(sink)
  }
}

module OgnlFlow = DataFlow::Global<OgnlConfig>;

import OgnlFlow::PathGraph

from OgnlFlow::PathNode source, OgnlFlow::PathNode sink
where OgnlFlow::flowPath(source, sink)
select sink.getNode(), source, sink, "User-controlled namespace flows into OGNL evaluation."
