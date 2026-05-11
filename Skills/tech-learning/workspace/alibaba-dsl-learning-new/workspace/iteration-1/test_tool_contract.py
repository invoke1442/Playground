#!/usr/bin/env python3
"""Contract tests for the Alibaba DSL helper scripts."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


BASE = Path(__file__).resolve().parents[2]
SKILL = BASE / "alibaba-dsl-new"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


class HelperScriptContract(unittest.TestCase):
    def test_lint_accepts_rule_roster_relation_import_contract(self):
        lint = load_module("lint_alibaba_dsl", SKILL / "scripts" / "lint_alibaba_dsl.py")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "rosters").mkdir()
            (root / "relation").mkdir()
            (root / "90001.rul").write_text(
                """Rule WebSqlRule extends AbstractTaintRule {
    import roster Java_web_taint;
    type = "SQLInjection";
    subType = "sqlInjectionJava";
}
""",
                encoding="utf-8",
            )
            (root / "rosters" / "Java_web_taint_0.ros").write_text(
                """Roster Java_web_taint {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { precise = true; value = "java.sql.Statement.execute"; };
}
""",
                encoding="utf-8",
            )
            (root / "relation" / "config_roster_relation.json").write_text(
                json.dumps({"90001": ["Java_web_taint_0"]}),
                encoding="utf-8",
            )
            report = lint.lint_config(root)
        self.assertTrue(report["ok"], report)

    def test_lint_rejects_import_after_fields(self):
        lint = load_module("lint_alibaba_dsl", SKILL / "scripts" / "lint_alibaba_dsl.py")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "rosters").mkdir()
            (root / "relation").mkdir()
            (root / "90001.rul").write_text(
                """Rule BrokenRule extends AbstractTaintRule {
    type = "SSRF";
    import roster Java_web_taint;
    subType = "ssrfJava";
}
""",
                encoding="utf-8",
            )
            report = lint.lint_config(root)
        self.assertFalse(report["ok"], report)
        self.assertTrue(any(error["code"] == "IMPORT_AFTER_FIELD" for error in report["errors"]))

    def test_verify_script_can_pack_plain_tar(self):
        verify = load_module("verify_alibaba_dsl", SKILL / "scripts" / "verify_alibaba_dsl.py")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "config"
            root.mkdir()
            (root / "90001.rul").write_text(
                'Rule TestRule extends AbstractTaintRule { type = "Test"; subType = "Test"; }\n',
                encoding="utf-8",
            )
            tar_path = Path(tmp) / "config.tar"
            verify.create_config_tar(root, tar_path)
            self.assertGreater(tar_path.stat().st_size, 0)
            self.assertTrue(tar_path.read_bytes().startswith(b"././@PaxHeader") or tar_path.read_bytes())

    def test_direct_eval_runner_uses_outer_sandbox_bypass(self):
        runner = load_module(
            "direct_eval_runner",
            Path(__file__).resolve().parent / "direct_eval_runner.py",
        )
        self.assertIn("--dangerously-bypass-approvals-and-sandbox", runner.build_codex_command(Path("/tmp/run")))

    def test_direct_eval_runner_extracts_token_usage(self):
        runner = load_module(
            "direct_eval_runner",
            Path(__file__).resolve().parent / "direct_eval_runner.py",
        )
        usage = runner.extract_usage(
            [
                {"type": "turn.started"},
                {
                    "type": "turn.completed",
                    "usage": {
                        "input_tokens": 10,
                        "cached_input_tokens": 3,
                        "output_tokens": 4,
                        "reasoning_output_tokens": 2,
                    },
                },
            ]
        )
        self.assertEqual(
            usage,
            {
                "input_tokens": 10,
                "cached_input_tokens": 3,
                "output_tokens": 4,
                "reasoning_output_tokens": 2,
            },
        )

    def test_direct_eval_runner_records_timeout_outputs(self):
        runner = load_module(
            "direct_eval_runner",
            Path(__file__).resolve().parent / "direct_eval_runner.py",
        )
        with tempfile.TemporaryDirectory() as tmp:
            run_dir = Path(tmp)
            outputs_dir = run_dir / "outputs"
            outputs_dir.mkdir()
            (outputs_dir / "partial.txt").write_text("partial", encoding="utf-8")
            result = runner.record_result(
                run_dir=run_dir,
                outputs_dir=outputs_dir,
                stdout='{"type":"turn.completed","usage":{"input_tokens":1}}\n',
                stderr="timed out",
                returncode=124,
                started=1.0,
                ended=3.5,
                timed_out=True,
            )
            metrics = json.loads((outputs_dir / "metrics.json").read_text(encoding="utf-8"))
            timing = json.loads((run_dir / "timing.json").read_text(encoding="utf-8"))
        self.assertEqual(result["returncode"], 124)
        self.assertEqual(metrics["usage"]["input_tokens"], 1)
        self.assertEqual(metrics["errors_encountered"], 1)
        self.assertTrue(metrics["timed_out"])
        self.assertIn("partial.txt", metrics["files_created"])
        self.assertEqual(timing["total_duration_seconds"], 2.5)

    def test_grader_prefers_deliverables_over_markdown_fences(self):
        grader = load_module("grade_runs", Path(__file__).resolve().parent / "grade_runs.py")
        with tempfile.TemporaryDirectory() as tmp:
            run_dir = Path(tmp)
            (run_dir / "outputs" / "config" / "rosters").mkdir(parents=True)
            (run_dir / "outputs" / "config" / "relation").mkdir(parents=True)
            (run_dir / "outputs" / "config" / "90001.rul").write_text(
                """Rule JavaSsrfTaintRule extends AbstractTaintRule {
    import roster Java_ssrf_taint;
    type = "SSRF";
    subType = "ssrfJava";
}
""",
                encoding="utf-8",
            )
            (run_dir / "outputs" / "config" / "rosters" / "Java_ssrf_taint_0.ros").write_text(
                """Roster Java_ssrf_taint {
    source.methodReturn += { value = "javax.servlet.http.HttpServletRequest.getParameter"; };
    sink.methodArg += { value = "java.net.URL.<init>"; };
    sanitizer.methodArg += { value = "com.alibaba.security.SecurityUtil.checkSSRF"; };
}
""",
                encoding="utf-8",
            )
            (run_dir / "outputs" / "config" / "relation" / "config_roster_relation.json").write_text(
                json.dumps({"90001": ["Java_ssrf_taint_0"]}),
                encoding="utf-8",
            )
            (run_dir / "outputs" / "user_notes.md").write_text(
                "```bash\npython scripts/lint_alibaba_dsl.py config --language java\n```\n\nRemote verify commands:\n\n```bash\npython scripts/verify_alibaba_dsl.py config --language java --verify-type rule --rule-id 90001\n```\n",
                encoding="utf-8",
            )
            grading = grader.grade_run("java-ssrf-rule", run_dir)
        self.assertEqual(grading["summary"]["pass_rate"], 1.0)


if __name__ == "__main__":
    unittest.main()
