# GitHub CTF4 文档设计

## 目标

为 GitHub Security Lab 的 CodeQL and Chill Java 版 CTF 生成一篇可直接纳入本地知识库的中文技术文档，兼顾：

- 学习者视角：解释 Java Bean Validation、消息插值、EL 执行、容器平台场景。
- 安全分析视角：说明漏洞成因、威胁模型、利用链与修复面。
- CodeQL 视角：解释为什么这个题的关键在于 source、sink、partial flow 和 additional taint steps。

## 受众

- 正在学习 CodeQL for Java 的安全研究者
- 想理解 Bean Validation 注入面与 Java 服务端模板/表达式执行风险的工程师
- 在本地维护 CodeQL 学习笔记的读者

## 输出位置

- 主文档：Tech-Learning/CodeQL/codeql-java-learning/codeql-java-vul/github-ctf4/GitHub-CTF4-Titus-BeanValidation-EL注入详解.md

## 采用结构

采用方案 C：双主线混合型。

1. CTF 概览
2. 相关技术栈介绍
3. 漏洞原理
4. 威胁模型
5. 利用方式与攻击链
6. 与 SSTI 的关系与区别
7. CodeQL 检测思路
8. 修复与缓解建议
9. 学习要点总结

## 内容边界

- 以官方 challenge、参考答案、Bean Validation 2.0 规范和 GHSL 通告为主。
- 不复现真实攻击 payload 的危险细节，不提供可直接用于未授权攻击的执行型利用代码。
- PoC 部分只说明利用条件与链路，不给出破坏性命令。

## 关键论点

- 这类漏洞的根因不是“普通字符串拼接”本身，而是“把不可信数据拼进会被后续解释执行的消息模板”。
- Bean Validation 在现代 Java 服务端里是一个跨层基础设施，因此攻击面常出现在“校验失败路径”而不是“业务成功路径”。
- CodeQL 默认数据流模型不会主动把 getter、集合操作、构造器、异常消息等都视为 taint 传播，题目的核心训练点就是补齐这些领域特定语义。

## 预期产出风格

- 中文、面向学习笔记
- 解释性强于结论堆砌
- 章节内兼顾概念、代码语义和检测思路
- 使用少量 Mermaid 图帮助理解攻击链与组件关系