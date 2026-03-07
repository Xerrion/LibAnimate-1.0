---
name: add-api-method
description: Guide for adding public API methods and private helpers to LibAnimate, covering LuaLS annotations, error handling, state access, and placement conventions.
---

# Add API Method

Guide for adding new public API methods or private helpers to `LibAnimate.lua`.

## Public Method Template

Public methods are attached to `lib` and use `self`:

```lua
---@param frame Frame The target frame
---@param animationName string Name of a registered animation
---@return boolean success Whether the operation succeeded
function lib:MyMethod(frame, animationName)
    if type(frame) ~= "table" then
        error("LibAnimate: 'frame' must be a Frame", 2)
    end
    if type(animationName) ~= "string" then
        error("LibAnimate: 'animationName' must be a string", 2)
    end

    local animData = self.animations[animationName]
    if not animData then
        error("LibAnimate: Unknown animation '" .. animationName .. "'", 2)
    end

    -- Implementation here
    return true
end
```

## Private Helper Template

Private functions are **local**, never attached to `lib`:

```lua
---@param progress number Current animation progress (0-1)
---@param keyframes Keyframe[] Sorted keyframe list
---@return number interpolatedValue
local function myHelper(progress, keyframes)
    -- Implementation here
end
```

## Placement in File

- **Private helpers**: Place as local functions **before** the public API section
- **Public methods**: Place after existing public API methods, **before** `RegisterAnimation` (which should remain last)
- Use separator comment blocks between logical sections:

```lua
------------------------------------------------------------
-- Section Name
------------------------------------------------------------
```

## Input Validation

- Use `error("LibAnimate: descriptive message", 2)` for all public API validation
- Level `2` reports the error at the **caller's** location, not inside the library
- Validate types: `type(x) ~= "string"`, `type(x) ~= "table"`, `type(x) ~= "number"`
- Check animation existence: `self.animations[name]`
- Check active state: `self.activeAnimations[frame]`
- Check queue existence: `self.animationQueues[frame]`

## Callback Safety

When invoking user-supplied callbacks, **never** let errors crash the OnUpdate driver:

```lua
if callback then
    local ok, err = pcall(callback, frame)
    if not ok then
        geterrorhandler()(err)
    end
end
```

## LuaLS Type Annotations

Annotate all public methods. Reference existing types:

| Type | Description |
|------|-------------|
| `Frame` | WoW frame object |
| `AnimationDefinition` | Table with type, keyframes, defaultDuration, defaultDistance |
| `Keyframe` | Single keyframe with progress + property values |
| `AnimateOpts` | Options table for `lib:Animate()` |
| `QueueEntry` | Single entry in an animation queue |
| `QueueOpts` | Options table for `lib:Queue()` |
| `AnimationState` | Runtime state of an active animation |
| `EasingSpec` | String preset name or `{x1, y1, x2, y2}` cubic-bezier table |
| `EasingFunction` | `fun(t: number): number` |

## State Tables

| Table | Keys | Values | Purpose |
|-------|------|--------|---------|
| `self.animations` | animation name | `AnimationDefinition` | Registered animation library |
| `self.activeAnimations` | frame | `AnimationState` | Currently playing animations |
| `self.animationQueues` | frame | `QueueEntry[]` | Queued animation sequences |

## Checklist

1. Add LuaLS `---@param` and `---@return` annotations
2. Validate all inputs with `error("...", 2)`
3. Wrap callbacks in `pcall` + `geterrorhandler()()`
4. Place in correct file section
5. Run `luacheck LibAnimate.lua`
