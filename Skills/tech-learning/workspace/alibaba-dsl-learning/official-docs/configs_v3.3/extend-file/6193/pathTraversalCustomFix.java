
package com.taobao.customrule;

import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.trace.runtime.stack.MapOfVariable;
import net.sourceforge.pmd.util.ASTUtil;
import net.sourceforge.pmd.util.CodeUtil;
import org.jaxen.JaxenException;

import java.util.regex.Pattern;

public class pathTraversalCustomFix {
    private static final Pattern FILTER = Pattern.compile("com\\.alibaba\\.security\\.SecurityUtil\\.pathFilter");

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) throws JaxenException {
        if (treenode == null) {
            return false;
        }

        if (!(treenode instanceof ASTPrimaryExpression)) {
            return false;
        }

        ASTPrimaryExpression primaryExpression = (ASTPrimaryExpression) treenode;
        String callString = primaryExpression.getCallString();
        if (CodeUtil.isMatched(FILTER, callString)) {
            if (primaryExpression.getFirstParentOfType(ASTIfStatement.class) != null
                    && primaryExpression.getFirstParentOfType(ASTEqualityExpression.class) != null
                    && primaryExpression.getFirstNextSibling(ASTPrimaryExpression.class) != null
                    && primaryExpression.getFirstNextSibling(ASTPrimaryExpression.class).hasDescendantOfType(ASTNullLiteral.class)) {

                // 加入安全变量
                ASTName name = (ASTName) ASTUtil.findFirstNode(primaryExpression, "./self::PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name");

                MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(name);
                if (rule.getVisitedMethodContext().isVariableMayTainted(var)) {
                    rule.getVisitedMethodContext().addSafeVariable(var);
                    if (var.getIndex() >= 0) {
                        rule.getVisitedMethodContext().getSafeArgs().add(var);
                    }
                    return true;
                }
            }
        }


        return false;
    }

}
 