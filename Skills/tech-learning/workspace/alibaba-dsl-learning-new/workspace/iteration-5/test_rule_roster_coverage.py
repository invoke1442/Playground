#!/usr/bin/env python3
"""Round-5 coverage checks for Rule/Roster syntax references.

This test intentionally avoids the remote verify API. It checks that the skill
captures the major stable facts from official docs and broad verify-tested
Rule/Roster notes.
"""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "alibaba-dsl-new"
OFFICIAL = ROOT / "official-docs" / "alibaba-dsl-api-doc.md"
LEGACY = ROOT.parent / "alibaba-dsl-learning" / "alibaba-dsl-learning-notes.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def require_all(text: str, needles: list[str], label: str) -> None:
    missing = [needle for needle in needles if needle not in text]
    assert not missing, f"{label} missing: {missing}"


def test_source_documents_are_the_expected_inputs() -> None:
    official = read(OFFICIAL)
    legacy = read(LEGACY)

    require_all(
        official,
        [
            "verify_type",
            "config_roster_relation.json",
            "config_addition_relation.json",
            "actual_use_config.json",
            "Line 1, Column 1: Lexical error",
            "the field value is required",
            "configure is not modifiable in parent rule",
        ],
        "official API doc",
    )
    require_all(
        legacy,
        [
            "define",
            "delete",
            "modifiable",
            "const",
            "source.methodReturn",
            "sink.methodArg",
            "sanitizer.methodReturn",
            "propagate.bAllPublicMethod",
            "source.paramAnnotation",
            "source.param_annotation",
            "sink.methodObject",
            "sink.allocArg",
            "source.methodParam",
        ],
        "broad verify notes",
    )


def test_skill_routes_agents_to_unified_references() -> None:
    skill = read(SKILL / "SKILL.md")
    require_all(
        skill,
        [
            "Treat `references/` as the API source of truth",
            "references/java-dsl-syntax.md",
            "references/javascript-dsl-syntax.md",
            "references/verification.md",
            "references/error-guide.md",
            "Run local lint first",
            "scripts/verify_alibaba_dsl.py",
        ],
        "SKILL.md",
    )


def test_java_syntax_reference_covers_trusted_rule_roster_facts() -> None:
    java_ref = read(SKILL / "references" / "java-dsl-syntax.md")
    require_all(
        java_ref,
        [
            "define",
            "delete",
            "modifiable",
            "const",
            "currently unsupported",
            "source.paramAnnotation",
            "source.methodParam",
            "source.mvcMapping",
            "source.allocReturn",
            "source.velocityReference",
            "source.methodReturnJws",
            "source.annotationJWS",
            "sink.allocArg",
            "sink.methodObject",
            "sink.methodArgJws",
            "sink.methoArgUpcast",
            "sink.responseBody",
            "sink.responseClass",
            "sink.applicationJsonProduces",
            "sink.applicationJsonAnnotation",
            "sink.methodCritical",
            "sink.methodSqlSpecial",
            "sink.contextJws",
            "sink.mybatisProvider",
            "sink.methodXbatis",
            "sink.methodXbatisExclude",
            "sink.bUseSinkFilter",
            "sink.filter",
            "sanitizer.safeTypes",
            "sanitizer.safeVarNames",
            "sanitizer.methodObject",
            "sanitizer.methodRedirectCheck",
            "sanitizer.methodSafeState",
            "sanitizer.methodUnSafeState",
            "sanitizer.methodArgWithRedirectCheck",
            "general.taintOnlyBySummary",
            "general.blackFieldMatch",
            "general.handlePolymorphism",
            "general.polyHandleNum",
            "general.scanAllFiles",
            "general.entranceFileXpath",
            "general.methodRedirect",
            "general.customSubject",
            "general.genAppSummary",
            "propagate.bAllPublicMethod",
            "propagate.bUseSqlSpecial",
            "propagate.bUseCritical",
            "propagate.bPreSanitizerParam",
            "propagate.bUseSafeState",
            "propagate.bUnkownAsSafe",
            "propagate.bTaintedStart",
            "propagate.bOnlyTaintedByObject",
            "propagate.bSanitizerParamTransmit",
            "propagate.bUseXXEFlags",
            "propagate.bUseStreamReader",
            "propagate.noTaintNoSourceFile",
            "propagate.definiteNoSourceFile",
            "propagate.criticalType",
            "propagate.xxeType",
            "propagate.xxeMethod",
            "propagate.methodStreamReader",
            "inline comments",
            "empty string",
            "includePlatforms = \"*\"",
            "excludePlatforms = \"\"",
            "method FQN",
            "method-name regex",
            "class/type names",
            "variable-name regex",
            "annotation FQN",
            "formal parameter names",
            "XPath AST matching",
            "Boolean/Int config",
            "ExcludeTag",
            "param JSON",
        ],
        "Java DSL syntax reference",
    )


def test_javascript_syntax_reference_covers_trusted_rule_roster_facts() -> None:
    js_ref = read(SKILL / "references" / "javascript-dsl-syntax.md")
    require_all(
        js_ref,
        [
            "config_addition_relation.json",
            "actual_use_config.json",
            "source.methodReturn",
            "source.expression",
            "source.paramDecorator",
            "sink.methodArg",
            "sink.expression",
            "sink.methodReturn",
            "sink.paramDecorator",
            "sink.param_annotation",
            "sink.method_annotation",
            "sink.method_param",
            "sink.functionArg",
            "sink.customSinkFunc",
            "sanitizer.methodReturn",
            "sanitizer.expression",
            "sanitizer.methodArg",
            "sanitizer.paramDecorator",
            "sanitizer.param_annotation",
            "sanitizer.method_annotation",
            "sanitizer.method_param",
            "sanitizer.customSanitizerFunc",
            "JS sanitizer.methodArg is string syntax",
            "JS sanitizer.methodReturn is block syntax with pattern",
            "JS sink.methodArg requires block syntax with pattern",
            "Source call/expression blocks use `value`",
            "value and pattern are mutually exclusive",
            "JavaScript block fields do not accept Java-specific `flag`, `excludeTag`, or `param`",
            "group is valid in JavaScript Roster only",
        ],
        "JavaScript DSL syntax reference",
    )


def test_verification_and_errors_cover_official_rule_roster_info() -> None:
    verification = read(SKILL / "references" / "verification.md")
    error_guide = read(SKILL / "references" / "error-guide.md")

    require_all(
        verification,
        [
            "verify_type",
            "verify_type=rule",
            "verify_type=roster",
            "config_roster_relation.json",
            "config_addition_relation.json",
            "actual_use_config.json",
            "Plain `.tar`",
            "Run local lint before remote verify",
            "official verifier acceptance",
        ],
        "verification reference",
    )
    require_all(
        error_guide,
        [
            "Lexical error",
            "the field value is required",
            "configure is not modifiable in parent rule",
            "the value should be string type",
            "invalid regular expression",
            "invalid xpath",
            "invalid json",
        ],
        "error guide",
    )


if __name__ == "__main__":
    for test in [
        test_source_documents_are_the_expected_inputs,
        test_skill_routes_agents_to_unified_references,
        test_java_syntax_reference_covers_trusted_rule_roster_facts,
        test_javascript_syntax_reference_covers_trusted_rule_roster_facts,
        test_verification_and_errors_cover_official_rule_roster_info,
    ]:
        test()
    print("iteration-5 rule/roster coverage checks passed")
