-- ps2_horror_v2/lua/autorun/server/sv_ps2_horror.lua
-- Server-side: force-pushes settings, tracks which clients have native shaders, distributes files

if CLIENT then return end

-- === WORKSHOP / FASTDL FILE DISTRIBUTION ===
-- As of March 2025, GMod loads custom shaders from Workshop addons (MOD/THIRDPARTY/BSP paths).
-- The Workshop mount handles shader loading automatically when the addon contains them.
-- We still resource.AddFile the VTF, VMT, and LUT for players who might not have the Workshop
-- version and rely on FastDL instead.

resource.AddFile("materials/correction/ps2_horror.raw")
resource.AddFile("materials/ps2_horror/bayer8x8.vtf")
resource.AddFile("materials/ps2_horror/bayer8x8.vmt")
resource.AddFile("materials/effects/shaders/ps2_master.vmt")
resource.AddFile("materials/effects/shaders/ps2_dither.vmt")
resource.AddFile("materials/effects/shaders/ps2_chroma.vmt")
resource.AddFile("materials/effects/shaders/ps2_affine.vmt")
resource.AddFile("materials/effects/shaders/ps2_crt.vmt")

-- NOTE: .vcs shader files are NOT valid targets for resource.AddFile (not whitelisted for FastDL).
-- They must arrive via the Workshop addon itself. This is why Workshop is the recommended route.
-- Uncomment and fill this line after you publish to Workshop:
--   resource.AddWorkshop("YOUR_WORKSHOP_ID_HERE")

-- === NETWORK STRINGS ===
util.AddNetworkString("PS2Horror_PushSettings")
util.AddNetworkString("PS2Horror_ReportMode")

-- === SERVER-TUNABLE SETTINGS ===
-- Edit this table to change the look server-wide. Changes propagate within 30 seconds.
PS2Horror_Settings = {
    enabled              = 1,
    color_depth          = 6.0,
    dither_strength      = 0.3,      -- was 0.5; 0.5 stippled flat regions too obviously
    saturation           = 0.45,
    contrast             = 1.18,
    cyan_shadows         = 0.055,
    warm_highlights      = 0.04,
    chroma_aberration    = 0.003,
    vignette             = 0.25,
    scanlines            = 0.08,
    scanline_freq        = 24.0,
    brightness           = 0.95,
    effect_strength      = 1.0,
}

-- Preset table - admin commands below select from these
local PRESETS = {
    haunting_ground = {
        color_depth = 6.0, dither_strength = 0.3, saturation = 0.45,
        contrast = 1.18, cyan_shadows = 0.055, warm_highlights = 0.04,
        chroma_aberration = 0.003, vignette = 0.25, scanlines = 0.08,
        scanline_freq = 24.0, brightness = 0.95,
    },
    silent_hill_2 = {
        color_depth = 5.0, dither_strength = 0.4, saturation = 0.3,
        contrast = 1.25, cyan_shadows = 0.03, warm_highlights = 0.02,
        chroma_aberration = 0.002, vignette = 0.35, scanlines = 0.10,
        scanline_freq = 20.0, brightness = 0.85,
    },
    re_outbreak = {
        color_depth = 8.0, dither_strength = 0.25, saturation = 0.6,
        contrast = 1.1, cyan_shadows = 0.07, warm_highlights = 0.06,
        chroma_aberration = 0.004, vignette = 0.20, scanlines = 0.05,
        scanline_freq = 30.0, brightness = 1.0,
    },
    fatal_frame = {
        color_depth = 4.0, dither_strength = 0.5, saturation = 0.2,
        contrast = 1.3, cyan_shadows = 0.02, warm_highlights = 0.01,
        chroma_aberration = 0.006, vignette = 0.4, scanlines = 0.15,
        scanline_freq = 18.0, brightness = 0.8,
    },
}

-- === TRACKED PLAYER STATE ===
-- Maps SteamID -> "native" / "lua" / "unknown"
local clientModes = {}

-- === SETTINGS PUSH ===
local function PushSettings(ply)
    net.Start("PS2Horror_PushSettings")
    net.WriteUInt(table.Count(PS2Horror_Settings), 8)
    for k, v in pairs(PS2Horror_Settings) do
        net.WriteString(k)
        net.WriteFloat(v)
    end
    if ply then net.Send(ply) else net.Broadcast() end
end

hook.Add("PlayerInitialSpawn", "PS2Horror_PushOnJoin", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then
            PushSettings(ply)
            clientModes[ply:SteamID()] = "unknown"
        end
    end)
end)

-- Reassert settings periodically (every 30s) to defeat local disables
timer.Create("PS2Horror_Reassert", 30, 0, function()
    if player.GetCount() > 0 then
        PushSettings()
    end
end)

hook.Add("PlayerDisconnected", "PS2Horror_Cleanup", function(ply)
    clientModes[ply:SteamID()] = nil
end)

-- === CLIENT MODE REPORT-BACK ===
-- Clients tell us whether they're running native or Lua mode
net.Receive("PS2Horror_ReportMode", function(len, ply)
    if not IsValid(ply) then return end
    local mode = net.ReadString()
    if mode == "native" or mode == "lua" then
        clientModes[ply:SteamID()] = mode
        print(string.format("[PS2 Horror] %s (%s) is running in %s mode",
            ply:Nick(), ply:SteamID(), mode))
    end
end)

-- === ADMIN COMMANDS ===
concommand.Add("ps2_horror_preset", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local name = args[1]
    local preset = PRESETS[name]
    if not preset then
        local msg = "Available presets: " .. table.concat(table.GetKeys(PRESETS), ", ")
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end
    for k, v in pairs(preset) do
        PS2Horror_Settings[k] = v
    end
    PushSettings()
    print("[PS2 Horror] Applied preset: " .. name)
end)

concommand.Add("ps2_horror_set", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local key, val = args[1], tonumber(args[2])
    if not key or not val then
        print("Usage: ps2_horror_set <key> <number>")
        print("Keys: " .. table.concat(table.GetKeys(PS2Horror_Settings), ", "))
        return
    end
    if PS2Horror_Settings[key] == nil then
        print("Unknown key: " .. key)
        return
    end
    PS2Horror_Settings[key] = val
    PushSettings()
    print(string.format("[PS2 Horror] Set %s = %g", key, val))
end)

concommand.Add("ps2_horror_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local lines = {"[PS2 Horror] Server status:"}
    table.insert(lines, "  Current settings:")
    for k, v in pairs(PS2Horror_Settings) do
        table.insert(lines, string.format("    %s = %g", k, v))
    end
    table.insert(lines, "  Client modes:")
    local native, lua_m, unknown = 0, 0, 0
    for _, p in ipairs(player.GetAll()) do
        local m = clientModes[p:SteamID()] or "unknown"
        table.insert(lines, string.format("    %s: %s", p:Nick(), m))
        if m == "native" then native = native + 1
        elseif m == "lua" then lua_m = lua_m + 1
        else unknown = unknown + 1 end
    end
    table.insert(lines, string.format("  Summary: %d native, %d lua, %d unknown", native, lua_m, unknown))

    local output = table.concat(lines, "\n")
    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, output)
    else
        print(output)
    end
end)

concommand.Add("ps2_horror_enable", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    PS2Horror_Settings.enabled = 1
    PushSettings()
end)

concommand.Add("ps2_horror_disable", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    PS2Horror_Settings.enabled = 0
    PushSettings()
end)

print("[PS2 Horror v2] Server module loaded.")
print("[PS2 Horror v2] Admin commands: ps2_horror_preset, ps2_horror_set, ps2_horror_status, ps2_horror_enable, ps2_horror_disable")
