# LibAnimate — Agent Guidelines

A standalone, LibStub-based WoW animation library providing keyframe-driven animations for any WoW frame, inspired by animate.css.

## Architecture

### Core Design
- **OnUpdate-based rendering** — Single shared driver frame, avoids WoW's buggy Animation/AnimationGroup system
- **Keyframe interpolation** — Animations defined as keyframe lists with property values at progress points
- **Per-segment easing** — Named presets + full cubic-bezier via Newton-Raphson solver
- **RegisterAnimation API** — Extensible: external addons can register custom animations

### Files
| File | Purpose |
|------|---------|
| `LibAnimate.lua` | Engine, API, easing functions |
| `Animations.lua` | 24 built-in animation definitions |
| `lib.xml` | XML loader (load order) |
| `LibAnimate.toc` | Standalone TOC |

### Supported Versions
- Retail (110207)
- TBC Anniversary (20505)
- MoP Classic (50503)

## Code Style
- **4 spaces** indentation, **120 char** max line length
- `std = "lua51"` — WoW uses Lua 5.1
- Cache WoW API globals as locals
- PascalCase functions, camelCase locals, UPPER_SNAKE constants

## Animation Definition Format
```lua
{
    type = "entrance",        -- or "exit"
    defaultDuration = 0.6,    -- seconds
    defaultDistance = 300,     -- pixels
    keyframes = {
        { time = 0.0, translateX = 0, translateY = 1.0, scale = 0.7, alpha = 0.7 },
        { time = 0.8, translateY = 0, scale = 0.7, alpha = 0.7 },
        { time = 1.0, scale = 1.0, alpha = 1.0 },
    },
}
```

Properties: `translateX`, `translateY` (fraction of distance), `scale` (uniform), `alpha` (opacity).
Coordinate system: WoW (positive Y = up, positive X = right).

## Git Workflow
- NEVER work on master — feature branches only
- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `ci:`
- release-please automates versioning — DO NOT manually tag
- Use PowerShell, not CMD
