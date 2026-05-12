#!/usr/bin/env python3
"""Coverage checks for integrating broad verify-tested Rule/Roster notes.

These tests read local files only. They validate documentation integration and
do not assert live remote verifier state.
"""

from __future__ import annotations

import unittest
from pathlib import Path


BASE = Path(__file__).resolve().parents[2]
SKILL = BASE / "alibaba-dsl-new"
LEGACY = BASE.parent / "alibaba-dsl-learning" / "alibaba-dsl-learning-notes.md"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class LegacyVerifyNotesIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.legacy = read(LEGACY)
        cls.skill = read(SKILL / "SKILL.md")
        cls.java_syntax = read(SKILL / "references" / "java-dsl-syntax.md")
        cls.js_syntax = read(SKILL / "references" / "javascript-dsl-syntax.md")
        cls.error_guide = read(SKILL / "references" / "error-guide.md")
        cls.java_loadclass = "\n".join(
            read(path) for path in sorted((SKILL / "references" / "java-loadclass").glob("*.md"))
        )
        cls.js_extend = "\n".join(
            read(path) for path in sorted((SKILL / "references" / "javascript-extend-file").glob("*.md"))
        )

    def assert_terms_present(self, haystack: str, terms: list[str]) -> None:
        missing = [term for term in terms if term not in haystack]
        self.assertFalse(missing, "Missing terms:\n" + "\n".join(missing))

    def test_legacy_notes_have_expected_reliable_rule_roster_facts(self):
        self.assert_terms_present(
            self.legacy,
            [
                "Java 规则中 `paramIndex` 字段**不被识别**",
                "`group` 在 Java **Roster 中有效**",
                "`group` 在 JS **Roster 中有效**",
                "relation config 仅保证 verify 通过",
                "`sink.methodReturn` 仅接受 **string 语法**",
                "propagate.methodArgToReturn` 不存在",
            ],
        )

    def test_skill_uses_integrated_rule_roster_conclusions(self):
        self.assert_terms_present(
            self.skill,
            [
                "references/java-dsl-syntax.md",
                "references/javascript-dsl-syntax.md",
                "Treat the syntax references as already integrated",
                "scripts/verify_alibaba_dsl.py",
            ],
        )

    def test_java_syntax_integrates_verified_rule_roster_facts(self):
        self.assert_terms_present(
            self.java_syntax,
            [
                "Verified Rule/Roster Facts",
                "import roster is the runtime link",
                "relation config is only verify-time file discovery",
                "import roster X exclude A,B;",
                "group is valid in Roster only; group in Rule causes ParseError",
                "type and subType are required",
                "Java sink.methodReturn is string-only",
                "Java sink.methodArg does not support paramIndex",
                "Java sanitizer.methodReturn and sanitizer.methodArg require block syntax",
                "source.paramAnnotation and source.param_annotation are different fields",
                "source.methodParam can match formal parameter names with xpath",
                "sink.xpath is not directly assignable",
                "propagate.methodArgToReturn does not exist",
                "param JSON is confirmed for Java sink.methodArg",
                "A Roster name is descriptive only; a propagate roster may contain propagate, sanitizer, sink, and general fields",
            ],
        )

    def test_javascript_syntax_integrates_verified_rule_roster_facts(self):
        self.assert_terms_present(
            self.js_syntax,
            [
                "Verified Rule/Roster Facts",
                "source.methodReturn, source.expression, and source.paramDecorator use value",
                "sink.methodArg and sanitizer.methodReturn use pattern",
                "value and pattern are mutually exclusive",
                "precise is not recognized in JavaScript rules",
                "group is valid in JavaScript Roster only; group in Rule causes ParseError",
                "JS sink.methodArg requires block syntax with pattern",
                "JS sanitizer.methodArg is string syntax",
                "JS sanitizer.methodReturn is block syntax with pattern",
                "paramIndex and taintTag are JavaScript-side sink constraints",
                "Use `references/javascript-extend-file/` for extend-file APIs",
            ],
        )

    def test_loadclass_extend_file_authority_remains_current_references(self):
        self.assert_terms_present(
            self.java_loadclass,
            [
                "evaluate(JavaNode, AbstractTaintedDataRule, AbstractTaintedDataRuleData)",
                "evaluate(JavaNode, BaseFSMMachineRule, BaseTaintedDataRuleData)",
                "InterDataCache.getInstance()",
            ],
        )
        self.assert_terms_present(
            self.js_extend,
            [
                "extendFileDir",
                "Multiple userDefineFunc",
                "TaintVarSet",
                "TypeScriptVisitorAdapter",
            ],
        )

    def test_error_guide_marks_integrated_verify_sources_without_claiming_current_verify(self):
        self.assert_terms_present(
            self.error_guide,
            [
                "broad verification notes",
                "confirm it with `scripts/verify_alibaba_dsl.py` after local lint passes",
                "configure is not modifiable in parent rule",
                "value should be complex type",
                "custom define config: source.X can only be string value",
            ],
        )


if __name__ == "__main__":
    unittest.main()
