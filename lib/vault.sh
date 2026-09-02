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

# Seed the email/* + llm/opencode Vault secrets from Infisical.
#
# A from-scratch bootstrap must restore the data that the committed
# ExternalSecrets (`email-env`, `email-bulk`, `analyst-secrets`/`pdf-scan-env`)
# sync into apps-ns, otherwise those Secrets never become Ready and the
# resume-email sender/verification pipeline and the analyst/llm apps have no
# credentials. This function is the bootstrap counterpart to
# tech-companies/scripts/import-vault-secrets.sh: it fetches the same Infisical
# values (via the Infisical v4 API, authenticated with INFISICAL_API_TOKEN) and
# writes them into Vault through the vault-0 pod (so it works during a cluster
# bring-up when Vault has no externally reachable address).
#
# Two Infisical projects feed this:
#   * Email project (default 0b5f1bae-...; override EMAIL_INFISICAL_PROJECT_ID)
#       secret/email/env  : SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_FROM
#       secret/email/bulk : TINYVALIDATOR_API_KEY MAILBOXLAYER_API_KEY HUNTER_API_KEY SMTP_USER_API SMTP_PASS_API
#   * LLM project llm-b-ete (default 1ef83d85-...; override LLM_INFISICAL_PROJECT_ID)
#       secret/llm/opencode : OPENCODE_ZEN_API_KEY
#
# The Infisical environment defaults to `dev` (override INFISICAL_ENV) and the
# secret path to `/` (override INFISICAL_SECRET_PATH). Requires curl + python3.
# SMTP_PASS* values may contain spaces (app passwords), so every value is
# single-quoted/escaped for injection into the pod's sh -c. Secret values are
# never echoed - only key names.
#
# Idempotent; safe to run on every bootstrap.
# Usage: seed_email_vault <vault_repo_path>
seed_email_vault() {
  local vault_repo="$1"
  local root_token
  root_token="$(python3 -c "import sys,json; print(json.load(open('$vault_repo/init.json'))['root_token'])")"

  local token="${INFISICAL_API_TOKEN:-}"
  if [[ -z "$token" ]]; then
    echo "[vault] WARNING: INFISICAL_API_TOKEN unset - skipping Infisical Vault seed"
    return 0
  fi
  local infisical_env="${INFISICAL_ENV:-dev}"
  local infisical_path="${INFISICAL_SECRET_PATH:-/}"
  local email_project="${EMAIL_INFISICAL_PROJECT_ID:-0b5f1bae-7749-4e3c-aeea-cc44cc986ad6}"
  local llm_project="${LLM_INFISICAL_PROJECT_ID:-1ef83d85-aeb8-4944-91c3-2fd7c0228600}"

  # fetch_secrets <project_id> <key...> -> prints "KEY=V grouped" lines? No:
  # fetch_secrets prints a NUL-terminated "key=value" stream for lookup.
  # Simpler: fetch each project's JSON once, emit "key value" per matching key.
  fetch_secrets() {
    local pid="$1"; shift
    local json
    json="$(curl -sf --max-time 30 \
      "https://us.infisical.com/api/v4/secrets?projectId=${pid}&environment=${infisical_env}&secretPath=${infisical_path}&viewSecretValue=true&limit=100" \
      -H "Authorization: Bearer ${token}")" || {
        echo "[vault]   ERROR: failed to fetch secrets from Infisical project ${pid}" >&2
        return 1
      }
    printf '%s' "$json" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception as e:
    sys.stderr.write(f"invalid Infisical response: {e}\n"); sys.exit(1)
need = set(sys.argv[1:])
mapping = {s.get("secretKey"): s.get("secretValue", "") for s in d.get("secrets", [])}
for k in need:
    if k in mapping:
        print(f"{k}\t{mapping[k]}")
' "$@"
  }

  # write_vault_path <vault_path> <key...> : fetch keys from Infisical and write.
  write_vault_path() {
    local path="$1"; shift
    local pid="$1"; shift
    local args=() k v kv quoted
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] || continue
      quoted="$(printf '%s' "$v" | sed "s/'/'\\\\''/g")"
      args+=("${k}='${quoted}'")
    done < <(fetch_secrets "$pid" "$@")
    if [[ ${#args[@]} -eq 0 ]]; then
      echo "[vault]   ${path}: no matching Infisical keys, skipping"
      return 0
    fi
    local names=() a
    for a in "${args[@]}"; do names+=("${a%%=*}"); done
    echo "[vault] Seeding ${path}: ${names[*]}"
    vault_exec vault-0 "VAULT_TOKEN='$root_token' vault kv put -mount=secret \"$path\" ${args[*]}"
  }

  echo "[vault] Seeding secrets into Vault from Infisical..."
  write_vault_path "email/env" "$email_project" \
    SMTP_HOST SMTP_PORT SMTP_USER SMTP_PASS SMTP_FROM
  write_vault_path "email/bulk" "$email_project" \
    TINYVALIDATOR_API_KEY MAILBOXLAYER_API_KEY HUNTER_API_KEY SMTP_USER_API SMTP_PASS_API
  write_vault_path "llm/opencode" "$llm_project" \
    OPENCODE_ZEN_API_KEY
  echo "[vault] Infisical seed complete (email/env, email/bulk, llm/opencode)."
}

# Provision ESO Kubernetes auth (roles es-vault, es-vault-analyst) + seed
# secret/aws/env. Idempotent; safe to run on every bootstrap after init + unseal
# so a from-scratch rebuild restores s3-credentials with no manual steps
# (declarative cluster recovery, specs/007). The analyst API key is NOT seeded
# here - it now lives at secret/llm/opencode and is seeded from Infisical by
# seed_email_vault() (analyst reads it via the vault-llm store, not analyst/env).
# Token reviewer = the `vault` SA (bound to system:auth-delegator via
# vault-server-binding) whose JWT+CA are mounted in the vault-0 pod.
# S3 creds from S3_ACCESS_KEY_ID / S3_SECRET_ACCESS_KEY (defaults: floci/floci1234)
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
