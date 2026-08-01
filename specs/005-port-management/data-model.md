# Data Model: Port Management for ArgoCD Apps

## Entities

### PortMapping
- **Description**: A host:cluster pair defining external-to-internal traffic routing
- **Fields**:
  - `service_name` (string) — friendly name (e.g., "argocd-http")
  - `host_port` (uint16) — port on the developer's machine
  - `cluster_port` (uint16) — port inside the k3d cluster
  - `protocol` (string) — TCP (default), UDP
  - `tls_enabled` (boolean) — whether TLS termination is expected
- **Relationships**: Defined in k3d cluster creation args (`--port` flags), documented in port allocation table

### ContainerPort
- **Description**: The port an application process listens on inside its container
- **Fields**:
  - `app_name` (string) — deployment name
  - `container_port` (uint16) — port the app binds to
  - `env_var` (string) — environment variable name for configuration (e.g., "PORT")
  - `default_value` (uint16) — fallback if env var is unset
- **Relationships**: Must match `targetPort` in the Kubernetes Service and `containerPort` in the Deployment

### PortAllocation
- **Description**: A complete record of port assignments across the cluster
- **Fields**:
  - `service_name` (string)
  - `host_port` (uint16)
  - `cluster_port` (uint16)
  - `service_port` (uint16) — Kubernetes Service port
  - `container_port` (uint16)
  - `tls` (boolean)
  - `defined_in` (string) — file path where this mapping is configured
- **Validation rules**:
  - All `host_port` values must be unique
  - All `cluster_port` values must be unique
  - `host_port` must be in range 1024–65535
  - Registry ports are reserved in range 50000–50004

## State Transitions

Port allocations are static configuration — no runtime state transitions. Changes follow a deploy-modify-redeploy cycle:
1. Developer edits port allocation table (argocd.sh header)
2. Developer updates corresponding k3d `--port` flags and Service/Deployment specs
3. Developer recreates cluster or applies changes

## Identity & Uniqueness

- `service_name` uniquely identifies each port mapping
- `host_port` must be globally unique across the cluster
- `cluster_port` must be globally unique across the cluster
