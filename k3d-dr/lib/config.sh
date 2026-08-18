#!/usr/bin/env bash
# config.sh - Configuration loading and validation library
# FR-019: YAML configuration file (backup-config.yml)
# FR-036: Formal YAML schema validation
# FR-037: Specific error messages for validation failures

set -euo pipefail

# Configuration state
declare CONFIG_FILE=""
declare CONFIG_VERSION=""
declare CONFIG_REPOSITORIES=""
declare CONFIG_KOPIA=""
declare CONFIG_VAULT=""
declare CONFIG_DATABASE_HOOKS=""
declare CONFIG_PORT_OFFSET="0"
declare CONFIG_DNS_SUFFIX=""

# Environment variable overrides (FR-040)
declare KOPIA_PASSWORD_ENV_OVERRIDE=""
declare KOPIA_BACKUP_UNSEAL_KEY_PATH_OVERRIDE=""
declare DATABASE_HOOKS_MANDATORY_OVERRIDE=""

# Validation errors (bash 3.2 compatible: global array instead of namerefs)
declare -a CONFIG_ERRORS=()

# Default values
_get_default() {
    local key="$1"
    case "$key" in
        kopia.retention.daily) echo "7" ;;
        kopia.retention.weekly) echo "4" ;;
        kopia.retention.monthly) echo "12" ;;
        vault.namespace) echo "vault" ;;
        database_hooks.timeout) echo "300" ;;
        database_hooks.mandatory) echo "true" ;;
        port_offset) echo "0" ;;
        *) echo "" ;;
    esac
}

# Load configuration from YAML file
# Usage: config_load <config_file>
config_load() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        echo "Error: Configuration file not found: $config_file" >&2
        return 1
    fi

    if [[ ! -r "$config_file" ]]; then
        echo "Error: Configuration file is not readable: $config_file" >&2
        return 1
    fi

    CONFIG_FILE="$config_file"

    # Check if yq is available
    if ! command -v yq &>/dev/null; then
        echo "Error: yq is required for configuration parsing. Install yq first." >&2
        return 1
    fi

    # Validate YAML syntax
    if ! yq eval '.' "$CONFIG_FILE" &>/dev/null; then
        echo "Error: Invalid YAML syntax in configuration file: $CONFIG_FILE" >&2
        return 1
    fi

    # Load configuration values
    _load_config_values

    # Validate configuration
    config_validate
}

# Load configuration values from YAML
_load_config_values() {
    CONFIG_VERSION="$(yq eval '.version // empty' "$CONFIG_FILE")"

    # Load repositories
    CONFIG_REPOSITORIES="$(yq eval '.repositories | length' "$CONFIG_FILE" 2>/dev/null || echo "0")"

    # Load Kopia settings
    CONFIG_KOPIA="$(yq eval '.kopia.repository_path // empty' "$CONFIG_FILE")"

    # Load Vault settings
    CONFIG_VAULT="$(yq eval '.vault.namespace // empty' "$CONFIG_FILE")"

    # Load database hook settings
    CONFIG_DATABASE_HOOKS="$(yq eval '.database_hooks.timeout // empty' "$CONFIG_FILE")"

    # Load port offset
    CONFIG_PORT_OFFSET="$(yq eval '.port_offset // empty' "$CONFIG_FILE")"
    [[ -z "$CONFIG_PORT_OFFSET" ]] && CONFIG_PORT_OFFSET="$(_get_default "port_offset")"

    # Load DNS suffix
    CONFIG_DNS_SUFFIX="$(yq eval '.dns_suffix // empty' "$CONFIG_FILE")"
}

# Validate configuration against schema
config_validate() {
    # Clear previous errors (bash 3.2 compatible: global array)
    CONFIG_ERRORS=()

    # Validate version
    if [[ -z "$CONFIG_VERSION" ]]; then
        CONFIG_ERRORS+=("version: Required field is missing")
    elif [[ "$CONFIG_VERSION" != "1.0" ]]; then
        CONFIG_ERRORS+=("version: Unsupported version '$CONFIG_VERSION'. Expected '1.0'")
    fi

    # Validate repositories
    if [[ "$CONFIG_REPOSITORIES" -eq 0 ]]; then
        CONFIG_ERRORS+=("repositories: At least one repository must be defined")
    fi

    # Validate each repository
    for i in $(seq 0 $((CONFIG_REPOSITORIES - 1))); do
        _validate_repository "$i"
    done

    # Validate Kopia settings
    _validate_kopia

    # Validate Vault settings
    _validate_vault

    # Validate database hook settings
    _validate_database_hooks

    # Validate port offset
    _validate_port_offset

    # Validate DNS suffix
    _validate_dns_suffix

    # Report validation errors
    if [[ ${#CONFIG_ERRORS[@]} -gt 0 ]]; then
        echo "Configuration validation errors:" >&2
        for error in "${CONFIG_ERRORS[@]}"; do
            echo "  - $error" >&2
        done
        return 1
    fi

    return 0
}

# Validate repository configuration (bash 3.2 compatible: global CONFIG_ERRORS array)
_validate_repository() {
    local index="$1"

    local name path pvc data_dir namespace
    name="$(yq eval ".repositories[$index].name // empty" "$CONFIG_FILE")"
    path="$(yq eval ".repositories[$index].path // empty" "$CONFIG_FILE")"
    pvc="$(yq eval ".repositories[$index].pvc // empty" "$CONFIG_FILE")"
    data_dir="$(yq eval ".repositories[$index].data_dir // empty" "$CONFIG_FILE")"
    namespace="$(yq eval ".repositories[$index].namespace // empty" "$CONFIG_FILE")"

    [[ -z "$name" ]] && CONFIG_ERRORS+=("repositories[$index].name: Required field is missing")
    [[ -z "$path" ]] && CONFIG_ERRORS+=("repositories[$index].path: Required field is missing")
    [[ -z "$pvc" ]] && CONFIG_ERRORS+=("repositories[$index].pvc: Required field is missing")
    [[ -z "$data_dir" ]] && CONFIG_ERRORS+=("repositories[$index].data_dir: Required field is missing")
    [[ -z "$namespace" ]] && CONFIG_ERRORS+=("repositories[$index].namespace: Required field is missing")

    # Validate path is absolute
    if [[ -n "$path" && "$path" != /* ]]; then
        CONFIG_ERRORS+=("repositories[$index].path: Must be an absolute path (got '$path')")
    fi

    # Validate data_dir is absolute
    if [[ -n "$data_dir" && "$data_dir" != /* ]]; then
        CONFIG_ERRORS+=("repositories[$index].data_dir: Must be an absolute path (got '$data_dir')")
    fi

    # Validate data_dir is not subdirectory of path (FR-029a)
    if [[ -n "$path" && -n "$data_dir" ]]; then
        if [[ "$data_dir" == "$path"* ]]; then
            CONFIG_ERRORS+=("repositories[$index].data_dir: Must not be a subdirectory of path (FR-029a)")
        fi
    fi
}

# Validate Kopia configuration (bash 3.2 compatible: global CONFIG_ERRORS array)
_validate_kopia() {
    local repository_path password_env
    repository_path="$(yq eval '.kopia.repository_path // empty' "$CONFIG_FILE")"
    password_env="$(yq eval '.kopia.password_env // empty' "$CONFIG_FILE")"

    [[ -z "$repository_path" ]] && CONFIG_ERRORS+=("kopia.repository_path: Required field is missing")
    [[ -z "$password_env" ]] && CONFIG_ERRORS+=("kopia.password_env: Required field is missing")

    # Validate repository_path is absolute
    if [[ -n "$repository_path" && "$repository_path" != /* ]]; then
        CONFIG_ERRORS+=("kopia.repository_path: Must be an absolute path (got '$repository_path')")
    fi

    # Validate retention values
    local daily weekly monthly
    daily="$(yq eval '.kopia.retention.daily // empty' "$CONFIG_FILE")"
    weekly="$(yq eval '.kopia.retention.weekly // empty' "$CONFIG_FILE")"
    monthly="$(yq eval '.kopia.retention.monthly // empty' "$CONFIG_FILE")"

    if [[ -n "$daily" ]] && ! [[ "$daily" =~ ^[0-9]+$ ]]; then
        CONFIG_ERRORS+=("kopia.retention.daily: Must be a positive integer (got '$daily')")
    fi
    if [[ -n "$weekly" ]] && ! [[ "$weekly" =~ ^[0-9]+$ ]]; then
        CONFIG_ERRORS+=("kopia.retention.weekly: Must be a positive integer (got '$weekly')")
    fi
    if [[ -n "$monthly" ]] && ! [[ "$monthly" =~ ^[0-9]+$ ]]; then
        CONFIG_ERRORS+=("kopia.retention.monthly: Must be a positive integer (got '$monthly')")
    fi
}

# Validate Vault configuration (bash 3.2 compatible: global CONFIG_ERRORS array)
_validate_vault() {
    local unseal_key_path
    unseal_key_path="$(yq eval '.vault.unseal_key_path // empty' "$CONFIG_FILE")"

    # Validate unseal_key_path is absolute if provided
    if [[ -n "$unseal_key_path" && "$unseal_key_path" != /* ]]; then
        CONFIG_ERRORS+=("vault.unseal_key_path: Must be an absolute path (got '$unseal_key_path')")
    fi
}

# Validate database hook configuration (bash 3.2 compatible: global CONFIG_ERRORS array)
_validate_database_hooks() {
    local timeout mandatory
    timeout="$(yq eval '.database_hooks.timeout // empty' "$CONFIG_FILE")"
    mandatory="$(yq eval '.database_hooks.mandatory // empty' "$CONFIG_FILE")"

    if [[ -n "$timeout" ]] && ! [[ "$timeout" =~ ^[0-9]+$ ]]; then
        CONFIG_ERRORS+=("database_hooks.timeout: Must be a positive integer (got '$timeout')")
    fi

    if [[ -n "$mandatory" ]] && [[ "$mandatory" != "true" && "$mandatory" != "false" ]]; then
        CONFIG_ERRORS+=("database_hooks.mandatory: Must be 'true' or 'false' (got '$mandatory')")
    fi
}

# Validate port offset (bash 3.2 compatible: global CONFIG_ERRORS array)
_validate_port_offset() {
    if [[ -n "$CONFIG_PORT_OFFSET" ]]; then
        if ! [[ "$CONFIG_PORT_OFFSET" =~ ^[0-9]+$ ]]; then
            CONFIG_ERRORS+=("port_offset: Must be a non-negative integer (got '$CONFIG_PORT_OFFSET')")
        elif [[ "$CONFIG_PORT_OFFSET" -gt 65000 ]]; then
            CONFIG_ERRORS+=("port_offset: Must be between 0 and 65000 (got '$CONFIG_PORT_OFFSET')")
        fi
    fi
}

# Validate DNS suffix (bash 3.2 compatible: global CONFIG_ERRORS array)
_validate_dns_suffix() {
    if [[ -n "$CONFIG_DNS_SUFFIX" ]]; then
        # DNS suffix should be in format: <original>=<replacement>
        if [[ "$CONFIG_DNS_SUFFIX" != *"="* ]]; then
            CONFIG_ERRORS+=("dns_suffix: Must be in format '<original>=<replacement>' (got '$CONFIG_DNS_SUFFIX')")
        fi
    fi
}

# Get configuration value with default
# Usage: config_get <key> [default_value]
config_get() {
    local key="$1"
    local default="${2:-}"

    local value=""
    case "$key" in
        repositories.count)
            value="$CONFIG_REPOSITORIES"
            ;;
        kopia.repository_path)
            value="$(yq eval '.kopia.repository_path // empty' "$CONFIG_FILE")"
            ;;
        kopia.password_env)
            # Check env override first (FR-002)
            value="${KOPIA_PASSWORD_ENV_OVERRIDE:-}"
            if [[ -z "$value" ]]; then
                value="$(yq eval '.kopia.password_env // empty' "$CONFIG_FILE")"
            fi
            ;;
        kopia.retention.daily)
            value="$(yq eval '.kopia.retention.daily // empty' "$CONFIG_FILE")"
            [[ -z "$value" ]] && value="$(_get_default "kopia.retention.daily")"
            ;;
        kopia.retention.weekly)
            value="$(yq eval '.kopia.retention.weekly // empty' "$CONFIG_FILE")"
            [[ -z "$value" ]] && value="$(_get_default "kopia.retention.weekly")"
            ;;
        kopia.retention.monthly)
            value="$(yq eval '.kopia.retention.monthly // empty' "$CONFIG_FILE")"
            [[ -z "$value" ]] && value="$(_get_default "kopia.retention.monthly")"
            ;;
        vault.namespace)
            value="$(yq eval '.vault.namespace // empty' "$CONFIG_FILE")"
            [[ -z "$value" ]] && value="$(_get_default "vault.namespace")"
            ;;
        vault.unseal_key_path)
            # Check env override first (FR-002)
            value="${KOPIA_BACKUP_UNSEAL_KEY_PATH_OVERRIDE:-}"
            if [[ -z "$value" ]]; then
                value="$(yq eval '.vault.unseal_key_path // empty' "$CONFIG_FILE")"
            fi
            ;;
        database_hooks.timeout)
            value="$(yq eval '.database_hooks.timeout // empty' "$CONFIG_FILE")"
            [[ -z "$value" ]] && value="$(_get_default "database_hooks.timeout")"
            ;;
        database_hooks.mandatory)
            # Check env override first (FR-002)
            value="${DATABASE_HOOKS_MANDATORY_OVERRIDE:-}"
            if [[ -z "$value" ]]; then
                value="$(yq eval '.database_hooks.mandatory // empty' "$CONFIG_FILE")"
                [[ -z "$value" ]] && value="$(_get_default "database_hooks.mandatory")"
            fi
            ;;
        port_offset)
            value="$CONFIG_PORT_OFFSET"
            ;;
        dns_suffix)
            value="$CONFIG_DNS_SUFFIX"
            ;;
        *)
            value="$default"
            ;;
    esac

    [[ -z "$value" ]] && value="$default"
    echo "$value"
}

# Get repository configuration by index
# Usage: config_get_repository <index> <field>
config_get_repository() {
    local index="$1"
    local field="$2"

    yq eval ".repositories[$index].$field // empty" "$CONFIG_FILE"
}

# Get all repository names
# Usage: config_get_repository_names
config_get_repository_names() {
    yq eval '.repositories[].name' "$CONFIG_FILE" 2>/dev/null || echo ""
}

# Apply environment variable overrides (FR-040)
# All configurable values can be overridden via KOPIA_BACKUP_* env vars
# Usage: config_apply_env_overrides
config_apply_env_overrides() {
    # Override kopia.repository_path if environment variable is set
    if [[ -n "${KOPIA_BACKUP_REPOSITORY_PATH:-}" ]]; then
        CONFIG_KOPIA="$KOPIA_BACKUP_REPOSITORY_PATH"
    fi

    # Override kopia.password_env if environment variable is set
    if [[ -n "${KOPIA_BACKUP_PASSWORD_ENV:-}" ]]; then
        # Store for use during kopia init
        KOPIA_PASSWORD_ENV_OVERRIDE="$KOPIA_BACKUP_PASSWORD_ENV"
    fi

    # Override vault.namespace if environment variable is set
    if [[ -n "${KOPIA_BACKUP_VAULT_NAMESPACE:-}" ]]; then
        CONFIG_VAULT="$KOPIA_BACKUP_VAULT_NAMESPACE"
    fi

    # Override vault.unseal_key_path if environment variable is set
    if [[ -n "${KOPIA_BACKUP_VAULT_UNSEAL_KEY_PATH:-}" ]]; then
        KOPIA_BACKUP_UNSEAL_KEY_PATH_OVERRIDE="$KOPIA_BACKUP_VAULT_UNSEAL_KEY_PATH"
    fi

    # Override database_hooks.timeout if environment variable is set
    if [[ -n "${KOPIA_BACKUP_DB_HOOKS_TIMEOUT:-}" ]]; then
        CONFIG_DATABASE_HOOKS="$KOPIA_BACKUP_DB_HOOKS_TIMEOUT"
    fi

    # Override database_hooks.mandatory if environment variable is set
    if [[ -n "${KOPIA_BACKUP_DB_HOOKS_MANDATORY:-}" ]]; then
        DATABASE_HOOKS_MANDATORY_OVERRIDE="$KOPIA_BACKUP_DB_HOOKS_MANDATORY"
    fi

    # Override port_offset if environment variable is set
    if [[ -n "${KOPIA_BACKUP_PORT_OFFSET:-}" ]]; then
        CONFIG_PORT_OFFSET="$KOPIA_BACKUP_PORT_OFFSET"
    fi

    # Override dns_suffix if environment variable is set
    if [[ -n "${KOPIA_BACKUP_DNS_SUFFIX:-}" ]]; then
        CONFIG_DNS_SUFFIX="$KOPIA_BACKUP_DNS_SUFFIX"
    fi
}

# Export functions
export -f config_load config_validate config_get config_get_repository config_get_repository_names config_apply_env_overrides
export CONFIG_FILE CONFIG_VERSION CONFIG_REPOSITORIES CONFIG_KOPIA CONFIG_VAULT CONFIG_DATABASE_HOOKS CONFIG_PORT_OFFSET CONFIG_DNS_SUFFIX
export KOPIA_PASSWORD_ENV_OVERRIDE KOPIA_BACKUP_UNSEAL_KEY_PATH_OVERRIDE DATABASE_HOOKS_MANDATORY_OVERRIDE