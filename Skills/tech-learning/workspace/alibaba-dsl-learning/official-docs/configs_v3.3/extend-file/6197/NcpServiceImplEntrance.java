
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
        import net.sourceforge.pmd.Rule;

        import java.util.*;
        import java.util.regex.Pattern;

        public class NcpServiceImplEntrance {
            protected static Logger logger = LoggerFactory.getLogger(NcpServiceImplEntrance.class);

            public static Boolean evaluate(JavaNode treenode, Rule rule) {
                if (treenode == null) {
                    return false;
                }

                if (!(treenode instanceof ASTCompilationUnit)) {
                    return false;
                }

                AbstractJavaNode decl = InterDataCache.getInstance().findDefinedClassNodeByRootNode((ASTCompilationUnit)treenode);
                if(decl instanceof ASTClassOrInterfaceDeclaration){
                    String className = ((ASTClassOrInterfaceDeclaration) decl).getClassName();
                    List<String> interfaces = InterDataCache.getInstance().findInterfaceByClassName(className);
                    for(String inter:interfaces){
                        Node node = InterDataCache.getInstance().findClassNode(inter);
                        if(ASTUtil.findFirstNode(node,"./parent::TypeDeclaration/Annotation//Name[@Image='NcpService']")!=null){
                            return true;
                        }
                    }
                }
                return false;
            }
        }
                            