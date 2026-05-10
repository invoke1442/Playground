#!/usr/bin/env python3
"""Shared Codex CLI subprocess runner for skill-creator scripts."""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any


def json_dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


@dataclass
class CodexExecResult:
    returncode: int
    stdout: str
    stderr: str
    events: list[dict[str, Any]]
    final_text: str
    command: list[str]
    raw_events_path: Path | None = None


def build_codex_exec_command(
    workspace: Path,
    *,
    codex_bin: str = "codex",
    model: str | None = None,
    profile: str | None = None,
    sandbox: str = "read-only",
    approval: str = "never",
    output_schema: Path | None = None,
    output_last_message: Path | None = None,
) -> list[str]:
    cmd = [
        codex_bin,
        "-a",
        approval,
        "exec",
        "--json",
        "--ephemeral",
        "--sandbox",
        sandbox,
        "--skip-git-repo-check",
        "-C",
        str(workspace),
    ]
    if model:
        cmd.extend(["--model", model])
    if profile:
        cmd.extend(["--profile", profile])
    if output_schema:
        cmd.extend(["--output-schema", str(output_schema)])
    if output_last_message:
        cmd.extend(["--output-last-message", str(output_last_message)])
    return cmd


def default_codex_env(base_env: dict[str, str] | None = None, work_root: Path | None = None) -> dict[str, str]:
    env = dict(base_env or os.environ)
    if work_root is None:
        work_root = Path(tempfile.mkdtemp(prefix="skill-creator-codex-"))
    work_root.mkdir(parents=True, exist_ok=True)
    for name in ("TMPDIR", "XDG_CACHE_HOME", "XDG_RUNTIME_DIR"):
        path = work_root / name.lower()
        path.mkdir(parents=True, exist_ok=True)
        env[name] = str(path)
    env.setdefault("CODEX_HOME", str(Path.home() / ".codex"))
    return env


def parse_jsonl(stdout: str) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            events.append(item)
    return events


def _collect_text(value: Any) -> list[str]:
    texts: list[str] = []
    if isinstance(value, str):
        texts.append(value)
    elif isinstance(value, list):
        for item in value:
            texts.extend(_collect_text(item))
    elif isinstance(value, dict):
        for key in ("text", "content", "message", "output"):
            if key in value:
                texts.extend(_collect_text(value[key]))
    return texts


def extract_final_text(events: list[dict[str, Any]], stdout: str = "") -> str:
    for event in reversed(events):
        event_type = str(event.get("type", ""))
        if event_type in {"agent_message", "assistant_message", "message", "result"}:
            text = "\n".join(part for part in _collect_text(event) if part.strip()).strip()
            if text:
                return text
    if events:
        text = "\n".join(part for part in _collect_text(events[-1]) if part.strip()).strip()
        if text:
            return text
    return stdout.strip()


def diagnose_codex_failure(stderr: str, stdout: str = "") -> str:
    combined = f"{stderr}\n{stdout}"
    if "unexpected argument '-a'" in combined or "unexpected argument '--ask-for-approval'" in combined:
        return "Use Codex CLI approval syntax as a top-level option: 'codex -a never exec ...'."
    if "Read-only file system" in combined:
        return (
            "Codex CLI failed while writing runtime state. Set writable TMPDIR, "
            "XDG_CACHE_HOME, and XDG_RUNTIME_DIR or run through codex_runner.default_codex_env()."
        )
    return combined.strip()


def run_codex_exec(
    prompt: str,
    *,
    workspace: Path,
    model: str | None = None,
    profile: str | None = None,
    timeout: int = 300,
    codex_bin: str = "codex",
    sandbox: str = "read-only",
    approval: str = "never",
    env: dict[str, str] | None = None,
    raw_events_path: Path | None = None,
    output_schema: Path | None = None,
) -> CodexExecResult:
    workspace = Path(workspace).resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    cmd = build_codex_exec_command(
        workspace,
        codex_bin=codex_bin,
        model=model,
        profile=profile,
        sandbox=sandbox,
        approval=approval,
        output_schema=output_schema,
    )
    run_env = default_codex_env(env)
    completed = subprocess.run(
        cmd,
        input=prompt,
        text=True,
        capture_output=True,
        timeout=timeout,
        env=run_env,
    )
    events = parse_jsonl(completed.stdout)
    if raw_events_path:
        raw_events_path.parent.mkdir(parents=True, exist_ok=True)
        raw_events_path.write_text(completed.stdout)
    final_text = extract_final_text(events, completed.stdout)
    if completed.returncode != 0 and not final_text:
        final_text = diagnose_codex_failure(completed.stderr, completed.stdout)
    return CodexExecResult(
        returncode=completed.returncode,
        stdout=completed.stdout,
        stderr=completed.stderr,
        events=events,
        final_text=final_text,
        command=cmd,
        raw_events_path=raw_events_path,
    )
