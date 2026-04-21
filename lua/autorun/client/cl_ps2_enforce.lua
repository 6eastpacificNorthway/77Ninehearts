-- ps2_horror_v2/lua/autorun/client/cl_ps2_enforce.lua
-- Receives server-pushed settings, applies them, and reports rendering mode back

if SERVER then return end

-- Maps server setting names to client convar names
local settingToConvar = {
    enabled              = "ps2_horror_enabled",
    color_depth          = "ps2_horror_color_depth",
    dither_strength      = "ps2_horror_dither_strength",
    saturation           = "ps2_horror_saturation",
    contrast             = "ps2_horror_contrast",
    cyan_shadows         = "ps2_horror_cyan_shadows",
    warm_highlights      = "ps2_horror_warm_highlights",
    chroma_aberration    = "ps2_horror_chroma_aberration",
    vignette             = "ps2_horror_vignette",
    scanlines            = "ps2_horror_scanlines",
    scanline_freq        = "ps2_horror_scanline_freq",
    brightness           = "ps2_horror_brightness",
    effect_strength      = "ps2_horror_effect_strength",
}

net.Receive("PS2Horror_PushSettings", function()
    local count = net.ReadUInt(8)
    for i = 1, count do
        local key = net.ReadString()
        local val = net.ReadFloat()
        local cvar = settingToConvar[key]
        if cvar then
            RunConsoleCommand(cvar, tostring(val))
        end
    end
end)

-- Report rendering mode back to server after we've initialized
local reportedMode = nil
timer.Create("PS2Horror_ReportMode", 2, 0, function()
    if not PS2Horror or not PS2Horror.ShaderMode then return end
    if PS2Horror.ShaderMode == reportedMode then return end

    reportedMode = PS2Horror.ShaderMode

    net.Start("PS2Horror_ReportMode")
    net.WriteString(PS2Horror.ShaderMode)
    net.SendToServer()
end)
