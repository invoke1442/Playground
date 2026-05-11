
package com.taobao.customrule;

import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.trace.runtime.stack.MapOfVariable;
import net.sourceforge.pmd.util.CodeUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;
import java.util.regex.Pattern;

public class SSRFCustomPropagate {
    protected static Logger logger = LoggerFactory.getLogger(SSRFCustomPropagate.class);
    private static final Pattern PROPAGATE_PATTERN = Pattern.compile("java\\.net\\.URL\\._init_|java\\.net\\.URI\\._init_");

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {

        if (treenode == null) {
            return false;
        }

        if (!(treenode instanceof ASTPrimaryExpression)) {
            return false;
        }

        ASTPrimaryExpression primaryExpression = (ASTPrimaryExpression) treenode;
        String callString = primaryExpression.getCallString();

        if (CodeUtil.isMatched(PROPAGATE_PATTERN, callString)) {
            ASTArgumentList argumentList = primaryExpression.getFirstDescendantOfType(ASTArgumentList.class);
            if (argumentList == null) {
                return false;
            }
            List<ASTExpression> astExpressionList = argumentList.findChildrenOfType(ASTExpression.class);
            if (!astExpressionList.isEmpty() && callString.contains("URL")) {
                int argNums = astExpressionList.size();
                if (argNums >= 2) {
                    boolean tainted = isTainted(rule, astExpressionList.get(1));
                    // 如果第二个参数没有污染则返回true，不传播污染
                    return !tainted;
                }
            } else if (!astExpressionList.isEmpty() && callString.contains("URI")) {
                int argNums = astExpressionList.size();
                if (argNums >=5) {
                    boolean tainted = isTainted(rule, astExpressionList.get(2));
                    return !tainted;
                } else if (argNums >= 3) {
                    boolean tainted = isTainted(rule, astExpressionList.get(1));
                    return !tainted;
                }
            }
        }

        return false;
    }

    public static boolean isTainted(AbstractTaintedDataRule rule, ASTExpression expression) {
        List<ASTName> nameList = expression.findDescendantsOfType(ASTName.class);
        for (ASTName name: nameList) {
            MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(name);
            if (rule.isVariableMayTainted(var)) {
                return true;
            }
        }
        return false;
    }

}
