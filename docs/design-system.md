# Design System

TASK-003 provides the dark-first token system under `mobile/lib/core/theme`.

- Colors: background, surfaces, primary, positive, negative, warning, text,
  and divider roles.
- Spacing: 4, 8, 12, 16, 20, 24, and 32 logical pixels.
- Radius: 4, 8, 12, 16, and 24 logical pixels.
- Typography: caption, body, title, and tabular number styles.
- Shared icon sizes, shadows, and a Material 3 dark theme.

Widgets should consume these semantic tokens rather than defining product
colors, spacing, typography, or radii locally.
