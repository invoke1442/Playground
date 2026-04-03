#!/bin/bash
# ============================================================================
# Round 4: Roster-Centric Pattern Experiments
# Principle: Source/Sink/Sanitizer/Propagation core semantics in Roster,
#            Rule is only the entry point (type/subType + import)
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
  trap "rm -rf '$TMP'" RETURN

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

  echo "$RESP" > "$RESULTS_DIR/${label}.json"

  local CODE
  CODE=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('code','?'))" 2>/dev/null || echo "?")
  if [[ "$CODE" == "0" ]]; then
    local OUTPUT
    OUTPUT=$(echo "$RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); o=d.get('data',{}).get('output',''); print(o)" 2>/dev/null || echo "")
    if [[ "$OUTPUT" == "[]" || "$OUTPUT" == "" ]]; then
      echo "✅ $label — PASSED"
    else
      echo "❌ $label — FAILED: $OUTPUT"
    fi
  else
    echo "❌ $label — API error code=$CODE"
  fi
}

# ============================================================================
# r01: Java — Rule with ONLY type/subType + import (no inline source/sink)
# Question: Can a Rule be purely an entry point?
# ============================================================================
echo "=== r01: Java Rule — import only, no inline definitions ==="
WS=$(mktemp -d); trap "rm -rf '$WS'" EXIT
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_ssrf_source_0.ros" << 'ROSEOF'
Roster Java_ssrf_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    sink.methodArg += {
        precise = true;
        value = "java.net.URL.<init>";
    };
}
ROSEOF

cat > "$WS/50001.rul" << 'RULEOF'
Rule SSRFEntry extends AbstractTaintRule {
    type = "SSRF";
    subType = "SSRFHook";
    import roster Java_ssrf_source;
}
RULEOF

verify "r01-java-rule-import-only" "java" "rule" "50001" "$WS"
rm -rf "$WS"

# ============================================================================
# r02: Java — Roster with source + sink + sanitizer (comprehensive)
# Question: Can a Roster hold ALL taint semantics?
# ============================================================================
echo "=== r02: Java Roster — source + sink + sanitizer ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_ssrf_full_0.ros" << 'ROSEOF'
Roster Java_ssrf_full {
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
    sink.methodArg += {
        precise = true;
        value = "java.net.HttpURLConnection.openConnection";
    };
    sanitizer.methodReturn += {
        value = "org.apache.commons.validator.routines.UrlValidator.isValid";
    };
}
ROSEOF

verify "r02-java-roster-full-semantics" "java" "roster" "Java_ssrf_full_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r03: Java — Multi-roster import in Rule (source roster + sink roster)
# Question: Can a Rule import multiple rosters?
# ============================================================================
echo "=== r03: Java Rule — multi-roster import ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_common_source_0.ros" << 'ROSEOF'
Roster Java_common_source {
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
        value = "java.sql.Statement.execute";
    };
    sanitizer.methodReturn += {
        value = "com.security.SQLFilter.escape";
    };
}
ROSEOF

cat > "$WS/50002.rul" << 'RULEOF'
Rule SQLiEntry extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
    import roster Java_common_source;
    import roster Java_sqli_sink;
}
RULEOF

verify "r03-java-rule-multi-roster" "java" "rule" "50002" "$WS"
rm -rf "$WS"

# ============================================================================
# r04: Java — Roster with propagate (taint propagation)
# Question: Does propagate.* work in Roster?
# ============================================================================
echo "=== r04: Java Roster — propagate field ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_propagate_roster_0.ros" << 'ROSEOF'
Roster Java_propagate_roster {
    propagate.methodReturn += {
        precise = true;
        value = "java.lang.String.concat";
    };
    propagate.methodReturn += {
        precise = true;
        value = "java.lang.StringBuilder.append";
    };
}
ROSEOF

verify "r04-java-roster-propagate" "java" "roster" "Java_propagate_roster_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r05: Java — Rule imports source roster + sink roster + propagate roster
# Question: Rule as pure entry importing 3 specialized rosters
# ============================================================================
echo "=== r05: Java Rule — three specialized rosters ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_web_source_0.ros" << 'ROSEOF'
Roster Java_web_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
}
ROSEOF

cat > "$WS/rosters/Java_cmdi_sink_0.ros" << 'ROSEOF'
Roster Java_cmdi_sink {
    sink.methodArg += {
        precise = true;
        value = "java.lang.Runtime.exec";
    };
}
ROSEOF

cat > "$WS/rosters/Java_cmdi_propagate_0.ros" << 'ROSEOF'
Roster Java_cmdi_propagate {
    propagate.methodReturn += {
        precise = true;
        value = "java.lang.String.concat";
    };
    sanitizer.methodReturn += {
        value = "com.security.CommandFilter.sanitize";
    };
}
ROSEOF

cat > "$WS/50003.rul" << 'RULEOF'
Rule CmdiEntry extends AbstractTaintRule {
    type = "CMDI";
    subType = "CMDInjection";
    import roster Java_web_source;
    import roster Java_cmdi_sink;
    import roster Java_cmdi_propagate;
}
RULEOF

verify "r05-java-rule-three-rosters" "java" "rule" "50003" "$WS"
rm -rf "$WS"

# ============================================================================
# r06: Java — Roster with group (platform-specific)
# Question: group in roster with source+sink+sanitizer
# ============================================================================
echo "=== r06: Java Roster — group with full semantics ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_xss_config_0.ros" << 'ROSEOF'
Roster Java_xss_config {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    sink.methodArg += {
        precise = true;
        value = "java.io.PrintWriter.write";
    };
    group SpringMVC {
        includePlatforms = "*";
        source.methodReturn += {
            precise = true;
            value = "org.springframework.web.bind.annotation.RequestParam";
        };
        sanitizer.methodReturn += {
            value = "org.springframework.web.util.HtmlUtils.htmlEscape";
        };
    };
}
ROSEOF

verify "r06-java-roster-group-full" "java" "roster" "Java_xss_config_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r07: Java — Roster with propagate + group containing propagate
# Question: Can group also have propagate?
# ============================================================================
echo "=== r07: Java Roster — propagate in group ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_prop_group_0.ros" << 'ROSEOF'
Roster Java_prop_group {
    propagate.methodReturn += {
        precise = true;
        value = "java.lang.String.concat";
    };
    group AllPlatforms {
        includePlatforms = "*";
        propagate.methodReturn += {
            precise = true;
            value = "java.lang.StringBuilder.append";
        };
    };
}
ROSEOF

verify "r07-java-roster-propagate-in-group" "java" "roster" "Java_prop_group_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r08: JS — Rule with ONLY type/subType + import (entry point only)
# ============================================================================
echo "=== r08: JS Rule — import only, no inline definitions ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_xss_full_0.ros" << 'ROSEOF'
Roster NodeJS_xss_full {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b|\\bres\\.write\\b/";
    };
    sanitizer.methodReturn += {
        pattern += "/\\bescapeHtml\\b|\\bsanitize\\b/";
    };
}
ROSEOF

cat > "$WS/60001.rul" << 'RULEOF'
Rule XssEntry_60001 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    import roster NodeJS_xss_full;
}
RULEOF

verify "r08-js-rule-import-only" "javascript" "rule" "60001" "$WS"
rm -rf "$WS"

# ============================================================================
# r09: JS — Multi-roster import in Rule
# ============================================================================
echo "=== r09: JS Rule — multi-roster import ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_common_source_0.ros" << 'ROSEOF'
Roster NodeJS_common_source {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b/";
    };
    source.expression += {
        value += "/ctx\\.request\\.body$/";
    };
}
ROSEOF

cat > "$WS/rosters/NodeJS_sqli_sink_0.ros" << 'ROSEOF'
Roster NodeJS_sqli_sink {
    sink.methodArg += {
        pattern += "/\\b(mysql|db|connection)\\.query$/";
        paramIndex = 0;
    };
    sanitizer.methodReturn += {
        pattern += "/\\bmysql\\.escape\\b/";
    };
}
ROSEOF

cat > "$WS/60002.rul" << 'RULEOF'
Rule SqliEntry_60002 extends AbstractTaintRule {
    type = "SqlInjection";
    subType = "SqliTs";
    import roster NodeJS_common_source;
    import roster NodeJS_sqli_sink;
}
RULEOF

verify "r09-js-rule-multi-roster" "javascript" "rule" "60002" "$WS"
rm -rf "$WS"

# ============================================================================
# r10: JS — Roster with group (platform-specific source)
# ============================================================================
echo "=== r10: JS Roster — group with source+sink ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_ssrf_config_0.ros" << 'ROSEOF'
Roster NodeJS_ssrf_config {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    sink.methodArg += {
        pattern += "/\\baxios\\b|\\bfetch\\b|\\brequest\\b/";
    };
    group express_handler {
        includePlatforms = "express";
        source.methodReturn += {
            value += "/\\breq\\.body\\b/";
        };
    };
    group koa_handler {
        includePlatforms = "koa";
        source.methodReturn += {
            value += "/\\bctx\\.request\\.body\\b/";
        };
    };
}
ROSEOF

verify "r10-js-roster-group-source-sink" "javascript" "roster" "NodeJS_ssrf_config_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r11: JS — Roster with taintTag in source+sink (tag correlation)
# ============================================================================
echo "=== r11: JS Roster — taintTag correlation ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_tagged_0.ros" << 'ROSEOF'
Roster NodeJS_tagged {
    source.expression += {
        taintTag = "sql_taint";
        value += "/ctx\\.sql$/";
    };
    source.expression += {
        taintTag = "cmd_taint";
        value += "/ctx\\.command$/";
    };
    sink.methodArg += {
        pattern += "/\\bdb\\.query$/";
        taintTag = "sql_taint";
        paramIndex = 0;
    };
    sink.methodArg += {
        pattern += "/\\bchild_process\\.exec$/";
        taintTag = "cmd_taint";
        paramIndex = 0;
    };
}
ROSEOF

verify "r11-js-roster-tainttag" "javascript" "roster" "NodeJS_tagged_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r12: Java — Roster with relation config
# Question: Does relation/config_roster_relation.json work?
# ============================================================================
echo "=== r12: Java Rule + Roster + relation config ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/relation"

cat > "$WS/rosters/Java_rel_source_0.ros" << 'ROSEOF'
Roster Java_rel_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
}
ROSEOF

cat > "$WS/50004.rul" << 'RULEOF'
Rule RelTest extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    import roster Java_rel_source;
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
RULEOF

cat > "$WS/relation/config_roster_relation.json" << 'JSONEOF'
{
    "50004": ["Java_rel_source_0"]
}
JSONEOF

verify "r12-java-rule-with-relation" "java" "rule" "50004" "$WS"
rm -rf "$WS"

# ============================================================================
# r13: Java — propagate in Rule (NOT roster) — for comparison
# ============================================================================
echo "=== r13: Java Rule — propagate directly in rule ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/50005.rul" << 'RULEOF'
Rule PropInRule extends AbstractTaintRule {
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

verify "r13-java-propagate-in-rule" "java" "rule" "50005" "$WS"
rm -rf "$WS"

# ============================================================================
# r14: Java — Roster-centric: SSRF complete example
# ============================================================================
echo "=== r14: Java SSRF complete — Roster-centric ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_ssrf_source_0.ros" << 'ROSEOF'
Roster Java_ssrf_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getHeader";
    };
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getQueryString";
    };
}
ROSEOF

cat > "$WS/rosters/Java_ssrf_sink_0.ros" << 'ROSEOF'
Roster Java_ssrf_sink {
    sink.methodArg += {
        precise = true;
        value = "java.net.URL.<init>";
    };
    sink.methodArg += {
        precise = true;
        value = "java.net.URI.create";
    };
    sink.methodArg += {
        precise = true;
        value = "org.apache.http.client.methods.HttpGet.<init>";
    };
    sink.methodArg += {
        precise = true;
        value = "org.apache.http.client.methods.HttpPost.<init>";
    };
    sanitizer.methodReturn += {
        value = "org.apache.commons.validator.routines.UrlValidator.isValid";
    };
    sanitizer.methodReturn += {
        value = "com.example.security.UrlWhitelist.check";
    };
}
ROSEOF

cat > "$WS/50006.rul" << 'RULEOF'
Rule SSRFRule extends AbstractTaintRule {
    type = "SSRF";
    subType = "SSRFHook";
    import roster Java_ssrf_source;
    import roster Java_ssrf_sink;
}
RULEOF

verify "r14-java-ssrf-roster-centric" "java" "rule" "50006" "$WS"
verify "r14a-java-ssrf-source-roster" "java" "roster" "Java_ssrf_source_0" "$WS"
verify "r14b-java-ssrf-sink-roster" "java" "roster" "Java_ssrf_sink_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r15: JS — SSRF complete — Roster-centric
# ============================================================================
echo "=== r15: JS SSRF complete — Roster-centric ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_ssrf_source_0.ros" << 'ROSEOF'
Roster NodeJS_ssrf_source {
    source.methodReturn += {
        value += "/\\breq\\.query\\b|\\breq\\.body\\b|\\breq\\.params\\b/";
    };
    group koa_handler {
        includePlatforms = "koa";
        source.methodReturn += {
            value += "/\\bctx\\.request\\.query\\b|\\bctx\\.request\\.body\\b/";
        };
    };
    group express_handler {
        includePlatforms = "express";
        source.methodReturn += {
            value += "/\\breq\\.headers\\b/";
        };
    };
}
ROSEOF

cat > "$WS/rosters/NodeJS_ssrf_sink_0.ros" << 'ROSEOF'
Roster NodeJS_ssrf_sink {
    sink.methodArg += {
        pattern += "/\\baxios\\.(get|post|put|delete|request)$/";
        paramIndex = 0;
    };
    sink.methodArg += {
        pattern += "/\\bfetch$/";
        paramIndex = 0;
    };
    sink.methodArg += {
        pattern += "/\\brequest\\.(get|post)$/";
        paramIndex = 0;
    };
    sanitizer.methodReturn += {
        pattern += "/\\burlValidator\\b|\\bisValidUrl\\b/";
    };
}
ROSEOF

cat > "$WS/60003.rul" << 'RULEOF'
Rule SsrfEntry_60003 extends AbstractTaintRule {
    type = "SSRF";
    subType = "SSRFTs";
    import roster NodeJS_ssrf_source;
    import roster NodeJS_ssrf_sink;
}
RULEOF

verify "r15-js-ssrf-roster-centric" "javascript" "rule" "60003" "$WS"
verify "r15a-js-ssrf-source-roster" "javascript" "roster" "NodeJS_ssrf_source_0" "$WS"
verify "r15b-js-ssrf-sink-roster" "javascript" "roster" "NodeJS_ssrf_sink_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r16: Java — sanitizer.methodArg in Roster (not just methodReturn)
# ============================================================================
echo "=== r16: Java Roster — sanitizer.methodArg ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_sanitizer_test_0.ros" << 'ROSEOF'
Roster Java_sanitizer_test {
    sanitizer.methodArg += {
        precise = true;
        value = "com.example.Encoder.encode";
    };
    sanitizer.methodReturn += {
        value = "com.example.Validator.validate";
    };
}
ROSEOF

verify "r16-java-roster-sanitizer-methodarg" "java" "roster" "Java_sanitizer_test_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r17: Java — Roster with loadclass
# ============================================================================
echo "=== r17: Java Roster — loadclass in roster ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters" "$WS/extend-file/rosters/Java_custom_0"

cat > "$WS/rosters/Java_custom_0.ros" << 'ROSEOF'
Roster Java_custom {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
    source.customSourceFunc = loadclass("Java_custom.CarrySource");
}
ROSEOF

cat > "$WS/extend-file/rosters/Java_custom_0/CarrySource.java" << 'JAVAEOF'
package com.example;
public class CarrySource {
    public static boolean isSource(Object node) {
        return false;
    }
}
JAVAEOF

verify "r17-java-roster-loadclass" "java" "roster" "Java_custom_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r18: Java — Empty Rule body (ONLY type + subType, no import)
# Question: Is this valid?
# ============================================================================
echo "=== r18: Java Rule — no source, no sink, no import ==="
WS=$(mktemp -d)

cat > "$WS/50007.rul" << 'RULEOF'
Rule EmptyRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
RULEOF

verify "r18-java-rule-empty-body" "java" "rule" "50007" "$WS"
rm -rf "$WS"

# ============================================================================
# r19: JS — Roster with paramDecorator + expression + methodReturn combined
# ============================================================================
echo "=== r19: JS Roster — all source types combined ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_multi_source_0.ros" << 'ROSEOF'
Roster NodeJS_multi_source {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    source.expression += {
        value += "/ctx\\.request\\.body$/";
        taintTag = "http_input";
    };
    source.paramDecorator += {
        value = "/@Query\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
}
ROSEOF

verify "r19-js-roster-multi-source-types" "javascript" "roster" "NodeJS_multi_source_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r20: Java — Rule with import at WRONG position (after sink) — negative test
# ============================================================================
echo "=== r20: Java Rule — import after sink (should fail) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_test_0.ros" << 'ROSEOF'
Roster Java_test {
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
}
ROSEOF

cat > "$WS/50008.rul" << 'RULEOF'
Rule BadImportPos extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
    import roster Java_test;
}
RULEOF

verify "r20-java-import-wrong-position" "java" "rule" "50008" "$WS"
rm -rf "$WS"

# ============================================================================
# r21: Java — Multiple imports order test
# Question: Can we have 3+ import statements?
# ============================================================================
echo "=== r21: Java Rule — three imports ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_src_0.ros" << 'ROSEOF'
Roster Java_src {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
}
ROSEOF

cat > "$WS/rosters/Java_snk_0.ros" << 'ROSEOF'
Roster Java_snk {
    sink.methodArg += {
        precise = true;
        value = "java.sql.Statement.executeQuery";
    };
}
ROSEOF

cat > "$WS/rosters/Java_san_0.ros" << 'ROSEOF'
Roster Java_san {
    sanitizer.methodReturn += {
        value = "com.example.Filter.clean";
    };
}
ROSEOF

cat > "$WS/50009.rul" << 'RULEOF'
Rule ThreeImports extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
    import roster Java_src;
    import roster Java_snk;
    import roster Java_san;
}
RULEOF

verify "r21-java-rule-three-imports" "java" "rule" "50009" "$WS"
rm -rf "$WS"

# ============================================================================
# r22: JS — Rule with import + inline override (hybrid)
# Question: Can rule add additional source/sink beyond imported ones?
# ============================================================================
echo "=== r22: JS Rule — import + inline override ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_base_0.ros" << 'ROSEOF'
Roster NodeJS_base {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
}
ROSEOF

cat > "$WS/60004.rul" << 'RULEOF'
Rule HybridRule_60004 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    import roster NodeJS_base;
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
}
RULEOF

verify "r22-js-rule-import-plus-inline" "javascript" "rule" "60004" "$WS"
rm -rf "$WS"

# ============================================================================
# r23: Java — Roster with precise=false (prefix matching)
# ============================================================================
echo "=== r23: Java Roster — prefix matching (precise=false) ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/Java_prefix_0.ros" << 'ROSEOF'
Roster Java_prefix {
    source.methodReturn += {
        precise = false;
        value = "javax.servlet.http.HttpServletRequest";
    };
    sink.methodArg += {
        precise = false;
        value = "java.sql.Statement";
    };
}
ROSEOF

verify "r23-java-roster-prefix-match" "java" "roster" "Java_prefix_0" "$WS"
rm -rf "$WS"

# ============================================================================
# r24: JS — sanitizer in Roster with pattern
# ============================================================================
echo "=== r24: JS Roster — sanitizer with pattern ==="
WS=$(mktemp -d)
mkdir -p "$WS/rosters"

cat > "$WS/rosters/NodeJS_san_test_0.ros" << 'ROSEOF'
Roster NodeJS_san_test {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    sanitizer.methodReturn += {
        pattern += "/\\bescapeHtml\\b|\\bDOMPurify\\.sanitize\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
}
ROSEOF

verify "r24-js-roster-sanitizer-pattern" "javascript" "roster" "NodeJS_san_test_0" "$WS"
rm -rf "$WS"

echo ""
echo "=============================================="
echo "All roster-centric experiments completed!"
echo "Results saved to: $RESULTS_DIR/"
echo "=============================================="
