#!/bin/bash
# ============================================================================
# Round 6: Edge cases & clarifications
# ============================================================================

set -euo pipefail
API="http://43.106.136.189:8081/api/v1/verify"
RESULTS_DIR="$(dirname "$0")/experiments/results"
mkdir -p "$RESULTS_DIR"

verify() {
  local label="$1" lang="$2" vtype="$3" id_val="$4" config_dir="$5"
  local id_name
  if [[ "$vtype" == "rule" ]]; then id_name="rule_id"; else id_name="roster_name"; fi
  local TMP=$(mktemp -d)
  COPYFILE_DISABLE=1 tar -cf "$TMP/config.tar" -C "$config_dir" .
  (
    echo "--bound"
    echo "Content-Disposition: form-data; name=\"language\""
    echo ""
    echo "$lang"
    echo "--bound"
    echo "Content-Disposition: form-data; name=\"verify_type\""
    echo ""
    echo "$vtype"
    echo "--bound"
    echo "Content-Disposition: form-data; name=\"$id_name\""
    echo ""
    echo "$id_val"
    echo "--bound"
    echo "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\""
    echo "Content-Type: application/octet-stream"
    echo ""
    cat "$TMP/config.tar"
    echo ""
    echo "--bound--"
  ) > "$TMP/payload.bin"
  local RESP
  RESP=$(curl -s --noproxy "*" --http1.0 \
    -H "Content-Type: multipart/form-data; boundary=bound" \
    --data-binary "@$TMP/payload.bin" \
    "$API" 2>/dev/null)
  rm -rf "$TMP"
  echo "$RESP" > "$RESULTS_DIR/${label}.json"
  local CODE
  CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code','?'))" 2>/dev/null || echo "?")
  if [[ "$CODE" == "0" ]]; then
    local OUTPUT
    OUTPUT=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); o=d.get('data',{}).get('output',''); print(o)" 2>/dev/null || echo "")
    if [[ "$OUTPUT" == "[]" || "$OUTPUT" == "" ]]; then
      echo "✅ $label — PASSED"
    else
      echo "❌ $label — FAILED: $(echo "$OUTPUT" | head -c 200)"
    fi
  else
    echo "❌ $label — API error code=$CODE"
  fi
}

# ============================================================================
# t01: Java — import BEFORE type/subType (official doc JS example pattern)
# ============================================================================
echo "=== t01: Java import BEFORE type/subType ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_t_0.ros" << 'ROSEOF'
Roster Java_t {
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
}
ROSEOF
cat > "$WS/80001.rul" << 'RULEOF'
Rule ImportFirst extends AbstractTaintRule {
    import roster Java_t;
    type = "Test";
    subType = "TestRule";
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}
RULEOF
verify "t01-java-import-before-type" "java" "rule" "80001" "$WS"
rm -rf "$WS"

# ============================================================================
# t02: JS — import BEFORE type/subType (matching official doc pattern)
# ============================================================================
echo "=== t02: JS import BEFORE type/subType ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/NodeJS_t_0.ros" << 'ROSEOF'
Roster NodeJS_t {
    source.methodReturn += { value += "/\\breq\\.query\\b/"; };
}
ROSEOF
cat > "$WS/80002.rul" << 'RULEOF'
Rule ImportFirst_80002 extends AbstractTaintRule {
    import roster NodeJS_t;
    type = "Xss";
    subType = "XssTs";
    sink.methodArg += { pattern += "/\\bres\\.send\\b/"; };
}
RULEOF
verify "t02-js-import-before-type" "javascript" "rule" "80002" "$WS"
rm -rf "$WS"

# ============================================================================
# t03: Java — import as VERY first line + source after
# ============================================================================
echo "=== t03: Java import first + source/sink inline ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_t3_0.ros" << 'ROSEOF'
Roster Java_t3 {
    sanitizer.methodReturn += { value = "com.example.Sanitizer.clean"; };
}
ROSEOF
cat > "$WS/80003.rul" << 'RULEOF'
Rule ImportTest3 extends AbstractTaintRule {
    import roster Java_t3;
    type = "Test";
    subType = "TestRule";
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}
RULEOF
verify "t03-java-import-first-inline" "java" "rule" "80003" "$WS"
rm -rf "$WS"

# ============================================================================
# t04: Java — import exactly matching official doc demo format
# Exact pattern: type, subType, source, sink, import at end
# ============================================================================
echo "=== t04: Java import at END (official doc example) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_common_source_0.ros" << 'ROSEOF'
Roster Java_common_source {
    source.methodReturn += { precise = true; value = "javax.servlet.http.HttpServletRequest.getParameter"; };
}
ROSEOF
cat > "$WS/80004.rul" << 'RULEOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.method";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.method";
    };
    import roster Java_common_source;
    import roster Java_cmdi_propagate;
}
RULEOF
verify "t04-java-import-at-end" "java" "rule" "80004" "$WS"
rm -rf "$WS"

# ============================================================================
# t05: Java loadclass source.customSourceFunc in Roster
# ============================================================================
echo "=== t05: Java Roster — loadclass source.customSourceFunc ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/extend-file/rosters/Java_custom_src_0"
cat > "$WS/rosters/Java_custom_src_0.ros" << 'ROSEOF'
Roster Java_custom_src {
    source.customSourceFunc = loadclass("Java_custom_src.CarrySource");
}
ROSEOF
cat > "$WS/extend-file/rosters/Java_custom_src_0/CarrySource.java" << 'JAVAEOF'
package com.example;
public class CarrySource {
    public static boolean isSource(Object node) { return false; }
}
JAVAEOF
verify "t05-java-roster-loadclass-source" "java" "roster" "Java_custom_src_0" "$WS"
rm -rf "$WS"

# ============================================================================
# t06: Java loadclass in Rule (not roster) — for comparison
# ============================================================================
echo "=== t06: Java Rule — loadclass sink.customSinkFunc ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/extend-file/80006"
cat > "$WS/80006.rul" << 'RULEOF'
Rule LoadclassRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.customSinkFunc = loadclass("LoadclassRule.CustomChecker");
}
RULEOF
cat > "$WS/extend-file/80006/CustomChecker.java" << 'JAVAEOF'
package com.example;
public class CustomChecker {
    public static boolean isSink(Object node) { return false; }
}
JAVAEOF
verify "t06-java-rule-loadclass-sink" "java" "rule" "80006" "$WS"
rm -rf "$WS"

# ============================================================================
# t07: Java — Rule with rosters/ dir but no .ros files (empty dir)
# Question: Does Rule verify pass with empty rosters/ dir?
# ============================================================================
echo "=== t07: Java Rule — empty rosters dir ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/80007.rul" << 'RULEOF'
Rule EmptyRoster extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}
RULEOF
verify "t07-java-rule-empty-rosters-dir" "java" "rule" "80007" "$WS"
rm -rf "$WS"

# ============================================================================
# t08: Java Rule — NO rosters/ dir at all
# ============================================================================
echo "=== t08: Java Rule — no rosters dir ==="
WS=$(mktemp -d)
cat > "$WS/80008.rul" << 'RULEOF'
Rule NoRosterDir extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += { precise = true; value = "com.example.Source.get"; };
    sink.methodArg += { precise = true; value = "com.example.Sink.exec"; };
}
RULEOF
verify "t08-java-rule-no-rosters-dir" "java" "rule" "80008" "$WS"
rm -rf "$WS"

# ============================================================================
# t09: Java Deserialization — Roster-centric + relation
# ============================================================================
echo "=== t09: Java Deserialization (Roster-centric) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"
cat > "$WS/rosters/Java_deser_config_0.ros" << 'ROSEOF'
Roster Java_deser_config {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getInputStream";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getReader";
    };
    sink.methodArg += {
        precise = true;
        value = "java.io.ObjectInputStream.readObject";
    };
    sink.methodArg += {
        precise = true;
        value = "com.alibaba.fastjson.JSON.parseObject";
    };
    sink.methodArg += {
        precise = true;
        value = "com.fasterxml.jackson.databind.ObjectMapper.readValue";
    };
    sanitizer.methodReturn += {
        value = "com.example.security.DeserializeFilter.check";
    };
}
ROSEOF
cat > "$WS/80009.rul" << 'RULEOF'
Rule DeserRule extends AbstractTaintRule {
    type = "Deserialization";
    subType = "DeserializationHook";
}
RULEOF
cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "80009": ["Java_deser_config_0"]
}
JSONEOF
verify "t09-java-deser-roster-centric" "java" "rule" "80009" "$WS"
rm -rf "$WS"

# ============================================================================
# t10: JS XXE — Roster-centric + relation
# ============================================================================
echo "=== t10: JS PathTraversal (Roster-centric) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"
cat > "$WS/rosters/NodeJS_pt_config_0.ros" << 'ROSEOF'
Roster NodeJS_pt_config {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bfs\\.(readFile|readFileSync|writeFile|createReadStream)$/";
        paramIndex = 0;
    };
    sink.methodArg += {
        pattern += "/\\bpath\\.join$/";
        paramIndex = 0;
    };
    sanitizer.methodReturn += {
        pattern += "/\\bpath\\.normalize\\b|\\bpath\\.resolve\\b/";
    };
}
ROSEOF
cat > "$WS/80010.rul" << 'RULEOF'
Rule PathTravTs_80010 extends AbstractTaintRule {
    type = "PathTraversal";
    subType = "PathTraversalTs";
}
RULEOF
cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "80010": ["NodeJS_pt_config_0"]
}
JSONEOF
verify "t10-js-pathtraversal-roster-centric" "javascript" "rule" "80010" "$WS"
rm -rf "$WS"

# ============================================================================
# t11: Java — define/delete/modifiable in Rule with Roster via relation
# ============================================================================
echo "=== t11: Java Rule — define/modifiable with relation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"
cat > "$WS/rosters/Java_modif_0.ros" << 'ROSEOF'
Roster Java_modif {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    sink.methodArg += {
        precise = true;
        value = "java.sql.Statement.executeQuery";
    };
}
ROSEOF
cat > "$WS/80011.rul" << 'RULEOF'
Rule ModifRule extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
    define extraSource = "com.example.ExtraSource.getData";
    source.methodReturn += {
        precise = true;
        value = extraSource;
    };
}
RULEOF
cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "80011": ["Java_modif_0"]
}
JSONEOF
verify "t11-java-define-with-relation" "java" "rule" "80011" "$WS"
rm -rf "$WS"

# ============================================================================
# t12: Java — Same roster shared by multiple rules
# ============================================================================
echo "=== t12: Java — shared roster across rules ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"
cat > "$WS/rosters/Java_common_0.ros" << 'ROSEOF'
Roster Java_common {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
}
ROSEOF
cat > "$WS/80012.rul" << 'RULEOF'
Rule Rule1 extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
    sink.methodArg += { precise = true; value = "java.sql.Statement.executeQuery"; };
}
RULEOF
cat > "$WS/80013.rul" << 'RULEOF'
Rule Rule2 extends AbstractTaintRule {
    type = "CMDI";
    subType = "CMDInjection";
    sink.methodArg += { precise = true; value = "java.lang.Runtime.exec"; };
}
RULEOF
cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "80012": ["Java_common_0"],
    "80013": ["Java_common_0"]
}
JSONEOF
verify "t12a-java-shared-roster-rule1" "java" "rule" "80012" "$WS"
verify "t12b-java-shared-roster-rule2" "java" "rule" "80013" "$WS"
rm -rf "$WS"

echo ""
echo "=============================================="
echo "All Round 6 experiments completed!"
echo "=============================================="
