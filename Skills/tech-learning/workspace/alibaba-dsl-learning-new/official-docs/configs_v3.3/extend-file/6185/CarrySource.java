package com.taobao.customrule;

import com.taobao.stc.engine.util.graph.node.BaseTracerNode;
import com.taobao.stc.engine.util.graph.node.InterJavaTracerNode;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import com.taobao.stc.pmd.rule.security.BaseTaintedDataRule;
import com.taobao.stc.pmd.util.JavaRuleUtil;
import net.sourceforge.pmd.cache.InterDataCache;
import net.sourceforge.pmd.lang.ast.Node;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.lang.model.InterAppTypeInfor;
import net.sourceforge.pmd.trace.runtime.stack.MapOfVariable;
import net.sourceforge.pmd.util.ASTUtil;
import net.sourceforge.pmd.util.CodeUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

public class CarrySource {

    protected static Logger logger = LoggerFactory.getLogger(CarrySource.class);

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

        ASTClassOrInterfaceDeclaration interfaceDeclaration = methodDeclaration.getFirstParentOfType(ASTClassOrInterfaceDeclaration.class);
        if (interfaceDeclaration == null) {
            return false;
        }

        String visitedMethodShortName = JavaRuleUtil.getMethodName(methodDeclaration);
        String visitedMethodProfile = methodDeclaration.getFullProfile();
        String className = CodeUtil.getEnclosingClassName(methodDeclaration);

        if (interfaceDeclaration.isInterface() || interfaceDeclaration.isAbstract()) {
            return false;
        }
        InterAppTypeInfor interAppTypeInfor = InterAppTypeInfor.getInterAppTypeInfor();
        if (!interAppTypeInfor.isInterface(className, "com.alibaba.boom.framework.base.IService")) {
            return false;
        }

        List<ASTFormalParameter> formalParameters = methodDeclaration.getFirstChildOfType(ASTMethodDeclarator.class).findDescendantsOfType(ASTFormalParameter.class);
        for (ASTFormalParameter param : formalParameters) {
            ASTVariableDeclaratorId id = param.getFirstChildOfType(ASTVariableDeclaratorId.class);
            ASTClassOrInterfaceType classOrInterfaceType = param.getFirstDescendantOfType(ASTClassOrInterfaceType.class);
            if (classOrInterfaceType != null) {
                String type = classOrInterfaceType.getClassName();
                if (interAppTypeInfor.isSuperClass(type, "com.alibaba.boom.framework.base.param.ParamBean") || interAppTypeInfor.isInterface(type, "com.alibaba.boom.framework.base.param.ParamBean")) {
                    Node node = InterDataCache.getInstance().findClassNode(type);
                    Map<String, List<String>> sources = getCarryUnsafeInputParams(node, taintRule);
                    if (sources.containsKey("REQUEST")) {
                        for (String source : sources.get("REQUEST")) {
                            MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(id);
                            var.getSubPath().add(source);
                            taintRule.addTaintedVariable(var, true, id);
                            InterJavaTracerNode from = new InterJavaTracerNode(var.getThisString(), visitedMethodShortName, id.getBeginLine(), id.getEndLine(), id.getBeginColumn(), id.getEndColumn(), BaseTracerNode.TYPE.INPUT, visitedMethodProfile);
                            String image = "Carry:@Parameter(bind=BindSource.REQUEST)";
                            InterJavaTracerNode to = new InterJavaTracerNode(image, visitedMethodShortName, id.getBeginLine(), id.getEndLine(), id.getBeginColumn(), id.getEndColumn(), BaseTracerNode.TYPE.INPUT, visitedMethodProfile);
                            taintRule.addEdgeToGraph(from, to);
                        }
                    }
                    if (sources.containsKey("ALL")) {
                        for (String source : sources.get("ALL")) {
                            MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(id);
                            var.getSubPath().add(source);
                            taintRule.addTaintedVariable(var, true, id);
                            InterJavaTracerNode from = new InterJavaTracerNode(var.getThisString(), visitedMethodShortName, id.getBeginLine(), id.getEndLine(), id.getBeginColumn(), id.getEndColumn(), BaseTracerNode.TYPE.INPUT, visitedMethodProfile);
                            String image = "Carry:@Parameter(bind=BindSource.ALL)";
                            InterJavaTracerNode to = new InterJavaTracerNode(image, visitedMethodShortName, id.getBeginLine(), id.getEndLine(), id.getBeginColumn(), id.getEndColumn(), BaseTracerNode.TYPE.INPUT, visitedMethodProfile);
                            taintRule.addEdgeToGraph(from, to);
                        }
                    }
                }
            }
        }
        return false;
    }

    public static Map<String, List<String>> getCarryUnsafeInputParams(Node treenode, BaseTaintedDataRule taintRule) {
        Map<String, List<String>> ret = new HashMap<>();
        List<String> request = new LinkedList<>();
        List<String> all = new LinkedList<>();
        List<Node> astClassOrInterfaceBodyDeclarationList = ASTUtil.findNodes(treenode, "./self::ClassOrInterfaceDeclaration/ClassOrInterfaceBody/ClassOrInterfaceBodyDeclaration");
        for (Node node: astClassOrInterfaceBodyDeclarationList) {
            ASTClassOrInterfaceBodyDeclaration astClassOrInterfaceBodyDeclaration = (ASTClassOrInterfaceBodyDeclaration) node;
            for (int i = 0; i < astClassOrInterfaceBodyDeclaration.jjtGetNumChildren(); i++) {
                Node possibleAnnotationNode = astClassOrInterfaceBodyDeclaration.jjtGetChild(i);
                Node possibleNormalAnnotationNode = possibleAnnotationNode.jjtGetChild(0);
                if (possibleAnnotationNode instanceof ASTAnnotation && possibleAnnotationNode.jjtGetNumChildren() > 0 && possibleNormalAnnotationNode instanceof ASTNormalAnnotation && possibleNormalAnnotationNode.jjtGetNumChildren() > 0) {
                    if ("Parameter".equals(possibleNormalAnnotationNode.getFirstChildOfType(ASTName.class).getImage())) {
                        List<ASTMemberValuePair> astMemberValuePairList = possibleNormalAnnotationNode.findDescendantsOfType(ASTMemberValuePair.class);
                        for (ASTMemberValuePair astMemberValuePair : astMemberValuePairList) {
                            ASTName name = astMemberValuePair.getFirstDescendantOfType(ASTName.class);
                            if (name != null && "BindSource.REQUEST".equals(name.getImage())) {
                                ASTVariableDeclaratorId id = (ASTVariableDeclaratorId) ASTUtil.findFirstNode(astClassOrInterfaceBodyDeclaration, "./FieldDeclaration/VariableDeclarator/VariableDeclaratorId");
                                ASTType typeNode = (ASTType) ASTUtil.findFirstNode(astClassOrInterfaceBodyDeclaration, "./FieldDeclaration/Type");
                                String typeName = CodeUtil.getClassName(typeNode);
                                if (id != null && !taintRule.isEnumType(typeName) && !taintRule.isArgTypeSafe(typeNode) && !taintRule.isMatched(typeName, taintRule.getSafeTypesSet(), id.jjtGetParent()) && !taintRule.isMatched(typeName, taintRule.getSafeTypes(), id.jjtGetParent()) && !request.contains(id.getImage())) {
                                    request.add(id.getImage());
                                }
                            } else if (name != null && "BindSource.ALL".equals(name.getImage())) {
                                ASTVariableDeclaratorId id = (ASTVariableDeclaratorId) ASTUtil.findFirstNode(astClassOrInterfaceBodyDeclaration, "./FieldDeclaration/VariableDeclarator/VariableDeclaratorId");
                                ASTType typeNode = (ASTType) ASTUtil.findFirstNode(astClassOrInterfaceBodyDeclaration, "./FieldDeclaration/Type");
                                String typeName = CodeUtil.getClassName(typeNode);
                                if (id != null && !taintRule.isEnumType(typeName) && !taintRule.isArgTypeSafe(typeNode) && !taintRule.isMatched(typeName, taintRule.getSafeTypesSet(), id.jjtGetParent()) && !taintRule.isMatched(typeName, taintRule.getSafeTypes(), id.jjtGetParent()) && !all.contains(id.getImage())) {
                                    all.add(id.getImage());
                                }
                            }
                        }
                    }
                }
            }
        }
        if (!request.isEmpty()) {
            ret.put("REQUEST", request);
        }
        if (!all.isEmpty()) {
            ret.put("ALL", all);
        }
        return ret;
    }
}