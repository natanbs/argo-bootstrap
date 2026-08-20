# Requirements Quality Checklist: ArgoCD Install Infra Apps

**Purpose**: Validate specification completeness, clarity, and consistency before implementation
**Created**: 2026-08-19
**Feature**: [spec.md](spec.md)

## Requirement Completeness

- [x] CHK001 - Is the GitHub token format specified (e.g., classic PAT, fine-grained PAT, OAuth token)? [Completeness, Spec §FR-001] → Classic PAT, per research R4
- [x] CHK002 - Is the credential Secret name (`github-repo-cred`) documented as a canonical naming convention? [Clarity, Spec §FR-001] → Named in data-model.md
- [x] CHK003 - Are the exact fields required in the interactive prompt (username only? username + token?) specified? [Completeness, Spec §FR-007] → Username + token, per FR-007 and research R4
- [ ] CHK004 - Is the behavior defined when the operator cancels or provides invalid input during interactive prompt? [Gap, Spec §FR-007] → Out of scope; script exits on empty input
- [x] CHK005 - Is the ApplicationSet source repo URL (`https://github.com/natanbs/argocd-infra.git`) documented as a fixed dependency? [Completeness, Spec §FR-003] → Documented in data-model.md

## Requirement Clarity

- [x] CHK006 - Is "correct repository and branch" in FR-004 resolved to a specific URL and revision? [Clarity, Spec §FR-004] → applicationset.yaml with ARGOCD_INFRA_BRANCH override (research R2)
- [x] CHK007 - Is "existing bootstrap behavior" in FR-005 enumerated with specific behaviors to preserve? [Clarity, Spec §FR-005] → Listed in FR-005: k3d cluster, ArgoCD install, port config, password change
- [ ] CHK008 - Is "within 5 minutes" in SC-001 defined with measurement start point (script start vs. ArgoCD install vs. ApplicationSet apply)? [Clarity, Spec §SC-001] → Measurement starts at script start
- [ ] CHK009 - Is "within one sync interval" in SC-002 defined with the ArgoCD sync interval configuration? [Clarity, Spec §SC-002] → Needs verification of actual ArgoCD sync interval
- [ ] CHK010 - Is "expected state" in SC-003 defined with specific resource states to verify? [Clarity, Spec §SC-003] → Partially defined in data-model.md state transitions

## Requirement Consistency

- [x] CHK011 - Is the scope constraint ("only infrastructure apps") consistent with the ApplicationSet deploying all 5 registered apps (including familytree, pdf-scan)? [Conflict, Spec §Constraints vs. Plan §Summary] → Fixed: spec now states all 5 apps deploy via ApplicationSet
- [x] CHK012 - Are the business apps (familytree, pdf-scan) explicitly listed as out-of-scope with their deploy behavior documented? [Consistency, Spec §Assumptions] → Research R5 explains all 5 deploy; no filtering
- [ ] CHK013 - Does FR-009 ("NOT store token in version control") align with the verification method in SC-004 ("verified by checking .gitignore and commit history")? [Consistency, Spec §FR-009 vs §SC-004] → SC-004 verification method is imperfect but acceptable

## Acceptance Criteria Quality

- [x] CHK014 - Can SC-001 ("all registered infra apps reaching Synced status") be objectively verified without knowing ArgoCD internals? [Measurability, Spec §SC-001] → Yes: `argocd app list` and `kubectl get pods`
- [ ] CHK015 - Can SC-005 ("accessible via their respective services") be verified with specific service endpoints and ports? [Measurability, Spec §SC-005] → Needs service/port specifics from infra repo
- [x] CHK016 - Are acceptance scenarios for US-1 testable independently without requiring the full bootstrap? [Coverage, Spec §US-1] → Yes: each scenario has Given/When/Then format

## Scenario Coverage

- [ ] CHK017 - Are requirements defined for partial bootstrap failure (e.g., ArgoCD installs but ApplicationSet fails to apply)? [Coverage, Gap] → Out of scope for v1; ArgoCD shows error status
- [ ] CHK018 - Are requirements defined for network partition between k3d cluster and GitHub during bootstrap? [Coverage, Gap] → Out of scope; ArgoCD retries automatically
- [ ] CHK019 - Are requirements defined for concurrent bootstrap executions (two operators running argocd.sh simultaneously)? [Coverage, Gap] → Out of scope; kubectl apply is idempotent
- [ ] CHK020 - Are requirements defined for ArgoCD version upgrade scenarios (ApplicationSet CRD compatibility)? [Coverage, Gap] → Out of scope; pinned to current ArgoCD version

## Edge Case Coverage

- [x] CHK021 - Is the operator action defined when ArgoCD reports repository inaccessible (invalid token)? [Edge Case, Spec §Edge Cases] → Yes: spec edge case describes expected behavior
- [ ] CHK022 - Is the retry/backoff behavior defined for transient GitHub API failures during bootstrap? [Edge Case, Gap] → Out of scope; kubectl apply handles transient failures
- [ ] CHK023 - Are requirements defined for cleanup when bootstrap is interrupted mid-execution? [Edge Case, Gap] → Out of scope; re-run is idempotent

## Non-Functional Requirements

- [ ] CHK024 - Are security requirements defined for token storage in Kubernetes (e.g., Secret encryption at rest)? [Gap] → Out of scope; depends on cluster security config
- [ ] CHK025 - Are audit logging requirements defined for credential creation and ApplicationSet deployment? [Gap] → Out of scope; kubectl output provides visibility
- [ ] CHK026 - Is the ArgoCD version compatibility range documented (minimum version supporting ApplicationSet)? [Gap] → Out of scope; pinned to current k3d setup

## Dependencies & Assumptions

- [x] CHK027 - Is the assumption of GitHub under `natanbs` organization validated against the actual ApplicationSet manifest? [Assumption, Spec §Assumptions] → Yes: matches applicationset.yaml
- [ ] CHK028 - Are network requirements documented (outbound HTTPS to github.com, ports 443)? [Dependency, Gap] → Assumed; out of scope for this feature
- [ ] CHK029 - Is the dependency on `kubectl` and `argocd` CLI versions documented? [Dependency, Gap] → Assumed available; out of scope for this feature

## Ambiguities & Conflicts

- [x] CHK030 - Is the `--help` text in argocd.sh (which shows `$1` argument usage) aligned with the new env var + interactive prompt approach? [Ambiguity, Spec §FR-007] → Task T008 updates --help text
