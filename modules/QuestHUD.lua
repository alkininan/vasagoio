local addonName, V = ...

-- RXP v4.11.40 saves live frame points on PLAYER_LOGOUT. Updating only its
-- SavedVariables would therefore be overwritten during the requested reload.
-- Keep reviewed saved anchors and the corresponding live frame in sync, without
-- changing guide sizes, active steps, native objectives or automation settings.
local OWNER, ADAPTER = "questHUD", "restedxp"
local names = { "RXPFrame", "RXPV2GuideWindow" }
local knownNames = { RXPFrame = true, RXPV2GuideWindow = true }
local anchors = { TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true,
    RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true }

local function reviewed()
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = metadata and metadata("RXPGuides", "Version")
    return not V:IsSecret(version) and version == "v4.11.40"
end

local function owner()
    if not LibStub then return end
    local ok, ace = pcall(function() return LibStub("AceAddon-3.0", true) end)
    if not ok or not ace or type(ace.GetAddon) ~= "function" then return end
    local found, rxp = pcall(ace.GetAddon, ace, "RXPGuides", true)
    if not found or not rxp or type(rxp.GetModule) ~= "function" then return end
    local loaded, settings = pcall(rxp.GetModule, rxp, "Settings", true)
    if not loaded or not settings or type(settings.GetSettingsDB) ~= "function" then return end
    local got, key = pcall(settings.GetSettingsDB, settings)
    if not got or V:IsSecret(key) or type(key) ~= "string" then return end
    local profiles = _G.RXPSettings and _G.RXPSettings.profiles
    local profile = type(profiles) == "table" and rawget(profiles, key)
    if type(profile) ~= "table" or profile ~= settings.profile or
        type(profile.framePositions) ~= "table" or type(rxp.enabledFrames) ~= "table" then return end
    return rxp, profile, key
end

local function usable(frame)
    if V:IsSecret(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata") then return false end
    if type(frame.ClearAllPoints) ~= "function" or type(frame.SetPoint) ~= "function" or
        type(frame.GetEffectiveScale) ~= "function" or type(frame.GetNumPoints) ~= "function" or
        type(frame.GetPoint) ~= "function" then return false end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or V:IsSecret(forbidden) or forbidden then return false end
    end
    return true
end

local function validPoints(points)
    if V:IsSecret(points) or type(points) ~= "table" or #points == 0 or #points > 9 then return false end
    for _, point in ipairs(points) do
        if V:IsSecret(point) or type(point) ~= "table" then return false end
        local anchor, relative, relativePoint, x, y = point[1], point[2], point[3], point[4], point[5]
        if V:IsSecret(anchor) or V:IsSecret(relative) or V:IsSecret(relativePoint) or
            not anchors[anchor] or not anchors[relativePoint] or not V:SafeNumber(x) or not V:SafeNumber(y) then return false end
        if relative ~= nil and (type(relative) ~= "string" or not usable(_G[relative])) then return false end
    end
    return true
end

local function capturePoints(frame)
    local count = V:SafeNumber(frame:GetNumPoints())
    assert(count and count >= 1 and count <= 9 and count % 1 == 0, "RXP live guide anchors are unavailable")
    local points = {}
    for i = 1, count do
        local anchor, relative, relativePoint, x, y = frame:GetPoint(i)
        assert(not V:IsSecret(anchor) and not V:IsSecret(relative) and not V:IsSecret(relativePoint) and
            anchors[anchor] and anchors[relativePoint] and V:SafeNumber(x) and V:SafeNumber(y) and
            (relative == nil or usable(relative)), "RXP live guide anchor is restricted or unsupported")
        points[i] = {anchor, relative, relativePoint, x, y}
    end
    return points
end

local function writeLivePoints(frame, points)
    frame:ClearAllPoints()
    for _, point in ipairs(points) do frame:SetPoint(point[1], point[2], point[3], point[4], point[5]) end
end

local function synchronize(targets)
    assert(not InCombatLockdown(), "RXP guide anchors cannot change in combat")
    -- Capture every target before the first write. RXP saves live points on
    -- logout, so a partial ClearAllPoints/SetPoint failure must not persist an
    -- empty guide anchor or leave an earlier guide at the proposed position.
    for _, target in ipairs(targets) do
        assert(usable(target.frame) and validPoints(target.points), "RXP guide anchor is not writable")
        target.before = capturePoints(target.frame)
        target.after = {}
        for i, point in ipairs(target.points) do
            target.after[i] = {point[1], point[2] and _G[point[2]] or UIParent, point[3], point[4], point[5]}
        end
    end
    local touched = 0
    local ok, failure = pcall(function()
        for i, target in ipairs(targets) do
            touched = i
            writeLivePoints(target.frame, target.after)
        end
    end)
    if not ok then
        local recovered = true
        for i = touched, 1, -1 do
            if not pcall(writeLivePoints, targets[i].frame, targets[i].before) then recovered = false end
        end
        if not recovered then error("RXP live anchor recovery failed; reload and inspect the guide") end
        error(failure)
    end
end

local function isActiveChange(change, profile, key)
    local path = change.path
    return type(path) == "table" and #path == 4 and path[1] == "RXPSettings" and
        path[2] == "profiles" and path[3] == key and path[4] == "framePositions" and
        knownNames[change.key] and _G.RXPSettings.profiles[key].framePositions == profile.framePositions
end

V:RegisterProfileAdapter(ADAPTER, {
    label = "RestedXP: separate guide and objective columns", addon = "RXPGuides", module = OWNER,
    Prepare = function()
        if not reviewed() then return nil, "RestedXP v4.11.40 is required for the reviewed guide anchor" end
        local rxp, profile, key = owner()
        if not rxp then return nil, "RestedXP's active Settings profile must be initialized; log in and reload once" end
        if InCombatLockdown() then return nil, "Leave combat before changing guide anchors" end
        local plan = { changes = {}, detail = "Move initialized RestedXP guide windows one column left: right inset 384, top inset 64 reference pixels. Preserve guide sizes, contents, active targets/items, native objectives and automation. Apply synchronizes live anchors before reload; Restore profiles restores saved and live anchors." }
        local uiScale = V:SafeNumber(UIParent:GetEffectiveScale())
        if not uiScale or uiScale <= 0 then return nil, "UI scale is unavailable" end
        for _, name in ipairs(names) do
            local frame = rxp.enabledFrames[name]
            if frame then
                if not usable(frame) or frame.savePosition == false or not validPoints(profile.framePositions[name]) then
                    return nil, "RestedXP guide anchors are not initialized or supported; reload once before setup"
                end
                if not pcall(capturePoints, frame) then return nil, "RestedXP live guide anchors are not ready; reload once before setup" end
                local scale = V:SafeNumber(frame:GetEffectiveScale())
                if not scale or scale <= 0 then return nil, "RestedXP guide scale is unavailable" end
                local ratio = uiScale / scale
                plan.changes[#plan.changes+1] = {
                    table = profile.framePositions,
                    path = {"RXPSettings", "profiles", key, "framePositions"}, key = name,
                    value = {{"TOPRIGHT", "UIParent", "TOPRIGHT", -V:Pixel(384)*ratio, -V:Pixel(64)*ratio}},
                    label = name .. " separate quest column",
                }
            end
        end
        if #plan.changes == 0 then return nil, "RestedXP guide window is not initialized" end
        return plan
    end,
    AfterApply = function(_, changes)
        local rxp, profile, key = owner()
        assert(rxp, "RestedXP active profile is unavailable")
        local targets = {}
        if changes then
            -- Failed restoration recovery supplies the snapshot's exact paths.
            -- Do not reconcile a different active profile to unrelated data.
            for _, change in ipairs(changes) do
                if isActiveChange(change, profile, key) then
                    assert(reviewed(), "RestedXP version changed after review")
                    targets[#targets+1] = {frame=rxp.enabledFrames[change.key], points=profile.framePositions[change.key]}
                end
            end
        else
            assert(reviewed(), "RestedXP version changed after review")
            for _, name in ipairs(names) do
                local frame = rxp.enabledFrames[name]
                if frame then targets[#targets+1] = {frame=frame, points=profile.framePositions[name]} end
            end
        end
        synchronize(targets)
    end,
    ValidateRestore = function(_, changes)
        local rxp, profile, key = owner()
        -- The restored path may belong to a different, currently inactive
        -- profile. RXP's logout callback cannot overwrite that profile.
        if not rxp then return false, "Load RestedXP's Settings profile before restoring its guide anchor" end
        for _, change in ipairs(changes) do
            if isActiveChange(change, profile, key) then
                local frame = rxp.enabledFrames[change.key]
                if not reviewed() or InCombatLockdown() or not usable(frame) or frame.savePosition == false or not validPoints(change.before) then
                    return false, "The active RestedXP guide anchor cannot be safely restored; use the reviewed version out of combat"
                end
                if not pcall(capturePoints, frame) then return false, "The active RestedXP live anchor cannot be captured for safe restoration" end
            end
        end
        return true
    end,
    AfterRestore = function(_, changes)
        local rxp, profile, key = owner()
        if not rxp then return end
        local targets = {}
        for _, change in ipairs(changes) do
            if isActiveChange(change, profile, key) then
                targets[#targets+1] = {frame=rxp.enabledFrames[change.key], points=profile.framePositions[change.key]}
            end
        end
        synchronize(targets)
    end,
})

V:RegisterModule(OWNER, {
    label = "Quest HUD separation", defaultEnabled = true,
    description = "Reviewed RestedXP guide placement; native objective tracker and guide contents are preserved.",
    Apply = function()
        if not reviewed() then return false, "RestedXP v4.11.40 is not loaded; its guide placement stays unchanged" end
        return true, "Guide position changes only through reviewed setup; Restore profiles undoes them. No polling or automatic movement."
    end,
})
