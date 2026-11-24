#!/usr/bin/env bash
# Hermetic regression tests for bin/liquibase-shell — THERO2-027 Part 1.
#
# Proves the fetch-failure contract: when kubectl fails (or returns empty),
# the wrapper exits 1 with "Failed to read ..." / "Tried keys ..." on output.
# The 2026-11-17 incident showed an apparent exit 0 after those messages;
# provenance traced it to exit-masking OUTSIDE the script. These tests pin
# the script-side behavior so future edits cannot silently break it.
#
# Cases (fetch stage only — never past it, no live DB needed):
#   1. kubectl exits nonzero        -> exit 1 + failure messages
#   2. kubectl exits 0, empty body  -> exit 1 + failure messages
#
# Hermetic: temp config via LIQUIBASE_CONFIG (existing seam), kubectl stub
# prepended to PATH. No network, no cluster.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WRAPPER="$SCRIPT_DIR/../bin/liquibase-shell"

PASS=0
FAIL=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- fixture config (standard changelog dir form) ---
mkdir -p "$TMP/repo/changelog"
cat > "$TMP/infra-config.yaml" <<'YAML'
liquibase_targets:
  fixture:
    description: hermetic test fixture
    namespace: test-ns
    service: test-svc
    remote_port: 5432
    local_port: 15432
    db_type: postgresql
    db_name: testdb
    schema: public
    secret_namespace: test-ns
    secret_name: test-secret
    secret_key: DB_PASSWORD
    username_key: DB_USER
    username_secret_namespace: test-ns
    username_secret_name: test-secret
    changelog_dir: changelog
    changelog_file: changelog-master.yaml
    safety: readonly
YAML

# --- kubectl stub: mode via $KUBECTL_FAKE_MODE ---
mkdir -p "$TMP/bin"
cat > "$TMP/bin/kubectl" <<'STUB'
#!/usr/bin/env bash
case "${KUBECTL_FAKE_MODE:-fail}" in
  fail)  exit 1 ;;
  empty) exit 0 ;;
  *)     exit 1 ;;
esac
STUB
chmod +x "$TMP/bin/kubectl"

run_case() {
  local mode="$1"
  (cd "$TMP" && \
    PATH="$TMP/bin:$PATH" \
    KUBECTL_FAKE_MODE="$mode" \
    LIQUIBASE_CONFIG="$TMP/infra-config.yaml" \
    HOME="$TMP" \
    LIQUIBASE_ASSUME_YES=1 \
    bash "$WRAPPER" fixture -- status >"$TMP/err" 2>&1)
}

check_case() {
  local name="$1" mode="$2"
  run_case "$mode"
  local rc=$?
  local out; out="$(cat "$TMP/err")"
  local ok=true
  [[ "$rc" -eq 1 ]] || { ok=false; echo "FAIL [$name]: exit=$rc (want 1)"; }
  grep -q "Failed to read" <<<"$out" || { ok=false; echo "FAIL [$name]: missing 'Failed to read'"; }
  grep -q "Tried keys"    <<<"$out" || { ok=false; echo "FAIL [$name]: missing 'Tried keys'"; }
  if $ok; then echo "pass [$name]"; PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
}

check_case "kubectl-fails" fail
check_case "kubectl-empty" empty

# Guard smoke check (part 2, no kubectl needed — fails at fetch, but the
# ledger-form warning must have printed before that for a non-standard dir form)
sed 's/changelog_dir: changelog/changelog_dir: changelogs/' "$TMP/infra-config.yaml" > "$TMP/infra-nonstd.yaml"
(cd "$TMP" && \
  PATH="$TMP/bin:$PATH" KUBECTL_FAKE_MODE=fail \
  LIQUIBASE_CONFIG="$TMP/infra-nonstd.yaml" HOME="$TMP" LIQUIBASE_ASSUME_YES=1 \
  bash "$WRAPPER" fixture -- status >"$TMP/out2" 2>&1)
if grep -q "WARNING \[ledger-form\]" "$TMP/out2"; then echo "pass [ledger-form-warns]"; PASS=$((PASS+1));
else echo "FAIL [ledger-form-warns]: no WARNING"; FAIL=$((FAIL+1)); fi

# Standard form must NOT warn
(cd "$TMP" && \
  PATH="$TMP/bin:$PATH" KUBECTL_FAKE_MODE=fail \
  LIQUIBASE_CONFIG="$TMP/infra-config.yaml" HOME="$TMP" LIQUIBASE_ASSUME_YES=1 \
  bash "$WRAPPER" fixture -- status >"$TMP/out3" 2>&1)
if grep -q "WARNING \[ledger-form\]" "$TMP/out3"; then echo "FAIL [standard-form-silent]: warned on standard form"; FAIL=$((FAIL+1));
else echo "pass [standard-form-silent]"; PASS=$((PASS+1)); fi

echo "---"
echo "$PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
