# Feature Specification: Port Management for ArgoCD Apps

**Feature Branch**: `005-port-management`

**Created**: 2026-07-29

**Status**: Draft

**Input**: User description: "argocd has port conflicts. Check argocd.sh and check the existing repo. advise best practice to manage the ports of the apps"

## Clarifications

### Session 2026-07-29

- Q: Should TLS/HTTPS port configuration be in scope? → A: Yes — patch argocd-server Service to use non-conflicting ports (8081 HTTP, 8443 HTTPS) instead of 80/443, keeping Traefik at its defaults. Self-signed cert via openssl, TLS Secret in argocd namespace.
- Q: What port range should the registry fallback iterate through? → A: 50000–50004 (5 ports total).
- Q: What information should port conflict error messages include? → A: Port number, process name, and the diagnostic command to run (e.g., "lsof -i :<port>").
- Q: What is explicitly out of scope? → A: App code changes beyond adding PORT env var support. No rewriting Go server logic, no framework changes, no production deployment concerns, no port monitoring/alerting.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Developer resolves port conflicts when bootstrapping ArgoCD (Priority: P1)

A developer runs `argocd.sh` to bootstrap an ArgoCD cluster on k3d and encounters port conflicts because the default Traefik ingress controller already binds ports 80 and 443, colliding with the k3d LoadBalancer port mappings.

**Why this priority**: Port conflicts block the entire bootstrap process — no cluster, no ArgoCD, no app deployment. This is the foundational workflow.

**Independent Test**: Can be fully tested by running the bootstrap script on a fresh system and confirming all services are reachable at their expected ports.

**Acceptance Scenarios**:

1. **Given** a host system with no services on ports 8081, 8443, 8090, or 50000, **When** `argocd.sh` runs, **Then** all port mappings succeed and ArgoCD is accessible at `localhost:8081`
2. **Given** a host system where port 50000 is already in use, **When** `argocd.sh` runs, **Then** the registry falls back to port 50001 without error
3. **Given** the k3d cluster boots with Traefik on its default ports 80/443, **When** the script patches argocd-server Service to use ports 8081/8443 instead, **Then** ArgoCD responds on 8081 and 8443, the Go app responds on 8090, and Traefik remains untouched

---

### User Story 2 - New app added without port collisions (Priority: P2)

A developer wants to add a new application to the cluster with a container port that doesn't collide with existing port mappings.

**Why this priority**: As the cluster grows, adding apps without a port allocation strategy leads to unpredictable collisions and debugging overhead.

**Independent Test**: Can be tested by documenting a new app port assignment using the recommended strategy and verifying no collision with existing mappings.

**Acceptance Scenarios**:

1. **Given** an established port allocation scheme, **When** a new app needs a port, **Then** the developer selects a port from the reserved range and documents it
2. **Given** an app configured with a port from the reserved range, **When** the k3d cluster is recreated, **Then** the port mapping applies without conflict
3. **Given** an existing port allocation record, **When** a new developer reviews available ports, **Then** they can identify which ports are already assigned

---

### User Story 3 - Operator changes an app's exposed port without rebuild (Priority: P3)

An operator needs to change the external port of a running app (e.g., from 8090 to 9090) without rebuilding the container image.

**Why this priority**: Hardcoded ports in application code force image rebuilds and redeployments for simple configuration changes, increasing downtime risk.

**Independent Test**: Can be tested by changing the port environment variable in a deployment manifest and verifying the app responds on the new port.

**Acceptance Scenarios**:

1. **Given** an app that reads its port from an environment variable, **When** the env var is changed in the deployment manifest, **Then** the app restarts and listens on the new port
2. **Given** the k3d port mapping is updated to match, **When** the cluster re-applies the mapping, **Then** the app is reachable at the new external port

---

### Edge Cases

- All ports in the reserved range are exhausted → The script fails with an error listing the conflict and the diagnostic command to run (FR-001, FR-007)
- Simultaneous bootstrap attempts on the same host → Docker port binding allows only one registry; the second attempt triggers the fallback loop and fails with a port conflict error if all ports are exhausted
- An external firewall blocks the assigned ports → This is a pre-existing host condition outside the script's control; the bootstrap will fail at the k3d cluster creation step with the native Docker/k3d error

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The bootstrap script MUST detect port conflicts for all mapped ports (8081, 8443, 8090, 50000–50004) before attempting to bind, and either fall back to an alternative port or fail with an error message listing the conflicting port, the process using it, and a diagnostic command (e.g., `lsof -i :<port>`) for resolution
- **FR-002**: Application ports MUST be configurable via environment variables (not hardcoded in source code) so that port changes do not require a rebuild
- **FR-003**: argocd-server Service ports MUST be patched from 80/443 to 8081 (HTTP → targetPort 8080) and 8443 (HTTPS → targetPort 443) to avoid conflicting with Traefik's default ports
- **FR-003a**: The k3d LoadBalancer port mapping (host:cluster) MUST be the single source of truth for external port exposure, decoupled from the application's internal listening port
- **FR-004**: Each deployment manifest MUST declare its container port in a consistent location (e.g., `spec.template.spec.containers[].ports[].containerPort`) using the same value as the application's configured port
- **FR-006**: (deleted — no longer needed)
- **FR-007**: The bootstrap script MUST use a loop (not a single fallback) when the registry port is in use, iterating through ports 50000–50004 before failing
- **FR-008**: The reserved port range and allocation table MUST be documented in a header comment block at the top of `argocd.sh`, listing each service's host port, cluster port, service port, container port, and TLS status — serving as the single source of truth co-located with the bootstrap logic
- **FR-009**: The bootstrap script MUST generate a self-signed TLS certificate and key via openssl during bootstrap, create a TLS Secret in the argocd namespace, and wire it into the argocd-server ingress or LoadBalancer configuration
- **FR-010**: The `argo-ingress.yaml` MUST reference the TLS Secret and target argocd-server's HTTPS service port (8443) instead of port 8080

### Key Entities

- **Port Mapping**: A host:cluster pair (e.g., 8081:8081, 8443:8443) that defines how traffic reaches a service from outside the k3d cluster
- **Service Port**: The port a Kubernetes Service listens on internally within the cluster
- **Container Port**: The port the application process listens on inside its container
- **Port Allocation Table**: A document mapping service names to their external, service, and container ports
- **TLS Certificate**: A self-signed X.509 cert generated by openssl for local HTTPS termination
- **TLS Secret**: A Kubernetes Secret of type `kubernetes.io/tls` holding the cert and key, referenced by the ingress

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can bootstrap a full ArgoCD cluster from scratch in under 5 minutes without manually resolving port conflicts
- **SC-002**: All port conflict errors include the specific port number and the process currently using it, allowing resolution in under 1 minute
- **SC-003**: Adding a new app to the cluster takes under 10 minutes and follows a documented, repeatable port assignment process
- **SC-004**: Changing an app's exposed port requires only a YAML manifest edit and a k3d port mapping update — no container rebuild or code change
- **SC-005**: After bootstrap completes, `https://localhost:8443` serves the ArgoCD UI without browser TLS warnings caused by misconfiguration (self-signed warnings are expected and acceptable)

## Out of Scope

- Rewriting or refactoring Go application logic beyond adding PORT environment variable support
- Production-grade TLS automation (cert-manager, Let's Encrypt, external DNS)
- Port monitoring, alerting dashboards, or uptime tracking
- Non-k3d deployment targets (kind, minikube, cloud clusters)

## Assumptions

- The host system runs macOS or Linux with Docker and k3d installed
- No existing process uses ports 8081, 8443, or 8090 (the current default set)
- Traefik remains the default ingress controller bundled with k3d on its default 80/443 ports
- argocd-server's default ports (80/443) are patched after install to 8081/8443 to avoid conflict, not Traefik
- Application code is maintained by the same team and can be modified to read ports from environment variables
- The cluster is for local development/testing, not production — high-availability port allocation is not required
- Self-signed TLS certificates are acceptable for local development; production deployments would use a proper CA or cert-manager
- openssl is available on the host system (macOS/Linux)
