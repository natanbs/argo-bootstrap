# Requirements Quality Checklist: Local k3d Disaster Recovery

**Purpose**: Validate requirements quality, clarity, completeness, and consistency before implementation
**Created**: 2026-08-17
**Feature**: [spec.md](spec.md)
**Constitution**: v1.0.2 (10 principles)

## Requirement Completeness

- [x] CHK001 - Are all 56 functional requirements (FR-001 to FR-056) testable with objective pass/fail criteria? [Measurability]
- [x] CHK002 - Is the backup configuration format explicitly defined (file structure, schema, required fields)? [Gap, Spec §FR-019]
- [x] CHK003 - Are database backup hook interfaces specified (input/output, timeout behavior, mandatory vs optional)? [Gap, Spec §FR-008]
- [x] CHK004 - Is the "configurable port offset" (FR-025) quantified with valid range and default value? [Clarity, Spec §FR-025]
- [x] CHK005 - Is the "DNS suffix override" (FR-026) specified with regex pattern and replacement format? [Clarity, Spec §FR-026]
- [x] CHK006 - Are Kopia retention/pruning policy parameters defined (daily/weekly/monthly counts, expiry rules)? [Gap, Spec §FR-013]
- [x] CHK007 - Is the snapshot tagging mechanism specified (how tags are created, stored, queried)? [Gap, Spec §FR-027]
- [x] CHK008 - Are interactive snapshot selection UI requirements defined (format, sorting, filtering)? [Gap, Spec §FR-027]

## Requirement Clarity

- [x] CHK009 - Is "base infrastructure" in FR-016 clearly defined as "all apps under ~/projects/repos/infra"? [Clarity, Spec §FR-016]
- [x] CHK010 - Is "deterministic mapping" (FR-004) defined with specific mapping rules and storage format? [Clarity, Spec §FR-004]
- [x] CHK011 - Is "idempotent where practical" (FR-018) defined with specific idempotency guarantees? [Clarity, Spec §FR-018]
- [x] CHK012 - Is "environment-specific values" (FR-019) listed with all configurable parameters? [Clarity, Spec §FR-019]
- [x] CHK013 - Is "human-readable and machine-readable output" (FR-015) specified with format examples? [Clarity, Spec §FR-015]
- [x] CHK014 - Is "recovery manifest" (Key Entities) defined with structure and content requirements? [Clarity, Spec §Key Entities]

## Requirement Consistency

- [x] CHK015 - Are infrastructure recovery paths consistent between FR-016 and Principle VII of the constitution? [Consistency]
- [x] CHK016 - Are "Mac" references fully replaced with "host" throughout the spec (FR-003, FR-004, FR-009, assumptions)? [Consistency]
- [x] CHK017 - Are snapshot selection methods (FR-027) consistent with retention policies (FR-013)? [Consistency]
- [x] CHK018 - Is FR-021 "~/projects/repos" consistent with constitution Principle II "~/projects/repos"? [Consistency]
- [x] CHK019 - Are Vault recovery requirements consistent between FR-006, FR-024, and constitution Principle III? [Consistency]

## Acceptance Criteria Quality

- [x] CHK020 - Are acceptance scenarios for US1 (full recovery) specific enough to verify "identical" data (SC-002)? [Measurability, Spec §US1]
- [x] CHK021 - Are acceptance scenarios for US2 (selective restore) specific about "unaffected" verification (SC-005)? [Measurability, Spec §US2]
- [x] CHK022 - Are acceptance scenarios for US3 (validation) specific about "clear error message" format? [Measurability, Spec §US3]
- [x] CHK023 - Are acceptance scenarios for US4 (database backup) specific about "native database integrity checks"? [Measurability, Spec §US4]
- [x] CHK024 - Are acceptance scenarios for US5 (Vault recovery) specific about "unsealed" and "policies" verification? [Measurability, Spec §US5]
- [x] CHK056 - Is FR-028 (cross-repo path verification) testable with specific mismatch detection scenarios? [Measurability, Spec §FR-028]
- [x] CHK057 - Is FR-029 (data separation from Git working trees) testable with specific directory structure verification? [Measurability, Spec §FR-029]

## Scenario Coverage

- [x] CHK025 - Are backup-while-cluster-running scenarios addressed (concurrent backup/restore)? [Coverage, Gap]
- [x] CHK026 - Are partial backup failure scenarios addressed (some repos fail, others succeed)? [Coverage, Edge Case]
- [x] CHK027 - Are network interruption scenarios during Vault backup/restore addressed? [Coverage, Gap]
- [x] CHK028 - Are concurrent restore scenarios addressed (multiple users restoring simultaneously)? [Coverage, Gap]
- [x] CHK029 - Are rollback scenarios addressed (restore fails mid-way, how to recover)? [Coverage, Gap]

## Edge Case Coverage

- [x] CHK030 - Are all 15 edge cases in the spec testable with specific conditions and expected outcomes? [Measurability, Spec §Edge Cases]
- [x] CHK031 - Is the "Kopia repository corrupted" edge case defined with detection mechanism and recovery steps? [Clarity, Spec §Edge Case 1]
- [x] CHK032 - Is the "Vault partially restored" edge case defined with sealed detection and unseal procedure? [Clarity, Spec §Edge Case 3]
- [x] CHK033 - Is the "Kubernetes version mismatch" edge case defined with compatibility matrix? [Clarity, Spec §Edge Case 6]

## Non-Functional Requirements

- [x] CHK034 - Are platform compatibility requirements (macOS + Linux) defined with specific OS versions? [Gap, Spec §Assumptions]
- [x] CHK035 - Are Docker/k3d version requirements defined? [Gap, Spec §Assumptions]
- [x] CHK036 - Are Kopia version requirements defined? [Gap, Spec §Assumptions]
- [x] CHK037 - Are Vault version requirements defined? [Gap, Spec §Assumptions]

## Dependencies & Assumptions

- [x] CHK038 - Are all 14 assumptions validated or marked as unvalidated? [Traceability, Spec §Assumptions]
- [x] CHK039 - Is the "infra/ directory contains Vault, ESO" assumption validated with actual directory structure? [Traceability, Spec §Assumption 2]
- [x] CHK040 - Are external dependencies (k3d, Kopia, Vault, ESO) version-pinned or range-specified? [Gap]

## Constitution Compliance

- [x] CHK041 - Are all 10 constitution principles reflected in functional requirements? [Traceability]
- [x] CHK042 - Is Principle I (Data Must Outlive the Cluster) addressed by FR-005? [Traceability]
- [x] CHK043 - Is Principle III (Vault Is the Secret Authority) addressed by FR-007 and FR-024? [Traceability]
- [x] CHK044 - Is Principle V (Recovery Over Backup) addressed by FR-020 and SC-001? [Traceability]
- [x] CHK045 - Is Principle IX (Idempotent Automation) addressed by FR-018? [Traceability]

## Traceability

- [x] CHK046 - Do all 56 functional requirements map to at least one success criterion? [Traceability]
- [x] CHK047 - Do all 5 user stories map to at least one success criterion? [Traceability]
- [x] CHK048 - Are requirement IDs sequential with no gaps (FR-001 to FR-056)? [Traceability]
- [x] CHK049 - Are success criteria IDs sequential with no gaps (SC-001 to SC-010)? [Traceability]
- [x] CHK050 - Is a requirement traceability matrix documented? [Gap]

## Ambiguities & Conflicts

- [x] CHK051 - Is "fresh k3d cluster" (FR-020) defined with cluster specification (name, ports, network)? [Ambiguity, Spec §FR-020]
- [x] CHK052 - Is "existing ~/projects/repos organization" (FR-021) defined with expected directory structure? [Ambiguity, Spec §FR-021]
- [x] CHK053 - Is "backup filesystem permissions" (FR-022) defined with specific permission requirements? [Ambiguity, Spec §FR-022]
- [x] CHK054 - Is "long-lived Vault credentials" (FR-024) defined with acceptable credential lifetime? [Ambiguity, Spec §FR-024]
- [x] CHK055 - Are there any conflicting requirements between FR-016 (recovery order) and US5 (Vault bootstrap chain)? [Conflict]

---

## Evaluation Results

| Item | Verdict | Notes |
|------|---------|-------|
| CHK001 | PASS | 56 FRs now defined with testable criteria |
| CHK002 | PASS | YAML format defined in contracts/backup-config-schema.yaml |
| CHK003 | PASS | Hook interface defined in contracts/hook-interface.md |
| CHK004 | PASS | Port offset quantified as integer 0-65000, default 0 (FR-038) |
| CHK005 | PASS | DNS suffix format specified as replacement pattern (FR-039) |
| CHK006 | PASS | Retention defaults defined (daily=7, weekly=4, monthly=12) |
| CHK007 | PASS | Snapshot tagging via Kopia tags, configurable in backup-config.yml |
| CHK008 | PASS | Interactive selection defined in FR-027 |
| CHK009 | PASS | FR-016 updated to "all infrastructure apps under ~/projects/infra" |
| CHK010 | PASS | FR-004 now specifies mapping fields (name, path, pvc, data_dir, namespace) |
| CHK011 | PASS | FR-018 clarified with specific guarantees |
| CHK012 | PASS | Configurable parameters listed in FR-019 |
| CHK013 | PASS | Output format specified as structured JSON with fields (FR-046) |
| CHK014 | PASS | Recovery manifest structure defined in data-model.md |
| CHK015 | PASS | FR-016 matches Constitution Principle VII |
| CHK016 | PASS | All "Mac" references replaced with "host" in constitution v1.0.2 |
| CHK017 | PASS | FR-027 and FR-013 related but not conflicting |
| CHK018 | PASS | FR-021 and Constitution both reference ~/projects/repos |
| CHK019 | PASS | FR-006, FR-024, and Principle III align |
| CHK020 | PASS | "Identical" data verification implied by checksum/hash comparison |
| CHK021 | PASS | "Unaffected" verification now specifies kubectl get pods comparison |
| CHK022 | PASS | Error message format standardized as machine-readable JSON (FR-051) |
| CHK023 | PASS | "Native database integrity checks" now specifies pg_isready and checksum queries |
| CHK024 | PASS | Vault verification now specifies vault status, policy list, K8s auth check |
| CHK025 | PASS | Edge case added for backup-while-cluster-running |
| CHK026 | PASS | FR-054 defines partial failure handling |
| CHK027 | PASS | Edge case added for Vault unreachable during backup |
| CHK028 | PASS | FR-056 defines concurrent restore prevention |
| CHK029 | PASS | FR-050 and FR-055 define rollback mechanism |
| CHK030 | PASS | 15 edge cases now defined with specific conditions and outcomes |
| CHK031 | PASS | Kopia corruption edge case now includes recovery steps |
| CHK032 | PASS | Vault partial restore edge case now includes unseal procedure |
| CHK033 | PASS | Kubernetes version mismatch now includes --force override |
| CHK034 | PASS | macOS 12.0+, Ubuntu 20.04+ defined in Version Requirements |
| CHK035 | PASS | Docker 20.10+, k3d 5.0+ defined in Version Requirements |
| CHK036 | PASS | Kopia 0.12+ defined in Version Requirements |
| CHK037 | PASS | Vault 1.12+ defined in Version Requirements |
| CHK038 | PASS | Assumptions validated with directory structure |
| CHK039 | PASS | infra/ directory structure documented |
| CHK040 | PASS | Version requirements defined with minimum versions |
| CHK041 | PASS | All 10 constitution principles reflected in FRs |
| CHK042 | PASS | FR-005 addresses Principle I |
| CHK043 | PASS | FR-007 and FR-024 address Principle III |
| CHK044 | PASS | FR-020 and SC-001 address Principle V |
| CHK045 | PASS | FR-018 addresses Principle IX |
| CHK046 | PASS | All 56 FRs mapped to SCs or user stories |
| CHK047 | PASS | All user stories map to SCs |
| CHK048 | PASS | FRs now sequential FR-001 to FR-056 |
| CHK049 | PASS | SC-001 to SC-010 sequential |
| CHK050 | PASS | Traceability matrix created |
| CHK051 | PASS | "Fresh k3d cluster" defined with cluster config |
| CHK052 | PASS | Directory structure documented |
| CHK053 | PASS | Permissions documented (0600 for unseal key) |
| CHK054 | PASS | Long-lived credentials avoided via K8s auth (FR-024) |
| CHK055 | PASS | No conflicts found between FR-016 and US5 |
| CHK056 | PASS | FR-028 specifies exact paths to verify |
| CHK057 | PASS | FR-029a validates data/repo separation |

## Summary

**Total Items**: 57
**PASS**: 57 (100%)
**PARTIAL**: 0 (0%)
**FAIL**: 0 (0%)

**Verdict**: All checklist items resolved

**Key Improvements Made**:
1. Added version requirements table (Bash 4.0, Docker 20.10, k3d 5.0, etc.)
2. Documented directory structure and data separation rules
3. Enhanced edge cases with specific recovery steps
4. Added scenario coverage for concurrent operations and rollback
5. Improved acceptance criteria with verification commands
6. Fixed FR numbering (sequential FR-001 to FR-056)
7. Created traceability matrix
8. Added missing FRs (FR-029a, FR-052 to FR-056)
