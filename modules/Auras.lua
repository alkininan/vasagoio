local addonName, V = ...
local OWNER, VERSION = "ForeverUnitFrames", "0.79.1"
local seen = setmetatable({}, { __mode = "k" })
local queued, ticker, ready = false, nil, false
local groups = { "buffs", "debuffs", "dispels" }
local unitKeys = { "player", "target", "pet", "targettarget", "focus", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5" }
local singleUnits = {}
for _, unit in ipairs(unitKeys) do singleUnits[unit] = true end
local dirtyUnits, dirtyButtons, allDirty = {}, setmetatable({}, { __mode = "k" }), false
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
local function sizeOf(button, method)
    if type(button[method]) ~= "function" then return end
    local ok, value = pcall(button[method], button)
    return ok and V:SafeNumber(value) or nil
end
local function decorate(button, group, force)
    if V:IsSecret(button) or type(button) ~= "table" or not button.icon or not button.cooldown or not button.count then return 0,0 end
    local record = seen[button]
    local width, height = sizeOf(button, "GetWidth"), sizeOf(button, "GetHeight")
    if record and not force and not record.stale and record.group == group
        and record.width == width and record.height == height then return 0,0 end
    record = record or {}; seen[button] = record
    record.group = group
    local ok = pcall(function()
        if button.IsForbidden and button:IsForbidden() then error("Restricted aura widget") end
        -- Classification comes from FUF's configured group, never aura payloads.
        -- Its dispels group is HARMFUL|RAID; debuffs is an actual harmful group.
        local signal = group == "dispels" and "dispel" or group == "debuffs" and "danger" or nil
        V:StyleAura(button, { signal = signal })
        if button.border then V:HideArtwork(button.border) end
        if not record.hooked and button.HookScript then
            button:HookScript("OnShow", function() schedule(nil, false, button) end)
            record.hooked = true
        end
    end)
    record.stale = not ok
    if ok then record.width, record.height = width, height end
    return ok and 1 or 0, ok and 0 or 1
end

local function scan(force, units)
    if not enabled() or InCombatLockdown() then return 0,0 end
    local visited, applied, refused = {}, 0, 0
    local function style(button, group)
        local a, r = decorate(button, group, force)
        applied, refused = applied+a, refused+r
    end
    local function walk(frame, depth, inheritedUnit)
        if V:IsSecret(frame) then return end
        if not frame or visited[frame] or depth > 4 then return end
        visited[frame] = true
        if frame.IsForbidden then
            local ok, forbidden = pcall(frame.IsForbidden, frame)
            if not ok or V:IsSecret(forbidden) or forbidden then return end
        end
        local unit = frame.unit
        if V:IsSecret(unit) then return end
        if type(unit) ~= "string" then unit = inheritedUnit end
        local selected = not units or (unit and units[unit])
        for _, key in ipairs(selected and groups or {}) do
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
                for i = 2, #children do walk(children[i], depth+1, unit) end
            else
                refused = refused + 1
            end
        end
    end
    for _, key in ipairs(unitKeys) do
        if not units or units[key] then walk(_G["ForeverUnitFrames_" .. key], 0, key) end
    end
    walk(_G.ForeverUnitFramesParty, 0)
    walk(_G.ForeverUnitFramesPartyPets, 0)
    -- Raid cell aura ownership is separate; leave the accepted raid design intact.
    return applied, refused
end

schedule = function(unit, forceAll, button)
    if not enabled() then return end
    if InCombatLockdown() then return end -- Core retries on PLAYER_REGEN_ENABLED.
    if forceAll then allDirty = true
    elseif button then
        dirtyButtons[button] = true
        if seen[button] then seen[button].stale = true end
    elseif unit then dirtyUnits[unit] = true end
    if queued then return end
    queued = true
    local function run()
        queued = false
        local units, buttons, force = dirtyUnits, dirtyButtons, allDirty
        dirtyUnits, dirtyButtons, allDirty = {}, setmetatable({}, { __mode = "k" }), false
        if not enabled() or InCombatLockdown() then return end
        local ok, _, refused = pcall(function()
            if force then return scan(true) end
            local applied, rejected = 0, 0
            if next(units) then applied, rejected = scan(false, units) end
            for changed in pairs(buttons) do
                local record = seen[changed]
                if record then
                    local a, r = decorate(changed, record.group, false)
                    applied, rejected = applied+a, rejected+r
                end
            end
            return applied, rejected
        end)
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
        dirtyUnits, dirtyButtons, allDirty = {}, setmetatable({}, { __mode = "k" }), false
        if ticker and ticker.Cancel then ticker:Cancel() end
        ticker = nil
        for button in pairs(seen) do
            if button.vasagoioSignal then pcall(button.vasagoioSignal.Hide, button.vasagoioSignal) end
        end
    end,
})

V:On("UNIT_AURA", function(_, unit)
    if V:IsSecret(unit) or type(unit) ~= "string" then return end
    -- Raid cells and nameplates are separate owners. Ignore their event traffic.
    if singleUnits[unit] or unit:match("^party[1-4]$") or unit:match("^partypet[1-4]$") then
        schedule(unit)
    end
end)
V:On("PLAYER_TARGET_CHANGED", function()
    schedule("target"); schedule("targettarget")
end)
-- A new roster or lifted restriction can rebuild/rebind existing owner pools.
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "ADDON_RESTRICTION_STATE_CHANGED", "PLAYER_REGEN_ENABLED" }) do
    V:On(event, function() schedule(nil, true) end)
end
