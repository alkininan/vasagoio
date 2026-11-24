local addonName, V = ...
local A = {}
V.AddonInteriors = A
local OWNER = "addonWindows"
local roots, hooks, originals = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})
local gargulWidgets = setmetatable({}, {__mode = "k"})
local reviewed = {MRT = "5335", Auctionator = "352", TalentsForeverBook = "0.38.28.20261116", Gargul = "8.1.0"}
local function color(role, alpha)
    local c = V.Tokens.colors[role]
    return {c[1], c[2], c[3], alpha or 1}
end

function A:Reviewed(addon)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return get and get(addon, "Version") == reviewed[addon]
end
local function available(o) return V.WindowSkin:Available(o) end
local function enabled() return not V.profileReloadPending and V.WindowSkin:Enabled(OWNER) end
local function ready()
    return enabled() and V.InteriorSkin and not (InCombatLockdown and InCombatLockdown())
end
local function request()
    if enabled() then V:Refresh("selected addon interior changed") end
end
local function hook(object, method, callback)
    if not available(object) or type(object[method]) ~= "function" or not hooksecurefunc then return end
    hooks[object] = hooks[object] or {}
    if hooks[object][method] then return end
    hooks[object][method] = true
    hooksecurefunc(object, method, callback)
end
local function hide(texture)
    if not available(texture) or not texture.SetAlpha then return end
    originals[texture] = originals[texture] or {}
    local old = originals[texture]
    if old.alpha == nil then
        if not texture.GetAlpha then return end
        local ok, alpha = pcall(texture.GetAlpha, texture)
        old.alpha = ok and V:SafeNumber(alpha)
        if not old.alpha then return end
    end
    texture:SetAlpha(0)
end
local function tint(texture, color)
    if not available(texture) or not texture.SetVertexColor then return end
    originals[texture] = originals[texture] or {}
    local old = originals[texture]
    if not old.color then
        if not texture.GetVertexColor then return end
        local ok, r, g, b, a = pcall(texture.GetVertexColor, texture)
        if not ok then return end
        r, g, b, a = V:SafeNumber(r), V:SafeNumber(g), V:SafeNumber(b), V:SafeNumber(a)
        if not r or not g or not b then return end
        old.color = {r, g, b, a or 1}
    end
    texture:SetVertexColor(unpack(color))
end
local function edges(list)
    if type(list) == "table" then for i = 1, 8 do hide(list[i]) end end
end
local function text(fs, role, preserve)
    if available(fs) then V.InteriorSkin:Text(fs, role or "body", preserve ~= false, OWNER) end
end
local function walk(root, callback, skip)
    local seen, budget = {}, 4096
    local function visit(frame, depth)
        if budget <= 0 or depth > 24 or not available(frame) or seen[frame] or frame.__vasagoio then return end
        seen[frame], budget = true, budget - 1
        if callback(frame) == false then if skip then skip[frame] = true end; return end
        if frame.GetChildren then
            local ok, children = pcall(function() return {frame:GetChildren()} end)
            if ok then for _, child in ipairs(children) do visit(child, depth + 1) end end
        end
    end
    visit(root, 0)
end

local function talentFrame(frame)
    local I = V.InteriorSkin
    -- Talent nodes carry owner-managed rank, planned-rank, prerequisites,
    -- selection/ghost glows and animated path art. Never flatten those states.
    if frame.icon and frame.slot and (frame.rank or frame.ring) then
        for _, key in ipairs({"rank", "live", "pick", "backTag", "count"}) do text(frame[key], "count", true) end
        return false
    end
    -- Remaining Edges() sets belong to card/list/control chrome, not nodes.
    edges(frame.edge)
    if frame.line and frame.text then tint(frame.line, color("muted", V.Tokens.alpha.input)) end
    if frame.track and frame.fill then tint(frame.track, color("track", V.Tokens.alpha.window)) end
    if frame.bg and not frame.art and not frame.rank and not frame.ring then
        hide(frame.bg); I:Panel(frame, "inset", OWNER)
    end
    if frame.border and frame.divL and frame.divR then
        for _, key in ipairs({"border", "divL", "divR", "vl", "vr"}) do hide(frame[key]) end
    end
    if type(frame.art) == "table" and frame.shade and frame.title then
        -- Keep the original class tree illustrations; replace their gold rim
        -- and neutral pane backing while retaining the point-progress fill.
        edges(frame.edge); hide(frame.fade)
        tint(frame.shade, color("panel", V.Tokens.alpha.window))
        tint(frame.fill, color("informationFill")); tint(frame.fillGlow, color("information"))
        text(frame.title, "name", false)
        I:Panel(frame, "inset", OWNER)
    end
    if frame.pane and available(frame.pane) then
        I:Panel(frame.pane, "inset", OWNER)
        hide(frame.pane.bg); hide(frame.pane.lip); edges(frame.pane.edge)
    end
    local plate = frame.plate
    if type(plate) == "table" and plate.body then
        hide(plate.body); hide(plate.drop); hide(plate.hi); hide(plate.lo); edges(plate.edges)
        if frame.GetRegions then
            local ok, regions = pcall(function() return {frame:GetRegions()} end)
            if ok then for _, region in ipairs(regions) do
                if available(region) and region.GetDrawLayer then
                    local good, layer = pcall(region.GetDrawLayer, region)
                    if good and not V:IsSecret(layer) and layer == "HIGHLIGHT" then hide(region) end
                end
            end end
        end
        -- Text buttons may also carry a small leading icon. Their plate is
        -- still a background control, not an inventory/talent icon slot.
        I:Panel(frame, "button", OWNER)
        I:Control(frame, type(frame.SetSelected) == "function" and "tab" or "button", OWNER, {skinIconButton = true})
        text(frame.label or frame.text, "control", true)
        hook(frame, "Ink", function(self) if ready() then text(self.label, "control", true) end end)
        hooks[frame] = hooks[frame] or {}
        if frame.HookScript and not hooks[frame].talentInk then
            hooks[frame].talentInk = true
            frame:HookScript("OnEnter", function()
                if ready() then text(frame.label or frame.text, "control", true) end
            end)
        end
        if frame.SetSelected then
            hook(frame, "SetSelected", function(self, selected)
                if ready() then I:SetSelected(self, selected); text(self.text, "body", false) end
            end)
            I:SetSelected(frame, plate.kind == "gold")
        end
    end
    if frame.box and frame.tick and frame.get and frame.SetChecked then
        hide(frame.box); edges(frame.edge)
        I:Control(frame, "checkbox", OWNER); tint(frame.tick, color("information"))
        hook(frame, "SetChecked", function(self)
            if ready() then hide(self.box); edges(self.edge); tint(self.tick, color("information")) end
        end)
    end
    -- The custom slider is a Button with drag scripts, not a native Slider.
    if frame.bar and frame.knob and frame.fill then
        tint(frame.bar, color("raised", V.Tokens.alpha.window)); tint(frame.knob, color("information")); tint(frame.fill, color("informationFill"))
        edges(frame.edge); edges(frame.barEdge); edges(frame.knobEdge)
    end
    if frame.edge and (frame.hint or frame.GetTextInsets) then edges(frame.edge) end
end

local function mrtList(list)
    if not ready() or not available(list) or type(list.List) ~= "table" or type(list.L) ~= "table" or list.isCheckList then return end
    for _, row in ipairs(list.List) do
        if available(row) then
            V.InteriorSkin:Control(row, "tab", OWNER)
            local index, selected = V:SafeNumber(row.index), V:SafeNumber(list.selected)
            V.InteriorSkin:SetSelected(row, index ~= nil and index == selected)
            hide(row.PushedTexture); hide(row.HighlightTexture)
        end
    end
end
local function mrtTabs(tabs)
    if not ready() or not available(tabs) or type(tabs.tabs) ~= "table" then return end
    for index, page in ipairs(tabs.tabs) do
        local button = available(page) and page.button
        if available(button) then
            V.InteriorSkin:Control(button, "tab", OWNER)
            for _, key in ipairs({"LeftDisabled", "MiddleDisabled", "RightDisabled"}) do hide(button[key]) end
            V.InteriorSkin:SetSelected(button, index == V:SafeNumber(tabs.selected))
        end
    end
end

function A:Apply(root, family)
    if not ready() or not available(root) then return end
    local skip = {}
    if family == "TalentsForeverBook" then walk(root, talentFrame, skip) end
    local result = V.InteriorSkin:Apply(root, {owner = OWNER, skip = skip, maxNodes = 8192})
    if family == "MRT" then
        -- ELib uses a dedicated Border* set for modern neutral control chrome.
        -- ColorState checkboxes intentionally encode enabled/disabled meaning.
        walk(root, function(frame)
            if not frame.colorStateIsBorderInsteadText then
                for _, key in ipairs({"BorderTop", "BorderLeft", "BorderBottom", "BorderRight"}) do hide(frame[key]) end
            end
            if frame.List and frame.L and type(frame.Update) == "function" then
                mrtList(frame); hook(frame, "Update", mrtList)
            end
            if frame.tabs and type(frame.UpdateTabs) == "function" then
                mrtTabs(frame); hook(frame, "UpdateTabs", mrtTabs)
            end
        end)
    elseif family == "Gargul" then
        walk(root, function(frame)
            local widget = frame.obj
            if not available(widget) or widget.type ~= "Frame" then return end
            if widget.frame == frame then
                hide(widget.titlebg); text(widget.titletext, "heading", false)
                -- AceGUIContainer-Frame's three dialog-header pieces use
                -- this native artwork ID; no item/icon regions are matched.
                if frame.GetRegions then
                    local ok, regions = pcall(function() return {frame:GetRegions()} end)
                    if ok then for _, region in ipairs(regions) do
                        if available(region) and region.GetTexture then
                            local good, id = pcall(region.GetTexture, region)
                            if good and V:SafeNumber(id) == 131080 then hide(region) end
                        end
                    end end
                end
            elseif frame.GetObjectType and frame.GetBackdropColor then
                -- The status pane carries this same widget reference; its
                -- close button remains a Button and is handled as a control.
                local ok, kind = pcall(frame.GetObjectType, frame)
                if ok and not V:IsSecret(kind) and kind == "Frame" then V.InteriorSkin:Panel(frame, "inset", OWNER) end
            end
        end)
    end
    return result
end

function A:Register(frame, family, shell)
    if not available(frame) or not frame.CreateTexture then return false end
    local record = roots[frame]
    local new = not record
    if new then
        record = {family = family, shell = shell ~= false}
        roots[frame] = record
    end
    if ready() and frame.HookScript and not record.showHook then
        frame:HookScript("OnShow", request); record.showHook = true
    end
    return new
end

local BAG = {
    Button = "button", IconButton = "icon", SideTabButton = "icon",
    TabButton = "tab", TopTabButton = "tab", CheckBox = "checkbox",
    Dropdown = "dropdown", EditBox = "editbox", SearchBox = "editbox",
    Slider = "slider", TrimScrollBar = "scrollbar", CategorySectionHeader = "button",
}
A.BaganatorTypes = {"Button", "ButtonFrame", "CategoryLabel", "CategorySectionHeader", "CheckBox",
    "CornerWidget", "Dialog", "Divider", "Dropdown", "EditBox", "IconButton", "InsetFrame", "ItemButton",
    "SearchBox", "SideTabButton", "Slider", "TabButton", "TopTabButton", "TrimScrollBar"}
function A:Bag(details)
    if not ready() or type(details) ~= "table" then return false end
    local f, kind, I = details.region, details.regionType, V.InteriorSkin
    if not available(f) then return false end
    if BAG[kind] then
        I:Control(f, BAG[kind], OWNER)
        if kind == "TabButton" or kind == "TopTabButton" then
            if f.IsEnabled then
                local ok, value = pcall(f.IsEnabled, f)
                if ok and not V:IsSecret(value) and type(value) == "boolean" then I:SetSelected(f, not value) end
            end
            hooks[f] = hooks[f] or {}
            if f.HookScript and not hooks[f].bagSelection then
                hooks[f].bagSelection = true
                f:HookScript("OnDisable", function() if ready() then I:SetSelected(f, true) end end)
                f:HookScript("OnEnable", function() if ready() then I:SetSelected(f, false) end end)
            end
        end
    elseif kind == "ButtonFrame" or kind == "Dialog" or kind == "InsetFrame" then
        I:Panel(f, kind == "InsetFrame" and "inset" or "window", OWNER)
        V.WindowSkin:Hook(f, OWNER)
        self:Apply(f, "Baganator")
    elseif kind == "ItemButton" then
        -- Never replace/hide IconBorder, quest, search, context or cooldown art.
        I:Control(f, "icon", OWNER); text(f.Count, "count", true)
    elseif kind == "CategoryLabel" or kind == "CornerWidget" then
        text(f, "body", true)
    elseif kind == "Divider" then tint(f, color("muted", V.Tokens.alpha.input))
    else return false end
    return true
end

-- Explicit owner namespace paths, from Gargul v8.1.0's Interface modules.
-- Only their published InterfaceItems.Frame.Window handle is read.
local GARGUL_SCOPES = {
    "Changelog", "MasterLooterDialog", "ShortcutKeysLegend", "PlayerSelector", "ReminderToAssignLootUsingGargul",
    "TMB.Overview", "TMB.Importer", "BoostedRolls.Overview", "BoostedRolls.Importer", "TradeTime.Overview",
    "Award.Award", "Award.Overview", "GDKP.AuctionDetails", "GDKP.CreateSession", "GDKP.EditAuction",
    "GDKP.AddGold", "GDKP.Distribute.AddRaider", "GDKP.Overview", "GDKP.Export", "GDKP.Import",
    "GDKP.EditSession", "Settings.Overview", "SoftRes.Overview", "SoftRes.Importer",
    "GDKP.Distribute.CreateMutator", "GDKP.Distribute.EditMutator", "GDKP.Distribute.Export",
    "GDKP.Distribute.EditRaider", "GDKP.Distribute.Import",
    "Dialogs.IncomingPlusOneDataDialog", "Dialogs.IncomingBoostedRollDataDialog",
}
local GARGUL_NAMES = {
    "Gargul.Interface.GearOverview", "Gargul.Interface.Locale.Window", "Gargul.Interface.Onboarding.Window",
    "Gargul.Interface.BonusFeatures.Window", "Gargul.Interface.GroupVersionCheck", "Gargul.BidderQueue.Window",
    "Gargul.Interface.Importer.Window", "Gargul.Interface.GDKP.Distribute.MailCuts.Window",
    "Gargul.Interface.Award.Overview.Window", "Gargul.Interface.TradeTime.Broadcast.Window",
    "Gargul.Interface.TradeTime.Overview.Window", "Gargul.Interface.GDKP.Auctioneer.Window",
    "Gargul.Interface.GDKP.MultiAuction.Client.Window", "Gargul.Interface.GDKP.MultiAuction.FillFromInventory.Window",
    "Gargul.Interface.GDKP.MultiAuction.AddItem.Window", "Gargul.Interface.GDKP.MultiAuction.Auctioneer.Window",
    "Gargul.Interface.GDKP.GoldTrades.Create.Window", "Gargul.Interface.GDKP.GoldTrades.Overview.Window",
    "GargulUI_RollerUI_Window",
}
local function asFrame(widget)
    if not available(widget) then return end
    return available(widget.frame) and widget.frame or widget
end
local function gargul()
    local g = _G.Gargul
    if not A:Reviewed("Gargul") or not available(g) then return end
    local interface = g.Interface
    if available(g.MasterLooterUI) then
        A:Register(asFrame(V.WindowSkin:Path(g.MasterLooterUI, "InterfaceItems.Frame.Window")), "Gargul")
    end
    if available(g.RollerUI) then
        A:Register(g.RollerUI.Window, "Gargul")
        hook(g.RollerUI, "draw", request); hook(g.RollerUI, "drawRollTracker", request)
    end
    if available(interface) then
        for _, path in ipairs(GARGUL_SCOPES) do
            local scope = V.WindowSkin:Path(interface, path)
            local widget = scope and V.WindowSkin:Path(scope, "InterfaceItems.Frame.Window")
            A:Register(asFrame(widget), "Gargul")
        end
        for _, name in ipairs(GARGUL_NAMES) do A:Register(_G[name], "Gargul") end
        hook(interface, "set", function(_, _, identifier, widget)
            if not enabled() then return end
            local frame = asFrame(widget)
            if identifier == "Window" then
                if A:Register(frame, "Gargul") then request() end
            elseif available(frame) and not gargulWidgets[frame] then
                gargulWidgets[frame] = true; request()
            end
        end)
        hook(interface, "createWindow", function(_, options)
            if enabled() and type(options) == "table" and type(options.name) == "string" then
                if A:Register(_G[options.name], "Gargul") then request() end
            end
        end)
    end
    if available(g.UI) then
        -- This registry contains owner-created native buttons, not arbitrary globals.
        if type(g.UI.components) == "table" then
            for _, frame in pairs(g.UI.components) do
                if available(frame) and ready() then V.InteriorSkin:Control(frame, "button", OWNER) end
            end
        end
        hook(g.UI, "createFrame", function() request() end)
    end
end

function A:Discover()
    if not ready() then return 0 end
    local tf = _G.TalentsForeverBook
    if self:Reviewed("TalentsForeverBook") and available(tf) and available(tf.UI) then
        for _, method in ipairs({"Refresh", "Layout", "SetTab", "LayoutTabs"}) do hook(tf.UI, method, request) end
        for _, key in ipairs({"sideFrame", "drawer"}) do self:Register(tf.UI[key], "TalentsForeverBook", false) end
    end
    local mrt = _G.GMRT
    if self:Reviewed("MRT") and available(mrt) and available(mrt.Options) then
        local f = mrt.Options.Frame
        self:Register(f, "MRT")
        if available(f) then
            hook(f, "SetPage", request)
            if type(f.Frames) == "table" then for _, page in ipairs(f.Frames) do self:Register(page, "MRT", false) end end
            -- ELib popups are parented to UIParent but retained by these
            -- reviewed options-page fields. Follow only those exact handles.
            walk(f, function(page)
                for _, key in ipairs({"OtherIconsFrame", "rosteredit", "rosteredit.importWindow", "selectReplaceWindow",
                    "moreInfoWindow", "DialogSetAlts", "DialogSelectBoss", "EditPage", "FBframe", "PullsFrame",
                    "graphsFrame", "linesRightClickMoreInfo", "listInvFrame", "spellExtraSettings",
                    "timeLineImportFromNoteFrame", "quickSetupFrame", "customTimeLineDataFrame", "setupFrame",
                    "setupFrame.formattingHelpFrame", "quickStartFrame", "addModSpellFrame"}) do
                    self:Register(V.WindowSkin:Path(page, key), "MRT")
                end
            end)
        end
        hook(mrt.Options, "Add", request)
        if available(mrt.lib) then hook(mrt.lib, "Popup", request) end
    end
    if self:Reviewed("Auctionator") and available(_G.Auctionator) then
        if available(Auctionator.Config) then hook(Auctionator.Config, "InternalInitializeFrames", request) end
    end
    gargul()
    local count = 0
    for frame, record in pairs(roots) do
        if available(frame) then
            self:Register(frame, record.family, record.shell)
            if record.shell then V.InteriorSkin:Panel(frame, "window", OWNER) end
            self:Apply(frame, record.family); count = count + 1
        end
    end
    return count
end

function A:Disable()
    if InCombatLockdown and InCombatLockdown() then return end
    if V.InteriorSkin then V.InteriorSkin:Restore(OWNER) end
    for texture, old in pairs(originals) do
        if available(texture) then
            if old.alpha ~= nil then texture:SetAlpha(old.alpha) end
            if old.color and texture.SetVertexColor then texture:SetVertexColor(unpack(old.color)) end
        end
    end
end
