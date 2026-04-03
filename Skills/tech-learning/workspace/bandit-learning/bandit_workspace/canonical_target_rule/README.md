# Canonical Bandit target_rule validation bundle

This directory validates the no-script Bandit target_rule format.

Canonical properties:
- no shell entrypoint
- local installable plugin package via `pyproject.toml`
- bundle-local `bandit.yaml`
- plugin code under `src/`

Runtime contract:
- runner invokes Bandit directly with `-c bandit.yaml -r <scan_target> -f json -o <result.json>`
- this package must already be installed in the Bandit environment
