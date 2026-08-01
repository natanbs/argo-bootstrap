# Feature Specification: Add App Filter Flag

**Feature Branch**: `004-add-app-filter`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "Add to reg.sh a flag -a / --app <app> that would show the tags only of the provided app (service)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Filter tags by app name (Priority: P1)

As a user of the reg.sh script, when I run the script with `-a <app>` or `--app <app>`, I see tags only for the specified container image (service), instead of all images in the registry. This allows me to quickly focus on a specific service without scrolling through unrelated images.

**Why this priority**: This is the core feature — filtering output to a single service saves time when debugging, auditing, or checking versions for a specific application.

**Independent Test**: Can be fully tested by running `./reg.sh -a myapp` and verifying that only the `myapp` image and its tags are displayed. Delivers immediate value by reducing noise.

**Acceptance Scenarios**:

1. **Given** a registry with images "api", "web", "worker", **When** the user runs `./reg.sh -a api`, **Then** only the "api" image and its tags are displayed.
2. **Given** a registry with images "api", "web", "worker", **When** the user runs `./reg.sh --app web`, **Then** only the "web" image and its tags are displayed.
3. **Given** a registry with an image "my-api", **When** the user runs `./reg.sh -a api`, **Then** the "my-api" image is NOT shown (exact match, not substring).

---

### User Story 2 - Combine app filter with full flag (Priority: P1)

As a user of the reg.sh script, when I run the script with `-a <app> -f` or `--app <app> --full`, I see all tags for the specified image in human-readable version order. The app filter and full flag work together seamlessly.

**Why this priority**: Users often need to see all tags for a specific service during debugging or auditing. Combining flags is a natural CLI pattern.

**Independent Test**: Can be fully tested by running `./reg.sh -a api -f` and verifying that all tags for "api" are shown.

**Acceptance Scenarios**:

1. **Given** a registry with image "api" having 10 tags, **When** the user runs `./reg.sh -a api -f`, **Then** all 10 tags for "api" are displayed in version-sorted order.
2. **Given** a registry with image "api" having 10 tags, **When** the user runs `./reg.sh --app api --full`, **Then** all 10 tags for "api" are displayed.

---

### User Story 3 - App filter with no match (Priority: P2)

As a user of the reg.sh script, when I run the script with `-a <app>` and no image matches the provided name, I see a clear message indicating that no matching image was found.

**Why this priority**: Good error feedback prevents confusion when a user misspells an app name or the service doesn't exist in the registry.

**Independent Test**: Can be fully tested by running `./reg.sh -a nonexistent` and verifying a "no match" message is shown.

**Acceptance Scenarios**:

1. **Given** a registry with images "api", "web", **When** the user runs `./reg.sh -a worker`, **Then** a message indicating no matching image is displayed.
2. **Given** a registry with images "api", "web", **When** the user runs `./reg.sh -a API`, **Then** no match is shown (matching is case-sensitive).

---

### Edge Cases

- What happens when `-a` is provided without a value? The script prints a usage hint to stderr and exits with a non-zero code.
- What happens when the app filter matches multiple images? Only exact repository name matches are shown. If the user wants partial matching, they should use the full registry listing.
- What happens when `-a` is combined with `-h`? The help flag takes precedence and displays the usage message.
- What happens when the registry is unreachable? The script handles the error as it currently does (curl failure output).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display tags only for the image whose repository name exactly matches the value provided with `-a` or `--app`.
- **FR-002**: System MUST require a non-empty value when `-a` or `--app` is provided; print usage hint to stderr and exit with non-zero code if missing.
- **FR-003**: System MUST combine the app filter with the existing `-f`/`--full` flag behavior (show all tags for matched image).
- **FR-004**: System MUST combine the app filter with the default 3-tag limit when `-f`/`--full` is not provided.
- **FR-005**: System MUST display a "no matching image" message when the provided app name does not match any image in the registry.
- **FR-006**: System MUST perform case-sensitive exact matching on the repository name.
- **FR-007**: System MUST update the help message to include the `-a`/`--app` option.
- **FR-008**: System MUST preserve existing behavior when `-a`/`--app` is not provided (show all images).

### Key Entities

- **Registry Image**: A container image stored in the registry, identified by its repository name. Has one or more tags.
- **App Filter**: A user-provided string that filters the output to only images whose repository name exactly matches the filter value.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running `./reg.sh -a <app>` shows only the specified image, reducing output to a single service in under 1 second.
- **SC-002**: Running `./reg.sh -a <app> -f` shows all tags for the specified image, combining filter and full display.
- **SC-003**: Running `./reg.sh -a <nonexistent>` shows a clear "no match" message instead of empty output.
- **SC-004**: The updated help message includes the new `-a`/`--app` option and is understandable without reading source code.
- **SC-005**: All existing behaviors (default 3-tag limit, full mode, help, invalid flags) continue to work unchanged when `-a`/`--app` is not used.

## Assumptions

- The `-a` / `--app` flag requires a value (it is not a boolean flag like `-f`).
- Matching is exact and case-sensitive on the full repository name (not substring or partial match).
- The `-a`/`--app` flag can be combined with `-f`/`--full` but not with `-h`/`--help` (help takes precedence).
- When `-a` is provided without a value, the script behaves like an invalid flag (usage hint to stderr, non-zero exit).
- The existing `-f`/`--full` and `-h`/`--help` flags are unaffected by this addition.
