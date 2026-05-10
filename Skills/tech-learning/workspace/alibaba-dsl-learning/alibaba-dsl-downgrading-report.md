# 一、只用 rule + roster，无法处理 结构匹配 + 否定过滤 （即semgrep 的 pattern-not 逻辑）；无法处理 实参字面量约束

## defect case 1: prohibit-jquery-html（无法处理 结构匹配 + 否定过滤）

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/jquery/security/audit/prohibit-jquery-html.yaml

```yaml
  patterns:
	# 源规则要求：先命中 .html(...)，再继续排除两个安全特例
  - pattern: |
	  $X.html(...)
  - pattern-not: |
	  $X.html("...",...)
  - pattern-not: $X.html()
```

### 分析

- 源规则要什么：先找到 `.html(...)` 调用，再排除 `.html("...")` 和 `.html()` 这两种安全情况。
- Alibaba DSL 只有什么：能写“`.html` 的第 0 个参数是 sink”这种方法级配置，也能写一些正则型 expression。
- Alibaba DSL 没有什么：没有在同一个调用点上继续追加“这个参数不是字面量”“这不是无参调用”这种结构过滤能力。
- 所以 translator 只能怎么降级：把“动态参数”粗略改写成一条正则，再把 `.html` 第 0 个参数当 sink；原来的两个排除条件都保不住。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260408-122245/001-prohibit-jquery-html/workspaces/2-translator/target_rule/rosters/JS_prohibit_jquery_html_config_0.ros

```text
Roster JS_prohibit_jquery_html_config {
	// Alibaba DSL 这里只有：用一条正则粗略表示“看起来像动态参数”
	// Alibaba DSL 没有：对同一个 .html 实参继续做 pattern-not 过滤
	source.expression += {
		taintTag = "jquery_html_dynamic_arg";
		value += "/\\.html\\s*\\(\\s*(?:[\"'][^\"']*[\"']\\s*\\+|`[^`]*\\$\\{[^}]+\\}[^`]*`|[^\"'\\)])/";
	};

	// Alibaba DSL 这里只有：把 .html 的第 0 个参数登记成 sink
	// Alibaba DSL 没有：区分“字面量参数”和“非字面量参数”
	sink.methodArg += {
		taintTag = "jquery_html_dynamic_arg";
		pattern += "/\\.html\\b/";
		paramIndex = 0;
	};

	// Alibaba DSL 这里只有：一个占位式排除项
	// Alibaba DSL 没有：和原 rule 等价的两条否定逻辑
	sanitizer.methodReturn += {
		pattern += "/a^/";
	};
}
```

## defect case 2: jdbc-sqli（无法处理 实参字面量约束）

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/sqli/jdbc-sqli.yaml

```yaml
	  # 源规则要求：把 String.format 产生的 $SQL 和后面的 execute 调用绑定到一起
	  - pattern-inside: |
		  String $SQL = String.format(...);
		  ...
		- pattern-inside: |
			$VAL $FUNC(...,String $SQL,...) {
			  ...
			}
	  # 源规则要求：排除纯常量拼接，这里靠 pattern-not-inside 做结构差集
	  - pattern-not-inside: |
		  String $SQL = "..." + "...";
		  ...
	  - pattern: $S.$METHOD($SQL,...)
	- pattern: |
		$S.$METHOD(String.format(...),...);
	- pattern: |
		$S.$METHOD($X + $Y,...);
  - pattern-either:
	- pattern-inside: |
		java.sql.Statement $S = ...;
		...
	- pattern-inside: |
		$TYPE $FUNC(...,java.sql.Statement $S,...) {
		  ...
		}
	# 源规则要求：这里再次排除纯常量 execute 调用
  - pattern-not: |
	  $S.$METHOD("..." + "...",...);
```

### 分析

- 源规则要什么：识别 `Statement.execute...` 这种 SQL 执行，但不要把“纯常量拼接 SQL”也算进去。
- Alibaba DSL 只有什么：能列 source，能列 sink，能做一些方法级 taint 连接。
- Alibaba DSL 没有什么：没有 `pattern-inside` / `pattern-not-inside` 这种“在同一个方法体里再做结构差集”的能力。
- 所以 translator 只能怎么降级：保留 `String.format`、形参、`execute*` 这些 source/sink 位点；原来“常量拼接不报”的约束消失。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-214357/005-jdbc-sqli/workspaces/2-translator/target_rule/rosters/JdbcSqliRoster_0.ros

```text
Roster JdbcSqliRoster {
	// Alibaba DSL 这里只有：把 format 返回值和形参直接当 source
	// Alibaba DSL 没有：保留“这个 $SQL 就是后面那个 execute 用到的 $SQL”这层局部绑定
	source.methodReturn += { precise = true; value = "java.lang.String.format"; };
	source.methodParam += { xpath = "//FormalParameter/VariableDeclaratorId"; tag = "jdbc_sqli_param"; };

	// Alibaba DSL 这里只有：execute 系列 sink 名单
	// Alibaba DSL 没有：把“纯常量拼接”从这些 sink 中再减掉
	sink.methodArg += { precise = true; value = "java.sql.Statement.executeQuery"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "java.sql.Statement.execute"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "java.sql.Statement.executeUpdate"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "java.sql.Statement.executeLargeUpdate"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "java.sql.Statement.addBatch"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "java.sql.Statement.nativeSQL"; param = "[{'position':0,'tainted':true}]"; };
}
```

# 二、只用 rule + roster 无法表示（source、sink、sanitizer、propagation）同一节点内的 AND 逻辑

## defect case 1: raw-html-join（无法表示同一节点内多个pattern间的 AND 逻辑）

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/browser/security/raw-html-join.yaml

```yaml
  patterns:
  - pattern-either:
	- patterns:
	  # 源规则要求：同一个 join 候选先命中主模式
	  - pattern: |
		  [..., $STRING, ...].join(...)
	  # 源规则要求：再对同一个 $STRING 追加二次约束，要求它像 HTML 片段
	  - metavariable-pattern:
		  metavariable: $STRING
		  language: generic
		  patterns:
			  - pattern-either: 
				  - pattern: |
					  ... </$TAG
				  - pattern: |
					  <$TAG ...
		  # 源规则要求：最后还要在同一个 join 候选上排除全常量情况
	  - pattern-not: |
		  [..., "$HARDCODED", ...].join("...")
```

### 分析

- 源规则要什么：同一个 `.join(...)` 候选必须同时满足三件事。第一，它是目标 join；第二，数组里那个元素真的像 HTML；第三，它不是全常量 join。
- Alibaba DSL 只有什么：能写若干条 `source.expression`、`sink.expression`、`sanitizer.expression`。同类多条配置基本上是并集，也就是 OR。
- Alibaba DSL 没有什么：没有“针对同一个候选节点，把 A、B、NOT C 绑在一起”的通用 AND 容器。
- 所以 translator 只能怎么降级：把一部分 AND 关系硬塞进正则内部，再把两种 source 场景拆成两条 `source.expression`。这两条 `source.expression` 之间是 OR，不是原始规则里的 AND。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260408-122245/010-raw-html-join/workspaces/2-translator/target_rule/rosters/RawHtmlJoinBrowserXss_0.ros

```text
Roster RawHtmlJoinBrowserXss {
	// Alibaba DSL 这里只有：第一条 source 正则，命中它就算 source
	// 这条和下面那条 source.expression 的关系是 OR
	// Alibaba DSL 没有：把“主模式 + 二次约束”拆成同一候选上的独立 AND 条件
	source.expression += {
		taintTag = "raw_html_join";
		value += "/\\[[^\\]]*<\\s*[A-Za-z][^\\]]*,[^\\]]*\\b[A-Za-z_$][A-Za-z0-9_$]*(?:\\[[^\\]]+\\])?[^\\]]*\\]\\s*\\.join\\s*\\(/";
	};

	// Alibaba DSL 这里只有：第二条 source 正则，命中它也算 source
	// 这不是“再满足一个条件”，而是“另一种也可以命中”的并集 OR
	source.expression += {
		taintTag = "raw_html_join";
		value += "/\\[[^\\]]*<\\/\\s*[A-Za-z][^\\]]*,[^\\]]*\\b[A-Za-z_$][A-Za-z0-9_$]*(?:\\[[^\\]]+\\])?[^\\]]*\\]\\s*\\.join\\s*\\(/";
	};

	// Alibaba DSL 这里只有：join 被登记成一个 sink 位点
	// Alibaba DSL 没有：把它和上面的 source 条件重新绑回“同一个候选节点”
	sink.expression += "/\\.join\\s*\\(/";

	// Alibaba DSL 这里只有：一条正则型排除
	// Alibaba DSL 没有：原始 rule 那种精确的 pattern-not 结构排除
	sanitizer.expression += "/\\[[^\\]]*[\"'`][^\"'`]*[\"'`][^\\]]*\\]\\s*\\.join\\s*\\(\\s*[\"'`][^\"'`]*[\"'`]\\s*\\)/";
}
```

## defect case 2: documentbuilderfactory-disallow-doctype-decl-false（无法表示同一节点内多个pattern间的 AND 逻辑）

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/xxe/documentbuilderfactory-disallow-doctype-decl-false.yaml

```yaml
  patterns:
	# 源规则要求：先命中危险配置 setFeature(..., false)
  - pattern: $DBFACTORY.setFeature("http://apache.org/xml/features/disallow-doctype-decl", false);
	# 源规则要求：同一方法里不能出现这一组补偿配置
  - pattern-not-inside: |
	  $RETURNTYPE $METHOD(...){
		...
		$DBF.setFeature("http://xml.org/sax/features/external-general-entities", false);
		...
		$DBF.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
		...
	  }
	# 源规则要求：另一组补偿配置也必须不存在
  - pattern-not-inside: |
	  $RETURNTYPE $METHOD(...){
		...
		$DBF.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
		...
		$DBF.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
		...
	  }
```

### 分析

- 源规则要什么：先命中危险配置，再确认同一方法里没有出现多组补偿设置。
- Alibaba DSL 只有什么：能列出 `newInstance`、`setFeature` 这类 API 位点。
- Alibaba DSL 没有什么：没有“同一方法里 A 出现且 B、C、D 都不出现”的联合否定能力。
- 所以 translator 只能怎么降级：留下 factory 创建点和 `setFeature` 这个危险位点；原来“不存在补偿配置”这层条件丢掉了。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-214357/001-documentbuilderfactory-disallow-doctype-decl-false/workspaces/2-translator/target_rule/rosters/Java_xxe_documentbuilderfactory_disallow_doctype_decl_false_cfg_0.ros

```text
Roster Java_xxe_documentbuilderfactory_disallow_doctype_decl_false_cfg {
	// Alibaba DSL 这里只有：factory 创建点
	// Alibaba DSL 没有：跟踪“补偿配置是否同方法出现”这种上下文
	source.methodReturn += { precise = true; value = "javax.xml.parsers.DocumentBuilderFactory.newInstance"; };
	source.methodReturn += { precise = true; value = "javax.xml.parsers.SAXParserFactory.newInstance"; };

	// Alibaba DSL 这里只有：把 setFeature 登记成危险位点
	// Alibaba DSL 没有：把多段 pattern-not-inside 一起绑回这个位点
	sink.methodObject += { precise = true; value = "javax.xml.parsers.DocumentBuilderFactory.setFeature"; };
	sink.methodObject += { precise = true; value = "javax.xml.parsers.SAXParserFactory.setFeature"; };
}
```

# 三、只用 rule + roster，无法处理JS 函数入参 / 库导出入参 / 绑定变量 source 边界

## defect case 1: tainted-eval（JS 函数入参）

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/aws-lambda/security/tainted-eval.yaml

```yaml
  pattern-sources:
  - patterns:
	# 源规则要求：source 必须是 exports.handler 真正绑定的那个事件形参
	- pattern: $EVENT
	- pattern-either:
	  - pattern-inside: |
		  exports.handler = function ($EVENT, ...) {
			...
		  }
	  - pattern-inside: |
		  function $FUNC ($EVENT, ...) {...}
		  ...
		  exports.handler = $FUNC
	  - pattern-inside: |
		  $FUNC = function ($EVENT, ...) {...}
		  ...
		  exports.handler = $FUNC
  pattern-sinks:
  - patterns:
	# 源规则要求：focus-metavariable 把真正危险的代码实参锁定出来
	- focus-metavariable: $CODE
	- pattern-either:
	  - pattern: eval($CODE)
	  - pattern: Function(...,$CODE)
	  - pattern: new Function(...,$CODE)
```

### 分析

- 源规则要什么：只把 Lambda handler 的那个事件形参当 source，不是所有叫 event 的变量都算。
- Alibaba DSL 只有什么：JS 里有 `source.expression` 这种表达式级匹配能力。
- Alibaba DSL 没有什么：没有一个稳定好用的“函数第 N 个参数就是 source，且这个参数属于 exports.handler”建模入口。
- 所以 translator 只能怎么降级：把事件参数边界放宽成 `event`、`evt`、`event.body` 这类表达式痕迹；精确的 handler 参数绑定丢失。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260408-122245/019-tainted-eval/workspaces/2-translator/target_rule/rosters/NodeJS_aws_lambda_tainted_eval_0.ros

```text
Roster NodeJS_aws_lambda_tainted_eval {
	// Alibaba DSL 这里只有：按变量名/属性名去猜 source
	// Alibaba DSL 没有：精确锁定“这个变量就是 exports.handler 的事件形参”
	source.expression += {
		taintTag = "aws_lambda_event";
		value += "/\\b(event|evt)\\b|\\b(event|evt)\\.(body|headers|queryStringParameters|pathParameters|rawPath|rawQueryString)\\b/";
	};

	// Alibaba DSL 这里只有：eval 的第 0 个参数是 sink
	// Alibaba DSL 没有：保留原始 focus-metavariable 那种更精确的实参绑定
	sink.methodArg += {
		taintTag = "aws_lambda_event";
		pattern += "/\\beval\\b/";
		paramIndex = 0;
	};

	sink.methodArg += {
		taintTag = "aws_lambda_event";
		pattern += "/\\bFunction\\b/";
	};
}
```

## defect case 2: UnsafeShellCommandConstruction

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/src/Security/CWE-078/UnsafeShellCommandConstruction.ql

```ql
/**
 * @name Unsafe shell command constructed from library input
 * @description Using externally controlled strings in a command line may allow a malicious
 *              user to change the meaning of the command.
 * @kind path-problem
 * @problem.severity error
 * @security-severity 6.3
 * @precision high
 * @id js/shell-command-constructed-from-input
 * @tags correctness
 *       security
 *       external/cwe/cwe-078
 *       external/cwe/cwe-088
 */

import javascript
import semmle.javascript.security.dataflow.UnsafeShellCommandConstructionQuery
import UnsafeShellCommandConstructionFlow::PathGraph

// 这里只能看出：这个查询把 source 交给了配置模块和 PathGraph
// “库导出入参”这件事不写在这几行表面文本里，而是藏在 source 的定义里
from
  UnsafeShellCommandConstructionFlow::PathNode source,
```

CodeQL 原文 1：真正的 source 定义在 customization 模块里

文件：/home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/lib/semmle/javascript/security/dataflow/UnsafeShellCommandConstructionCustomizations.qll

```ql
/**
 * A parameter of an exported function, seen as a source for shell command constructed from library input.
 */
class ExternalInputSource extends Source {
	ExternalInputSource() {
		this = Exports::getALibraryInputParameter() and
		not (
			// looks to be on purpose.
			this.(DataFlow::ParameterNode).getName() = ["cmd", "command"]
			or
			this.(DataFlow::ParameterNode).getName().regexpMatch(".*(Cmd|Command)$")
		)
	}
}
```

CodeQL 原文 2：导出函数入参本身又是这样定义出来的

文件：/home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/lib/semmle/javascript/PackageExports.qll

```ql
/**
 * Gets a parameter that is a library input to a top-level package.
 */
cached
DataFlow::Node getALibraryInputParameter() {
	Stages::Taint::ref() and
	exists(int bound, DataFlow::FunctionNode func |
		func = getAValueExportedByPackage().getABoundFunctionValue(bound)
	|
		result = func.getParameter(any(int arg | arg >= bound))
		or
		result = func.getFunction().getArgumentsVariable().getAnAccess().flow()
	)
}
```

### 分析

- 这里和“库导出入参”的关系，现在直接能从 CodeQL 原文看出来：`ExternalInputSource` 明确写成了 `this = Exports::getALibraryInputParameter()`。
- 它真正要的是：先找到“包导出的函数”，再取这个导出函数的形参或 `arguments` 访问点当 source；如果参数名明显就是 `cmd`、`command`、`*Cmd`、`*Command`，还要排除掉。
- Alibaba DSL 只有什么：可以写一些 source 正则，匹配 `module.exports`、`arguments`、`opts` 这类表面痕迹。
- Alibaba DSL 没有什么：没有 CodeQL 那种 library input 抽象、路径图、精确参数过滤。
- 所以 translator 只能怎么降级：看到 `module.exports` / `exports.*` 痕迹，再看到 `arguments` / `opts` / `input` 之类名字，就近似当 source；但“它必须真的是导出函数的入参”这层精确边界已经没了。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-230129/029-UnsafeShellCommandConstruction/workspaces/2-translator/target_rule/rosters/NodeJS_library_input_cmdi_source_0.ros

```text
Roster NodeJS_library_input_cmdi_source {
	// Alibaba DSL 这里只有：看到 exports/module.exports 这种导出痕迹，就近似认为和“库导出入口”有关
	// Alibaba DSL 没有：先解析导出值，再精确回到那个导出函数的参数位
	source.expression += { value += "/\\b(module\\.exports|exports(\\.[A-Za-z_$][\\w$]*)?)\\b/"; };
	// Alibaba DSL 这里只有：arguments/opts/input 这类“像入参”的名字痕迹
	// Alibaba DSL 没有：cmd/command 这种参数名排除、bound 参数偏移、精确导出图
	source.expression += { value += "/\\b(arguments(\\[[0-9]+\\])?|argv|options|opts|input|path|filename|target|src|dest)\\b/"; };
}
```

# 四、只用rule + roster，无法处理污点数据 tag 的 组合判定 / 优先级降级

- 这里说的 tag，不是 roster 里随便写的一个字符串名字，而是 FindSecBugs 的 污点 对象上挂着的一组状态标记。
- 在源码里，`Taint.Tag` 是一个枚举，里面有 `CR_ENCODED`、`LF_ENCODED`、`URL_ENCODED`、`SQL_INJECTION_SAFE`、`APOSTROPHE_ENCODED` 这类标签；detector 运行时会对同一个 `Taint` 做 `hasTag(...)` 判断，再结合 `isSafe()`、`isTainted()` 决定最终优先级。
- 所以源规则要求的，不是“某个 API 在 sanitizer 名单里”这么简单，而是“同一个污点值当前带了哪些 tag，这些 tag 之间是 AND 还是 OR，它最后该落到 IGNORE、LOW、NORMAL、HIGH 哪一档”。
- Alibaba DSL 里的能力弱很多。Java 侧虽然有 `tag`、`excludeTag` 这类字段，但它们是规则匹配/导入层面的普通标签，不是 FindSecBugs 这种会跟着污点值流动、还能被 detector 用 `hasTag` 组合判断的状态位；JS 侧有 `taintTag`，本质上也只是把 source 和 sink 关联起来的“同名通道”。
- 换句话说，源规则需要的是“污点状态机上的 tag 操作”，而 Alibaba DSL 纯 rule/roster 最多只能做“给某类 source/sink 贴一个名字，要求两边名字相同才连通”，做不到 `hasTag(A) && hasTag(B)`、`hasTag(C) -> LOW`、`hasTag(D) -> IGNORE` 这种判定。

## defect case 1: SmtpHeaderInjectionDetector

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/injection/smtp/SmtpHeaderInjectionDetector.java

```java
	@Override
	protected int getPriority(Taint taint) {
		if (!taint.isSafe()) {
			// 源规则要求：CR_ENCODED 和 LF_ENCODED 要一起成立，才算完全安全
			boolean newLineSafe = taint.hasTag(Taint.Tag.CR_ENCODED) && taint.hasTag(Taint.Tag.LF_ENCODED);
			// 源规则要求：URL_ENCODED 也是另一条会影响优先级的分支
			boolean urlSafe = (taint.hasTag(Taint.Tag.URL_ENCODED));
			if(newLineSafe || urlSafe) {
				return Priorities.IGNORE_PRIORITY;
			}
		}
		if (taint.isTainted()) {
			return Priorities.HIGH_PRIORITY;
		} else if (!taint.isSafe()) {
			return Priorities.NORMAL_PRIORITY;
		} else {
			return Priorities.IGNORE_PRIORITY;
		}
	}
```

### 分析

- 源规则要什么：先看同一个 污点数据 身上有哪些 tag。这里至少有两种操作：一是 `hasTag(CR_ENCODED) && hasTag(LF_ENCODED)` 这种 AND 组合；二是 `newLineSafe || urlSafe` 这种 OR 组合。组合结果再映射到 `IGNORE_PRIORITY`、`NORMAL_PRIORITY`、`HIGH_PRIORITY`。
- 源规则里的 tag 在这里怎么用：`CR_ENCODED` 和 `LF_ENCODED` 要同时存在，才说明换行相关字符都被处理过；`URL_ENCODED` 单独成立时，也可以走另一条 suppress 分支。也就是说，tag 不只是“有或没有”，而是会参与布尔表达式，再参与优先级决策。
- Alibaba DSL 只有什么：能列 source，能列 sink，能列 sanitizer API 名单；如果是 JS 规则，还能用 `taintTag` 把 source 和 sink 绑到同一条通道上。
- Alibaba DSL 没有什么：没有 FindSecBugs 这种“污点值自带 tag 集合”，没有 `hasTag(...)` 查询接口，没有 tag 的 AND/OR 组合判断，也没有基于 tag 结果再映射 `IGNORE/NORMAL/HIGH` 的 priority 状态机。
- 所以 translator 只能怎么降级：把 URL 编码、URI 编码之类 API 直接当 sanitizer。这样保留下来的只是“经过这些 API 可能更安全”，但“CR 和 LF 同时满足才完全 suppress、否则只是 NORMAL/HIGH”这层细粒度语义已经丢了。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-221326/002-SmtpHeaderInjectionDetector/workspaces/2-translator/target_rule/rosters/Java_smtp_header_injection_0.ros

```text
Roster Java_smtp_header_injection {
	// Alibaba DSL 这里只有：全局 source 列表
	// Alibaba DSL 没有：tag 组合后的优先级判断
	source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
	source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameterValues"; };
	source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getHeader"; };
	source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getHeaders"; };
	source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getQueryString"; };

	// Alibaba DSL 这里只有：sink 方法名单
	// Alibaba DSL 没有：NORMAL / HIGH / IGNORE 这些分层结果
	sink.methodArg += { precise = true; value = "javax.mail.Message.setSubject"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "javax.mail.Message.addHeader"; param = "[{'position':0,'tainted':true}]"; };
	sink.methodArg += { precise = true; value = "javax.mail.Message.addHeader"; param = "[{'position':1,'tainted':true}]"; };

	// Alibaba DSL 这里只有：若干 sanitizer API 名单
	// Alibaba DSL 没有：CR_ENCODED、LF_ENCODED、URL_ENCODED 这些 tag 本身
	sanitizer.methodReturn += { value = "java.net.URLEncoder.encode"; };
	sanitizer.methodReturn += { value = "org.owasp.encoder.Encode.forUri"; };
	sanitizer.methodReturn += { value = "org.owasp.encoder.Encode.forUriComponent"; };
}
```

## defect case 2: SqlInjectionDetector

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/injection/sql/SqlInjectionDetector.java

```java
	@Override
	protected int getPriority(Taint taint) {
		// 源规则要求：SQL_INJECTION_SAFE 直接 suppress
		if (!taint.isSafe() && taint.hasTag(Taint.Tag.SQL_INJECTION_SAFE)) {
			return Priorities.IGNORE_PRIORITY;
		// 源规则要求：APOSTROPHE_ENCODED 只降级到 LOW，不是完全安全
		} else if (!taint.isSafe() && taint.hasTag(Taint.Tag.APOSTROPHE_ENCODED)) {
			return Priorities.LOW_PRIORITY;
		} else {
			return super.getPriority(taint);
		}
	}
```

### 分析

- 源规则要什么：同一个 `Taint` 上的不同 tag，要触发不同的结果。`SQL_INJECTION_SAFE` 代表直接 suppress；`APOSTROPHE_ENCODED` 只代表风险下降一档，最后是 `LOW_PRIORITY`，不是完全安全。
- 源规则里的 tag 在这里怎么用：这里不是 tag 组合，而是“不同 tag 对应不同后果”的分支判定。也就是说，tag 不只是过滤条件，还是优先级映射的输入。
- Alibaba DSL 只有什么：source/sink/sanitizer 这三类配置；JS 里还能用 `taintTag` 做 source 到 sink 的同名关联。
- Alibaba DSL 没有什么：没有“同一个污点值带着不同 tag 进入不同优先级分支”的状态机，也没有 `LOW` 和 `IGNORE` 这种分层结果表达能力。
- 所以 translator 只能怎么降级：把能看到的 source 先展开，必要时把部分安全 API 粗略登记成 sanitizer；但 `SQL_INJECTION_SAFE -> IGNORE` 和 `APOSTROPHE_ENCODED -> LOW` 这两条差异化规则无法保留，最终只能塌缩成更粗的一层“命中 sanitizer / 未命中 sanitizer”。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-221326/006-SqlInjectionDetector/workspaces/2-translator/target_rule/rosters/Java_sql_injection_findsecbugs_0.ros

```text
Roster Java_sql_injection_findsecbugs {
	// Alibaba DSL 这里只有：一些通用设置和 source 列表
	// Alibaba DSL 没有：IGNORE / LOW 这种分层结果
	general.handlePolymorphism = true;

	// Alibaba DSL 这里只有：把外部输入展开成 TAINTED source
	// Alibaba DSL 没有：SQL_INJECTION_SAFE / APOSTROPHE_ENCODED 这套 tag 状态机
	source.methodReturn += { precise = true; value = "io.dropwizard.servlets.Servlets.getFullUrl"; }; // dropwizard.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getContentType"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getLocalAddr"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getLocalName"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getParameter"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getParameterMap"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getParameterNames"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getParameterValues"; }; // java-ee.txt
	source.methodReturn += { precise = true; value = "javax.servlet.ServletRequest.getRemoteHost"; }; // java-ee.txt
}
```

# 五、无法处理 多状态流转 / 自定义传播边

## defect case 1: prototype-pollution-assignment

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/javascript/lang/security/audit/prototype-pollution/prototype-pollution-assignment.yaml

```yaml
  patterns:
	# 源规则要求：最终危险点是动态属性写入
  - pattern: |
	  $X[$B] = ...
  - pattern-not: |
	  $X[$B] = '...'
	# 源规则要求：前面必须先出现动态索引读取，这一步是风险升级前的中间态
  - pattern-inside: |
	  $X = $SMTH[$A]
	  ...
	# 源规则要求：再排除 constructor / __proto__ 这类 guard 分支
  - pattern-not-inside: |
	  if (<...'constructor' ...>) {
		...
	  }
	  ...
  - pattern-not-inside: |
	  if (<...'__proto__' ...>) {
		...
	  }
	  ...
  - metavariable-pattern:
	  patterns:
	  - pattern-not: '"..."'
	  - pattern-not: |
		  `...${...}...`
	  metavariable: $A
```

### 分析

- 源规则要什么：不是普通 taint 流。它要求先有“读动态 key”，再有“用这个 key 去写对象属性”，风险在第二步升级。
- Alibaba DSL 只有什么：source、sink、sanitizer 这些静态配置位。
- Alibaba DSL 没有什么：没有“状态从 A 变成 B”的传播规则，也没有自定义传播边。
- 所以 translator 只能怎么降级：把“读动态 key”登记成 source，把“写属性”登记成 sink，用同一个 taintTag 粗暴串起来。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260408-122245/002-prototype-pollution-assignment/workspaces/2-translator/target_rule/rosters/NodeJS_prototype_pollution_assignment_0.ros

```text
Roster NodeJS_prototype_pollution_assignment {
	// Alibaba DSL 这里只有：一条正则，看到“动态索引读取”就算 source
	// Alibaba DSL 没有：把它表示成状态升级前的中间态
	source.expression += {
		taintTag = "prototype_pollution_dynamic_key";
		value += "/=[^;\\n]*\\[[^\\]\\n]+\\]/";
	};

	// Alibaba DSL 这里只有：写属性时命中 sink
	// Alibaba DSL 没有：把“读 key”和“写属性”之间的升级关系单独建模
	sink.methodArg += {
		taintTag = "prototype_pollution_dynamic_key";
		pattern += "/\\[[^\\]\\n]+\\]\\s*=/";
		paramIndex = 0;
	};

	// Alibaba DSL 这里只有：弱化后的 barrier / 排除项
	// Alibaba DSL 没有：原始 pattern-not-inside 那种结构级 guard
	sanitizer.methodReturn += {
		pattern += "/\\bObject\\.freeze\\b|\\bObject\\.seal\\b|\\bObject\\.create\\b/";
	};
	sanitizer.expression += "/\\b(constructor|__proto__)\\b/";
}
```

## defect case 2: PrototypePollutingAssignment

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/codeql/javascript/ql/src/Security/CWE-915/PrototypePollutingAssignment.ql

```ql
// 源规则要求：真正的语义建立在 flowPath 与 isIgnoredLibraryFlow 上
from
  PrototypePollutingAssignmentFlow::PathNode source, PrototypePollutingAssignmentFlow::PathNode sink
where
  PrototypePollutingAssignmentFlow::flowPath(source, sink) and
  not isIgnoredLibraryFlow(source.getNode(), sink.getNode())
select sink, source, sink,
  "This assignment may alter Object.prototype if a malicious '__proto__' string is injected from $@.",
  source.getNode(), source.getNode().(Source).describe()
```

### 分析

- 源规则要什么：完整路径图，再加上“某些库流要忽略”的过滤。
- Alibaba DSL 只有什么：source 列表、sink 列表、少量正则匹配。
- Alibaba DSL 没有什么：没有 path graph，也没有 ignoredLibraryFlow 这种路径级过滤。
- 所以 translator 只能怎么降级：把常见输入展开成若干 source，把 merge/assign 等 API 当 sink；原始路径语义没了。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-230129/020-PrototypePollutingAssignment/workspaces/2-translator/target_rule/rosters/NodeJS_PrototypePollutingAssignment_Config_0.ros

```text
Roster NodeJS_PrototypePollutingAssignment_Config {
	// Alibaba DSL 这里只有：若干 source 列表 / 正则
	// Alibaba DSL 没有：library flow 的多状态路径图
	source.methodReturn += {
		taintTag = "proto_key";
		value += "/\\breq\\.(query|body|params|headers)\\b|\\brequest\\.(query|body|params|headers)\\b/";
	};

	source.expression += {
		taintTag = "proto_key";
		value += "/\\bctx\\.request\\.(query|body|params|headers)\\b|\\bevent\\.(queryStringParameters|body|headers|pathParameters)\\b/";
	};

	source.expression += {
		taintTag = "proto_key";
		value += "/\\b(argv|process\\.env|window\\.location|document\\.location)\\b/";
	};

	// Alibaba DSL 这里只有：merge / assign 这一类 sink API
	// Alibaba DSL 没有：原始 flowPath 和 ignoredLibraryFlow 过滤
	sink.methodArg += {
		taintTag = "proto_key";
		paramIndex = 0;
		pattern += "/\\b(Object\\.assign|assign|merge|mergeWith|defaultsDeep|extend)\\b/";
	};
```

# 六、无法处理 字节码级 CFG 聚合 / 多条件同时成立才安全 的场景

## defect case 1: XxeDetector

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/find-sec-bugs/findsecbugs-plugin/src/main/java/com/h3xstream/findsecbugs/xml/XxeDetector.java

```java
	// 源规则要求：先收集多个 feature 状态，后面再组合判断“是否真的安全”
	private static final String XXE_SAX_PARSER_TYPE = "XXE_SAXPARSER";
	private static final String XXE_XML_READER_TYPE = "XXE_XMLREADER";
	private static final String XXE_DOCUMENT_TYPE = "XXE_DOCUMENT";
	private static final String XXE_XPATH_TYPE = "XXE_XPATH";

	private static final String FEATURE_DISALLOW_DTD = "http://apache.org/xml/features/disallow-doctype-decl";
	private static final String FEATURE_SECURE_PROCESSING = "http://javax.xml.XMLConstants/feature/secure-processing";
	private static final String FEATURE_GENERAL_ENTITIES = "http://xml.org/sax/features/external-general-entities";
	private static final String FEATURE_EXTERNAL_ENTITIES = "http://xml.org/sax/features/external-parameter-entities";

	private final BugReporter bugReporter;

	public XxeDetector(BugReporter bugReporter) {
		this.bugReporter = bugReporter;
	}

	@Override
	public void sawOpcode(int seen) {
		if (seen != Const.INVOKEVIRTUAL && seen != Const.INVOKEINTERFACE) {
			return;
		}
```

### 分析

- 源规则要什么：不是看到一个 parse 就报，而是要看同一个对象生命周期里，多个安全配置是否都已经到位。
- Alibaba DSL 只有什么：能把 parse 列成 sink，能把 setFeature、setEntityResolver 之类列成 sanitizer。
- Alibaba DSL 没有什么：没有“这些安全条件必须同时都满足”的 CFG 聚合能力。
- 所以 translator 只能怎么降级：保留 parse 和若干安全 API 名单；真正的“多条件一起成立才安全”消失。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-221326/024-XxeDetector/workspaces/2-translator/target_rule/rosters/Java_xxe_document_config_0.ros

```text
Roster Java_xxe_document_config {
	// Alibaba DSL 这里只有：把 parse 当一个普通位点来处理
	// Alibaba DSL 没有：在同一个对象生命周期里聚合前面的多个安全条件
	source.methodArg += { precise = true; value = "javax.xml.parsers.DocumentBuilder.parse"; };

	sink.methodArg += {
		precise = true;
		value = "javax.xml.parsers.DocumentBuilder.parse";
		param = "[{'position':0,'tainted':true}]";
	};

	// Alibaba DSL 这里只有：若干独立的 sanitizer API 名单
	// Alibaba DSL 没有：要求“这些 sanitizer 要一起成立”
	sanitizer.methodArg += { value = "org.xml.sax.XMLReader.setEntityResolver"; };
	sanitizer.methodArg += { value = "javax.xml.parsers.SAXParserFactory.setFeature"; };
	sanitizer.methodArg += { value = "org.xml.sax.XMLReader.setFeature"; };
	sanitizer.methodArg += { value = "javax.xml.parsers.DocumentBuilderFactory.setFeature"; };
	sanitizer.methodArg += { value = "javax.xml.parsers.DocumentBuilderFactory.setXIncludeAware"; };
	sanitizer.methodArg += { value = "javax.xml.parsers.DocumentBuilderFactory.setExpandEntityReferences"; };
```

## defect case 2: saxparserfactory-disallow-doctype-decl-missing

### 源规则原始文本

源文件：/home/nyn/Desktop/Projects/SAST/sast_tools/semgrep-rules/java/lang/security/audit/xxe/saxparserfactory-disallow-doctype-decl-missing.yaml

```yaml
	pattern-sinks:
	  - patterns:
		  # 源规则要求：最终风险点是同一个 FACTORY 上的 newSAXParser
		  - pattern: $FACTORY.newSAXParser();
	pattern-sanitizers:
	  # 源规则要求：这里是 by-side-effect，并且多个 setFeature 组合后才算安全
	  - by-side-effect: true
		pattern-either:
		  - patterns:
			- pattern-either:
			  - pattern: >
				  $FACTORY.setFeature("http://apache.org/xml/features/disallow-doctype-decl",
				  true);
			  - pattern: >
				  $FACTORY.setFeature("http://xml.org/sax/features/external-general-entities",
				  false);

				  ...

				  $FACTORY.setFeature("http://xml.org/sax/features/external-parameter-entities", false);
```

### 分析

- 源规则要什么：同一个 factory 先被安全配置，再去调用 `newSAXParser()`；而且这些配置是按副作用生效的。
- Alibaba DSL 只有什么：`newInstance`、`newSAXParser`、`setFeature` 这些 API 位点，还有一些通用 propagate 配置。
- Alibaba DSL 没有什么：没有精确的“同一个对象、多个条件、按副作用生效”判定能力。
- 所以 translator 只能怎么降级：保留 factory 创建、`newSAXParser`、`setFeature`，再补一些泛化 propagate；原始对象级安全判定仍然保不住。

### 降级后的alibaba-dsl原始文本

目标文件：/home/nyn/Desktop/Projects/SAST/oh-my-rule/.ruletransfer/run-20260407-214357/014-saxparserfactory-disallow-doctype-decl-missing/workspaces/2-translator/target_rule/rosters/Java_xxe_saxparserfactory_disallow_doctype_config_0.ros

```text
Roster Java_xxe_saxparserfactory_disallow_doctype_config {
	// Alibaba DSL 这里只有：factory 创建点和 newSAXParser 位点
	// Alibaba DSL 没有：同一个 FACTORY 对象上的完整副作用语义
	source.methodReturn += { precise = true; value = "javax.xml.parsers.SAXParserFactory.newInstance"; };

	sink.methodObject += { precise = true; value = "javax.xml.parsers.SAXParserFactory.newSAXParser"; };

	// Alibaba DSL 这里只有：把 setFeature 当一个普通 sanitizer API
	// Alibaba DSL 没有：原始 by-side-effect + 多条件同时成立的要求
	sanitizer.methodArg += { precise = true; value = "javax.xml.parsers.SAXParserFactory.setFeature"; };

	// Alibaba DSL 这里只有：通用 propagate 近似
	// Alibaba DSL 没有：真正的对象级副作用安全判定
	propagate.customMethodPropagate += { value = ".*"; from = "0"; to = "return"; };
	propagate.methodArgToObjectAndReturn += { value = ".*"; };

	propagate.bUseXXEFlags += { value = true; };
	propagate.xxeMethod += { value = "javax.xml.parsers.SAXParserFactory.setFeature"; };
	propagate.xxeType += { value = "javax.xml.parsers.SAXParserFactory"; };
}
```
