-- cl_ps2_lua_fallback.lua
-- Active when native shaders aren't installed. Approximates the master shader
-- using Source's built-in post-process primitives (DrawColorModify,
-- DrawColorCorrection, DrawSharpen) plus a Bayer texture overlay.
--
-- Real dithering, bit depth reduction, and chromatic aberration require shader
-- access -- they're not possible here. This path is a reasonable approximation,
-- not an equivalent.

if SERVER then return end

local bayerMat = nil
local function GetBayerMat()
    if not bayerMat then
        bayerMat = Material("ps2_horror/bayer8x8")
    end
    return bayerMat
end

-- Build the DrawColorModify parameter table from our convars.
-- Note: DrawColorModify applies its tint uniformly to every pixel, so we can't
-- reproduce the shader's "shadow-only cyan + highlight-only warm" split here.
-- We do only the global adjustments (saturation, contrast, brightness) and let
-- the LUT file (applied below via DrawColorCorrection) handle the tint splits.
--
-- LIMITATION: the LUT is baked at fixed values in generate_lut.py. Tweaking
-- ps2_horror_cyan_shadows / warm_highlights at runtime does nothing in Lua
-- mode -- to change the baked tints you'd regenerate the LUT offline. Only
-- native (shader) mode supports runtime tint adjustment.
local function BuildColorParams(strength)
    local sat        = GetConVar("ps2_horror_saturation"):GetFloat()
    local contrast   = GetConVar("ps2_horror_contrast"):GetFloat()
    local brightness = GetConVar("ps2_horror_brightness"):GetFloat()

    return {
        ["$pp_colour_addr"]       = 0,
        ["$pp_colour_addg"]       = 0,
        ["$pp_colour_addb"]       = 0,
        ["$pp_colour_brightness"] = (brightness - 1.0) * strength,
        ["$pp_colour_contrast"]   = 1 + (contrast - 1) * strength,
        ["$pp_colour_colour"]     = 1 - (1 - sat) * strength,
        ["$pp_colour_mulr"]       = 1.0,
        ["$pp_colour_mulg"]       = 1.0,
        ["$pp_colour_mulb"]       = 1.0,
    }
end

-- Fake posterization using DrawSharpen. Lower color depth = more contrast boost.
-- This doesn't create real banding (we can't quantize without shaders), but it
-- pushes the image toward a more hard-edged look that suggests banding.
local function ApplyPosterizationHint(depth)
    if depth >= 32 then return end
    local amount = math.Clamp(10 / depth, 0, 3) * 0.2
    DrawSharpen(amount, 0.8)
end

-- Vignette drawn as a series of filled rectangles in concentric rings.
-- Alpha drops off toward the center -- approximates a radial gradient.
local function DrawVignette(strength)
    if strength <= 0.01 then return end

    local scrW, scrH = ScrW(), ScrH()
    local rings = 12

    for ring = 1, rings do
        -- Ring N occupies inset to inset+step, with alpha increasing toward edges
        local t = ring / rings
        local insetFrac = 1 - t
        local insetX = scrW * insetFrac * 0.02
        local insetY = scrH * insetFrac * 0.02

        -- Quadratic falloff for a softer gradient
        local a = math.Clamp((1 - insetFrac) * (1 - insetFrac) * strength * 180, 0, 255)
        surface.SetDrawColor(0, 0, 0, a)

        -- Four edge bands, overlapping at corners (the overlap darkens corners
        -- more -- exactly what a vignette should do)
        local band = scrW * 0.015
        surface.DrawRect(insetX, insetY, scrW - 2 * insetX, band)                 -- top
        surface.DrawRect(insetX, scrH - insetY - band, scrW - 2 * insetX, band)   -- bottom
        surface.DrawRect(insetX, insetY, band, scrH - 2 * insetY)                 -- left
        surface.DrawRect(scrW - insetX - band, insetY, band, scrH - 2 * insetY)   -- right
    end
end

-- Main render pass
hook.Add("RenderScreenspaceEffects", "PS2Horror_LuaFallback", function()
    if PS2Horror == nil or PS2Horror.ShaderMode ~= "lua" then return end
    if not GetConVar("ps2_horror_enabled"):GetBool() then return end

    local strength = GetConVar("ps2_horror_effect_strength"):GetFloat()
    if strength <= 0.01 then return end

    -- 1. Color grading
    DrawColorModify(BuildColorParams(strength))

    -- 2. Posterization hint (sharpen-based approximation)
    ApplyPosterizationHint(GetConVar("ps2_horror_color_depth"):GetFloat())

    -- 3. Color correction LUT (materials/correction/ps2_horror.raw)
    DrawColorCorrection("correction/ps2_horror.raw", 0.85 * strength)
end)

-- Bayer dither overlay -- drawn in HUDPaint so it sits over the world but
-- under any HUD elements the gamemode draws later.
hook.Add("HUDPaint", "PS2Horror_BayerOverlay", function()
    if PS2Horror == nil or PS2Horror.ShaderMode ~= "lua" then return end
    if not GetConVar("ps2_horror_enabled"):GetBool() then return end

    local strength = GetConVar("ps2_horror_effect_strength"):GetFloat()
    local dither = GetConVar("ps2_horror_dither_strength"):GetFloat() * strength
    if dither <= 0.01 then return end

    local mat = GetBayerMat()
    if not mat or mat:IsError() then return end

    -- 24Hz animated offset -- PS2 judder feel
    local t = CurTime() * 24
    local ox = math.floor(t * 3) % 64
    local oy = math.floor(t * 2) % 64

    local alpha = math.Clamp(22 * dither, 0, 40)
    local scrW, scrH = ScrW(), ScrH()
    local texW, texH = 64, 64

    surface.SetDrawColor(255, 255, 255, alpha)
    surface.SetMaterial(mat)
    surface.DrawTexturedRectUV(
        -ox, -oy,
        scrW + texW, scrH + texH,
        0, 0,
        (scrW + texW) / texW,
        (scrH + texH) / texH
    )
end)

-- Vignette -- separate hook so alpha layering matches the native shader order
hook.Add("HUDPaint", "PS2Horror_Vignette", function()
    if PS2Horror == nil or PS2Horror.ShaderMode ~= "lua" then return end
    if not GetConVar("ps2_horror_enabled"):GetBool() then return end

    local strength = GetConVar("ps2_horror_effect_strength"):GetFloat()
    local vig = GetConVar("ps2_horror_vignette"):GetFloat() * strength
    DrawVignette(vig)
end)

-- NOTE: chromatic aberration is NOT reproduced in Lua mode. Faking it via
-- DrawMotionBlur or overdraw creates more artifacts than it solves. Lua-mode
-- clients simply miss this effect; it's one of the reasons to install the
-- native shader pack.

print("[PS2 Horror] Lua fallback renderer loaded.")
