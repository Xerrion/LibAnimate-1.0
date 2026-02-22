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

LibAnimate is a standalone, LibStub-based animation library that provides smooth, keyframe-driven animations for any WoW frame. It uses an **OnUpdate-based rendering engine** rather than WoW's built-in Animation/AnimationGroup system, which suffers from long-standing bugs with alpha persistence and Translation offset semantics. See the **[Wiki](https://github.com/Xerrion/LibAnimate/wiki)** for full documentation.

## Features

- **OnUpdate-driven** â€” Avoids WoW AnimationGroup bugs entirely
- **Single shared driver frame** â€” All animations run through one OnUpdate handler
- **Keyframe interpolation** â€” Define animations as keyframes with translate, scale, and alpha
- **Per-segment easing** â€” Named presets or custom cubic-bezier curves per keyframe segment
- **77 built-in animations** â€” Entrance, exit, and attention-seeker animations
- **Extensible** â€” Register custom animations via `RegisterAnimation`
- **Delay & repeat** â€” Start after a delay, loop animations with `repeatCount`
- **Animation queues** â€” Chain animations in sequence with per-step callbacks

## Supported Versions

| Version | Interface |
|---------|-----------|
| Retail | 110207 |
| TBC Anniversary | 20505 |
| MoP Classic | 50503 |

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

## API Overview

| Method | Description |
|--------|-------------|
| `Animate(frame, name, opts?)` | Play an animation on a frame |
| `Stop(frame)` | Stop and restore to pre-animation state |
| `UpdateAnchor(frame, x, y)` | Update base anchor during animation |
| `IsAnimating(frame)` | Check if a frame is animating |
| `GetAnimationInfo(name)` | Get an animation's definition table |
| `GetAnimationNames()` | List all registered animation names |
| `GetEntranceAnimations()` | List entrance animation names |
| `GetExitAnimations()` | List exit animation names |
| `GetAttentionAnimations()` | List attention seeker names |
| `Queue(frame, entries, opts?)` | Queue a sequence of animations on a frame |
| `ClearQueue(frame)` | Cancel an animation queue and stop |
| `IsQueued(frame)` | Check if a frame has a pending queue |
| `RegisterAnimation(name, def)` | Register a custom animation |

For detailed parameters, return types, and examples, see the **[API Reference](https://github.com/Xerrion/LibAnimate/wiki/API-Reference)**.

## Built-in Animations

| Category | Count |
|----------|-------|
| Attention Seekers | 10 |
| Back | 8 |
| Bouncing | 10 |
| Fading | 26 |
| Sliding | 8 |
| Zooming | 10 |
| Specials | 1 |
| Utility | 4 |
| **Total** | **77** |

Browse the full catalog with descriptions in the **[Animation Catalog](https://github.com/Xerrion/LibAnimate/wiki/Animation-Catalog)**.

## Documentation

For comprehensive documentation, visit the **[LibAnimate Wiki](https://github.com/Xerrion/LibAnimate/wiki)**:

- **[Getting Started](https://github.com/Xerrion/LibAnimate/wiki/Getting-Started)** â€” Installation, first animation, key concepts
- **[API Reference](https://github.com/Xerrion/LibAnimate/wiki/API-Reference)** â€” Complete method documentation
- **[Animation Catalog](https://github.com/Xerrion/LibAnimate/wiki/Animation-Catalog)** â€” All 77 built-in animations
- **[Custom Animations](https://github.com/Xerrion/LibAnimate/wiki/Custom-Animations)** â€” Create your own animations
- **[Easing Functions](https://github.com/Xerrion/LibAnimate/wiki/Easing-Functions)** â€” Presets and cubic-bezier curves

## License

MIT â€” See [LICENSE](LICENSE) file.
