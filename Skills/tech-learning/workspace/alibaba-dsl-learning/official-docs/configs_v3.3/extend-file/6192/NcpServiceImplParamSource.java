
                                package com.taobao.stc.pmd.rule.security.userdfineclass;

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

	public class NcpServiceImplParamSource {
    	protected static Logger logger = LoggerFactory.getLogger(NcpServiceImplParamSource.class);

    	public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {
        	if (treenode == null) {
            	return false;
        	}

        	if(rule.getClass() != BaseTaintedDataRule.class) {
            	return false;
        	}
        	BaseTaintedDataRule taintRule = (BaseTaintedDataRule)rule;

        	if (!(treenode instanceof ASTMethodDeclaration)) {
            	return false;
        	}

        	if(treenode instanceof ASTConstructorDeclaration){
            	return false;
        	}

        	ASTMethodDeclaration methodDeclaration = (ASTMethodDeclaration) treenode;
        	if(!methodDeclaration.isPublic()){
            	return false;
        	}
        	String visitedMethodShortName= JavaRuleUtil.getMethodName(methodDeclaration);
        	String visitedMethodProfile = methodDeclaration.getFullProfile();

        	boolean entrance = false;
        	String className = CodeUtil.getEnclosingClassName(methodDeclaration);
        	List<String> interfaces = InterDataCache.getInstance().findInterfaceByClassName(className);
        	for(String inter:interfaces){
            	Node node = InterDataCache.getInstance().findClassNode(inter);
            	if(ASTUtil.findFirstNode(node,"./parent::TypeDeclaration/Annotation//Name[@Image='NcpService']")!=null){
                	if(isNcpMethodName(node,visitedMethodShortName)){
                    	entrance = true;
                    	break;
                	}
            	}
        	}
        	if(!entrance){
            	return false;
        	}

        	//taintRule.getVisitedMethodContext().setRestController(true);

        	List<ASTFormalParameter> formalParameters = methodDeclaration.getFirstChildOfType(ASTMethodDeclarator.class).findDescendantsOfType(ASTFormalParameter.class);
        	for(ASTFormalParameter param :formalParameters){
            	ASTVariableDeclaratorId id = param.getFirstChildOfType(ASTVariableDeclaratorId.class);
            	ASTType typeNode = param.getFirstChildOfType(ASTType.class);
            	String  typeName = CodeUtil.getClassName(typeNode);
            	if(!taintRule.isEnumType(typeName)&&!taintRule.isArgTypeSafe(typeNode)&&!taintRule.isMatched(typeName,taintRule.getSafeTypesSet(),param)&&!taintRule.isMatched(typeName,taintRule.getSafeTypes(),param)){
                	MapOfVariable var = MapOfVariable.getMapOfVariableFromNode(id);
                	taintRule.addTaintedVariable(var,true,id);
                //建立TRACE
                	InterJavaTracerNode from = new 	InterJavaTracerNode(var.getThisString(),visitedMethodShortName,id.getBeginLine(),id.getEndLine(),id.getBeginColumn(),id.getEndColumn(), BaseTracerNode.TYPE.INPUT,visitedMethodProfile);
                	String image = "Vine Interface";
                	InterJavaTracerNode to = new 	InterJavaTracerNode(image,visitedMethodShortName,id.getBeginLine(),id.getEndLine(),id.getBeginColumn(),id.getEndColumn(),BaseTracerNode.TYPE.INPUT,visitedMethodProfile);
                	taintRule.addEdgeToGraph(from,to);
            	}
        	}
        	return false;
    	}
    	public static Boolean isNcpMethodName(Node node,String visitedMethodShortName){
        	String xpath="./ClassOrInterfaceBody/ClassOrInterfaceBodyDeclaration/MethodDeclaration/MethodDeclarator";
        	List<Node> methodNames = ASTUtil.findNodes(node, xpath);
        	for (Node name : methodNames) {
            	if (name != null && name.getImage() != null) {
                	String image = name.getImage();
                	if (visitedMethodShortName.endsWith(image)) {
                    	return true;
                	}
            	}
        	}
        	return false;
    	}
	}
                            