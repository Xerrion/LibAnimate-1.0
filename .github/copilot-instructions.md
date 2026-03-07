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

### Naming Conventions
- `PascalCase` for public/API functions: `Animate`, `RegisterAnimation`, `GetQueueInfo`
- `camelCase` for local variables and private functions: `animData`, `defaultDuration`
- `UPPER_SNAKE_CASE` for constants: `PROPERTY_DEFAULTS`, `MAJOR`, `MINOR`

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

## Git Workflow
- NEVER work on master -- feature branches only
- Conventional commits required (see table above)
- release-please automates versioning (see CI/CD section)
- Use PowerShell, not CMD

## Packaging (.pkgmeta)
- `package-as`: LibAnimate
- `enable-toc-creation`: yes
- External dependency: LibStub (from wowace repos)
- Ignored in package: `.md` files, `.github/`, config files, `AGENTS.md`, `icon.png`, LibStub tests
