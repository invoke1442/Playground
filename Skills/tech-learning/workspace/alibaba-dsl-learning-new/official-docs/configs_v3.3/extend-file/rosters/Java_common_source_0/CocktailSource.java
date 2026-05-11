
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
 * @author hejunyao.hjy@alibaba-inc.com
 * @date 2021/11/8 11:13
 */
public class CocktailSource {

    protected static Logger logger = LoggerFactory.getLogger(CocktailSource.class);

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {
        if (treenode == null) {
            return false;
        }

        if (rule.getClass() != BaseTaintedDataRule.class) {
            return false;
        }

        if (!(treenode instanceof ASTMethodDeclaration)) {
            return false;
        }

        if (treenode instanceof ASTConstructorDeclaration) {
            return false;
        }
        BaseTaintedDataRule taintRule = (BaseTaintedDataRule) rule;

        ASTMethodDeclaration methodDeclaration = (ASTMethodDeclaration) treenode;

        if (!methodDeclaration.getMethodName().equals("execute")){
            return false;
        }

        String visitedMethodShortName = JavaRuleUtil.getMethodName(methodDeclaration);
        String visitedMethodProfile = methodDeclaration.getFullProfile();

        List<ASTFormalParameter> formalParameters = methodDeclaration.getFirstChildOfType(ASTMethodDeclarator.class).findDescendantsOfType(ASTFormalParameter.class);
        for(ASTFormalParameter param :formalParameters){
            ASTVariableDeclaratorId id = param.getFirstChildOfType(ASTVariableDeclaratorId.class);
            ASTType typeNode = param.getFirstChildOfType(ASTType.class);
            String  typeName = CodeUtil.getClassName(typeNode);
            if(!taintRule.isEnumType(typeName)&&!taintRule.isArgTypeSafe(typeNode)&&!taintRule.isMatched(typeName,taintRule.getSafeTypesSet(),param)&&!taintRule.isMatched(typeName,taintRule.getSafeTypes(),param)){
                MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(id);
                taintRule.addTaintedVariable(var,true,id);
                //建立TRACE
                InterJavaTracerNode from = new InterJavaTracerNode(var.getThisString(),visitedMethodShortName,id.getBeginLine(),id.getEndLine(),id.getBeginColumn(),id.getEndColumn(), BaseTracerNode.TYPE.INPUT,visitedMethodProfile);
                String image = "Cocktail Interface";
                InterJavaTracerNode to = new InterJavaTracerNode(image,visitedMethodShortName,id.getBeginLine(),id.getEndLine(),id.getBeginColumn(),id.getEndColumn(),BaseTracerNode.TYPE.INPUT,visitedMethodProfile);
                taintRule.addEdgeToGraph(from,to);
            }
        }
        return false;
    }
}
