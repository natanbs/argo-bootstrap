# Data Model: Declarative Bootstrap Migration

## Entities

No data model changes. This feature modifies the internal parsing mechanism of an existing script without introducing new entities or changing existing ones.

### Existing Entities (unchanged)

- **Repo Registration**: `argocd repo add` — URL, username, password. Idempotent with `--upsert`.
- **ArgoCD ConfigMap**: `argocd-cmd-params-cm` — keys `server.insecure`, `server.session.expires`. Patched via `kubectl patch --type merge`.

## State Transitions

None. The repo registration flow is identical — only the JSON parser changes from Python to jq.

## Relationships

No changes.
