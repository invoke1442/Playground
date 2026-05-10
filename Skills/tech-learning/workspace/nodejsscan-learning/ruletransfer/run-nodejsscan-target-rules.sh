#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run-nodejsscan-target-rules.sh \
    --target-rule /path/to/target_rule \
    --output-dir /path/to/out \
    [--format json|sarif|sonarqube] \
    [--config /path/to/.njsscan] \
    [--missing-controls] \
    [--exit-warning] \
    [--summary-json /path/to/summary.json] \
    <scan_path_1> [scan_path_2 ...]

Required environment variables:
  nodejsscan_BIN   Path to the local nodejsscan wrapper binary
  nodejsscan_REPO  Path to the local njsscan source repository

Optional environment variables:
  nodejsscan_PYTHON_BIN   Python interpreter that can import njsscan/libsast
  nodejsscan_PYTHONPATH   Extra import paths for njsscan/libsast, separated by ':'
  nodejsscan_SEMGREP_BIN  Explicit semgrep executable to use

Notes:
  - This script is for custom target_rule execution. It does not install dependencies.
  - target_rule contract:
      target_rule/
        semantic_grep/translated_rule.yaml
        pattern_matcher/translated_rule.yaml
        missing_controls.yaml
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 2
}

sanitize_name() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

nodejsscan_BIN="${nodejsscan_BIN:-}"
nodejsscan_REPO="${nodejsscan_REPO:-}"
nodejsscan_PYTHONPATH="${nodejsscan_PYTHONPATH:-}"
nodejsscan_SEMGREP_BIN="${nodejsscan_SEMGREP_BIN:-}"
PYTHON_BIN="${nodejsscan_PYTHON_BIN:-${PYTHON_BIN:-python3}}"

[[ -n "$nodejsscan_BIN" ]] || die 'nodejsscan_BIN is required'
[[ -n "$nodejsscan_REPO" ]] || die 'nodejsscan_REPO is required'
[[ -x "$nodejsscan_BIN" ]] || die "nodejsscan_BIN is not executable: $nodejsscan_BIN"
[[ -d "$nodejsscan_REPO" ]] || die "nodejsscan_REPO is not a directory: $nodejsscan_REPO"

TARGET_RULE_DIR=
OUTPUT_DIR=
FORMAT=json
CONFIG_FILE=
MISSING_CONTROLS=0
EXIT_WARNING=0
SUMMARY_JSON=
SCAN_PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target-rule)
      TARGET_RULE_DIR="${2:?missing value for --target-rule}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?missing value for --output-dir}"
      shift 2
      ;;
    --format)
      FORMAT="${2:?missing value for --format}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:?missing value for --config}"
      shift 2
      ;;
    --missing-controls)
      MISSING_CONTROLS=1
      shift
      ;;
    --exit-warning)
      EXIT_WARNING=1
      shift
      ;;
    --summary-json)
      SUMMARY_JSON="${2:?missing value for --summary-json}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        SCAN_PATHS+=("$1")
        shift
      done
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      SCAN_PATHS+=("$1")
      shift
      ;;
  esac
done

[[ -n "$TARGET_RULE_DIR" ]] || die '--target-rule is required'
[[ -n "$OUTPUT_DIR" ]] || die '--output-dir is required'
[[ -d "$TARGET_RULE_DIR" ]] || die "target_rule directory not found: $TARGET_RULE_DIR"
[[ "${#SCAN_PATHS[@]}" -gt 0 ]] || die 'at least one scan path is required'

case "$FORMAT" in
  json) OUTPUT_EXT=json ;;
  sarif) OUTPUT_EXT=sarif ;;
  sonarqube) OUTPUT_EXT=json ;;
  *) die "unsupported --format: $FORMAT" ;;
esac

TOOLS_DIR="$(cd "$(dirname "$nodejsscan_BIN")" && pwd)"
DEFAULT_SITE_PACKAGES="$TOOLS_DIR/nodejsscan-py"
if [[ -z "$nodejsscan_PYTHONPATH" && -d "$DEFAULT_SITE_PACKAGES" ]]; then
  nodejsscan_PYTHONPATH="$DEFAULT_SITE_PACKAGES"
fi
if [[ -z "$nodejsscan_SEMGREP_BIN" ]]; then
  if [[ -x "$DEFAULT_SITE_PACKAGES/bin/semgrep" ]]; then
    nodejsscan_SEMGREP_BIN="$DEFAULT_SITE_PACKAGES/bin/semgrep"
  elif command -v semgrep >/dev/null 2>&1; then
    nodejsscan_SEMGREP_BIN="$(command -v semgrep)"
  fi
fi
[[ -n "$nodejsscan_SEMGREP_BIN" ]] || die 'could not locate semgrep; set nodejsscan_SEMGREP_BIN explicitly'
[[ -x "$nodejsscan_SEMGREP_BIN" ]] || die "nodejsscan_SEMGREP_BIN is not executable: $nodejsscan_SEMGREP_BIN"

mkdir -p "$OUTPUT_DIR"
SUMMARY_JSON="${SUMMARY_JSON:-$OUTPUT_DIR/run-summary.json}"
SUMMARY_TSV="$OUTPUT_DIR/.run-summary.tsv"
RUNTIME_BASE="$OUTPUT_DIR/.runtime"
rm -f "$SUMMARY_TSV"
mkdir -p "$RUNTIME_BASE"

overall=0
index=0

for scan_path in "${SCAN_PATHS[@]}"; do
  [[ -e "$scan_path" ]] || die "scan path not found: $scan_path"
  index=$((index + 1))
  scan_abs="$(realpath "$scan_path")"
  slug="$(sanitize_name "$scan_abs")"
  [[ -n "$slug" ]] || slug="scan_${index}"
  outfile="$OUTPUT_DIR/$(printf '%03d' "$index")__${slug}.${OUTPUT_EXT}"
  runtime_dir="$(mktemp -d "$RUNTIME_BASE/nodejsscan.XXXXXX")"
  runtime_home="$runtime_dir/home"
  shim_dir="$runtime_dir/bin"
  mkdir -p "$runtime_home/.semgrep"
  mkdir -p "$shim_dir"
  cat > "$shim_dir/semgrep" <<EOF
#!/usr/bin/env bash
set -euo pipefail
export HOME="$runtime_home"
export PYTHONPATH="$nodejsscan_PYTHONPATH\${PYTHONPATH:+:\$PYTHONPATH}"
exec "$nodejsscan_SEMGREP_BIN" "\$@"
EOF
  chmod +x "$shim_dir/semgrep"

  set +e
  TARGET_RULE_DIR="$TARGET_RULE_DIR" \
  SCAN_PATH="$scan_abs" \
  OUTFILE="$outfile" \
  FORMAT="$FORMAT" \
  CONFIG_FILE="$CONFIG_FILE" \
  MISSING_CONTROLS="$MISSING_CONTROLS" \
  EXIT_WARNING="$EXIT_WARNING" \
  NODEJSSCAN_REPO="$nodejsscan_REPO" \
  NODEJSSCAN_PYTHONPATH="$nodejsscan_PYTHONPATH" \
  NODEJSSCAN_SHIM_DIR="$shim_dir" \
  NODEJSSCAN_HOME="$runtime_home" \
  "$PYTHON_BIN" - <<'PY'
import os
import sys
from pathlib import Path

repo = os.environ['NODEJSSCAN_REPO']
pythonpath = os.environ.get('NODEJSSCAN_PYTHONPATH', '')
shim_dir = os.environ['NODEJSSCAN_SHIM_DIR']
home = os.environ['NODEJSSCAN_HOME']
target_rule_dir = Path(os.environ['TARGET_RULE_DIR'])
scan_path = os.environ['SCAN_PATH']
outfile = os.environ['OUTFILE']
fmt = os.environ['FORMAT']
config_file = os.environ.get('CONFIG_FILE') or False
missing_controls_flag = os.environ.get('MISSING_CONTROLS') == '1'
exit_warning = os.environ.get('EXIT_WARNING') == '1'

os.environ['HOME'] = home
os.environ['PATH'] = shim_dir + os.pathsep + os.environ.get('PATH', '')

extra_paths = [p for p in pythonpath.split(os.pathsep) if p]
for path in extra_paths + [repo]:
    if path and path not in sys.path:
        sys.path.insert(0, path)

import yaml
try:
    import njsscan
    import njsscan.settings as settings
    from njsscan.njsscan import NJSScan
    from njsscan.formatters import json_out, sarif, sonarqube
    from libsast import Scanner
except ModuleNotFoundError as exc:
    print(
        'failed to import njsscan/libsast; set nodejsscan_PYTHONPATH or nodejsscan_PYTHON_BIN so the selected Python can import them',
        file=sys.stderr,
    )
    print(f'original import error: {exc}', file=sys.stderr)
    sys.exit(2)

semantic_dir = target_rule_dir / 'semantic_grep'
pattern_dir = target_rule_dir / 'pattern_matcher'
missing_controls_file = target_rule_dir / 'missing_controls.yaml'

has_semantic = semantic_dir.is_dir() and (
    any(semantic_dir.rglob('*.yml')) or any(semantic_dir.rglob('*.yaml'))
)
has_pattern = pattern_dir.is_dir() and (
    any(pattern_dir.rglob('*.yml')) or any(pattern_dir.rglob('*.yaml'))
)
has_controls = missing_controls_file.is_file()
missing_controls_flag = missing_controls_flag or has_controls

if not (has_semantic or has_pattern or has_controls):
    print('target_rule does not contain semantic_grep/, pattern_matcher/, or missing_controls.yaml', file=sys.stderr)
    sys.exit(2)

if has_controls:
    controls_doc = yaml.safe_load(missing_controls_file.read_text(encoding='utf-8')) or {}
    controls = controls_doc.get('controls', {})
    if not isinstance(controls, dict):
        print('missing_controls.yaml must define a top-level "controls" mapping', file=sys.stderr)
        sys.exit(2)
    settings.MISSING_CONTROLS = missing_controls_file
    if controls:
        settings.GOOD_CONTROLS_ID = set(controls.keys())

scanner = NJSScan([scan_path], True, missing_controls_flag, config_file)
scanner.options['sgrep_rules'] = semantic_dir.as_posix() if has_semantic else None
scanner.options['match_rules'] = pattern_dir.as_posix() if has_pattern else None
scanner.options['multiprocessing'] = 'thread'

raw_results = Scanner(scanner.options, scanner.paths).scan()
raw_results.setdefault('semantic_grep', {'matches': {}, 'errors': []})
raw_results.setdefault('pattern_matcher', {})
scanner.format_output(raw_results)
results = scanner.result

if fmt == 'json':
    json_out.json_output(outfile, results, njsscan.__version__)
elif fmt == 'sarif':
    sarif.sarif_output(outfile, results, njsscan.__version__)
elif fmt == 'sonarqube':
    sonarqube.sonarqube_output(outfile, results, njsscan.__version__)
else:
    print(f'unsupported format: {fmt}', file=sys.stderr)
    sys.exit(2)

if results.get('errors'):
    sys.exit(3)

combined = {}
if results.get('nodejs'):
    combined.update(results['nodejs'])
if results.get('templates'):
    combined.update(results['templates'])
for meta in combined.values():
    severity = meta['metadata']['severity']
    if severity == 'ERROR' or (severity == 'WARNING' and exit_warning):
        sys.exit(1)
sys.exit(0)
PY
  status=$?
  set -e

  printf '%s\t%s\t%s\t%s\n' "$scan_abs" "$outfile" "$FORMAT" "$status" >> "$SUMMARY_TSV"
  rm -rf "$runtime_dir"
  if [[ "$status" -ne 0 ]]; then
    overall=1
  fi
done

SUMMARY_TSV="$SUMMARY_TSV" SUMMARY_JSON="$SUMMARY_JSON" "$PYTHON_BIN" - <<'PY'
import json
import os
from pathlib import Path

summary_tsv = Path(os.environ['SUMMARY_TSV'])
summary_json = Path(os.environ['SUMMARY_JSON'])
records = []
if summary_tsv.exists():
    for line in summary_tsv.read_text(encoding='utf-8').splitlines():
        scan_path, outfile, fmt, status = line.split('\t')
        records.append({
            'scan_path': scan_path,
            'outfile': outfile,
            'format': fmt,
            'exit_code': int(status),
        })
summary_json.write_text(json.dumps({'runs': records}, indent=2, ensure_ascii=False), encoding='utf-8')
PY

exit "$overall"
