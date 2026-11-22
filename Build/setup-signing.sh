#!/bin/zsh
# 一次性创建稳定自签名证书（TCC 授权按签名绑定，固定证书可让重新构建后授权不失效）。
# build.sh 现在固定使用该证书，不再回退 Apple Development 或 ad-hoc。
set -euo pipefail
cd "$(dirname "$0")"

CERT_NAME="MacAppControlDeck Self-Signed"
if security find-certificate -c "$CERT_NAME" >/dev/null 2>&1; then
  echo "证书已存在：$CERT_NAME"
  exit 0
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/openssl.cnf" <<EOF
[ req ]
distinguished_name = dn
x509_extensions = v3
prompt = no
[ dn ]
CN = $CERT_NAME
O = Local Development
[ v3 ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" \
  -days 3650 -config "$WORK/openssl.cnf" >/dev/null 2>&1

openssl pkcs12 -export -legacy -out "$WORK/identity.p12" \
  -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
  -name "$CERT_NAME" -passout pass:deck >/dev/null 2>&1 \
  || openssl pkcs12 -export -out "$WORK/identity.p12" \
      -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
      -name "$CERT_NAME" -passout pass:deck >/dev/null 2>&1

security import "$WORK/identity.p12" -k ~/Library/Keychains/login.keychain-db \
  -P deck -T /usr/bin/codesign >/dev/null

echo "已创建证书：$CERT_NAME"
echo "首次签名时系统可能弹出钥匙串授权，请选择「始终允许」。"
echo "如签名仍失败，请在「钥匙串访问」中把该证书的信任设置为「代码签名」。"
