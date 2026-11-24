local addonName, V = ...
local W = V.WindowSkin
local bagListenerInstalled, ticker
local discovered = setmetatable({}, {__mode = "k"})
local TALENTS_VERSIONS = { ["0.38.28.20261116"] = true, ["0.38.33.20261123"] = true }

-- Named roots verified against these releases. An upgrade keeps all addon
-- functionality and suspends only this optional cosmetic adapter until reviewed.
local ROOTS = {
    {addon = "MRT", version = "5335", name = "MRTOptionsFrame", titles = {"HeaderText"}},
    {addon = "Auctionator", version = "352", name = "AuctionatorFullScanFrame"},
    {addon = "Auctionator", version = "352", name = "AuctionatorPageStatusDialogFrame"},
    {addon = "Auctionator", version = "352", name = "AuctionatorThrottlingTimeoutDialogFrame"},
    {addon = "TalentsForeverBook", version = TALENTS_VERSIONS, name = "TalentsForeverBookFrame",
        art = {"page", "vignette", "titleRule"}, titles = {"tfTitle", "titleText"}, cover = true},
    {addon = "TalentsForeverBook", version = TALENTS_VERSIONS, name = "TalentsForeverBookTrainer",
        art = {"bg", "top", "page", "vignette"}, cover = true},
    {addon = "TalentsForeverBook", version = TALENTS_VERSIONS, name = "TalentsForeverBookToast",
        art = {"page", "vignette"}, cover = true},
}
for _, name in ipairs({"AuctionatorShoppingFrame", "AuctionatorConfigFrame", "AuctionatorCancellingFrame",
    "AuctionatorSellingFrame", "AuctionatorBuyFrame"}) do
    ROOTS[#ROOTS + 1] = {addon = "Auctionator", version = "352", name = name}
end
for _, name in ipairs({"BasicOptions", "Tooltips", "ShoppingAlt", "Selling", "SellingAllItems",
    "SellingShortcuts", "Cancelling", "Profile", "Advanced"}) do
    ROOTS[#ROOTS + 1] = {addon = "Auctionator", version = "352", name = "AuctionatorConfig" .. name .. "Frame"}
end

local function versionMatches(entry)
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = metadata and metadata(entry.addon, "Version")
    if V:IsSecret(version) or type(version) ~= "string" then return false end
    if type(entry.version) == "table" then return entry.version[version] == true end
    return version == entry.version
end

local function applyRoot(entry)
    local frame = _G[entry.name]
    if not versionMatches(entry) or not W:Available(frame) then return false end
    if not W:Shell(frame, entry.art, entry.titles, "addonWindows") then return false end
    if entry.cover and type(frame.cover) == "table" then
        for i = 1, 8 do W:Hide(frame.cover[i],"addonWindows") end
    end
    if V.AddonInteriors then V.AddonInteriors:Apply(frame, entry.addon) end
    W:Hook(frame, "addonWindows")
    discovered[frame] = true
    return true
end

local function styleBagRegion(details)
    if not W:Enabled("addonWindows") or type(details) ~= "table" then return end
    if InCombatLockdown and InCombatLockdown() then V:Refresh("bag skin deferred in combat"); return end
    local frame, kind = details.region, details.regionType
    if not W:Available(frame) then return end
    if V.AddonInteriors and V.InteriorSkin then V.AddonInteriors:Bag(details); return end
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
    description = "Reviewed addon windows, controls and interior panels; owner layouts and functionality preserved.",
    defaultEnabled = true,
    Apply = function()
        if InCombatLockdown and InCombatLockdown() then return false, "Waiting for combat to end" end
        local count = 0
        for _, entry in ipairs(ROOTS) do if applyRoot(entry) then count = count + 1 end end
        local bags = baganator()
        local interiors = V.AddonInteriors and V.AddonInteriors:Discover() or 0
        if not ticker and C_Timer and C_Timer.NewTicker then ticker = C_Timer.NewTicker(2, discoverLazyRoots) end
        if count == 0 and interiors == 0 and not bags then
            return false, "No reviewed addon windows or Baganator skin API are available yet. Lazy owner roots are watched; unreviewed versions retain their own appearance.", "pending"
        end
        return true, tostring(count) .. " reviewed named windows and " .. tostring(interiors) .. " owner-registered interiors; Baganator API " ..
            (bags and "connected (19 region types)" or "unavailable") .. ". Controls, panels and typography use vasagoio; owner layouts and semantic art retained. Native validation is pending."
    end,
    Disable = function()
        if ticker then ticker:Cancel(); ticker = nil end
        if V.AddonInteriors then V.AddonInteriors:Disable() end
        W:RestoreBackdrops("addonWindows")
        -- Baganator has no public unregister-listener API; the callback becomes
        -- a no-op when this module is disabled and disappears on UI reload.
    end,
})

V:On("ADDON_LOADED", function()
    if W:Enabled("addonWindows") then V:Refresh("selected addon loaded") end
end)

V.AddonWindowCoverage = {
    baganator = "All 19 public skin-region types: panels, buttons, tabs, inputs, sliders, scrollbars and typography; item/rarity/search/cooldown state retained",
    talentsForever = "Reviewed book/trainer/toast, leveling-order drawer and plan card, tree pane chrome, plate controls, tabs, inputs and typography; talent artwork, ranks, paths, next-point/completed and saved/loaded state retained",
    mrt = "Reviewed GMRT options root, lazy tool pages and child dialogs; controls and typography themed, raid-leading behavior retained",
    auctionator = "Reviewed shopping/selling/cancelling/config panes, buy/scan/status dialogs and nine config pages; prices and item semantics retained",
    openMap = "Native WorldMap adapter; canvas, markers and OpenMap behavior retained",
    gargul = "8.1.0 and 8.1.1 reviewed Interface.set/createWindow and UI.components contracts; owner window controls and text, including lazy loot/roll/GDKP/settings dialogs",
    otherAddons = "Only reviewed owner roots and public registries are traversed; no global frame sweep",
}
