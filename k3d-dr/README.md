# k3d-dr: Local k3d Disaster Recovery

**Version**: 1.0  
**Date**: 2026-08-17  
**Feature**: 006-k3d-disaster-recovery

## Overview

k3d-dr is a fully local disaster-recovery system for disposable k3d Kubernetes clusters using Kopia as the sole backup engine. It enables single-command recovery from complete cluster destruction.

## Features

- **Single-command recovery**: Destroy and recreate clusters with one command
- **Encrypted backups**: All data encrypted with AES-256-GCM
- **Selective restore**: Restore specific repositories or volumes
- **Vault integration**: Automatic Vault unseal and recovery
- **Database support**: Native database backup hooks
- **Parallel clusters**: Run backup and production clusters simultaneously
- **Resumable operations**: Continue interrupted backups

## Prerequisites

- macOS 12.0+ or Ubuntu 20.04+
- Docker 20.10+
- k3d 5.0+
- kubectl 1.24+
- Kopia 0.12+
- Vault 1.12+
- Helm 3.10+

## Installation

```bash
# Clone repository
git clone <repository-url>
cd argo-bootstrap

# Make scripts executable
chmod +x k3d-dr/backup.sh k3d-dr/restore.sh
```

## Quick Start

### 1. Configure

Create `backup-config.yml`:

```yaml
version: "1.0"
repositories:
  - name: my-app
    path: ~/projects/repos/my-app
    pvc: my-app-data
    data_dir: /data/my-app
    namespace: default
kopia:
  repository_path: ~/.kopia-repository
  password_env: KOPIA_PASSWORD
  retention:
    daily: 7
    weekly: 4
    monthly: 12
vault:
  namespace: vault
  unseal_key_path: ~/.vault-unseal-key
database_hooks:
  timeout: 300
  mandatory: true
port_offset: 0
dns_suffix: lab=bak
```

### 2. Set Environment Variables

```bash
export KOPIA_PASSWORD="your-secure-password"
```

### 3. Backup

```bash
./k3d-dr/backup.sh -c backup-config.yml
```

### 4. Restore

```bash
# Full restore
./k3d-dr/restore.sh -c backup-config.yml

# Selective restore
./k3d-dr/restore.sh -c backup-config.yml --repo my-app

# Restore from snapshot
./k3d-dr/restore.sh -c backup-config.yml --snapshot abc123
```

## Commands

### backup.sh

```bash
./k3d-dr/backup.sh [OPTIONS]

Options:
  -c, --config FILE    Configuration file (default: backup-config.yml)
  -v, --verbose        Enable debug logging
  --json               Output in JSON format
  --dry-run            Perform validation only, don't backup
  -h, --help           Show this help message
```

### restore.sh

```bash
./k3d-dr/restore.sh [OPTIONS]

Options:
  -c, --config FILE    Configuration file (default: backup-config.yml)
  -r, --repo NAME      Restore specific repository only
  --volume NAME        Restore specific volume only
  -v, --verbose        Enable debug logging
  --json               Output in JSON format
  --rollback           Rollback partial restore
  --snapshot ID        Restore from specific snapshot
  --tag NAME           Restore from tagged snapshot
  -h, --help           Show this help message
```

## Configuration

See [backup-config-schema.yaml](schemas/backup-config-schema.yaml) for full schema.

### Key Settings

- **repositories**: List of repositories to backup
- **kopia**: Kopia repository settings
- **vault**: Vault configuration
- **database_hooks**: Database backup/restore hooks
- **port_offset**: Port offset for parallel clusters
- **dns_suffix**: DNS suffix override for parallel clusters

## Documentation

- [Recovery Procedures](docs/RECOVERY.md)
- [Credential Management](docs/CREDENTIALS.md)
- [Hook Interface](../specs/006-k3d-disaster-recovery/contracts/hook-interface.md)

## Testing

### Unit Tests

```bash
cd k3d-dr/tests
bats unit/
```

### Integration Tests

```bash
cd k3d-dr/tests
bats integration/
```

## Development

### Project Structure

```
k3d-dr/
├── backup.sh              # Main backup script
├── restore.sh             # Main restore script
├── validate_quickstart.sh # Quickstart validation script
├── lib/                   # Shared libraries
│   ├── logging.sh         # Structured logging
│   ├── progress.sh        # Progress reporting
│   ├── lock.sh            # Lock management
│   ├── config.sh          # Configuration loading
│   ├── errors.sh          # Error handling
│   ├── kopia.sh           # Kopia operations
│   ├── vault.sh           # Vault operations
│   ├── k3d.sh             # k3d operations
│   ├── kubernetes.sh      # Kubernetes operations
│   ├── ports.sh           # Port offset utility
│   ├── dns.sh             # DNS suffix utility
│   ├── health.sh          # Health checks
│   ├── state.sh           # State tracking
│   ├── registry.sh        # Registry persistence
│   ├── validation.sh      # Validation library
│   ├── snapshots.sh       # Snapshot management
│   ├── metadata.sh        # Cluster metadata collection
│   └── discovery.sh       # Infrastructure app discovery
├── schemas/               # Validation schemas
│   └── backup-config.yaml
├── hooks/                 # Database hooks
│   ├── db-backup.sh       # Backup hook runner
│   ├── db-restore.sh      # Restore hook runner
│   └── examples/          # Example hooks
├── tests/                 # Test suite
│   ├── unit/              # Unit tests (9 test files)
│   ├── integration/       # Integration tests
│   └── fixtures/          # Test fixtures
└── docs/                  # Documentation
    ├── RECOVERY.md        # Recovery procedures
    └── CREDENTIALS.md     # Credential management
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit changes
4. Push to the branch
5. Create a Pull Request

## License

See [LICENSE](../LICENSE) for details.

## Support

For issues and questions:

1. Check documentation
2. Review troubleshooting guide
3. Open an issue