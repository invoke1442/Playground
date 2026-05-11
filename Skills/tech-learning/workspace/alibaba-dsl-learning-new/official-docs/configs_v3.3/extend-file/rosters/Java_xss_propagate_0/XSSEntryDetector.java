

package com.taobao.customrule;

import com.sun.xml.bind.v2.TODO;
import net.sourceforge.pmd.lang.ast.Node;
import com.taobao.stc.pmd.rule.security.*;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.util.ASTUtil;
import org.apache.ecs.wml.B;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import com.taobao.stc.pmd.rule.security.BaseTaintedDataRule;

import java.util.List;
import java.util.*;

/**
 * @author wenyuan.xwy@alibaba-inc.com
 * @date 2021/9/30 10:30
 * <p>
 * 1. XSS issues are reported only when request method support GET. Consider the following cases:
 * +----------------------------+-------------------+-------------+--------------+----------------------------+
 * | Class\Method               | @RequestMapping() | @GetMapping | @PostMapping | @RequestMapping(method=M2) |
 * +============================+===================+=============+==============+============================+
 * | NULL                       | any               | ∅ ∪ {GET}   | ∅ ∪ {POST}   | ∅ ∪ M2                     |
 * +----------------------------+-------------------+-------------+--------------+----------------------------+
 * | @RequestMapping()          | any               | ∅ ∪ {GET}   | ∅ ∪ {POST}   | ∅ ∪ M2                     |
 * +----------------------------+-------------------+-------------+--------------+----------------------------+
 * | @RequestMapping(method=M1) | ∅ ∪ {M1}          | M1 ∪ {GET}  | M1 ∪ {POST}  | M1 ∪ M2                    |
 * +----------------------------+-------------------+-------------+--------------+----------------------------+
 * <p>
 * 2. XSS issues are reported only when response's type support text/html. Consider the following cases(method will rewrite the type definition):
 * +--------------+------+-------------+--------------+
 * | Class\Method | NULL | produces={} | produces={y} |
 * +==============+======+=============+==============+
 * | NULL         | any  | any         | {y}          |
 * +--------------+------+-------------+--------------+
 * | produces={}  | any  | any         | {y}          |
 * +--------------+------+-------------+--------------+
 * | produces={x} | {x}  | {x}         | {y}          |
 * +--------------+------+-------------+--------------+
 */
public class XSSEntryDetector {
    protected static Logger logger = LoggerFactory.getLogger(XSSEntryDetector.class);
    public static final List<String> safeContentTypes = new ArrayList<String>(Arrays.asList("application/json", "text/json","application/javascript","application/octet-stream","text/json", "application/vnd.ms-excel"));

    enum Method {
        GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS, TRACE
    }

    enum ContentType {
        HTML, // text/html ： HTML格式
        PLAIN, // text/plain ：纯文本格式
        XML, // text/xml, application/xml： XML数据格式
        GIF, // image/gif ：gif图片格式
        JPEG, // image/jpeg ：jpg图片格式
        PNG, // image/png：png图片格式
        XHTML, // application/xhtml+xml ：XHTML格式
        ATOM_XML, // application/atom+xml ：Atom XML聚合格式
        JSON, // application/json： JSON数据格式
        PDF, // application/pdf：pdf格式
        MSWORD, // application/msword ： Word文档格式
        STREAM, // application/octet-stream ： 二进制流数据（如常见的文件下载）
        FORM, // application/x-www-form-urlencoded
        NULL, // not set ( )
        EMPTY, // empty set ( {} )
    }


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
        ASTMethodDeclaration methodDeclaration = ((ASTMethodDeclaration) treenode);

        String setContentType = getSetContentType(methodDeclaration);
        //新增针对非Springboot情况下的检测
        boolean supportHtml = false;

        if(setContentType.equals("JSON")||setContentType.equals("Other")||(isNcpImpl(methodDeclaration)&&setContentType.equals("NULL"))){
            //如果contentType为application/json则认为安全
            return true;
        }
        // 判断是否入口函数

        List<ASTAnnotation> classAnnotations = methodDeclaration.getNthParent(4).findChildrenOfType(ASTAnnotation.class);
        // Test if controller belongs to springboot framework, otherwise we can't support.
        boolean isSpringboot = false;
        for (ASTAnnotation annotation : classAnnotations) {
            ASTName name = annotation.getFirstDescendantOfType(ASTName.class);
            if (name.getImage().contains("Controller")) {
                isSpringboot = true;
                break;
            }
        }

        if (!isSpringboot) {
            return false;
        }

        boolean supportGet = false;
        List<ASTAnnotation> methodAnnotations = methodDeclaration.jjtGetParent().findChildrenOfType(ASTAnnotation.class);
        Set<Method> annotations = getSupportedMethods(classAnnotations);
        annotations.addAll(getSupportedMethods(methodAnnotations));
        if (annotations.contains(Method.GET) || annotations.isEmpty()) {
            supportGet = true;
        }

        boolean isUserSetProduces = false;
        Set<ContentType> classTypes = getSupportedContentTypes(classAnnotations);
        Set<ContentType> methodTypes = getSupportedContentTypes(methodAnnotations);
        if (classTypes.isEmpty() || classTypes.contains(ContentType.NULL) || classTypes.contains(ContentType.EMPTY)) {
            if (methodTypes.isEmpty() || methodTypes.contains(ContentType.NULL) || methodTypes.contains(ContentType.EMPTY)) {
                supportHtml = true;
                isUserSetProduces =true;
            } else if (methodTypes.contains(ContentType.HTML)) {
                supportHtml = true;
            } else {
                supportHtml = false;
            }
        } else if (classTypes.contains(ContentType.HTML)) {
            if (methodTypes.isEmpty() || methodTypes.contains(ContentType.NULL) || methodTypes.contains(ContentType.EMPTY)) {
                supportHtml = true;
            } else if (methodTypes.contains(ContentType.HTML)) {
                supportHtml = true;
            } else {
                supportHtml = false;
            }
        }



        //安全的情况：若不存在注解，需要SetContentType为json；若存在注解，注解Produces、setContentType不存在或未设置成html且方法ResultType不是String，则认为安全中断扫描
        //不安全的情况：setContentType、Produces等强制返回contentType为text/html，需要进一步扫描

        //检测SetContentType 如果限制为ContentType为html则继续检测，为json则安全。
        String setContentTypeInFunc = getSetContentType(methodDeclaration);
        String setContentTypeInResponseEntity = getResponseEntityType(methodDeclaration);
        if(!(setContentTypeInFunc.equals("HTML"))&&!(setContentTypeInFunc.equals("NULL"))){
            supportHtml = false ;
        }
        if(!(setContentTypeInResponseEntity.equals("HTML"))&&!(setContentTypeInResponseEntity.equals("NULL"))){
            supportHtml = false ;
        }
        //检测ResultType是否String 是的话contentType还是text/html
        //先检测是否存在注解，如存在且满足注解均未被Produces限制，ResultType不是String、无setContentType的情况认为安全
        if (hasJsonAnnotation(methodAnnotations) || hasJsonAnnotation(classAnnotations)){
            //if(checkProduces(methodAnnotations) && checkProduces(classAnnotations) && setContentType.equals("NULL") && isResultTypeNotString(methodDeclaration)){
            if(isUserSetProduces && setContentType.equals("NULL") && isResultTypeNotString(methodDeclaration)){
                return true;
            }
        }



        if (supportHtml) {
            return false;
            //不中断
        } else {
            return true;
        }
    }
    static Boolean isNormalWrite(List<ASTAnnotation> annotations){
        //TODO
        return true;
    }

    static Boolean hasJsonAnnotation(List<ASTAnnotation> annotations) {
        Boolean checkFlag = false;
        //安全配置
        for (ASTAnnotation annotation : annotations) {
            ASTName name = annotation.getFirstDescendantOfType(ASTName.class);
            if (name != null && name.getImage() != null) {
                String image = name.getImage();
                if ("RestController".equals(image) || "ResponseBody".equals(image)) {
                    return true;
                }
            }
        }
        return false;
    }
    static Boolean  checkProduces(List<ASTAnnotation> annotations) {
        for (ASTAnnotation annotation : annotations) {
            ASTName name = annotation.getFirstDescendantOfType(ASTName.class);
            if (name != null && name.getImage() != null) {
                String image = name.getImage();

                if (image.endsWith("Mapping")) {
                    // RequestMapping() & RequestMapping(method=x) & RequestMapping(method={})
                    String xpath = "./NormalAnnotation/MemberValuePairs/MemberValuePair[@Image='produces']";
                    ASTMemberValuePair memberValuePair = (ASTMemberValuePair) ASTUtil.findFirstNode(annotation, xpath);
                    if (memberValuePair != null) {
                        xpath = ".//MemberValue/PrimaryExpression/PrimaryPrefix/Literal";

                        List<Node> contentNames = ASTUtil.findNodes(memberValuePair, xpath);
                        for (int i = 0; i < contentNames.size(); i++) {
                            ASTLiteral methodName = (ASTLiteral) contentNames.get(i);
                            if (methodName.getImage().contains("text/html")) {
                                return false;
                            }
                        }
                    }
                }
            }
        }
        return true;
    }

    /**
     * @param annotations springboot annotations AST on class or method
     * @return ∅            if RequestMapping()
     * {any}        if RequestMapping(method={})
     * {x}          if RequestMapping(method=x)
     * {x, y, z}    if RequestMapping(method={x, y, z})
     * ∅            others
     */
    static Set<Method> getSupportedMethods(List<ASTAnnotation> annotations) {
        Set<Method> supportedMethods = new HashSet<>();
        for (ASTAnnotation annotation : annotations) {

            ASTName name = annotation.getFirstDescendantOfType(ASTName.class);
            if (name != null && name.getImage() != null) {
                String image = name.getImage();
                if ("RequestMapping".equals(image)) {
                    // RequestMapping() & RequestMapping(method=x) & RequestMapping(method={})
                    String xpath = "./NormalAnnotation/MemberValuePairs/MemberValuePair[@Image='method']";
                    ASTMemberValuePair memberValuePair = (ASTMemberValuePair) ASTUtil.findFirstNode(annotation, xpath);
                    if (memberValuePair == null) {
                        // RequestMapping()
                        return supportedMethods;
                    } else {
                        xpath = ".//MemberValue/PrimaryExpression/PrimaryPrefix/Name";
                        List<Node> methodNames = ASTUtil.findNodes(memberValuePair, xpath);
                        if (methodNames.isEmpty()) {
                            // RequestMapping(method={})
                            supportedMethods.add(Method.GET);
                            supportedMethods.add(Method.POST);
                            supportedMethods.add(Method.PUT);
                            supportedMethods.add(Method.DELETE);
                            supportedMethods.add(Method.PATCH);
                            supportedMethods.add(Method.HEAD);
                            supportedMethods.add(Method.OPTIONS);
                            supportedMethods.add(Method.TRACE);
                        } else {
                            // RequestMapping(method={A,B,C,...})
                            for (int i = 0; i < methodNames.size(); i++) {
                                ASTName methodName = (ASTName) methodNames.get(i);
                                if ("RequestMethod.GET".equals(methodName.getImage()) || "GET".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.GET);
                                } else if ("RequestMethod.POST".equals(methodName.getImage()) || "POST".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.POST);
                                } else if ("RequestMethod.PUT".equals(methodName.getImage()) || "PUT".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.PUT);
                                } else if ("RequestMethod.DELETE".equals(methodName.getImage()) || "DELETE".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.DELETE);
                                } else if ("RequestMethod.PATCH".equals(methodName.getImage()) || "PATCH".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.PATCH);
                                } else if ("RequestMethod.HEAD".equals(methodName.getImage()) || "HEAD".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.HEAD);
                                } else if ("RequestMethod.OPTIONS".equals(methodName.getImage()) || "OPTIONS".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.OPTIONS);
                                } else if ("RequestMethod.TRACE".equals(methodName.getImage()) || "TRACE".equals(methodName.getImage())) {
                                    supportedMethods.add(Method.TRACE);
                                }
                            }
                        }
                    }
                } else if (image.endsWith("Mapping")) {
                    // {GET, POST, PUT}Mapping
                    if ("GetMapping".equals(image)) {
                        supportedMethods.add(Method.GET);
                    } else if ("PostMapping".equals(image)) {
                        supportedMethods.add(Method.POST);
                    } else if ("PutMapping".equals(image)) {
                        supportedMethods.add(Method.PUT);
                    } else if ("DeleteMapping".equals(image)) {
                        supportedMethods.add(Method.DELETE);
                    } else if ("PatchMapping".equals(image)) {
                        supportedMethods.add(Method.PATCH);
                    }

                }
            }
        }
        return supportedMethods;
    }

    static Set<ContentType> getSupportedContentTypes(List<ASTAnnotation> annotations) {
        Set<ContentType> supportedContents = new HashSet<>();
        for (ASTAnnotation annotation : annotations) {
            ASTName name = annotation.getFirstDescendantOfType(ASTName.class);
            if (name != null && name.getImage() != null) {
                String image = name.getImage();
                if (image.endsWith("Mapping")) {
                    // RequestMapping() & RequestMapping(method=x) & RequestMapping(method={})
                    String xpath = "./NormalAnnotation/MemberValuePairs/MemberValuePair[@Image='produces']";
                    ASTMemberValuePair memberValuePair = (ASTMemberValuePair) ASTUtil.findFirstNode(annotation, xpath);
                    if (memberValuePair == null) {
                        // RequestMapping()
                        supportedContents.add(ContentType.NULL);
                        return supportedContents;
                    } else {
                        xpath = ".//MemberValue/PrimaryExpression/PrimaryPrefix/Literal";
                        boolean isEmpty=true;
                        List<Node> contentNames = ASTUtil.findNodes(memberValuePair, xpath);
                        if (!contentNames.isEmpty()) {
                            isEmpty=false;
                            // RequestMapping(method={A,B,C,...})
                            for (int i = 0; i < contentNames.size(); i++) {
                                ASTLiteral methodName = (ASTLiteral) contentNames.get(i);
                                if (methodName.getImage().contains("!text/html")) {
                                    supportedContents.add(ContentType.JSON);
                                } else if (methodName.getImage().contains("text/html")) {
                                    supportedContents.add(ContentType.HTML);
                                } else {
                                    supportedContents.add(ContentType.JSON);
                                }
                            }
                        }
                        xpath = ".//MemberValue/PrimaryExpression/PrimaryPrefix/Name";
                        contentNames = ASTUtil.findNodes(memberValuePair, xpath);
                        if (!contentNames.isEmpty()) {
                            // RequestMapping(method={A,B,C,...})
                            isEmpty=false;
                            for (int i = 0; i < contentNames.size(); i++) {
                                ASTName methodName = (ASTName) contentNames.get(i);
                                if (methodName.getImage().endsWith("TEXT_HTML_VALUE")
                                        ||methodName.getImage().endsWith("TEXT_HTML")
                                ) {
                                    supportedContents.add(ContentType.HTML);
                                } else {
                                    supportedContents.add(ContentType.JSON);
                                }
                            }
                        }
                        if (isEmpty){
                            supportedContents.add(ContentType.EMPTY);
                        }
                    }
                }
            }
        }
        return supportedContents;
    }
    public static String getResponseEntityType(ASTMethodDeclaration methodDeclaration) {
        //for .ok
        String xpath = ".//BlockStatement/Statement/ReturnStatement/Expression/PrimaryExpression/PrimaryPrefix/Name";
        //for header/contenttype
        String xpath2 = ".//BlockStatement/Statement/ReturnStatement/Expression/PrimaryExpression/PrimarySuffix";
        List<Node> contentNamesForResponseEntity = ASTUtil.findNodes(methodDeclaration, xpath);
        for (Node name : contentNamesForResponseEntity) {
            if (name != null && name.getImage() != null) {
                String image = name.getImage();
                if (image.endsWith("ResponseEntity.ok")) {
                    List<Node> funcNames = ASTUtil.findNodes(methodDeclaration, xpath2);
                    for (Node name2 : funcNames) {
                        if (name2 != null && name2.getImage() != null) {
                            String image2 = name2.getImage();
                            if (image2.endsWith("header") || image2.endsWith("Header")) {
                                String literalXpath = ".//BlockStatement/Statement/ReturnStatement/Expression/PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Literal";
                                List<Node> literaltNames = ASTUtil.findNodes(methodDeclaration, literalXpath);
                                for (int x = 0; x < literaltNames.size(); x = x + 1) {
                                    if (literaltNames.get(x) != null && literaltNames.get(x).getImage() != null) {
                                        if (literaltNames.get(x).getImage().toLowerCase().contains("content-type")) {
                                            if (literaltNames.get(x+1) != null && isSafeContentType(literaltNames.get(x+1).getImage().toLowerCase())) {
                                                return "JSON";
                                            } else if (literaltNames.get(x+1) != null &&  literaltNames.get(x + 1).getImage().toLowerCase().contains("text/html")) {
                                                return "HTML";
                                            }
                                        }
                                    }
                                }
                                String nameXpath = ".//ReturnStatement/Expression/PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name";
                                List<Node> nameNames = ASTUtil.findNodes(methodDeclaration, nameXpath);
                                for (int x = 0; x < nameNames.size(); x = x + 1) {
                                    if (nameNames.get(x) != null && nameNames.get(x).getImage() != null) {
                                        if (nameNames.size() > x+1 && ((nameNames.get(x).getImage().toLowerCase().contains("content_type")) || (nameNames.get(x).getImage().toLowerCase().contains("content-type")))) {
                                            if (nameNames.get(x+1) != null && nameNames.get(x + 1).getImage().toLowerCase().contains("json")) {
                                                return "JSON";
                                            } else if (nameNames.get(x+1) != null &&  nameNames.get(x + 1).getImage().toLowerCase().contains("text_html")) {
                                                return "HTML";
                                            }
                                        }
                                    }
                                }
                                return "Other";
                            } else if (image2.endsWith("contentType")){
                                String literalXpath = ".//PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Literal";
                                List<Node> literaltNames = ASTUtil.findNodes(methodDeclaration, literalXpath);
                                for (int x = 0; x < literaltNames.size(); x = x + 1) {
                                    if (literaltNames.get(x) != null && literaltNames.get(x).getImage() != null) {
                                        if (isSafeContentType(literaltNames.get(x).getImage().toLowerCase())){
                                            return  "JSON";
                                        }else if (literaltNames.get(x).getImage().toLowerCase().contains("text/html")) {
                                            return "HTML";
                                        }
                                    }
                                }
                                String nameXpath = ".//PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name";
                                List<Node> nameNames = ASTUtil.findNodes(methodDeclaration, nameXpath);
                                for (int x = 0; x < nameNames.size(); x = x + 1) {
                                    if (nameNames.get(x) != null && nameNames.get(x).getImage() != null) {
                                        if (nameNames.get(x).getImage().toLowerCase().contains("json")){
                                            return  "JSON";
                                        }else if (nameNames.get(x).getImage().toLowerCase().contains("text_html")) {
                                            return "HTML";
                                        }
                                    }
                                }
                                return "Other";
                            }
                        }
                    }
                }
            }

        }
        return "NULL";
    }
    //检测是否使用setContentType 返回限定的ContentType
    //https://pre-stc-server.alibaba-inc.com/leak-scan/#/rule/fbiDetail?id=2ccc6454-ee7a-43f7-9981-2180aa20ae9d&tag=baseLineUdfScan
    public static String getSetContentType(ASTMethodDeclaration methodDeclaration) {
        int n =methodDeclaration.jjtGetNumChildren();
        List list = new ArrayList();

        for(int i =0; i < n; i++){
            List<Node> contentNames = new ArrayList<>();
            List<Node> contentNames1 = new ArrayList<>();
            List<Node> contentNames2 = new ArrayList<>();
            Node child=methodDeclaration.jjtGetChild(i);
            String xpath=".//BlockStatement/Statement/StatementExpression/PrimaryExpression/PrimaryPrefix/Name";
            contentNames1 = ASTUtil.findNodes(child, xpath);
            String xpath2=".//BlockStatement/Statement/StatementExpression/PrimaryExpression/PrimarySuffix";
            contentNames2 = ASTUtil.findNodes(child, xpath2);
            contentNames.addAll(contentNames1);
            contentNames.addAll(contentNames2);
            for (Node name : contentNames){
                if(name != null && name.getImage() != null){
                    String image = name.getImage();
                    if(image.endsWith("setContentType")){
                        //检测setContentType中是否为text/html
                        String literalXpath=".//BlockStatement/Statement/StatementExpression/PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Literal";
                        List<Node> literaltNames = ASTUtil.findNodes(child, literalXpath);
                        for(Node literal:literaltNames ){
                            if(literal != null && literal.getImage() != null){
                                String literalImage = literal.getImage();
                                if(literalImage.toLowerCase().contains("text/html")){
                                    //设置contentType为text/html 不安全
                                    return "HTML";
                                }
                                //safeContentTypes.contains(literaltNames.get(x+1).getImage().toLowerCase())
                                else if(isSafeContentType(literalImage.toLowerCase())){
                                    // 设置contentType为json 安全
                                    return "JSON";
                                }
                            }
                        }

                        String nameXpath=".//BlockStatement/Statement/StatementExpression/PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name";
                        List<Node> nameNames = ASTUtil.findNodes(child,nameXpath);
                        for(Node literal:nameNames ){
                            if(literal != null && literal.getImage() != null){
                                String literalImage = literal.getImage();
                                if(literalImage.contains("TEXT_HTML_VALUE")){
                                    //设置contentType为text/html 不安全
                                    return "HTML";
                                }
                            }
                        }

                        return "Other";
                        //新增对setheader的检测，当setheader存在且第一个参数是Content-type，根据第二个参数判断返回格式
                    } else if (image.endsWith("addHeader")||image.endsWith("setHeader")||image.endsWith(".add")){
                        String literalXpath= ".//BlockStatement/Statement/StatementExpression/PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Literal";
                        List<Node> literaltNames = ASTUtil.findNodes(child, literalXpath);
                        String nameXpath= ".//BlockStatement/Statement/StatementExpression/PrimaryExpression/PrimarySuffix/Arguments/ArgumentList/Expression/PrimaryExpression/PrimaryPrefix/Name";
                        List<Node> nameNames = ASTUtil.findNodes(child, nameXpath);
                        for(int x = 0 ;x < literaltNames.size();x=x+1){
                            if(literaltNames.get(x) != null && literaltNames.get(x).getImage() != null){
                                if(literaltNames.get(x).getImage().toLowerCase().contains("content-type")){
//                                    if(nameNames.get()!= null && nameNames.get(x).getImage() != null){
//                                        if(literaltNames.get(x+1).getImage().contains("TEXT_HTML")){
//                                            return "HTML";
//                                        }
//                                    }
                                    if(literaltNames.size() > x+1){
                                        if (isSafeContentType(literaltNames.get(x+1).getImage().toLowerCase())){
                                            return "JSON";
                                        } else if (literaltNames.get(x+1).getImage().toLowerCase().contains("text/html")) {
                                            return "HTML";
                                        } else {
                                            return "Other";
                                        }
                                    }

                                }
                            }
                        }
                        // return "NULL";
                    }
                }
            }
        }
        //无setContentType 继续检测
        return "NULL";
    }

    public static Boolean isResultTypeNotString(ASTMethodDeclaration methodDeclaration) {
        int n =methodDeclaration.jjtGetNumChildren();
        List list = new ArrayList();
        Node child=methodDeclaration.jjtGetChild(0);
        String xpath=".//Type/ReferenceType/ClassOrInterfaceType";
        List<Node> contentNames = ASTUtil.findNodes(child, xpath);
        for (Node name : contentNames){
            if(name != null && name.getImage() != null){
                String image = name.getImage();
                if(image.equals("String") || image.equals("ResponseEntity")){
                    //检测ResultType是否为String或ResponseEntity
                    return false;
                }
            }
        }
        //无setContentType 继续检测
        return true;
    }

    public static Boolean isSafeContentType(String contentType){
        String[] realContentType = contentType.replace("'","").replace("\"","").split(";");
        for(int i =0; i < realContentType.length ; i++){
            if(safeContentTypes.contains(realContentType[i])){
                return true;
            }
        }
        return false;
    }
    public static Boolean isNcpImpl(ASTMethodDeclaration methodDeclaration){
        Node child=methodDeclaration.jjtGetParent().jjtGetParent().jjtGetParent().jjtGetParent();
        String Implxpath=".//ImplementsList/ClassOrInterfaceType";
        String namexpath=".//ClassOrInterfaceDeclaration";
        String importXpath="/ImportDeclaration/Name";
        List<Node> ImplxpathcontentNames = ASTUtil.findNodes(child, Implxpath);
        List<Node> NamecontentNames = ASTUtil.findNodes(child, namexpath);
        List<Node> ImportNames = ASTUtil.findNodes(child, importXpath);
        for (Node Implname : ImplxpathcontentNames){
            if(Implname != null && Implname.getImage() != null){
                String image1 = Implname.getImage();
                if(image1.endsWith("Service")){
                    for (Node name : NamecontentNames){
                        if(name != null && name.getImage() != null){
                            String image2 = name.getImage();
                            if(image2.endsWith("Impl")){
                                for (Node Importname : ImportNames){
                                    if(Importname != null && Importname.getImage() != null){
                                        String Importimage3 = Importname.getImage();
                                        if(Importimage3.contains("me.ele")){

                                            return true;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        //无Ncp
        return false;
    }
}
                   