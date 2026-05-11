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
| `source` | `methodReturn`, `methodParam`, `paramAnnotation`, `mvcMapping`, `allocReturn`, `velocityReference`, `methodReturnJws`, `annotationJWS` |
| `sink` | `methodArg`, `methodObject`, `allocArg`, `methodArgJws`, `methodCritical`, `methodSqlSpecial`, `methodXbatis`, `responseBody`, `applicationJsonProduces` |
| `sanitizer` | `methodReturn`, `methodArg`, `methodObject`, `safeTypes`, `safeVarNames`, `methodSafeState`, `methodUnSafeState` |
| `propagate` | `customMethodPropagate`, `methodObjectToReturn`, `methodObjectToFirstArg`, `methodArgOrObjectToObjectAndReturn`, `methodArgToObjectAndReturn`, `methodArgToReturnCritical`, `bAllPublicMethod` |
| `general` | `customSubject`, `entranceFileXpath`, `scanAllFiles`, `userDefinePatternClass`, `userDefineEntranceClass`, `methodRedirect`, `taintOnlyBySummary`, `handlePolymorphism` |

## Matching Semantics

- `precise = true` means exact FQN-style matching when the field supports it.
- Without `precise`, `value` is generally treated as a regex-like pattern.
- `param` constrains argument positions and taint/type expectations, for example `"[{'position':0,'tainted':true}]"`.
- `tag` marks sources or propagations for later matching.
- `excludeTag` lets `import roster ... exclude TagName` disable selected items.
- `xpath` is used in fields such as `source.methodParam` to match AST structure.

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

## Groups

```java
group spring_handler {
    includePlatforms = "*";
    source.mvcMapping += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestMapping";
    };
};
```

Use groups for framework/platform differences and to expose `excludeTag`-controlled behavior.
