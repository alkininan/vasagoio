local addonName, V = ...

-- Shell adapters and the source-scoped interior service preserve native
-- window structure, control placement and secure attributes.
local W = { hooked = setmetatable({}, {__mode = "k"}) }
V.WindowSkin = W
local WHITE = V.Tokens.colors.text
local NINE = {"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center"}
local ART = {"Bg", "Background", "TitleBg", "TitleBackground", "TopTileStreaks",
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopBorder", "BottomBorder", "LeftBorder", "RightBorder"}
local originals = setmetatable({}, {__mode = "k"})

-- Native recovery actions share pooled StaticPopup slots with ordinary
-- confirmations. Keep the whole pool native: a slot styled for another dialog
-- may be reused for death/release/resurrection while secure UI owns its state.
-- Skinner's reviewed StaticPopups code also explicitly avoids OnShow hooks.
local nativeRecoveryRoots={"StaticPopup1","StaticPopup2","StaticPopup3","StaticPopup4","GhostFrame","DeathRecapFrame"}
function W:NativeRecoveryDialog(object)
    for _=1,32 do
        if V:IsSecret(object) or (type(object)~="table" and type(object)~="userdata") then return false end
        for _,name in ipairs(nativeRecoveryRoots) do
            if _G[name] and object==_G[name] then return true end
        end
        if type(object.GetParent)~="function" then return false end
        local ok,parent=pcall(object.GetParent,object)
        if not ok or V:IsSecret(parent) or parent==object then return false end
        object=parent
    end
    return false
end

function W:Enabled(id)
    if V.IsModuleEnabled then return V:IsModuleEnabled(id) end
    return V.db and V.db.enabled and V.db.modules[id] ~= false
end

function W:Available(object)
    if V:IsSecret(object) then return false end
    if not object then return false end
    if type(object) ~= "table" and type(object) ~= "userdata" then return false end
    if object.IsForbidden then
        local ok, forbidden = pcall(object.IsForbidden, object)
        if not ok or V:IsSecret(forbidden) or forbidden then return false end
    end
    return true
end

-- Visibility includes hidden parents; avoid scanning entire closed UI trees.
function W:Visible(frame)
    if not self:Available(frame) then return false end
    local query = type(frame.IsVisible) == "function" and frame.IsVisible or frame.IsShown
    if type(query) ~= "function" then return true end
    local ok, shown = pcall(query, frame)
    return ok and not V:IsSecret(shown) and shown == true
end

function W:Path(root, path)
    local object = root
    for key in path:gmatch("[^.]+") do
        if not self:Available(object) then return nil end
        object = object[key]
    end
    return object
end

function W:Hide(object, owner)
    if V.InteriorSkin and owner then return V.InteriorSkin:Hide(object,owner) end
    if self:Available(object) and object.SetAlpha then V:HideArtwork(object) end
end

-- Native rows keep their native type size, wrapping and click area. Font roles
-- are applied without increasing their dimensions or touching text contents.
function W:Text(text)
    if not self:Available(text) or not text.GetFont or not text.SetFont then return end
    local ok, _, size = pcall(text.GetFont, text)
    size = ok and V:SafeNumber(size)
    if not size then return end
    V:StyleText(text, "name", WHITE)
    local path, _, flags = V:Font("name")
    text:SetFont(path, size, flags)
end

function W:Shell(frame, extraArt, extraTitles, owner)
    if not self:Available(frame) or not frame.CreateTexture then return false end
    if self:NativeRecoveryDialog(frame) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if V.InteriorSkin then
        -- Shell and interior mutations must share the same original snapshot.
        -- A legacy pre-pass would capture already-themed fonts/backdrops and
        -- could undo a second, still-active presentation owner on disable.
        local I, id = V.InteriorSkin, owner or "nativeWindows"
        if not I:Panel(frame,"window",id) then return false end
        for _, key in ipairs(ART) do I:Hide(frame[key],id) end
        for _, path in ipairs(extraArt or {}) do I:Hide(self:Path(frame,path),id) end
        I:Text(frame.TitleText,"heading",false,id)
        I:Text(self:Path(frame,"TitleContainer.TitleText"),"heading",false,id)
        for _, path in ipairs(extraTitles or {}) do I:Text(self:Path(frame,path),"heading",false,id) end
        return true
    end
    for _, key in ipairs(ART) do self:Hide(frame[key]) end
    local nine = frame.NineSlice
    if self:Available(nine) then
        for _, key in ipairs(NINE) do self:Hide(nine[key]) end
    end
    -- An existing BackdropTemplate may otherwise cover our surface. Its
    -- textures remain installed; only cosmetic colors are made transparent.
    if frame.GetBackdropColor and frame.SetBackdropColor then
        if not originals[frame] then
            local color = {frame:GetBackdropColor()}
            local border = frame.GetBackdropBorderColor and {frame:GetBackdropBorderColor()}
            originals[frame] = {color = color, border = border, owner = owner or "nativeWindows"}
        end
        frame:SetBackdropColor(0, 0, 0, 0)
        if frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0, 0, 0, 0) end
    end
    for _, path in ipairs(extraArt or {}) do self:Hide(self:Path(frame, path)) end
    V:Surface(frame, V.Tokens and V.Tokens.alpha.window or .84, V.Tokens and V.Tokens.radius or 10)
    self:Text(frame.TitleText)
    self:Text(self:Path(frame, "TitleContainer.TitleText"))
    for _, path in ipairs(extraTitles or {}) do self:Text(self:Path(frame, path)) end
    return true
end

function W:Hook(frame, id)
    if self:NativeRecoveryDialog(frame) then return false end
    if V.InteriorSkin then return V.InteriorSkin:Watch(frame,{owner=id}) end
    if not self:Available(frame) or not frame.HookScript or self.hooked[frame] then return end
    self.hooked[frame] = true
    frame:HookScript("OnShow", function()
        if W:Enabled(id) then V:Refresh("window shown", id) end
    end)
end

function W:RestoreBackdrops(owner)
    if InCombatLockdown and InCombatLockdown() then return end
    if V.InteriorSkin then return V.InteriorSkin:Restore(owner) end
    for frame, record in pairs(originals) do
        if record.owner == owner and self:Available(frame) then
            frame:SetBackdropColor(unpack(record.color))
            if record.border and frame.SetBackdropBorderColor then
                frame:SetBackdropBorderColor(unpack(record.border))
            end
        end
    end
end

local WINDOWS = {
    {"CharacterFrame", {"LeftPaneHost.StoneBg", "RightPaneHost.StoneBg"}},
    {"InspectFrame"}, {"PaperDollFrame"}, {"ReputationFrame"}, {"TokenFrame"},
    {"PlayerSpellsFrame"}, {"SpellBookFrame"}, {"PlayerTalentFrame"},
    {"QuestLogFrame"}, {"QuestFrame"}, {"GossipFrame"}, {"MerchantFrame"},
    {"TradeFrame"}, {"MailFrame"}, {"SendMailFrame"}, {"OpenMailFrame"},
    {"ClassTrainerFrame"}, {"TradeSkillFrame"}, {"CraftFrame"}, {"ProfessionsFrame"},
    {"AuctionFrame"}, {"AuctionHouseFrame"}, {"BankFrame"}, {"PetStableFrame"},
    {"FriendsFrame"}, {"GuildFrame"}, {"CommunitiesFrame"}, {"ChannelFrame"},
    {"PVPUIFrame"}, {"PVPFrame"}, {"LFGParentFrame"}, {"LFDParentFrame"},
    {"RaidInfoFrame"}, {"CalendarFrame"}, {"AchievementFrame"},
    {"WorldMapFrame"}, {"GameMenuFrame"}, {"SettingsPanel"}, {"InterfaceOptionsFrame"},
    {"KeyBindingFrame"}, {"MacroFrame"}, {"HelpFrame", {"BrowserInset.Bg"}},
    {"ReportFrame"}, {"TicketStatusFrameButton"}, {"LegacySystemFrame"},
    {"DressUpFrame"}, {"ItemRefTooltip"}, {"GameTooltip"},
    {"StaticPopup1"}, {"StaticPopup2"}, {"StaticPopup3"}, {"StaticPopup4"},
}
W.NativeRoots = WINDOWS

local function hasSkinner()
    local s = _G.Skinner
    return s and s.db and s.db.profile and (not s.IsEnabled or s:IsEnabled())
end

local function skinnerPaletteConfigured()
    local profile = _G.Skinner.db.profile
    local backdrop = profile.Backdrop
    if type(backdrop) ~= "table" or profile.FrameBorders ~= false then return false end
    for i, key in ipairs({"r", "g", "b"}) do
        local value = V:SafeNumber(backdrop[key])
        if not value or math.abs(value - V.Tokens.colors.panel[i]) > .0001 then return false end
    end
    local alpha = V:SafeNumber(backdrop.a)
    return alpha and math.abs(alpha - V.Tokens.alpha.window) < .0001
end

V:RegisterModule("nativeWindows", {
    label = "Native window skins",
    description = "Original layouts with source-scoped interior controls, typography and rounded surfaces.",
    defaultEnabled = true,
    Apply = function()
        if InCombatLockdown and InCombatLockdown() then return false, "Waiting for combat to end" end
        if V.NativeInteriors and V.InteriorSkin then
            local result = V.NativeInteriors:Apply()
            local detail = tostring(result.roots or 0) .. " native roots; " .. tostring(result.controls or 0) ..
                " controls and " .. tostring(result.texts or 0) .. " text regions themed without native layout changes."
            if result.limitReached or (result.deferred or 0) > 0 or (result.skipped or 0) > 0 then
                return false, detail .. " Some widgets could not be inspected, were restricted or exceeded the traversal budget; retry out of combat.", "pending"
            end
            if hasSkinner() and not skinnerPaletteConfigured() then
                return false, detail .. " Review setup to configure Skinner's native palette, then reload.", "pending"
            end
            return true, detail .. " Death/recovery dialogs remain native; their functional validation is manual. Embedded Help web content and front-end screens stay outside addon control. Native validation is pending."
        end
        if hasSkinner() then
            if not skinnerPaletteConfigured() then
                return false, "Skinner owns native skins; its vasagoio palette is not configured. Review /vasagoio setup, then reload. Unreviewed versions require manual configuration.", "pending"
            end
            return true, "Skinner owns native skins with the configured neutral palette. Native layouts retained; embedded Help webpage excluded."
        end
        local count = 0
        for _, entry in ipairs(WINDOWS) do
            local frame = _G[entry[1]]
            if W:Shell(frame, entry[2]) then count = count + 1; W:Hook(frame, "nativeWindows") end
        end
        local stats = _G.CharacterStatsPaneScrollBox
        if W:Available(stats) then W:Hide(stats.ClassBackground) end
        return true, tostring(count) .. " native shells present; load-on-demand roots watched. Inner controls and embedded Help HTML are not fully reskinned."
    end,
    Disable = function()
        if V.NativeInteriors then V.NativeInteriors:Disable() end
        W:RestoreBackdrops("nativeWindows")
    end,
})

V:On("ADDON_LOADED", function() if W:Enabled("nativeWindows") then V:Refresh("native window addon loaded", "nativeWindows") end end)

-- Schema-reviewed integration: no vendor code is bundled and no private
-- Skinner methods are called. AceDB profile leaves are snapshotted by core.
local REVIEWED_SKINNER = "beta12.70938.1"
V:RegisterProfileAdapter("skinner", {
    label = "Skinner native windows",
    addon = "Skinner",
    Prepare = function()
        local skinner = _G.Skinner
        if not hasSkinner() then return nil, "Skinner is not loaded; native shell fallback remains available" end
        local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
        if not metadata or metadata("Skinner", "Version") ~= REVIEWED_SKINNER then
            return nil, "Skinner version is not schema-reviewed; configure it manually or use the native shell fallback"
        end
        local db = skinner.db
        local name = db.GetCurrentProfile and db:GetCurrentProfile()
        local raw = _G.SkinnerDB
        if type(name) ~= "string" or type(raw) ~= "table" or type(raw.profiles) ~= "table" or type(raw.profiles[name]) ~= "table" then
            return nil, "Skinner AceDB profile schema unavailable"
        end
        local profile, changes = db.profile, {}
        local prefix = {"SkinnerDB", "profiles", name}
        local function set(target, key, value, relative)
            if target[key] == nil or type(target[key]) ~= type(value) then return end
            local path = {}
            for _, part in ipairs(prefix) do path[#path+1] = part end
            for _, part in ipairs(relative or {}) do path[#path+1] = part end
            local field = relative and #relative > 0 and table.concat(relative, ".") .. "." .. key or key
            changes[#changes+1] = {table = target, key = key, value = value, path = path, label = "Skinner " .. field}
        end
        local function scalar(key, value) set(profile, key, value) end
        local function nested(key, sub, value)
            if type(profile[key]) == "table" then set(profile[key], sub, value, {key}) end
        end
        scalar("FrameBorders", false)
        scalar("ClassClrBd", false); scalar("ClassClrBg", false); scalar("ClassClrGr", false)
        scalar("BgUseTex", false); scalar("DisableAllNPC", false); scalar("DisableAllP", false); scalar("DisableAllUI", false)
        -- Third-party windows/HUD stay with their owners; no global Skinner takeover.
        scalar("DisableAllAS", true)
        scalar("ChatButtons", false); scalar("ChatFrames", false); scalar("ChatTabs", false)
        scalar("StaticPopups", false); scalar("GhostFrame", false); scalar("DeathRecap", false)
        nested("Gradient", "enable", false)
        for _, key in ipairs({"CastingBar", "CompactFrames", "MainMenuBar", "Minimap", "MinimapButtons", "ChatEditBox", "ChatBubbles", "ObjectiveTracker"}) do nested(key, "skin", false) end
        for _, key in ipairs({"CharacterFrames", "PlayerSpells", "MailFrame", "HelpFrame", "Settings", "MerchantFrame", "GossipFrame"}) do scalar(key, true) end
        local function rgba(color, alpha) return {color[1], color[2], color[3], alpha or 1} end
        local colors = {
            Backdrop = rgba(V.Tokens.colors.panel, V.Tokens.alpha.window), BackdropBorder = {0, 0, 0, 0},
            HeadText = rgba(WHITE), BodyText = rgba(WHITE), IgnoredText = rgba(V.Tokens.colors.muted),
            DisabledText = rgba(V.Tokens.colors.muted, V.Tokens.controls.disabledAlpha),
            TooltipBorder = {0, 0, 0, 0}, SliderBorder = {0, 0, 0, 0},
        }
        for key, color in pairs(colors) do
            for i, channel in ipairs({"r", "g", "b", "a"}) do nested(key, channel, color[i]) end
        end
        -- UnitFrames is a separately namespaced Skinner module. Only known
        -- toggles are disabled; the selected HUD owner retains control.
        local ns = db.GetNamespace and db:GetNamespace("UnitFrames", true)
        if ns and ns.profile and raw.namespaces and raw.namespaces.UnitFrames then
            prefix = {"SkinnerDB", "namespaces", "UnitFrames", "profiles", name}
            for _, key in ipairs({"arena", "focus", "party", "pet", "petlvl", "player", "target"}) do set(ns.profile, key, false) end
        end
        if #changes == 0 then return nil, "Skinner profile fields did not match the reviewed schema" end
        return {changes = changes, detail = "Neutral black native skins, borderless surfaces, white text; HUD and third-party skins excluded. Reviewed decorative Skinner surfaces receive vasagoio corners through the interior adapter. Reload required."}
    end,
    AfterApply = function() V:Print("Skinner palette saved. Reload the UI to rebuild its cached colors; profile rollback remains available.") end,
})
