
package com.taobao.customrule;

import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import com.taobao.stc.pmd.rule.security.BaseTaintedDataRule;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.util.CodeUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.regex.Pattern;

public class SSRFPkgHandler {
    protected static Logger logger = LoggerFactory.getLogger(SSRFPkgHandler.class);
    private static final Pattern URL_TAINTED = Pattern.compile("org\\.apache\\.commons\\.io\\.IOUtils\\.toString|com\\.alibaba\\.fastjson2\\.JSON\\.parseObject" +
            "|com\\.fasterxml\\.jackson\\.databind\\.ObjectMapper\\.readValue|com\\.itextpdf\\.text\\.Image\\.getInstance"); //
    private static final Pattern URL_TYPE = Pattern.compile("java\\.net\\.(URL|URI)");
    private static final Pattern ERROR_CALL = Pattern.compile("org\\.springframework\\.context\\.(.*?)(getMessage|getMergedProperties)");

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {

        if (treenode == null) {
            return false;
        }

        if (!(treenode instanceof ASTPrimaryExpression)) {
            return false;
        }

        ASTPrimaryExpression primaryExpression = (ASTPrimaryExpression) treenode;
        String callString = primaryExpression.getCallString();
        if (CodeUtil.isMatched(URL_TAINTED, callString)) {
            ASTArgumentList argumentList = primaryExpression.getFirstDescendantOfType(ASTArgumentList.class);
            if (argumentList != null) {
                ASTPrimaryExpression firstArg = argumentList.getFirstDescendantOfType(ASTPrimaryExpression.class);
                if (firstArg != null && CodeUtil.isMatched(URL_TYPE, firstArg.getClassName())) {
                    return false;
                }
            }
            return true;
        }

        if (CodeUtil.isMatched(ERROR_CALL, callString)) {
            return true;
        }


        return false;

    }
}
