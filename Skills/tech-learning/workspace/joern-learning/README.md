# Joern 学习文档索引

本目录按主题拆分了 7 份 Joern 深度学习文档，目标读者是“零基础到初学但愿意做工程实践的人”。

建议阅读顺序：

1. `01-joern-open-source.md`
2. `02-joern-supported-languages.md`
3. `03-joern-cli-guide.md`
4. `05-joern-static-analysis-principles-and-workflow.md`
5. `06-joern-common-rule-syntax.md`
6. `04-joern-querydb-and-rules-repo.md`
7. `07-joern-vulnerability-scanning-best-practices.md`

文件说明：

- `01-joern-open-source.md`：Joern 是否开源、开源到什么程度、仓库结构怎么看、版本节奏怎么理解。
- `02-joern-supported-languages.md`：Joern 支持哪些语言、前端怎么分层、不同语言适合怎么导入。
- `03-joern-cli-guide.md`：`joern`、`joern-scan`、`joern-parse`、`joern-export`、`joern-flow`、`joern-slice`、`joern-vectors` 的参数和用法。
- `04-joern-querydb-and-rules-repo.md`：规则仓 `querydb` 的结构、加载机制、发布方式、扩展方式。
- `05-joern-static-analysis-principles-and-workflow.md`：CPG、overlay、数据流、查询、扫描的完整工作流。
- `06-joern-common-rule-syntax.md`：常用规则语法、查询骨架、数据流规则、测试和避坑。
- `07-joern-vulnerability-scanning-best-practices.md`：真实工程中的漏洞扫描流程、分层策略、误报控制、团队落地。

说明：

- 所有文档以 Joern 官方文档和 `joernio/joern` 官方 GitHub 仓库为主轴整理。
- 涉及“最新版本”的地方，已按 2026-03-19 实际联网核对。
- 每篇文档都包含记忆卡片、正文、练习与复习闭环、参考来源与版本说明。
- 7 份正文中的 Mermaid 图已于 2026-03-19 在当前环境用 `npx @mermaid-js/mermaid-cli` 完成编译验证。
