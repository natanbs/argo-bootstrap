# Quickstart: CLI Tool Install

This feature enhances `argocd.sh` to automatically install missing prerequisites.

## Usage

```bash
./argocd.sh
```

Or with a GitHub token for private repos:

```bash
./argocd.sh <git-token>
```

## What It Does

1. Detects your OS (macOS or Linux)
2. Checks if `kubectl` is installed — installs if missing
3. Checks if `k3d` is installed — installs if missing
4. Checks if `argocd` CLI is installed — installs if missing
5. Proceeds with the normal bootstrap flow

## Platform Support

| Tool     | macOS                        | Debian/Ubuntu                          |
|----------|------------------------------|----------------------------------------|
| kubectl  | `brew install kubernetes-cli` | Binary from `dl.k8s.io` → `/usr/local/bin` |
| k3d      | `brew install k3d`           | Script from `get.k3d.io`               |
| argocd   | `brew install argocd`        | Binary from GitHub → `/usr/local/bin`  |
