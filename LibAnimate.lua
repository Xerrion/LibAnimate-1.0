-------------------------------------------------------------------------------
-- LibAnimate
-- Keyframe-driven animation library for World of Warcraft frames
-- Inspired by animate.css (https://animate.style)
--
-- Supported versions: Retail, TBC Anniversary, MoP Classic
-------------------------------------------------------------------------------

local MAJOR, MINOR = "LibAnimate", 1
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-------------------------------------------------------------------------------
-- Type Definitions
-------------------------------------------------------------------------------

---@class LibAnimate
---@field animations table<string, AnimationDefinition> Registered animation definitions
---@field activeAnimations table<Frame, AnimationState> Currently running animations
---@field easings table<string, fun(t: number): number> Named easing presets
---@field CubicBezier fun(p1x: number, p1y: number, p2x: number, p2y: number): fun(t: number): number
---@field ApplyEasing fun(easing: EasingSpec, t: number): number

---@class AnimationDefinition
---@field type "entrance"|"exit"|"attention" Animation category
---@field defaultDuration number? Default duration in seconds
---@field defaultDistance number? Default translation distance in pixels
---@field keyframes Keyframe[] Ordered list of keyframes (progress 0.0 to 1.0)

---@class Keyframe
---@field progress number Normalized time position (0.0 to 1.0)
---@field translateX number? Horizontal offset as fraction of distance (default 0)
---@field translateY number? Vertical offset as fraction of distance (default 0)
---@field scale number? Uniform scale factor (default 1.0)
---@field alpha number? Opacity (default 1.0)
---@field easing EasingSpec? Easing for the segment STARTING at this keyframe

--- A named preset (e.g. "easeOutCubic") or cubic-bezier control points {p1x, p1y, p2x, p2y}.
---@alias EasingSpec string|number[]

---@class AnimateOpts
---@field duration number? Override animation duration in seconds
---@field distance number? Override translation distance in pixels
---@field delay number? Delay in seconds before animation starts (default 0)
---@field repeatCount number? Number of times to play (0 = infinite, nil/1 = once)
---@field onFinished fun(frame: Frame)? Callback fired when the animation completes naturally

--- Configuration for a single step in an animation queue.
---@class QueueEntry
---@field name string Animation name
---@field duration number? Duration override in seconds
---@field distance number? Distance override in pixels
---@field delay number? Delay before this step starts in seconds
---@field repeatCount number? Repeat count for this step (0 = infinite)
---@field onFinished fun(frame: Frame)? Callback when this step completes

--- Options for the animation queue.
---@class QueueOpts
---@field onFinished fun(frame: Frame)? Called when the entire sequence completes

---@class AnimationState
---@field definition AnimationDefinition
---@field keyframes Keyframe[]
---@field startTime number GetTime() at animation start
---@field duration number Active duration in seconds
---@field distance number Translation distance in pixels
---@field delay number Delay in seconds before animation starts
---@field repeatCount number Number of total repeats (0 = infinite, 1 = once)
---@field currentRepeat number Current repeat iteration (starts at 1)
---@field onFinished fun(frame: Frame)?
---@field anchorPoint string Captured anchor point
---@field anchorRelativeTo Frame? Captured relative-to frame
---@field anchorRelativePoint string Captured relative point
---@field anchorX number Captured anchor X offset
---@field anchorY number Captured anchor Y offset
---@field originalScale number Pre-animation scale
---@field originalAlpha number Pre-animation alpha
---@field resolvedEasings table<integer, fun(t: number): number>

-------------------------------------------------------------------------------
-- Cached Globals
-------------------------------------------------------------------------------

local GetTime = GetTime
local CreateFrame = CreateFrame
local geterrorhandler = geterrorhandler
local pairs = pairs
local next = next
local ipairs = ipairs
local type = type
local math_min = math.min
local math_abs = math.abs
local math_floor = math.floor
local table_sort = table.sort

-------------------------------------------------------------------------------
-- State Initialization
-------------------------------------------------------------------------------

lib.animations = lib.animations or {}
lib.activeAnimations = lib.activeAnimations or {}
lib.animationQueues = lib.animationQueues or {}

if not lib.driverFrame then
    lib.driverFrame = CreateFrame("Frame")
    lib.driverFrame:Hide()
end
local driverFrame = lib.driverFrame

-------------------------------------------------------------------------------
-- Easing Functions
-------------------------------------------------------------------------------

--- Named easing presets mapping string names to easing functions.
--- Each function takes a normalized time `t` in [0, 1] and returns the eased value.
---
--- Available presets:
--- - `"linear"` — No easing
--- - `"easeInQuad"`, `"easeOutQuad"`, `"easeInOutQuad"` — Quadratic
--- - `"easeInCubic"`, `"easeOutCubic"`, `"easeInOutCubic"` — Cubic
--- - `"easeInBack"`, `"easeOutBack"`, `"easeInOutBack"` — Back (overshoot)
---@type table<string, fun(t: number): number>
lib.easings = {
    linear = function(t)
        return t
    end,

    easeInQuad = function(t)
        return t * t
    end,

    easeOutQuad = function(t)
        return 1 - (1 - t) * (1 - t)
    end,

    easeInOutQuad = function(t)
        if t < 0.5 then
            return 2 * t * t
        end
        return 1 - (-2 * t + 2) * (-2 * t + 2) / 2
    end,

    easeInCubic = function(t)
        return t * t * t
    end,

    easeOutCubic = function(t)
        local inv = 1 - t
        return 1 - inv * inv * inv
    end,

    easeInOutCubic = function(t)
        if t < 0.5 then
            return 4 * t * t * t
        end
        local inv = -2 * t + 2
        return 1 - inv * inv * inv / 2
    end,

    easeInBack = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        return c3 * t * t * t - c1 * t * t
    end,

    easeOutBack = function(t)
        local c1 = 1.70158
        local c3 = c1 + 1
        local inv = t - 1
        return 1 + c3 * inv * inv * inv + c1 * inv * inv
    end,

    easeInOutBack = function(t)
        local c1 = 1.70158
        local c2 = c1 * 1.525
        if t < 0.5 then
            return ((2 * t) * (2 * t) * ((c2 + 1) * (2 * t) - c2)) / 2
        end
        local inv = 2 * t - 2
        return (inv * inv * ((c2 + 1) * inv + c2) + 2) / 2
    end,
}

-------------------------------------------------------------------------------
-- Cubic-Bezier Solver
-------------------------------------------------------------------------------

--- Creates a cubic-bezier easing function from four control points.
--- Uses Newton-Raphson iteration with binary-search fallback.
---@param p1x number X of first control point (0-1)
---@param p1y number Y of first control point
---@param p2x number X of second control point (0-1)
---@param p2y number Y of second control point
---@return fun(t: number): number easingFn Easing function mapping [0,1] to [0,1]
local function CubicBezier(p1x, p1y, p2x, p2y)
    --- Evaluates the X component of the cubic bezier at parameter t.
    ---@param t number Bezier parameter (0-1)
    ---@return number x X coordinate on the bezier curve
    local function sampleCurveX(t)
        return (((1 - 3 * p2x + 3 * p1x) * t + (3 * p2x - 6 * p1x)) * t + 3 * p1x) * t
    end

    --- Evaluates the Y component (output value) of the cubic bezier at parameter t.
    ---@param t number Bezier parameter (0-1)
    ---@return number y Y coordinate on the bezier curve
    local function sampleCurveY(t)
        return (((1 - 3 * p2y + 3 * p1y) * t + (3 * p2y - 6 * p1y)) * t + 3 * p1y) * t
    end

    --- Evaluates the derivative of the X component at parameter t (for Newton-Raphson).
    ---@param t number Bezier parameter (0-1)
    ---@return number dx Derivative of X with respect to t
    local function sampleCurveDerivativeX(t)
        return (3 * (1 - 3 * p2x + 3 * p1x) * t + 2 * (3 * p2x - 6 * p1x)) * t + 3 * p1x
    end

    --- Finds the bezier parameter t that produces a given X value.
    --- Uses Newton-Raphson iteration (8 steps) with binary-search fallback (20 steps).
    ---@param x number Target X value (0-1)
    ---@return number t Bezier parameter that maps to x
    local function solveCurveX(x)
        -- Newton-Raphson
        local t = x
        for _ = 1, 8 do
            local currentX = sampleCurveX(t) - x
            if math_abs(currentX) < 1e-6 then
                return t
            end
            local dx = sampleCurveDerivativeX(t)
            if math_abs(dx) < 1e-6 then
                break
            end
            t = t - currentX / dx
        end

        -- Binary search fallback
        local lo, hi = 0.0, 1.0
        t = x
        for _ = 1, 20 do
            local currentX = sampleCurveX(t)
            if math_abs(currentX - x) < 1e-6 then
                return t
            end
            if currentX > x then
                hi = t
            else
                lo = t
            end
            t = (lo + hi) * 0.5
        end
        return t
    end

    --- Returned easing function: maps a normalized progress value through the bezier curve.
    ---@param x number Normalized progress (0-1), clamped at boundaries
    ---@return number y Eased progress value
    return function(x)
        if x <= 0 then return 0 end
        if x >= 1 then return 1 end
        return sampleCurveY(solveCurveX(x))
    end
end

lib.CubicBezier = CubicBezier

-------------------------------------------------------------------------------
-- ApplyEasing Helper
-------------------------------------------------------------------------------

--- Applies an easing function to a progress value.
--- Accepts a named preset string or a cubic-bezier control point table.
--- This is a utility function; the hot-path uses pre-resolved easing functions instead.
---@param easing EasingSpec Easing preset name or {p1x, p1y, p2x, p2y}
---@param t number Normalized progress (0-1)
---@return number easedT Eased progress value
local function ApplyEasing(easing, t)
    if type(easing) == "string" then
        local fn = lib.easings[easing]
        if fn then return fn(t) end
        return t
    elseif type(easing) == "table" then
        local fn = CubicBezier(easing[1], easing[2], easing[3], easing[4])
        return fn(t)
    end
    return t
end

lib.ApplyEasing = ApplyEasing

-------------------------------------------------------------------------------
-- Keyframe Interpolation
-------------------------------------------------------------------------------

--- Default values for keyframe properties when not explicitly set.
--- Used by `GetProperty` to fill in missing values during interpolation.
---@type table<string, number>
local PROPERTY_DEFAULTS = {
    translateX = 0,
    translateY = 0,
    scale = 1.0,
    alpha = 1.0,
}

--- Finds the two bracketing keyframes for a given progress value.
--- Returns the start and end keyframes of the active segment, the interpolation
--- progress within that segment, and the index of the start keyframe.
---@param keyframes Keyframe[] Ordered keyframe list (progress 0.0 to 1.0)
---@param progress number Normalized animation progress (0-1)
---@return Keyframe kf1 Start keyframe of the active segment
---@return Keyframe kf2 End keyframe of the active segment
---@return number segmentProgress Interpolation progress within the segment (0-1)
---@return integer kf1Index Index of kf1 in the keyframes array
local function FindKeyframes(keyframes, progress)
    -- Handle boundary cases explicitly
    if progress <= 0 then
        local segmentLength = keyframes[2].progress - keyframes[1].progress
        local segmentProgress = 0
        if segmentLength > 0 then
            segmentProgress = (progress - keyframes[1].progress) / segmentLength
        end
        return keyframes[1], keyframes[2], segmentProgress, 1
    end

    local n = #keyframes
    if progress >= 1.0 then
        return keyframes[n - 1], keyframes[n], 1, n - 1
    end

    -- Search for bracketing keyframes
    for i = 1, n - 1 do
        if progress >= keyframes[i].progress and progress <= keyframes[i + 1].progress then
            local segmentLength = keyframes[i + 1].progress - keyframes[i].progress
            local segmentProgress = 0
            if segmentLength > 0 then
                segmentProgress = (progress - keyframes[i].progress) / segmentLength
            end
            return keyframes[i], keyframes[i + 1], segmentProgress, i
        end
    end

    -- Fallback: should never reach here with valid keyframes (0.0 to 1.0 boundary)
    return keyframes[n - 1], keyframes[n], 1, n - 1
end

--- Returns a keyframe property value, falling back to PROPERTY_DEFAULTS if not set.
---@param kf Keyframe The keyframe to read from
---@param name string Property name ("translateX", "translateY", "scale", or "alpha")
---@return number value The property value
local function GetProperty(kf, name)
    if kf[name] ~= nil then
        return kf[name]
    end
    return PROPERTY_DEFAULTS[name]
end

--- Linearly interpolates between two values.
---@param a number Start value
---@param b number End value
---@param t number Interpolation factor (0 = a, 1 = b)
---@return number result Interpolated value
local function Lerp(a, b, t)
    return a + (b - a) * t
end

-------------------------------------------------------------------------------
-- ApplyToFrame
-------------------------------------------------------------------------------

--- Applies interpolated animation properties to a frame.
--- Computes the final anchor offset from translation fractions and distance,
--- repositions the frame, and sets scale and alpha. Scale is clamped to a
--- minimum of 0.001 to prevent WoW `SetScale(0)` errors.
---@param frame Frame The frame being animated
---@param state AnimationState The active animation state
---@param tx number Interpolated translateX (fraction of distance)
---@param ty number Interpolated translateY (fraction of distance)
---@param sc number Interpolated scale factor
---@param al number Interpolated alpha (opacity)
local function ApplyToFrame(frame, state, tx, ty, sc, al)
    local distance = state.distance or 0

    local offsetX = tx * distance
    local offsetY = ty * distance

    frame:ClearAllPoints()
    frame:SetPoint(state.anchorPoint, state.anchorRelativeTo, state.anchorRelativePoint,
        state.anchorX + offsetX, state.anchorY + offsetY)

    -- Clamp scale to minimum to prevent SetScale(0) errors (P4)
    if sc < 0.001 then sc = 0.001 end
    frame:SetScale(sc)
    frame:SetAlpha(al)
end

-------------------------------------------------------------------------------
-- Driver Frame OnUpdate
-------------------------------------------------------------------------------

--- Main animation driver. Runs every frame while any animation is active.
--- For each active animation: advances progress, finds bracketing keyframes,
--- applies per-segment easing, interpolates properties, and applies to the frame.
--- Completed animations are snapped to final state and their callbacks are fired
--- in a deferred pass (after all state cleanup) to prevent re-entrancy issues.
driverFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    local toRemove = nil

    for frame, state in pairs(lib.activeAnimations) do
        local elapsed = now - state.startTime

        -- Handle delay: skip interpolation while in delay period
        if elapsed < state.delay then -- luacheck: ignore 542
            -- Do nothing, frame stays in its pre-animation state
        else
            local rawProgress = math_min(
                (elapsed - state.delay) / state.duration, 1.0
            )

            -- Find bracketing keyframes
            local kf1, kf2, segmentProgress, kf1Index =
                FindKeyframes(state.keyframes, rawProgress)

            -- Apply per-segment easing (pre-resolved at animation start)
            if state.resolvedEasings[kf1Index] then
                segmentProgress =
                    state.resolvedEasings[kf1Index](segmentProgress)
            end

            -- Interpolate properties (unrolled for performance)
            local easedT = segmentProgress
            local tx = Lerp(
                GetProperty(kf1, "translateX"),
                GetProperty(kf2, "translateX"), easedT
            )
            local ty = Lerp(
                GetProperty(kf1, "translateY"),
                GetProperty(kf2, "translateY"), easedT
            )
            local sc = Lerp(
                GetProperty(kf1, "scale"),
                GetProperty(kf2, "scale"), easedT
            )
            local al = Lerp(
                GetProperty(kf1, "alpha"),
                GetProperty(kf2, "alpha"), easedT
            )

            -- Apply to frame
            ApplyToFrame(frame, state, tx, ty, sc, al)

            -- Check completion with repeat support
            if rawProgress >= 1.0 then
                if state.repeatCount == 0
                    or state.currentRepeat < state.repeatCount
                then
                    -- Reset for next repeat (no delay between repeats)
                    state.startTime = now
                    state.delay = 0
                    state.currentRepeat = state.currentRepeat + 1
                else
                    if not toRemove then toRemove = {} end
                    toRemove[#toRemove + 1] = frame
                end
            end
        end
    end

    -- Process completions
    if toRemove then
        -- First pass: clean up state and snap to final values
        local callbacks = nil
        for _, frame in ipairs(toRemove) do
            local state = lib.activeAnimations[frame]
            if state then
                local onFinished = state.onFinished
                if onFinished then
                    if not callbacks then callbacks = {} end
                    callbacks[#callbacks + 1] = { fn = onFinished, frame = frame }
                end

                -- Snap to final state
                local lastKf = state.keyframes[#state.keyframes]
                local ftx = GetProperty(lastKf, "translateX")
                local fty = GetProperty(lastKf, "translateY")
                local fsc = GetProperty(lastKf, "scale")
                local fal = GetProperty(lastKf, "alpha")
                ApplyToFrame(frame, state, ftx, fty, fsc, fal)

                lib.activeAnimations[frame] = nil
            end
        end

        -- Second pass: fire callbacks (after all state is clean)
        if callbacks then
            for _, cb in ipairs(callbacks) do
                cb.fn(cb.frame)
            end
        end
    end

    -- Hide driver if no active animations
    if not next(lib.activeAnimations) then
        driverFrame:Hide()
    end
end)

-------------------------------------------------------------------------------
-- Public API
-------------------------------------------------------------------------------

--- Plays a registered animation on a frame.
---
--- The frame must have exactly one anchor point set via `SetPoint()`.
--- Frames with multiple anchor points (two-point sizing) are not supported
--- and will lose their secondary anchors during animation.
---
--- If the frame is already animating, the current animation is stopped
--- (restoring the frame to its pre-animation state) before the new one starts.
---
--- Supports `delay` to wait before starting and `repeatCount` to repeat
--- (0 = infinite). If the frame has an active queue, the queue is cleared.
---
--- For exit animations, the frame is left at its final keyframe state when
--- the animation completes. The consumer must handle cleanup (e.g. `frame:Hide()`)
--- in the `onFinished` callback.
---
--- For attention-seeker animations, the frame returns to its original state
--- when the animation completes (keyframes start and end at identity values).
---
--- Usage:
--- ```lua
--- local LibAnimate = LibStub("LibAnimate")
--- LibAnimate:Animate(myFrame, "fadeIn", {
---     duration = 0.5,
---     delay = 0.2,
---     repeatCount = 3,
---     onFinished = function(frame) print("done!") end,
--- })
--- ```
---@param frame Frame The frame to animate (must have one anchor point)
---@param name string Registered animation name
---@param opts AnimateOpts? Animation options
---@return boolean success Always returns true on success; errors on invalid input
function lib:Animate(frame, name, opts)
    if opts ~= nil and type(opts) ~= "table" then
        error("LibAnimate: opts must be a table or nil", 2)
    end
    opts = opts or {}

    -- Stop existing animation on this frame
    if lib.activeAnimations[frame] then
        self:Stop(frame)
    end

    -- Clear any active queue on this frame
    lib.animationQueues[frame] = nil

    local def = lib.animations[name]
    if not def then
        error("LibAnimate: Unknown animation '" .. tostring(name) .. "'", 2)
    end

    local duration = opts.duration or def.defaultDuration
    if not duration or duration <= 0 then
        error("LibAnimate: Animation duration must be greater than 0", 2)
    end

    -- Capture current anchor
    local pt, rel, relPt, x, y = frame:GetPoint()
    if not pt then
        error("LibAnimate: Frame has no anchor point set", 2)
    end

    local originalScale = frame:GetScale()
    local originalAlpha = frame:GetAlpha()

    -- Pre-resolve easing functions to avoid per-tick allocation.
    -- Convention: kf.easing applies to the segment STARTING at that keyframe
    -- (i.e., the easing from kf[i] to kf[i+1] is defined on kf[i]).
    local resolvedEasings = {}
    for i, kf in ipairs(def.keyframes) do
        if kf.easing then
            if type(kf.easing) == "string" then
                resolvedEasings[i] = lib.easings[kf.easing] or lib.easings.linear
            elseif type(kf.easing) == "table" then
                resolvedEasings[i] = CubicBezier(kf.easing[1], kf.easing[2], kf.easing[3], kf.easing[4])
            end
        end
    end

    local delay = opts.delay or 0
    if type(delay) ~= "number" or delay < 0 then
        error("LibAnimate: delay must be a non-negative number", 2)
    end

    local repeatCount = opts.repeatCount or 1
    if type(repeatCount) ~= "number" or repeatCount < 0 or repeatCount ~= math_floor(repeatCount) then
        error("LibAnimate: repeatCount must be 0 (infinite) or a positive integer", 2)
    end

    local state = {
        definition = def,
        keyframes = def.keyframes,
        startTime = GetTime(),
        duration = duration,
        distance = opts.distance or def.defaultDistance or 0,
        delay = delay,
        repeatCount = repeatCount,
        currentRepeat = 1,
        onFinished = opts.onFinished,
        anchorPoint = pt,
        anchorRelativeTo = rel,
        anchorRelativePoint = relPt,
        anchorX = x or 0,
        anchorY = y or 0,
        originalScale = originalScale,
        originalAlpha = originalAlpha,
        resolvedEasings = resolvedEasings,
    }

    lib.activeAnimations[frame] = state
    driverFrame:Show()

    return true
end

--- Stops the animation on a frame and restores it to its pre-animation state.
--- Restores the original anchor position, scale, and alpha captured at animation start.
--- If the frame has an active animation queue, the queue is also cleared.
--- Does nothing if the frame is not currently animating and has no queue.
--- The `onFinished` callback is NOT fired when an animation is stopped.
---@param frame Frame The frame to stop animating
function lib:Stop(frame)
    -- Clear any active queue on this frame
    lib.animationQueues[frame] = nil

    local state = lib.activeAnimations[frame]
    if not state then return end

    -- Restore to base anchor with clean state
    frame:ClearAllPoints()
    frame:SetPoint(state.anchorPoint, state.anchorRelativeTo, state.anchorRelativePoint,
        state.anchorX, state.anchorY)
    frame:SetScale(state.originalScale)
    frame:SetAlpha(state.originalAlpha)

    lib.activeAnimations[frame] = nil

    if not next(lib.activeAnimations) then
        driverFrame:Hide()
    end
end

--- Updates the base anchor offsets of an in-progress animation.
--- Use this when the frame's logical position changes during animation
--- (e.g. repositioning a notification while it slides in).
--- Does nothing if the frame is not currently animating.
---@param frame Frame The animated frame
---@param x number New base anchor X offset
---@param y number New base anchor Y offset
function lib:UpdateAnchor(frame, x, y)
    local state = lib.activeAnimations[frame]
    if state then
        state.anchorX = x
        state.anchorY = y
    end
end

--- Returns whether a frame currently has an active animation.
---@param frame Frame The frame to check
---@return boolean isAnimating True if the frame is currently animating
function lib:IsAnimating(frame)
    return lib.activeAnimations[frame] ~= nil
end

-------------------------------------------------------------------------------
-- Animation Queue
-------------------------------------------------------------------------------

--- Internal helper to start the next entry in an animation queue.
--- Retrieves the current queue entry, builds options, and calls Animate
--- with an internal onFinished that advances the queue.
---@param self LibAnimate
---@param frame Frame The frame being animated
local function StartQueueEntry(self, frame)
    local queue = self.animationQueues[frame]
    if not queue then return end

    local entry = queue.entries[queue.index]
    if not entry then
        -- Queue exhausted
        local onFinished = queue.onFinished
        self.animationQueues[frame] = nil
        if onFinished then onFinished(frame) end
        return
    end

    local opts = {
        duration = entry.duration,
        distance = entry.distance,
        delay = entry.delay,
        repeatCount = entry.repeatCount,
        onFinished = function(f)
            -- Fire per-step callback (pcall so queue always advances)
            if entry.onFinished then
                local ok, err = pcall(entry.onFinished, f)
                if not ok then
                    geterrorhandler()(err)
                end
            end
            -- Advance queue
            if self.animationQueues[f] then
                self.animationQueues[f].index =
                    self.animationQueues[f].index + 1
                StartQueueEntry(self, f)
            end
        end,
    }

    -- Save/restore queue around Animate() since it clears queues
    local savedQueue = self.animationQueues[frame]
    self:Animate(frame, entry.name, opts)
    self.animationQueues[frame] = savedQueue
end

--- Queues a sequence of animations to play one after another on a frame.
--- Each entry can have its own duration, distance, delay, repeatCount,
--- and onFinished callback.
--- The sequence-level onFinished fires after the entire queue completes.
---@param frame Frame The frame to animate
---@param entries QueueEntry[] Array of animation steps
---@param opts QueueOpts? Sequence-level options
function lib:Queue(frame, entries, opts)
    if not frame then
        error("LibAnimate:Queue — frame must not be nil", 2)
    end
    if type(entries) ~= "table" or #entries == 0 then
        error("LibAnimate:Queue — entries must be a non-empty table", 2)
    end

    if opts ~= nil and type(opts) ~= "table" then
        error("LibAnimate:Queue — opts must be a table or nil", 2)
    end
    opts = opts or {}

    -- Validate all animation names upfront
    for i, entry in ipairs(entries) do
        if type(entry.name) ~= "string"
            or not lib.animations[entry.name]
        then
            error(
                "LibAnimate:Queue — invalid animation name '"
                    .. tostring(entry.name)
                    .. "' at entry " .. i,
                2
            )
        end
    end

    -- Stop any current animation and clear existing queue
    self:Stop(frame)

    -- Initialize the queue
    lib.animationQueues[frame] = {
        entries = entries,
        index = 1,
        onFinished = opts.onFinished,
    }

    StartQueueEntry(self, frame)
end

--- Cancels the animation queue on a frame and stops the current animation.
--- The frame is restored to its pre-animation state. No callbacks are fired.
---@param frame Frame The frame to cancel the queue on
function lib:ClearQueue(frame)
    lib.animationQueues[frame] = nil
    self:Stop(frame)
end

--- Returns whether a frame has an active animation queue.
---@param frame Frame The frame to check
---@return boolean isQueued True if the frame has a pending queue
function lib:IsQueued(frame)
    return lib.animationQueues[frame] ~= nil
end

--- Returns the definition table for a registered animation.
---@param name string The animation name
---@return AnimationDefinition? definition The animation definition, or nil if not registered
function lib:GetAnimationInfo(name)
    return lib.animations[name]
end

--- Returns a sorted list of all registered animation names.
---@return string[] names Alphabetically sorted animation names
function lib:GetAnimationNames()
    local names = {}
    for animName in pairs(lib.animations) do
        names[#names + 1] = animName
    end
    table_sort(names)
    return names
end

--- Returns a sorted list of all registered entrance animation names.
---@return string[] names Alphabetically sorted entrance animation names
function lib:GetEntranceAnimations()
    local names = {}
    for animName, def in pairs(lib.animations) do
        if def.type == "entrance" then
            names[#names + 1] = animName
        end
    end
    table_sort(names)
    return names
end

--- Returns a sorted list of all registered exit animation names.
---@return string[] names Alphabetically sorted exit animation names
function lib:GetExitAnimations()
    local names = {}
    for animName, def in pairs(lib.animations) do
        if def.type == "exit" then
            names[#names + 1] = animName
        end
    end
    table_sort(names)
    return names
end

--- Returns a sorted list of all registered attention-seeker animation names.
---@return string[] names Alphabetically sorted attention animation names
function lib:GetAttentionAnimations()
    local names = {}
    for name, def in pairs(lib.animations) do
        if def.type == "attention" then
            names[#names + 1] = name
        end
    end
    table_sort(names)
    return names
end

--- Registers a custom animation definition.
---
--- Keyframe requirements:
--- - At least 2 keyframes
--- - Sorted ascending by `progress`
--- - First keyframe must have `progress = 0.0`
--- - Last keyframe must have `progress = 1.0`
---
--- Easing on a keyframe applies to the segment STARTING at that keyframe
--- (i.e., the transition from `kf[i]` to `kf[i+1]` uses `kf[i].easing`).
---
--- Usage:
--- ```lua
--- LibAnimate:RegisterAnimation("customSlide", {
---     type = "entrance",
---     defaultDuration = 0.4,
---     defaultDistance = 200,
---     keyframes = {
---         { progress = 0.0, translateX = -1.0, alpha = 0 },
---         { progress = 1.0, translateX = 0, alpha = 1.0 },
---     },
--- })
--- ```
---@param name string Unique animation name
---@param definition AnimationDefinition Animation definition table
function lib:RegisterAnimation(name, definition)
    if type(name) ~= "string" then
        error("LibAnimate: Animation name must be a string", 2)
    end
    if type(definition) ~= "table" then
        error("LibAnimate: Animation definition must be a table", 2)
    end
    if not definition.type then
        error("LibAnimate: Animation definition must have a 'type' field ('entrance', 'exit', or 'attention')", 2)
    end
    if not definition.keyframes or #definition.keyframes < 2 then
        error("LibAnimate: Animation must have at least 2 keyframes", 2)
    end

    -- Validate keyframe ordering
    local keyframes = definition.keyframes
    for i = 2, #keyframes do
        if keyframes[i].progress < keyframes[i - 1].progress then
            error("LibAnimate: Keyframes must be sorted by progress (ascending)", 2)
        end
    end

    -- Validate boundaries
    if keyframes[1].progress ~= 0.0 then
        error("LibAnimate: First keyframe must have progress = 0.0", 2)
    end
    if keyframes[#keyframes].progress ~= 1.0 then
        error("LibAnimate: Last keyframe must have progress = 1.0", 2)
    end

    -- Validate defaultDuration if provided
    if definition.defaultDuration and definition.defaultDuration <= 0 then
        error("LibAnimate: defaultDuration must be greater than 0", 2)
    end

    lib.animations[name] = definition
end
