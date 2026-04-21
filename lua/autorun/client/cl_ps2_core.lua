-- cl_ps2_core.lua
-- Entry point: detects whether native shaders are installed and dispatches
-- accordingly. Also owns the convar list and the native-mode render hook.

if SERVER then return end

PS2Horror = PS2Horror or {}
PS2Horror.Version = "2.0"
PS2Horror.ShaderMode = nil   -- "native" or "lua"
PS2Horror.MasterMaterial = nil

-- Convars (server can force-push these)
CreateClientConVar("ps2_horror_enabled",            "1",     true, false)
CreateClientConVar("ps2_horror_force_lua",          "1",     true, false,
    "Force the Lua fallback even if native shaders are installed")
CreateClientConVar("ps2_horror_color_depth",        "6.0",   true, false)
CreateClientConVar("ps2_horror_dither_strength",    "0.3",   true, false)
CreateClientConVar("ps2_horror_saturation",         "0.45",  true, false)
CreateClientConVar("ps2_horror_contrast",           "1.18",  true, false)
CreateClientConVar("ps2_horror_cyan_shadows",       "0.055", true, false)
CreateClientConVar("ps2_horror_warm_highlights",    "0.04",  true, false)
CreateClientConVar("ps2_horror_chroma_aberration",  "0.003", true, false)
CreateClientConVar("ps2_horror_vignette",           "0.4",   true, false)
CreateClientConVar("ps2_horror_scanlines",          "0.05",  true, false)
CreateClientConVar("ps2_horror_scanline_freq",      "540.0", true, false,
    "Scanline count across screen height (540 ~= 1080p native)")
CreateClientConVar("ps2_horror_brightness",         "0.95",  true, false)
CreateClientConVar("ps2_horror_effect_strength",    "1.0",   true, false)

-- --- SHADER DETECTION ---
local function DetectShaderSupport()
    local vmtPath = "materials/effects/shaders/ps2_master.vmt"
    local hasVmt = file.Exists(vmtPath, "GAME")

    -- ShaderCompile may emit .vcs under several naming conventions depending
    -- on tool version. Check the most likely candidates.
    local candidates = {
        "shaders/fxc/ps2_master_ps2x.vcs",
        "shaders/fxc/ps2_master_ps2x_ps20b.vcs",
        "shaders/fxc/ps2_master_ps20b.vcs",
        "shaders/fxc/ps2_master.vcs",
    }
    local foundShader = nil
    for _, path in ipairs(candidates) do
        if file.Exists(path, "GAME") then
            foundShader = path
            break
        end
    end

    -- Custom pixel shaders require DX9+; VMT <dx90 block handles DX8
    local dxLevel = render.GetDXLevel and render.GetDXLevel() or 90
    local dxOk = dxLevel >= 90

    local info = {
        shader = foundShader,
        vmt = hasVmt and vmtPath or nil,
        dx = dxOk,
        dxLevel = dxLevel,
    }

    if foundShader and hasVmt and dxOk then
        return "native", info
    end
    return "lua", info
end

-- --- NATIVE SHADER SETUP ---
local function InitNativeShaders()
    local mat = Material("effects/shaders/ps2_master")
    if not mat or mat:IsError() then
        print("[PS2 Horror] Master material failed to load; falling back to Lua")
        return false
    end
    PS2Horror.MasterMaterial = mat
    PS2Horror.ShaderMode = "native"
    print("[PS2 Horror] Native shader mode active.")
    return true
end

local function InitLuaFallback()
    PS2Horror.ShaderMode = "lua"
    print("[PS2 Horror] Lua fallback mode active.")
end

-- --- CONVAR -> MATERIAL PARAM SYNC ---
-- Distributes our 12 user-facing convars across the shader's 16 float slots.
-- Some slots are computed (shadow R/G from a single cyan_shadows convar, etc.)
-- to reduce UI surface area. All values are floats.
local function SyncMaterialParams()
    if PS2Horror.ShaderMode ~= "native" then return end
    local mat = PS2Horror.MasterMaterial
    if not mat or mat:IsError() then return end

    local depth      = GetConVar("ps2_horror_color_depth"):GetFloat()
    local dither     = GetConVar("ps2_horror_dither_strength"):GetFloat()
    local sat        = GetConVar("ps2_horror_saturation"):GetFloat()
    local contrast   = GetConVar("ps2_horror_contrast"):GetFloat()
    local cyan       = GetConVar("ps2_horror_cyan_shadows"):GetFloat()
    local warm       = GetConVar("ps2_horror_warm_highlights"):GetFloat()
    local chroma     = GetConVar("ps2_horror_chroma_aberration"):GetFloat()
    local vignette   = GetConVar("ps2_horror_vignette"):GetFloat()
    local scanAmount = GetConVar("ps2_horror_scanlines"):GetFloat()
    local scanFreq   = GetConVar("ps2_horror_scanline_freq"):GetFloat()
    local brightness = GetConVar("ps2_horror_brightness"):GetFloat()
    local strength   = GetConVar("ps2_horror_effect_strength"):GetFloat()

    -- c0
    mat:SetFloat("$c0_x", depth)
    mat:SetFloat("$c0_y", dither)
    mat:SetFloat("$c0_z", sat)
    mat:SetFloat("$c0_w", contrast)
    -- c1 - shadow tint derived from a single cyan slider
    mat:SetFloat("$c1_x", -cyan * 0.4)
    mat:SetFloat("$c1_y",  cyan * 0.3)
    mat:SetFloat("$c1_z",  cyan)
    mat:SetFloat("$c1_w",  chroma)
    -- c2 - highlight tint derived from a single warm slider
    mat:SetFloat("$c2_x",  warm)
    mat:SetFloat("$c2_y",  warm * 0.5)
    mat:SetFloat("$c2_z", -warm * 0.75)
    mat:SetFloat("$c2_w",  vignette)
    -- c3
    mat:SetFloat("$c3_x",  scanAmount)
    mat:SetFloat("$c3_y",  scanFreq)
    mat:SetFloat("$c3_z",  brightness)
    mat:SetFloat("$c3_w",  strength)
end

-- --- RENDER HOOK (native mode only) ---
hook.Add("RenderScreenspaceEffects", "PS2Horror_Master", function()
    if PS2Horror.ShaderMode ~= "native" then return end
    if not GetConVar("ps2_horror_enabled"):GetBool() then return end

    SyncMaterialParams()
    render.SetMaterial(PS2Horror.MasterMaterial)
    render.DrawScreenQuad()
end)

-- --- INITIALIZATION ---
hook.Add("InitPostEntity", "PS2Horror_Init", function()
    timer.Simple(1, function()
        local forceLua = GetConVar("ps2_horror_force_lua"):GetBool()
        local mode, info = DetectShaderSupport()

        print(string.format(
            "[PS2 Horror] Detection: shader=%s vmt=%s dx=%d",
            tostring(info.shader), tostring(info.vmt), info.dxLevel or 0
        ))

        if forceLua or mode == "lua" then
            InitLuaFallback()
        else
            if not InitNativeShaders() then
                InitLuaFallback()
            end
        end
    end)
end)

-- --- COMMANDS ---
concommand.Add("ps2_horror_status", function()
    print("[PS2 Horror v" .. PS2Horror.Version .. "]")
    print("  Mode:            " .. tostring(PS2Horror.ShaderMode))
    print("  Enabled:         " .. tostring(GetConVar("ps2_horror_enabled"):GetBool()))
    print("  Effect strength: " .. GetConVar("ps2_horror_effect_strength"):GetFloat())
    local _, info = DetectShaderSupport()
    print("  Shader file:     " .. tostring(info.shader))
    print("  VMT file:        " .. tostring(info.vmt))
    print("  DX level:        " .. tostring(info.dxLevel))
end)

concommand.Add("ps2_horror_install_help", function()
    chat.AddText(Color(100, 200, 255), "[PS2 Horror] ",
        Color(255, 255, 255), "Current mode: " .. tostring(PS2Horror.ShaderMode))
    if PS2Horror.ShaderMode == "native" then
        chat.AddText("Native shaders are loaded. No action needed.")
    else
        chat.AddText("To enable native shaders, ensure the Workshop addon is subscribed,")
        chat.AddText("then restart GMod (shaders only load on startup).")
    end
end)

print("[PS2 Horror v" .. PS2Horror.Version .. "] Core loaded.")
