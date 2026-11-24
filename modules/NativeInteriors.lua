local _, V = ...
local W = V.WindowSkin
local N = {}
V.NativeInteriors = N
local OWNER = "nativeWindows"
local watched, rowCallbacks = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
local selections = setmetatable({}, {__mode = "k"})
local selectionHooks = {}
local ticker
local visibility = setmetatable({}, {__mode = "k"})
local reconcileAfterCombat

-- Exact decorative atlases from the reviewed client XML. No substring or
-- color-based removal: item icons, quest markers, talent states and model
-- content are never classified as decoration by this list.
local decorativeAtlases = {
    ["UI-Character-Info-General-BG"] = true,
    ["UI-Character-Info-Stat-BG"] = true,
    ["UI-Character-Info-Stat-StoneBG3"] = true,
    ["UI-Character-Info-Title"] = true,
    ["UI-Character-Info-Line-Bounce"] = true,
    ["UI-Character-Info-Line-Bounce2"] = true,
    ["UI-Character-Info-ItemLevel-Bounce"] = true,
    ["UI-Character-Info-ScrollLine"] = true,
    ["UI-Character-Info-OutfitCard"] = true,
    ["UI-Character-Info-OutfitCard-Hover"] = true,
    ["UI-Character-Info-StatTab"] = true,
    ["common-framedivider"] = true,
    ["common-insideframe"] = true,
    ["Profession-Background-Template2"] = true,
    ["spellbook-divider"] = true,
}

-- Only named background surfaces are removed. These paths are source-backed
-- interior art, not an attempt to strip every Texture under a native window.
local interiors = {
    CharacterFrame = {
        art = {"LeftPaneHost.StoneBg", "RightPaneHost.StoneBg"},
        panels = {"RightPaneHost"},
    },
    PaperDollFrame = {
        art = {"TopBackgroundStripHost.TopBackgroundStrip", "TopBackgroundStripHost.TopBackgroundStripBottomEdge",
            "TitleManagerPane.Border", "EquipmentManagerPane.Border",
            "CharacterModelScene.BackgroundTopLeft", "CharacterModelScene.BackgroundTopRight",
            "CharacterModelScene.BackgroundBotLeft", "CharacterModelScene.BackgroundBotRight",
            "CharacterModelScene.BackgroundOverlay"},
        panels = {"TitleManagerPane", "EquipmentManagerPane"},
    },
    CharacterStatsPane = {
        art = {"ClassBackground", "ItemLevelFrame.Background", "ItemLevelCategory.Background",
            "AttributesCategory.Background", "EnhancementsCategory.Background"},
    },
    CharacterStatsPaneScrollBox = {art = {"ClassBackground", "Border"}},
    CharacterStatsPanePetScrollBox = {art = {"Border"}},
    PlayerSpellsFrame = {
        panels = {"TalentsFrame", "SpellBookFrame"},
        art = {"TalentsFrame.Background", "SpellBookFrame.Background"},
    },
    GossipFrame = {art = {"GreetingPanel.Background"}, panels = {"GreetingPanel"}},
    SettingsPanel = {panels = {"CategoryList", "Container"}},
    ProfessionsFrame = {panels = {"CraftingPage", "BookPage"}},
    HelpFrame = {art = {"Browser.BrowserInset.Bg"}},
    InspectFrame = {panels = {"Inset", "InsetRight"}},
    ["PaperDollFrame.CharacterModelScene.ControlFrame"] = {},
}

-- Older native layouts expose these as named globals instead of parent keys.
-- Reading references does not inspect any mail/quest text or inventory data.
local globalArt = {
    "InboxFrameBg", "SendStationeryBackgroundLeft", "SendStationeryBackgroundRight",
    "OpenStationeryBackgroundLeft", "OpenStationeryBackgroundRight",
    "SendMailHorizontalBarLeft", "SendMailHorizontalBarLeft2", "QuestGreetingFrameHorizontalBreak",
}
local narrativeText = {
    "QuestInfoTitleHeader", "QuestInfoDescriptionHeader", "QuestInfoDescriptionText",
    "QuestInfoObjectivesHeader", "QuestInfoObjectivesText", "QuestInfoRewardsFrameReceiveText",
    "QuestInfoRewardsFrameChooseText", "QuestInfoRewardText", "QuestProgressTitleText",
    "QuestProgressText", "QuestProgressRequiredItemsText", "GreetingText", "CurrentQuestsText",
    "AvailableQuestsText", "GossipGreetingText", "OpenMailBodyText", "SendMailBodyEditBox",
}
local statScrollBoxes = {"CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox"}

local function running()
    return W:Enabled(OWNER) and not V.profileReloadPending
end

local function get(path)
    if type(path) ~= "string" then return end
    local value = _G
    for key in path:gmatch("[^.]+") do
        if V:IsSecret(value) or (type(value) ~= "table" and type(value) ~= "userdata") then return end
        value = value[key]
    end
    return W:Available(value) and value or nil
end

local function parentOf(frame)
    if not W:Available(frame) or not frame.GetParent then return end
    local ok, parent = pcall(frame.GetParent, frame)
    if ok and W:Available(parent) then return parent end
end

local function descendant(frame, ancestor)
    for _ = 1, 32 do
        frame = parentOf(frame)
        if not frame then return false end
        if frame == ancestor then return true end
    end
    return false
end

local TAB_ART = {"Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
    "LeftHighlight", "MiddleHighlight", "RightHighlight", "SquareBackground",
    "SquareBackgroundActive", "SquareBackgroundActiveGlow"}

local function safeShown(object)
    if not W:Available(object) or type(object.IsShown) ~= "function" then return end
    local ok, value = pcall(object.IsShown, object)
    if ok and not V:IsSecret(value) and type(value) == "boolean" then return value end
end

local function safeMethod(object, method)
    if not W:Available(object) or type(object[method]) ~= "function" then return end
    local ok, value = pcall(object[method], object)
    if ok and not V:IsSecret(value) then return value end
end

local function paintSelection(frame, value)
    if not running() or not W:Available(frame) or not V.InteriorSkin then return end
    if V:IsSecret(value) or type(value) ~= "boolean" then return end
    if InCombatLockdown() then V:Refresh("native selection after combat", "nativeWindows"); return end
    local binding = selections[frame]
    if not binding then return end
    binding.selected = value
    local I = V.InteriorSkin
    I:Control(frame, "tab", OWNER)
    for _, key in ipairs(binding.art or TAB_ART) do I:Hide(frame[key], OWNER) end
    if binding.checkedArt then I:Hide(safeMethod(frame, "GetCheckedTexture"), OWNER) end
    -- A native mixin can reassign its FontObject whenever selection changes.
    -- Only reviewed tab/category labels receive the neutral control color.
    if binding.label then I:Text(frame[binding.label], "control", false, OWNER) end
    I:SetSelected(frame, value)
end

local function bindSelection(frame, binding)
    selections[frame] = binding
    if binding.method and hooksecurefunc then
        pcall(hooksecurefunc, frame, binding.method, function(self, selected)
            paintSelection(self, selected)
        end)
        if binding.hoverText then
            -- MinimalTab's native hover handlers reassign the FontObject.
            -- Reapply only presentation after those owner handlers complete.
            for _, method in ipairs({"OnEnter", "OnLeave"}) do
                if type(frame[method]) == "function" then
                    pcall(hooksecurefunc, frame, method, function(self)
                        paintSelection(self, safeMethod(self, "IsSelected"))
                    end)
                end
            end
        end
    end
end

local function selectionFrame(frame)
    if not running() or not W:Available(frame) then return end
    local binding = selections[frame]
    if not binding then
        if type(frame.SetTabSelected) == "function" and type(frame.GetTextYOffset) == "function"
            and W:Available(frame.Text) and (W:Available(frame.LeftActive) or W:Available(frame.SquareBackgroundActive)) then
            binding = {method = "SetTabSelected", field = "isSelected", label = "Text"}
        elseif MinimalTabMixin and frame.GetAtlas == MinimalTabMixin.GetAtlas
            and type(frame.IsSelected) == "function" and W:Available(frame.Left) then
            binding = {method = "OnSelected", getter = "IsSelected", label = "Text", hoverText = true}
        elseif SettingsCategoryListButtonMixin and frame.UpdateStateInternal == SettingsCategoryListButtonMixin.UpdateStateInternal
            and W:Available(frame.Label) and W:Available(frame.Texture) then
            binding = {method = "UpdateStateInternal", art = {"Texture"}, label = "Label", category = true}
        elseif type(frame.SetChecked) == "function" and type(frame.GetIconAnchorOffsetsForTabArt) == "function"
            and W:Available(frame.SelectedTexture) and W:Available(frame.Icon) then
            binding = {method = "SetChecked", shown = "SelectedTexture", art = {"Background", "SelectedTexture", "HighlightTexture"}}
        elseif W:Available(frame.LeftActive) and W:Available(frame.MiddleActive)
            and W:Available(frame.RightActive) and W:Available(frame.Text) then
            binding = {shown = "LeftActive", label = "Text", legacy = true}
        elseif W:Available(frame.SelectedBar) and (descendant(frame, get("PaperDollFrame.TitleManagerPane"))
            or descendant(frame, get("PaperDollFrame.EquipmentManagerPane"))) then
            binding = {shown = "SelectedBar", art = {"SelectedBar", "HighlightBar"}, row = true}
        end
        if not binding then return end
        bindSelection(frame, binding)
    end
    local selected
    if binding.field then selected = frame[binding.field]
    elseif binding.getter then selected = safeMethod(frame, binding.getter)
    elseif binding.shown then selected = safeShown(frame[binding.shown])
    elseif binding.category then selected = safeShown(frame.Texture) == true and safeMethod(frame.Texture, "GetAtlas") == "Options_List_Active" end
    if V:IsSecret(selected) or type(selected) ~= "boolean" then selected = binding.selected end
    paintSelection(frame, selected)
end

local function registerSelectionHooks()
    if not hooksecurefunc then return end
    -- Public native owner functions, scoped to already visited native tabs/rows.
    -- This observes state only; it never invokes selection or a click itself.
    for _, entry in ipairs({
        {"PanelTemplates_SelectTab", true}, {"PanelTemplates_DeselectTab", false},
        {"PaperDollEquipmentManagerPane_SetButtonSelected"}, {"PaperDollTitlesPane_SetButtonSelected"},
    }) do
        local name, fixed = entry[1], entry[2]
        if not selectionHooks[name] and type(_G[name]) == "function" then
            local ok = pcall(hooksecurefunc, name, function(frame, selected)
                if not W:Available(frame) then return end
                local binding = selections[frame]
                if not binding or not (binding.legacy or binding.row) then return end
                if fixed ~= nil then selected = fixed end
                paintSelection(frame, selected)
            end)
            if ok then selectionHooks[name] = true end
        end
    end
    -- Character's four stat/pet-stat/equipment/title tabs are CheckButtons,
    -- unlike the separate large mode tabs. Keep each icon and checked state.
    for i = 1, 4 do
        local tab = get("PaperDollSidebarTab" .. i)
        if tab and type(tab.SetChecked) == "function" then
            if not selections[tab] then
                bindSelection(tab, {method = "SetChecked", getter = "GetChecked", art = {}, checkedArt = true})
            end
            selectionFrame(tab)
        end
    end
end

local function records()
    local result, byFrame, boundaries = {}, {}, {}
    local function add(name, shell)
        local frame = get(name)
        if not frame or not frame.CreateTexture or W:NativeRecoveryDialog(frame) then return end
        if byFrame[frame] then
            if shell == false then byFrame[frame].shell = false end
            return
        end
        local entry = {name = name, frame = frame, shell = shell ~= false}
        result[#result + 1], byFrame[frame] = entry, entry
    end
    for _, entry in ipairs(V.WindowCatalog or {}) do
        if entry.boundary then
            boundaries[entry.frame] = true
        else
            local host, frame = get(entry.host), get(entry.frame)
            add(entry.host, not entry.scanOnly)
            if frame and (not host or (frame ~= host and not descendant(frame, host))) then
                add(entry.frame, entry.frame == entry.host and not entry.scanOnly)
            end
            for _, name in ipairs(entry.aliases or {}) do add(name, not entry.scanOnly) end
        end
    end
    for _, entry in ipairs(W.NativeRoots or {}) do
        if not boundaries[entry[1]] then add(entry[1], true) end
    end
    -- Explicit child interiors can have globals even when their host is closed.
    for name in pairs(interiors) do
        local frame = get(name)
        if not boundaries[name] and frame and not byFrame[frame] then add(name, false) end
    end
    -- One outer surface per host. Tab pages and attached content retain their
    -- bounds without stacking a second opaque window background over the host.
    for _, record in ipairs(result) do
        if record.shell then
            local ancestor = parentOf(record.frame)
            for _ = 1, 32 do
                if not ancestor then break end
                if byFrame[ancestor] then record.shell = false; break end
                ancestor = parentOf(ancestor)
            end
        end
    end
    return result
end

local function accumulated(total, stats)
    if type(stats) ~= "table" then return end
    for _, field in ipairs({"nodes", "controls", "texts", "panels", "skipped", "deferred"}) do
        total[field] = (total[field] or 0) + (V:SafeNumber(stats[field]) or 0)
    end
    if stats.limitReached then total.limitReached = true end
end

local function rowStyle(...)
    if not running() or not V.InteriorSkin then return end
    if InCombatLockdown() then V:Refresh("native row styling after combat", "nativeWindows"); return end
    local row
    -- ScrollUtil's iterate-existing path uses (frame, data); subsequent
    -- callbacks use (owner, frame, data). Never inspect elementData.
    if select("#", ...) == 2 then row = ... else row = select(2, ...) end
    if W:Available(row) then
        pcall(V.InteriorSkin.Apply, V.InteriorSkin, row,
            {owner = OWNER, art = {"Background"}, decorativeAtlases = decorativeAtlases, skinner = true, maxNodes = 96})
    end
end

local function registerStatRows()
    if not ScrollUtil or type(ScrollUtil.AddInitializedFrameCallback) ~= "function" then return end
    for _, name in ipairs(statScrollBoxes) do
        local host = get(name)
        local box = host and host.ScrollBox
        if W:Available(box) and box.RegisterCallback and box.ForEachFrame and not rowCallbacks[box] then
            local ok = pcall(ScrollUtil.AddInitializedFrameCallback, box, rowStyle, N, true)
            if ok then rowCallbacks[box] = true end
        end
    end
end

local function style(record, visited)
    local frame, name = record.frame, record.name
    if not W:Available(frame) then return end
    local spec = interiors[name] or {}
    if record.shell then W:Shell(frame, spec.art, nil, OWNER) end
    local skip = {}
    if name == "HelpFrame" and W:Available(frame.Browser) then skip[frame.Browser] = true end
    if name == "EditModeManagerFrame" then
        for _, key in ipairs({"Grid", "MagnetismPreviewLinesContainer"}) do
            if W:Available(frame[key]) then skip[frame[key]] = true end
        end
    end
    local stats = V.InteriorSkin:Apply(frame, {owner = OWNER, art = spec.art, panels = spec.panels, skip = skip,
        decorativeAtlases = decorativeAtlases, skinner = true, maxNodes = 2400, onFrame = selectionFrame, visited = visited})
    if not watched[frame] then
        W:Hook(frame, OWNER)
        watched[frame] = true
    end
    return stats
end

local function run(discoveryOnly)
    local totals = {roots = 0, controls = 0, texts = 0, panels = 0, skipped = 0, deferred = 0}
    if not running() or not V.InteriorSkin then return totals end
    if InCombatLockdown() then
        V:Refresh("native interiors after combat", OWNER); totals.deferred = 1; return totals
    end
    registerSelectionHooks()
    local visited = {}
    for _, record in ipairs(records()) do
        local frame = record.frame
        local isVisible = W:Visible(frame)
        local wasVisible = visibility[frame]
        -- Install the cheap OnShow observer even for closed windows, but defer
        -- their descendant traversal until they are actually shown.
        -- Watch is deduplicated and also renews the ownership claim after
        -- disable/reenable while a window remains closed.
        W:Hook(frame, OWNER); watched[frame] = true
        visibility[frame] = isVisible
        if isVisible and (not discoveryOnly or not wasVisible or reconcileAfterCombat) then
            local ok, stats = pcall(style, record, visited)
            if ok then totals.roots = totals.roots + 1; accumulated(totals, stats)
            else totals.deferred = totals.deferred + 1 end
        end
    end
    if not discoveryOnly or totals.roots > 0 then
        for _, name in ipairs(globalArt) do W:Hide(get(name),OWNER) end
        for _, name in ipairs(narrativeText) do
            local text = get(name)
            if text then pcall(V.InteriorSkin.Text, V.InteriorSkin, text, "body", false, OWNER) end
        end
        registerStatRows()
    end
    reconcileAfterCombat = nil
    if not discoveryOnly or totals.roots > 0 then N.last = totals end
    return totals
end

function N:Apply()
    local result = run(false)
    if not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(2, function()
            if running() then
                local ok = pcall(run, true)
                if not ok then V:Report(OWNER, "pending", "A native interior is currently restricted; retry after its owner is ready.") end
            end
        end)
    end
    return result
end

function N:Disable()
    if ticker then ticker:Cancel(); ticker = nil end
    if V.InteriorSkin and V.InteriorSkin.Restore then V.InteriorSkin:Restore(OWNER) end
end

N.Specifications, N.DecorativeAtlases = interiors, decorativeAtlases
V:On("PLAYER_REGEN_ENABLED", function()
    if running() then reconcileAfterCombat = true; V:Refresh("native interiors combat ended", OWNER) end
end)
