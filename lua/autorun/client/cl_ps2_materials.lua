-- ps2_horror/lua/autorun/client/cl_ps2_materials.lua
-- Runtime material flattening: removes normal maps, specular, phong, env cubes
-- Forces half-lambert shading for that soft pre-baked look

if SERVER then return end

CreateClientConVar("ps2_horror_flatten_materials", "1", true, false,
    "Flatten world materials to PS2-era shading (disable bumpmaps, specular)")

local modifiedMats = {}
local origParams = {}

local function FlattenMaterial(mat)
    if not mat or mat:IsError() then return end
    local name = mat:GetName()
    if modifiedMats[name] then return end
    modifiedMats[name] = true

    -- Save originals so we can restore on disable
    origParams[name] = {
        bump = mat:GetString("$bumpmap"),
        envmap = mat:GetString("$envmap"),
        phong = mat:GetInt("$phong"),
        halflambert = mat:GetInt("$halflambert"),
        specular = mat:GetInt("$basemapalphaphongmask"),
    }

    -- Strip modern shading features
    mat:SetUndefined("$bumpmap")
    mat:SetUndefined("$bumpmap2")
    mat:SetUndefined("$envmap")
    mat:SetUndefined("$envmapmask")
    mat:SetInt("$phong", 0)
    mat:SetInt("$halflambert", 1)
    mat:SetInt("$nodiffusebumplight", 1)
    mat:SetFloat("$phongboost", 0)
    mat:SetFloat("$phongexponent", 0)
    mat:SetInt("$rimlight", 0)
    mat:SetInt("$basemapalphaphongmask", 0)

    -- Slight darkening / desaturation baked into material color
    mat:SetVector("$color2", Vector(0.92, 0.92, 0.95))
end

local function RestoreMaterial(name)
    local mat = Material(name)
    if not mat or mat:IsError() then return end
    local orig = origParams[name]
    if not orig then return end

    if orig.bump and orig.bump ~= "" then mat:SetString("$bumpmap", orig.bump) end
    if orig.envmap and orig.envmap ~= "" then mat:SetString("$envmap", orig.envmap) end
    mat:SetInt("$phong", orig.phong or 0)
    mat:SetInt("$halflambert", orig.halflambert or 0)
    mat:SetVector("$color2", Vector(1,1,1))

    modifiedMats[name] = nil
end

-- Scan and flatten map materials when joining a map
hook.Add("InitPostEntity", "PS2Horror_FlattenMats", function()
    if not GetConVar("ps2_horror_flatten_materials"):GetBool() then return end

    timer.Simple(2, function()
        -- Walk through all known materials that Source has loaded
        -- GetRenderTargets isn't the right API; instead we hook material lookups
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent:GetModel() then
                local mats = ent:GetMaterials()
                if mats then
                    for _, matName in ipairs(mats) do
                        local m = Material(matName)
                        FlattenMaterial(m)
                    end
                end
            end
        end
        print("[PS2 Horror] Flattened " .. table.Count(modifiedMats) .. " materials")
    end)
end)

-- Also flatten materials on newly spawned entities
hook.Add("NetworkEntityCreated", "PS2Horror_FlattenNew", function(ent)
    if not GetConVar("ps2_horror_flatten_materials"):GetBool() then return end
    timer.Simple(0.1, function()
        if not IsValid(ent) then return end
        local mats = ent:GetMaterials()
        if not mats then return end
        for _, matName in ipairs(mats) do
            FlattenMaterial(Material(matName))
        end
    end)
end)

-- Console command to manually restore (for debugging / if player wants to opt out locally)
concommand.Add("ps2_horror_restore_materials", function()
    for name, _ in pairs(modifiedMats) do
        RestoreMaterial(name)
    end
    print("[PS2 Horror] Restored " .. table.Count(origParams) .. " materials")
end)

-- Force low-quality texture filtering and strip modern rendering features.
-- This is aggressive (affects gameplay via no specular, no shadows, etc.) so it
-- defaults to OFF. Server admins can enable via ps2_horror_force_lowgfx 1 and
-- push that setting to clients for a more consistent look.
CreateClientConVar("ps2_horror_force_lowgfx", "0", true, false,
    "Aggressively strip modern rendering (specular, phong, HDR). Affects gameplay visibility.")

hook.Add("InitPostEntity", "PS2Horror_ForceFilter", function()
    if not GetConVar("ps2_horror_force_lowgfx"):GetBool() then return end
    timer.Simple(1, function()
        RunConsoleCommand("mat_filtertextures", "1")   -- bilinear, not trilinear
        RunConsoleCommand("mat_trilinear",      "0")
        RunConsoleCommand("mat_forceaniso",     "0")
        RunConsoleCommand("mat_specular",       "0")   -- kills cubemap reflections
        RunConsoleCommand("mat_bumpmap",        "0")
        RunConsoleCommand("mat_phong",          "0")
        RunConsoleCommand("r_rimlight",         "0")
        RunConsoleCommand("mat_hdr_level",      "0")   -- disable HDR bloom
        RunConsoleCommand("mat_bloomscale",     "0")
        RunConsoleCommand("r_flashlightdepthtexture", "0")  -- flat shadows
        print("[PS2 Horror] Low-gfx mode applied (ps2_horror_force_lowgfx).")
    end)
end)
