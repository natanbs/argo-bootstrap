# Feature Specification: Restore ArgoCD Ingress

**Feature Branch**: `011-restore-argocd-ingress`

**Created**: Fri Oct 02 2026

**Status**: Draft

**Input**: User description: "http://argocd.lab/ 404 page not found

Check other repos to implement accordingly"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.

  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - Access ArgoCD via HTTP Ingress (Priority: P1)

As a platform operator, I can access ArgoCD at `http://argocd.lab/` via the local cluster ingress so I don't need to remember the direct LoadBalancer ports (8081/8443).

**Why this priority**: Restores standard local-dev access path used by sibling repos; consistent with how other apps are exposed.

**Independent Test**: `curl -i -H "Host: argocd.lab" http://127.0.0.1/` returns 200 OK with ArgoCD HTML (or redirects appropriately per cluster config). Can be tested independently once ingress is applied.

**Acceptance Scenarios**:

1. **Given** k3d cluster is running with Traefik, **When** I browse to `http://argocd.lab/`, **Then** ArgoCD login UI loads successfully over plain HTTP.
2. **Given** ArgoCD is running with `server.insecure=true`, **When** the ingress routes to `argocd-server` on the HTTP target port, **Then** no TLS error is shown.

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

- What happens if ArgoCD server is still restarting? Ingress should route to ready backend when healthy.
- How does the system behave if another app already claims `argocd.lab`? Only one Ingress should define that host (no conflict).
- How does it behave when accessing via IP directly? Ingress rules match Host header; direct access via LoadBalancer ports remains available for debugging.

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST create an Ingress manifest (`argo-ingress.yaml`) for ArgoCD in the repo root following sibling conventions (Traefik ingress controller, `ingressClassName: traefik`, `host: argocd.lab`, path `/` with `pathType: Prefix`).
- **FR-002**: The ArgoCD Ingress MUST route to service `argocd-server` in namespace `argocd` on the HTTP target port (matching the existing Service configuration with `server.insecure=true`), using plain HTTP entrypoint (not forcing HTTPS redirect).
- **FR-003**: The ingress configuration MUST be consistent with other `.lab` apps (e.g. `tech-companies` pattern for plain HTTP routing under Traefik).
- **FR-004**: System MUST preserve existing ArgoCD Service behavior (LoadBalancer with externalIPs on ports 8081/8443) as configured in `argocd.sh` unless a change is required to align backend port with the ingress target.
- **FR-005**: The solution MUST be idempotent and reproducible via the bootstrap process (no manual post-deploy steps required).

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `http://argocd.lab/` returns HTTP 200 (or successful redirect to login) within 2 seconds when cluster is healthy.
- **SC-002**: Ingress routes correctly with no TLS certificate errors over plain HTTP.
- **SC-003**: The restored ingress matches sibling repo conventions (Traefik, .lab host, standard path/backend structure).
- **SC-004**: Existing direct access via LoadBalancer ports (8081/8443) remains functional.

## Assumptions

- Local k3d cluster uses Traefik as ingress controller (consistent with existing sibling repos and k3d setup).
- ArgoCD runs with `server.insecure=true` and Service targetPort 8080 for HTTP (8081 external), which means plain HTTP ingress to the HTTP port is appropriate.
- Hostname `argocd.lab` resolves to the host (external DNS/hosts resolution is outside repo scope).
- No changes to ArgoCD Helm installation method are needed (ArgoCD installed via raw manifests as in `argocd.sh`).
