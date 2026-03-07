---
name: conventional-commit
description: Conventional commit format for LibAnimate with release-please integration, including prefix-to-changelog mapping, versioning rules, and branch workflow.
---

# Conventional Commits

LibAnimate uses release-please to automate versioning and changelog generation. Correct commit prefixes are critical.

## Prefix Reference

| Prefix | Changelog Section | Hidden? | Version Bump |
|--------|-------------------|---------|--------------|
| `feat:` | Features | No | MINOR |
| `fix:` | Bug Fixes | No | PATCH |
| `perf:` | Performance | No | PATCH |
| `refactor:` | Refactor | No | PATCH |
| `docs:` | Documentation | No | PATCH |
| `style:` | Styling | No | PATCH |
| `test:` | Testing | No | PATCH |
| `ci:` | CI/CD | No | PATCH |
| `chore:` | Miscellaneous | **Yes** | PATCH |
| `revert:` | Reverts | No | PATCH |

**`chore:` is hidden from the changelog** -- use it only for trivial changes that users don't need to see.

## Branch Workflow

- **NEVER** commit directly to `master`
- Always create a feature branch: `git checkout -b feat/my-feature`
- Push and create a PR to `master`
- release-please handles the rest after merge

## Commit Message Format

```
<type>: <description>

[optional body]
```

### Good Examples

```
feat: add rollIn and rollOut animations
fix: correct easing interpolation for backInDown at progress 0.5
perf: cache keyframe lookup results to reduce per-frame allocations
refactor: extract cubic-bezier solver into dedicated helper
docs: update animation definition format in AGENTS.md
style: fix indentation in Animations.lua attention seekers section
ci: add luacheck step for Animations.lua
```

### Optional Scopes

Scopes are not enforced but recommended for clarity:

```
feat(animations): add flipInX and flipInY entrance animations
fix(easing): handle edge case in easeInBack with negative t values
refactor(api): simplify Queue entry validation logic
```

## Versioning Rules

- Tags have **no `v` prefix**: `3.5.4` not `v3.5.4`
- **NEVER** create tags manually -- release-please handles this
- **NEVER** edit `CHANGELOG.md` manually -- it is auto-generated
- Version manifest: `.release-please-manifest.json`
- Config: `release-please-config.json`

## Breaking Changes

For breaking API changes, add `!` after the type or include `BREAKING CHANGE:` in the footer:

```
feat!: rename Animate to PlayAnimation

feat: redesign queue API

BREAKING CHANGE: Queue() now accepts an options table instead of positional arguments.
```

This triggers a **MAJOR** version bump.
