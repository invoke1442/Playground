#!/usr/bin/env python3
"""Final consolidation checks for a unified Alibaba DSL skill reference model.

This round removes the legacy/non-legacy split from the active skill. Historical
evidence may inform the content, but the shipped skill should expose one unified
set of instructions and references.
"""

from __future__ import annotations

import unittest
from pathlib import Path


BASE = Path(__file__).resolve().parents[2]
SKILL = BASE / "alibaba-dsl-new"
REFERENCES = SKILL / "references"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class UnifiedReferenceModel(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.skill = read(SKILL / "SKILL.md")
        cls.java_syntax = read(REFERENCES / "java-dsl-syntax.md")
        cls.js_syntax = read(REFERENCES / "javascript-dsl-syntax.md")
        cls.verify_ref = read(REFERENCES / "verification.md")
        cls.error_guide = read(REFERENCES / "error-guide.md")
        cls.ref_texts = {
            path.relative_to(SKILL).as_posix(): read(path)
            for path in REFERENCES.rglob("*.md")
        }

    def assert_terms_present(self, haystack: str, terms: list[str]) -> None:
        missing = [term for term in terms if term not in haystack]
        self.assertFalse(missing, "Missing terms:\n" + "\n".join(missing))

    def test_no_legacy_policy_file_remains(self) -> None:
        self.assertFalse((REFERENCES / "legacy-verify-notes-policy.md").exists())

    def test_skill_routes_to_unified_references(self) -> None:
        self.assert_terms_present(
            self.skill,
            [
                "references/java-dsl-syntax.md",
                "references/javascript-dsl-syntax.md",
                "references/verification.md",
                "references/error-guide.md",
                "Run local lint first",
                "scripts/verify_alibaba_dsl.py",
                "ALIBABA_DSL_VERIFY_URL",
            ],
        )
        self.assertNotIn("references/legacy-verify-notes-policy.md", self.skill)
        self.assertNotIn("legacy", self.skill.lower())

    def test_active_references_do_not_present_a_legacy_split(self) -> None:
        for rel_path, text in self.ref_texts.items():
            self.assertNotIn(
                "legacy-verify-notes-policy",
                text,
                f"{rel_path} still depends on the removed legacy policy file",
            )
            self.assertNotIn(
                "Legacy verify-era",
                text,
                f"{rel_path} still presents a legacy/non-legacy split",
            )

    def test_java_and_js_syntax_present_unified_verified_facts(self) -> None:
        self.assert_terms_present(
            self.java_syntax,
            [
                "Verified Rule/Roster Facts",
                "type and subType are required",
                "Java sink.methodReturn is string-only",
                "Java sanitizer.methodReturn and sanitizer.methodArg require block syntax",
                "source.paramAnnotation and source.param_annotation are different fields",
            ],
        )
        self.assert_terms_present(
            self.js_syntax,
            [
                "Verified Rule/Roster Facts",
                "precise is not recognized in JavaScript rules",
                "sink.methodArg and sanitizer.methodReturn use pattern",
                "value and pattern are mutually exclusive",
                "group is valid in JavaScript Roster only; group in Rule causes ParseError",
            ],
        )

    def test_verification_and_error_docs_assume_remote_verify_is_available(self) -> None:
        self.assert_terms_present(
            self.verify_ref,
            [
                "Run local lint before remote verify",
                "scripts/verify_alibaba_dsl.py",
                "official verifier acceptance",
                "verify_type=rule",
                "verify_type=roster",
                "ALIBABA_DSL_VERIFY_URL",
            ],
        )
        self.assert_terms_present(
            self.error_guide,
            [
                "confirm it with `scripts/verify_alibaba_dsl.py` after local lint passes",
                "configure is not modifiable in parent rule",
                "invalid regular expression",
            ],
        )
        self.assertNotIn("currently unavailable", self.verify_ref)
        self.assertNotIn("current environment cannot re-run the remote verifier", self.error_guide)


if __name__ == "__main__":
    unittest.main()
