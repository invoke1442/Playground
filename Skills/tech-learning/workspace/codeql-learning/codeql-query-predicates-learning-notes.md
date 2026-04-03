# 记忆卡片摘要（快速复习版）

## 1. 大纲（压缩版）
- 谓词是什么：QL 中的逻辑关系（本质是元组集合）
- 为什么看起来像函数：调用形式相似，但语义是关系推导，不是单值返回
- 谓词定义：无 `result` / 有 `result`
- 三类谓词：非成员谓词、特征谓词（characteristic predicate）、成员谓词
- 内置谓词：非成员 built-ins + 各类型成员 built-ins
- 绑定行为：谓词必须可有限求值；无限谓词会报绑定错误
- `bindingset`：声明“在某些参数已绑定时可有限求值”
- 数据库谓词：来自数据库表，不能在 QL 中自行定义

## 2. 思维导图（Mermaid）
```mermaid
mindmap
  root((CodeQL QL 谓词))
    本质
      关系
      元组集合
      元数 arity
    定义方式
      predicate 无result
      类型前缀 有result
      result特殊变量
    谓词种类
      非成员谓词
      特征谓词
      成员谓词
    内置谓词
      非成员 built-ins
      boolean/date/int/string 成员 built-ins
    绑定行为
      有限求值
      unbound 错误
      不会自动绑定的表达式
    bindingset
      前提绑定条件
      多个注解独立
      bindingset[x] vs bindingset[x,y]
    数据库谓词
      来自数据库schema
      类似关系表
      不可在QL里定义
```

## 3. 重要知识点（必须记住）
- 谓词在 QL 里本质上是“关系（relation）”，严格说是一个元组集合，不是传统编程语言里的“函数实现”。[来源1]
- 有 `result` 的谓词也仍然是关系；对同一组输入参数可以有多个 `result`，也可以没有结果。[来源1]
- 谓词的元数（arity）不包含 `result` 变量。[来源1]
- QL 编译器要求谓词能在有限时间内求值；若变量无法被约束到有限集合，会报 “not bound to a value” 一类错误。[来源1][来源2]
- `bindingset` 不是“让无限谓词变正确”，而是声明“在某些参数已绑定时，这个谓词是可有限求值的”。[来源1][来源2]
- `bindingset[x] bindingset[y]` 与 `bindingset[x, y]` 含义不同，前者表示二选一即可，后者表示两个都要先绑定。[来源1]

## 4. 难点 / 易混点
- “像函数” vs “本质是关系”
- “有返回值” vs “单值函数”：QL 的 `result` 可以多值/零值
- `length()` 这类内置成员谓词可计算结果，但不一定能反向绑定接收者（receiver）：
  - `正向` 通常可行：当 `str` 已绑定时，`str.length()` 可以计算并用于过滤（例如检查 `< 10`）。
  - `反向` 通常不行：只写 `str.length() < 10` 并不会让编译器去“枚举所有短字符串”，因为字符串空间是无限的，`str` 仍可能 unbound。[来源1]
  - 关键原因：QL 里的 `=`、`<` 是逻辑约束，不是命令式“先算右边再赋值”；绑定分析需要明确的有限锚点（范围、有限谓词、已绑定参数）。[来源1][来源2]
  - 错误直觉：`length < 10` 看起来条件很强，所以“应该能推出 str”。
  - 正确直觉：这个条件只是测试，不是有限枚举来源；应先绑定 `str`，再用 `length()` 过滤。
  - 最小对比：
    - 易报绑定错误：`predicate shortString(string str) { str.length() < 10 }`
    - 常见修复：`bindingset[str] predicate shortString(string str) { str.length() < 10 }`，并在调用点先绑定 `str`（如来自有限枚举谓词或显式常量）。[来源1]
- 特征谓词不是构造函数（constructor），它是描述类成员条件的逻辑性质
- 数据库谓词和普通谓词用法相似，但来源不同（数据库提供，QL 里不能定义）

## 5. QA 快速复习卡片
- Q: `predicate` 和 `int foo(...)` 的区别是什么？
  A: 前者无 `result`，后者有 `result`，但两者本质都定义关系。
- Q: `result` 算不算 arity？
  A: 不算。arity 只看显式参数个数。[来源1]
- Q: 为什么 `result = i * 4` 会报绑定错误？
  A: `int` 是无限类型，`*` 不会自动绑定操作数，`i` 和 `result` 都可能保持未绑定。[来源1]
- Q: `bindingset[x] bindingset[y]` 和 `bindingset[x, y]` 一样吗？
  A: 不一样。前者是“x 或 y 任一已绑定即可”，后者是“x 和 y 都必须已绑定”。[来源1]
- Q: 特征谓词和成员谓词都常用 `this`，区别在哪？
  A: 特征谓词用 `this` 限定哪些值属于该类；成员谓词里 `this` 像普通参数一样参与关系定义。[来源3]

## 6. 快速复现步骤（最短路径）
1. 打开官方文档 `Predicates` 页面，先看 “Predicates with result / Kinds of predicates / Binding behavior”。[来源1]
2. 手抄并理解 `isCountry`、`hasCapital`、`getSuccessor` 三个例子（把它们当关系表看）。[来源1]
3. 手抄 `bindingset` 示例，对比 `bindingset[x] bindingset[y]` 与 `bindingset[x, y]`。[来源1]
4. 补看 `Types` 页面里 `characteristic predicates` 与 `member predicates` 的定义，确认 `this` 的角色。[来源3]
5. 查 `QL language specification` 的 Built-ins 章节，了解 built-in 分为非成员和按类型的成员谓词。[来源2]

---

# 学习笔记正文（详细版）

## 0. 学习目标、读者画像与假设
- 技术：`CodeQL / QL language`（主题：`predicates`）
- 学习目标：入门并建立“谓词 = 关系”的正确心智模型；能读懂并编写基础谓词；理解绑定错误与 `bindingset`
- 读者水平：初学（根据你的描述推断）
- 时间预算：标准版（约 1-3 小时阅读）
- 版本范围：CodeQL 在线官方文档（未显式标注版本，以访问时内容为准）
- 运行环境：未提供；本文示例以“可读/可抄写”为主
- 假设与限制：
  - 你已有基本编程经验，知道“函数/参数/返回值”的概念
  - 本文未在当前环境实际运行 CodeQL 示例（`未在当前环境实际验证`）
  - 重点是 QL 语言层面的谓词，不展开具体语言库（如 Java / JS / C# 的 CodeQL API）

## 1. 背景与用途（从读者视角）
- 如果你写过 Python/Java/JS，第一次看 QL 谓词会觉得它像“函数定义”。
- 这种感觉有帮助，但也容易误导：QL 的核心语义是关系查询（Datalog 风格），谓词描述的是“哪些元组满足某种逻辑关系”。官方文档直接强调谓词是构成 QL 程序的逻辑关系。[来源1]
- 为什么这个区别重要：
  - 你会更容易理解为什么一个“有返回值的谓词”可以返回多个值或不返回值。[来源1]
  - 你会更容易理解绑定（binding）错误，因为 QL 关心是否能有限地枚举关系中的元组。[来源1][来源2]
  - 你会更容易理解数据库谓词：数据库表本身就是关系表，QL 调用它们本质是在约束元组。[来源1]

## 2. 核心概念与术语（直白解释）

### 2.1 谓词（Predicate）
- 直白解释：一条“成立条件”的定义。
- 严格解释：一个谓词求值为一组元组（set of tuples）。[来源1]

### 2.2 元组（Tuple）与元数（Arity）
- 元组：关系中的一行值，如 `("Belgium", "Brussels")`
- 元数（arity）：每个元组有几个元素。
- 关键点：`result` 不计入 arity。[来源1]

### 2.3 `result`（结果变量）
- 当谓词定义前写的是类型（例如 `int foo(...)`）而不是 `predicate` 时，会引入特殊变量 `result`。[来源1]
- 但它仍是关系变量，不是“必须单值返回”的函数返回值。[来源1]

### 2.4 绑定（Binding）
- 直白解释：某个变量是否已被限制到有限范围，编译器能否有限地求值。
- 若编译器能证明变量没有被约束到有限集合，就会报未绑定错误（unbound）。[来源1][来源2]
- 更准确一点：这里的“绑定”不是命令式语言里“给变量赋值”的意思，而是 `编译器做静态分析时` 判断该变量是否能被有限枚举/确定。[来源1][来源2]
- 为什么 QL 特别在意绑定：
  - QL 是关系查询语言，很多类型（如 `int`、`string`）的理论取值空间是无限的
  - 如果一个谓词/表达式让编译器需要在无限空间里“猜值”，查询就无法保证有限求值
  - 所以编译器会在编译期检查绑定条件，而不是等到运行时再碰运气
- 你可以把“绑定”理解成一个问题：
  - `当前这一行逻辑里，编译器有没有足够信息，把这个变量限制到有限候选集？`
- 常见“会帮助绑定”的来源（初学够用版）：
  - 明确枚举/有限范围：例如 `i in [1 .. 9]`（把 `i` 限定到 9 个候选值）[来源1]
  - 来自有限关系的谓词调用：例如数据库谓词或你自己写的有限枚举谓词（如 `isCountry(c)`）[来源1]
  - 满足某个谓词声明的 `bindingset` 前提后调用该谓词（后文会展开）[来源1][来源2]
- 常见“看起来像能算，但不一定能绑定”的情况：
  - 算术表达式（如 `result = i * 4`）并不自动提供你想要的绑定方向，可能导致 `i` 和 `result` 都未绑定。[来源1]
    - 关系视角看这条式子：它定义的是一个二元关系 `{(i, result) | result = i * 4}`，这个关系本身是无限的（`int` 空间无限）。
    - 如果此时 `i` 和 `result` 都没有先被别的条件限制到有限集合，编译器就等于要在无限整数空间里同时寻找满足关系的配对。
    - QL 的绑定分析不会因为“数学上似乎可以反推”就默认给出某个方向（例如默认按 `i -> result` 或 `result -> i`）去枚举；它需要看到明确的有限锚点（range / 有限谓词 / 已绑定参数）。[来源1][来源2]
    - 换句话说，`=` 在这里表达的是“约束关系成立”，不是命令式语义里的“先算右边，再赋给左边”。
    - 所以 `result = i * 4` 常见的修复方式不是改写算式，而是增加绑定来源，例如 `i in [1 .. 10] and result = i * 4`，或在谓词上用 `bindingset[i]` 并在调用处先绑定 `i`。[来源1]
  - 某些成员谓词/内置谓词只是做测试，不负责反向枚举接收者；官方示例里 `str.length()` 不会绑定 `str`。[来源1]
- 一个很实用的区分：
  - “约束（constraint）”不一定等于“绑定（binding）”
  - 你写了一个逻辑条件，可能只是增加限制，但仍不足以让编译器从无限集合中有限枚举
- 最小对比例子（帮助建立直觉）：
  - 容易通过绑定检查：`i in [1 .. 9] and result = i + 1`
  - 容易报 unbound：`result = i + 1`（缺少把 `i` 限定到有限集合的条件）
- 和 `bindingset` 的关系（先建立连接）：
  - `bindingset` 不是“跳过绑定检查”
  - 它是在声明：`当某些参数已经绑定时，这个谓词可以有限求值`
  - 所以真正关键的是“调用点是否满足该前提”，而不只是“定义上写了 `bindingset`”[来源1][来源2]

### 2.5 内置谓词（Built-in predicates）
- QL 自带，无需额外 `import` 即可使用。[来源1]
- 语言规范把 built-ins 分成：
  - 非成员 built-ins（如 `any`、`none`、`toUrl`）[来源2]
  - 各类型成员 built-ins（如 `boolean`、`date`、`int`、`string` 等类型的成员谓词）[来源2]

## 3. 工作原理 / 机制（先直观后严格）

### 3.1 直观版：把谓词当“关系表”
- 你给的理解非常接近官方表述：
  - `isCountry(country)` 可以看成一列的关系表
  - `hasCapital(country, capital)` 可以看成两列的关系表
- 这正是官方 `Predicates` 页的示例与解释。[来源1]

你的写法（概念上正确）：
```ql
predicate isCountry(string country) {
  country = "Germany"
  or
  country = "Belgium"
  or
  country = "France"
}

predicate hasCapital(string country, string capital) {
  country = "Belgium" and capital = "Brussels"
  or
  country = "Germany" and capital = "Berlin"
  or
  country = "France" and capital = "Paris"
}
```

### 3.2 严格版：谓词是逻辑关系，不是普通函数
- QL 允许“有 `result` 的谓词”使用函数风格语法，但语义依然是关系。[来源1]
- 这意味着：
  - 同一输入可以对应多个 `result`
  - 同一输入也可以没有 `result`
  - `result` 可以像普通参数一样参与关系表达，而不是只能写成 `result = <表达式>` 这种固定形式。[来源1]

例如（官方思想，便于理解）：
```ql
string getANeighbor(string country) {
  country = "France" and result = "Belgium"
  or
  country = "France" and result = "Germany"
  or
  country = "Germany" and result = "Austria"
  or
  country = "Germany" and result = "Belgium"
}
```

这里 `getANeighbor("Germany")` 有两个结果，而不是一个。[来源1]

### 3.3 一个容易误解的点：QL 的“函数感”来自语法，不来自语义
- 你说“谓词跟函数概念非常相似”是个很好的入门桥梁。
- 建议升级为更准确的表述：
  - `入门心智模型`：像函数（有参数，可能有 result）
  - `正确语义模型`：关系（relation），可多值/零值，受绑定规则约束

## 4. 核心 API / 语法 / 组件 / 命令（按技术类型适配）

### 4.1 定义谓词的语法骨架
你总结的四点是正确的（官方同样按这四点说明）：关键字或结果类型、名字、参数列表、谓词体。[来源1]

#### 4.1.1 无 `result` 的谓词
```ql
predicate isCountry(string country) {
  country = "Germany"
  or
  country = "Belgium"
  or
  country = "France"
}
```

#### 4.1.2 有 `result` 的谓词
```ql
int getSuccessor(int i) {
  result = i + 1 and
  i in [1 .. 9]
}
```

说明：
- 用返回类型（如 `int`）代替 `predicate`
- `result` 是特殊变量，由语法引入。[来源1]

### 4.2 三类谓词（Kinds of predicates）

#### 4.2.1 非成员谓词（Non-member predicate）
- 定义在类外，不属于任何类。[来源1]

#### 4.2.2 特征谓词（Characteristic predicate）
- 定义在类体内，使用 `this` 限定哪些值属于该类，是类的逻辑性质描述。[来源1][来源3]
- 注意：不是构造函数（不会“创建对象”），只是描述 membership 条件。[来源3]
- 可以把它理解成“类的入场规则（filter）”：
  - `extends int` 先给出候选集合（所有 `int`）
  - 特征谓词再用 `this` 把候选集合收窄成你真正想要的子集（例如 `1/4/9`）[来源3]
- `this` 在特征谓词中的含义：
  - `this` 代表“当前被检查是否属于该类的值”
  - 你写的条件本质上是在回答：`这个值满足什么条件时，才算这个类的成员？`
- 为什么它看起来像“构造函数”：
  - 名字和类名相同（例如 `FavoriteNumbers()`）
  - 但语义不是实例化，而是定义类成员资格（membership）
  - QL 的类更像“带名字的逻辑性质 + 类型约束”，不是面向对象语言里的对象工厂。[来源3]
- 和成员谓词的边界（最容易混淆）：
  - 特征谓词：定义“谁属于这个类”
  - 成员谓词：在“已经属于这个类”的前提下，描述它还有什么关系/派生信息
  - 判断口诀：如果你在回答“这值是不是这个类”，写特征谓词；如果在回答“这个类的值有什么属性/映射”，写成员谓词
- 对 `FavoriteNumbers` 示例的直译：
  - `FavoriteNumbers()` 不是在创建 3 个对象
  - 它是在声明：只有当 `this = 1 or 4 or 9` 时，该 `int` 值才属于 `FavoriteNumbers`
  - 所以 `1.getName()` 合法（因为 `1` 属于该类），而一个不在集合里的值不会满足这个类的特征条件（概念上不属于该类）

#### 4.2.3 成员谓词（Member predicate）
- 也定义在类体内，但用于“对该类成员做关系定义/计算”，可以在某个值上调用。[来源1][来源3]
- `this` 在成员谓词里像普通参数一样使用。[来源3]

对应示例（你给的结构是对的，下面是整理版）：
```ql
int getSuccessor(int i) {  // 1) 非成员谓词
  result = i + 1 and
  i in [1 .. 9]
}

class FavoriteNumbers extends int {
  FavoriteNumbers() {      // 2) 特征谓词
    this = 1 or
    this = 4 or
    this = 9
  }

  string getName() {       // 3) 成员谓词
    this = 1 and result = "one"
    or
    this = 4 and result = "four"
    or
    this = 9 and result = "nine"
  }
}
```

### 4.3 内置谓词（Built-ins）怎么理解
- 官方 `Predicates` 页说：QL 有一批内置谓词，可以直接用，无需额外导入。[来源1]
- 语言规范 `Built-ins` 章节进一步给出分类和表格（结果类型、参数类型、语义说明）：[来源2]
  - `Non-member built-ins`：例如 `any`、`none`、`toUrl`
  - `Built-ins for boolean`
  - `Built-ins for date`
  - `Built-ins for float`
  - `Built-ins for int`
  - `Built-ins for string`
- 你说“不同数据类型拥有不同的内置谓词”这点是正确的。[来源2]

一个实用提醒（很关键）：
- “是内置成员谓词”不等于“会在绑定分析里绑定接收者”。
- 官方示例明确指出：`str.length()` 不会绑定 `str`，所以 `predicate shortString(string str) { str.length() < 10 }` 会触发绑定错误。[来源1]

### 4.4 数据库谓词（Database predicates）
- 每个 CodeQL 数据库包含一些“关系表”（数据库谓词），在 QL 里使用方式和普通谓词类似。[来源1]
- 但差别是：你不能在 QL 代码里定义数据库谓词，它们由底层数据库定义；不同数据库可用的数据库谓词不同。[来源1]
- 这就是为什么同一个 QL 语法在不同语言数据库（Java/JS/C++）里可用的底层 schema 谓词会不同。
- 可以把它们和你自己写的谓词做一个直观类比：
  - 数据库谓词 ≈ `基础事实表（base facts / base relations）`
  - QL 中自己定义的谓词 ≈ `在基础事实上推导出来的规则/视图（derived relations）`
  - 两者在查询里都能“像谓词一样调用”，但来源完全不同
- 它们到底“存的是什么”：
  - 是 extractor 从源码/二进制/项目元数据中提取出来的事实
  - 例如（概念层面）“有哪些文件/函数/调用/位置关系”等
  - 这些事实被存进 CodeQL 数据库后，QL 查询再基于这些关系做组合、过滤、推导
- 为什么说“在 QL 里用起来像普通谓词”：
  - 你依然是在写逻辑条件（`where` 中约束变量）
  - 依然可以和其它谓词做连接（join）与组合
  - 对使用者来说，它同样是“给变量施加关系约束”的工具
- 但它和普通谓词有 4 个关键区别（建议重点记住）：
  - `来源不同`：数据库谓词来自数据库 schema，不是你在 `.ql` 文件里写出来的谓词体。[来源1]
  - `可定义性不同`：普通谓词可以在 QL 中定义；数据库谓词不能在 QL 中定义/改写。[来源1]
  - `可移植性不同`：普通谓词（若只用通用 QL 语法）较通用；数据库谓词强依赖数据库类型/语言 schema（Java 数据库和 JS 数据库可用的底层谓词不同）。[来源1]
  - `抽象层级不同`：数据库谓词往往更底层；标准库类和成员谓词通常会在其之上提供更易用、更稳定的抽象（你日常写查询更多是用标准库 API，而不是直接操作底层 schema 谓词）
- 对初学者很重要的一点：你平时常见的 `Class/Method/Call` 等库类型与成员谓词，很多时候是在“封装数据库谓词”
  - 也就是说，标准库帮你把底层事实表组织成更容易理解的对象/关系接口
  - 所以初学阶段通常不需要先直接学习所有数据库谓词名称，先学标准库抽象更高效
- 在绑定（binding）上的意义（和前文 2.4 呼应）：
  - 数据库谓词通常来自一个具体数据库实例，因此关系本身是有限的（数据库里实际提取到的事实数量有限）
  - 这类谓词经常能给变量提供“有限候选集”，从而帮助绑定分析通过
  - 但要注意：这不等于“只要出现数据库谓词就一定不会有绑定问题”；仍要看变量是否真的被该谓词约束到了
- 一个实用心智模型（推荐记住）：
  - `数据库谓词负责提供事实`
  - `你写的谓词负责组织事实、命名逻辑、表达规则`
  - `最终查询负责选择要输出的结果`
- 常见误解纠正：
  - 误解：数据库谓词是“内置谓词”的一种
  - 正解：两者不是一回事。内置谓词是 QL 语言自带能力；数据库谓词是具体数据库 schema 提供的事实关系（取决于数据库内容和语言前端）。[来源1][来源2]
- 初学者实践建议：
  - 先从标准库类/成员谓词入手（更稳定、更可读）
  - 需要深入性能或理解底层行为时，再去看对应语言的数据库 schema/库实现如何映射到底层数据库谓词

## 5. 常见用法与典型场景

### 场景1：把业务逻辑拆成小谓词复用
- 例如先定义 `isCountry` / `hasCapital`，再在查询里组合。
- 这样做的好处是：
  - 可读性更强
  - 逻辑可复用
  - 更方便调试绑定问题（分段看哪个谓词没绑定）

### 场景2：用有 `result` 的谓词表达“映射关系”
- 如“后继”“名称映射”“邻居关系”
- 但不要把它当成严格单值函数，否则你会在看到多结果时困惑

### 场景3：在类里封装 domain-specific 逻辑
- 用特征谓词定义“什么值属于这个类”
- 用成员谓词定义“这个类的值有哪些相关关系/派生信息”
- 这是 CodeQL 标准库里非常常见的组织方式（尤其是 AST / dataflow 类型）

### 场景4：处理绑定错误时用 `bindingset`
- 当一个谓词本身在全域上是无限关系，但你只会在“输入已绑定”的上下文里使用它，可以显式声明 `bindingset`。[来源1][来源2]

## 6. 最小可运行示例（含预期输出/现象）

> 说明：以下示例 `未在当前环境实际验证`。预期结果基于官方文档语义和示例推导。[来源1]

### 示例1：无 `result` 谓词（把谓词当一列表）
- 目标：理解“谓词 = 元组集合”
- 前提条件：任意可运行 QL 示例的环境（例如 CodeQL 扩展中打开一个数据库）
- 代码/命令：
```ql
predicate isCountry(string country) {
  country = "Germany"
  or
  country = "Belgium"
  or
  country = "France"
}

from string c
where isCountry(c)
select c
```
- 运行步骤：
  1. 新建 `.ql` 查询文件
  2. 粘贴代码并执行
- 预期输出/现象：
  - 返回 3 行，包含 `Germany`、`Belgium`、`France`（顺序不应作为语义保证）
- 常见错误与修复：
  - 错误：把 `and` / `or` 的逻辑结构写乱，导致漏结果
  - 修复：先按“每个 `or` 分支对应一行元组”的思路重排代码

### 示例2：有 `result` 的谓词（但不是单值函数）
- 目标：理解 `result` 的关系语义
- 前提条件：同上
- 代码/命令：
```ql
string getANeighbor(string country) {
  country = "France" and result = "Belgium"
  or
  country = "France" and result = "Germany"
  or
  country = "Germany" and result = "Austria"
  or
  country = "Germany" and result = "Belgium"
}

from string n
where n = getANeighbor("Germany")
select n
```
- 运行步骤：
  1. 执行查询
- 预期输出/现象：
  - 返回两行：`Austria` 和 `Belgium`
- 常见错误与修复：
  - 错误：误以为只能返回一个 `result`
  - 修复：记住 QL 谓词是关系，可一对多 / 零对多

### 示例3：绑定错误与 `bindingset`
- 目标：理解为什么会报 unbound，以及如何声明使用前提
- 前提条件：同上
- 代码/命令（会报错的版本）：
```ql
int multiplyBy4(int i) {
  result = i * 4
}
```
- 预期输出/现象：
  - 编译阶段出现未绑定错误（`i` / `result` / `i * 4` 未绑定）[来源1]
- 修复版本：
```ql
bindingset[i]
int multiplyBy4(int i) {
  result = i * 4
}

from int i
where i in [1 .. 10]
select multiplyBy4(i)
```
- 预期输出/现象：
  - 查询合法，返回 `4, 8, ..., 40`（具体展示格式依工具 UI）
- 常见错误与修复：
  - 错误：以为加了 `bindingset[i]` 后任何调用都合法
  - 修复：调用时仍需保证 `i` 在上下文中已被约束到有限集合（如 `[1 .. 10]`）

### 示例4：`bindingset[x] bindingset[y]` 与 `bindingset[x, y]` 的区别
- 目标：掌握多绑定集的语义差异
- 前提条件：同上
- 代码/命令：
```ql
bindingset[x]
bindingset[y]
predicate plusOne(int x, int y) {
  x + 1 = y
}

from int x, int y
where y = 42 and plusOne(x, y)
select x, y
```
- 预期输出/现象：
  - 查询合法，因为这里 `y` 已绑定（`y = 42`）
  - 返回 `x = 41, y = 42`
- 绑定错误示例（故意）：
```ql
bindingset[x, y]
predicate plusOneNeedBoth(int x, int y) {
  x + 1 = y
}

from int x, int y
where x in [0 .. 3] and plusOneNeedBoth(x, y)
select x, y
```
- 为什么这里 `x in [0 .. 3]` 仍“不够”：
  - `x in [0 .. 3]` 只把 `x` 绑定到有限集合，并没有先绑定 `y`。
  - `bindingset[x, y]` 的含义是“调用前 `x` 和 `y` 都要已绑定”，不是“至少绑定一个就行”。[来源1]
  - `x + 1 = y` 在这里是关系约束，不是命令式“先算出 y 再赋值”；它不能替代 `bindingset[x, y]` 对“调用前置绑定条件”的要求。
  - 所以会报绑定相关错误（本例是故意写来触发该错误）。
- 常见错误与修复：
  - 错误：把两个单独的 `bindingset` 写成一个 `bindingset[x, y]`
  - 修复：先想清楚你要表达的是“任一已绑定即可”还是“全部都要先绑定”
  - 如果你希望“只绑定 `x` 也能调用”，应写成：
    - `bindingset[x]`
    - `bindingset[y]`

## 7. 常见错误与排查路径

### 错误1：把谓词当严格单值函数
- 现象：看到多结果或无结果时困惑
- 原因：沿用了命令式语言的函数思维
- 排查顺序：
  1. 看谓词定义是否有多个 `or` 分支为同一输入赋不同 `result`
  2. 看是否存在某些输入根本没有满足 `result` 的分支
  3. 用“关系表”的视角重读定义

### 错误2：`not bound to a value`
- 现象：编译器报 unbound 错误
- 常见原因：
  - 变量类型本身是无限类型（如 `int`、`string`）
  - 使用的表达式/内置谓词不提供绑定能力（例如官方示例中的 `length()` 不绑定 `str`）[来源1]
  - 缺少范围约束（如 `i in [1 .. 9]`）
  - 应该用 `bindingset` 却没声明，或声明了但调用处未满足前提
- 排查顺序：
  1. 标出每个变量第一次出现的位置
  2. 检查它是否由有限集合约束（枚举、范围、数据库谓词、已绑定参数等）
  3. 检查使用的操作/成员谓词是否会绑定变量
  4. 必要时拆成更小谓词定位问题

### 错误3：混淆特征谓词与成员谓词
- 现象：把类成员关系写进特征谓词，或忘记在特征谓词中约束 `this`
- 排查顺序：
  1. 问自己：这是在定义“什么值属于类”，还是“对类成员做计算/关系定义”？
  2. 前者写特征谓词；后者写成员谓词

### 错误4：以为数据库谓词能在 QL 里定义
- 现象：试图仿照普通谓词去声明某个 schema 表
- 正解：数据库谓词由底层数据库 schema 提供，QL 中只能使用，不能定义。[来源1]

## 8. 最佳实践与边界条件

### 最佳实践
- `必须记住`：先用“关系”心智模型读谓词，再用“函数”语法辅助理解
- `必须记住`：写有 `result` 的谓词时，主动思考“是否可能多结果/零结果”
- `容易踩坑`：对无限类型（`int` / `string`）的变量尽早施加有限约束
- `容易踩坑`：遇到绑定错误时，不要只盯一行代码；按“变量是否被有限约束”的路径排查
- `先知道即可`：很多内置成员谓词可以链式调用，但其绑定行为需要具体看语义，不是都能反向绑定 receiver

### 边界条件 / 限制
- 内置谓词的完整列表和精确语义以语言规范 `Built-ins` 章节为准，不同数据库还会有额外非成员谓词（不一定在规范里逐一列出）。[来源2]
- 数据库谓词的可用性依赖你正在查询的数据库类型（不同语言 schema 不同）。[来源1]
- 本文示例聚焦 QL 语言基础，不覆盖递归谓词的完整规则（官方另有 `Recursion` 页面）。[来源1]

## 9. 版本差异 / 兼容性说明（如适用）
- 本文主要基于 CodeQL 官方在线文档的 QL 语言参考与规范页面，页面未显式给出“语言版本号”，因此以访问日期记录为准（2026-02-26）。[来源1][来源2][来源3]
- 对“谓词是关系”“绑定行为”“`bindingset` 语义”“三类谓词”这类概念性规则，通常跨版本较稳定；但 built-ins 列表与细节、文档表述、工具报错文本可能出现变化。
- 若你后续使用特定 CodeQL CLI 版本或 GitHub Advanced Security 托管环境，建议以该版本配套文档为准。

## 10. 延伸学习路径（官方优先）
- 先读（必须）：
  - `Predicates`（本主题主文档）[来源1]
  - `Types` 中 `Classes / Characteristic predicates / Member predicates`（理解 `this`）[来源3]
  - `QL language specification` 的 `Built-ins` 与 `bindingset` 相关条目（形式化定义）[来源2]
- 再做（建议）：
  - 亲自抄写官方 `bindingset` 示例并改造（如改成 `plusTwo`, `truncate`）
  - 故意写出一个 unbound 错误，再自己修复
- 进阶：
  - `Recursion` 页面（递归谓词）
  - `Annotations` 页面（`bindingset` 之外常见注解）
  - 具体语言库（Java/JS/Python 等）中的类与成员谓词设计模式

---

# 练习与复习闭环

## 1. 分层练习

### 基础练习
1. 把 `isCountry` 改成 `isCity`，写出 4 个城市。
2. 写一个无 `result` 谓词 `isSmallEven(int i)`，只包含 `2,4,6,8`。
3. 写一个有 `result` 谓词 `int getDouble(int i)`，并加上 `i in [1 .. 5]` 约束。
4. 标注以下谓词的 arity（注意 `result` 不计入）：`predicate p(int x)`, `string f(int x, int y)`.

### 应用练习
1. 写一个有 `result` 的谓词 `string getCapital(string country)`，让 `"France"` 和 `"Germany"` 有结果，`"Belgium"` 没结果。
2. 设计一个类 `SmallSquareNumbers extends int`，特征谓词限定 `1,4,9,16`，成员谓词返回英文名（可只写部分）。
3. 写出一个会触发 unbound 错误的示例，并解释为什么 unbound。
4. 用 `bindingset` 修复上题，并写出调用处如何保证前提成立。

### 综合练习
1. 用 3 个谓词表达一个小型知识图谱（如国家-首都-邻国），并写查询组合它们。
2. 同时写出：
   - `bindingset[x] bindingset[y]` 版本
   - `bindingset[x, y]` 版本
   然后解释两者在调用上的差异。
3. 阅读一个 CodeQL 标准库类（任选），指出其类中的特征谓词与成员谓词各在做什么（只需概念层面）。

## 2. 动手任务（带验收标准）
- 任务：写一份 `predicates-playground.ql`，至少包含
  - 1 个无 `result` 谓词
  - 1 个有 `result` 谓词（多结果）
  - 1 个类（含特征谓词 + 成员谓词）
  - 1 个 `bindingset` 示例
- 验收标准：
  - 你能口头解释每个谓词对应的“关系表”是什么
  - 你能指出每个变量是如何被绑定到有限集合的（或为什么需要 `bindingset`）
  - 你能解释 `result` 为什么不等于传统函数返回值

## 3. 常见误区纠偏
- 误区：有 `result` 的谓词就是函数。
  正解：语法像函数，但语义仍是关系，可多值/零值。[来源1]
- 误区：`result = i * 4` 明明写了等式，变量就应该自动确定。
  正解：QL 还要求“绑定可有限求值”；等式本身不保证绑定方向成立。[来源1][来源2]
- 误区：特征谓词就是构造器。
  正解：特征谓词描述类成员条件，不创建对象。[来源3]
- 误区：所有内置成员谓词都能帮你绑定 receiver。
  正解：不一定；官方示例表明 `length()` 在某场景下不绑定 `str`。[来源1]

## 4. 复习节奏建议
- Day 1：
  - 重看“关系 vs 函数”与 `result` 多值/零值
  - 手抄 2 个无 `result` + 2 个有 `result` 例子
- Day 3：
  - 专门练 3 个 unbound 错误和修复
  - 复习 `bindingset[x]` 与 `bindingset[x,y]` 差异
- Day 7：
  - 写一个小类（特征 + 成员谓词）
  - 用自己的话解释 `this` 在两种谓词中的不同角色
- Day 14：
  - 阅读一个真实 CodeQL 库类定义
  - 标注其中的成员谓词/特征谓词/可能的绑定约束

## 5. 自测题与参考答案（简版）
1. 题目：为什么说 QL 谓词本质是关系而不是函数？
   参考答案：因为谓词求值是元组集合；即使有 `result` 也可以对同一输入产生多个结果或零结果。[来源1]
2. 题目：`result` 是否计入 arity？
   参考答案：不计入，arity 只统计显式参数个数。[来源1]
3. 题目：`bindingset` 的作用是什么？
   参考答案：声明在某些参数已绑定（有限）时，谓词整体可有限求值。[来源1][来源2]
4. 题目：`bindingset[x] bindingset[y]` 和 `bindingset[x, y]` 的区别？
   参考答案：前者是多个独立绑定集（满足任一个即可），后者是同一个绑定集（必须都满足）。[来源1]
5. 题目：特征谓词和成员谓词都用 `this`，最核心区别是什么？
   参考答案：特征谓词用 `this` 限定类成员范围；成员谓词里 `this` 像普通参数参与关系定义。[来源3]

---

# 参考来源与版本说明

## 官方来源（优先）
1. [Predicates — CodeQL](https://codeql.github.com/docs/ql-language-reference/predicates/) - 在线文档（未显式版本号） - 访问日期：2026-02-26 - 本文主轴（定义、种类、绑定行为、`bindingset`、数据库谓词）
2. [QL language specification — CodeQL（Built-ins / bindingset formal definitions）](https://codeql.github.com/docs/ql-language-reference/ql-language-specification/) - 在线文档（未显式版本号） - 访问日期：2026-02-26 - 用于 built-ins 分类与 `bindingset` 形式化定义
3. [Types — CodeQL（Classes / Characteristic predicates / Member predicates）](https://codeql.github.com/docs/ql-language-reference/types/) - 在线文档（未显式版本号） - 访问日期：2026-02-26 - 用于 `this`、特征谓词、成员谓词解释
4. [Annotations — CodeQL](https://codeql.github.com/docs/ql-language-reference/annotations/) - 在线文档（未显式版本号） - 访问日期：2026-02-26 - 用于确认 `bindingset` 注解适用范围（补充）

## 第三方来源（按采信程度标注）
- 本次未使用第三方来源（你提供的是官方文档链接与个人理解草稿）。

## 关键结论引用映射
- [来源1] -> 谓词是关系/元组集合；`result` 语义；三类谓词；绑定错误示例；`bindingset` 示例与语义；数据库谓词说明
- [来源2] -> Built-ins 章节分类；`bindingset` 的形式化定义与默认绑定集语义
- [来源3] -> 特征谓词/成员谓词定义；`this` 在二者中的角色区别；成员谓词调用方式
- [来源4] -> `bindingset` 作为注解的适用范围（补充核对）

## 冲突点与裁决（如有）
- 本次未发现官方来源之间的实质性冲突。
