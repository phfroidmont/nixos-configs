---
name: scalive
description: >-
  Scalive application development, debugging, and review. Use when working on
  Scalive's Scala 3 server-rendered LiveViews using ZIO, not generic Scala code.
---

# Scalive

Use this skill for work on Scalive applications, not for unrelated Scala projects.

## Start with documentation

1. Fetch https://scalive.dev/llms.txt at the start of the Scalive task. It is a documentation index, not a skill manifest.
2. Follow the relevant linked Markdown documentation before recommending APIs: guides, resolved examples, and API reference as applicable.
3. Inspect the project's Scalive dependency version and local conventions before changing code. If published docs differ from the pinned version, verify APIs against that version's source or examples.

## Work in the project's version

- Trace the existing lifecycle, model, messages, and rendering flow before modifying a LiveView.
- For routing, components, forms, or browser integration, consult the corresponding docs and local usage rather than inferring names or behavior.
- Use project testing conventions and relevant documented testing guidance to verify changes.
- Do not silently upgrade dependencies or assume parity with Phoenix LiveView.
- If documentation is unavailable, say so; rely on local examples and dependency source instead of guessing APIs.

## Apply and verify

For a bug, reproduce the behavior using the project's existing setup before editing.
Keep changes consistent with nearby Scalive code and the version actually in use.
Run the smallest relevant project check or test after editing; report what was not run.
When reviewing, distinguish behavior confirmed by code or docs from assumptions.
