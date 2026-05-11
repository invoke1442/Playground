
                                
package com.taobao.customrule;

import com.taobao.stc.pmd.model.PMDConstants;
import com.taobao.stc.pmd.rule.model.TaintedResult;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import com.taobao.stc.pmd.rule.security.BaseTaintedDataRule;
import com.taobao.stc.pmd.rule.security.BaseTaintedDataRuleData;
import net.sourceforge.pmd.cache.InterDataCache;
import net.sourceforge.pmd.lang.java.ast.*;
import net.sourceforge.pmd.trace.runtime.stack.MapOfVariable;
import net.sourceforge.pmd.util.CodeUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.ArrayList;
import java.util.regex.Pattern;

/**
 * @ClassName FilterSource
 * @Description 自定义source：用于Filter，将httpRequest.getRequestURI标记为污染
 * @Author liuziyin
 * @Author liuziyin
 * @Date 2022/9/27 17:50
 * Version 1.0
 **/
public class FilterSource {
    protected static Logger logger = LoggerFactory.getLogger(FilterSource.class);

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {
        String className = CodeUtil.getEnclosingClassName(rule.getCurrentEntrance());
        if (!InterDataCache.getInstance().getClassToFilter().containsKey(className)){
            return false;
        }

        if (treenode == null) {
            return false;
        }

        if (rule.getClass() != BaseTaintedDataRule.class) {
            return false;
        }
        BaseTaintedDataRule taintRule = (BaseTaintedDataRule) rule;
        BaseTaintedDataRuleData taintData = (BaseTaintedDataRuleData) data;

        if (!(treenode instanceof ASTPrimaryExpression)) {
            return false;
        }

        ASTPrimaryExpression astPrimaryExpression = (ASTPrimaryExpression) treenode;

        String callString = astPrimaryExpression.getCallString();
        if (checkIsSource(callString)){
            String image = "URLRedirect - Source in Filter";
            MapOfVariable var = MapOfVariable.getTempMapOfVariable(image);
            rule.setFlag("FilterUrlRedirect");
            TaintedResult result = new TaintedResult();
            result.setSink(PMDConstants.TaintedType.INPUT);
            astPrimaryExpression.setImage(image);
            result.setName(astPrimaryExpression);
            var.setImage(image);
            result.setTaintedVar(var);
            result.setMethodName(rule.getVisitedMethodShortName());
            result.setMethodSignature(rule.getVisitedMethodProfile());
            taintData.result = result;
            return true;
        }
        return false;
    }

    public static boolean checkIsSource(String callString){
        if (callString == null || "".equals(callString)) {
            return false;
        }

        // source return set
        ArrayList<String> sourceReturnSet = new ArrayList<>();
        sourceReturnSet.add("javax.servlet.http.HttpServletRequest.getRequestURI");
        sourceReturnSet.add("javax.servlet.http.HttpServletRequest.getInputStream");
        sourceReturnSet.add("javax.servlet.http.HttpServletRequest.getRemoteUser");
        sourceReturnSet.add("com.alibaba.citrus.service.form.impl.FormImpl.getForm");
        sourceReturnSet.add("com.alibaba.service.form.FormService.getForm");
        sourceReturnSet.add("javax.servlet.http.HttpServletRequest.getQueryString");
        sourceReturnSet.add("com.alibaba.citrus.service.form.impl.FormImpl.init");
        sourceReturnSet.add("org.apache.commons.fileupload.FileItem.getString");
        sourceReturnSet.add("org.springframework.web.socket.TextMessage.getPayload");
        sourceReturnSet.add("com.ali.shy.web.RequestCycle.getRequest.getQueryString");
        sourceReturnSet.add("org.springframework.web.multipart.MultipartFile.getOriginalFilename");
        sourceReturnSet.add("org.springframework.web.socket.TextMessage.asBytes");
        sourceReturnSet.add("org.springframework.web.socket.BinaryMessage.getPayload");
        if (sourceReturnSet.contains(callString)){
            return true;
        }

        // source return
        String sourceReturnPatternString = "\\bParameterParser\\.(getString|toQueryString)\\b|(Request|RequestWrapper)\\.(getInputStream|getParameterMap|getParameterNames|getParameterValues|getParameterValue|getParameter|getParameters)\\b|com.alibaba.citrus.service.upload.UploadService.parseRequest\\b|org.apache.commons.fileupload.\\w+?.parseRequest\\b|turbine.util.parser.ParameterParser\\b|\\bgetParameters\\.(getString|toQueryString|getFileItem|getFileItems|getStrings)\\b";
        Pattern sourceReturn = Pattern.compile(sourceReturnPatternString);
        if (CodeUtil.isMatched(sourceReturn, callString)) {
            return true;
        }

        return false;
    }
}

                            