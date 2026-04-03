# Alibaba DSL — Experiment Summary & Derived Best Practices
# Date: 2026-04-01
# Total experiments: 80+ (exp01-22, f01-12, g01-12, h01-09, r01-24, s01-24, t01-12)

## CRITICAL FINDING 1: `import` keyword NOT SUPPORTED
- ALL positions tested: before type, after type, after source/sink
- Java: ParseError or NullPointerException (runtime crash)
- JS: ParseError ("mismatched input 'import' expecting '}'") or runtime error
- Evidence: exp03, r01, r03, r05, r08, r09, r12, r14, r15, r20, r21, r22, t01-t04
- Official docs show `import` but API does NOT support it

## CRITICAL FINDING 2: Correct Rule↔Roster linking = relation/config_roster_relation.json
- Format: {"rule_id": ["RosterName_0"]}
- Supports multiple rosters per rule
- Supports shared rosters across multiple rules
- Evidence: s01✅, s02✅, s03✅, s04✅, s05✅, s13✅, s14✅, s19✅, s20✅, s23✅, t09✅, t10✅, t11✅, t12a✅, t12b✅

## CRITICAL FINDING 3: rosters/ directory MUST exist
- Even if empty
- Error without it: "ruleDir has no roster sub directory"
- Evidence: t07✅ (empty dir ok), t08❌ (no dir fails)

## CRITICAL FINDING 4: Java `loadclass` NOT SUPPORTED
- source.customSourceFunc, sink.customSinkFunc → all fail
- Error: "custom define config: X can only be string value"
- Evidence: t05❌, t06❌, s21❌, exp05❌, exp22❌

## CRITICAL FINDING 5: JS `loadclass` WORKS (in Roster only)
- source.customSourceFunc = loadclass("Module.func_0") ✅
- Using = (not +=)
- Evidence: s22✅, g11✅

## Java Supported Fields (verified)
| Field | Rule | Roster | Evidence |
|-------|------|--------|----------|
| source.methodReturn | ✅ | ✅ | exp01, r02 |
| source.methodArg | ✅ | ✅ | g04, g10 |
| sink.methodArg | ✅ | ✅ | exp01, r02 |
| sanitizer.methodReturn | ✅ | ✅ | g05, r02 |
| sanitizer.methodArg | ✅ | ✅ | r16, s08a |
| group (Roster only) | ❌ | ✅ | exp04❌, f06✅ |
| define | ✅ | - | f10, t11 |
| delete | ✅ | - | f11 |
| modifiable | ✅ | - | g07 |
| precise (true/false) | ✅ | ✅ | exp01, r23 |

## Java NOT Supported (verified)
| Field | Error | Evidence |
|-------|-------|----------|
| propagate.* | custom define config | s07a❌, s07b❌, s07c❌, r04❌, r07❌, s06❌, r13❌ |
| sink.methodReturn | custom define config | g06❌ |
| sink.functionArg | custom define config | s09❌ |
| sanitizer.functionArg | custom define config | s08b❌ |
| sanitizer.functionReturn | custom define config | s08c❌ |
| source.param_annotation | custom define config | s10❌ |
| source.method_annotation | custom define config | s11❌ |
| source.method_param | custom define config | s15❌ |
| loadclass | custom define config | t05❌, t06❌ |
| const | ParseError | s12❌ |
| general.desc | not modifiable | s16❌ |
| import | ParseError/NPE | t01-t04❌ |

## JS Supported Fields (verified)
| Field | Rule | Roster | Evidence |
|-------|------|--------|----------|
| source.methodReturn | ✅ | ✅ | f03, f08 |
| source.expression | ✅ | ✅ | exp17, g08 |
| source.paramDecorator | - | ✅ | g09 |
| sink.methodArg (pattern req) | ✅ | ✅ | f03, g03 |
| sanitizer.methodReturn | - | ✅ | r24, s18 |
| group (Roster only) | ❌ | ✅ | f07❌, g01✅ |
| loadclass (Roster) | - | ✅ | s22, g11 |
| taintTag | ✅ | ✅ | exp17, s11 |
| paramIndex | ✅ | ✅ | in sink.methodArg |
| expression | ✅ | ✅ | g08 |

## JS NOT Supported
| Field | Error | Evidence |
|-------|-------|----------|
| precise | cannot find field | exp10❌, exp11❌ |
| propagate.* | custom define config | s17❌ |
| import | ParseError | t02❌ |

## Roster-Centric Best Practice (RECOMMENDED PATTERN)
1. Rule = entry point only (type + subType)
2. Roster = ALL source/sink/sanitizer definitions
3. relation/config_roster_relation.json = linking
4. rosters/ dir = ALWAYS present (even if empty for Rule-only verification)
5. Multiple specialized Rosters: source + sink + sanitizer (separation of concerns)
6. Group in Roster for platform-specific configs
