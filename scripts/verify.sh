#!/usr/bin/env bash
# usage: verify.sh <dir containing blob.txt and bundle.json>
set +e
cd "$1" || exit 1
PAT='^https://github\.com/kmosher/test-actions/\.github/workflows/[^/]+@refs/heads/production$'
ISS=https://token.actions.githubusercontent.com
python3 -I - <<'PY' > cert.b64
import json
b = json.load(open('bundle.json'))
vm = b['verificationMaterial']
c = vm.get('certificate') or vm['x509CertificateChain']['certificates'][0]
print(c['rawBytes'])
PY
base64 -d cert.b64 > cert.der
echo "== cosign version"; cosign version 2>&1 | grep -i gitversion
echo "== certificate SAN"; openssl x509 -inform DER -noout -ext subjectAltName | tail -n +2
echo "== certificate OIDC issuer extension"; openssl x509 -inform DER -noout -text | grep -A1 '1.3.6.1.4.1.57264.1.1:' | tr -d '\n'; echo
echo "== any-identity verify (signature valid, issuer pinned)"
cosign verify-blob --bundle bundle.json --certificate-identity-regexp '.*' --certificate-oidc-issuer "$ISS" blob.txt; echo "ANYIDENTITY_EXIT=$?"
echo "== production-branch regexp verify"
cosign verify-blob --bundle bundle.json --certificate-identity-regexp "$PAT" --certificate-oidc-issuer "$ISS" blob.txt; echo "PRODREGEX_EXIT=$?"
exit 0
