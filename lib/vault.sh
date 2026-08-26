#!/usr/bin/env bash
# vault.sh - HashiCorp Vault setup and unseal library
# FR-011: Extract Vault setup code into lib/vault.sh module

set -euo pipefail

# Vault local address for CLI operations
VAULT_LOCAL_ADDR="${VAULT_LOCAL_ADDR:-https://127.0.0.1:8200}"

# Helper: run vault CLI inside a pod with correct VAULT_ADDR
# Usage: vault_exec <pod> <command>
vault_exec() {
  local pod=$1; shift
  kubectl exec -n vault "$pod" -- sh -c "VAULT_ADDR='$VAULT_LOCAL_ADDR' $*"
}

# Create vault-tls source secret in apps-ns
# Usage: create_vault_tls_secret <vault_repo_path>
create_vault_tls_secret() {
  local vault_repo="$1"
  echo "[vault] Creating vault-tls source secret..."
  if [[ -f "$vault_repo/scripts/vault-tls.sh" ]]; then
    bash "$vault_repo/scripts/vault-tls.sh"
  else
    echo "[vault] WARNING: vault-tls.sh not found at $vault_repo/scripts/vault-tls.sh"
    echo "[vault] Please run it manually to create the vault-tls secret in apps-ns"
  fi
}

# Create vault-unseal-keys placeholder secret
# Usage: create_vault_unseal_placeholder
create_vault_unseal_placeholder() {
  echo "[vault] Creating vault-unseal-keys secret..."
  kubectl create namespace vault --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n vault create secret generic vault-unseal-keys \
    --from-literal=key1=PLACEHOLDER \
    --from-literal=key2=PLACEHOLDER \
    --from-literal=key3=PLACEHOLDER \
    --dry-run=client -o yaml | kubectl apply -f -
}

# Wait for vault-tls secret to be synced to vault namespace
# Usage: wait_for_vault_tls
wait_for_vault_tls() {
  echo "[vault] Waiting for vault-tls secret in vault namespace..."
  until kubectl get secret vault-tls -n vault >/dev/null 2>&1; do
    sleep 5
  done
  echo "[vault] vault-tls secret is ready."
}

# Initialize vault and return init JSON
# Usage: init_vault <vault_repo_path>
# Returns: sets INIT_JSON variable
init_vault() {
  local vault_repo="$1"

  echo "[vault] Checking VAULT_ADDR inside vault-0..."
  kubectl exec -n vault vault-0 -- printenv VAULT_ADDR 2>/dev/null || echo "[vault] (could not read VAULT_ADDR)"

  echo "[vault] Waiting for vault-0 API to be reachable..."
  local timeout=60 count=0
  until (vault_exec vault-0 "vault status -tls-skip-verify -format=json" 2>/dev/null || true) | grep -q '"initialized"'; do
    count=$((count + 1))
    if [ $count -ge $timeout ]; then
      echo "[vault] ERROR: Timed out waiting for vault-0 API after $((timeout * 5))s"
      return 1
    fi
    sleep 5
  done
  echo "[vault] vault-0 API is reachable."

  echo "[vault] Initializing vault..."
  INIT_JSON=$(vault_exec vault-0 "vault operator init -key-shares=5 -key-threshold=3 -format=json -tls-skip-verify")
  if [[ -z "$INIT_JSON" ]] || ! echo "$INIT_JSON" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    echo "[vault] ERROR: vault operator init failed or returned invalid JSON"
    echo "[vault] Output: $INIT_JSON"
    return 1
  fi
  echo "$INIT_JSON" > "$vault_repo/init.json"
  echo "[vault] Vault initialized. Keys saved to $vault_repo/init.json"
}

# Unseal vault-0, vault-1, vault-2 in sequence
# Usage: unseal_vault
# Requires: INIT_JSON variable set by init_vault
unseal_vault() {
  # Extract unseal keys
  local key1 key2 key3
  key1=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][0])")
  key2=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][1])")
  key3=$(echo "$INIT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['unseal_keys_b64'][2])")

  # Update the secret with real keys
  kubectl -n vault delete secret vault-unseal-keys --ignore-not-found
  kubectl -n vault create secret generic vault-unseal-keys \
    --from-literal=key1="$key1" \
    --from-literal=key2="$key2" \
    --from-literal=key3="$key3"

  # Unseal vault-0
  echo "[vault] Unsealing vault-0..."
  for key in "$key1" "$key2" "$key3"; do
    local result
    result=$(vault_exec vault-0 "vault operator unseal -format=json -tls-skip-verify '$key'" 2>&1) || {
      echo "[vault] ERROR: failed to unseal vault-0: $result"
      return 1
    }
    echo "  key applied, sealed=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed','?'))" 2>/dev/null || echo "parse-error")"
  done
  echo "[vault] vault-0 unsealed. Waiting for it to be ready..."
  if ! kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=300s; then
    echo "[vault] ERROR: vault-0 did not become Ready within 300s"
    return 1
  fi
  local sealed
  sealed=$(vault_exec vault-0 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null)
  if [ "$sealed" != "False" ]; then
    echo "[vault] ERROR: vault-0 is still sealed after unseal (sealed=$sealed)"
    return 1
  fi
  echo "[vault] vault-0 verified: sealed=False"

  # Unseal vault-1
  echo "[vault] Waiting for vault-1 to join raft cluster (initialized)..."
  local timeout=60 count=0
  until (vault_exec vault-1 "vault status -tls-skip-verify -format=json" 2>/dev/null || true) | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('initialized') else 1)"; do
    count=$((count + 1))
    if [ $count -ge $timeout ]; then
      echo "[vault] ERROR: Timed out waiting for vault-1 to initialize after $((timeout * 5))s"
      return 1
    fi
    sleep 5
  done
  echo "[vault] vault-1 joined raft cluster."
  echo "[vault] Unsealing vault-1..."
  for key in "$key1" "$key2" "$key3"; do
    local result unseal_exit
    result=$(vault_exec vault-1 "vault operator unseal -format=json -tls-skip-verify '$key'" 2>&1)
    unseal_exit=$?
    echo "  key applied, sealed=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed','?'))" 2>/dev/null || echo "parse-error")"
    if [ $unseal_exit -ne 0 ]; then
      echo "[vault] ERROR: failed to unseal vault-1 (exit $unseal_exit): $result"
      return 1
    fi
  done
  echo "[vault] vault-1 unsealed. Waiting for it to be ready..."
  if ! kubectl wait --for=condition=Ready pod/vault-1 -n vault --timeout=300s; then
    echo "[vault] ERROR: vault-1 did not become Ready within 300s"
    return 1
  fi
  sealed=$(vault_exec vault-1 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null)
  if [ "$sealed" != "False" ]; then
    echo "[vault] ERROR: vault-1 is still sealed after unseal (sealed=$sealed)"
    return 1
  fi
  echo "[vault] vault-1 verified: sealed=False"

  # Unseal vault-2
  echo "[vault] Waiting for vault-2 to join raft cluster (initialized)..."
  timeout=60
  count=0
  until (vault_exec vault-2 "vault status -tls-skip-verify -format=json" 2>/dev/null || true) | python3 -c "import sys,json; exit(0 if json.load(sys.stdin).get('initialized') else 1)"; do
    count=$((count + 1))
    if [ $count -ge $timeout ]; then
      echo "[vault] ERROR: Timed out waiting for vault-2 to initialize after $((timeout * 5))s"
      return 1
    fi
    sleep 5
  done
  echo "[vault] vault-2 joined raft cluster."
  echo "[vault] Unsealing vault-2..."
  for key in "$key1" "$key2" "$key3"; do
    local result unseal_exit
    result=$(vault_exec vault-2 "vault operator unseal -format=json -tls-skip-verify '$key'" 2>&1)
    unseal_exit=$?
    echo "  key applied, sealed=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('sealed','?'))" 2>/dev/null || echo "parse-error")"
    if [ $unseal_exit -ne 0 ]; then
      echo "[vault] ERROR: failed to unseal vault-2 (exit $unseal_exit): $result"
      return 1
    fi
  done
  echo "[vault] vault-2 unsealed. Waiting for it to be ready..."
  if ! kubectl wait --for=condition=Ready pod/vault-2 -n vault --timeout=300s; then
    echo "[vault] ERROR: vault-2 did not become Ready within 300s"
    return 1
  fi
  sealed=$(vault_exec vault-2 "vault status -tls-skip-verify -format=json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['sealed'])" 2>/dev/null)
  if [ "$sealed" != "False" ]; then
    echo "[vault] ERROR: vault-2 is still sealed after unseal (sealed=$sealed)"
    return 1
  fi
  echo "[vault] vault-2 verified: sealed=False"

  echo "[vault] Vault initialized and unsealed."
}

# Verify vault cluster status
# Usage: verify_vault_status
verify_vault_status() {
  echo "[vault] --- Vault Cluster Status ---"
  for i in 0 1 2; do
    local status
    status=$(vault_exec "vault-$i" "vault status -tls-skip-verify -format=json" 2>/dev/null)
    if [ -n "$status" ]; then
      echo "[vault] vault-$i: sealed=$(echo "$status" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'{d[\"sealed\"]} initialized={d[\"initialized\"]} progress={d.get(\"progress\",\"?\")}')")"
    else
      echo "[vault] vault-$i: (could not get status)"
    fi
  done
  echo "[vault] ---"
}
