package com.taobao.customrule;

import com.taobao.stc.pmd.rule.security.BaseTaintedDataRule;
import net.sourceforge.pmd.Rule;
import net.sourceforge.pmd.cache.InterDataCache;
import net.sourceforge.pmd.lang.ast.Node;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.lang.model.InterAppTypeInfor;
import net.sourceforge.pmd.util.ASTUtil;
import net.sourceforge.pmd.util.CodeUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.List;

public class CarryEntrance {

    protected static Logger logger = LoggerFactory.getLogger(CarryEntrance.class);

    public static Boolean evaluate(JavaNode treenode, Rule rule) {
        if (treenode == null) {
            return false;
        }

        if (rule.getClass() != BaseTaintedDataRule.class) {
            return false;
        }

        if (!(treenode instanceof ASTCompilationUnit)) {
            return false;
        }

        InterAppTypeInfor interAppTypeInfor = InterAppTypeInfor.getInterAppTypeInfor();
        String className = CodeUtil.getEnclosingClassName(treenode);
        AbstractJavaNode decl = InterDataCache.getInstance().findDefinedClassNodeByRootNode((ASTCompilationUnit) treenode);
        if (decl instanceof ASTClassOrInterfaceDeclaration) {
            className = ((ASTClassOrInterfaceDeclaration) decl).getClassName();
        }

        if (interAppTypeInfor.isAbstract(className) || interAppTypeInfor.isInterface(className)) {
            return false;
        }

        List<Node> formalParameters = ASTUtil.findNodes(treenode, "./self::CompilationUnit/TypeDeclaration/ClassOrInterfaceDeclaration/ClassOrInterfaceBody/ClassOrInterfaceBodyDeclaration/MethodDeclaration/MethodDeclarator/FormalParameters/FormalParameter");
        for (Node formalParameter : formalParameters) {
            ASTClassOrInterfaceType classOrInterfaceType = formalParameter.getFirstDescendantOfType(ASTClassOrInterfaceType.class);
            if (classOrInterfaceType != null) {
                String type = classOrInterfaceType.getClassName();
                if (interAppTypeInfor.isSuperClass(type, "com.alibaba.boom.framework.base.param.ParamBean") || interAppTypeInfor.isInterface(type, "com.alibaba.boom.framework.base.param.ParamBean")) {
                    return true;
                }
            }
        }
        return false;
    }
}