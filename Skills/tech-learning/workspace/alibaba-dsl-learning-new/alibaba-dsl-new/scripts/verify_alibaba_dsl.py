#!/usr/bin/env python3
"""Package and verify Alibaba DSL configs through the official verify API."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


DEFAULT_VERIFY_URL = "http://43.106.136.189:8081/api/v1/verify"
VERIFY_URL = os.environ.get("ALIBABA_DSL_VERIFY_URL", DEFAULT_VERIFY_URL)
BOUNDARY = "bound"


def create_config_tar(config_dir: str | Path, tar_path: str | Path) -> Path:
    config_dir = Path(config_dir).resolve()
    tar_path = Path(tar_path).resolve()
    tar_path.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(tar_path, "w") as archive:
        for path in sorted(config_dir.rglob("*")):
            archive.add(path, arcname=str(path.relative_to(config_dir)))
    return tar_path


def build_multipart_payload(
    tar_path: str | Path,
    payload_path: str | Path,
    *,
    language: str,
    verify_type: str,
    rule_id: str | None = None,
    roster_name: str | None = None,
) -> Path:
    tar_path = Path(tar_path).resolve()
    payload_path = Path(payload_path).resolve()
    fields = [("language", language), ("verify_type", verify_type)]
    if verify_type == "rule":
        if not rule_id:
            raise ValueError("rule_id is required for rule verification")
        fields.append(("rule_id", str(rule_id)))
    elif verify_type == "roster":
        if not roster_name:
            raise ValueError("roster_name is required for roster verification")
        fields.append(("roster_name", str(roster_name)))
    else:
        raise ValueError("verify_type must be `rule` or `roster`")

    with payload_path.open("wb") as handle:
        for name, value in fields:
            handle.write(f"--{BOUNDARY}\n".encode())
            handle.write(f'Content-Disposition: form-data; name="{name}"\n\n'.encode())
            handle.write(str(value).encode())
            handle.write(b"\n")
        handle.write(f"--{BOUNDARY}\n".encode())
        handle.write(b'Content-Disposition: form-data; name="file"; filename="config.tar"\n')
        handle.write(b"Content-Type: application/octet-stream\n\n")
        handle.write(tar_path.read_bytes())
        handle.write(b"\n")
        handle.write(f"--{BOUNDARY}--\n".encode())
    return payload_path


def call_verify_api(payload_path: str | Path, *, url: str = VERIFY_URL, timeout: int = 90) -> dict:
    payload_path = Path(payload_path).resolve()
    cmd = [
        "curl",
        "--silent",
        "--show-error",
        "--noproxy",
        "*",
        "--http1.0",
        "-H",
        f"Content-Type: multipart/form-data; boundary={BOUNDARY}",
        "--data-binary",
        f"@{payload_path}",
        url,
    ]
    try:
        completed = subprocess.run(cmd, text=True, capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as exc:
        return {
            "returncode": 124,
            "stdout": exc.stdout or "",
            "stderr": exc.stderr or f"verify API request timed out after {timeout} seconds",
            "command": cmd,
            "response": None,
            "verify_output": None,
            "error": "TIMEOUT",
        }
    result: dict = {
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
        "command": cmd,
    }
    try:
        parsed = json.loads(completed.stdout)
    except json.JSONDecodeError:
        parsed = None
    result["response"] = parsed
    if parsed and isinstance(parsed, dict):
        output = parsed.get("data", {}).get("output") if isinstance(parsed.get("data"), dict) else None
        if isinstance(output, str) and output.strip():
            try:
                result["verify_output"] = json.loads(output)
            except json.JSONDecodeError:
                result["verify_output"] = output
        else:
            result["verify_output"] = output
    return result


def verify_config(
    config_dir: str | Path,
    *,
    language: str,
    verify_type: str,
    rule_id: str | None = None,
    roster_name: str | None = None,
    url: str = VERIFY_URL,
    keep_artifacts: Path | None = None,
    timeout: int = 90,
) -> dict:
    with tempfile.TemporaryDirectory(prefix="alibaba-dsl-verify-") as tmp:
        tmp_dir = Path(tmp)
        if keep_artifacts:
            tmp_dir = Path(keep_artifacts).resolve()
            tmp_dir.mkdir(parents=True, exist_ok=True)
        tar_path = create_config_tar(config_dir, tmp_dir / "config.tar")
        payload_path = build_multipart_payload(
            tar_path,
            tmp_dir / "payload.bin",
            language=language,
            verify_type=verify_type,
            rule_id=rule_id,
            roster_name=roster_name,
        )
        result = call_verify_api(payload_path, url=url, timeout=timeout)
        result["tar_path"] = str(tar_path)
        result["payload_path"] = str(payload_path)
        if keep_artifacts:
            (Path(keep_artifacts) / "verify-result.json").write_text(
                json.dumps(result, ensure_ascii=False, indent=2),
                encoding="utf-8",
            )
        return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify Alibaba DSL config directories.")
    parser.add_argument("config_dir")
    parser.add_argument("--language", choices=["java", "javascript"], required=True)
    parser.add_argument("--verify-type", choices=["rule", "roster"], required=True)
    parser.add_argument("--rule-id")
    parser.add_argument("--roster-name")
    parser.add_argument("--url", default=VERIFY_URL)
    parser.add_argument("--keep-artifacts", type=Path)
    parser.add_argument("--timeout", type=int, default=90)
    args = parser.parse_args()

    result = verify_config(
        args.config_dir,
        language=args.language,
        verify_type=args.verify_type,
        rule_id=args.rule_id,
        roster_name=args.roster_name,
        url=args.url,
        keep_artifacts=args.keep_artifacts,
        timeout=args.timeout,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))
    response = result.get("response")
    if result["returncode"] != 0:
        return result["returncode"]
    if isinstance(response, dict) and response.get("code") != 0:
        return 1
    verify_output = result.get("verify_output")
    return 0 if verify_output in ("", [], None) else 2


if __name__ == "__main__":
    sys.exit(main())
