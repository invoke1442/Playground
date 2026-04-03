#!/bin/bash
set -e

API="http://43.106.136.189:8081/api/v1/verify"
RESULTS_DIR="$(dirname "$0")/experiments/results"
mkdir -p "$RESULTS_DIR"

# Helper function: build multipart payload and POST
verify() {
  local lang="$1" vtype="$2" id_name="$3" id_val="$4" tar_path="$5" label="$6"
  local tmp=$(mktemp -d)
  
  (
    printf -- "--bound\r\n"
    printf "Content-Disposition: form-data; name=\"language\"\r\n\r\n"
    printf "%s\r\n" "$lang"
    printf -- "--bound\r\n"
    printf "Content-Disposition: form-data; name=\"verify_type\"\r\n\r\n"
    printf "%s\r\n" "$vtype"
    printf -- "--bound\r\n"
    printf "Content-Disposition: form-data; name=\"%s\"\r\n\r\n" "$id_name"
    printf "%s\r\n" "$id_val"
    printf -- "--bound\r\n"
    printf "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\"\r\n"
    printf "Content-Type: application/octet-stream\r\n\r\n"
    cat "$tar_path"
    printf "\r\n--bound--\r\n"
  ) > "$tmp/payload.bin"

  local resp
  resp=$(curl -s --noproxy "*" --http1.0 \
    -H "Content-Type: multipart/form-data; boundary=bound" \
    --data-binary "@$tmp/payload.bin" \
    "$API" 2>&1)
  
  echo "$resp" > "$RESULTS_DIR/${label}.json"
  echo "[$label] $(echo "$resp" | head -c 500)"
  rm -rf "$tmp"
}

# ===================================================================
# Experiment 1: Valid Java Rule (minimal)
# ===================================================================
echo "============================================"
echo "Exp 1: Valid minimal Java Rule"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30001.rul" << 'EOF'
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
}
EOF
tar -cf "$D/config.tar" -C "$D" 30001.rul rosters
verify "java" "rule" "rule_id" "30001" "$D/config.tar" "exp1-valid-java-rule"
rm -rf "$D"

# ===================================================================
# Experiment 2: Valid Java Roster (minimal)
# ===================================================================
echo ""
echo "============================================"
echo "Exp 2: Valid minimal Java Roster"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/rosters/Java_test_roster_0.ros" << 'EOF'
Roster Java_test_roster {
    sanitizer.methodReturn += {
        value = "com.example.Sanitizer.clean";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" rosters
verify "java" "roster" "roster_name" "Java_test_roster_0" "$D/config.tar" "exp2-valid-java-roster"
rm -rf "$D"

# ===================================================================
# Experiment 3: Valid Java Rule with import roster
# ===================================================================
echo ""
echo "============================================"
echo "Exp 3: Java Rule with import roster"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30002.rul" << 'EOF'
Rule SSRFRule extends AbstractTaintRule {
    type = "SSRF";
    subType = "SSRFHook";
    import roster Java_common_source;
    source.methodReturn += {
        precise = true;
        value = "com.example.HttpClient.getUrl";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.HttpClient.connect";
    };
}
EOF
cat > "$D/rosters/Java_common_source.ros" << 'EOF'
Roster Java_common_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 30002.rul rosters
verify "java" "rule" "rule_id" "30002" "$D/config.tar" "exp3-java-rule-with-roster"
rm -rf "$D"

# ===================================================================
# Experiment 4: Java Rule with group
# ===================================================================
echo ""
echo "============================================"
echo "Exp 4: Java Rule with group"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30003.rul" << 'EOF'
Rule GroupTestRule extends AbstractTaintRule {
    type = "SQLi";
    subType = "SQLInjection";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.getInput";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.DB.query";
    };
    group AllPlatforms {
        includePlatforms = "*";
        sanitizer.methodReturn += {
            value = "com.example.Sanitizer.escape";
        };
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 30003.rul rosters
verify "java" "rule" "rule_id" "30003" "$D/config.tar" "exp4-java-rule-with-group"
rm -rf "$D"

# ===================================================================
# Experiment 5: Java Rule with extend-file
# ===================================================================
echo ""
echo "============================================"
echo "Exp 5: Java Rule with extend-file (loadclass)"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters" "$D/extend-file/30004"
cat > "$D/30004.rul" << 'EOF'
Rule ExtendTestRule extends AbstractTaintRule {
    type = "Test";
    subType = "ExtendTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.getData";
    };
    sink.customSinkFunc = loadclass("ExtendTestRule.customSink_0");
}
EOF
cat > "$D/extend-file/30004/ExtendTestRule.java" << 'EOF'
import com.alipay.codequery.dal.mybatis.domain.*;
public class ExtendTestRule {
    public static boolean customSink_0(Object rule, Object node, Object context) {
        return false;
    }
}
EOF
tar -cf "$D/config.tar" -C "$D" 30004.rul rosters extend-file
verify "java" "rule" "rule_id" "30004" "$D/config.tar" "exp5-java-rule-extend-file"
rm -rf "$D"

# ===================================================================
# Experiment 6: Invalid Java Rule - bad field name
# ===================================================================
echo ""
echo "============================================"
echo "Exp 6: Invalid Java Rule - bad field name"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30005.rul" << 'EOF'
Rule BadFieldRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.nonExistentField += {
        value = "com.example.Source.method";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 30005.rul rosters
verify "java" "rule" "rule_id" "30005" "$D/config.tar" "exp6-invalid-java-bad-field"
rm -rf "$D"

# ===================================================================
# Experiment 7: Invalid Java Rule - parse error (syntax)
# ===================================================================
echo ""
echo "============================================"
echo "Exp 7: Invalid Java Rule - syntax error"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30006.rul" << 'EOF'
Rule SyntaxErrorRule extends AbstractTaintRule {
    type = "Test"
    subType = "TestRule";
}
EOF
tar -cf "$D/config.tar" -C "$D" 30006.rul rosters
verify "java" "rule" "rule_id" "30006" "$D/config.tar" "exp7-invalid-java-syntax-error"
rm -rf "$D"

# ===================================================================
# Experiment 8: Invalid - missing rule_id parameter
# ===================================================================
echo ""
echo "============================================"
echo "Exp 8: Missing rule_id parameter"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30007.rul" << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
EOF
tar -cf "$D/config.tar" -C "$D" 30007.rul rosters
# Deliberately use roster_name instead of rule_id
TMP=$(mktemp -d)
(
  printf -- "--bound\r\n"
  printf "Content-Disposition: form-data; name=\"language\"\r\n\r\n"
  printf "java\r\n"
  printf -- "--bound\r\n"
  printf "Content-Disposition: form-data; name=\"verify_type\"\r\n\r\n"
  printf "rule\r\n"
  printf -- "--bound\r\n"
  printf "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\"\r\n"
  printf "Content-Type: application/octet-stream\r\n\r\n"
  cat "$D/config.tar"
  printf "\r\n--bound--\r\n"
) > "$TMP/payload.bin"
RESP=$(curl -s --noproxy "*" --http1.0 -H "Content-Type: multipart/form-data; boundary=bound" --data-binary "@$TMP/payload.bin" "$API")
echo "$RESP" > "$RESULTS_DIR/exp8-missing-rule-id.json"
echo "[exp8-missing-rule-id] $RESP"
rm -rf "$D" "$TMP"

# ===================================================================
# Experiment 9: Invalid language value
# ===================================================================
echo ""
echo "============================================"
echo "Exp 9: Invalid language value"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30008.rul" << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
EOF
tar -cf "$D/config.tar" -C "$D" 30008.rul rosters
verify "python" "rule" "rule_id" "30008" "$D/config.tar" "exp9-invalid-language"
rm -rf "$D"

# ===================================================================
# Experiment 10: Valid JS Rule (minimal)
# ===================================================================
echo ""
echo "============================================"
echo "Exp 10: Valid minimal JS Rule"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/6991.rul" << 'EOF'
Rule XssTs_6991 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        precise = false;
        value = "\\b(this|ctx|app)\\.getQuery\\b|\\breq\\.query\\b";
    };
    sink.methodArg += {
        precise = false;
        value = "\\bres\\.send\\b|\\bres\\.write\\b";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 6991.rul rosters
verify "javascript" "rule" "rule_id" "6991" "$D/config.tar" "exp10-valid-js-rule"
rm -rf "$D"

# ===================================================================
# Experiment 11: Valid JS Roster (minimal)
# ===================================================================
echo ""
echo "============================================"
echo "Exp 11: Valid minimal JS Roster"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/rosters/NodeJS_backend_test_source_0.ros" << 'EOF'
Roster NodeJS_backend_test_source {
    source.methodReturn += {
        precise = false;
        value = "\\breq\\.query\\b";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" rosters
verify "javascript" "roster" "roster_name" "NodeJS_backend_test_source_0" "$D/config.tar" "exp11-valid-js-roster"
rm -rf "$D"

# ===================================================================
# Experiment 12: Java Roster with group
# ===================================================================
echo ""
echo "============================================"
echo "Exp 12: Java Roster with group"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/rosters/Java_propagate_test_0.ros" << 'EOF'
Roster Java_propagate_test {
    sanitizer.methodReturn += {
        value = "com.example.SecurityUtil.escape";
    };
    group AllPlatforms {
        includePlatforms = "*";
        excludePlatforms = "legacy";
        sanitizer.methodReturn += {
            value = "com.example.Sanitizer.sanitize";
        };
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" rosters
verify "java" "roster" "roster_name" "Java_propagate_test_0" "$D/config.tar" "exp12-java-roster-with-group"
rm -rf "$D"

# ===================================================================
# Experiment 13: Filename mismatch - rule_id vs filename
# ===================================================================
echo ""
echo "============================================"
echo "Exp 13: Filename mismatch (rule_id=99999, file=30001.rul)"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30001.rul" << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.method";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 30001.rul rosters
verify "java" "rule" "rule_id" "99999" "$D/config.tar" "exp13-filename-mismatch"
rm -rf "$D"

# ===================================================================
# Experiment 14: Java Rule - source only (no sink)
# ===================================================================
echo ""
echo "============================================"
echo "Exp 14: Java Rule - source only, no sink"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30009.rul" << 'EOF'
Rule SourceOnlyRule extends AbstractTaintRule {
    type = "Test";
    subType = "SourceOnly";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.method";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 30009.rul rosters
verify "java" "rule" "rule_id" "30009" "$D/config.tar" "exp14-java-source-only"
rm -rf "$D"

# ===================================================================
# Experiment 15: Java Rule - missing required fields (no type/subType)
# ===================================================================
echo ""
echo "============================================"
echo "Exp 15: Java Rule - missing type/subType"
echo "============================================"
D=$(mktemp -d)
mkdir -p "$D/rosters"
cat > "$D/30010.rul" << 'EOF'
Rule NoTypeRule extends AbstractTaintRule {
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.method";
    };
}
EOF
tar -cf "$D/config.tar" -C "$D" 30010.rul rosters
verify "java" "rule" "rule_id" "30010" "$D/config.tar" "exp15-java-missing-type"
rm -rf "$D"

# ===================================================================
# Summary
# ===================================================================
echo ""
echo "============================================"
echo "All experiments complete. Results in $RESULTS_DIR/"
echo "============================================"
ls -la "$RESULTS_DIR/"
