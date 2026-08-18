# Data Model: Fix Code Review Bugs

**Feature**: 007-fix-code-review-bugs
**Date**: 2026-08-18

## Entities

### Config Override

Represents an environment variable override for a configuration key.

| Field | Type | Description |
|-------|------|-------------|
| key | string | Configuration key (e.g., `kopia.password_env`) |
| env_var | string | Environment variable name (e.g., `KOPIA_PASSWORD_ENV`) |
| value | string | Override value (from environment) |
| source | enum | `env` or `yaml` (where value came from) |

**Validation Rules**:
- If `source` is `env`, value must be non-empty
- If `source` is `yaml`, value comes from YAML file
- Env overrides take priority over YAML values

**State Transitions**:
```
[unset] → [yaml] → [env] (if env var set)
```

### Retention Policy

Represents Kopia snapshot retention settings.

| Field | Type | Description |
|-------|------|-------------|
| latest | integer | Number of most recent snapshots to keep (optional) |
| daily | integer | Number of daily snapshots to keep |
| weekly | integer | Number of weekly snapshots to keep |
| monthly | integer | Number of monthly snapshots to keep |

**Validation Rules**:
- `daily`, `weekly`, `monthly` must be positive integers
- `latest` is optional; if not set, Kopia default applies
- All values must be independently configurable

**State Transitions**:
```
[default] → [configured] → [applied] (via kopia policy set)
```

### Secret Validation Result

Result of validating a config file for inline secrets.

| Field | Type | Description |
|-------|------|-------------|
| passed | boolean | Whether validation passed |
| errors | list | List of validation errors found |
| pattern | string | The secret pattern that was detected (if failed) |

**Validation Rules**:
- Only flag values, not key names
- Key names containing "password" or "secret" are legitimate
- Inline secrets (values containing actual secret data) are flagged

**State Transitions**:
```
[pending] → [passed] or [failed]
```

## Relationships

```
Config Override ──applies to──▶ Config
Retention Policy ──configures──▶ Kopia Repository
Secret Validation ──validates──▶ Config File
```

## Data Flow

```
1. Config file loaded (YAML)
2. Env overrides applied (Config Override)
3. Config validated (Secret Validation)
4. Retention policy applied (Retention Policy)
5. Backup/restore executed
```
