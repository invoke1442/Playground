package com.taobao.customrule;

import com.taobao.stc.engine.util.graph.node.InterJavaTracerNode;
import com.taobao.stc.engine.util.graph.node.TracerNode;
import com.taobao.stc.pmd.model.PMDConstants;
import com.taobao.stc.pmd.rule.model.MethodArgs;
import com.taobao.stc.pmd.rule.model.TaintedResult;
import com.taobao.stc.pmd.rule.security.*;
import net.sourceforge.pmd.cache.InterDataCache;
import net.sourceforge.pmd.exception.NotInvocationException;
import net.sourceforge.pmd.lang.ast.Node;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.lang.java.symboltable.VariableNameDeclaration;
import net.sourceforge.pmd.lang.symboltable.NameOccurrence;
import net.sourceforge.pmd.trace.runtime.stack.MapOfVariable;
import net.sourceforge.pmd.util.ASTUtil;
import net.sourceforge.pmd.util.CodeUtil;
import org.apache.commons.lang3.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

public class ThreadPoolUserDefineInvoke {
    protected static Logger logger = LoggerFactory.getLogger(ThreadPoolUserDefineInvoke.class);

    private static final Pattern BEAN_PATTERN = Pattern.compile("\\.getBean\\.");
    private static final Pattern POOL_PATTERN = Pattern.compile("(java\\.util\\.Timer\\.schedule)|(Executors\\.newCachedThreadPool\\.execute)|(ScheduledExecutorService\\.schedule)|((ExecutorService|ThreadPoolExecutor)\\.(execute|submit|invokeAny|invokeAll))");
    private static final Pattern THREAD_PATTERN = Pattern.compile("\\.start");
    private static final Pattern DATABINDER_PATTEN = Pattern.compile("WebDataBinder\\.bind$");


    public static Boolean evaluate(JavaNode treenode, BaseFSMMachineRule rule) throws NotInvocationException {
        if(rule.getClass() != BaseFSMMachineRule.class){
            return false;
        }

        if(!(treenode instanceof ASTPrimaryExpression)){
            return false;
        }
        ASTPrimaryExpression primaryExpression = (ASTPrimaryExpression)treenode;

        BaseTaintedDataRuleData taintData = new BaseTaintedDataRuleData();

        if(handleUserDefineInvoke(primaryExpression,rule,taintData)){
            return true;
        }
        return false;
    }

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) throws NotInvocationException {
        if(rule.getClass() != BaseTaintedDataRule.class){
            return false;
        }
        if(!(treenode instanceof ASTPrimaryExpression)){
            return false;
        }
        ASTPrimaryExpression primaryExpression = (ASTPrimaryExpression)treenode;

        BaseTaintedDataRuleData taintData = (BaseTaintedDataRuleData)data;

        if(handleUserDefineInvoke(primaryExpression,rule,taintData)){
            return true;
        }

        return false;
    }

    public static Boolean handleUserDefineInvoke(ASTPrimaryExpression primaryExpression, AbstractJavaRule rule, BaseTaintedDataRuleData taintData) throws NotInvocationException {
        String callString = primaryExpression.getCallString();
        if(callString == null){
            return false;
        }

        // BeanFactory
        if(CodeUtil.isMatched(BEAN_PATTERN,callString)){
            String className = null;
            ASTMethodDeclaration methodDeclaration = null;
            String flag = "getBeanInvoke";

            ASTClassOrInterfaceType classOrInterfaceType = primaryExpression.getFirstDescendantOfType(ASTClassOrInterfaceType.class);
            if (classOrInterfaceType == null) {
                return false;
            }
            className = classOrInterfaceType.getClassName();

            if (className != null) {
                String methodName = callString.replaceFirst("(.*?)getBean\\.", "");
                String method = className + "." + StringUtils.substringBeforeLast(methodName, ".");
                ASTName name = (ASTName) ASTUtil.findFirstNode(primaryExpression,"./PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name");
                if (name != null) {
                    List<MethodArgs> methodArgs = rule.getMethodArgsForInvoke(primaryExpression, 1);
                    invoke(flag, name, 1, rule, primaryExpression, method, taintData, methodArgs, name.getFirstParentOfType(ASTArguments.class));
                    return true;
                }
            }
        }
        
        // 线程池
        if (CodeUtil.isMatched(POOL_PATTERN,callString)) {
            String className = null;
            ASTName name = null;
            String flag = "ThreadPoolInvoke";

            // 获取集合add处的参数，遍历每一次add，添加多条调用边
            if ((callString.contains("invokeAll") || callString.contains("invokeAny"))) {
                ASTName argName = primaryExpression.getFirstDescendantOfType(ASTArgumentList.class).getFirstDescendantOfType(ASTName.class);
                MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(argName);
                if (var.getDecl() instanceof VariableNameDeclaration) {
                    VariableNameDeclaration decl = (VariableNameDeclaration) var.getDecl();
                    ASTVariableDeclaratorId id = decl.getDeclaratorId();
                    List<NameOccurrence> collectionOcc = id.getUsages();
                    for (NameOccurrence occ: collectionOcc) {
                        if (occ.getLocation() instanceof ASTName) {
                            ASTName locName = (ASTName) occ.getLocation();
                            if (locName.getImage().contains(".add")) {
                                // 向上找第一个基本表达式，再向下找第一个argumentList
                                ASTPrimaryExpression locPrimaryExpression = locName.getFirstParentOfType(ASTPrimaryExpression.class);
                                ASTExpression targetExpression = locPrimaryExpression.getFirstDescendantOfType(ASTExpression.class);
                                if (targetExpression != null) {
                                    className = targetExpression.getClassName();
                                    name = targetExpression.getFirstDescendantOfType(ASTName.class);
                                    if (name == null) {
                                        continue;
                                    }
                                    // 尝试添加多条边
                                    if(className != null) {
                                        String method = className + ".call";

                                        ASTArguments arguments = name.getFirstParentOfType(ASTArguments.class);
                                        List<MethodArgs> methodArgs = new ArrayList<>();
                                        invoke(flag, name, 0, rule, primaryExpression, method, taintData, methodArgs, arguments);
                                    }

                                }
                            }
                        }
                    }
                }
            } else {
                // doing
                ASTPrimaryExpression targetPrimaryExpression = (ASTPrimaryExpression) ASTUtil.findFirstNode(primaryExpression,"./self::PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression");
              	if (targetPrimaryExpression == null) {
                    return false;
                }
                className = targetPrimaryExpression.getClassName();
                name = targetPrimaryExpression.getFirstDescendantOfType(ASTName.class);
                if (className != null && name != null) {
                    String callMethod = className + ".call";
                    String runMethod = className + ".run";
                    List<MethodArgs> methodArgs = new ArrayList<>();
                    // 如果有call方法则执行call，没有call则执行run
                    if (!invoke(flag, name, 0, rule, primaryExpression, callMethod, taintData, methodArgs, primaryExpression.getFirstDescendantOfType(ASTArguments.class))) {
                        invoke(flag, name, 0, rule, primaryExpression, runMethod, taintData, methodArgs, primaryExpression.getFirstDescendantOfType(ASTArguments.class));
                    }
                    return true;
                }
            }
        }

        // 多线程
        if (CodeUtil.isMatched(THREAD_PATTERN, callString)) {
            String className = null;
            String method = null;
            String invokerClass = StringUtils.substringBeforeLast(primaryExpression.getCallString(), ".");
            ASTName name = null;
            ASTArguments arguments = null;

            if (invokerClass.equals("java.lang.Thread")) {
                ASTName invokerName = primaryExpression.getFirstDescendantOfType(ASTName.class);
                MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(invokerName);
                String targetClassName = null;
                ASTPrimaryExpression target = null;
                if (var.getDecl() instanceof VariableNameDeclaration) {
                    VariableNameDeclaration decl = (VariableNameDeclaration) var.getDecl();
                    ASTVariableDeclaratorId id = decl.getDeclaratorId();
                    target = (ASTPrimaryExpression) ASTUtil.findFirstNode(id, "./self::VariableDeclaratorId/following-sibling::VariableInitializer/Expression/PrimaryExpression/PrimaryPrefix/AllocationExpression/Arguments/ArgumentList/Expression/PrimaryExpression");
                    if (target != null) {
                        targetClassName = target.getClassName();
                    }
                }

                if (target == null || targetClassName == null) {
                    return false;
                } else if (targetClassName.equals("java.util.concurrent.FutureTask")) {
                    ASTName callName = target.getFirstDescendantOfType(ASTName.class);
                    MapOfVariable var1 = MapOfVariable.getMapOfVariableFromNode(callName);
                    if (var1.getDecl() instanceof VariableNameDeclaration) {
                        VariableNameDeclaration decl = (VariableNameDeclaration) var1.getDecl();
                        ASTVariableDeclaratorId id = decl.getDeclaratorId();
                        ASTPrimaryExpression callPrimaryExpression = (ASTPrimaryExpression) ASTUtil.findFirstNode(id, "./self::VariableDeclaratorId/following-sibling::VariableInitializer/Expression/PrimaryExpression/PrimaryPrefix/AllocationExpression/Arguments/ArgumentList/Expression/PrimaryExpression");
                        if (callPrimaryExpression != null) {
                            className = callPrimaryExpression.getClassName();
                            name = callPrimaryExpression.getFirstDescendantOfType(ASTName.class);
                            method = className + ".call";
                            arguments = primaryExpression.getFirstDescendantOfType(ASTArguments.class);
                        }
                    }
                } else {
                    className = targetClassName;
                    name = target.getFirstDescendantOfType(ASTName.class);
                    method = className + ".run";
                    arguments = primaryExpression.getFirstDescendantOfType(ASTArguments.class);
                }

            } else if (InterDataCache.getInstance().findSuperClassesByClassName(invokerClass).contains("java.lang.Thread")) {
                className = invokerClass;
                name = (ASTName) ASTUtil.findFirstNode(primaryExpression, "./self::PrimaryExpression/PrimaryPrefix/Name");
                method = className + ".run";
                arguments = primaryExpression.getFirstDescendantOfType(ASTArguments.class);
            }

            if (className != null && name != null) {
                String flag = "ThreadInvoke";
                List<MethodArgs> methodArgs = new ArrayList<>();
                invoke(flag, name, 0, rule, primaryExpression, method, taintData, methodArgs, arguments);
                return true;
            }

        }

        if(CodeUtil.isMatched(DATABINDER_PATTEN,callString)){
            ASTName name = (ASTName)ASTUtil.findFirstNode(primaryExpression,"./PrimaryPrefix/Name");
            ASTExpression firstArgExp = (ASTExpression)ASTUtil.findFirstNode(primaryExpression,"./PrimarySuffix/Arguments/ArgumentList/Expression");
            if(name!=null && firstArgExp!=null){
                String varName = MapOfVariable.getMapOfVariableFromNode(name).getImage();
                ASTMethodDeclaration methodDeclaration = primaryExpression.getFirstParentOfType(ASTMethodDeclaration.class);
                ASTName targetName = (ASTName) ASTUtil.findFirstNode(methodDeclaration,".//VariableDeclarator[./VariableDeclaratorId[@Image = '"+ varName +"']]/VariableInitializer/Expression/PrimaryExpression/PrimaryPrefix/AllocationExpression/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name" +
                        "|.//StatementExpression[./AssignmentOperator[@Image='='] and ./PrimaryExpression/PrimaryPrefix/Name[@Image='"+ varName +"']]/Expression/PrimaryExpression/PrimaryPrefix/AllocationExpression/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name");
                if(targetName!=null){
                    rule.visitTreeNode(firstArgExp,taintData);
                    rule.handleUserDefineTaintFlow(taintData.result,MapOfVariable.getMapOfVariableFromNode(targetName),name);
                }
            }
        }

        return false;
    }

    public static boolean invoke(String flag, ASTName name, int order, AbstractJavaRule rule, ASTPrimaryExpression primaryExpression, String method,
                                 BaseTaintedDataRuleData taintData, List<MethodArgs> methodArgs, ASTArguments arguments) {
        List<Node> methods = InterDataCache.getInstance().findMethodNodes(method);
        if (methods == null || methods.size() < 1) {
            return false;
        } else {
            ASTMethodDeclaration methodDeclaration = (ASTMethodDeclaration)methods.get(0);

            TaintedResult objectResult = rule.handleSingleVar(MapOfVariable.getMapOfVariableFromNode(name),name);
            addFlag(rule, primaryExpression, flag, order, objectResult);
            rule.handleUserDefineInvoke(methodDeclaration,
                    methodArgs,taintData,primaryExpression.getFirstChildOfType(ASTPrimaryPrefix.class),
                    arguments, objectResult
            );
            return true;
        }
    }

    public static void addFlag(AbstractJavaRule rule, ASTPrimaryExpression primaryExpression, String flag, int order, TaintedResult objectResult) {
        if (rule.getClass() == BaseFSMMachineRule.class) {
            if (rule.getFlag() != null) {
                rule.setFlag(rule.getFlag() + "; " + flag);
            } else {
                rule.setFlag(flag);
            }
        } else if (rule.getClass() == BaseTaintedDataRule.class) {
            BaseTaintedDataRule baseTaintedDataRule = (BaseTaintedDataRule) rule;
            if (objectResult != null) {
                addTracer(objectResult, baseTaintedDataRule, flag);
            } else {
                List<MethodArgs> methodArgsList = rule.getMethodArgsForInvoke(primaryExpression, order);
                for (MethodArgs methodArgs : methodArgsList) {
                    TaintedResult result = methodArgs.getArgResult();
                    addTracer(result, baseTaintedDataRule, flag);
                }
            }
        }
    }

    public static void addTracer(TaintedResult objectResult, BaseTaintedDataRule baseTaintedDataRule, String flag) {
        if(objectResult.getSink() == PMDConstants.TaintedType.INPUT || objectResult.getSink() == PMDConstants.TaintedType.NONE){
            MapOfVariable resultVar = objectResult.getTaintedVar();
            TracerNode.TYPE type;
            if (objectResult.getSink() == PMDConstants.TaintedType.INPUT) {
                type = TracerNode.TYPE.INPUT;
            } else {
                type = TracerNode.TYPE.NONE;
            }

            InterJavaTracerNode to = new InterJavaTracerNode(resultVar.getThisString(), objectResult.getMethodName(), objectResult.getName().getBeginLine(), objectResult.getName().getEndLine(), objectResult.getName().getBeginColumn(), objectResult.getName().getEndColumn(), type, objectResult.getMethodSignature());
            InterJavaTracerNode flagNode = baseTaintedDataRule.addNodeToGraph(to);
            flagNode.setFlag(flag);
            if(objectResult.isPrecise()){
                for (List<String> accessPath : objectResult.getTaintSubPathes()) {
                    MapOfVariable newResultVar = resultVar.copy();
                    newResultVar.getSubPath().addAll(accessPath);
                    newResultVar.normalize(objectResult.getName());
                    to = new InterJavaTracerNode(newResultVar.getThisString(), objectResult.getMethodName(), objectResult.getName().getBeginLine(), objectResult.getName().getEndLine(), objectResult.getName().getBeginColumn(), objectResult.getName().getEndColumn(), type, objectResult.getMethodSignature());
                    InterJavaTracerNode flagNode1 = baseTaintedDataRule.addNodeToGraph(to);
                    flagNode1.setFlag(flag);
                }
            }
        }
    }
}
 