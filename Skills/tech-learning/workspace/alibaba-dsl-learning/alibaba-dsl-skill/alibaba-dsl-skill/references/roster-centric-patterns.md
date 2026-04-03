# Alibaba DSL — Roster-Centric 实战模式

> 所有示例均通过 verify API 验证。每个示例包含完整的 Rule + Roster + relation config。

---

## Java: SSRF (s19✅)

**Rule** `70019.rul`:
```java
Rule XssRule extends AbstractTaintRule { type = "SSRF"; subType = "SSRFHook"; }
```

**Roster** `rosters/Java_ssrf_config_0.ros`:
```java
Roster Java_ssrf_config {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getHeader"; };
    sink.methodArg += { precise = true; value = "java.net.URL.<init>"; };
    sink.methodArg += { precise = true; value = "java.net.HttpURLConnection.openConnection"; };
    sanitizer.methodReturn += { value = "org.apache.commons.validator.routines.UrlValidator.isValid"; };
}
```

**relation/config_roster_relation.json**: `{"70019": ["Java_ssrf_config_0"]}`

---

## Java: SQLi — 多 Roster 分离 (s03✅)

**Rule** `70003.rul`:
```java
Rule SQLiComplete extends AbstractTaintRule { type = "SQLi"; subType = "SQLInjection"; }
```

**Roster 1** `rosters/Java_source_0.ros`:
```java
Roster Java_source {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getHeader"; };
}
```

**Roster 2** `rosters/Java_sqli_sink_0.ros`:
```java
Roster Java_sqli_sink {
    sink.methodArg += { precise = true; value = "java.sql.Statement.executeQuery"; };
    sink.methodArg += { precise = true; value = "java.sql.PreparedStatement.executeQuery"; };
}
```

**Roster 3** `rosters/Java_sanitizer_0.ros`:
```java
Roster Java_sanitizer {
    sanitizer.methodReturn += { value = "com.example.SQLFilter.escape"; };
}
```

**relation**: `{"70003": ["Java_source_0", "Java_sqli_sink_0", "Java_sanitizer_0"]}`

---

## Java: CMDI (s13✅)

**Rule** `70013.rul`:
```java
Rule CmdiEntry extends AbstractTaintRule { type = "CMDI"; subType = "CMDInjection"; }
```

**Roster** `rosters/Java_cmdi_full_0.ros`:
```java
Roster Java_cmdi_full {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
    sanitizer.methodReturn += { value = "com.example.CommandFilter.sanitize"; };
}
```

**relation**: `{"70013": ["Java_cmdi_full_0"]}`

---

## Java: PathTraversal + Group (s23✅)

**Rule** `70023.rul`:
```java
Rule PathTraversalRule extends AbstractTaintRule { type = "PathTraversal"; subType = "PathTraversalHook"; }
```

**Roster** `rosters/Java_pt_config_0.ros`:
```java
Roster Java_pt_config {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getPathInfo"; };
    sink.methodArg += { precise = true; value = "java.io.File.<init>"; };
    sink.methodArg += { precise = true; value = "java.io.FileInputStream.<init>"; };
    sink.methodArg += { precise = true; value = "java.nio.file.Paths.get"; };
    sanitizer.methodReturn += { value = "org.apache.commons.io.FilenameUtils.normalize"; };
    group SpringBoot {
        includePlatforms = "*";
        sanitizer.methodReturn += { value = "org.springframework.util.StringUtils.cleanPath"; };
    };
}
```

**relation**: `{"70023": ["Java_pt_config_0"]}`

---

## Java: Deserialization (t09✅)

**Rule** `80009.rul`:
```java
Rule DeserRule extends AbstractTaintRule { type = "Deserialization"; subType = "DeserializationHook"; }
```

**Roster** `rosters/Java_deser_config_0.ros`:
```java
Roster Java_deser_config {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getInputStream"; };
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getReader"; };
    sink.methodArg += { precise = true; value = "java.io.ObjectInputStream.readObject"; };
    sink.methodArg += { precise = true; value = "com.alibaba.fastjson.JSON.parseObject"; };
    sink.methodArg += { precise = true; value = "com.fasterxml.jackson.databind.ObjectMapper.readValue"; };
    sanitizer.methodReturn += { value = "com.example.security.DeserializeFilter.check"; };
}
```

**relation**: `{"80009": ["Java_deser_config_0"]}`

---

## JS: XSS (s04✅)

**Rule** `70004.rul`:
```javascript
Rule XssEntry_70004 extends AbstractTaintRule { type = "Xss"; subType = "XssTs"; }
```

**Roster** `rosters/NodeJS_xss_core_0.ros`:
```javascript
Roster NodeJS_xss_core {
    source.methodReturn += { value += "/\\breq\\.query\\b|\\breq\\.body\\b/"; };
    sink.methodArg += { pattern += "/\\bres\\.send\\b|\\bres\\.write\\b/"; };
    sanitizer.methodReturn += { pattern += "/\\bescapeHtml\\b/"; };
}
```

**relation**: `{"70004": ["NodeJS_xss_core_0"]}`

---

## JS: SQLi — 多 Roster (s05✅)

**Rule** `70005.rul`:
```javascript
Rule SqliTs_70005 extends AbstractTaintRule { type = "SqlInjection"; subType = "SqliTs"; }
```

**Roster 1** `rosters/NodeJS_common_src_0.ros`:
```javascript
Roster NodeJS_common_src {
    source.methodReturn += { value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/"; };
    source.expression += { value += "/ctx\\.request\\.body$/"; };
}
```

**Roster 2** `rosters/NodeJS_sqli_sink_0.ros`:
```javascript
Roster NodeJS_sqli_sink {
    sink.methodArg += { pattern += "/\\b(mysql|db|connection|pool)\\.query$/"; paramIndex = 0; };
}
```

**Roster 3** `rosters/NodeJS_sqli_sanitizer_0.ros`:
```javascript
Roster NodeJS_sqli_sanitizer {
    sanitizer.methodReturn += { pattern += "/\\bmysql\\.escape\\b|\\bsqlstring\\.escape\\b/"; };
}
```

**relation**: `{"70005": ["NodeJS_common_src_0", "NodeJS_sqli_sink_0", "NodeJS_sqli_sanitizer_0"]}`

---

## JS: CMDI + Group (s20✅)

**Rule** `70020.rul`:
```javascript
Rule CmdiEntry_70020 extends AbstractTaintRule { type = "CMDI"; subType = "CMDInjectionTs"; }
```

**Roster 1** `rosters/NodeJS_cmdi_source_0.ros`:
```javascript
Roster NodeJS_cmdi_source {
    source.methodReturn += { value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/"; };
    source.expression += { value += "/ctx\\.request\\.(query|body)$/"; };
    group koa_handler {
        includePlatforms = "koa";
        source.methodReturn += { value += "/\\bctx\\.request\\.body\\b/"; };
    };
}
```

**Roster 2** `rosters/NodeJS_cmdi_sink_0.ros`:
```javascript
Roster NodeJS_cmdi_sink {
    sink.methodArg += { pattern += "/\\bchild_process\\.(exec|execSync|spawn|fork)$/"; paramIndex = 0; };
    sink.methodArg += { pattern += "/\\bexec\\b|\\bexecSync\\b/"; paramIndex = 0; };
    sanitizer.methodReturn += { pattern += "/\\bshellEscape\\b|\\bescapeShellArg\\b/"; };
}
```

**relation**: `{"70020": ["NodeJS_cmdi_source_0", "NodeJS_cmdi_sink_0"]}`

---

## JS: PathTraversal (t10✅)

**Rule** `80010.rul`:
```javascript
Rule PathTravTs_80010 extends AbstractTaintRule { type = "PathTraversal"; subType = "PathTraversalTs"; }
```

**Roster** `rosters/NodeJS_pt_config_0.ros`:
```javascript
Roster NodeJS_pt_config {
    source.methodReturn += { value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/"; };
    sink.methodArg += { pattern += "/\\bfs\\.(readFile|readFileSync|writeFile|createReadStream)$/"; paramIndex = 0; };
    sink.methodArg += { pattern += "/\\bpath\\.join$/"; paramIndex = 0; };
    sanitizer.methodReturn += { pattern += "/\\bpath\\.normalize\\b|\\bpath\\.resolve\\b/"; };
}
```

**relation**: `{"80010": ["NodeJS_pt_config_0"]}`

---

## 模式总结

| 模式 | 适用场景 |
|------|---------|
| 单 Roster | 简单规则, source/sink/sanitizer 内聚 |
| 多 Roster (分离) | 复杂规则, source/sink/sanitizer 独立复用 |
| Roster + Group | 需要平台差异化配置 |
| 共享 Roster | 多条规则复用同一组 source (t12✅) |
