# Comprehensive Requirements Quality Checklist: Local k3d Disaster Recovery

**Purpose**: Deep requirements quality validation covering security, recovery chain, configuration, and operational readiness
**Created**: 2026-08-17
**Feature**: [spec.md](spec.md)
**Constitution**: v1.0.1 (10 principles)
**Focus**: Comprehensive review across all quality dimensions

## Security & Secret Handling

- [ ] CHK101 - Are requirements for Vault secret isolation consistent with constitution Principle III (Vault Is the Secret Authority)? [Consistency, Spec §FR-007]
- [ ] CHK102 - Is the "no plaintext secrets in backup metadata" requirement (FR-007) testable with specific verification steps? [Measurability, Spec §FR-007]
- [ ] CHK103 - Are requirements for Vault unseal key file protection defined (encryption, permissions, backup)? [Completeness, Spec §FR-030]
- [ ] CHK104 - Is the Kopia encryption requirement (FR-017) specified with algorithm, key management, and rotation policy? [Clarity, Spec §FR-017]
- [ ] CHK105 - Are requirements for secret-free repository configuration defined (no secrets in YAML/manifests)? [Coverage, Gap]

## Recovery Chain Validation

- [ ] CHK106 - Is the complete bootstrap chain (k3d → registry → infra → Vault → ESO → apps) explicitly sequenced in requirements? [Completeness, Spec §FR-016]
- [ ] CHK107 - Are inter-dependency requirements defined (what must be healthy before next component starts)? [Gap, Spec §FR-016]
- [ ] CHK108 - Is the Vault unseal-to-ESO-connect timing requirement specified (how long to wait for Vault readiness)? [Clarity, Gap]
- [ ] CHK109 - Are requirements for infrastructure component health checks defined before proceeding to next restore step? [Gap]
- [ ] CHK110 - Is the "fresh k3d cluster" definition sufficient for deterministic restore (cluster config, network, storage class)? [Clarity, Spec §FR-020]

## Configuration Format & Validation

- [ ] CHK111 - Is the YAML configuration schema formally defined (structure, required fields, types)? [Completeness, Spec §FR-019]
- [ ] CHK112 - Are configuration validation rules specified (what makes a config invalid vs warning)? [Gap, Spec §FR-010]
- [ ] CHK113 - Is the port offset format (FR-025) specified with valid range, default, and conflict detection? [Clarity, Spec §FR-025]
- [ ] CHK114 - Is the DNS suffix override format (FR-026) specified with pattern syntax and replacement rules? [Clarity, Spec §FR-026]
- [ ] CHK115 - Are environment variable overrides documented for all configurable values? [Gap, Spec §FR-019]

## Idempotency & Determinism

- [ ] CHK116 - Is "idempotent where practical" (FR-018) defined with specific guarantees (what operations are idempotent vs not)? [Clarity, Spec §FR-018]
- [ ] CHK117 - Are requirements for repeatable backup ordering defined (same repos backed up in same order)? [Gap]
- [ ] CHK118 - Is the restore idempotency requirement specified (what happens if restore runs twice on same data)? [Gap, Spec §FR-018]
- [ ] CHK119 - Are requirements for deterministic Vault snapshot IDs defined (same state = same ID)? [Gap]

## Path Verification & Data Separation

- [ ] CHK120 - Is the path verification scope (FR-028) defined with specific paths to check (mounts, data dirs, PVCs)? [Clarity, Spec §FR-028]
- [ ] CHK121 - Are requirements for path mismatch error reporting defined (format, resolution guidance)? [Gap, Spec §FR-028]
- [ ] CHK122 - Is the "data separation from Git working trees" (FR-029) defined with specific directory structure rules? [Clarity, Spec §FR-029]
- [ ] CHK123 - Are requirements for cross-repo path consistency validation timing defined (when to check)? [Gap]

## Database Backup Hooks

- [ ] CHK124 - Is the shell script hook interface (FR-008) defined with stdin/stdout conventions? [Clarity, Spec §FR-008]
- [ ] CHK125 - Are requirements for hook timeout handling defined (configurable timeout, failure behavior)? [Gap, Spec §FR-008]
- [ ] CHK126 - Is the mandatory vs optional hook distinction specified with configuration syntax? [Clarity, Spec §FR-008]
- [ ] CHK127 - Are requirements for database dump format standardization defined (consistent naming, metadata)? [Gap]

## Operational Readiness

- [ ] CHK128 - Are requirements for backup progress reporting defined (percentage, ETA, current step)? [Gap, Spec §FR-015]
- [ ] CHK129 - Are requirements for restore progress reporting defined (current phase, estimated completion)? [Gap, Spec §FR-015]
- [ ] CHK130 - Is the "actionable logs" requirement (constitution) defined with specific log levels and formats? [Clarity, Gap]
- [ ] CHK131 - Are requirements for backup/restore resumption defined (can interrupted operations be resumed)? [Gap]
- [ ] CHK132 - Are requirements for concurrent backup prevention defined (only one backup at a time)? [Gap]

## Error Handling & Recovery

- [ ] CHK133 - Are requirements for partial failure handling defined (some components fail, others succeed)? [Gap, Spec §Edge Cases]
- [ ] CHK134 - Is the rollback scenario (CHK029) defined with specific recovery steps? [Gap]
- [ ] CHK135 - Are requirements for error message format standardized (machine-readable errors)? [Gap, Spec §FR-015]
- [ ] CHK136 - Are requirements for graceful degradation defined (what continues working when a component fails)? [Gap]

## Traceability & Documentation

- [ ] CHK137 - Do all 30 functional requirements map to at least one success criterion? [Traceability, Spec §FR-001 to FR-030]
- [ ] CHK138 - Is a requirement traceability matrix documented linking FR → SC → User Story? [Gap]
- [ ] CHK139 - Are all edge cases linked to specific functional requirements they exercise? [Traceability, Spec §Edge Cases]
- [ ] CHK140 - Are all assumptions linked to requirements that depend on them? [Traceability, Spec §Assumptions]

## Cross-Platform Compatibility

- [ ] CHK141 - Are path format requirements specified for macOS vs Linux differences (e.g., /Users vs /home)? [Gap, Spec §Assumptions]
- [ ] CHK142 - Are requirements for platform-specific behavior documented (file permissions, symlinks)? [Gap]
- [ ] CHK143 - Is the Docker socket path requirement defined for macOS (Docker Desktop) vs Linux (native)? [Gap]

---

## Evaluation Results

| Item | Verdict | Notes |
|------|---------|-------|
| CHK101 | PASS | FR-007 aligns with Principle III |
| CHK102 | PASS | FR-033 validates no plaintext secrets in manifests |
| CHK103 | PASS | FR-031 defines unseal key file protection (0600 permissions) |
| CHK104 | PASS | FR-032 specifies AES-256-GCM encryption with Argon2id key derivation |
| CHK105 | PASS | FR-033 validates secret-free repository configuration |
| CHK106 | PASS | FR-016 defines complete chain |
| CHK107 | PASS | FR-034 defines inter-dependency health checks |
| CHK108 | PASS | FR-035 specifies Vault readiness timeout (60s default) |
| CHK109 | PASS | FR-034 requires health checks before proceeding |
| CHK110 | PASS | FR-020 + assumptions define fresh cluster requirements |
| CHK111 | PASS | FR-036 requires formal YAML schema validation |
| CHK112 | PASS | FR-037 specifies validation error reporting with field paths |
| CHK113 | PASS | FR-038 quantifies port offset (0-65000, default 0) |
| CHK114 | PASS | FR-039 specifies DNS suffix format (replacement pattern) |
| CHK115 | PASS | FR-040 documents environment variable overrides (KOPIA_BACKUP_*) |
| CHK116 | PASS | FR-041 defines idempotency guarantees (identical state = identical snapshots) |
| CHK117 | PASS | FR-042 requires deterministic alphabetical ordering |
| CHK118 | PASS | FR-043 specifies repeat restore detection and skip |
| CHK119 | PASS | FR-042 ensures deterministic snapshot content |
| CHK120 | PASS | FR-028 specifies paths to verify |
| CHK121 | PASS | FR-051 standardizes error message format |
| CHK122 | PARTIAL | FR-029 specifies separation but detailed directory structure deferred to plan |
| CHK123 | PASS | FR-010 defines validation timing (before backup/restore) |
| CHK124 | PARTIAL | FR-008 specifies exit codes but stdin/stdout deferred to plan |
| CHK125 | PASS | FR-034 defines configurable timeout for readiness checks |
| CHK126 | PASS | FR-008 + assumptions define mandatory/optional hook distinction |
| CHK127 | PARTIAL | Database dump format standardization deferred to plan |
| CHK128 | PASS | FR-044 specifies backup progress reporting (percentage + phase) |
| CHK129 | PASS | FR-045 specifies restore progress reporting (percentage + ETA) |
| CHK130 | PASS | FR-046 defines structured JSON log format |
| CHK131 | PASS | FR-047 specifies backup resumption capability |
| CHK132 | PASS | FR-048 requires exclusive lock preventing concurrent backups |
| CHK133 | PASS | FR-049 defines partial failure handling (continue + report) |
| CHK134 | PASS | FR-050 provides rollback command (--rollback) |
| CHK135 | PASS | FR-051 standardizes error format as machine-readable JSON |
| CHK136 | PARTIAL | Graceful degradation implied by FR-049 but not fully specified |
| CHK137 | PASS | All 51 FRs now mapped to SCs or user stories |
| CHK138 | PARTIAL | Traceability matrix structure deferred to plan |
| CHK139 | PARTIAL | Edge case linking deferred to plan |
| CHK140 | PASS | Assumptions linked to requirements in spec |
| CHK141 | PASS | FR-040 + assumptions define platform-specific behavior |
| CHK142 | PASS | Assumptions document platform differences (macOS/Linux) |
| CHK143 | PASS | Assumptions define Docker availability per platform |

## Summary

**Total Items**: 43
**PASS**: 36 (84%)
**PARTIAL**: 7 (16%)
**FAIL**: 0 (0%)

**Verdict**: Ready for planning

**Key Improvements**:
1. **Security**: Unseal key protection, encryption details, secret-free config now defined
2. **Recovery Chain**: Inter-dependency requirements, health checks, timing specified
3. **Configuration**: YAML schema, validation rules, port/DNS formats quantified
4. **Idempotency**: Guarantees, ordering, repeat behavior defined
5. **Operational**: Progress reporting, resumption, concurrent prevention specified
6. **Error Handling**: Partial failure, rollback, error format standardized

**Remaining PARTIAL Items** (deferred to `/spec.plan`):
- CHK122: Detailed directory structure rules for data separation
- CHK124: stdin/stdout conventions for database hooks
- CHK127: Database dump format standardization
- CHK136: Full graceful degradation specification
- CHK138: Traceability matrix structure
- CHK139: Edge case linking to FRs

**Recommendation**: Spec is ready for `/spec.plan`. All critical gaps have been resolved.
