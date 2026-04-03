#!/bin/bash
# Follow-up experiments to resolve questions from round 1
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

# F1: JS rule WITHOUT precise (use pattern instead of value)
echo "=== F1: JS Rule using 'pattern' not 'precise+value' ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/6991.rul" << 'EOF'
Rule XssTs_6991 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        value = "\\b(this|ctx|app)\\.getQuery\\b|\\breq\\.query\\b";
    };
    sink.methodArg += {
        value = "\\bres\\.send\\b|\\bres\\.write\\b";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 6991.rul rosters
verify "javascript" "rule" "rule_id" "6991" "$D/c.tar" "f01-js-rule-no-precise"
rm -rf "$D"

# F2: JS rule using 'pattern' instead of 'value'
echo "=== F2: JS Rule using 'pattern' field ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/6992.rul" << 'EOF'
Rule XssTs_6992 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        pattern = "\\b(this|ctx|app)\\.getQuery\\b|\\breq\\.query\\b";
    };
    sink.methodArg += {
        pattern = "\\bres\\.send\\b|\\bres\\.write\\b";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 6992.rul rosters
verify "javascript" "rule" "rule_id" "6992" "$D/c.tar" "f02-js-rule-pattern-field"
rm -rf "$D"

# F3: JS rule using pattern with += (from docs example)
echo "=== F3: JS Rule using 'pattern += /regex/' ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/6993.rul" << 'EOF'
Rule XssTs_6993 extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        value += "/\\b(this|ctx|app)\\.getQuery\\b|\\breq\\.query\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b|\\bres\\.write\\b/";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 6993.rul rosters
verify "javascript" "rule" "rule_id" "6993" "$D/c.tar" "f03-js-rule-pattern-pluseq"
rm -rf "$D"

# F4: Java Rule - import AFTER source/sink (position test)
echo "=== F4: Java Rule - import after source/sink ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30020.rul" << 'EOF'
Rule ImportAfterRule extends AbstractTaintRule {
    type = "SSRF";
    subType = "SSRFHook";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
    import roster Java_common_source;
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
tar -cf "$D/c.tar" -C "$D" 30020.rul rosters
verify "java" "rule" "rule_id" "30020" "$D/c.tar" "f04-java-import-after-fields"
rm -rf "$D"

# F5: Java Rule - loadclass with string value (not =, use +=)
echo "=== F5: Java Rule - loadclass with += ==="
D=$(mktemp -d); mkdir -p "$D/rosters" "$D/extend-file/30021"
cat > "$D/30021.rul" << 'EOF'
Rule LoadclassTestRule extends AbstractTaintRule {
    type = "Test";
    subType = "LoadTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.getData";
    };
    sink.customSinkFunc += loadclass("LoadclassTestRule.customSink_0");
}
EOF
cat > "$D/extend-file/30021/LoadclassTestRule.java" << 'EOF'
public class LoadclassTestRule {
    public static boolean customSink_0(Object rule, Object node, Object context) {
        return false;
    }
}
EOF
tar -cf "$D/c.tar" -C "$D" 30021.rul rosters extend-file
verify "java" "rule" "rule_id" "30021" "$D/c.tar" "f05-java-loadclass-pluseq"
rm -rf "$D"

# F6: Java Rule - group inside Java (test group syntax)
echo "=== F6: Java Roster - group (not rule) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/rosters/Java_group_test_0.ros" << 'EOF'
Roster Java_group_test {
    sanitizer.methodReturn += {
        value = "com.example.Sanitizer.escape";
    };
    group AllPlatforms {
        includePlatforms = "*";
        sanitizer.methodReturn += {
            value = "com.example.Sanitizer.sanitize";
        };
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters
verify "java" "roster" "roster_name" "Java_group_test_0" "$D/c.tar" "f06-java-roster-group-test"
rm -rf "$D"

# F7: JS Rule with group
echo "=== F7: JS Rule with group (cocktail) ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/7010.rul" << 'EOF'
Rule JsGroupRule extends AbstractTaintRule {
    type = "Xss";
    subType = "XssTs";
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
    sink.methodArg += {
        pattern += "/\\bres\\.send\\b/";
    };
    group cocktail_handler {
        includePlatforms = "cocktail";
        source.methodReturn += {
            value += "/\\bctx\\.getQuery\\b/";
        };
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 7010.rul rosters
verify "javascript" "rule" "rule_id" "7010" "$D/c.tar" "f07-js-rule-group"
rm -rf "$D"

# F8: JS Roster without precise
echo "=== F8: JS Roster without 'precise' ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/rosters/NodeJS_test_0.ros" << 'EOF'
Roster NodeJS_test {
    source.methodReturn += {
        value += "/\\breq\\.query\\b/";
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" rosters
verify "javascript" "roster" "roster_name" "NodeJS_test_0" "$D/c.tar" "f08-js-roster-no-precise"
rm -rf "$D"

# F9: Java Rule - what fields does sink support? test with paramIndex
echo "=== F9: Java Rule with sink.methodArg paramIndex ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30022.rul" << 'EOF'
Rule ParamIndexRule extends AbstractTaintRule {
    type = "Test";
    subType = "ParamTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
        paramIndex = 0;
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30022.rul rosters
verify "java" "rule" "rule_id" "30022" "$D/c.tar" "f09-java-paramindex"
rm -rf "$D"

# F10: Java Rule - test 'define' and 'modifiable' keywords
echo "=== F10: Java Rule with 'define' keyword ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30023.rul" << 'EOF'
Rule DefineTestRule extends AbstractTaintRule {
    type = "Test";
    subType = "DefineTest";
    define mySource = "com.example.Source.get";
    source.methodReturn += {
        precise = true;
        value = mySource;
    };
}
EOF
tar -cf "$D/c.tar" -C "$D" 30023.rul rosters
verify "java" "rule" "rule_id" "30023" "$D/c.tar" "f10-java-define-keyword"
rm -rf "$D"

# F11: What about 'delete' keyword in Java?
echo "=== F11: Java Rule with 'delete' keyword ==="
D=$(mktemp -d); mkdir -p "$D/rosters"
cat > "$D/30024.rul" << 'EOF'
Rule DeleteTestRule extends AbstractTaintRule {
    type = "Test";
    subType = "DeleteTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    delete source.methodReturn;
}
EOF
tar -cf "$D/c.tar" -C "$D" 30024.rul rosters
verify "java" "rule" "rule_id" "30024" "$D/c.tar" "f11-java-delete-keyword"
rm -rf "$D"

# F12: Relation config test - with config_roster_relation.json
echo "=== F12: Java Rule with relation config ==="
D=$(mktemp -d); mkdir -p "$D/rosters" "$D/relation"
cat > "$D/30025.rul" << 'EOF'
Rule RelationTestRule extends AbstractTaintRule {
    type = "Test";
    subType = "RelationTest";
    source.methodReturn += {
        precise = true;
        value = "com.example.Source.get";
    };
    sink.methodArg += {
        precise = true;
        value = "com.example.Sink.exec";
    };
}
EOF
cat > "$D/rosters/Java_common_source_0.ros" << 'EOF'
Roster Java_common_source {
    source.methodReturn += {
        precise = true;
        value = "javax.servlet.http.HttpServletRequest.getParameter";
    };
}
EOF
cat > "$D/relation/config_roster_relation.json" << 'EOF'
{
    "30025": ["Java_common_source_0"]
}
EOF
tar -cf "$D/c.tar" -C "$D" 30025.rul rosters relation
verify "java" "rule" "rule_id" "30025" "$D/c.tar" "f12-java-relation-config"
rm -rf "$D"

echo ""
echo "=== FOLLOW-UP EXPERIMENTS DONE ==="
for f in "$RD"/f*.json; do
  echo "$(basename "$f"): $(cat "$f")"
  echo ""
done
