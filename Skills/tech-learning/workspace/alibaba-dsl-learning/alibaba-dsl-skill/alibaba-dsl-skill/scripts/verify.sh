#!/bin/bash
# Alibaba DSL Rule/Roster verification script
# Usage:
#   bash verify.sh rule    java       <rule_id>     <config_dir>
#   bash verify.sh roster  java       <roster_name> <config_dir>
#   bash verify.sh rule    javascript <rule_id>     <config_dir>
#   bash verify.sh roster  javascript <roster_name> <config_dir>
#
# config_dir structure (Roster-centric):
#   config/
#   ├── {rule_id}.rul                   # Rule entry point
#   ├── rosters/                        # REQUIRED (even if empty)
#   │   └── {RosterName}_0.ros
#   └── relation/
#       └── config_roster_relation.json # {"rule_id": ["Roster_0"]}
#
# Examples:
#   bash verify.sh rule java 70001 ./my-config
#   bash verify.sh roster java Java_ssrf_config_0 ./my-config
#   bash verify.sh rule javascript 70004 ./js-config

set -euo pipefail

API="http://43.106.136.189:8081/api/v1/verify"

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <rule|roster> <java|javascript> <rule_id|roster_name> <config_dir>"
  exit 1
fi

VTYPE="$1"
LANG="$2"
ID_VAL="$3"
CONFIG_DIR="$4"

# Validate inputs
if [[ "$VTYPE" != "rule" && "$VTYPE" != "roster" ]]; then
  echo "Error: verify_type must be 'rule' or 'roster', got '$VTYPE'" >&2
  exit 1
fi
if [[ "$LANG" != "java" && "$LANG" != "javascript" ]]; then
  echo "Error: language must be 'java' or 'javascript', got '$LANG'" >&2
  exit 1
fi
if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "Error: config directory '$CONFIG_DIR' does not exist" >&2
  exit 1
fi

# Determine ID parameter name
if [[ "$VTYPE" == "rule" ]]; then
  ID_NAME="rule_id"
else
  ID_NAME="roster_name"
fi

# Create tar from config directory
TMP_DIR=$(mktemp -d)
trap "rm -rf '$TMP_DIR'" EXIT

COPYFILE_DISABLE=1 tar -cf "$TMP_DIR/config.tar" -C "$CONFIG_DIR" .

# Build multipart payload manually (avoids curl -F encoding issues)
(
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"language\""
  echo ""
  echo "$LANG"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"verify_type\""
  echo ""
  echo "$VTYPE"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"$ID_NAME\""
  echo ""
  echo "$ID_VAL"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\""
  echo "Content-Type: application/octet-stream"
  echo ""
  cat "$TMP_DIR/config.tar"
  echo ""
  echo "--bound--"
) > "$TMP_DIR/payload.bin"

# Send request
RESPONSE=$(curl -s --noproxy "*" --http1.0 \
  -H "Content-Type: multipart/form-data; boundary=bound" \
  --data-binary "@$TMP_DIR/payload.bin" \
  "$API" 2>/dev/null)

echo "$RESPONSE"

# Parse result
CODE=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code','?'))" 2>/dev/null || echo "?")
if [[ "$CODE" == "0" ]]; then
  OUTPUT=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('output',''))" 2>/dev/null || echo "")
  if [[ "$OUTPUT" == "[]" || "$OUTPUT" == "" ]]; then
    echo ""
    echo "✅ Verification PASSED"
  else
    echo ""
    echo "❌ Verification FAILED — errors found in output"
    echo "$OUTPUT" | python3 -m json.tool 2>/dev/null || echo "$OUTPUT"
  fi
else
  echo ""
  echo "❌ API error (code=$CODE)"
fi
