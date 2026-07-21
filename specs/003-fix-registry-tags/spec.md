# Feature Specification: Fix Registry Tags Display

**Feature Branch**: `003-fix-registry-tags`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "Previous reg.sh change was incorrect. Restore the changes with corrected behaviour: -h/--help shows help, no arguments shows last 3 tags per service, -f/--full shows all tags. Tags should always be sorted for human readability (e.g. v1.1.2 before v1.1.11)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View registry with limited tags by default (Priority: P1)

As a user of the reg.sh script, when I run the script without any arguments, I see each container image listed with only the 3 most recent tags, sorted in human-readable version order. This keeps the output concise and focused on the most relevant versions.

**Why this priority**: This is the core default behavior — reducing output noise so users can quickly scan which images exist and their latest tags without being overwhelmed by a long list.

**Independent Test**: Can be fully tested by running `./reg.sh` against the local registry and verifying that each image shows at most 3 tags in human-readable version order. Delivers immediate value by decluttering output.

**Acceptance Scenarios**:

1. **Given** a registry with an image that has 5 tags (v1.1.1, v1.1.2, v1.1.11, v1.2.0, v2.0.0), **When** the user runs `./reg.sh`, **Then** the output shows only 3 tags for that image, sorted as v2.0.0, v1.2.0, v1.1.11 (most recent first in human-readable order).
2. **Given** a registry with an image that has 2 tags, **When** the user runs `./reg.sh`, **Then** the output shows all 2 tags (no padding to 3).
3. **Given** a registry with multiple images, **When** the user runs `./reg.sh`, **Then** each image independently shows at most 3 tags, and image names are listed in alphabetical order.

---

### User Story 2 - View all tags with full flag (Priority: P1)

As a user of the reg.sh script, when I run the script with the `-f` or `--full` flag, I see every available tag for each image in human-readable version order, matching the original default behavior before the limit was added.

**Why this priority**: Users occasionally need the full tag list for debugging, auditing, or finding specific versions. Without this escape hatch, the feature would be a regression in capability.

**Independent Test**: Can be fully tested by running `./reg.sh -f` or `./reg.sh --full` and verifying that all tags for each image are displayed in human-readable version order. Delivers value by restoring full visibility on demand.

**Acceptance Scenarios**:

1. **Given** a registry with an image that has 5 tags, **When** the user runs `./reg.sh -f`, **Then** the output shows all 5 tags for that image in human-readable version order.
2. **Given** a registry with multiple images, **When** the user runs `./reg.sh --full`, **Then** every image shows all of its tags.
3. **Given** an image with no tags, **When** the user runs `./reg.sh -f`, **Then** the image is listed but shows no tags.

---

### User Story 3 - View help information (Priority: P2)

As a user of the reg.sh script, when I run the script with `-h` or `--help`, I see a brief usage summary showing the available flags and their purpose.

**Why this priority**: Help is a standard CLI convention that improves discoverability. Without it, users must read the source to learn about available options.

**Independent Test**: Can be fully tested by running `./reg.sh -h` or `./reg.sh --help` and verifying that a usage message is displayed describing the available flags.

**Acceptance Scenarios**:

1. **Given** any state, **When** the user runs `./reg.sh -h`, **Then** a help/usage message is displayed.
2. **Given** any state, **When** the user runs `./reg.sh --help`, **Then** the same help/usage message is displayed.

---

### Edge Cases

- What happens when an image has zero tags? The image should still be listed with an empty tags section.
- What happens when an invalid flag is provided? The script prints a short usage hint to stderr and exits with a non-zero code.
- What happens when the registry is unreachable? The script handles the error as it currently does (curl failure output).
- How are non-semver tags sorted? Tags that do not follow version patterns are sorted alphabetically after version-sorted tags, or sorted within the version-aware comparison as plain strings.
- How is version-aware sorting implemented? Tags are sorted in descending order (newest first), with natural number ordering so that v1.1.11 comes after v1.1.2 (not before).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display at most 3 tags per image when the script is run without flags.
- **FR-002**: System MUST display all available tags per image when the script is run with the `-f` or `--full` flag.
- **FR-003**: System MUST display a help/usage message when the script is run with `-h` or `--help`.
- **FR-004**: System MUST sort tags in human-readable version order (natural number ordering), with the most recent version first.
- **FR-005**: System MUST preserve the existing behavior of listing images in alphabetical order.
- **FR-006**: System MUST continue to display images even when they have fewer than 3 tags (show all available).
- **FR-007**: System MUST handle the case where an image has no tags gracefully.
- **FR-008**: System MUST print a usage hint to stderr and exit with a non-zero code when an invalid or unrecognized flag is provided.

### Key Entities

- **Registry Image**: A container image stored in the registry, identified by its repository name. Has one or more tags representing different versions or builds.
- **Tag**: A label assigned to a container image, used to identify a specific version. Tags are sorted in human-readable version order for display (e.g., v1.1.11 after v1.1.2).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running the script without flags produces output with at most 3 tags per image, reducing visual clutter by at least 50% for images with many tags.
- **SC-002**: Running the script with `-f` or `--full` produces the complete tag list for all images, matching the original script behavior exactly.
- **SC-003**: Tags are always displayed in human-readable version order, with v1.1.2 appearing before v1.1.11 in every display mode.
- **SC-004**: The default output is scannable in under 5 seconds for a registry with 20+ images.
- **SC-005**: The help flag displays a clear usage message that allows a new user to understand all available options without reading source code.

## Assumptions

- The `-f` / `--full` flag is the preferred convention for showing all tags, replacing the previously planned `-a` / `--all` flag.
- "Last 3 tags" refers to the 3 most recent tags in human-readable version order (descending), not alphabetical order.
- Human-readable version sort means natural number ordering within version segments (v1.1.2 < v1.1.11), commonly referred to as "version sort" or "natural sort."
- Non-version tags (e.g., "latest", "stable", "dev") are sorted alphabetically after version-sorted tags, or treated as plain strings in the version comparison.
- The script remains a simple shell script; no refactoring into a more complex tool is expected.
- The local registry at `localhost:50000` remains the target; no configuration changes are needed.
- The existing error handling for unreachable registries or missing dependencies is preserved as-is.
