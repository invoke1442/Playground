# Gosec 自定义安全规则开发全指南 (新人手册)

本指南涵盖了 `gosec` 中两种主要的规则开发模式：**AST 模式**（简单语法检查）与 **Taint 模式**（高级污点分析）。

---

## 1. 规则模式：我该选哪种？

| 模式 | 适用场景 | 底层技术 | 实现难度 |
| :--- | :--- | :--- | :--- |
| **AST 模式** | 看到特定代码就报警（如：`md5.New()`，`os.Mkdir(..., 0777)`） | 基于语法树匹配 | 简单 |
| **Taint 模式** | 追踪不安全数据的流向（如：SQL 注入、命令注入） | 基于 SSA 和数据流追踪 | 中等 (声明式) |

---

## 2. AST 模式：简单语法匹配 (推荐入门)

AST（抽象语法树）模式用于检查代码的静态结构。例如，你想要禁止在项目中使用某个危险函数。

### 第一步：创建规则实现
**文件位置**：`rules/<规则名>.go`

```go
package rules

import (
	"go/ast"
	"github.com/securego/gosec/v2"
	"github.com/securego/gosec/v2/issue"
)

type myASTRule struct {
	callListRule // 使用内置辅助类简化函数名匹配
}

// 构造函数
func NewMyASTRule(id string, _ gosec.Config) (gosec.Rule, []ast.Node) {
	rule := &myASTRule{
		callListRule: newCallListRule(id, "发现不安全的函数调用", issue.Medium, issue.High),
	}
	// 只要代码中出现 net/http.ListenAndServe 就报警
	rule.Add("net/http", "ListenAndServe") 
	return rule, []ast.Node{(*ast.CallExpr)(nil)}
}
```

### 第二步：注册规则
**文件位置**：`rules/rulelist.go`

在 `Generate` 函数的 `rules` 切片中新增一行：
```go
{"G999", "My custom AST rule", NewMyASTRule},
```

---

## 3. Taint 模式：高级污点分析 (跨函数追踪)

如果你需要判断一个变量是否来自攻击者（Source），并最终进入了危险函数（Sink），请使用此模式。

### 第一步：创建逻辑定义
**文件位置**：`analyzers/<规则名>.go`

```go
package analyzers

import (
	"github.com/securego/gosec/v2/taint"
	"golang.org/x/tools/go/analysis"
)

func MyTaintConfig() taint.Config {
	return taint.Config{
		Sources: []taint.Source{
			{Package: "os", Name: "Getenv", IsFunc: true},
		},
		Sinks: []taint.Sink{
			{Package: "net/http", Method: "Get", CheckArgs: []int{0}},
		},
	}
}

func newMyTaintAnalyzer(id string, description string) *analysis.Analyzer {
	config := MyTaintConfig()
	rule := MyTaintMetadata // 定义在下方的元数据中
	rule.ID = id
	rule.Description = description
	return taint.NewGosecAnalyzer(&rule, &config)
}
```

### 第二步：注册元数据与构造函数
**文件位置**：`analyzers/analyzerslist.go`

在 `var (...)` 区中定义元数据：
```go
MyTaintMetadata = taint.RuleInfo{
    ID: "G701", Description: "...", Severity: "HIGH",
}
```
并在 `defaultAnalyzers` 切片中注册 `newMyTaintAnalyzer`。

---

## 4. 调试与发布

1.  **编译自定义二进制文件**：
    `go build -o gosec ./cmd/gosec/main.go`
2.  **指定规则运行**：
    `./gosec -include=你的规则ID .`
3.  **查看详细日志**：
    使用 `-v` 参数确认规则是否被正确加载。

> [!TIP]
> 绝大多数简单的 API 审计场景建议先尝试 **AST 模式**；只有当“变量传递”成为误报主要来源时，才考虑升级为 **Taint 模式**。
