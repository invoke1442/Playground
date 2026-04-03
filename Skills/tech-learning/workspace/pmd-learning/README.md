# PMD 学习文档总览

本目录基于 PMD 官方文档 `https://docs.pmd-code.org/latest/` 与官方仓库 `https://github.com/pmd/pmd` 整理，访问日期均为 `2026-03-19`。

文档列表：

1. `01-pmd-open-source-overview.md`
2. `02-pmd-supported-languages.md`
3. `03-pmd-cli-usage.md`
4. `04-pmd-static-analysis-principles.md`
5. `05-pmd-rule-syntax.md`
6. `06-pmd-vulnerability-scanning-best-practices.md`

整理原则：

- 以 PMD 7.22.0 的 latest 文档为主轴。
- GitHub 仓库用于确认开源状态、仓库定位、README 描述和许可证。
- 每篇文档都包含记忆卡片、Mermaid 思维导图、正文、练习复习、来源映射。
- CLI 示例、规则示例和漏洞扫描流程主要依据官方资料解释；当前环境未安装 PMD 二进制分发包，因此命令示例未做本地运行验证。
- 6 篇主题文档的字符数均已检查，全部超过 5000 字。
- Mermaid 思维导图已从文档中提取并使用 `@mermaid-js/mermaid-cli` 编译为 SVG 做过验证，验证产物位于隐藏目录 `.mermaid-check/`。

官方章节映射概览：

- 开源性与项目定位：README、License、Installation、How PMD Works
- 支持语言：Language overview、Language configuration、Rule Reference、README
- CLI 用法：Installation and basic CLI usage、CLI reference、Incremental analysis、Report formats
- 静态分析原理：How PMD Works、Writing a custom rule、Your first rule、AST dump
- 规则语法：Making rulesets、Your first rule、Writing XPath rules、Writing a custom rule
- 漏洞扫描最佳实践：Best Practices、Making rulesets、CLI reference、Incremental analysis、Security rules pages
