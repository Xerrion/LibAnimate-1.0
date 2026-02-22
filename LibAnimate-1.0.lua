-------------------------------------------------------------------------------
-- LibAnimate-1.0
-- Keyframe-driven animation library for World of Warcraft frames
-- Inspired by animate.css (https://animate.style)
--
-- Supported versions: Retail, TBC Anniversary, MoP Classic
-------------------------------------------------------------------------------

local MAJOR, MINOR = "LibAnimate-1.0", 1
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

-- NOTE: For cubic-bezier table params, we create a new function each call.
-- This could be optimized by caching per unique param set, but is acceptable
-- for V1 since animations are short-lived.
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

-------------------------------------------------------------------------------
-- Keyframe Interpolation
-------------------------------------------------------------------------------

local PROPERTY_DEFAULTS = {
    translateX = 0,
    translateY = 0,
    scale = 1.0,
    alpha = 1.0,
}
local PROPERTY_NAMES = { "translateX", "translateY", "scale", "alpha" }

local function FindKeyframes(keyframes, progress)
    local kf1 = keyframes[1]
    local kf2 = keyframes[#keyframes]

    for i = 1, #keyframes - 1 do
        if progress >= keyframes[i].time and progress <= keyframes[i + 1].time then
            kf1 = keyframes[i]
            kf2 = keyframes[i + 1]
            break
        end
    end

    local segmentLength = kf2.time - kf1.time
    local segmentProgress = 0
    if segmentLength > 0 then
        segmentProgress = (progress - kf1.time) / segmentLength
    end

    return kf1, kf2, segmentProgress
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

local function InterpolateProperties(kf1, kf2, t)
    local result = {}
    for _, name in ipairs(PROPERTY_NAMES) do
        local v1 = GetProperty(kf1, name)
        local v2 = GetProperty(kf2, name)
        result[name] = Lerp(v1, v2, t)
    end
    return result
end

-------------------------------------------------------------------------------
-- ApplyToFrame
-------------------------------------------------------------------------------

local function ApplyToFrame(frame, state, props)
    local distance = state.distance

    local tx = props.translateX * distance
    local ty = props.translateY * distance

    frame:ClearAllPoints()
    frame:SetPoint(state.anchorPoint, state.anchorRelativeTo, state.anchorRelativePoint,
        state.anchorX + tx, state.anchorY + ty)
    frame:SetScale(props.scale)
    frame:SetAlpha(props.alpha)
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
        local kf1, kf2, segmentProgress = FindKeyframes(state.keyframes, rawProgress)

        -- Apply per-segment easing
        if kf1.easing then
            segmentProgress = ApplyEasing(kf1.easing, segmentProgress)
        end

        -- Interpolate properties
        local props = InterpolateProperties(kf1, kf2, segmentProgress)

        -- Apply to frame
        ApplyToFrame(frame, state, props)

        -- Check completion
        if rawProgress >= 1.0 then
            if not toRemove then toRemove = {} end
            toRemove[#toRemove + 1] = frame
        end
    end

    -- Process completions
    if toRemove then
        for _, frame in ipairs(toRemove) do
            local state = lib.activeAnimations[frame]
            if state then
                local onFinished = state.onFinished

                -- Snap to final state
                local lastKf = state.keyframes[#state.keyframes]
                local finalProps = {}
                for _, name in ipairs(PROPERTY_NAMES) do
                    finalProps[name] = GetProperty(lastKf, name)
                end
                ApplyToFrame(frame, state, finalProps)

                lib.activeAnimations[frame] = nil

                if onFinished then
                    onFinished(frame)
                end
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

    -- Capture current anchor
    local pt, rel, relPt, x, y = frame:GetPoint()
    if not pt then
        error("LibAnimate-1.0: Frame has no anchor point set", 2)
    end

    local state = {
        definition = def,
        keyframes = def.keyframes,
        startTime = GetTime(),
        duration = opts.duration or def.defaultDuration,
        distance = opts.distance or def.defaultDistance,
        onFinished = opts.onFinished,
        anchorPoint = pt,
        anchorRelativeTo = rel,
        anchorRelativePoint = relPt,
        anchorX = x or 0,
        anchorY = y or 0,
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
    frame:SetScale(1)
    frame:SetAlpha(1)

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
    for name in pairs(lib.animations) do
        names[#names + 1] = name
    end
    table_sort(names)
    return names
end

function lib:GetEntranceAnimations()
    local names = {}
    for name, def in pairs(lib.animations) do
        if def.type == "entrance" then
            names[#names + 1] = name
        end
    end
    table_sort(names)
    return names
end

function lib:GetExitAnimations()
    local names = {}
    for name, def in pairs(lib.animations) do
        if def.type == "exit" then
            names[#names + 1] = name
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

    lib.animations[name] = definition
end
