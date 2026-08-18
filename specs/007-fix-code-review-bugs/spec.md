# Feature Specification: Fix Code Review Bugs

**Feature Branch**: `007-fix-code-review-bugs`

**Created**: 2026-08-18

**Status**: Draft

**Input**: User description: "Fix the code review bugs found in the k3d-dr backup/restore implementation — 2 high-severity, 3 medium, and 2 low issues."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Backup and Restore Execute Without False Validation Failures (Priority: P1)

As a platform engineer, I want to run `backup.sh` and `restore.sh` without the secret validation falsely flagging my config keys (like `password_env`) as inline secrets, so that the backup/restore workflow completes successfully.

**Why this priority**: The `validate_no_secrets` false-positive bug blocks ALL backup and restore operations. Without this fix, the entire system is non-functional.

**Independent Test**: Can be tested by running `validate_no_secrets` against a config file containing `password_env: KOPIA_PASSWORD` and confirming it does NOT trigger a validation failure.

**Acceptance Scenarios**:

1. **Given** a backup config with `kopia.password_env: KOPIA_PASSWORD`, **When** `validate_no_secrets` is called, **Then** validation passes without errors.
2. **Given** a backup config with `vault.unseal_key_path: /path/to/key`, **When** `validate_no_secrets` is called, **Then** validation passes without errors.
3. **Given** a backup config with an actual inline secret like `kopia.password: my-super-secret-password`, **When** `validate_no_secrets` is called, **Then** validation fails with a clear error.

---

### User Story 2 - Environment Variable Overrides Are Applied (Priority: P1)

As a platform engineer, I want to override configuration values via environment variables (e.g., `KOPIA_PASSWORD_ENV`, `VAULT_UNSEAL_KEY_PATH`), so that I can configure backup/restore without modifying the YAML config file.

**Why this priority**: The env override system is implemented but silently ignored — `config_get` always re-reads from YAML. This means environment-based configuration is broken.

**Independent Test**: Can be tested by setting `KOPIA_PASSWORD_ENV=my-password` before running `config_load`, then verifying `config_get "kopia.password_env"` returns `my-password` instead of the YAML value.

**Acceptance Scenarios**:

1. **Given** `KOPIA_PASSWORD_ENV=MY_PASSWORD` is set, **When** config is loaded, **Then** `config_get "kopia.password_env"` returns `MY_PASSWORD`.
2. **Given** `VAULT_UNSEAL_KEY_PATH=/custom/path` is set, **When** config is loaded, **Then** `config_get "vault.unseal_key_path"` returns `/custom/path`.
3. **Given** no env overrides are set, **When** config is loaded, **Then** values come from the YAML file as before.

---

### User Story 3 - Vault K8s Auth Uses Correct CA Certificate (Priority: P2)

As a platform engineer, I want the Vault Kubernetes auth setup to provide the actual CA certificate instead of reading from stdin, so that the auth method is configured correctly during restore.

**Why this priority**: The `kubernetes_ca_cert="@"` argument causes Vault CLI to hang or error, breaking Vault K8s auth setup during restore.

**Independent Test**: Can be tested by running the Vault auth setup command and confirming it does not hang waiting for stdin input.

**Acceptance Scenarios**:

1. **Given** a running Vault instance with K8s auth, **When** `_configure_vault_k8s_auth` is called, **Then** the CA certificate is provided directly (not via stdin).
2. **Given** the Vault CLI receives the correct cert, **When** auth is configured, **Then** the command completes without hanging.

---

### User Story 4 - Retention Policy Flags Are Correctly Mapped (Priority: P2)

As a platform engineer, I want `--keep-latest` and `--keep-daily` to be configured independently, so that my retention policy accurately reflects my backup strategy.

**Why this priority**: Currently `--keep-latest` is accidentally set to the same value as `--keep-daily`, which may cause unintended snapshot pruning.

**Independent Test**: Can be tested by setting different values for daily and latest retention and verifying the correct flags are passed to Kopia.

**Acceptance Scenarios**:

1. **Given** `retention.daily=7` and no explicit latest config, **When** `kopia_retention` is called, **Then** `--keep-latest` is set to a sensible default (or omitted) and `--keep-daily` is set to 7.
2. **Given** explicit `retention.latest=30`, **When** `kopia_retention` is called, **Then** `--keep-latest` is set to 30.

---

### User Story 5 - Idempotency Check Works Without Running Pods (Priority: P3)

As a platform engineer, I want the idempotency check to work even when no pod is currently mounted on the PVC, so that the restore process handles the common case where the application hasn't been deployed yet.

**Why this priority**: The current check requires a running pod to exec into, but during restore the application pod typically doesn't exist yet.

**Independent Test**: Can be tested by running the idempotency check against a PVC with no pods attached and confirming it correctly falls through to the restore path.

**Acceptance Scenarios**:

1. **Given** a PVC exists but no pod is mounted, **When** the idempotency check runs, **Then** it falls through (does not error) and proceeds with the restore.
2. **Given** a PVC exists with a running pod that has data, **When** the idempotency check runs, **Then** it detects the data and skips the restore.

---

### Edge Cases

- What happens when `validate_no_secrets` encounters a config with both legitimate key names (containing "password") and actual inline secrets?
- What happens when multiple env overrides are set simultaneously?
- What happens when the Vault CA cert path is invalid during K8s auth setup?
- What happens when retention values are set to 0 for all periods?
- What happens when the PVC exists but has no data and no pod?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `validate_no_secrets` MUST only flag actual secret *values*, not config *key names* that happen to contain words like "password" or "secret"
- **FR-002**: `config_apply_env_overrides` values MUST be consumed by `config_get` for all supported override keys
- **FR-003**: Vault K8s auth setup MUST provide the CA certificate directly rather than reading from stdin
- **FR-004**: `kopia_retention` MUST map `--keep-latest` and `--keep-daily` to independent config values
- **FR-005**: The idempotency check MUST handle the case where no pod is mounted on the PVC
- **FR-006**: Remove dead code in `validate_cross_field` that re-sources config unnecessarily
- **FR-007**: Extract shared JSON/text construction into a helper function to eliminate duplication between stdout and log file output

### Key Entities

- **Config**: Backup/restore configuration loaded from YAML with env override support
- **Validation**: Pre-flight checks that verify config correctness before backup/restore
- **Retention Policy**: Kopia snapshot retention settings (latest, daily, weekly, monthly)
- **Idempotency Check**: Mechanism to detect already-restored data and skip redundant work

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `backup.sh` and `restore.sh` complete successfully with a standard config file containing `password_env` fields
- **SC-002**: Environment variable overrides are reflected in `config_get` output for all supported keys
- **SC-003**: Vault K8s auth setup completes without hanging or reading from stdin
- **SC-004**: `--keep-latest` and `--keep-daily` are independently configurable via retention config
- **SC-005**: Idempotency check completes without error when no pod is mounted on the PVC
- **SC-006**: All modified scripts pass `bash -n` syntax validation
- **SC-007**: Existing unit tests that were passing continue to pass (no regressions)

## Assumptions

- The existing codebase structure and library organization are preserved
- Bash 3.2 compatibility is maintained (no `declare -A`, `declare -g`, `local -n`)
- The fix for `validate_no_secrets` targets the value portion of YAML lines, not the key portion
- Env override support covers the keys already defined in `config_apply_env_overrides` (no new keys)
- The Vault CA cert fix uses the cluster's service account CA cert from the standard path `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
- The `--keep-latest` default when not explicitly configured should not change existing behavior (i.e., if user has not been setting it, the fix should not introduce new pruning)
- Low-severity items (dead code removal, code dedup) are included in scope as they are quick to address and improve maintainability
