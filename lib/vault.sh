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

# Enable KV v2 secrets engine at secret/
# Usage: enable_vault_secrets <vault_repo_path>
# Uses the root token from init.json (a tokenless CLI call silently 403s).
enable_vault_secrets() {
  local vault_repo="$1"
  echo "[vault] Enabling KV v2 secrets engine at secret/..."
  local root_token
  root_token="$(python3 -c "import sys,json; print(json.load(open('$vault_repo/init.json'))['root_token'])")"
  vault_exec vault-0 "VAULT_TOKEN='$root_token' vault secrets enable -path=secret kv-v2" 2>/dev/null || {
    echo "[vault] WARNING: KV v2 engine may already be enabled (continuing)"
  }
  echo "[vault] KV v2 secrets engine ready."
}

# Provision ESO Kubernetes auth (roles es-vault, es-vault-analyst) + seed
# secret/aws/env and secret/analyst/env.
# Idempotent; safe to run on every bootstrap after init + unseal so a
# from-scratch rebuild restores s3-credentials and analyst-secrets with no
# manual steps (declarative cluster recovery, specs/007).
# Token reviewer = the `vault` SA (bound to system:auth-delegator via
# vault-server-binding) whose JWT+CA are mounted in the vault-0 pod.
# S3 creds from S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY (defaults: floci/floci1234)
# Analyst key from ANALYST_ZEN_API_KEY_B64 (NO default - real credential;
#   store base64 form; ExternalSecret decodes via decodingStrategy: Base64)
# Usage: provision_es_vault <vault_repo_path>
provision_es_vault() {
  local vault_repo="$1"
  local root_token
  root_token="$(python3 -c "import sys,json; print(json.load(open('$vault_repo/init.json'))['root_token'])")"

  echo "[vault] Enabling Kubernetes auth method (kubernetes)..."
  vault_exec vault-0 "VAULT_TOKEN='$root_token' vault auth enable -path=kubernetes kubernetes" 2>/dev/null || {
    echo "[vault]   kubernetes auth already enabled (continuing)"
  }

  echo "[vault] Writing auth/kubernetes/config (token reviewer = vault SA)..."
  vault_exec vault-0 "VAULT_TOKEN='$root_token' vault write auth/kubernetes/config \
    kubernetes_host='https://kubernetes.default.svc:443' \
    token_reviewer_jwt=@/var/run/secrets/kubernetes.io/serviceaccount/token \
    kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
    disable_iss_validation=true"

  echo "[vault] Writing policy aws-read-env..."
  local policy_b64
  policy_b64="$(base64 < "$vault_repo/policies/aws-read-env.hcl" | tr -d '\n')"
  vault_exec vault-0 "VAULT_TOKEN='$root_token' sh -c 'echo $policy_b64 | base64 -d > /tmp/aws-read-env.hcl && vault policy write aws-read-env /tmp/aws-read-env.hcl'"

  echo "[vault] Writing role es-vault (SA apps-ns/es-vault-auth)..."
  vault_exec vault-0 "VAULT_TOKEN='$root_token' vault write auth/kubernetes/role/es-vault \
    bound_service_account_names='es-vault-auth' \
    bound_service_account_namespaces='apps-ns' \
    audience='https://kubernetes.default.svc.cluster.local' \
    policies='aws-read-env' \
    token_ttl=1h"

  echo "[vault] Seeding secret/aws/env..."
  local access_key="${S3_ACCESS_KEY_ID:-floci}"
  local secret_key="${S3_SECRET_ACCESS_KEY:-floci1234}"
  vault_exec vault-0 "VAULT_TOKEN='$root_token' vault kv put -mount=secret aws/env S3_ACCESS_KEY_ID='$access_key' S3_SECRET_ACCESS_KEY='$secret_key'"

  echo "[vault] Writing policy analyst-read-env..."
  policy_b64="$(base64 < "$vault_repo/policies/analyst-read-env.hcl" | tr -d '\n')"
  vault_exec vault-0 "VAULT_TOKEN='$root_token' sh -c 'echo $policy_b64 | base64 -d > /tmp/analyst-read-env.hcl && vault policy write analyst-read-env /tmp/analyst-read-env.hcl'"

  echo "[vault] Writing role es-vault-analyst (SA apps-ns/analyst-vault-auth)..."
  vault_exec vault-0 "VAULT_TOKEN='$root_token' vault write auth/kubernetes/role/es-vault-analyst \
    bound_service_account_names='analyst-vault-auth' \
    bound_service_account_namespaces='apps-ns' \
    audience='https://kubernetes.default.svc.cluster.local' \
    policies='analyst-read-env' \
    token_ttl=1h"

  # Seed secret/analyst/env for the analyst app's OPENCODE_ZEN_API_KEY.
  # Stored as base64 (analyst ExternalSecret decodes via decodingStrategy).
  # No committed default: the key is a real credential; supply
  # ANALYST_ZEN_API_KEY_B64 (Infisical feeds it long-term, 007 FR-006).
  echo "[vault] Seeding secret/analyst/env..."
  local analyst_key_b64="${ANALYST_ZEN_API_KEY_B64:-}"
  if [[ -n "$analyst_key_b64" ]]; then
    vault_exec vault-0 "VAULT_TOKEN='$root_token' vault kv put -mount=secret analyst/env OPENCODE_ZEN_API_KEY='$analyst_key_b64'"
  else
    echo "[vault] WARNING: ANALYST_ZEN_API_KEY_B64 unset - SKIPPING secret/analyst/env seed"
    echo "[vault]          analyst ESO will not produce analyst-secrets until provided"
  fi
  echo "[vault] es-vault provisioning complete."
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
