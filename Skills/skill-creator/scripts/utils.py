"""Shared utilities for skill-creator scripts."""

from pathlib import Path
from typing import Any


def parse_simple_frontmatter(frontmatter_text: str) -> dict[str, Any]:
    """Parse the small YAML subset used by skill frontmatter.

    This intentionally avoids importing PyYAML. Some Codex environments have a
    broken libyaml extension; frontmatter validation should still work there.
    """
    result: dict[str, Any] = {}
    lines = frontmatter_text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        if not raw.strip() or raw.lstrip().startswith("#"):
            i += 1
            continue
        if raw.startswith((" ", "\t")):
            raise ValueError(f"Unexpected indented frontmatter line: {raw}")
        if ":" not in raw:
            raise ValueError(f"Invalid frontmatter line: {raw}")
        key, value = raw.split(":", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            raise ValueError("Frontmatter key cannot be empty")
        if value in (">", "|", ">-", "|-"):
            continuation: list[str] = []
            i += 1
            while i < len(lines) and (lines[i].startswith("  ") or lines[i].startswith("\t")):
                continuation.append(lines[i].strip())
                i += 1
            result[key] = "\n".join(continuation) if value.startswith("|") else " ".join(continuation)
            continue
        result[key] = value.strip('"').strip("'")
        i += 1
    return result


def split_skill_md(content: str) -> tuple[str, str]:
    lines = content.split("\n")
    if not lines or lines[0].strip() != "---":
        raise ValueError("SKILL.md missing frontmatter (no opening ---)")
    for i, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return "\n".join(lines[1:i]), "\n".join(lines[i + 1 :])
    raise ValueError("SKILL.md missing frontmatter (no closing ---)")


def parse_skill_md(skill_path: Path) -> tuple[str, str, str]:
    """Parse a SKILL.md file, returning (name, description, full_content)."""
    content = (skill_path / "SKILL.md").read_text()
    frontmatter_text, _ = split_skill_md(content)
    frontmatter = parse_simple_frontmatter(frontmatter_text)
    return str(frontmatter.get("name", "")), str(frontmatter.get("description", "")), content
