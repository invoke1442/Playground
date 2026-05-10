import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from scripts import codex_runner
from scripts.generate_openai_yaml import format_display_name, write_openai_yaml
from scripts.init_skill import normalize_skill_name, init_skill
from scripts.quick_validate import validate_skill


class CodexMigrationTests(unittest.TestCase):
    def test_validate_skill_does_not_require_pyyaml(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill_dir = Path(tmp) / "sample-skill"
            skill_dir.mkdir()
            (skill_dir / "SKILL.md").write_text(
                "---\n"
                "name: sample-skill\n"
                "description: |\n"
                "  Use this skill for sample Codex tasks.\n"
                "compatibility: Codex CLI\n"
                "---\n\n"
                "# Sample Skill\n"
            )

            valid, message = validate_skill(skill_dir)

        self.assertTrue(valid, message)

    def test_openai_yaml_generation(self):
        with tempfile.TemporaryDirectory() as tmp:
            skill_dir = Path(tmp) / "github-pr-helper"
            skill_dir.mkdir()

            output = write_openai_yaml(
                skill_dir,
                "github-pr-helper",
                ["default_prompt=Use $github-pr-helper to review this pull request."],
            )

            content = output.read_text()
        self.assertEqual(format_display_name("github-pr-helper"), "GitHub PR Helper")
        self.assertIn('display_name: "GitHub PR Helper"', content)
        self.assertIn("default_prompt", content)

    def test_init_skill_creates_codex_metadata(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = init_skill(
                "My Skill",
                tmp,
                ["scripts"],
                include_examples=False,
                interface_overrides=[
                    "default_prompt=Use $my-skill to handle this workflow.",
                ],
            )

            self.assertIsNotNone(result)
            skill_dir = Path(result)
            self.assertTrue((skill_dir / "SKILL.md").exists())
            self.assertTrue((skill_dir / "agents" / "openai.yaml").exists())
            self.assertTrue((skill_dir / "scripts").is_dir())
            self.assertEqual(normalize_skill_name("My Skill"), "my-skill")

    def test_codex_runner_builds_exec_command(self):
        with tempfile.TemporaryDirectory() as tmp:
            workspace = Path(tmp) / "workspace"
            workspace.mkdir()
            result_payload = {"type": "agent_message", "message": {"content": [{"text": "ok"}]}}

            with patch("subprocess.run") as run:
                run.return_value.returncode = 0
                run.return_value.stdout = f"{codex_runner.json_dumps(result_payload)}\n"
                run.return_value.stderr = ""

                result = codex_runner.run_codex_exec(
                    "Say exactly: ok",
                    workspace=workspace,
                    model="gpt-test",
                    timeout=5,
                )

            cmd = run.call_args.args[0]
            self.assertEqual(cmd[:4], ["codex", "-a", "never", "exec"])
            self.assertIn("--json", cmd)
            self.assertIn("--ephemeral", cmd)
            self.assertIn("-a", cmd)
            self.assertIn("never", cmd)
            self.assertEqual(result.returncode, 0)
            self.assertIn("ok", result.final_text)


if __name__ == "__main__":
    unittest.main()
