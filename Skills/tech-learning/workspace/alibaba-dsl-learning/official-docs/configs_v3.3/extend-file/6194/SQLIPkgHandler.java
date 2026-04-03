
package com.taobao.customrule;

import com.taobao.stc.pmd.rule.model.incremental.EncapsulationFeature;
import com.taobao.stc.pmd.rule.model.incremental.IncMethodSummary;
import com.taobao.stc.pmd.rule.model.incremental.SinkEncapFeature;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRule;
import com.taobao.stc.pmd.rule.security.AbstractTaintedDataRuleData;
import net.sourceforge.pmd.lang.java.ast.JavaNode;
import net.sourceforge.pmd.util.CodeUtil;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.regex.Pattern;

/**
 * 删除特定二三方包的函数摘要避免误报 - 无风险或sink前置
 */
public class SQLIPkgHandler {
    protected static Logger logger = LoggerFactory.getLogger(SQLIPkgHandler.class);
    private static final Pattern IgnorePkg = Pattern.compile("(?i)(ibatis|mybatis|xbatis)");
    private static Boolean filtered = false;

    public static Boolean evaluate(JavaNode treenode, AbstractTaintedDataRule rule, AbstractTaintedDataRuleData data) {
        synchronized (filtered) {
            if (!filtered) {
                filterSummary(rule, "sqlInjectionJava");
                filterSummary(rule, "HSF_sqlInjectionJava");
                filtered = true;
            }
        }
        return false;
    }

    public static void filterSummary(AbstractTaintedDataRule rule,String subType){
        Map<String, IncMethodSummary> summarys = rule.getExternTaintSummarys().get(subType);
        if(summarys == null){
            return;
        }
        Map<String, IncMethodSummary> newSummary = new HashMap<>();
        for(Map.Entry<String, IncMethodSummary> entry:summarys.entrySet()){
            String profile = entry.getKey();
            IncMethodSummary summary = entry.getValue();
            //如果没有sink封装信息则跳过
            boolean hasSink = false;
            for(EncapsulationFeature feature :summary.getEncapsulationFeatureSet().getFeatures()) {
                if (feature instanceof SinkEncapFeature) {
                    hasSink = true;
                    break;
                }
            }
            if(!hasSink){
                newSummary.put(profile,summary);
                continue;
            }

            String appName = summary.getAppName();
            //二方包appName示例：com.fasterxml.jackson.datatype:jackson-datatype-jsr310:2.9.10/8353DB784CC75E2EF48439C89FFB962B
            if(appName == null){
                newSummary.put(profile,summary);
                continue;
            }
            //非二三方包摘要跳过
            if(!appName.contains(":") || !appName.contains("/")){
                newSummary.put(profile,summary);
                continue;
            }

            //排除appName中的md5字段
            appName = appName.substring(0,appName.lastIndexOf("/"));

            String args[] = appName.split(":");
            if(args.length !=3){
                newSummary.put(profile,summary);
                continue;
            }

            if(!CodeUtil.isMatched(IgnorePkg, args[0] + ":" + args[1])) {
                newSummary.put(profile,summary);
                continue;
            }
        }
        rule.getExternTaintSummarys().put(subType,newSummary);
    }
}
