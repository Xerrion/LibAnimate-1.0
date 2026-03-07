---
name: create-animation
description: Step-by-step guide for creating new animation definitions in LibAnimate, including keyframe format, validation rules, easing options, and placement conventions.
---

# Create Animation

Guide for adding new animation definitions to `Animations.lua`.

## Workflow

1. Identify the animation category (Back, Sliding, Zooming, Fading, Move, Attention, Bouncing, Special)
2. Find the matching separator comment block in `Animations.lua`
3. Write the animation definition using the template below
4. Run `luacheck Animations.lua` to verify

## Animation Template

```lua
lib:RegisterAnimation("myAnimationName", {
    type = "entrance",        -- REQUIRED: "entrance", "exit", or "attention"
    defaultDuration = 0.6,    -- seconds (must be > 0)
    defaultDistance = 300,     -- pixels (used for translate properties)
    keyframes = {
        { progress = 0.0, translateX = 0, translateY = 1.0, alpha = 0 },
        { progress = 0.5, translateY = 0.2, alpha = 0.7 },
        { progress = 1.0, alpha = 1.0 },
    },
})
```

## Keyframe Rules

These are enforced by `RegisterAnimation` -- violations throw errors:

- Minimum **2 keyframes** required
- `progress` values must be **sorted ascending** (0.0 to 1.0)
- First keyframe **must** have `progress = 0.0`
- Last keyframe **must** have `progress = 1.0`
- `defaultDuration` must be > 0 if provided

## Available Properties

| Property | Default | Description |
|----------|---------|-------------|
| `translateX` | `0` | Horizontal offset as fraction of `defaultDistance` |
| `translateY` | `0` | Vertical offset as fraction of `defaultDistance` |
| `scale` | `1.0` | Uniform scale factor |
| `alpha` | `1.0` | Opacity (0 = invisible, 1 = fully visible) |

Only specify properties that **change** from defaults. Unspecified properties inherit from `PROPERTY_DEFAULTS`.

## Coordinate System

WoW coordinates: **positive Y = up**, **positive X = right**.
- `translateY = 1.0` with `defaultDistance = 300` means 300px upward
- `translateX = -1.0` with `defaultDistance = 300` means 300px leftward

## Per-Segment Easing

Each keyframe can have an optional `easing` field controlling interpolation **to** that keyframe:

```lua
{ progress = 0.6, scale = 1.2, easing = "easeOutCubic" }
{ progress = 1.0, scale = 1.0, easing = { 0.68, -0.55, 0.265, 1.55 } }
```

### Available Named Presets
`linear`, `easeIn`, `easeOut`, `easeInOut`, `easeInCubic`, `easeOutCubic`, `easeInOutCubic`, `easeInBack`, `easeOutBack`, `easeInOutBack`

### Custom Cubic-Bezier
Pass a table of 4 numbers: `{ x1, y1, x2, y2 }` (control points, same as CSS `cubic-bezier()`).

## Naming Conventions

- Animation names use **camelCase**: `backInDown`, `fadeOutUp`, `zoomInLeft`
- Match animate.css names where applicable
- Entrance/exit pairs should mirror each other (e.g., `fadeIn` / `fadeOut`)

## File Organization

Animations are grouped by category with separator comment blocks:

```lua
------------------------------------------------------------
-- Category Name
------------------------------------------------------------
```

Place new animations within the appropriate category block, after existing animations in that group.
