-------------------------------------------------------------------------------
-- LibAnimate-1.0
-- Keyframe-driven animation library for World of Warcraft frames
-- Inspired by animate.css (https://animate.style)
--
-- Supported versions: Retail, TBC Anniversary, MoP Classic
-------------------------------------------------------------------------------

local MAJOR, MINOR = "LibAnimate-1.0", 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-------------------------------------------------------------------------------
-- Cached Globals
-------------------------------------------------------------------------------

local GetTime = GetTime
local CreateFrame = CreateFrame
local pairs = pairs
local next = next
local ipairs = ipairs
local type = type
local math_min = math.min
local math_abs = math.abs
local table_sort = table.sort

-------------------------------------------------------------------------------
-- State Initialization
-------------------------------------------------------------------------------

lib.animations = lib.animations or {}
lib.activeAnimations = lib.activeAnimations or {}

if not lib.driverFrame then
    lib.driverFrame = CreateFrame("Frame")
    lib.driverFrame:Hide()
end
local driverFrame = lib.driverFrame

-------------------------------------------------------------------------------
-- Easing Functions
-------------------------------------------------------------------------------

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
            return (2 * t * 2 * t * ((c2 + 1) * 2 * t - c2)) / 2
        end
        local inv = 2 * t - 2
        return (inv * inv * ((c2 + 1) * inv + c2) + 2) / 2
    end,
}

-------------------------------------------------------------------------------
-- Cubic-Bezier Solver
-------------------------------------------------------------------------------

local function CubicBezier(p1x, p1y, p2x, p2y)
    local function sampleCurveX(t)
        return (((1 - 3 * p2x + 3 * p1x) * t + (3 * p2x - 6 * p1x)) * t + 3 * p1x) * t
    end

    local function sampleCurveY(t)
        return (((1 - 3 * p2y + 3 * p1y) * t + (3 * p2y - 6 * p1y)) * t + 3 * p1y) * t
    end

    local function sampleCurveDerivativeX(t)
        return (3 * (1 - 3 * p2x + 3 * p1x) * t + 2 * (3 * p2x - 6 * p1x)) * t + 3 * p1x
    end

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

-- NOTE: This function is kept as a utility for future API use.
-- The hot-path (OnUpdate) uses pre-resolved easing functions instead.
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

local PROPERTY_DEFAULTS = {
    translateX = 0,
    translateY = 0,
    scale = 1.0,
    alpha = 1.0,
}

local function FindKeyframes(keyframes, progress)
    local kf1 = keyframes[1]
    local kf2 = keyframes[#keyframes]
    local kf1Index = 1

    for i = 1, #keyframes - 1 do
        if progress >= keyframes[i].progress and progress <= keyframes[i + 1].progress then
            kf1 = keyframes[i]
            kf2 = keyframes[i + 1]
            kf1Index = i
            break
        end
    end

    local segmentLength = kf2.progress - kf1.progress
    local segmentProgress = 0
    if segmentLength > 0 then
        segmentProgress = (progress - kf1.progress) / segmentLength
    end

    return kf1, kf2, segmentProgress, kf1Index
end

local function GetProperty(kf, name)
    if kf[name] ~= nil then
        return kf[name]
    end
    return PROPERTY_DEFAULTS[name]
end

local function Lerp(a, b, t)
    return a + (b - a) * t
end

-------------------------------------------------------------------------------
-- ApplyToFrame
-------------------------------------------------------------------------------

local function ApplyToFrame(frame, state, tx, ty, sc, al)
    local distance = state.distance

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

driverFrame:SetScript("OnUpdate", function()
    local now = GetTime()
    local toRemove = nil

    for frame, state in pairs(lib.activeAnimations) do
        local rawProgress = math_min((now - state.startTime) / state.duration, 1.0)

        -- Find bracketing keyframes
        local kf1, kf2, segmentProgress, kf1Index = FindKeyframes(state.keyframes, rawProgress)

        -- Apply per-segment easing (pre-resolved at animation start)
        if state.resolvedEasings[kf1Index] then
            segmentProgress = state.resolvedEasings[kf1Index](segmentProgress)
        end

        -- Interpolate properties (unrolled for performance)
        local easedT = segmentProgress
        local tx = Lerp(GetProperty(kf1, "translateX"), GetProperty(kf2, "translateX"), easedT)
        local ty = Lerp(GetProperty(kf1, "translateY"), GetProperty(kf2, "translateY"), easedT)
        local sc = Lerp(GetProperty(kf1, "scale"), GetProperty(kf2, "scale"), easedT)
        local al = Lerp(GetProperty(kf1, "alpha"), GetProperty(kf2, "alpha"), easedT)

        -- Apply to frame
        ApplyToFrame(frame, state, tx, ty, sc, al)

        -- Check completion
        if rawProgress >= 1.0 then
            if not toRemove then toRemove = {} end
            toRemove[#toRemove + 1] = frame
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

--- Plays a named animation on a frame.
-- The frame must have exactly one anchor point set via SetPoint().
-- Frames with multiple anchor points (two-point sizing) are not supported
-- and will lose their secondary anchors during animation.
-- For exit animations, the frame is left at its final keyframe state when
-- the animation completes. The consumer must handle cleanup (e.g., frame:Hide())
-- in the onFinished callback.
function lib:Animate(frame, name, opts)
    opts = opts or {}

    -- Stop existing animation on this frame
    if lib.activeAnimations[frame] then
        self:Stop(frame)
    end

    local def = lib.animations[name]
    if not def then
        error("LibAnimate-1.0: Unknown animation '" .. tostring(name) .. "'", 2)
    end

    local duration = opts.duration or def.defaultDuration
    if not duration or duration <= 0 then
        error("LibAnimate-1.0: Animation duration must be greater than 0", 2)
    end

    -- Capture current anchor
    local pt, rel, relPt, x, y = frame:GetPoint()
    if not pt then
        error("LibAnimate-1.0: Frame has no anchor point set", 2)
    end

    local originalScale = frame:GetScale()
    local originalAlpha = frame:GetAlpha()

    -- Pre-resolve easing functions to avoid per-tick allocation
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

    local state = {
        definition = def,
        keyframes = def.keyframes,
        startTime = GetTime(),
        duration = duration,
        distance = opts.distance or def.defaultDistance,
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

function lib:Stop(frame)
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

function lib:UpdateAnchor(frame, x, y)
    local state = lib.activeAnimations[frame]
    if state then
        state.anchorX = x
        state.anchorY = y
    end
end

function lib:IsAnimating(frame)
    return lib.activeAnimations[frame] ~= nil
end

function lib:GetAnimationInfo(name)
    return lib.animations[name]
end

function lib:GetAnimationNames()
    local names = {}
    for animName in pairs(lib.animations) do
        names[#names + 1] = animName
    end
    table_sort(names)
    return names
end

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

function lib:RegisterAnimation(name, definition)
    if type(name) ~= "string" then
        error("LibAnimate-1.0: Animation name must be a string", 2)
    end
    if type(definition) ~= "table" then
        error("LibAnimate-1.0: Animation definition must be a table", 2)
    end
    if not definition.type then
        error("LibAnimate-1.0: Animation definition must have a 'type' field ('entrance' or 'exit')", 2)
    end
    if not definition.keyframes or #definition.keyframes < 2 then
        error("LibAnimate-1.0: Animation must have at least 2 keyframes", 2)
    end

    -- Validate keyframe ordering
    local keyframes = definition.keyframes
    for i = 2, #keyframes do
        if keyframes[i].progress < keyframes[i - 1].progress then
            error("LibAnimate-1.0: Keyframes must be sorted by progress (ascending)", 2)
        end
    end

    -- Validate boundaries
    if keyframes[1].progress ~= 0.0 then
        error("LibAnimate-1.0: First keyframe must have progress = 0.0", 2)
    end
    if keyframes[#keyframes].progress ~= 1.0 then
        error("LibAnimate-1.0: Last keyframe must have progress = 1.0", 2)
    end

    -- Validate defaultDuration if provided
    if definition.defaultDuration and definition.defaultDuration <= 0 then
        error("LibAnimate-1.0: defaultDuration must be greater than 0", 2)
    end

    lib.animations[name] = definition
end
