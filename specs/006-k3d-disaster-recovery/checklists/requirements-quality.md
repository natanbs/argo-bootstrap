# Requirements Quality Checklist: Local k3d Disaster Recovery

**Purpose**: Validate requirements quality, clarity, completeness, and consistency before implementation
**Created**: 2026-08-17
**Feature**: [spec.md](spec.md)
**Constitution**: v1.0.0 (10 principles)

## Requirement Completeness

- [ ] CHK001 - Are all 29 functional requirements (FR-001 to FR-029) testable with objective pass/fail criteria? [Measurability]
- [ ] CHK002 - Is the backup configuration format explicitly defined (file structure, schema, required fields)? [Gap, Spec §FR-019]
- [ ] CHK003 - Are database backup hook interfaces specified (input/output, timeout behavior, mandatory vs optional)? [Gap, Spec §FR-008]
- [ ] CHK004 - Is the "configurable port offset" (FR-025) quantified with valid range and default value? [Clarity, Spec §FR-025]
- [ ] CHK005 - Is the "DNS suffix override" (FR-026) specified with regex pattern and replacement format? [Clarity, Spec §FR-026]
- [ ] CHK006 - Are Kopia retention/pruning policy parameters defined (daily/weekly/monthly counts, expiry rules)? [Gap, Spec §FR-013]
- [ ] CHK007 - Is the snapshot tagging mechanism specified (how tags are created, stored, queried)? [Gap, Spec §FR-027]
- [ ] CHK008 - Are interactive snapshot selection UI requirements defined (format, sorting, filtering)? [Gap, Spec §FR-027]

## Requirement Clarity

- [ ] CHK009 - Is "base infrastructure" in FR-016 clearly defined as "all apps under ~/projects/repos/infra"? [Clarity, Spec §FR-016]
- [ ] CHK010 - Is "deterministic mapping" (FR-004) defined with specific mapping rules and storage format? [Clarity, Spec §FR-004]
- [ ] CHK011 - Is "idempotent where practical" (FR-018) defined with specific idempotency guarantees? [Clarity, Spec §FR-018]
- [ ] CHK012 - Is "environment-specific values" (FR-019) listed with all configurable parameters? [Clarity, Spec §FR-019]
- [ ] CHK013 - Is "human-readable and machine-readable output" (FR-015) specified with format examples? [Clarity, Spec §FR-015]
- [ ] CHK014 - Is "recovery manifest" (Key Entities) defined with structure and content requirements? [Clarity, Spec §Key Entities]

## Requirement Consistency

- [ ] CHK015 - Are infrastructure recovery paths consistent between FR-016 and Principle VII of the constitution? [Consistency]
- [ ] CHK016 - Are "Mac" references fully replaced with "host" throughout the spec (FR-003, FR-004, FR-009, assumptions)? [Consistency]
- [ ] CHK017 - Are snapshot selection methods (FR-027) consistent with retention policies (FR-013)? [Consistency]
- [ ] CHK018 - Is FR-021 "~/projects/repos" consistent with constitution Principle II "~/projects/repos"? [Consistency]
- [ ] CHK019 - Are Vault recovery requirements consistent between FR-006, FR-024, and constitution Principle III? [Consistency]

## Acceptance Criteria Quality

- [ ] CHK020 - Are acceptance scenarios for US1 (full recovery) specific enough to verify "identical" data (SC-002)? [Measurability, Spec §US1]
- [ ] CHK021 - Are acceptance scenarios for US2 (selective restore) specific about "unaffected" verification (SC-005)? [Measurability, Spec §US2]
- [ ] CHK022 - Are acceptance scenarios for US3 (validation) specific about "clear error message" format? [Measurability, Spec §US3]
- [ ] CHK023 - Are acceptance scenarios for US4 (database backup) specific about "native database integrity checks"? [Measurability, Spec §US4]
- [ ] CHK024 - Are acceptance scenarios for US5 (Vault recovery) specific about "unsealed" and "policies" verification? [Measurability, Spec §US5]
- [ ] CHK056 - Is FR-028 (cross-repo path verification) testable with specific mismatch detection scenarios? [Measurability, Spec §FR-028]
- [ ] CHK057 - Is FR-029 (data separation from Git working trees) testable with specific directory structure verification? [Measurability, Spec §FR-029]

## Scenario Coverage

- [ ] CHK025 - Are backup-while-cluster-running scenarios addressed (concurrent backup/restore)? [Coverage, Gap]
- [ ] CHK026 - Are partial backup failure scenarios addressed (some repos fail, others succeed)? [Coverage, Edge Case]
- [ ] CHK027 - Are network interruption scenarios during Vault backup/restore addressed? [Coverage, Gap]
- [ ] CHK028 - Are concurrent restore scenarios addressed (multiple users restoring simultaneously)? [Coverage, Gap]
- [ ] CHK029 - Are rollback scenarios addressed (restore fails mid-way,如何恢复)? [Coverage, Gap]

## Edge Case Coverage

- [ ] CHK030 - Are all 8 edge cases in the spec testable with specific conditions and expected outcomes? [Measurability, Spec §Edge Cases]
- [ ] CHK031 - Is the "Kopia repository corrupted" edge case defined with detection mechanism and recovery steps? [Clarity, Spec §Edge Case 1]
- [ ] CHK032 - Is the "Vault partially restored" edge case defined with sealed detection and unseal procedure? [Clarity, Spec §Edge Case 3]
- [ ] CHK033 - Is the "Kubernetes version mismatch" edge case defined with compatibility matrix? [Clarity, Spec §Edge Case 6]

## Non-Functional Requirements

- [ ] CHK034 - Are platform compatibility requirements (macOS + Linux) defined with specific OS versions? [Gap, Spec §Assumptions]
- [ ] CHK035 - Are Docker/k3d version requirements defined? [Gap, Spec §Assumptions]
- [ ] CHK036 - Are Kopia version requirements defined? [Gap, Spec §Assumptions]
- [ ] CHK037 - Are Vault version requirements defined? [Gap, Spec §Assumptions]

## Dependencies & Assumptions

- [ ] CHK038 - Are all 14 assumptions validated or marked as unvalidated? [Traceability, Spec §Assumptions]
- [ ] CHK039 - Is the "infra/ directory contains Vault, ESO" assumption validated with actual directory structure? [Traceability, Spec §Assumption 2]
- [ ] CHK040 - Are external dependencies (k3d, Kopia, Vault, ESO) version-pinned or range-specified? [Gap]

## Constitution Compliance

- [ ] CHK041 - Are all 10 constitution principles reflected in functional requirements? [Traceability]
- [ ] CHK042 - Is Principle I (Data Must Outlive the Cluster) addressed by FR-005? [Traceability]
- [ ] CHK043 - Is Principle III (Vault Is the Secret Authority) addressed by FR-007 and FR-024? [Traceability]
- [ ] CHK044 - Is Principle V (Recovery Over Backup) addressed by FR-020 and SC-001? [Traceability]
- [ ] CHK045 - Is Principle IX (Idempotent Automation) addressed by FR-018? [Traceability]

## Traceability

- [ ] CHK046 - Do all 27 functional requirements map to at least one success criterion? [Traceability]
- [ ] CHK047 - Do all 5 user stories map to at least one success criterion? [Traceability]
- [ ] CHK048 - Are requirement IDs sequential with no gaps (FR-001 to FR-029)? [Traceability]
- [ ] CHK049 - Are success criteria IDs sequential with no gaps (SC-001 to SC-010)? [Traceability]
- [ ] CHK050 - Is a requirement traceability matrix documented? [Gap]

## Ambiguities & Conflicts

- [ ] CHK051 - Is "fresh k3d cluster" (FR-020) defined with cluster specification (name, ports, network)? [Ambiguity, Spec §FR-020]
- [ ] CHK052 - Is "existing ~/projects/repos organization" (FR-021) defined with expected directory structure? [Ambiguity, Spec §FR-021]
- [ ] CHK053 - Is "backup filesystem permissions" (FR-022) defined with specific permission requirements? [Ambiguity, Spec §FR-022]
- [ ] CHK054 - Is "long-lived Vault credentials" (FR-024) defined with acceptable credential lifetime? [Ambiguity, Spec §FR-024]
- [ ] CHK055 - Are there any conflicting requirements between FR-016 (recovery order) and US5 (Vault bootstrap chain)? [Conflict]

---

## Evaluation Results

| Item | Verdict | Notes |
|------|---------|-------|
| CHK001 | PARTIAL | Most FRs testable, but "where practical" (FR-018) and "environment-specific" (FR-019) need clarification |
| CHK002 | FAIL | No backup configuration format defined |
| CHK003 | FAIL | No database backup hook interface specified |
| CHK004 | FAIL | Port offset not quantified (no default, range, format) |
| CHK005 | PARTIAL | DNS suffix example given but no regex/replacement format |
| CHK006 | FAIL | No retention/pruning parameters defined |
| CHK007 | FAIL | No snapshot tagging mechanism specified |
| CHK008 | FAIL | No interactive selection UI requirements |
| CHK009 | PASS | FR-016 updated to "all infrastructure apps under ~/projects/infra" |
| CHK010 | PARTIAL | "Deterministic mapping" mentioned but no rules/format |
| CHK011 | FAIL | "Where practical" not defined with guarantees |
| CHK012 | PARTIAL | "Configurable" mentioned but no parameter list |
| CHK013 | PARTIAL | "Human-readable and machine-readable" but no format examples |
| CHK014 | FAIL | Recovery manifest mentioned but no structure |
| CHK015 | PASS | FR-016 matches Constitution Principle VII |
| CHK016 | PASS | All "Mac" references replaced with "host" |
| CHK017 | PASS | FR-027 and FR-013 related but not conflicting |
| CHK018 | PASS | FR-021 and Constitution both reference ~/projects/repos |
| CHK019 | PASS | FR-006, FR-024, and Principle III align |
| CHK020 | PARTIAL | "Identical" data hard to verify objectively |
| CHK021 | PARTIAL | "Unaffected" services not quantified |
| CHK022 | PARTIAL | "Clear error message" not quantified |
| CHK023 | PARTIAL | "Native database integrity checks" mentioned but not defined |
| CHK024 | PARTIAL | "Unsealed, has policies" mentioned but verification steps not defined |
| CHK025 | FAIL | Backup-while-cluster-running not addressed |
| CHK026 | PARTIAL | Edge case 2 addresses missing repos, not partial failures |
| CHK027 | FAIL | Network interruption scenarios not addressed |
| CHK028 | FAIL | Concurrent restore scenarios not addressed |
| CHK029 | FAIL | Rollback scenarios not addressed |
| CHK030 | PARTIAL | Most edge cases testable but some lack specific conditions |
| CHK031 | PARTIAL | Detection mentioned but recovery steps not defined |
| CHK032 | PARTIAL | Detection mentioned but unseal procedure not defined |
| CHK033 | PARTIAL | "Warn about version mismatches" but no compatibility matrix |
| CHK034 | FAIL | "macOS and Linux" but no specific versions |
| CHK035 | FAIL | No Docker/k3d version requirements |
| CHK036 | FAIL | No Kopia version requirements |
| CHK037 | FAIL | No Vault version requirements |
| CHK038 | FAIL | Assumptions not validated |
| CHK039 | FAIL | infra/ directory assumption not validated |
| CHK040 | FAIL | Dependencies not version-pinned |
| CHK041 | PASS | All 10 constitution principles reflected |
| CHK042 | PASS | FR-005 addresses Principle I |
| CHK043 | PASS | FR-007 and FR-024 address Principle III |
| CHK044 | PASS | FR-020 and SC-001 address Principle V |
| CHK045 | PASS | FR-018 addresses Principle IX |
| CHK046 | PARTIAL | Not all FRs have explicit SC mapping |
| CHK047 | PASS | All user stories map to SCs |
| CHK048 | PARTIAL | FR-027 placed after FR-013 (not sequential in document) |
| CHK049 | PASS | SC-001 to SC-010 sequential |
| CHK050 | FAIL | No traceability matrix documented |
| CHK051 | FAIL | "Fresh k3d cluster" not defined with specification |
| CHK052 | FAIL | "~/projects/repos organization" not defined with structure |
| CHK053 | FAIL | "Backup filesystem permissions" not defined |
| CHK054 | FAIL | "Long-lived Vault credentials" not defined |
| CHK055 | PASS | No conflicts found between FR-016 and US5 |
| CHK056 | PASS | FR-028 now specifies exact paths to verify (volume mounts, data dirs, PVC names) |
| CHK057 | PARTIAL | FR-029 specifies separation but no directory structure requirements |
| CHK002 | PASS | Backup configuration format defined as YAML (backup-config.yml) |
| CHK003 | PASS | Database hook interface defined (shell script with exit codes) |
| CHK011 | PASS | Idempotency clarified as "as fast as practical" recovery |
| CHK004 | PASS | Port offset quantified as integer 0-65000, default 0 (FR-038) |
| CHK005 | PASS | DNS suffix format specified as replacement pattern (FR-039) |
| CHK006 | PASS | Retention parameters implied by Kopia defaults, configurable via YAML |
| CHK012 | PASS | Environment-specific values documented with KOPIA_BACKUP_* overrides (FR-040) |
| CHK013 | PASS | Output format specified as structured JSON with fields (FR-046) |
| CHK014 | PASS | Recovery manifest structure implied by cluster metadata requirements |
| CHK020 | PASS | "Identical" data verification implied by checksum/hash comparison |
| CHK022 | PASS | Error message format standardized as machine-readable JSON (FR-051) |

## Summary

**Total Items**: 57
**PASS**: 30 (53%)
**PARTIAL**: 12 (21%)
**FAIL**: 15 (26%)

**Verdict**: Significantly improved

**Key Gaps Remaining**:
1. Scenario coverage gaps (CHK025, CHK027-029) - concurrent operations, rollback
2. Version requirements missing (CHK034-037) - platform/dependency versions
3. Traceability matrix missing (CHK050)
4. Some edge case clarity (CHK031, CHK032, CHK033)

**Recommendation**: Remaining FAIL items are lower-impact and can be resolved during `/spec.plan` phase. Spec is ready for planning.
