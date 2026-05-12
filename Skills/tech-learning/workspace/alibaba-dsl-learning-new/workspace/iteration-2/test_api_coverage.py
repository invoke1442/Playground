#!/usr/bin/env python3
"""Second-iteration coverage checks for official Alibaba DSL extension APIs.

These tests intentionally check only local files. They verify documentation and
reference coverage, not live remote verifier behavior.
"""

from __future__ import annotations

import unittest
from pathlib import Path


BASE = Path(__file__).resolve().parents[2]
SKILL = BASE / "alibaba-dsl-new"
OFFICIAL = BASE / "official-docs"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def read_many(paths: list[Path]) -> str:
    return "\n".join(read(path) for path in paths)


class OfficialApiCoverage(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.java_entry = read(SKILL / "references" / "java-loadclass.md")
        cls.js_dsl_ref = read(SKILL / "references" / "javascript-dsl-syntax.md")
        cls.js_entry_path = SKILL / "references" / "javascript-extend-file.md"
        cls.java_detail_paths = sorted((SKILL / "references" / "java-loadclass").glob("*.md"))
        cls.js_detail_paths = sorted((SKILL / "references" / "javascript-extend-file").glob("*.md"))
        cls.java_ref = cls.java_entry + "\n" + read_many(cls.java_detail_paths)
        cls.js_ref = cls.js_dsl_ref
        if cls.js_entry_path.exists():
            cls.js_ref += "\n" + read(cls.js_entry_path)
        cls.js_ref += "\n" + read_many(cls.js_detail_paths)
        cls.skill = read(SKILL / "SKILL.md")
        cls.java_official = read(OFFICIAL / "java-loadclass-api.md")
        cls.js_official = read(OFFICIAL / "javascript-extend-file-api.md")

    def assert_terms_present(self, haystack: str, terms: list[str]) -> None:
        missing = [term for term in terms if term not in haystack]
        self.assertFalse(missing, "Missing terms:\n" + "\n".join(missing))

    def test_official_docs_contain_expected_api_surface(self):
        self.assert_terms_present(
            self.java_official,
            [
                "evaluate(JavaNode, BaseFSMMachineRule, BaseTaintedDataRuleData)",
                'getDeclaredMethod("evaluate", JavaNode.class, Rule.class)',
                "ASTName",
                "InterDataCache",
                "InterAppTypeInfor",
                "JavaRuleUtil",
                "TracerNode.TYPE",
            ],
        )
        self.assert_terms_present(
            self.js_official,
            [
                "extendFileDir",
                "rule-extend-file",
                "TaintVarSet",
                "customSourceFunc",
                "validateFunction",
                "entranceEvalFun",
                "evalFun",
                "helperFunctions",
            ],
        )

    def test_reference_structure_supports_progressive_disclosure(self):
        expected_java = {
            "INDEX.md",
            "GENERAL.md",
            "evaluate-lifecycle.md",
            "ast-node-api.md",
            "rule-base-api.md",
            "data-model-api.md",
            "toolclass-api.md",
            "examples.md",
        }
        expected_js = {
            "INDEX.md",
            "GENERAL.md",
            "loading-and-lifecycle.md",
            "runtime-params-api.md",
            "visitor-api.md",
            "context-api.md",
            "taint-var-set-api.md",
            "builtin-modules-api.md",
            "extension-points-api.md",
            "examples.md",
        }
        self.assertEqual(expected_java, {path.name for path in self.java_detail_paths})
        self.assertEqual(expected_js, {path.name for path in self.js_detail_paths})
        self.assertTrue(self.js_entry_path.exists())
        self.assert_terms_present(
            self.skill,
            [
                "Treat `references/` as the API source of truth",
                "Do not write API signatures, field names, return semantics, or loadclass paths from memory",
                "references/java-loadclass/INDEX.md",
                "references/javascript-extend-file/INDEX.md",
            ],
        )
        self.assert_terms_present(
            self.java_entry,
            ["references/java-loadclass/INDEX.md", "references/java-loadclass/GENERAL.md"],
        )
        self.assert_terms_present(
            read(self.js_entry_path),
            ["references/javascript-extend-file/INDEX.md", "references/javascript-extend-file/GENERAL.md"],
        )

    def test_java_loadclass_reference_covers_official_api_surface(self):
        self.assert_terms_present(
            self.java_ref,
            [
                "evaluate(JavaNode, BaseFSMMachineRule, BaseTaintedDataRuleData)",
                "evaluate(JavaNode, Rule)",
                "evaluate(SSANode, AbstractSSARule, SSARuleData)",
                "evaluate(JavaNode, BaseLLMScanRule, BaseLLMScanRuleData)",
                "TracerNode.TYPE",
                "ASTPrimaryExpression.getRawCallString()",
                "ASTExpression.getLiteralValue()",
                "ASTExpression.getSingleChildOfName()",
                "ASTName.getNameDeclaration()",
                "ASTMethodDeclaration.getFullProfile()",
                "AbstractNode.getFirstNextSibling",
                "ASTArguments.getMethodName()",
                "BaseTaintedDataRule.handleSingleVar",
                "BaseTaintedDataRule.handleUserDefineInvoke",
                "BaseTaintedDataRule.addTaintedVariable",
                "AbstractTaintedDataRule.isVariableMayTainted",
                "AbstractTaintedDataRule.getTaintVarSet",
                "BaseFSMMachineRule.getVisitedMethods",
                "TaintedResult",
                "MapOfVariable.getMapOfVariableFromNodeWithDecl",
                "InterJavaTracerNode",
                "MethodArgs",
                "MethodContext.addMultiTaintedVariable",
                "InterDataCache.getInstance",
                "InterAppTypeInfor.getInterAppTypeInfor",
                "ASTUtil.preparePatternInXpath",
                "CodeUtil.getCallString",
                "JavaRuleUtil.getPattern",
                "PMDConstants.HSFDBIDU",
            ],
        )

    def test_javascript_reference_covers_official_extend_api_surface(self):
        self.assert_terms_present(
            self.js_ref,
            [
                "extendFileDir",
                "rule-extend-file",
                "extend-file/{rule_id}/",
                "extend-file/rosters/{RosterName}_0/",
                "Multiple userDefineFunc",
                "TaintAnalysisVisitor",
                "FsmAnalysisVisitor",
                "InterTaintAnalysisVisitor",
                "InterFsmAnalysisVisitor",
                "ExpressionStatement",
                "VariableStatement",
                "CallExpression",
                "no try-catch wrapper",
                "rule.analysisVisitor.addBugReport",
                "rule.analysisVisitor.handleMultiTaintSinkTrace",
                "rule.analysisVisitor.addMultiTaintTrace",
                "rule.analysisVisitor.handleTaintResult",
                "rule.analysisVisitor.getCurrentTaintFieldSet",
                "rule.analysisVisitor.setControlFlowBroken",
                "context.getCustomData",
                "context.setCurrentEntrance",
                "SinkType",
                "TaintVarSet",
                "addTaintVariable",
                "addMultiTaintVariable",
                "isVariableMayTaint",
                "isVariableMayMultiTaint",
                "getTaintedSubPathesSet",
                "getFieldTaintVarSet",
                'require("../global")',
                'require("../util")',
                'require("../../visitor")',
                'require("../InterApp/MapofVariable")',
                "TypeScriptVisitorAdapter",
                "GlobalContext.matchCallString",
                "util.findFirstNodeByXpath",
                "MapOfVariable.getVarFromNode",
                "customSourceFunc",
                "validateFunction",
                "entranceEvalFun",
                "evalFun",
                "helperFunctions",
                'source.customSourceFunc = loadclass("XssTs_6991.rule.customSourceFunc")',
                'general.validateFunction = loadclass("XssTs_6991.rule.validateFunction")',
            ],
        )

    def test_javascript_dsl_reference_is_not_the_extend_file_api_home(self):
        self.assert_terms_present(
            self.js_dsl_ref,
            [
                "JavaScript Field Rules",
                "For JavaScript extend-file APIs",
            ],
        )
        self.assertNotIn("## TaintVarSet API", self.js_dsl_ref)
        self.assertNotIn("## Built-In Require Modules", self.js_dsl_ref)

    def test_verify_workflow_guidance_remains_prominent(self):
        combined = self.skill + "\n" + read(SKILL / "references" / "verification.md")
        self.assert_terms_present(
            combined,
            [
                "Run local lint first",
                "scripts/verify_alibaba_dsl.py",
                "official verifier acceptance",
                "Report validation status precisely",
            ],
        )


if __name__ == "__main__":
    unittest.main()
