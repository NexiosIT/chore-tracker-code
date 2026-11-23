# Intent Engineering SDLC Code Repo — Operator Notes

> Auto-loaded by Claude Code every session. **Generation guide: [docs/WORKFLOW.md](docs/WORKFLOW.md).**

This is a **code repository** in an Intent Engineering SDLC project. The specs that drive this code live upstream in the product-hub; code here is generated from them.

## Where things are
- **How generation works** → [docs/WORKFLOW.md](docs/WORKFLOW.md)
- **Generate code** → `/ie/generate` (detail: `.claude/commands/ie/generate.md`)
- **What to build this run** → `.flowforge/manifest.yml` (assembled + distributed by the hub)
- **Finish the run** → `ie generation finalize`, in **this** repo on the feature branch, **before** its PR opens — it archives `.flowforge/` into `.flowforge/archive/{feature-id}/` so the integration branch never carries live generation state (`--revert` puts it back if review sends the work back). Nothing is expected of this repo after the merge: the operator records the delivery in the hub with `ie feature deliver <id>`.
- **Where the product-hub lives** → `.ie/hub.yml` (per-machine pointer written by `ie feature handover`, read by `/ie/generate`; gitignored, never committed)
- **Foundation gates** → `ie service status <id>` from the product-hub

## Cardinal rules
- Generation is checkpoint-driven (CP1 → CP5); tests gate each step — don't skip checkpoints.
- Fix defects in the upstream spec and regenerate; never hand-patch generated code.

<!-- Project-specific rules go below. This file is yours — `ie service init` will not overwrite it. -->
