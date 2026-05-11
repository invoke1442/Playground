# Web Taint Modeling Patterns

## General Method

1. Define sources from request inputs, route params, headers, cookies, file uploads, message handlers, RPC payloads, or framework-specific controller parameters.
2. Define sinks that consume tainted data in a dangerous operation.
3. Add sanitizers that genuinely validate or encode the data for the specific sink context.
4. Add propagation for builders, wrappers, copies, and framework handoff methods.
5. Verify with at least one vulnerable and one safe sample path in the target language.

## Java Vulnerability Patterns

| Vulnerability | Typical sources | Typical sinks | Typical sanitizers |
|---|---|---|---|
| SQL injection | `HttpServletRequest.getParameter`, Spring `@RequestParam`, JAX-RS params | `Statement.execute*`, `Connection.prepareStatement`, ORM native query APIs, MyBatis template render paths | SQL-specific parameterization or `SecurityUtil.escapeSql` when valid for the context |
| SSRF | request params, headers, uploaded config values | `new URL`, `URI.create`, `RestTemplate.*`, `HttpClient.execute`, `OkHttpClient.newCall` | allowlist URL validation, `checkSSRF`, safe URL builders |
| XSS | request params, cookies, template context inputs | servlet writer methods, template `put`, response body sinks | context-appropriate HTML/JS/JSON encoding |
| Command injection | request params and job/task inputs | `Runtime.exec`, `ProcessBuilder`, shell launch APIs, Groovy/script eval for commands | command allowlists, argument escaping |
| Path traversal | request params, upload names | `new File`, file read/write/copy/delete APIs, `Paths.get` | canonical path checks and path filters |
| XXE | uploaded XML, request streams | XML parser builders/readers, SAX/DOM/JAXB parse APIs | secure parser config, validated XML utilities |

## JavaScript Vulnerability Patterns

| Vulnerability | Typical sources | Typical sinks | Typical sanitizers |
|---|---|---|---|
| XSS | `req.query`, `req.body`, `ctx.request.body`, route params | `res.send`, `res.write`, `ctx.body`, template render calls | `escapeHtml`, `sanitizeHtml`, context-specific encoders |
| SQL injection | request data | `query`, `sequelize.query`, mysql connection queries | parameterized APIs and SQL escaping for the right dialect |
| SSRF | request data, headers | `fetch`, `axios`, `request`, URL-opening wrappers | allowlist URL validation |
| Command injection | request data | `child_process.exec`, shell wrappers | fixed command maps and argument escaping |
| Path traversal | request data, upload names | `fs.readFile`, `fs.writeFile`, `path.join` to sensitive roots | path normalization plus root containment checks |

## Modeling Advice

- Prefer exact FQNs for high-risk sinks where the engine resolves type information.
- Use regex patterns for framework APIs and overloaded method families.
- Add `param` or `paramIndex` to avoid treating safe arguments as dangerous.
- Do not model validation as a sanitizer unless it proves the sink-specific safety property.
- For builders, add propagation from tainted argument or object to return/object.
- For framework entrypoints, use `general.entranceFileXpath`, `source.methodParam`, or loadclass.
- For false positives, first add precise param/type/tag constraints; use loadclass only when field constraints are insufficient.
