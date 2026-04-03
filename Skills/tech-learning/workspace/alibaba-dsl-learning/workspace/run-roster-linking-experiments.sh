#!/bin/bash
# ============================================================================
# Round 5: Roster Linking & Advanced Feature Experiments
# Key hypothesis: Rule↔Roster linking via relation/ dir, NOT import
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
# s01: Java — Rule + Roster linked via relation (Roster-centric, no import)
# ============================================================================
echo "=== s01: Java Rule + Roster via relation (no import) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_ssrf_core_0.ros" << 'ROSEOF'
Roster Java_ssrf_core {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getHeader";
    };
    sink.methodArg += {
        precise = true;
        value = "java.net.URL.<init>";
    };
    sanitizer.methodReturn += {
        value = "org.apache.commons.validator.routines.UrlValidator.isValid";
    };
}
ROSEOF

cat > "$WS/70001.rul" << 'RULEOF'
Rule SSRFEntry extends AbstractTaintRule {
    type = "SSRF";
    subType = "SSRFHook";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70001": ["Java_ssrf_core_0"]
}
JSONEOF

verify "s01-java-roster-centric-relation" "java" "rule" "70001" "$WS"
rm -rf "$WS"

# ============================================================================
# s02: Java — Rule + Roster via relation + Rule has minimal inline addition
# ============================================================================
echo "=== s02: Java Rule + Roster via relation + inline addition ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_web_source_0.ros" << 'ROSEOF'
Roster Java_web_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    sanitizer.methodReturn += {
        value = "com.example.SecurityUtil.escape";
    };
}
ROSEOF

cat > "$WS/70002.rul" << 'RULEOF'
Rule SQLiRule extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
    sink.methodArg += {
        precise = true;
        value = "java.sql.Statement.executeQuery";
    };
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70002": ["Java_web_source_0"]
}
JSONEOF

verify "s02-java-rule-relation-with-inline" "java" "rule" "70002" "$WS"
rm -rf "$WS"

# ============================================================================
# s03: Java — Rule + multiple Rosters via relation
# ============================================================================
echo "=== s03: Java Rule + multiple Rosters via relation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_source_0.ros" << 'ROSEOF'
Roster Java_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getHeader";
    };
}
ROSEOF

cat > "$WS/rosters/Java_sqli_sink_0.ros" << 'ROSEOF'
Roster Java_sqli_sink {
    sink.methodArg += {
        precise = true;
        value = "java.sql.Statement.executeQuery";
    };
    sink.methodArg += {
        precise = true;
        value = "java.sql.PreparedStatement.executeQuery";
    };
}
ROSEOF

cat > "$WS/rosters/Java_sanitizer_0.ros" << 'ROSEOF'
Roster Java_sanitizer {
    sanitizer.methodReturn += {
        value = "com.example.SQLFilter.escape";
    };
}
ROSEOF

cat > "$WS/70003.rul" << 'RULEOF'
Rule SQLiComplete extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70003": ["Java_source_0", "Java_sqli_sink_0", "Java_sanitizer_0"]
}
JSONEOF

verify "s03-java-multi-roster-relation" "java" "rule" "70003" "$WS"
rm -rf "$WS"

# ============================================================================
# s04: JS — Rule + Roster via relation (no import)
# ============================================================================
echo "=== s04: JS Rule + Roster via relation (no import) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/NodeJS_xss_core_0.ros" << 'ROSEOF'
Roster NodeJS_xss_core {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b|\\bres\\.write\\b/";
    };
    sanitizer.methodReturn += {
        pattern += "/\\bescapeHtml\\b/";
    };
}
ROSEOF

cat > "$WS/70004.rul" << 'RULEOF'
Rule XssEntry_70004 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70004": ["NodeJS_xss_core_0"]
}
JSONEOF

verify "s04-js-roster-centric-relation" "javascript" "rule" "70004" "$WS"
rm -rf "$WS"

# ============================================================================
# s05: JS — Rule + multiple Rosters via relation
# ============================================================================
echo "=== s05: JS Rule + multiple Rosters via relation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/NodeJS_common_src_0.ros" << 'ROSEOF'
Roster NodeJS_common_src {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/";
    };
    source.expression += {
        value += "/ctx\\.request\\.body$/";
    };
}
ROSEOF

cat > "$WS/rosters/NodeJS_sqli_sink_0.ros" << 'ROSEOF'
Roster NodeJS_sqli_sink {
    sink.methodArg += {
        pattern += "/\\b(mysql|db|connection|pool)\\.query$/";
        paramIndex = 0;
    };
}
ROSEOF

cat > "$WS/rosters/NodeJS_sqli_sanitizer_0.ros" << 'ROSEOF'
Roster NodeJS_sqli_sanitizer {
    sanitizer.methodReturn += {
        pattern += "/\\bmysql\\.escape\\b|\\bsqlstring\\.escape\\b/";
    };
}
ROSEOF

cat > "$WS/70005.rul" << 'RULEOF'
Rule SqliTs_70005 extends AbstractTaintRule {
    type = "SqlInjection";
    subType = "SqliTs";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70005": ["NodeJS_common_src_0", "NodeJS_sqli_sink_0", "NodeJS_sqli_sanitizer_0"]
}
JSONEOF

verify "s05-js-multi-roster-relation" "javascript" "rule" "70005" "$WS"
rm -rf "$WS"

# ============================================================================
# s06: Java — propagate in Rule (no roster, confirm it fails)
# ============================================================================
echo "=== s06: Java — propagate.methodReturn in Rule ==="
WS=$(mktemp -d)

cat > "$WS/70006.rul" << 'RULEOF'
Rule PropTest extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    propagate.methodReturn += {
        precise = true;
        value = "java.lang.String.concat";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
RULEOF

verify "s06-java-propagate-in-rule" "java" "rule" "70006" "$WS"
rm -rf "$WS"

# ============================================================================
# s07: Java — propagate in Roster (test again with correct format)
# Try different propagate field names
# ============================================================================
echo "=== s07: Java Roster — propagate fields exploration ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

# s07a: propagate.methodReturn
cat > "$WS/rosters/Java_prop_a_0.ros" << 'ROSEOF'
Roster Java_prop_a {
    propagate.methodReturn += {
        precise = true;
        value = "java.lang.String.concat";
    };
}
ROSEOF
verify "s07a-java-roster-propagate-methodReturn" "java" "roster" "Java_prop_a_0" "$WS"
rm -rf "$WS"

# s07b: propagate.methodArg
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_prop_b_0.ros" << 'ROSEOF'
Roster Java_prop_b {
    propagate.methodArg += {
        precise = true;
        value = "java.lang.StringBuilder.append";
    };
}
ROSEOF
verify "s07b-java-roster-propagate-methodArg" "java" "roster" "Java_prop_b_0" "$WS"
rm -rf "$WS"

# s07c: propagate with loadclass (customFunctionPropagate)
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_prop_c_0.ros" << 'ROSEOF'
Roster Java_prop_c {
    propagate.customFunctionPropagate = loadclass("Java_prop_c.PropChecker");
}
ROSEOF
verify "s07c-java-roster-propagate-loadclass" "java" "roster" "Java_prop_c_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s08: Java — sanitizer.methodArg vs sanitizer.functionArg
# ============================================================================
echo "=== s08: Java Roster — sanitizer field variants ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

# s08a: sanitizer.methodArg
cat > "$WS/rosters/Java_san_a_0.ros" << 'ROSEOF'
Roster Java_san_a {
    sanitizer.methodArg += {
        precise = true;
        value = "com.example.Encoder.encode";
    };
}
ROSEOF
verify "s08a-java-roster-sanitizer-methodArg" "java" "roster" "Java_san_a_0" "$WS"
rm -rf "$WS"

# s08b: sanitizer.functionArg
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_san_b_0.ros" << 'ROSEOF'
Roster Java_san_b {
    sanitizer.functionArg += {
        precise = true;
        value = "com.example.Validator.validate";
    };
}
ROSEOF
verify "s08b-java-roster-sanitizer-functionArg" "java" "roster" "Java_san_b_0" "$WS"
rm -rf "$WS"

# s08c: sanitizer.functionReturn
WS=$(mktemp -d)
mkdir -p "$WS/rosters"
cat > "$WS/rosters/Java_san_c_0.ros" << 'ROSEOF'
Roster Java_san_c {
    sanitizer.functionReturn += {
        value = "com.example.Sanitizer.clean";
    };
}
ROSEOF
verify "s08c-java-roster-sanitizer-functionReturn" "java" "roster" "Java_san_c_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s09: Java — sink.functionArg (from PDF)
# ============================================================================
echo "=== s09: Java Roster — sink.functionArg ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_sink_func_0.ros" << 'ROSEOF'
Roster Java_sink_func {
    sink.functionArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
    };
}
ROSEOF
verify "s09-java-roster-sink-functionArg" "java" "roster" "Java_sink_func_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s10: Java — source.param_annotation (from PDF)
# ============================================================================
echo "=== s10: Java Roster — source.param_annotation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_param_ann_0.ros" << 'ROSEOF'
Roster Java_param_ann {
    source.param_annotation += {
        precise = true;
        value = "org.springframework.web.bind.annotation.RequestParam";
    };
}
ROSEOF
verify "s10-java-roster-source-param-annotation" "java" "roster" "Java_param_ann_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s11: Java — source.method_annotation (from PDF)
# ============================================================================
echo "=== s11: Java Roster — source.method_annotation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_method_ann_0.ros" << 'ROSEOF'
Roster Java_method_ann {
    source.method_annotation += {
        precise = true;
        value = "org.springframework.web.bind.annotation.GetMapping";
    };
}
ROSEOF
verify "s11-java-roster-source-method-annotation" "java" "roster" "Java_method_ann_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s12: Java — const in Roster
# ============================================================================
echo "=== s12: Java Roster — const keyword ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_const_0.ros" << 'ROSEOF'
Roster Java_const {
    const SERVLET_SOURCE = "javax.servlet.http.HttpServletRequest.getParameter";
    source.methodReturn += {
        precise = true;
        value = SERVLET_SOURCE;
    };
}
ROSEOF
verify "s12-java-roster-const" "java" "roster" "Java_const_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s13: Java — Rule empty + Roster via relation + rosters dir exists
# ============================================================================
echo "=== s13: Java Rule empty body + relation to full roster ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_cmdi_full_0.ros" << 'ROSEOF'
Roster Java_cmdi_full {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    sink.methodArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
    };
    sanitizer.methodReturn += {
        value = "com.example.CommandFilter.sanitize";
    };
}
ROSEOF

cat > "$WS/70013.rul" << 'RULEOF'
Rule CmdiEntry extends AbstractTaintRule {
    type = "CMDI";
    subType = "CMDInjection";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70013": ["Java_cmdi_full_0"]
}
JSONEOF

verify "s13-java-entry-rule-full-roster-relation" "java" "rule" "70013" "$WS"
rm -rf "$WS"

# ============================================================================
# s14: JS — Roster with taintTag + Rule via relation
# ============================================================================
echo "=== s14: JS taintTag roster + rule via relation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/NodeJS_sqli_tagged_0.ros" << 'ROSEOF'
Roster NodeJS_sqli_tagged {
    source.expression += {
        taintTag = "taint_tag_sql";
        value += "/ctx\\.sql$/";
    };
    sink.methodArg += {
        pattern += "/\\b(mysql|db)\\.query$/";
        paramIndex = 0;
        taintTag = "taint_tag_sql";
    };
}
ROSEOF

cat > "$WS/70014.rul" << 'RULEOF'
Rule SqliTagged_70014 extends AbstractTaintRule {
    type = "SqlInjection";
    subType = "SqliTs";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70014": ["NodeJS_sqli_tagged_0"]
}
JSONEOF

verify "s14-js-tainttag-roster-relation" "javascript" "rule" "70014" "$WS"
rm -rf "$WS"

# ============================================================================
# s15: Java — source.method_param (xpath from PDF)
# ============================================================================
echo "=== s15: Java Roster — source.method_param (xpath) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_xpath_0.ros" << 'ROSEOF'
Roster Java_xpath {
    source.method_param += {
        precise = true;
        value = "com.example.Controller.handleRequest[0]";
    };
}
ROSEOF
verify "s15-java-roster-source-method-param" "java" "roster" "Java_xpath_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s16: Java — general.desc field
# ============================================================================
echo "=== s16: Java Rule — general.desc ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/70016.rul" << 'RULEOF'
Rule DescTest extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    general.desc = "This is a test rule description";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
RULEOF

verify "s16-java-rule-general-desc" "java" "rule" "70016" "$WS"
rm -rf "$WS"

# ============================================================================
# s17: JS — propagate in Roster
# ============================================================================
echo "=== s17: JS Roster — propagate ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_propagate_0.ros" << 'ROSEOF'
Roster NodeJS_propagate {
    propagate.methodReturn += {
        value += "/\\bJSON\\.stringify\\b/";
    };
}
ROSEOF
verify "s17-js-roster-propagate" "javascript" "roster" "NodeJS_propagate_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s18: JS — Roster with group containing sanitizer
# ============================================================================
echo "=== s18: JS Roster — group with sanitizer ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_xss_san_0.ros" << 'ROSEOF'
Roster NodeJS_xss_san {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
    group react_handler {
        includePlatforms = "*";
        sanitizer.methodReturn += {
            pattern += "/\\bescapeHtml\\b|\\bDOMPurify\\.sanitize\\b/";
        };
    };
}
ROSEOF
verify "s18-js-roster-group-sanitizer" "javascript" "roster" "NodeJS_xss_san_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s19: Java — Complete real-world XSS Rule (Roster-centric + relation)
# ============================================================================
echo "=== s19: Java XSS complete (Roster-centric + relation) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_xss_source_0.ros" << 'ROSEOF'
Roster Java_xss_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getHeader";
    };
    source.methodReturn += {
        precise = false;
        value = "javax.servlet.http.HttpServletRequest.get";
    };
}
ROSEOF

cat > "$WS/rosters/Java_xss_sink_0.ros" << 'ROSEOF'
Roster Java_xss_sink {
    sink.methodArg += {
        precise = true;
        value = "java.io.PrintWriter.write";
    };
    sink.methodArg += {
        precise = true;
        value = "java.io.PrintWriter.println";
    };
    sink.methodArg += {
        precise = true;
        value = "javax.servlet.http.HttpServletResponse.getWriter";
    };
    sanitizer.methodReturn += {
        value = "org.springframework.web.util.HtmlUtils.htmlEscape";
    };
    sanitizer.methodReturn += {
        value = "org.apache.commons.text.StringEscapeUtils.escapeHtml4";
    };
}
ROSEOF

cat > "$WS/70019.rul" << 'RULEOF'
Rule XssRule extends AbstractTaintRule {
    type = "Xss";
    subType = "XssHook";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70019": ["Java_xss_source_0", "Java_xss_sink_0"]
}
JSONEOF

verify "s19-java-xss-roster-centric" "java" "rule" "70019" "$WS"
verify "s19a-java-xss-source-roster" "java" "roster" "Java_xss_source_0" "$WS"
verify "s19b-java-xss-sink-roster" "java" "roster" "Java_xss_sink_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s20: JS — Complete real-world CMDI Rule (Roster-centric + relation)
# ============================================================================
echo "=== s20: JS CMDI complete (Roster-centric + relation) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/NodeJS_cmdi_source_0.ros" << 'ROSEOF'
Roster NodeJS_cmdi_source {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/";
    };
    source.expression += {
        value += "/ctx\\.request\\.(query|body)$/";
    };
    group koa_handler {
        includePlatforms = "koa";
        source.methodReturn += {
            value += "/\\bctx\\.request\\.body\\b/";
        };
    };
}
ROSEOF

cat > "$WS/rosters/NodeJS_cmdi_sink_0.ros" << 'ROSEOF'
Roster NodeJS_cmdi_sink {
    sink.methodArg += {
        pattern += "/\\bchild_process\\.(exec|execSync|spawn|fork)$/";
        paramIndex = 0;
    };
    sink.methodArg += {
        pattern += "/\\bexec\\b|\\bexecSync\\b/";
        paramIndex = 0;
    };
    sanitizer.methodReturn += {
        pattern += "/\\bshellEscape\\b|\\bescapeShellArg\\b/";
    };
}
ROSEOF

cat > "$WS/70020.rul" << 'RULEOF'
Rule CmdiEntry_70020 extends AbstractTaintRule {
    type = "CMDI";
    subType = "CMDInjectionTs";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70020": ["NodeJS_cmdi_source_0", "NodeJS_cmdi_sink_0"]
}
JSONEOF

verify "s20-js-cmdi-roster-centric" "javascript" "rule" "70020" "$WS"
verify "s20a-js-cmdi-source-roster" "javascript" "roster" "NodeJS_cmdi_source_0" "$WS"
verify "s20b-js-cmdi-sink-roster" "javascript" "roster" "NodeJS_cmdi_sink_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s21: Java — Roster with loadclass (correct path format)
# ============================================================================
echo "=== s21: Java Roster — loadclass with extend-file ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/extend-file/rosters/Java_custom_prop_0"

cat > "$WS/rosters/Java_custom_prop_0.ros" << 'ROSEOF'
Roster Java_custom_prop {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    sink.customSinkFunc = loadclass("Java_custom_prop.CustomSinkChecker");
}
ROSEOF

cat > "$WS/extend-file/rosters/Java_custom_prop_0/CustomSinkChecker.java" << 'JAVAEOF'
package com.example;
public class CustomSinkChecker {
    public static boolean isSink(Object node) {
        return false;
    }
}
JAVAEOF

verify "s21-java-roster-loadclass-sink" "java" "roster" "Java_custom_prop_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s22: JS — Roster with loadclass + extend-file
# ============================================================================
echo "=== s22: JS Roster — loadclass with extend-file ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/extend-file/rosters/NodeJS_custom_func_0"

cat > "$WS/rosters/NodeJS_custom_func_0.ros" << 'ROSEOF'
Roster NodeJS_custom_func {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    source.customSourceFunc = loadclass("NodeJS_custom_func.customSourceFunc_0");
}
ROSEOF

cat > "$WS/extend-file/rosters/NodeJS_custom_func_0/NodeJS_custom_func.js" << 'JSEOF'
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => {
    return false;
};
JSEOF

verify "s22-js-roster-loadclass-source" "javascript" "roster" "NodeJS_custom_func_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s23: Java PathTraversal — complete Roster-centric example
# ============================================================================
echo "=== s23: Java PathTraversal (Roster-centric + relation) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_pt_config_0.ros" << 'ROSEOF'
Roster Java_pt_config {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getPathInfo";
    };
    sink.methodArg += {
        precise = true;
        value = "java.io.File.<init>";
    };
    sink.methodArg += {
        precise = true;
        value = "java.io.FileInputStream.<init>";
    };
    sink.methodArg += {
        precise = true;
        value = "java.nio.file.Paths.get";
    };
    sanitizer.methodReturn += {
        value = "org.apache.commons.io.FilenameUtils.normalize";
    };
    group SpringBoot {
        includePlatforms = "*";
        sanitizer.methodReturn += {
            value = "org.springframework.util.StringUtils.cleanPath";
        };
    };
}
ROSEOF

cat > "$WS/70023.rul" << 'RULEOF'
Rule PathTraversalRule extends AbstractTaintRule {
    type = "PathTraversal";
    subType = "PathTraversalHook";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70023": ["Java_pt_config_0"]
}
JSONEOF

verify "s23-java-pathtraversal-roster-centric" "java" "rule" "70023" "$WS"
verify "s23a-java-pt-roster" "java" "roster" "Java_pt_config_0" "$WS"
rm -rf "$WS"

# ============================================================================
# s24: relation format — actual_use_config.json
# ============================================================================
echo "=== s24: Relation with actual_use_config.json ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_test_rel_0.ros" << 'ROSEOF'
Roster Java_test_rel {
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
ROSEOF

cat > "$WS/70024.rul" << 'RULEOF'
Rule RelConfigTest extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "70024": ["Java_test_rel_0"]
}
JSONEOF

cat > "$WS/relation/actual_use_config.json" << 'JSONEOF'
[70024]
JSONEOF

verify "s24-java-relation-with-actual-use" "java" "rule" "70024" "$WS"
rm -rf "$WS"

echo ""
echo "=============================================="
echo "All Round 5 experiments completed!"
echo "=============================================="
