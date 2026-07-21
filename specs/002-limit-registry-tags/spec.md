# Feature Specification: Limit Registry Tags Display

**Feature Branch**: `002-limit-registry-tags`

**Created**: 2026-07-21

**Status**: Draft

**Input**: User description: "The reg.sh should only show last 3 tags per app. Add a flag to view all the tags"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View registry with limited tags by default (Priority: P1)

As a user of the reg.sh script, when I run the script without any arguments, I see each container image listed with only the 3 most recent tags (based on alphabetical sort order). This keeps the output concise and focused on the most relevant versions.

**Why this priority**: This is the core behavior change — reducing output noise so users can quickly scan which images exist and their latest tags without being overwhelmed by a long list.

**Independent Test**: Can be fully tested by running `./reg.sh` against the local registry and verifying that each image shows at most 3 tags. Delivers immediate value by decluttering output.

**Acceptance Scenarios**:

1. **Given** a registry with an image that has 5 tags, **When** the user runs `./reg.sh`, **Then** the output shows only 3 tags for that image (the last 3 in sorted order).
2. **Given** a registry with an image that has 2 tags, **When** the user runs `./reg.sh`, **Then** the output shows all 2 tags (no padding to 3).
3. **Given** a registry with multiple images, **When** the user runs `./reg.sh`, **Then** each image independently shows at most 3 tags.

---

### User Story 2 - View all tags with a flag (Priority: P1)

As a user of the reg.sh script, when I run the script with an "all tags" flag, I see every available tag for each image, matching the previous default behavior.

**Why this priority**: Users occasionally need the full tag list for debugging, auditing, or finding specific versions. Without this escape hatch, the feature would be a regression in capability.

**Independent Test**: Can be fully tested by running `./reg.sh -a` (or the chosen flag) and verifying that all tags for each image are displayed. Delivers value by restoring full visibility on demand.

**Acceptance Scenarios**:

1. **Given** a registry with an image that has 5 tags, **When** the user runs `./reg.sh -a`, **Then** the output shows all 5 tags for that image.
2. **Given** a registry with multiple images, **When** the user runs `./reg.sh --all`, **Then** every image shows all of its tags.
3. **Given** an image with no tags, **When** the user runs `./reg.sh -a`, **Then** the image is listed but shows no tags (same as current behavior).

---

### Edge Cases

- What happens when an image has zero tags? The image should still be listed with an empty tags section.
- What happens when an invalid flag is provided? The script should display usage information or ignore the flag gracefully, continuing with default (limited) behavior.
- What happens when the registry is unreachable? The script should handle the error as it currently does (curl failure output).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display at most 3 tags per image when the script is run without the "all" flag.
- **FR-002**: System MUST display all available tags per image when the script is run with the `-a` or `--all` flag.
- **FR-003**: System MUST preserve the existing behavior of listing all images in the registry.
- **FR-004**: System MUST preserve the existing sort order of tags within the limited display.
- **FR-005**: System MUST continue to display images even when they have fewer than 3 tags (show all available).
- **FR-006**: System MUST handle the case where an image has no tags gracefully.

### Key Entities

- **Registry Image**: A container image stored in the registry, identified by its repository name. Has one or more tags representing different versions or builds.
- **Tag**: A label assigned to a container image, used to identify a specific version. Tags are sorted alphabetically for display.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Running the script without flags produces output with at most 3 tags per image, reducing visual clutter by at least 50% for images with many tags.
- **SC-002**: Running the script with `-a` or `--all` produces the complete tag list for all images, matching the original script behavior exactly.
- **SC-003**: The default output is scannable in under 5 seconds for a registry with 20+ images.
- **SC-004**: The feature adds no new external dependencies or tools beyond what the script already requires.

## Assumptions

- The `-a` / `--all` flag is the preferred convention for showing all tags, following standard CLI patterns.
- "Last 3 tags" refers to the last 3 in alphabetical sort order, consistent with the existing sort behavior of the script.
- The script will remain a simple shell script; no refactoring into a more complex tool is expected.
- The local registry at `localhost:50000` remains the target; no configuration changes are needed.
- The existing error handling for unreachable registries or missing dependencies is preserved as-is.
