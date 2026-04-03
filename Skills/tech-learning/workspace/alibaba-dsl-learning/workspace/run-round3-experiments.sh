#!/bin/bash
# Round 3: targeted experiments
cd "$(dirname "$0")"
API="http://43.106.136.189:8081/api/v1/verify"
RD="experiments/results"
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

# G1: JS Roster with group
echo "=== G1: JS Roster with group ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/rosters/NodeJS_group_test_0.ros" << 'EOF'
Roster NodeJS_group_test {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    group cocktail_handler {
        includePlatforms = "cocktail";
        source.methodReturn += {
            value += "/\\bctx\\.getQuery\\b/";
        };
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters
verify "javascript" "roster" "roster_name" "NodeJS_group_test_0" "$D/c.tar" "g01-js-roster-group"
rm -rf "$D"

# G2: JS Rule - does sink.methodArg need both value and pattern? 
# Test: value only + pattern only individually
echo "=== G2: JS sink.methodArg - value only ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/7020.rul" << 'EOF'
Rule JsSinkValueOnly extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    sink.methodArg += {
        value += "/\\bres\\.send\\b/";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 7020.rul rosters
verify "javascript" "rule" "rule_id" "7020" "$D/c.tar" "g02-js-sink-value-only"
rm -rf "$D"

# G3: JS sink.methodArg - pattern only
echo "=== G3: JS sink.methodArg - pattern only ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/7021.rul" << 'EOF'
Rule JsSinkPatternOnly extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 7021.rul rosters
verify "javascript" "rule" "rule_id" "7021" "$D/c.tar" "g03-js-sink-pattern-only"
rm -rf "$D"

# G4: Java - what fields does source support? Test methodArg
echo "=== G4: Java source.methodArg ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30030.rul" << 'EOF'
Rule SourceMethodArgRule extends AbstractTaintRule {
    type = "Test";
    subType = "MethodArgTest";
    source.methodArg += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30030.rul rosters
verify "java" "rule" "rule_id" "30030" "$D/c.tar" "g04-java-source-methodarg"
rm -rf "$D"

# G5: Java - sanitizer in rule (not roster)
echo "=== G5: Java sanitizer in rule ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30031.rul" << 'EOF'
Rule SanitizerInRuleTest extends AbstractTaintRule {
    type = "Test";
    subType = "SanitizerTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
    sanitizer.methodReturn += {
        value = "com.example.Sanitizer.clean";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30031.rul rosters
verify "java" "rule" "rule_id" "30031" "$D/c.tar" "g05-java-sanitizer-in-rule"
rm -rf "$D"

# G6: Java - sink.methodReturn (reverse of methodArg)
echo "=== G6: Java sink.methodReturn ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30032.rul" << 'EOF'
Rule SinkMethodReturnRule extends AbstractTaintRule {
    type = "Test";
    subType = "SinkReturnTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodReturn += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30032.rul rosters
verify "java" "rule" "rule_id" "30032" "$D/c.tar" "g06-java-sink-methodreturn"
rm -rf "$D"

# G7: Java - 'modifiable' keyword
echo "=== G7: Java 'modifiable' keyword ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30033.rul" << 'EOF'
Rule ModifiableTestRule extends AbstractTaintRule {
    type = "Test";
    subType = "ModTest";
    modifiable source.methodReturn;
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30033.rul rosters
verify "java" "rule" "rule_id" "30033" "$D/c.tar" "g07-java-modifiable"
rm -rf "$D"

# G8: JS - source.expression without taintTag
echo "=== G8: JS source.expression without taintTag ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/7030.rul" << 'EOF'
Rule JsExprNoTag extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.expression += {
        value += "/ctx\\.query$/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 7030.rul rosters
verify "javascript" "rule" "rule_id" "7030" "$D/c.tar" "g08-js-expression-no-tag"
rm -rf "$D"

# G9: JS - paramDecorator in roster
echo "=== G9: JS Roster with paramDecorator ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/rosters/NodeJS_decorator_test_0.ros" << 'EOF'
Roster NodeJS_decorator_test {
    source.paramDecorator += {
        value = "/@Query\\b/";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters
verify "javascript" "roster" "roster_name" "NodeJS_decorator_test_0" "$D/c.tar" "g09-js-roster-paramdecorator"
rm -rf "$D"

# G10: Java Rule - multiple source/sink entries
echo "=== G10: Java Rule - multiple source entries ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30034.rul" << 'EOF'
Rule MultiSourceRule extends AbstractTaintRule {
    type = "Test";
    subType = "MultiSource";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get1";
    };
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get2";
    };
    source.methodArg += {
        precise = true;
        value = "com.example.Source.getArg";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30034.rul rosters
verify "java" "rule" "rule_id" "30034" "$D/c.tar" "g10-java-multi-source"
rm -rf "$D"

# G11: JS - does loadclass work in roster extend-file?
echo "=== G11: JS Roster with loadclass + extend-file ==="
D=$(mktemp -d); mkdir -p "$D/rosters" "$D/extend-file/rosters/NodeJS_custom_func_0"
cat > "$D/rosters/NodeJS_custom_func_0.ros" << 'EOF'
Roster NodeJS_custom_func {
    source.customSourceFunc = loadclass("NodeJS_custom_func.customSourceFunc_0");
}
EOF
cat > "$D/extend-file/rosters/NodeJS_custom_func_0/NodeJS_custom_func.js" << 'EOF'
let rule = {};
module.exports.rule = rule;
rule.customSourceFunc_0 = (rule, node, context) => {
    return false;
};
EOF
tar -cf "$D/c.tar" -C "$D" rosters extend-file
verify "javascript" "roster" "roster_name" "NodeJS_custom_func_0" "$D/c.tar" "g11-js-roster-loadclass"
rm -rf "$D"

# G12: What does Java accept for valid verify_type?
echo "=== G12: Invalid verify_type ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30035.rul" << 'EOF'
Rule TestRule extends AbstractTaintRule {
    type = "Test";
    subType = "TestRule";
}
EOF
tar -cf "$D/c.tar" -C "$D" 30035.rul rosters
verify "java" "invalid_type" "rule_id" "30035" "$D/c.tar" "g12-invalid-verify-type"
rm -rf "$D"

echo ""
echo "=== ROUND 3 DONE ==="
for f in "$RD"/g*.json; do
  echo "$(basename "$f"): $(cat "$f")"
  echo ""
done
