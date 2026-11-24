local addonName, V = ...
local OWNER, VERSION = "ForeverUnitFrames", "0.79.1"
local seen = setmetatable({}, { __mode = "k" })
local queued, ticker, ready = false, nil, false
local groups = { "buffs", "debuffs", "dispels" }
local profileReady

local function enabled()
    return ready and not V.profileReloadPending and V:IsModuleEnabled("auras")
        and V:IsModuleEnabled("unitframes") and profileReady()
end

local function versionOK()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return get and get(OWNER, "Version") == VERSION
end

profileReady = function()
    if not UnitFullName then return false end
    local name, realm = UnitFullName("player")
    if V:IsSecret(name) or V:IsSecret(realm) then return false end
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
    if V:IsSecret(realm) or type(name) ~= "string" or type(realm) ~= "string" then return false end
    local db = _G.ForeverUnitFramesDB
    local profile = db and db.active and db.active[name .. "-" .. realm]
    return not V:IsSecret(profile) and type(profile) == "string" and profile:match("^vasagoio") ~= nil
end

local schedule
local function decorate(button, group, force)
    if V:IsSecret(button) or type(button) ~= "table" or not button.icon or not button.cooldown or not button.count then return 0,0 end
    local record = seen[button]
    if record and not force and not record.stale then return 0,0 end
    record = record or {}; seen[button] = record
    local ok = pcall(function()
        if button.IsForbidden and button:IsForbidden() then error("Restricted aura widget") end
        -- Classification comes from FUF's configured group, never aura payloads.
        -- Its dispels group is HARMFUL|RAID; debuffs is an actual harmful group.
        local signal = group == "dispels" and "dispel" or group == "debuffs" and "danger" or nil
        V:StyleAura(button, { signal = signal })
        if button.border then V:HideArtwork(button.border) end
        if not record.hooked and button.HookScript then
            button:HookScript("OnShow", function() schedule() end)
            record.hooked = true
        end
    end)
    record.stale = not ok
    return ok and 1 or 0, ok and 0 or 1
end

local function scan(force)
    if not enabled() or InCombatLockdown() then return 0,0 end
    local visited, applied, refused = {}, 0, 0
    local function style(button, group)
        local a, r = decorate(button, group, force)
        applied, refused = applied+a, refused+r
    end
    local function walk(frame, depth)
        if V:IsSecret(frame) then return end
        if not frame or visited[frame] or depth > 4 then return end
        visited[frame] = true
        if frame.IsForbidden then
            local ok, forbidden = pcall(frame.IsForbidden, frame)
            if not ok or V:IsSecret(forbidden) or forbidden then return end
        end
        for _, key in ipairs(groups) do
            -- FUF's plain/sample fallback pools contain button frames directly.
            local group = frame.auras and frame.auras[key]
            if type(group) == "table" then
                if type(group.buttons) == "table" then
                    for _, button in ipairs(group.buttons) do style(button, key) end
                end
                if type(group.free) == "table" and type(group.free.buttons) == "table" then
                    for _, button in ipairs(group.free.buttons) do style(button, key) end
                end
            end
            -- Live native aura containers register plain owner records. We read
            -- only references, never their aura lists, IDs, counts or durations.
            local entry = frame.auraContainers and frame.auraContainers[key]
            if type(entry) == "table" and type(entry.buttons) == "table" then
                for _, item in ipairs(entry.buttons) do
                    if type(item) == "table" then style(item.button, key) end
                end
            end
        end
        if frame.GetChildren then
            local children = {pcall(frame.GetChildren, frame)}
            if children[1] then
                for i = 2, #children do walk(children[i], depth+1) end
            else
                refused = refused + 1
            end
        end
    end
    for _, key in ipairs({ "player", "target", "pet", "targettarget", "focus", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
        walk(_G["ForeverUnitFrames_" .. key], 0)
    end
    walk(_G.ForeverUnitFramesParty, 0)
    walk(_G.ForeverUnitFramesPartyPets, 0)
    -- Raid cell aura ownership is separate; leave the accepted raid design intact.
    return applied, refused
end

schedule = function()
    if queued or not enabled() then return end
    if InCombatLockdown() then return end -- Core retries on PLAYER_REGEN_ENABLED.
    queued = true
    local function run()
        queued = false
        if not enabled() or InCombatLockdown() then return end
        local ok, _, refused = pcall(scan, true)
        if not ok or refused > 0 then V:Report("auras", "pending", "Native aura widgets refused styling; retry after restrictions lift") end
    end
    if C_Timer and C_Timer.After then C_Timer.After(.1, run) else run() end
end

V:RegisterModule("auras", {
    label = "FUF aura presentation", defaultEnabled = true,
    description = "Styles owner-created buff, harmful and dispellable aura widgets without reading their aura data.",
    Apply = function()
        if InCombatLockdown() then return false, "Aura presentation waits until combat ends" end
        if not versionOK() or not _G.ForeverUnitFrames or not V.StyleAura then
            ready = false
            return false, "Audited FUF 0.79.1 and the shared aura presentation service are required"
        end
        if not V:IsModuleEnabled("unitframes") or not profileReady() then
            ready = false
            return false, "Apply the reviewed FUF profile and reload before styling its auras"
        end
        ready = true
        local applied, refused = scan(true)
        if not ticker and C_Timer and C_Timer.NewTicker then
            -- Discover newly allocated pool buttons without repeatedly styling
            -- existing ones or invoking any aura query API.
            ticker = C_Timer.NewTicker(1, function()
                if enabled() then
                    local ok = pcall(scan, false)
                    if not ok then V:Report("auras", "pending", "Native aura pool access is currently restricted") end
                end
            end)
        end
        if refused > 0 then return false, "Some native aura widgets are restricted; presentation retries when they become available" end
        return true, "FUF aura pools styled: " .. applied .. ". Buffs have no signal; harmful and known dispel groups use bottom signals."
    end,
    Disable = function()
        ready = false
        if ticker and ticker.Cancel then ticker:Cancel() end
        ticker = nil
        for button in pairs(seen) do
            if button.vasagoioSignal then pcall(button.vasagoioSignal.Hide, button.vasagoioSignal) end
        end
    end,
})

for _, event in ipairs({ "UNIT_AURA", "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    V:On(event, schedule)
end
