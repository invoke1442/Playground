#!/usr/bin/env python3
"""Improve a Codex skill description based on trigger eval results."""

from __future__ import annotations

import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

from scripts.codex_runner import run_codex_exec
from scripts.utils import parse_skill_md


def _call_codex(prompt: str, model: str | None, timeout: int = 300, codex_bin: str = "codex") -> str:
    workspace = Path(tempfile.mkdtemp(prefix="skill-description-improve-"))
    result = run_codex_exec(
        prompt,
        workspace=workspace,
        model=model,
        timeout=timeout,
        codex_bin=codex_bin,
    )
    if result.returncode != 0:
        raise RuntimeError(f"codex exec exited {result.returncode}\nstderr: {result.stderr}\n{result.final_text}")
    return result.final_text


def _extract_description(text: str) -> str:
    match = re.search(r"<new_description>(.*?)</new_description>", text, re.DOTALL)
    return (match.group(1) if match else text).strip().strip('"')


def improve_description(
    skill_name: str,
    skill_content: str,
    current_description: str,
    eval_results: dict,
    history: list[dict],
    model: str,
    test_results: dict | None = None,
    log_dir: Path | None = None,
    iteration: int | None = None,
    codex_bin: str = "codex",
) -> str:
    failed_triggers = [r for r in eval_results["results"] if r["should_trigger"] and not r["pass"]]
    false_triggers = [r for r in eval_results["results"] if not r["should_trigger"] and not r["pass"]]

    train_score = f"{eval_results['summary']['passed']}/{eval_results['summary']['total']}"
    if test_results:
        test_score = f"{test_results['summary']['passed']}/{test_results['summary']['total']}"
        scores_summary = f"Train: {train_score}, Test: {test_score}"
    else:
        scores_summary = f"Train: {train_score}"

    prompt = f"""You are optimizing a Codex skill description for a skill called "{skill_name}".

A Codex skill has a name and description that help Codex decide whether to read the skill. If Codex uses the skill, it reads SKILL.md and any referenced scripts, references, or assets. Your goal is to write a description that triggers for relevant user intents and avoids near-miss irrelevant tasks.

Current description:
<current_description>
{current_description}
</current_description>

Current scores ({scores_summary}):
"""
    if failed_triggers:
        prompt += "FAILED TO TRIGGER (should have triggered but did not):\n"
        for r in failed_triggers:
            prompt += f'  - "{r["query"]}" (triggered {r["triggers"]}/{r["runs"]} times)\n'
        prompt += "\n"

    if false_triggers:
        prompt += "FALSE TRIGGERS (triggered but should not have):\n"
        for r in false_triggers:
            prompt += f'  - "{r["query"]}" (triggered {r["triggers"]}/{r["runs"]} times)\n'
        prompt += "\n"

    if history:
        prompt += "PREVIOUS ATTEMPTS (do not repeat these; try a structurally different wording):\n\n"
        for h in history:
            train_s = f"{h.get('train_passed', h.get('passed', 0))}/{h.get('train_total', h.get('total', 0))}"
            test_s = f"{h.get('test_passed', '?')}/{h.get('test_total', '?')}" if h.get("test_passed") is not None else None
            score_str = f"train={train_s}" + (f", test={test_s}" if test_s else "")
            prompt += f'<attempt {score_str}>\nDescription: "{h["description"]}"\n'
            for r in h.get("results", []):
                status = "PASS" if r["pass"] else "FAIL"
                prompt += f'  [{status}] "{r["query"][:80]}" (triggered {r["triggers"]}/{r["runs"]})\n'
            prompt += "</attempt>\n\n"

    prompt += f"""Skill content:
<skill_content>
{skill_content}
</skill_content>

Write a new description that generalizes from the failures without overfitting to individual queries. Keep it comfortably under the 1024-character hard limit. Focus on user intent and contexts where this skill is useful, not implementation details. Make it distinctive enough to compete with other Codex skills.

Respond with only the new description text in <new_description> tags."""

    text = _call_codex(prompt, model, codex_bin=codex_bin)
    description = _extract_description(text)

    transcript: dict = {
        "iteration": iteration,
        "prompt": prompt,
        "response": text,
        "parsed_description": description,
        "char_count": len(description),
        "over_limit": len(description) > 1024,
    }

    if len(description) > 1024:
        shorten_prompt = (
            f"{prompt}\n\nA previous attempt produced this over-limit description "
            f"({len(description)} characters):\n\n{description}\n\n"
            "Rewrite it under 1024 characters. Respond only in <new_description> tags."
        )
        shorten_text = _call_codex(shorten_prompt, model, codex_bin=codex_bin)
        description = _extract_description(shorten_text)
        transcript["rewrite_response"] = shorten_text
        transcript["rewrite_description"] = description
        transcript["rewrite_char_count"] = len(description)

    transcript["final_description"] = description
    if log_dir:
        log_dir.mkdir(parents=True, exist_ok=True)
        (log_dir / f"improve_iter_{iteration or 'unknown'}.json").write_text(json.dumps(transcript, indent=2))
    return description


def main():
    parser = argparse.ArgumentParser(description="Improve a Codex skill description based on eval results")
    parser.add_argument("--eval-results", required=True, help="Path to eval results JSON from run_eval.py")
    parser.add_argument("--skill-path", required=True, help="Path to skill directory")
    parser.add_argument("--history", default=None, help="Path to history JSON")
    parser.add_argument("--model", required=True, help="Model for Codex improvement")
    parser.add_argument("--codex-bin", default="codex", help="Codex CLI executable")
    parser.add_argument("--verbose", action="store_true", help="Print progress to stderr")
    args = parser.parse_args()

    skill_path = Path(args.skill_path)
    if not (skill_path / "SKILL.md").exists():
        print(f"Error: No SKILL.md found at {skill_path}", file=sys.stderr)
        sys.exit(1)

    eval_results = json.loads(Path(args.eval_results).read_text())
    history = json.loads(Path(args.history).read_text()) if args.history else []
    name, _, content = parse_skill_md(skill_path)
    current_description = eval_results["description"]

    new_description = improve_description(
        skill_name=name,
        skill_content=content,
        current_description=current_description,
        eval_results=eval_results,
        history=history,
        model=args.model,
        codex_bin=args.codex_bin,
    )
    if args.verbose:
        print(f"Improved: {new_description}", file=sys.stderr)
    print(
        json.dumps(
            {
                "description": new_description,
                "history": history
                + [
                    {
                        "description": current_description,
                        "passed": eval_results["summary"]["passed"],
                        "failed": eval_results["summary"]["failed"],
                        "total": eval_results["summary"]["total"],
                        "results": eval_results["results"],
                    }
                ],
            },
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
