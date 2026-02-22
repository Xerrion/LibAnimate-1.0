-------------------------------------------------------------------------------
-- Animations.lua
-- Built-in animation definitions for LibAnimate-1.0
-- Adapted from animate.css (https://animate.style) by Daniel Eden
--
-- Supported versions: Retail, TBC Anniversary, MoP Classic
-------------------------------------------------------------------------------

local lib = LibStub("LibAnimate-1.0")

-------------------------------------------------------------------------------
-- Back Entrances (defaultDuration=0.6, defaultDistance=300)
-------------------------------------------------------------------------------

lib:RegisterAnimation("backInDown", {
    type = "entrance",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, translateY = 1.0, scale = 0.7, alpha = 0.7 },
        { progress = 0.8, translateY = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("backInUp", {
    type = "entrance",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, translateY = -1.0, scale = 0.7, alpha = 0.7 },
        { progress = 0.8, translateY = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("backInLeft", {
    type = "entrance",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, translateX = -1.0, scale = 0.7, alpha = 0.7 },
        { progress = 0.8, translateX = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("backInRight", {
    type = "entrance",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, translateX = 1.0, scale = 0.7, alpha = 0.7 },
        { progress = 0.8, translateX = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

-------------------------------------------------------------------------------
-- Back Exits (defaultDuration=0.6, defaultDistance=300)
-------------------------------------------------------------------------------

lib:RegisterAnimation("backOutDown", {
    type = "exit",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.2, translateY = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, translateY = -1.0, scale = 0.7, alpha = 0.7 },
    },
})

lib:RegisterAnimation("backOutUp", {
    type = "exit",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.2, translateY = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, translateY = 1.0, scale = 0.7, alpha = 0.7 },
    },
})

lib:RegisterAnimation("backOutLeft", {
    type = "exit",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.2, translateX = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, translateX = -1.0, scale = 0.7, alpha = 0.7 },
    },
})

lib:RegisterAnimation("backOutRight", {
    type = "exit",
    defaultDuration = 0.6,
    defaultDistance = 300,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.2, translateX = 0, scale = 0.7, alpha = 0.7 },
        { progress = 1.0, translateX = 1.0, scale = 0.7, alpha = 0.7 },
    },
})

-------------------------------------------------------------------------------
-- Sliding Entrances (defaultDuration=0.4, defaultDistance=200)
-------------------------------------------------------------------------------

lib:RegisterAnimation("slideInDown", {
    type = "entrance",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateY = 1.0 },
        { progress = 1.0, translateY = 0 },
    },
})

lib:RegisterAnimation("slideInUp", {
    type = "entrance",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateY = -1.0 },
        { progress = 1.0, translateY = 0 },
    },
})

lib:RegisterAnimation("slideInLeft", {
    type = "entrance",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateX = -1.0 },
        { progress = 1.0, translateX = 0 },
    },
})

lib:RegisterAnimation("slideInRight", {
    type = "entrance",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateX = 1.0 },
        { progress = 1.0, translateX = 0 },
    },
})

-------------------------------------------------------------------------------
-- Sliding Exits (defaultDuration=0.4, defaultDistance=200)
-------------------------------------------------------------------------------

lib:RegisterAnimation("slideOutDown", {
    type = "exit",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateY = 0 },
        { progress = 1.0, translateY = -1.0 },
    },
})

lib:RegisterAnimation("slideOutUp", {
    type = "exit",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateY = 0 },
        { progress = 1.0, translateY = 1.0 },
    },
})

lib:RegisterAnimation("slideOutLeft", {
    type = "exit",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateX = 0 },
        { progress = 1.0, translateX = -1.0 },
    },
})

lib:RegisterAnimation("slideOutRight", {
    type = "exit",
    defaultDuration = 0.4,
    defaultDistance = 200,
    keyframes = {
        { progress = 0.0, translateX = 0 },
        { progress = 1.0, translateX = 1.0 },
    },
})

-------------------------------------------------------------------------------
-- Zooming Entrances (defaultDuration=0.5, defaultDistance=400)
-------------------------------------------------------------------------------

lib:RegisterAnimation("zoomIn", {
    type = "entrance",
    defaultDuration = 0.5,
    defaultDistance = 0,
    keyframes = {
        { progress = 0.0, scale = 0.3, alpha = 0 },
        { progress = 0.5, alpha = 1.0 },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("zoomInDown", {
    type = "entrance",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, translateY = 1.0, scale = 0.1, alpha = 0, easing = { 0.55, 0.055, 0.675, 0.19 } },
        { progress = 0.6, translateY = -0.06, scale = 0.475, alpha = 1.0, easing = { 0.175, 0.885, 0.32, 1 } },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("zoomInUp", {
    type = "entrance",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, translateY = -1.0, scale = 0.1, alpha = 0, easing = { 0.55, 0.055, 0.675, 0.19 } },
        { progress = 0.6, translateY = 0.06, scale = 0.475, alpha = 1.0, easing = { 0.175, 0.885, 0.32, 1 } },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("zoomInLeft", {
    type = "entrance",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, translateX = -1.0, scale = 0.1, alpha = 0, easing = { 0.55, 0.055, 0.675, 0.19 } },
        { progress = 0.6, translateX = 0.01, scale = 0.475, alpha = 1.0, easing = { 0.175, 0.885, 0.32, 1 } },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

lib:RegisterAnimation("zoomInRight", {
    type = "entrance",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, translateX = 1.0, scale = 0.1, alpha = 0, easing = { 0.55, 0.055, 0.675, 0.19 } },
        { progress = 0.6, translateX = -0.01, scale = 0.475, alpha = 1.0, easing = { 0.175, 0.885, 0.32, 1 } },
        { progress = 1.0, scale = 1.0, alpha = 1.0 },
    },
})

-------------------------------------------------------------------------------
-- Zooming Exits (defaultDuration=0.5, defaultDistance=400)
-------------------------------------------------------------------------------

lib:RegisterAnimation("zoomOut", {
    type = "exit",
    defaultDuration = 0.5,
    defaultDistance = 0,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.5, scale = 0.3, alpha = 0 },
        { progress = 1.0, scale = 0.3, alpha = 0 },
    },
})

lib:RegisterAnimation("zoomOutDown", {
    type = "exit",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0, easing = { 0.55, 0.055, 0.675, 0.19 } },
        { progress = 0.4, translateY = 0.03, scale = 0.475, alpha = 1.0, easing = { 0.175, 0.885, 0.32, 1 } },
        { progress = 1.0, translateY = -1.0, scale = 0.1, alpha = 0 },
    },
})

lib:RegisterAnimation("zoomOutUp", {
    type = "exit",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0, easing = { 0.55, 0.055, 0.675, 0.19 } },
        { progress = 0.4, translateY = -0.03, scale = 0.475, alpha = 1.0, easing = { 0.175, 0.885, 0.32, 1 } },
        { progress = 1.0, translateY = 1.0, scale = 0.1, alpha = 0 },
    },
})

lib:RegisterAnimation("zoomOutLeft", {
    type = "exit",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.4, translateX = 0.021, scale = 0.475, alpha = 1.0 },
        { progress = 1.0, translateX = -1.0, scale = 0.1, alpha = 0 },
    },
})

lib:RegisterAnimation("zoomOutRight", {
    type = "exit",
    defaultDuration = 0.5,
    defaultDistance = 400,
    keyframes = {
        { progress = 0.0, scale = 1.0, alpha = 1.0 },
        { progress = 0.4, translateX = -0.021, scale = 0.475, alpha = 1.0 },
        { progress = 1.0, translateX = 1.0, scale = 0.1, alpha = 0 },
    },
})
