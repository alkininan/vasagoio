local addonName, V = ...
local W = V.WindowSkin
local bagListenerInstalled, ticker
local discovered = setmetatable({}, {__mode = "k"})

-- Named roots verified against these releases. An upgrade keeps all addon
-- functionality and suspends only this optional cosmetic adapter until reviewed.
local ROOTS = {
    {addon = "MRT", version = "5335", name = "MRTOptionsFrame", titles = {"HeaderText"}},
    {addon = "Auctionator", version = "352", name = "AuctionatorFullScanFrame"},
    {addon = "Auctionator", version = "352", name = "AuctionatorPageStatusDialogFrame"},
    {addon = "Auctionator", version = "352", name = "AuctionatorThrottlingTimeoutDialogFrame"},
    {addon = "TalentsForeverBook", version = "0.38.28.20261116", name = "TalentsForeverBookFrame",
        art = {"page", "vignette", "titleRule"}, titles = {"tfTitle", "titleText"}, cover = true},
    {addon = "TalentsForeverBook", version = "0.38.28.20261116", name = "TalentsForeverBookTrainer",
        art = {"bg", "top", "page", "vignette"}, cover = true},
    {addon = "TalentsForeverBook", version = "0.38.28.20261116", name = "TalentsForeverBookToast",
        art = {"page", "vignette"}, cover = true},
}

local function versionMatches(entry)
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return metadata and metadata(entry.addon, "Version") == entry.version
end

local function applyRoot(entry)
    local frame = _G[entry.name]
    if not versionMatches(entry) or not W:Available(frame) then return false end
    if not W:Shell(frame, entry.art, entry.titles, "addonWindows") then return false end
    if entry.cover and type(frame.cover) == "table" then
        for i = 1, 8 do W:Hide(frame.cover[i]) end
    end
    W:Hook(frame, "addonWindows")
    discovered[frame] = true
    return true
end

local function styleBagRegion(details)
    if not W:Enabled("addonWindows") or type(details) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then V:Refresh("bag skin deferred in combat"); return end
    local frame, kind = details.region, details.regionType
    if not W:Available(frame) then return end
    if kind == "ButtonFrame" or kind == "Dialog" then
        W:Shell(frame, nil, nil, "addonWindows")
        W:Hook(frame, "addonWindows")
    elseif kind == "ItemButton" then
        -- Keep item texture, rarity/quest/search/desaturation markers, tooltip,
        -- inventory click actions and owner cooldowns entirely intact.
        if W:Available(frame.Count) then V:StyleText(frame.Count, "count") end
    end
end

local function baganator()
    local api = _G.Baganator and Baganator.API and Baganator.API.Skins
    if not api or type(api.RegisterListener) ~= "function" or type(api.GetAllFrames) ~= "function" then
        return false
    end
    if not bagListenerInstalled then
        api.RegisterListener(styleBagRegion)
        bagListenerInstalled = true
    end
    local all = api.GetAllFrames()
    if type(all) == "table" then
        for _, details in ipairs(all) do styleBagRegion(details) end
    end
    return true
end

local function discoverLazyRoots()
    if not W:Enabled("addonWindows") or (InCombatLockdown and InCombatLockdown()) then return end
    for _, entry in ipairs(ROOTS) do
        local frame = _G[entry.name]
        if W:Available(frame) and not discovered[frame] and versionMatches(entry) then
            -- Discovery does not open a window. The named frame may be created
            -- on the owner's first user click, after its ADDON_LOADED event.
            V:Refresh("selected addon window created")
            return
        end
    end
end

V:RegisterModule("addonWindows", {
    label = "Selected addon window skins",
    description = "Baganator skin API and reviewed named outer windows; functionality preserved.",
    defaultEnabled = true,
    Apply = function()
        if InCombatLockdown and InCombatLockdown() then return false, "Waiting for combat to end" end
        local count = 0
        for _, entry in ipairs(ROOTS) do if applyRoot(entry) then count = count + 1 end end
        local bags = baganator()
        if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(2, discoverLazyRoots) end
        if count == 0 and not bags then
            return false, "No reviewed addon shell or Baganator skin API is available yet. Listed lazy window roots are watched; unreviewed versions remain unchanged.", "pending"
        end
        return true, tostring(count) .. " reviewed addon shells present; Baganator API " .. (bags and "connected" or "unavailable") ..
            ". Talents inner art, MRT inner tools, Gargul and other addon internals remain owner-styled; OpenMap uses native WorldMap shell."
    end,
    Disable = function()
        if ticker then ticker:Cancel(); ticker = nil end
        W:RestoreBackdrops("addonWindows")
        -- Baganator has no public unregister-listener API; the callback becomes
        -- a no-op when this module is disabled and disappears on UI reload.
    end,
})

V:On("ADDON_LOADED", function()
    if W:Enabled("addonWindows") then V:Refresh("selected addon loaded") end
end)

V.AddonWindowCoverage = {
    baganator = "Public skin API: outer ButtonFrame/Dialog shells and count typography; item/rarity/search behavior retained",
    talentsForever = "Reviewed named outer shells only; all inner talent nodes, planning and training features retained",
    mrt = "Reviewed options shell only; raid-leading tools retained and their internals unchanged",
    auctionator = "Reviewed named scan/status dialog shells; AuctionFrame/House outer shell belongs to native adapter",
    openMap = "Native WorldMap outer shell only; map canvas, markers and OpenMap behavior retained",
    gargul = "No reviewed skin API or frame contract available; functionality retained, appearance pending adapter",
    otherAddons = "Not traversed or globally restyled",
}
