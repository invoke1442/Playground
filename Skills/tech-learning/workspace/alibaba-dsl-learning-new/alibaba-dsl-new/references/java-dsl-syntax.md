# Java DSL Syntax

## Rule Pattern

```java
Rule JavaWebTaintRule extends AbstractTaintRule {
    import roster Java_web_taint;
    import roster Java_common_propagate exclude StringConcatMethod;
    type = "SSRF";
    subType = "ssrfJava";
    general.customSubject = "SSRF";
}
```

Imports must be the first statements in the Rule body. Import the roster declaration name (`Java_web_taint`), not the file stem (`Java_web_taint_0`).

## Verified Rule/Roster Facts

This section consolidates the stable Rule/Roster conclusions from official docs, bundled configs, and broad verification runs. Use `references/java-loadclass/` for Java extension APIs rather than inferring them from Rule/Roster syntax notes.

- `type and subType are required` in Java Rule files.
- `define` and `delete` are supported for local configuration changes in child rules.
- `modifiable` declarations are supported for configurations that child rules are allowed to adjust.
- `const` declarations produced `ParseError` in broad verification runs and are currently unsupported.
- `import roster is the runtime link`: imported Rosters affect runtime behavior only when the Rule body imports them.
- `relation config is only verify-time file discovery`: relation config helps verification locate roster files, but it is not a runtime import.
- Correct use needs both `import roster Name;` and relation entry `"Name_0"`.
- Import by Roster declaration name, not the `_0.ros` filename stem.
- Multiple imports can appear consecutively at the top of the Rule body.
- `import roster X exclude A,B;` is valid and excludes matching groups/tags.
- `group is valid in Roster only; group in Rule causes ParseError`.
- A Rule can combine inline fields with imported Roster definitions.
- A Roster name is descriptive only; a propagate roster may contain propagate, sanitizer, sink, and general fields.
- `//` inline comments are accepted in broad verification examples.
- Empty strings such as `value = ""` appear in product rosters as wide-match or placeholder values. Treat the runtime semantics as context-dependent.

## Roster Pattern

```java
Roster Java_web_taint {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };

    sink.methodArg += {
        precise = true;
        value = "java.net.URL.<init>";
        param = "[{'position':0,'tainted':true}]";
    };

    sanitizer.methodArg += {
        precise = true;
        value = "com.alibaba.security.SecurityUtil.checkSSRF";
    };
}
```

Use `sanitizer.methodReturn` for APIs that return a safe replacement value, such as `escapeSql(input)`. Use `sanitizer.methodArg` for checker APIs where passing the argument through the method validates that argument. The official SSRF roster models `com.alibaba.security.SecurityUtil.checkSSRF` with `sanitizer.methodArg`.

## Common Java Fields

| Domain | Fields seen in official configs |
|---|---|
| `source` | `methodReturn`, `methodArg`, `methodParam`, `paramAnnotation`, `mvcMapping`, `allocReturn`, `velocityReference`, `methodReturnJws`, `annotationJWS`, string-only compatibility fields `param_annotation`, `method_annotation`, `method_param`, `expression` |
| `sink` | `methodArg`, `methodObject`, `allocArg`, `methodArgJws`, `methoArgUpcast`, `methodReturn`, `methodCritical`, `methodSqlSpecial`, `methodXbatis`, `methodXbatisExclude`, `responseBody`, `responseClass`, `applicationJsonProduces`, `applicationJsonAnnotation`, `contextJws`, `mybatisProvider`, `bUseSinkFilter`, `filter`, string-only compatibility fields `expression`, `param_annotation`, `method_annotation`, `method_param`, `customSinkFunc` |
| `sanitizer` | `methodReturn`, `methodArg`, `methodObject`, `safeTypes`, `safeVarNames`, `methodRedirectCheck`, `methodSafeState`, `methodUnSafeState`, `methodArgWithRedirectCheck`, string-only compatibility fields `expression`, `param_annotation`, `method_annotation`, `method_param`, `customSanitizerFunc` |
| `propagate` | `customMethodPropagate`, `methodObjectToReturn`, `methodObjectToReturnCritical`, `methodObjectToFirstArg`, `methodObjectToFirstArgCritical`, `methodArgOrObjectToObjectAndReturn`, `methodArgToObjectAndReturn`, `methodArgToReturnCritical`, `methodReturnUpcast`, `vmContext`, `bAllPublicMethod`, `bUseSqlSpecial`, `bUseCritical`, `bPreSanitizerParam`, `bUseSafeState`, `bUnkownAsSafe`, `bTaintedStart`, `bOnlyTaintedByObject`, `bSanitizerParamTransmit`, `bUseXXEFlags`, `bUseStreamReader`, `noTaintNoSourceFile`, `definiteNoSourceFile`, `criticalType`, `xxeType`, `xxeMethod`, `methodStreamReader` |
| `general` | `customSubject`, `entranceFileXpath`, `scanAllFiles`, `userDefinePatternClass`, `userDefineEntranceClass`, `methodRedirect`, `taintOnlyBySummary`, `blackFieldMatch`, `handlePolymorphism`, `polyHandleNum`, `genAppSummary` |

This table is a field catalog, not a promise that every field accepts the same child keys. Check the verified grammar below before choosing string versus block syntax.

Fully-qualified field checklist for search:

- Source fields: `source.methodReturn`, `source.methodArg`, `source.methodParam`, `source.paramAnnotation`, `source.mvcMapping`, `source.allocReturn`, `source.velocityReference`, `source.methodReturnJws`, `source.annotationJWS`.
- Sink fields: `sink.methodArg`, `sink.methodObject`, `sink.allocArg`, `sink.methodArgJws`, `sink.methoArgUpcast`, `sink.responseBody`, `sink.responseClass`, `sink.applicationJsonProduces`, `sink.applicationJsonAnnotation`, `sink.methodCritical`, `sink.methodSqlSpecial`, `sink.contextJws`, `sink.mybatisProvider`, `sink.methodXbatis`, `sink.methodXbatisExclude`, `sink.bUseSinkFilter`, `sink.filter`.
- Sanitizer fields: `sanitizer.methodReturn`, `sanitizer.methodArg`, `sanitizer.methodObject`, `sanitizer.safeTypes`, `sanitizer.safeVarNames`, `sanitizer.methodRedirectCheck`, `sanitizer.methodSafeState`, `sanitizer.methodUnSafeState`, `sanitizer.methodArgWithRedirectCheck`.
- General fields: `general.taintOnlyBySummary`, `general.blackFieldMatch`, `general.handlePolymorphism`, `general.polyHandleNum`, `general.scanAllFiles`, `general.entranceFileXpath`, `general.methodRedirect`, `general.customSubject`, `general.genAppSummary`.
- Propagate fields: `propagate.bAllPublicMethod`, `propagate.bUseSqlSpecial`, `propagate.bUseCritical`, `propagate.bPreSanitizerParam`, `propagate.bUseSafeState`, `propagate.bUnkownAsSafe`, `propagate.bTaintedStart`, `propagate.bOnlyTaintedByObject`, `propagate.bSanitizerParamTransmit`, `propagate.bUseXXEFlags`, `propagate.bUseStreamReader`, `propagate.noTaintNoSourceFile`, `propagate.definiteNoSourceFile`, `propagate.criticalType`, `propagate.xxeType`, `propagate.xxeMethod`, `propagate.methodStreamReader`, `propagate.customMethodPropagate`, `propagate.methodObjectToReturn`, `propagate.methodObjectToFirstArg`, `propagate.methodArgOrObjectToObjectAndReturn`, `propagate.methodArgToObjectAndReturn`, `propagate.methodArgToReturnCritical`, `propagate.vmContext`.

The exact runtime meaning of an `empty string` value is field-dependent. Product rosters use empty-string values for broad-match or placeholder entries, but do not assume a universal "match all" semantic without runtime evidence.

## Verify-Tested Field Grammar

Use these boundaries when Rule/Roster syntax conflicts with older summaries:

| Field or pattern | Verified syntax boundary |
|---|---|
| `source.methodReturn` | Block syntax with `precise` and `value` |
| `source.methodArg` | Block syntax with `precise` and `value` |
| `source.paramAnnotation` | CamelCase block field; `source.paramAnnotation and source.param_annotation are different fields` |
| `source.methodParam` | CamelCase block field; can use `xpath` and `tag` |
| `source.param_annotation`, `source.method_annotation`, `source.method_param` | Snake_case string-only compatibility fields; they are not modifiable in AbstractTaintRule child rules |
| `source.expression` | String-style expression field in broad verification runs; avoid block syntax unless official configs show the exact field supports it |
| `sink.methodArg` | Block syntax with `value`; `Java sink.methodArg does not support paramIndex` |
| `sink.methodReturn` | `Java sink.methodReturn is string-only`; block syntax fails |
| `sink.expression`, `sink.param_annotation`, `sink.method_annotation`, `sink.method_param`, `sink.customSinkFunc` | String syntax |
| `sink.methodObject`, `sink.allocArg` | Block syntax with `precise` and `value` |
| `sanitizer.methodReturn`, `sanitizer.methodArg` | Java sanitizer.methodReturn and sanitizer.methodArg require block syntax |
| `sanitizer.expression`, `sanitizer.param_annotation`, `sanitizer.method_annotation`, `sanitizer.method_param`, `sanitizer.customSanitizerFunc` | String syntax |
| `general.*` booleans/integers | Direct assignment such as `general.scanAllFiles = true` |
| `propagate.b*` and `sink.bUseSinkFilter` | Complex block syntax with `value = true/false` |

`param JSON is confirmed for Java sink.methodArg` and appears in broad match tests for `source.methodReturn`. The verified shape is a string such as `"[{'position':0,'tainted':true}]"`. It can also combine `position`, `tainted`, `type`, and `value`, for example requiring a fixed header-name argument and a tainted value argument. Do not generalize `param` to JS or to every Java block field.

`flag` and `ExcludeTag` / `excludeTag` are not universal child keys. Use them only where official configs or a trusted verification run show the exact field supports them.

## Rule-Level Configuration Controls

Use these controls cautiously; they affect inherited fields and are easy to overuse:

```java
define source.methodReturn += {
    precise = true;
    value = "com.example.Requests.getInput";
};

delete source.methodReturn;

modifiable source.methodReturn;
```

- `define` adds or overrides a configuration entry in a child Rule.
- `delete` removes an inherited configuration entry.
- `modifiable` marks a parent configuration as child-editable.
- `const NAME = "value";` is documented in older grammar notes but failed with `ParseError` in broad verification runs. Treat `const` as currently unsupported.

## Matching Semantics

- `precise = true` means exact FQN-style matching when the field supports it.
- Without `precise`, `value` is generally treated as a regex-like pattern.
- `param` constrains argument positions and taint/type expectations, for example `"[{'position':0,'tainted':true}]"`.
- `tag` marks sources or propagations for later matching.
- `excludeTag` lets `import roster ... exclude TagName` disable selected items.
- `xpath` is used in fields such as `source.methodParam` to match AST structure.
- `source.methodParam can match formal parameter names with xpath`, including `@Image='username'` and `matches(@Image,'...')`.
- Core `value` matching targets code identifiers such as method FQN strings, method-name regex patterns, class/type names, annotation FQN names, variable-name regex patterns, and propagate method names. It does not directly match arbitrary call-argument literal values.
- XPath AST matching is available through fields that explicitly support `xpath`, especially `general.entranceFileXpath` and `source.methodParam.xpath`.
- Boolean/Int config belongs to direct `general.*` fields and block-style `propagate.b*` / `sink.bUseSinkFilter` fields, depending on the specific field.
- ExcludeTag is used with import-level `exclude` to suppress tagged groups or entries.
- `sink.xpath is not directly assignable`; use supported `xpath` subfields such as `source.methodParam.xpath` or entry filters such as `general.entranceFileXpath`.

## Propagation

Use `propagate.customMethodPropagate` for method-specific flows:

```java
propagate.customMethodPropagate += {
    value = "java.lang.StringBuilder.append";
    from = "0";
    to = "return";
};
```

Common `from`/`to` values are numeric argument indexes, `object`, and `return`.

`propagate.methodArgToReturn does not exist`. Use verified fields such as `propagate.methodArgToReturnCritical`, `propagate.methodArgToObjectAndReturn`, or `propagate.methodArgOrObjectToObjectAndReturn` when those semantics are needed.

## Groups

```java
group spring_handler {
    includePlatforms = "*";
    excludePlatforms = "";
    source.mvcMapping += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestMapping";
    };
};
```

Use groups for framework/platform differences and to expose `excludeTag`-controlled behavior.
