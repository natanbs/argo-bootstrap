# Requirements Quality Checklist: ArgoCD Install Infra Apps

**Purpose**: Validate specification completeness, clarity, and consistency before implementation
**Created**: 2026-08-19
**Feature**: [spec.md](spec.md)

## Requirement Completeness

- [ ] CHK001 - Is the GitHub token format specified (e.g., classic PAT, fine-grained PAT, OAuth token)? [Completeness, Spec §FR-001]
- [ ] CHK002 - Is the credential Secret name (`github-repo-cred`) documented as a canonical naming convention? [Clarity, Spec §FR-001]
- [ ] CHK003 - Are the exact fields required in the interactive prompt (username only? username + token?) specified? [Completeness, Spec §FR-007]
- [ ] CHK004 - Is the behavior defined when the operator cancels or provides invalid input during interactive prompt? [Gap, Spec §FR-007]
- [ ] CHK005 - Is the ApplicationSet source repo URL (`https://github.com/natanbs/argocd-infra.git`) documented as a fixed dependency? [Completeness, Spec §FR-003]

## Requirement Clarity

- [ ] CHK006 - Is "correct repository and branch" in FR-004 resolved to a specific URL and revision? [Clarity, Spec §FR-004]
- [ ] CHK007 - Is "existing bootstrap behavior" in FR-005 enumerated with specific behaviors to preserve? [Clarity, Spec §FR-005]
- [ ] CHK008 - Is "within 5 minutes" in SC-001 defined with measurement start point (script start vs. ArgoCD install vs. ApplicationSet apply)? [Clarity, Spec §SC-001]
- [ ] CHK009 - Is "within one sync interval (3 minutes)" in SC-002 defined with the ArgoCD sync interval configuration? [Clarity, Spec §SC-002]
- [ ] CHK010 - Is "expected state" in SC-003 defined with specific resource states to verify? [Clarity, Spec §SC-003]

## Requirement Consistency

- [ ] CHK011 - Is the scope constraint ("only infrastructure apps") consistent with the ApplicationSet deploying all 5 registered apps (including familytree, pdf-scan)? [Conflict, Spec §Constraints vs. Plan §Summary]
- [ ] CHK012 - Are the business apps (familytree, pdf-scan) explicitly listed as out-of-scope with their deploy behavior documented? [Consistency, Spec §Assumptions]
- [ ] CHK013 - Does FR-009 ("NOT store token in version control") align with the verification method in SC-004 ("verified by checking .gitignore and commit history")? [Consistency, Spec §FR-009 vs §SC-004]

## Acceptance Criteria Quality

- [ ] CHK014 - Can SC-001 ("all registered infra apps reaching Synced status") be objectively verified without knowing ArgoCD internals? [Measurability, Spec §SC-001]
- [ ] CHK015 - Can SC-005 ("accessible via their respective services") be verified with specific service endpoints and ports? [Measurability, Spec §SC-005]
- [ ] CHK016 - Are acceptance scenarios for US-1 testable independently without requiring the full bootstrap? [Coverage, Spec §US-1]

## Scenario Coverage

- [ ] CHK017 - Are requirements defined for partial bootstrap failure (e.g., ArgoCD installs but ApplicationSet fails to apply)? [Coverage, Gap]
- [ ] CHK018 - Are requirements defined for network partition between k3d cluster and GitHub during bootstrap? [Coverage, Gap]
- [ ] CHK019 - Are requirements defined for concurrent bootstrap executions (two operators running argocd.sh simultaneously)? [Coverage, Gap]
- [ ] CHK020 - Are requirements defined for ArgoCD version upgrade scenarios (ApplicationSet CRD compatibility)? [Coverage, Gap]

## Edge Case Coverage

- [ ] CHK021 - Is the operator action defined when ArgoCD reports repository inaccessible (invalid token)? [Edge Case, Spec §Edge Cases]
- [ ] CHK022 - Is the retry/backoff behavior defined for transient GitHub API failures during bootstrap? [Edge Case, Gap]
- [ ] CHK023 - Are requirements defined for cleanup when bootstrap is interrupted mid-execution? [Edge Case, Gap]

## Non-Functional Requirements

- [ ] CHK024 - Are security requirements defined for token storage in Kubernetes (e.g., Secret encryption at rest)? [Gap]
- [ ] CHK025 - Are audit logging requirements defined for credential creation and ApplicationSet deployment? [Gap]
- [ ] CHK026 - Is the ArgoCD version compatibility range documented (minimum version supporting ApplicationSet)? [Gap]

## Dependencies & Assumptions

- [ ] CHK027 - Is the assumption of GitHub under `natanbs` organization validated against the actual ApplicationSet manifest? [Assumption, Spec §Assumptions]
- [ ] CHK028 - Are network requirements documented (outbound HTTPS to github.com, ports 443)? [Dependency, Gap]
- [ ] CHK029 - Is the dependency on `kubectl` and `argocd` CLI versions documented? [Dependency, Gap]

## Ambiguities & Conflicts

- [ ] CHK030 - Is the `--help` text in argocd.sh (which shows `$1` argument usage) aligned with the new env var + interactive prompt approach? [Ambiguity, Spec §FR-007]
