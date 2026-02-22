# LibAnimate

A keyframe-driven animation library for World of Warcraft addons, inspired by [animate.css](https://animate.style/).

## Overview

LibAnimate is a standalone, LibStub-based animation library that provides smooth, keyframe-driven animations for any WoW frame. It uses an **OnUpdate-based rendering engine** rather than WoW's built-in Animation/AnimationGroup system, which suffers from long-standing bugs with alpha persistence and Translation offset semantics.

**Key features:**

- **OnUpdate-driven** — Avoids WoW AnimationGroup bugs entirely
- **Single shared driver frame** — All animations run through one OnUpdate handler for efficiency
- **Keyframe interpolation** — Define animations as a series of keyframes with progress, translate, scale, and alpha
- **Per-segment easing** — Each keyframe segment can use a different easing function or custom cubic-bezier curve
- **32 built-in animations** — Slide, zoom, back, fade, and move-style entrance/exit animations out of the box
- **Extensible** — Register custom animations via `RegisterAnimation`

**Supported WoW versions:** Retail, MoP Classic, TBC Anniversary, Classic Era

## Installation

### Via .pkgmeta (recommended)

For addon authors using [BigWigsMods/packager](https://github.com/BigWigsMods/packager), add the following to your `.pkgmeta`:

```yaml
externals:
  Libs/LibStub:
    url: https://repos.wowace.com/wow/libstub/trunk
    tag: latest
  Libs/LibAnimate:
    url: https://github.com/Xerrion/LibAnimate
```

Then in your `.toc` file:

```
Libs\LibStub\LibStub.lua
Libs\LibAnimate\lib.xml
```

### Manual

Download the library and place it in your addon's `Libs/` folder. Load `lib.xml` after LibStub in your `.toc`:

```
Libs\LibStub\LibStub.lua
Libs\LibAnimate\lib.xml
```

## Quick Start

```lua
local LibAnimate = LibStub("LibAnimate")

-- Animate a frame sliding in from the top
local myFrame = CreateFrame("Frame", nil, UIParent)
myFrame:SetSize(200, 50)
myFrame:SetPoint("CENTER", 0, 0)

-- Play entrance animation
LibAnimate:Animate(myFrame, "slideInDown", {
    duration = 0.5,
    distance = 300,
    onFinished = function()
        print("Animation complete!")
    end,
})

-- Later, play exit animation
LibAnimate:Animate(myFrame, "slideOutUp", {
    duration = 0.4,
    distance = 200,
    onFinished = function()
        myFrame:Hide()
    end,
})

-- Stop animation and restore frame to its base state
LibAnimate:Stop(myFrame)
```

## API Reference

### `lib:Animate(frame, animationName, options)`

Plays a named animation on a frame. If the frame is already animating, the current animation is stopped and the frame is restored before starting the new one.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `frame` | Frame | The WoW frame to animate. Must have at least one anchor point set via `SetPoint`. |
| `animationName` | string | Name of a registered animation (e.g., `"slideInDown"`, `"zoomOut"`). |
| `options` | table (optional) | Override table with the fields below. |

**Options fields:**

| Field | Type | Description |
|-------|------|-------------|
| `duration` | number | Animation duration in seconds. Defaults to the animation definition's `defaultDuration`. |
| `distance` | number | Distance in pixels for translate-based animations. Defaults to the animation definition's `defaultDistance`. |
| `onFinished` | function | Callback invoked when the animation completes naturally (not when stopped via `Stop`). |

**Errors:** Throws if `animationName` is not registered or if the frame has no anchor point.

---

### `lib:Stop(frame)`

Immediately stops any active animation on the frame and restores it to its base state (original anchor position, alpha = 1, scale = 1).

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `frame` | Frame | The frame to stop animating. |

---

### `lib:UpdateAnchor(frame, x, y)`

Updates the stored base anchor position for a frame that is currently animating. Useful for repositioning toast frames mid-animation (e.g., when the frame above in a stack is dismissed).

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `frame` | Frame | The frame currently being animated. |
| `x` | number | New anchor X offset. |
| `y` | number | New anchor Y offset. |

---

### `lib:IsAnimating(frame)`

Returns whether the given frame currently has an active animation.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `frame` | Frame | The frame to check. |

**Returns:** `boolean`

---

### `lib:GetAnimationNames()`

Returns a sorted list of all registered animation names.

**Returns:** `table` — Array of strings.

---

### `lib:GetEntranceAnimations()`

Returns a sorted list of all registered entrance animation names (where `definition.type == "entrance"`).

**Returns:** `table` — Array of strings.

---

### `lib:GetExitAnimations()`

Returns a sorted list of all registered exit animation names (where `definition.type == "exit"`).

**Returns:** `table` — Array of strings.

---

### `lib:RegisterAnimation(name, definition)`

Registers a custom animation definition. Can also override built-in animations.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | Unique animation name. |
| `definition` | table | Animation definition (see fields below). |

**Definition fields:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `type` | string | Yes | Either `"entrance"` or `"exit"`. |
| `defaultDuration` | number | No | Default duration in seconds. |
| `defaultDistance` | number | No | Default distance in pixels. |
| `keyframes` | table | Yes | Array of keyframe tables (minimum 2). See below. |

**Keyframe fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `progress` | number | — | Position in the animation timeline, `0.0` to `1.0`. Required. |
| `translateX` | number | `0` | Horizontal offset as a fraction of `distance`. |
| `translateY` | number | `0` | Vertical offset as a fraction of `distance`. **Positive Y = up** (WoW coordinates). |
| `scale` | number | `1.0` | Scale factor. |
| `alpha` | number | `1.0` | Opacity, `0.0` to `1.0`. |
| `easing` | string or table | `nil` | Easing for the segment FROM this keyframe TO the next. A string selects a preset name; a table of `{p1x, p1y, p2x, p2y}` defines custom cubic-bezier control points. |

**Errors:** Throws if `name` is not a string, `definition` is not a table, `type` is missing, or fewer than 2 keyframes are provided.

## Built-in Animations

| Name | Type | Default Duration | Default Distance | Description |
|------|------|-----------------|-----------------|-------------|
| backInDown | entrance | 0.6s | 300 | Slides in from above with scale bounce |
| backInUp | entrance | 0.6s | 300 | Slides in from below with scale bounce |
| backInLeft | entrance | 0.6s | 300 | Slides in from the left with scale bounce |
| backInRight | entrance | 0.6s | 300 | Slides in from the right with scale bounce |
| backOutDown | exit | 0.6s | 300 | Slides out downward with scale shrink |
| backOutUp | exit | 0.6s | 300 | Slides out upward with scale shrink |
| backOutLeft | exit | 0.6s | 300 | Slides out to the left with scale shrink |
| backOutRight | exit | 0.6s | 300 | Slides out to the right with scale shrink |
| slideInDown | entrance | 0.4s | 200 | Slides in from above |
| slideInUp | entrance | 0.4s | 200 | Slides in from below |
| slideInLeft | entrance | 0.4s | 200 | Slides in from the left |
| slideInRight | entrance | 0.4s | 200 | Slides in from the right |
| slideOutDown | exit | 0.4s | 200 | Slides out downward |
| slideOutUp | exit | 0.4s | 200 | Slides out upward |
| slideOutLeft | exit | 0.4s | 200 | Slides out to the left |
| slideOutRight | exit | 0.4s | 200 | Slides out to the right |
| zoomIn | entrance | 0.5s | 0 | Zooms in from small scale |
| zoomInDown | entrance | 0.5s | 400 | Zooms in from above |
| zoomInUp | entrance | 0.5s | 400 | Zooms in from below |
| zoomInLeft | entrance | 0.5s | 400 | Zooms in from the left |
| zoomInRight | entrance | 0.5s | 400 | Zooms in from the right |
| zoomOut | exit | 0.5s | 0 | Zooms out to nothing |
| zoomOutDown | exit | 0.5s | 400 | Zooms out downward |
| zoomOutUp | exit | 0.5s | 400 | Zooms out upward |
| zoomOutLeft | exit | 0.5s | 400 | Zooms out to the left |
| zoomOutRight | exit | 0.5s | 400 | Zooms out to the right |
| fadeIn | entrance | 0.3s | 0 | Fades in from transparent |
| fadeOut | exit | 0.3s | 0 | Fades out to transparent |
| moveUp | entrance | 0.2s | 50 | Moves up into position |
| moveDown | entrance | 0.2s | 50 | Moves down into position |
| moveLeft | entrance | 0.2s | 50 | Moves left into position |
| moveRight | entrance | 0.2s | 50 | Moves right into position |

## Custom Animations

You can register your own animations using `RegisterAnimation`. Animations are defined as a series of keyframes that the library interpolates between during playback.

```lua
local LibAnimate = LibStub("LibAnimate")

-- Custom "bounceIn" animation
LibAnimate:RegisterAnimation("bounceIn", {
    type = "entrance",
    defaultDuration = 0.75,
    defaultDistance = 0,
    keyframes = {
        { progress = 0.0, scale = 0.3, alpha = 0 },
        { progress = 0.5, scale = 1.05, alpha = 1, easing = "easeOutQuad" },
        { progress = 0.7, scale = 0.95, easing = "easeInOutQuad" },
        { progress = 1.0, scale = 1.0 },
    },
})

-- Use it
LibAnimate:Animate(myFrame, "bounceIn")
```

**Coordinate system note:** WoW's Y-axis is inverted compared to CSS. Positive `translateY` values move the frame **up**, negative values move it **down**.

## Easing Functions

### Built-in Presets

| Name | Description |
|------|-------------|
| `linear` | Constant speed, no acceleration |
| `easeInQuad` | Accelerating from zero velocity |
| `easeOutQuad` | Decelerating to zero velocity |
| `easeInOutQuad` | Acceleration then deceleration |
| `easeInCubic` | Accelerating from zero velocity (steeper) |
| `easeOutCubic` | Decelerating to zero velocity (steeper) |
| `easeInOutCubic` | Acceleration then deceleration (steeper) |
| `easeInBack` | Pulls back slightly before accelerating |
| `easeOutBack` | Overshoots slightly before settling |
| `easeInOutBack` | Pull back + overshoot |

### Custom Cubic-Bezier

You can specify custom cubic-bezier control points as a table of four numbers `{p1x, p1y, p2x, p2y}` on any keyframe's `easing` field:

```lua
-- Per-segment cubic-bezier easing in keyframe definitions
{ progress = 0.0, scale = 0.3, easing = {0.55, 0.055, 0.675, 0.19} },
```

## License

MIT — See [LICENSE](LICENSE) file.
