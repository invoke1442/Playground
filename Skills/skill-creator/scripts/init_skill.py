#!/usr/bin/env python3
"""Initialize a new Codex skill from a template."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    from scripts.generate_openai_yaml import write_openai_yaml
except ModuleNotFoundError:
    from generate_openai_yaml import write_openai_yaml


MAX_SKILL_NAME_LENGTH = 64
ALLOWED_RESOURCES = {"scripts", "references", "assets"}

SKILL_TEMPLATE = """---
name: {skill_name}
description: [TODO: Complete and informative explanation of what the skill does and when to use it. Include specific scenarios, file types, or tasks that should trigger it.]
---

# {skill_title}

## Overview

[TODO: 1-2 sentences explaining what this Codex skill enables.]

## Workflow

[TODO: Describe the steps Codex should follow. Keep instructions concise and task-oriented.]

## Resources

[TODO: Reference any bundled scripts, references, or assets only when they are actually useful.]
"""

EXAMPLE_SCRIPT = '''#!/usr/bin/env python3
"""Example helper script for {skill_name}."""


def main():
    print("This is an example script for {skill_name}")


if __name__ == "__main__":
    main()
'''

EXAMPLE_REFERENCE = """# Reference Documentation for {skill_title}

Replace this placeholder with detailed reference material, or delete it if not needed.
"""

EXAMPLE_ASSET = """# Example Asset File

Replace this placeholder with templates, images, fonts, or other assets used in final outputs.
"""


def normalize_skill_name(skill_name):
    normalized = skill_name.strip().lower()
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized)
    normalized = normalized.strip("-")
    normalized = re.sub(r"-{2,}", "-", normalized)
    return normalized


def title_case_skill_name(skill_name):
    return " ".join(word.capitalize() for word in skill_name.split("-"))


def parse_resources(raw_resources):
    if not raw_resources:
        return []
    resources = [item.strip() for item in raw_resources.split(",") if item.strip()]
    invalid = sorted({item for item in resources if item not in ALLOWED_RESOURCES})
    if invalid:
        allowed = ", ".join(sorted(ALLOWED_RESOURCES))
        print(f"[ERROR] Unknown resource type(s): {', '.join(invalid)}")
        print(f"   Allowed: {allowed}")
        sys.exit(1)
    deduped = []
    seen = set()
    for resource in resources:
        if resource not in seen:
            deduped.append(resource)
            seen.add(resource)
    return deduped


def create_resource_dirs(skill_dir, skill_name, skill_title, resources, include_examples):
    for resource in resources:
        resource_dir = skill_dir / resource
        resource_dir.mkdir(exist_ok=True)
        if resource == "scripts":
            if include_examples:
                example_script = resource_dir / "example.py"
                example_script.write_text(EXAMPLE_SCRIPT.format(skill_name=skill_name))
                example_script.chmod(0o755)
                print("[OK] Created scripts/example.py")
            else:
                print("[OK] Created scripts/")
        elif resource == "references":
            if include_examples:
                example_reference = resource_dir / "api_reference.md"
                example_reference.write_text(EXAMPLE_REFERENCE.format(skill_title=skill_title))
                print("[OK] Created references/api_reference.md")
            else:
                print("[OK] Created references/")
        elif resource == "assets":
            if include_examples:
                example_asset = resource_dir / "example_asset.txt"
                example_asset.write_text(EXAMPLE_ASSET)
                print("[OK] Created assets/example_asset.txt")
            else:
                print("[OK] Created assets/")


def init_skill(skill_name, path, resources, include_examples, interface_overrides):
    skill_name = normalize_skill_name(skill_name)
    if not skill_name:
        print("[ERROR] Skill name must include at least one letter or digit.")
        return None
    if len(skill_name) > MAX_SKILL_NAME_LENGTH:
        print(
            f"[ERROR] Skill name '{skill_name}' is too long ({len(skill_name)} characters). "
            f"Maximum is {MAX_SKILL_NAME_LENGTH} characters."
        )
        return None

    skill_dir = Path(path).resolve() / skill_name
    if skill_dir.exists():
        print(f"[ERROR] Skill directory already exists: {skill_dir}")
        return None
    try:
        skill_dir.mkdir(parents=True, exist_ok=False)
        print(f"[OK] Created skill directory: {skill_dir}")
    except Exception as e:
        print(f"[ERROR] Error creating directory: {e}")
        return None

    skill_title = title_case_skill_name(skill_name)
    try:
        (skill_dir / "SKILL.md").write_text(SKILL_TEMPLATE.format(skill_name=skill_name, skill_title=skill_title))
        print("[OK] Created SKILL.md")
        if not write_openai_yaml(skill_dir, skill_name, interface_overrides):
            return None
        if resources:
            create_resource_dirs(skill_dir, skill_name, skill_title, resources, include_examples)
    except Exception as e:
        print(f"[ERROR] Error initializing skill: {e}")
        return None

    print(f"\n[OK] Skill '{skill_name}' initialized successfully at {skill_dir}")
    return skill_dir


def main():
    parser = argparse.ArgumentParser(description="Create a new Codex skill directory.")
    parser.add_argument("skill_name", help="Skill name (normalized to hyphen-case)")
    parser.add_argument("--path", required=True, help="Output directory for the skill")
    parser.add_argument("--resources", default="", help="Comma-separated list: scripts,references,assets")
    parser.add_argument("--examples", action="store_true", help="Create example files in resource directories")
    parser.add_argument(
        "--interface",
        action="append",
        default=[],
        help="Interface override in key=value format (repeatable)",
    )
    args = parser.parse_args()

    skill_name = normalize_skill_name(args.skill_name)
    if skill_name != args.skill_name:
        print(f"Note: Normalized skill name from '{args.skill_name}' to '{skill_name}'.")
    resources = parse_resources(args.resources)
    if args.examples and not resources:
        print("[ERROR] --examples requires --resources to be set.")
        sys.exit(1)
    result = init_skill(skill_name, args.path, resources, args.examples, args.interface)
    sys.exit(0 if result else 1)


if __name__ == "__main__":
    main()
