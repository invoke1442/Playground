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
        ASTPrimaryExpression expression = (ASTPrimaryExpression) treenode;
        return "javax.servlet.http.HttpServletRequest.getRequestURI".equals(expression.getCallString());
    }
}
