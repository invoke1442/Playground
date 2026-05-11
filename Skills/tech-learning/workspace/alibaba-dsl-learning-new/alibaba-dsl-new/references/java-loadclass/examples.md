# Java Loadclass Examples

## Taint Pattern Skeleton

```java
package com.taobao.customrule;

import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import net.sourceforge.pmd.lang.java.ast.ASTPrimaryExpression;
import net.sourceforge.pmd.lang.java.ast.JavaNode;

public class FilterSource {
    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {
        if (!(treenode instanceof ASTPrimaryExpression)) {
            return false;
        }
        ASTPrimaryExpression expr = (ASTPrimaryExpression) treenode;
        String call = expr.getCallString();
        return "javax.servlet.http.HttpServletRequest.getRequestURI".equals(call);
    }
}
```

## DSL Link

```java
general.userDefinePatternClass += {
    userDefineClass = loadclass("com.taobao.customrule.FilterSource");
};
```

Use this pattern only when regular DSL source/sink/sanitizer/propagate fields cannot express the condition.
