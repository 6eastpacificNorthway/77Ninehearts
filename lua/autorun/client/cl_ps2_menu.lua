-- ps2_horror_v2/lua/autorun/client/cl_ps2_menu.lua
-- Tuning UI: type 'ps2_horror_menu' in console to open.
-- Note: if server is force-pushing settings, they override local changes every 30s.

if SERVER then return end

concommand.Add("ps2_horror_menu", function()
    if IsValid(PS2HorrorMenu) then PS2HorrorMenu:Remove() end

    local frame = vgui.Create("DFrame")
    PS2HorrorMenu = frame
    frame:SetSize(420, 700)
    frame:Center()
    frame:SetTitle("PS2 Horror v2 -- Tuning (" .. (PS2Horror and PS2Horror.ShaderMode or "?") .. " mode)")
    frame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)

    local function AddLabel(text, color)
        local l = vgui.Create("DLabel", scroll)
        l:Dock(TOP)
        l:DockMargin(10, 10, 10, 2)
        l:SetText(text)
        l:SetTextColor(color or Color(200, 200, 200))
        l:SetFont("DermaDefaultBold")
        return l
    end

    local function AddSlider(label, cvar, min, max, dec)
        local s = vgui.Create("DNumSlider", scroll)
        s:Dock(TOP)
        s:DockMargin(10, 3, 10, 3)
        s:SetText(label)
        s:SetMin(min)
        s:SetMax(max)
        s:SetDecimals(dec or 2)
        s:SetConVar(cvar)
        return s
    end

    local function AddCheck(label, cvar)
        local c = vgui.Create("DCheckBoxLabel", scroll)
        c:Dock(TOP)
        c:DockMargin(10, 3, 10, 3)
        c:SetText(label)
        c:SetConVar(cvar)
        return c
    end

    local function AddButton(label, fn)
        local b = vgui.Create("DButton", scroll)
        b:Dock(TOP)
        b:DockMargin(10, 3, 10, 3)
        b:SetText(label)
        b.DoClick = fn
        return b
    end

    AddLabel("-- Toggles --", Color(180, 220, 255))
    AddCheck("Master Enable", "ps2_horror_enabled")
    AddCheck("Force Lua Fallback (debug)", "ps2_horror_force_lua")
    AddCheck("Flatten World Materials", "ps2_horror_flatten_materials")
    AddCheck("Force Low-Gfx Mode (aggressive)", "ps2_horror_force_lowgfx")

    AddLabel("-- Color Grading --", Color(180, 220, 255))
    AddSlider("Saturation", "ps2_horror_saturation", 0, 1.5)
    AddSlider("Contrast", "ps2_horror_contrast", 0.8, 1.5)
    AddSlider("Brightness", "ps2_horror_brightness", 0.5, 1.5)
    AddSlider("Cyan Shadow Tint", "ps2_horror_cyan_shadows", 0, 0.15)
    AddSlider("Warm Highlight Tint", "ps2_horror_warm_highlights", 0, 0.1)

    AddLabel("-- PS2 Artifacts --", Color(180, 220, 255))
    AddSlider("Color Depth (levels)", "ps2_horror_color_depth", 2, 32, 0)
    AddSlider("Dither Strength", "ps2_horror_dither_strength", 0, 1)
    AddSlider("Chromatic Aberration", "ps2_horror_chroma_aberration", 0, 0.01, 4)
    AddSlider("Scanlines", "ps2_horror_scanlines", 0, 0.3)
    AddSlider("Scanline Frequency", "ps2_horror_scanline_freq", 100, 1080, 0)
    AddSlider("Vignette", "ps2_horror_vignette", 0, 1)
    AddSlider("Effect Strength (master)", "ps2_horror_effect_strength", 0, 1)

    AddLabel("-- Presets --", Color(255, 220, 180))

    AddButton("Haunting Ground (default)", function()
        RunConsoleCommand("ps2_horror_color_depth", "6.0")
        RunConsoleCommand("ps2_horror_dither_strength", "0.5")
        RunConsoleCommand("ps2_horror_saturation", "0.45")
        RunConsoleCommand("ps2_horror_contrast", "1.18")
        RunConsoleCommand("ps2_horror_cyan_shadows", "0.055")
        RunConsoleCommand("ps2_horror_warm_highlights", "0.04")
        RunConsoleCommand("ps2_horror_chroma_aberration", "0.003")
        RunConsoleCommand("ps2_horror_vignette", "0.4")
        RunConsoleCommand("ps2_horror_scanlines", "0.05")
        RunConsoleCommand("ps2_horror_brightness", "0.95")
    end)

    AddButton("Silent Hill 2 (fog & dread)", function()
        RunConsoleCommand("ps2_horror_color_depth", "5.0")
        RunConsoleCommand("ps2_horror_dither_strength", "0.7")
        RunConsoleCommand("ps2_horror_saturation", "0.3")
        RunConsoleCommand("ps2_horror_contrast", "1.25")
        RunConsoleCommand("ps2_horror_cyan_shadows", "0.03")
        RunConsoleCommand("ps2_horror_warm_highlights", "0.02")
        RunConsoleCommand("ps2_horror_chroma_aberration", "0.002")
        RunConsoleCommand("ps2_horror_vignette", "0.6")
        RunConsoleCommand("ps2_horror_scanlines", "0.07")
        RunConsoleCommand("ps2_horror_brightness", "0.85")
    end)

    AddButton("Resident Evil Outbreak", function()
        RunConsoleCommand("ps2_horror_color_depth", "8.0")
        RunConsoleCommand("ps2_horror_dither_strength", "0.3")
        RunConsoleCommand("ps2_horror_saturation", "0.6")
        RunConsoleCommand("ps2_horror_contrast", "1.1")
        RunConsoleCommand("ps2_horror_cyan_shadows", "0.07")
        RunConsoleCommand("ps2_horror_warm_highlights", "0.06")
        RunConsoleCommand("ps2_horror_chroma_aberration", "0.004")
        RunConsoleCommand("ps2_horror_vignette", "0.3")
        RunConsoleCommand("ps2_horror_scanlines", "0.03")
        RunConsoleCommand("ps2_horror_brightness", "1.0")
    end)

    AddButton("Fatal Frame (maximum crunch)", function()
        RunConsoleCommand("ps2_horror_color_depth", "4.0")
        RunConsoleCommand("ps2_horror_dither_strength", "0.8")
        RunConsoleCommand("ps2_horror_saturation", "0.2")
        RunConsoleCommand("ps2_horror_contrast", "1.3")
        RunConsoleCommand("ps2_horror_cyan_shadows", "0.02")
        RunConsoleCommand("ps2_horror_warm_highlights", "0.01")
        RunConsoleCommand("ps2_horror_chroma_aberration", "0.006")
        RunConsoleCommand("ps2_horror_vignette", "0.7")
        RunConsoleCommand("ps2_horror_scanlines", "0.1")
        RunConsoleCommand("ps2_horror_brightness", "0.8")
    end)

    AddButton("Off", function()
        RunConsoleCommand("ps2_horror_enabled", "0")
    end)

    AddLabel("-- Diagnostics --", Color(255, 255, 180))
    AddButton("Print status to console", function()
        RunConsoleCommand("ps2_horror_status")
    end)
    AddButton("Install help", function()
        RunConsoleCommand("ps2_horror_install_help")
    end)
end)
