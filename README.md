<p align="center">
  <img src="icon.png" alt="LibAnimate" width="128" />
</p>

# LibAnimate

[![GitHub release](https://img.shields.io/github/v/release/Xerrion/LibAnimate?style=flat-square)](https://github.com/Xerrion/LibAnimate/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
[![Lint](https://img.shields.io/github/actions/workflow/status/Xerrion/LibAnimate/lint.yml?label=lint&style=flat-square)](https://github.com/Xerrion/LibAnimate/actions/workflows/lint.yml)
[![Wiki](https://img.shields.io/badge/docs-Wiki-brightgreen?style=flat-square)](https://github.com/Xerrion/LibAnimate/wiki)

A keyframe-driven animation library for World of Warcraft addons, inspired by [animate.css](https://animate.style/).

## Overview

LibAnimate is a standalone, LibStub-based animation library that provides smooth, keyframe-driven animations for any WoW frame. It uses an **OnUpdate-based rendering engine** rather than WoW's built-in Animation/AnimationGroup system, which suffers from long-standing bugs with alpha persistence and Translation offset semantics.

**Key features:**

- **OnUpdate-driven** — Avoids WoW AnimationGroup bugs entirely
- **Single shared driver frame** — All animations run through one OnUpdate handler for efficiency
- **Keyframe interpolation** — Define animations as a series of keyframes with progress, translate, scale, and alpha
- **Per-segment easing** — Each keyframe segment can use a different easing function or custom cubic-bezier curve
- **77 built-in animations** — Entrance, exit, and attention-seeker animations inspired by animate.css
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

-- Play an attention-seeker animation (returns to original state)
LibAnimate:Animate(myFrame, "heartBeat")

-- Stop animation and restore frame to its base state
LibAnimate:Stop(myFrame)
```

## API Reference

### `lib:Animate(frame, animationName, options)`

Plays a named animation on a frame. If the frame is already animating, the current animation is stopped and the frame is restored before starting the new one.

The frame must have exactly one anchor point set via `SetPoint()`. Frames with multiple anchor points (two-point sizing) are not supported and will lose their secondary anchors during animation.

For exit animations, the frame is left at its final keyframe state when the animation completes. The consumer must handle cleanup (e.g. `frame:Hide()`) in the `onFinished` callback.

For attention-seeker animations, the frame returns to its original state when the animation completes (keyframes start and end at identity values).

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `frame` | Frame | The WoW frame to animate. Must have exactly one anchor point set via `SetPoint`. |
| `animationName` | string | Name of a registered animation (e.g., `"slideInDown"`, `"zoomOut"`, `"heartBeat"`). |
| `options` | table (optional) | Override table with the fields below. |

**Options fields:**

| Field | Type | Description |
|-------|------|-------------|
| `duration` | number | Animation duration in seconds. Defaults to the animation definition's `defaultDuration`. |
| `distance` | number | Distance in pixels for translate-based animations. Defaults to the animation definition's `defaultDistance`. |
| `onFinished` | function | Callback invoked when the animation completes naturally (not when stopped via `Stop`). Receives the frame as its argument. |

**Returns:** `boolean` — Always returns `true` on success.

**Errors:** Throws if `animationName` is not registered or if the frame has no anchor point.

---

### `lib:Stop(frame)`

Immediately stops any active animation on the frame and restores it to its pre-animation state (original anchor position, scale, and alpha). The `onFinished` callback is **not** fired when an animation is stopped.

Does nothing if the frame is not currently animating.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `frame` | Frame | The frame to stop animating. |

---

### `lib:UpdateAnchor(frame, x, y)`

Updates the stored base anchor position for a frame that is currently animating. Useful for repositioning frames mid-animation (e.g., when a frame above in a notification stack is dismissed).

Does nothing if the frame is not currently animating.

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

### `lib:GetAnimationInfo(name)`

Returns the definition table for a registered animation.

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `name` | string | The animation name. |

**Returns:** `table` or `nil` — The animation definition table, or `nil` if the animation is not registered.

---

### `lib:GetAnimationNames()`

Returns a sorted list of all registered animation names.

**Returns:** `table` — Array of strings, sorted alphabetically.

---

### `lib:GetEntranceAnimations()`

Returns a sorted list of all registered entrance animation names (where `definition.type == "entrance"`).

**Returns:** `table` — Array of strings, sorted alphabetically.

---

### `lib:GetExitAnimations()`

Returns a sorted list of all registered exit animation names (where `definition.type == "exit"`).

**Returns:** `table` — Array of strings, sorted alphabetically.

---

### `lib:GetAttentionAnimations()`

Returns a sorted list of all registered attention-seeker animation names (where `definition.type == "attention"`).

**Returns:** `table` — Array of strings, sorted alphabetically.

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
| `type` | string | Yes | `"entrance"`, `"exit"`, or `"attention"`. |
| `defaultDuration` | number | No | Default duration in seconds. |
| `defaultDistance` | number | No | Default distance in pixels for translate-based animations. |
| `keyframes` | table | Yes | Array of keyframe tables (minimum 2). See below. |

**Keyframe fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `progress` | number | — | Position in the animation timeline, `0.0` to `1.0`. Required. First keyframe must be `0.0`, last must be `1.0`. |
| `translateX` | number | `0` | Horizontal offset as a fraction of `distance`. Positive = right. |
| `translateY` | number | `0` | Vertical offset as a fraction of `distance`. **Positive Y = up** (WoW coordinates). |
| `scale` | number | `1.0` | Uniform scale factor. Clamped to a minimum of `0.001` internally. |
| `alpha` | number | `1.0` | Opacity, `0.0` to `1.0`. |
| `easing` | string or table | `nil` | Easing for the segment **from** this keyframe **to** the next. A string selects a preset name; a table of `{p1x, p1y, p2x, p2y}` defines custom cubic-bezier control points. |

**Keyframe requirements:**
- At least 2 keyframes
- Sorted ascending by `progress`
- First keyframe must have `progress = 0.0`
- Last keyframe must have `progress = 1.0`

**Errors:** Throws if `name` is not a string, `definition` is not a table, `type` is missing, keyframes are invalid, or `defaultDuration` is not positive.

## Built-in Animations

### Attention Seekers

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| bounce | 1.0s | 30 | Bounces the frame up and down |
| flash | 1.0s | 0 | Blinks the frame on and off twice |
| pulse | 1.0s | 0 | Subtle scale throb |
| rubberBand | 1.0s | 0 | Elastic scale oscillation |
| shakeX | 1.0s | 10 | Rapid horizontal shake |
| shakeY | 1.0s | 10 | Rapid vertical shake |
| headShake | 1.0s | 6 | Damped horizontal oscillation |
| tada | 1.0s | 0 | Scale pulse for emphasis |
| wobble | 1.0s | 100 | Side-to-side sway with decreasing amplitude |
| heartBeat | 1.3s | 0 | Double-pulse heartbeat scale effect |

### Back Entrances

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| backInDown | 0.6s | 300 | Slides in from above with scale bounce |
| backInUp | 0.6s | 300 | Slides in from below with scale bounce |
| backInLeft | 0.6s | 300 | Slides in from the left with scale bounce |
| backInRight | 0.6s | 300 | Slides in from the right with scale bounce |

### Back Exits

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| backOutDown | 0.6s | 300 | Slides out downward with scale shrink |
| backOutUp | 0.6s | 300 | Slides out upward with scale shrink |
| backOutLeft | 0.6s | 300 | Slides out to the left with scale shrink |
| backOutRight | 0.6s | 300 | Slides out to the right with scale shrink |

### Bouncing Entrances

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| bounceIn | 0.75s | 0 | Scale-based bounce entrance |
| bounceInDown | 1.0s | 500 | Bounces in from above |
| bounceInLeft | 1.0s | 500 | Bounces in from the left |
| bounceInRight | 1.0s | 500 | Bounces in from the right |
| bounceInUp | 1.0s | 500 | Bounces in from below |

### Bouncing Exits

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| bounceOut | 0.75s | 0 | Scale-based bounce exit |
| bounceOutDown | 1.0s | 500 | Bounces out downward |
| bounceOutLeft | 1.0s | 500 | Bounces out to the left |
| bounceOutRight | 1.0s | 500 | Bounces out to the right |
| bounceOutUp | 1.0s | 500 | Bounces out upward |

### Fading Entrances

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| fadeIn | 0.3s | 0 | Fades in from transparent |
| fadeInDown | 0.5s | 100 | Fades in while sliding from above |
| fadeInDownBig | 0.5s | 2000 | Fades in while sliding from far above |
| fadeInLeft | 0.5s | 100 | Fades in while sliding from the left |
| fadeInLeftBig | 0.5s | 2000 | Fades in while sliding from far left |
| fadeInRight | 0.5s | 100 | Fades in while sliding from the right |
| fadeInRightBig | 0.5s | 2000 | Fades in while sliding from far right |
| fadeInUp | 0.5s | 100 | Fades in while sliding from below |
| fadeInUpBig | 0.5s | 2000 | Fades in while sliding from far below |
| fadeInTopLeft | 0.5s | 100 | Fades in from the top-left corner |
| fadeInTopRight | 0.5s | 100 | Fades in from the top-right corner |
| fadeInBottomLeft | 0.5s | 100 | Fades in from the bottom-left corner |
| fadeInBottomRight | 0.5s | 100 | Fades in from the bottom-right corner |

### Fading Exits

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| fadeOut | 0.3s | 0 | Fades out to transparent |
| fadeOutDown | 0.5s | 100 | Fades out while sliding downward |
| fadeOutDownBig | 0.5s | 2000 | Fades out while sliding far downward |
| fadeOutLeft | 0.5s | 100 | Fades out while sliding to the left |
| fadeOutLeftBig | 0.5s | 2000 | Fades out while sliding far left |
| fadeOutRight | 0.5s | 100 | Fades out while sliding to the right |
| fadeOutRightBig | 0.5s | 2000 | Fades out while sliding far right |
| fadeOutUp | 0.5s | 100 | Fades out while sliding upward |
| fadeOutUpBig | 0.5s | 2000 | Fades out while sliding far upward |
| fadeOutTopLeft | 0.5s | 100 | Fades out toward the top-left corner |
| fadeOutTopRight | 0.5s | 100 | Fades out toward the top-right corner |
| fadeOutBottomRight | 0.5s | 100 | Fades out toward the bottom-right corner |
| fadeOutBottomLeft | 0.5s | 100 | Fades out toward the bottom-left corner |

### Sliding Entrances

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| slideInDown | 0.4s | 200 | Slides in from above |
| slideInUp | 0.4s | 200 | Slides in from below |
| slideInLeft | 0.4s | 200 | Slides in from the left |
| slideInRight | 0.4s | 200 | Slides in from the right |

### Sliding Exits

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| slideOutDown | 0.4s | 200 | Slides out downward |
| slideOutUp | 0.4s | 200 | Slides out upward |
| slideOutLeft | 0.4s | 200 | Slides out to the left |
| slideOutRight | 0.4s | 200 | Slides out to the right |

### Zooming Entrances

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| zoomIn | 0.5s | 0 | Zooms in from small scale |
| zoomInDown | 0.5s | 400 | Zooms in from above |
| zoomInUp | 0.5s | 400 | Zooms in from below |
| zoomInLeft | 0.5s | 400 | Zooms in from the left |
| zoomInRight | 0.5s | 400 | Zooms in from the right |

### Zooming Exits

| Name | Duration | Distance | Description |
|------|----------|----------|-------------|
| zoomOut | 0.5s | 0 | Zooms out to nothing |
| zoomOutDown | 0.5s | 400 | Zooms out downward |
| zoomOutUp | 0.5s | 400 | Zooms out upward |
| zoomOutLeft | 0.5s | 400 | Zooms out to the left |
| zoomOutRight | 0.5s | 400 | Zooms out to the right |

### Specials

| Name | Type | Duration | Distance | Description |
|------|------|----------|----------|-------------|
| jackInTheBox | entrance | 1.0s | 0 | Scale and alpha pop-in |

### Utility

| Name | Type | Duration | Distance | Description |
|------|------|----------|----------|-------------|
| moveUp | entrance | 0.2s | 50 | Moves up into position |
| moveDown | entrance | 0.2s | 50 | Moves down into position |
| moveLeft | entrance | 0.2s | 50 | Moves left into position |
| moveRight | entrance | 0.2s | 50 | Moves right into position |

## Custom Animations

You can register your own animations using `RegisterAnimation`. Animations are defined as a series of keyframes that the library interpolates between during playback.

```lua
local LibAnimate = LibStub("LibAnimate")

-- Custom slide-and-scale entrance
LibAnimate:RegisterAnimation("myCustomEntrance", {
    type = "entrance",
    defaultDuration = 0.5,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateX = -1.0, scale = 0.8, alpha = 0 },
        { progress = 0.7, translateX = 0.05, scale = 1.02, alpha = 1.0, easing = "easeOutCubic" },
        { progress = 1.0, translateX = 0, scale = 1.0 },
    },
})

-- Custom attention-seeker
LibAnimate:RegisterAnimation("myPulse", {
    type = "attention",
    defaultDuration = 0.8,
    defaultDistance = 0,
    keyframes = {
        { progress = 0.0, scale = 1.0, easing = "easeInOutCubic" },
        { progress = 0.5, scale = 1.2 },
        { progress = 1.0, scale = 1.0 },
    },
})

-- Use them
LibAnimate:Animate(myFrame, "myCustomEntrance")
LibAnimate:Animate(myFrame, "myPulse")
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

The `CubicBezier(p1x, p1y, p2x, p2y)` utility function is also available on the library table for creating reusable easing functions:

```lua
local myEasing = LibAnimate.CubicBezier(0.68, -0.55, 0.265, 1.55)
local easedValue = myEasing(0.5)  -- Returns the eased value at t=0.5
```

## License

MIT — See [LICENSE](LICENSE) file.
