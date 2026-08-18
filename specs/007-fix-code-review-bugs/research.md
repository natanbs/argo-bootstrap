# Research: Fix Code Review Bugs

**Feature**: 007-fix-code-review-bugs
**Date**: 2026-08-18

## Research Tasks

### 1. Bash grep regex for YAML value matching (FR-001)

**Question**: How to match only the value portion of a YAML line, not the key?

**Decision**: Use `grep -P` (Perl regex) or `awk` to match content after the colon.

**Rationale**: YAML format is `key: value`. The current pattern `^[^#]*password.*:` matches the entire line including the key. We need to match only the value portion.

**Alternatives considered**:
- `awk -F':'` — Split on colon, check second field
- `sed` — Complex, hard to maintain
- Python yq — Adds dependency, overkill for simple check

**Implementation**:
```bash
# Match lines where the VALUE (after colon) contains secret patterns
# Skip comments and key-only lines
if echo "$line" | grep -qP ':\s*(password|secret|token|api_key|apikey|access_key|private_key)\s*=' 2>/dev/null; then
    # This is an inline secret value
fi
```

Or simpler approach: check if the line has a value that looks like a secret (contains `=` or is quoted).

**Revised decision**: Match lines where the value portion contains a secret-like pattern, ignoring key names.

### 2. Config override priority (FR-002)

**Question**: Should env overrides take priority over YAML values?

**Decision**: Yes, env overrides should take priority. This is the standard pattern for configuration.

**Rationale**: Environment variables are typically used for deployment-specific overrides. YAML provides defaults.

**Implementation**:
```bash
config_get() {
    local key="$1"
    local default="${2:-}"
    local value
    
    # Check env overrides first
    case "$key" in
        kopia.password_env)
            value="${KOPIA_PASSWORD_ENV_OVERRIDE:-}"
            ;;
        vault.unseal_key_path)
            value="${KOPIA_BACKUP_UNSEAL_KEY_PATH_OVERRIDE:-}"
            ;;
        # ... other keys
    esac
    
    # Fall back to YAML if no override
    if [[ -z "$value" ]]; then
        # existing yq logic
    fi
    
    [[ -z "$value" ]] && value="$default"
    echo "$value"
}
```

### 3. Vault CA cert source (FR-003)

**Question**: Where is the Kubernetes CA cert available in a k3d cluster?

**Decision**: Use the standard Kubernetes service account CA cert path.

**Rationale**: In a Kubernetes cluster (including k3d), the CA cert is mounted at `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt` for every pod.

**Implementation**:
```bash
local ca_cert
ca_cert="$(cat /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 2>/dev/null)"
if [[ -n "$ca_cert" ]]; then
    vault write ... kubernetes_ca_cert="$ca_cert" ...
else
    log_warn "Cannot read Kubernetes CA cert" "vault"
    return 1
fi
```

### 4. Retention flag separation (FR-004)

**Question**: Should `--keep-latest` have its own config key?

**Decision**: Yes, add `retention.latest` config key.

**Rationale**: `--keep-latest` and `--keep-daily` serve different purposes. `--keep-latest` controls the number of most recent snapshots regardless of time, while `--keep-daily` controls daily snapshot retention.

**Implementation**:
- Add `kopia_retention()` parameter for `latest`
- Add `config_get "retention.latest"` in backup.sh
- Default to Kopia's default (not set) when not explicitly configured

### 5. Idempotency check without pods (FR-005)

**Question**: How to check if data exists on a PVC without a running pod?

**Decision**: Fall through to restore when no pod is mounted.

**Rationale**: During restore, the application pod typically doesn't exist yet. The idempotency check should gracefully handle this case by falling through to the restore path.

**Implementation**:
```bash
if kubernetes_wait "pvc" "$pvc" 5 2>/dev/null; then
    local pod_name
    pod_name="$(kubectl get pods ... | jq ... | head -1)"
    if [[ -n "$pod_name" ]] && kubectl exec ... -- ls "$data_dir" &>/dev/null; then
        # Data exists, skip restore
        return 0
    fi
fi
# Fall through to restore (no pod or no data)
```

### 6. Log helper extraction (FR-007)

**Question**: How to eliminate duplicate JSON/text construction in logging.sh?

**Decision**: Extract a `_format_log_entry` function.

**Rationale**: The same JSON/text construction is duplicated for stdout and log file. Extracting it improves maintainability.

**Implementation**:
```bash
_format_log_entry() {
    local format="$1" timestamp="$2" level="$3" message="$4" component="$5" metadata="$6"
    
    if [[ "$format" == "json" ]]; then
        echo "{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"message\":\"$(_json_escape "$message\")\"}"
    else
        if [[ -n "$component" ]]; then
            echo "[$timestamp] $level [$component] $message"
        else
            echo "[$timestamp] $level $message"
        fi
    fi
}
```
