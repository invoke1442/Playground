#!/bin/bash
# Alibaba DSL comprehensive experiment runner
# Writes each result to experiments/results/

cd "$(dirname "$0")"
API="http://43.106.136.189:8081/api/v1/verify"
RD="experiments/results"
rm -rf "$RD"
mkdir -p "$RD"

verify() {
  local lang="$1" vtype="$2" id_name="$3" id_val="$4" tar_path="$5" label="$6"
  local tmp=$(mktemp -d)
  
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
    cat "$tar_path"
    echo ""
    echo "--bound--"
  ) > "$tmp/payload.bin"

  curl -s --noproxy "*" --http1.0 \
    -H "Content-Type: multipart/form-data; boundary=bound" \
    --data-binary "@$tmp/payload.bin" \
    "$API" > "$RD/${label}.json" 2>/dev/null
  
  echo "[$label] $(cat "$RD/${label}.json")"
  rm -rf "$tmp"
}

# No-id verify (missing rule_id/roster_name)
verify_no_id() {
  local lang="$1" vtype="$2" tar_path="$3" label="$4"
  local tmp=$(mktemp -d)
  
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
    echo "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\""
    echo "Content-Type: application/octet-stream"
    echo ""
    cat "$tar_path"
    echo ""
    echo "--bound--"
  ) > "$tmp/payload.bin"

  curl -s --noproxy "*" --http1.0 \
    -H "Content-Type: multipart/form-data; boundary=bound" \
    --data-binary "@$tmp/payload.bin" \
    "$API" > "$RD/${label}.json" 2>/dev/null
  
  echo "[$label] $(cat "$RD/${label}.json")"
  rm -rf "$tmp"
}

echo "=== Exp 1: Valid minimal Java Rule ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" 30001.rul rosters
verify "java" "rule" "rule_id" "30001" "$D/c.tar" "exp01-valid-java-rule"
rm -rf "$D"

echo "=== Exp 2: Valid minimal Java Roster ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/rosters/Java_test_roster_0.ros" << 'EOF'
Roster Java_test_roster {
    sanitizer.methodReturn += {
        value = "com.example.Sanitizer.clean";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters
verify "java" "roster" "roster_name" "Java_test_roster_0" "$D/c.tar" "exp02-valid-java-roster"
rm -rf "$D"

echo "=== Exp 3: Java Rule with import roster ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" 30002.rul rosters
verify "java" "rule" "rule_id" "30002" "$D/c.tar" "exp03-java-rule-import-roster"
rm -rf "$D"

echo "=== Exp 4: Java Rule with group ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" 30003.rul rosters
verify "java" "rule" "rule_id" "30003" "$D/c.tar" "exp04-java-rule-group"
rm -rf "$D"

echo "=== Exp 5: Java Rule with extend-file ==="
D=$(mktemp -d); mkdir -p "$D/rosters" "$D/extend-file/30004"
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
tar -cf "$D/c.tar" -C "$D" 30004.rul rosters extend-file
verify "java" "rule" "rule_id" "30004" "$D/c.tar" "exp05-java-rule-extend-file"
rm -rf "$D"

echo "=== Exp 6: INVALID - bad field name ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30005.rul" << 'EOF'
Rule BadFieldRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.nonExistentField += {
        value = "com.example.Source.method";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30005.rul rosters
verify "java" "rule" "rule_id" "30005" "$D/c.tar" "exp06-bad-field-name"
rm -rf "$D"

echo "=== Exp 7: INVALID - syntax error (missing semicolon) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30006.rul" << 'EOF'
Rule SyntaxErrorRule extends AbstractTaintRule {
    type = "Test"
    subType = "TestRule";
}
EOF
tar -cf "$D/c.tar" -C "$D" 30006.rul rosters
verify "java" "rule" "rule_id" "30006" "$D/c.tar" "exp07-syntax-error"
rm -rf "$D"

echo "=== Exp 8: INVALID - missing rule_id param ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30007.rul" << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
EOF
tar -cf "$D/c.tar" -C "$D" 30007.rul rosters
verify_no_id "java" "rule" "$D/c.tar" "exp08-missing-rule-id"
rm -rf "$D"

echo "=== Exp 9: INVALID - bad language ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30008.rul" << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
EOF
tar -cf "$D/c.tar" -C "$D" 30008.rul rosters
verify "python" "rule" "rule_id" "30008" "$D/c.tar" "exp09-bad-language"
rm -rf "$D"

echo "=== Exp 10: Valid minimal JS Rule ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" 6991.rul rosters
verify "javascript" "rule" "rule_id" "6991" "$D/c.tar" "exp10-valid-js-rule"
rm -rf "$D"

echo "=== Exp 11: Valid minimal JS Roster ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/rosters/NodeJS_backend_test_0.ros" << 'EOF'
Roster NodeJS_backend_test {
    source.methodReturn += {
        precise = false;
        value = "\\breq\\.query\\b";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters
verify "javascript" "roster" "roster_name" "NodeJS_backend_test_0" "$D/c.tar" "exp11-valid-js-roster"
rm -rf "$D"

echo "=== Exp 12: Java Roster with group ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" rosters
verify "java" "roster" "roster_name" "Java_propagate_test_0" "$D/c.tar" "exp12-java-roster-group"
rm -rf "$D"

echo "=== Exp 13: Filename mismatch (rule_id=99999, file=30001.rul) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" 30001.rul rosters
verify "java" "rule" "rule_id" "99999" "$D/c.tar" "exp13-filename-mismatch"
rm -rf "$D"

echo "=== Exp 14: Source only (no sink) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
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
tar -cf "$D/c.tar" -C "$D" 30009.rul rosters
verify "java" "rule" "rule_id" "30009" "$D/c.tar" "exp14-source-only"
rm -rf "$D"

echo "=== Exp 15: Missing type/subType ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30010.rul" << 'EOF'
Rule NoTypeRule extends AbstractTaintRule {
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.method";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30010.rul rosters
verify "java" "rule" "rule_id" "30010" "$D/c.tar" "exp15-missing-type"
rm -rf "$D"

echo "=== Exp 16: JS Rule with paramDecorator (XPath) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/7001.rul" << 'EOF'
Rule XssDecoratorRule extends AbstractTaintRule {
    type = "Xss";
    subType = "XssDecorator";
    source.paramDecorator += {
        value = "/@Query\\b/";
    };
    sink.methodArg += {
        precise = false;
        value = "\\bres\\.send\\b";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 7001.rul rosters
verify "javascript" "rule" "rule_id" "7001" "$D/c.tar" "exp16-js-param-decorator"
rm -rf "$D"

echo "=== Exp 17: JS Rule with taintTag and expression ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/7002.rul" << 'EOF'
Rule SqliTagRule extends AbstractTaintRule {
    type = "SqlInjection";
    subType = "SqliTs";
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
EOF
tar -cf "$D/c.tar" -C "$D" 7002.rul rosters
verify "javascript" "rule" "rule_id" "7002" "$D/c.tar" "exp17-js-tainttag-expression"
rm -rf "$D"

echo "=== Exp 18: Java Rule - value type error (int instead of string) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30011.rul" << 'EOF'
Rule TypeErrorRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
    source.methodReturn += {
        precise = true;
        value = 12345;
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30011.rul rosters
verify "java" "rule" "rule_id" "30011" "$D/c.tar" "exp18-value-type-error"
rm -rf "$D"

echo "=== Exp 19: Empty .rul file ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
touch "$D/30012.rul"
tar -cf "$D/c.tar" -C "$D" 30012.rul rosters
verify "java" "rule" "rule_id" "30012" "$D/c.tar" "exp19-empty-rul-file"
rm -rf "$D"

echo "=== Exp 20: JS Rule with loadclass + extend-file ==="
D=$(mktemp -d); mkdir -p "$D/rosters" "$D/extend-file/7003"
cat > "$D/7003.rul" << 'EOF'
Rule JsExtendRule extends AbstractTaintRule {
    type = "Custom";
    subType = "JsExtend";
    source.customSourceFunc = loadclass("NodeJS_custom.customSource_0");
    sink.methodArg += {
        precise = false;
        value = "\\bres\\.send\\b";
    };
}
EOF
cat > "$D/extend-file/7003/JsExtendRule.js" << 'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSource_0 = (rule, node, context) => {
    return false;
};
EOF
tar -cf "$D/c.tar" -C "$D" 7003.rul rosters extend-file
verify "javascript" "rule" "rule_id" "7003" "$D/c.tar" "exp20-js-rule-loadclass"
rm -rf "$D"

echo "=== Exp 21: Lexical error (random garbage) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30013.rul" << 'EOF'
@#$%^&*
not_a_rule {
  ???
}
EOF
tar -cf "$D/c.tar" -C "$D" 30013.rul rosters
verify "java" "rule" "rule_id" "30013" "$D/c.tar" "exp21-lexical-error"
rm -rf "$D"

echo "=== Exp 22: Java Roster with extend-file ==="
D=$(mktemp -d); mkdir -p "$D/rosters" "$D/extend-file/rosters/Java_custom_roster_0"
cat > "$D/rosters/Java_custom_roster_0.ros" << 'EOF'
Roster Java_custom_roster {
    source.customSourceFunc = loadclass("Java_custom_roster.CarrySource");
}
EOF
cat > "$D/extend-file/rosters/Java_custom_roster_0/CarrySource.java" << 'EOF'
public class CarrySource {
    public static boolean customSourceFunc(Object rule, Object node, Object context) {
        return false;
    }
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters extend-file
verify "java" "roster" "roster_name" "Java_custom_roster_0" "$D/c.tar" "exp22-java-roster-extend-file"
rm -rf "$D"

echo ""
echo "=== ALL EXPERIMENTS DONE ==="
echo ""
for f in "$RD"/*.json; do
  echo "$(basename "$f"): $(cat "$f")"
  echo ""
done
