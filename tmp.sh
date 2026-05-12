WS_DIR=$(mktemp -d) && mkdir -p "$WS_DIR/rosters" && \
echo "UnVsZSBUZXN0UnVsZSBleHRlbmRzIEFic3RyYWN0VGFpbnRSdWxlIHsKICAgIHR5cGUgPSAiVGVzdCI7CiAgICBzdWJUeXBlID0gIlRlc3RSdWxlIjsKCiAgICAvLyDmupDlrprkuYkKICAgIHNvdXJjZS5tZXRob2RSZXR1cm4gKz0gewogICAgICAgIHByZWNpc2UgPSB0cnVlOwogICAgICAgIHZhbHVlID0gImNvbS5leGFtcGxlLlNvdXJjZS5tZXRob2QiOwogICAgfTsKCiAgICAvLyDmsYflrprkuYkKICAgIHNpbmsubWV0aG9kQXJnICs9IHsKICAgICAgICBwcmVjaXNlID0gdHJ1ZTsKICAgICAgICB2YWx1ZSA9ICJjb20uZXhhbXBsZS5TaW5rLm1ldGhvZCI7CiAgICB9Owp9Cg==" | base64 -d > "$WS_DIR/30001.rul" && \
tar -cf "$WS_DIR/config.tar" -C "$WS_DIR" 30001.rul && \
# 使用 --data-binary 手动发送 Body，避开 curl -F 的复杂特征
(
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"language\""
  echo ""
  echo "java"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"verify_type\""
  echo ""
  echo "rule"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"rule_id\""
  echo ""
  echo "30001"
  echo "--bound"
  echo "Content-Disposition: form-data; name=\"file\"; filename=\"config.tar\""
  echo "Content-Type: application/octet-stream"
  echo ""
  cat "$WS_DIR/config.tar"
  echo ""
  echo "--bound--"
) > "$WS_DIR/payload.bin"

curl -v --noproxy "*" \
  --http1.0 \
  -H "Content-Type: multipart/form-data; boundary=bound" \
  --data-binary "@$WS_DIR/payload.bin" \
  "http://43.106.136.189:8081/api/v1/verify" ; \
rm -rf "$WS_DIR"