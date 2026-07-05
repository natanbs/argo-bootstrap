# Data Model: CLI Tool Install

## Entities

### Tool

| Attribute   | Type    | Description                                      |
|-------------|---------|--------------------------------------------------|
| name        | string  | CLI tool identifier (kubectl, argocd)            |
| installed   | boolean | Whether tool is present in system PATH            |
| platform    | string  | Target OS (macos, linux)                         |

### Platform

| Attribute   | Type    | Description                                      |
|-------------|---------|--------------------------------------------------|
| os          | string  | Operating system: darwin, linux                   |
| package_mgr | string | Package manager: brew, direct_binary              |
| arch        | string  | System architecture: amd64, arm64                  |

## Relationships

- A **Tool** is installed on a **Platform** using the platform's installation method
- Platform determines which installation command to run
- Tool's installed state is checked via `command -v`
