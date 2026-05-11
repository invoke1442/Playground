
                                
package com.taobao.customrule;

import com.taobao.stc.engine.util.graph.node.BaseTracerNode;
import com.taobao.stc.engine.util.graph.node.InterJavaTracerNode;
import com.taobao.stc.pmd.util.JavaRuleUtil;
import net.sourceforge.pmd.cache.InterDataCache;
import net.sourceforge.pmd.lang.ast.Node;
import com.taobao.stc.pmd.model.PMDConstants;
import com.taobao.stc.pmd.rule.model.TaintedResult;
import com.taobao.stc.pmd.rule.security.*;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.trace.runtime.stack.MapOfVariable;
import net.sourceforge.pmd.util.ASTUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import net.sourceforge.pmd.util.CodeUtil;
import com.taobao.stc.pmd.rule.model.MethodContext;

import java.util.*;
import java.util.regex.Pattern;

/**
 * @author wenyuan.xwy@alibaba-inc.com
 * @date 2021/9/22 11:13
 */
public class DfaasSource {

    protected static Logger logger = LoggerFactory.getLogger(DfaasSource.class);

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {
        if (treenode == null) {
            return false;
        }

        if (rule.getClass() != BaseTaintedDataRule.class) {
            return false;
        }
        BaseTaintedDataRule taintRule = (BaseTaintedDataRule) rule;

        if (!(treenode instanceof ASTMethodDeclaration)) {
            return false;
        }

        if (treenode instanceof ASTConstructorDeclaration) {
            return false;
        }

        ASTMethodDeclaration methodDeclaration = (ASTMethodDeclaration) treenode;
        String visitedMethodShortName = JavaRuleUtil.getMethodName(methodDeclaration);
        String visitedMethodProfile = methodDeclaration.getFullProfile();

        if (!methodDeclaration.getMethodName().equals("handle")){
            return false;
        }

        boolean entrance = false;
        String className = CodeUtil.getEnclosingClassName(methodDeclaration);
        List<String> interfaces = InterDataCache.getInstance().findInterfaceByClassName(className);
            for (String inter : interfaces) {
                if (inter.equals("com.alibaba.dt.faas.runtime.DFunction"))
                    entrance = true;
            }
        if (!entrance) {
            return false;
        }

        List<ASTFormalParameter> formalParameters = methodDeclaration.getFirstChildOfType(ASTMethodDeclarator.class).findDescendantsOfType(ASTFormalParameter.class);
        ASTFormalParameter param = formalParameters.get(0);
        ASTVariableDeclaratorId id = param.getFirstChildOfType(ASTVariableDeclaratorId.class);
        ASTType typeNode = param.getFirstChildOfType(ASTType.class);
        String typeName = CodeUtil.getClassName(typeNode);
        if (!taintRule.isEnumType(typeName) && !taintRule.isArgTypeSafe(typeNode) && !taintRule.isMatched(typeName, taintRule.getSafeTypesSet(), param) && !taintRule.isMatched(typeName, taintRule.getSafeTypes(), param)) {
            MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(id);
            taintRule.addTaintedVariable(var, true, id);
            //建立TRACE
            InterJavaTracerNode from = new InterJavaTracerNode(var.getThisString(), visitedMethodShortName, id.getBeginLine(), id.getEndLine(), id.getBeginColumn(), id.getEndColumn(), BaseTracerNode.TYPE.INPUT, visitedMethodProfile);
            String image = "DFaaS Interface";
            InterJavaTracerNode to = new InterJavaTracerNode(image, visitedMethodShortName, id.getBeginLine(), id.getEndLine(), id.getBeginColumn(), id.getEndColumn(), BaseTracerNode.TYPE.INPUT, visitedMethodProfile);
            taintRule.addEdgeToGraph(from, to);
        }
        return false;
    }
}
                                    
                            