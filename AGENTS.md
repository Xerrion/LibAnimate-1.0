# LibAnimate - Agent Guidelines

A standalone, LibStub-based WoW animation library providing keyframe-driven animations for any WoW frame, inspired by animate.css.

## Architecture

### Core Design
- **OnUpdate-based rendering** - Single shared driver frame, avoids WoW's buggy Animation/AnimationGroup system
- **Keyframe interpolation** - Animations defined as keyframe lists with property values at progress points
- **Per-segment easing** - Named presets + full cubic-bezier via Newton-Raphson solver
- **RegisterAnimation API** - Extensible: external addons can register custom animations
- **State management** - `lib.animations`, `lib.activeAnimations`, `lib.animationQueues`

### Files
| File | Purpose |
|------|---------|
| `LibAnimate.lua` | Engine, public API, easing functions, cubic-bezier solver, OnUpdate driver |
| `Animations.lua` | 50+ built-in animation definitions (Back, Sliding, Zooming, Fading, Move, Attention, Bouncing, Special) |
| `lib.xml` | XML loader (load order: LibStub -> LibAnimate.lua -> Animations.lua) |
| `LibAnimate.toc` | Standalone TOC file |
| `.luacheckrc` | Luacheck linting configuration |

### Supported WoW Versions
- Retail (110207 / 120001)
- TBC Anniversary (20505)
- MoP Classic (50502 / 50503)

## Build / Lint / Test

### Linting
```sh
luacheck .                    # Lint all files
luacheck LibAnimate.lua       # Lint single file
luacheck Animations.lua       # Lint single file
```
CI runs `nebularg/actions-luacheck` on PRs to master with `--no-color`.

### Testing
No unit test framework. This is a WoW addon library -- testing is done in-game.

### Building
No build step. Lua files are loaded directly by the WoW client. Distribution packaging uses `BigWigsMods/packager@v2`.

## Code Style

### Formatting
- **4 spaces** indentation (NO tabs)
- **120 char** max line length
- `std = "lua51"` -- WoW uses Lua 5.1
- Use **PowerShell**, not CMD

### File Header
Every Lua file starts with:

```lua
-------------------------------------------------------------------------------
-- FileName.lua
-- Brief description
--
-- Supported versions: Retail, MoP Classic, TBC Anniversary, Cata, Classic
-------------------------------------------------------------------------------
```

### Naming

| Element | Convention | Example |
|---------|------------|---------|
| Files | PascalCase | `MyAddon_Core.lua` |
| SavedVariables | PascalCase | `MyAddonDB` |
| Local variables | camelCase | `local currentState` |
| Functions (public or local) | PascalCase | `local function UpdateState()` |
| Constants | UPPER_SNAKE | `local MAX_RETRIES = 5` |
| Slash commands | UPPER_SNAKE | `SLASH_MYADDON1` |
| Color codes | UPPER_SNAKE | `local COLOR_RED = "\|cffff0000"` |
| Unused args | underscore prefix | `local _unused` |

### Globals and Caching
Cache WoW API globals as locals at the top of the file:
```lua
local GetTime = GetTime
local CreateFrame = CreateFrame
local geterrorhandler = geterrorhandler
local pairs, next, ipairs, type = pairs, next, ipairs, type
local math_min = math.min
local math_abs = math.abs
local math_floor = math.floor
local table_sort = table.sort
local table_insert = table.insert
local table_remove = table.remove
```

### Type Annotations
Use LuaLS annotations for all public types and APIs:
```lua
---@class LibAnimate
---@alias EasingFunction fun(t: number): number
---@param frame Frame
---@param animationName string
---@return boolean
```

### Error Handling
- `error("message", 2)` with level 2 for public API input validation (reports at caller)
- `pcall()` + `geterrorhandler()()` for callback invocation (don't crash the driver)
- Never let errors in one animation crash the entire OnUpdate loop

### Luacheck
- `std = "lua51"`, `max_line_length = 120`, `codes = true`
- Ignore 212 for `self` parameters
- Inline ignores: `-- luacheck: ignore 542` for intentional empty if-blocks
- `read_globals`: Lua builtins, WoW API (`CreateFrame`, `GetTime`, `UIParent`, `geterrorhandler`), `LibStub`
- Excludes: `Libs/*`

### Code Organization
- Separator comment blocks (dashes) between sections
- Private functions are local, NOT attached to `lib`
- Public API methods use `self` parameter (attached to `lib` table)
- Keep functions under 50 lines; extract helpers when longer
- Prefer composition over inheritance

---

## Versioning and File Loading
- Do not gate features with runtime version checks
- Split version-specific code into separate files
- Load with TOC `## Interface` / `## Interface-*` directives or packager comment
  directives (`#@retail@`, `#@non-retail@`)

Packager directives are comments locally, so later files can override earlier ones.

---

## Common Pitfalls
- Missing APIs for a target version -- check `docs/` for the exact client build
- Deprecated globals like `COMBATLOGENABLED` and `COMBATLOGDISABLED` (removed in Cata;
  always provide `or` fallbacks)
- Race conditions on `PLAYER_ENTERING_WORLD` -- use a short `C_Timer.After` delay
- Timer leaks -- cancel `C_Timer` or `AceTimer` handles before reusing
- `GetItemInfo` or item data can be nil on first call -- retry with a timer

## Animation Definition Format

```lua
{
    type = "entrance",        -- "entrance", "exit", or "attention"
    defaultDuration = 0.6,    -- seconds
    defaultDistance = 300,     -- pixels
    keyframes = {
        { time = 0.0, translateX = 0, translateY = 1.0, scale = 0.7, alpha = 0.7 },
        { time = 0.8, translateY = 0, scale = 0.7, alpha = 0.7 },
        { time = 1.0, scale = 1.0, alpha = 1.0 },
    },
}
```

**Properties:** `translateX`, `translateY` (fraction of distance), `scale` (uniform), `alpha` (opacity).
**Defaults:** translateX=0, translateY=0, scale=1.0, alpha=1.0 (`PROPERTY_DEFAULTS` table).
**Coordinates:** WoW system (positive Y = up, positive X = right).

## CI/CD

### Release Flow (release-please)
- `release-please-action@v4` creates/updates a Release PR on every push to master
- Merging the Release PR creates a git tag + GitHub Release
- Tag push triggers `BigWigsMods/packager@v2` for CurseForge + Wago uploads
- Config: `release-please-config.json`, manifest: `.release-please-manifest.json`
- DO NOT manually create tags -- release-please handles versioning
- No `v` prefix in tags (e.g., `3.5.4` not `v3.5.4`)

### Conventional Commit Mapping
| Prefix | Changelog Section | Hidden? |
|--------|-------------------|---------|
| `feat:` | Features | No |
| `fix:` | Bug Fixes | No |
| `perf:` | Performance | No |
| `refactor:` | Refactor | No |
| `docs:` | Documentation | No |
| `style:` | Styling | No |
| `test:` | Testing | No |
| `ci:` | CI/CD | No |
| `chore:` | Miscellaneous | Yes |
| `revert:` | Reverts | No |

## GitHub Workflow

### Issues
Create issues using the repo's issue templates (`.github/ISSUE_TEMPLATE/`):
- **Bug reports**: Use `bug-report.yml` template. Title prefix: `[Bug]: `
- **Feature requests**: Use `feature-request.yml` template. Title prefix: `[Feature]: `

Create via CLI:
```bash
gh issue create --repo <ORG>/<REPO> --label "bug" --title "[Bug]: <title>" --body "<body matching template fields>"
gh issue create --repo <ORG>/<REPO> --label "enhancement" --title "[Feature]: <title>" --body "<body matching template fields>"
```

### Branches
Use conventional branch prefixes:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature | `feat/87-mail-toasts` |
| `fix/` | Bug fix | `fix/99-anchor-zorder` |
| `refactor/` | Code improvement | `refactor/96-listener-utils` |

Include the issue number in the branch name when linked to an issue.

### Commits
Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat: <description> (#issue)` - new feature
- `fix: <description> (#issue)` - bug fix
- `refactor: <description> (#issue)` - code restructuring
- `docs: <description>` - documentation only

Always use `--no-gpg-sign` (GPG signing not available in CI agent environments).

### Pull Requests
1. Create PRs via CLI using the repo's `.github/PULL_REQUEST_TEMPLATE.md` format
2. Link to the issue with `Closes #N` in the PR body
3. PRs require passing status checks (luacheck, test) before merge
4. Squash merge only: `gh pr merge <number> --squash`
5. Branches are auto-deleted after merge

### Project Boards
When a repo has a GitHub Projects board, update issue status as work progresses:

| Phase | Board Status | Action |
|-------|-------------|--------|
| Triaged/planned | Ready | Issue is understood and ready for work |
| Work starts | In progress | Add comment describing the approach |
| PR created | In review | Add comment with PR link |
| PR merged | Done | Auto-updated by GitHub automation or manual move |

Use `gh project` CLI commands to update board status:
```bash
gh project item-list <PROJECT_NUMBER> --owner <ORG> --format json
gh project field-list <PROJECT_NUMBER> --owner <ORG> --format json
gh project item-edit --project-id <ID> --id <ITEM_ID> --field-id <FIELD_ID> --single-select-option-id <OPTION_ID>
```

Add comments on issues at each phase transition to maintain a clear audit trail.

## Packaging (.pkgmeta)
- `package-as`: LibAnimate
- `enable-toc-creation`: yes
- External dependency: LibStub (from wowace repos)
- Ignored in package: `.md` files, `.github/`, config files, `AGENTS.md`, `icon.png`, LibStub tests

---

## Working Agreement for Agents
- Addon-level AGENTS.md overrides root rules when present
- Do not add new dependencies without discussing trade-offs
- Run luacheck before and after changes
- If only manual tests exist, document what you verified in-game
- Verify changes in the game client when possible
- Keep changes small and focused; prefer composition over inheritance

---

## Communication Style

When responding to or commenting on issues, always write in **first-person singular** ("I")
as the repo owner -- never use "we" or "our team". Speak as if you are the developer personally.

**Writing style:**
- Direct, structured, solution-driven. Get to the point fast. Text is a tool, not decoration.
- Think in systems. Break things into flows, roles, rules, and frameworks.
- Bias toward precision. Concrete output, copy-paste-ready solutions, clear constraints. Low
  tolerance for fluff.
- Tone is calm and rational with small flashes of humor and self-awareness.
- When confident in a topic, become more informal and creative.
- When something matters, become sharp and focused.
