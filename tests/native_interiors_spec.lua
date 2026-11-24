local root = (arg and arg[1]) or "."
local V = {db = {enabled = true, modules = {}}, modules = {}, surfaces = {}, events = {}, errors = {}}
local combat, calls, rows, tick, cancelled = false, {}, {}, nil, false
local applyCounts = {}
local function texture(atlas)
    return {alpha = 1, atlas = atlas, GetAlpha = function(self) return self.alpha end,
        SetAlpha = function(self, a) self.alpha = a end, GetAtlas = function(self) return self.atlas end,
        IsShown = function(self) return self.shown ~= false end}
end
local function font(color)
    return {color = color or {1,1,1}, size = 13, GetFont = function(self) return "native.ttf", self.size, "" end,
        SetFont = function(self, _, size) self.size = size end}
end
local function frame(parent, objectType)
    local f = {parent = parent, type = objectType or "Frame", children = {}, regions = {}, hooks = 0, Bg = texture(), TitleText = font()}
    function f:GetParent() return self.parent end
    function f:GetChildren() return unpack(self.children) end
    function f:GetRegions() return unpack(self.regions) end
    function f:GetObjectType() return self.type end
    function f:CreateTexture() return texture() end
    function f:IsShown() return self.shown ~= false end
    function f:HookScript(event, fn) self.hooks = self.hooks + 1; self[event] = fn end
    function f:SetSize() error("native size changed") end
    function f:SetPoint() error("native anchor changed") end
    function f:SetParent() error("native structure changed") end
    if parent then parent.children[#parent.children+1] = f end
    return f
end
function V:RegisterModule(id, spec) self.modules[id] = spec end
function V:RegisterProfileAdapter() end
function V:On(event, fn) self.events[event] = fn end
function V:IsModuleEnabled(id) return self.db.enabled and self.db.modules[id] ~= false end
function V:IsSecret(value) return type(value) == "table" and value.secret == true end
function V:SafeNumber(value) return type(value) == "number" and value or nil end
function V:HideArtwork(object) object:SetAlpha(0) end
function V:Surface(object) self.surfaces[object] = true end
function V:StyleText(text, role, color) text.styled = true; text.styledColor=color end
function V:Font() return "Fonts\\FRIZQT__.TTF",16,"" end
function V:Refresh() self.refreshes = (self.refreshes or 0) + 1 end
function V:Report(id,state,detail) self.errors[#self.errors+1] = {id,state,detail} end
InCombatLockdown = function() return combat end
C_Timer = {NewTicker = function(_, fn) tick = fn; return {Cancel = function() cancelled = true end} end}
C_AddOns = {GetAddOnMetadata = function() return "beta12.70938.1" end}
V.InteriorSkin = {watched = {}}
local function path(f, name)
    for key in name:gmatch("[^.]+") do f = f and f[key] end
    return f
end
function V.InteriorSkin:Apply(f, opts)
    applyCounts[f] = (applyCounts[f] or 0) + 1
    calls[f] = opts
    self:Watch(f, opts)
    for _, key in ipairs(opts.art or {}) do local t = path(f,key); if t then t:SetAlpha(0) end end
    for _, t in ipairs(f.regions or {}) do if opts.decorativeAtlases[t.atlas] then t:SetAlpha(0) end end
    if opts.onFrame then
        local function visit(node)
            if opts.skip and opts.skip[node] then return end
            if node.type == "ModelScene" or node.type == "Browser" then return end
            opts.onFrame(node)
            for _, child in ipairs(node.children or {}) do visit(child) end
        end
        visit(f)
    end
    return {nodes=1,controls=1,texts=1,panels=0,skipped=f.skipCount or 0,deferred=0}
end
function V.InteriorSkin:Text(text, role, preserveColor)
    if not text or not text.GetFont then return false end
    text.role, text.preserveColor = role, preserveColor
    if preserveColor==false then text.styledColor=V.Tokens.colors.text end
    return true
end
function V.InteriorSkin:Panel(f, kind, owner)
    if not f or not f.CreateTexture then return false end
    V.surfaces[f]=true
    for _, key in ipairs({"Bg", "Background", "TitleBg"}) do self:Hide(f[key],owner) end
    if f.NineSlice then
        for _, key in ipairs({"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center"}) do self:Hide(f.NineSlice[key],owner) end
    end
    return {object=f,kind=kind,owner=owner}
end
function V.InteriorSkin:Watch(f, opts)
    if not f then return false end
    self.watchClaims=self.watchClaims or {}
    self.watchClaims[f]=true
    if self.watched[f] then return true end
    self.watched[f]=opts
    f:HookScript("OnShow",function() if V:IsModuleEnabled(opts.owner) then V:Refresh("native shown") end end)
    return true
end
function V.InteriorSkin:Restore(owner) self.restored = owner;self.watchClaims={} end
function V.InteriorSkin:Control(f, kind) f.controlKind=kind end
function V.InteriorSkin:SetSelected(f, selected) f.markerSelected=selected end
function V.InteriorSkin:Hide(t) if t then t:SetAlpha(0) end end
local secureHooks = {}
function hooksecurefunc(object, method, callback)
    if type(object)=="string" then callback=method; method=object;object=_G end
    secureHooks[method]=(secureHooks[method] or 0)+1
    local original=object[method]
    object[method]=function(...) local result={original(...)};callback(...);return unpack(result) end
end
function PanelTemplates_SelectTab(tab) tab.LeftActive.shown=true end
function PanelTemplates_DeselectTab(tab) tab.LeftActive.shown=false end
function PaperDollTitlesPane_SetButtonSelected(button, selected) button.SelectedBar.shown=selected end
function PaperDollEquipmentManagerPane_SetButtonSelected(button, selected) button.SelectedBar.shown=selected end
MinimalTabMixin = {GetAtlas = function() return "Options_Tab_Left" end}
SettingsCategoryListButtonMixin = {UpdateStateInternal = function(self, selected)
    self.Texture.atlas=selected and "Options_List_Active" or "Options_List_Hover";self.Texture.shown=true
end}
ScrollUtil = {AddInitializedFrameCallback = function(box, callback, owner, existing)
    rows[box] = {callback=callback,owner=owner,count=(rows[box] and rows[box].count or 0)+1}
    if existing then box:ForEachFrame(callback) end
end}

UIParent = frame()
CharacterFrame = frame(UIParent)
CharacterFrame.LeftPaneHost, CharacterFrame.RightPaneHost = frame(CharacterFrame), frame(CharacterFrame)
CharacterFrame.RightPaneHost.StoneBg = texture()
CharacterFrame.regions = {texture("UI-Character-Info-General-BG"), texture("Item-Quality-Rare")}
PaperDollFrame = frame(CharacterFrame)
function PaperDollFrame:IsVisible() return self:IsShown() and CharacterFrame:IsShown() end
PaperDollFrame.TitleManagerPane = frame(PaperDollFrame)
local titleRow=frame(PaperDollFrame.TitleManagerPane,"Button")
titleRow.SelectedBar, titleRow.Check, titleRow.icon=texture(),texture("NativeCheck"),texture("TitleIcon")
titleRow.SelectedBar.shown=false
local tab=frame(CharacterFrame,"Button")
tab.Text,tab.LeftActive,tab.Icon=font(),texture(),texture("NativeTabIcon")
tab.isSelected=false
function tab:GetTextYOffset() return 0 end
function tab:SetTabSelected(selected) self.isSelected=selected end
local legacy=frame(CharacterFrame,"Button")
legacy.Text,legacy.LeftActive,legacy.MiddleActive,legacy.RightActive=font(),texture(),texture(),texture()
legacy.LeftActive.shown=false
PaperDollSidebarTab1=frame(CharacterFrame,"CheckButton")
PaperDollSidebarTab1.checked=false
PaperDollSidebarTab1.Icon,PaperDollSidebarTab1.checkedTexture=texture("StatIcon"),texture("StatSelected")
function PaperDollSidebarTab1:GetChecked() return self.checked end
function PaperDollSidebarTab1:SetChecked(value) self.checked=value end
function PaperDollSidebarTab1:GetCheckedTexture() return self.checkedTexture end
PaperDollFrame.CharacterModelScene = frame(PaperDollFrame,"ModelScene")
PaperDollFrame.CharacterModelScene.BackgroundTopLeft = texture()
PaperDollFrame.CharacterModelScene.model = "native model sentinel"
CharacterStatsPaneScrollBox = frame(CharacterFrame)
CharacterStatsPaneScrollBox.ClassBackground = texture()
local row = frame(CharacterStatsPaneScrollBox)
row.Background, row.Icon, row.Value = texture(), texture("StatIcon"), font({.1,.9,.1})
CharacterStatsPaneScrollBox.ScrollBox = frame(CharacterStatsPaneScrollBox)
function CharacterStatsPaneScrollBox.ScrollBox:RegisterCallback() end
function CharacterStatsPaneScrollBox.ScrollBox:ForEachFrame(callback) callback(row, {}) end
ReputationFrame = frame(CharacterFrame)
HelpFrame = frame(UIParent)
HelpBrowser = frame(HelpFrame,"Browser")
HelpFrame.Browser = HelpBrowser
HelpBrowser.BrowserInset = {Bg=texture()}
HelpBrowser.content = "embedded HTML sentinel"
AccountSaveFrame, CinematicFrame, PlayerFrame = frame(UIParent),frame(UIParent),frame(UIParent)
EditModeManagerFrame = frame(UIParent)
SettingsPanel=frame(UIParent)
SettingsPanel.GameTab=frame(SettingsPanel,"Button")
local minimal=SettingsPanel.GameTab
minimal.Left,minimal.Text,minimal.selected=texture(),font(),false
minimal.GetAtlas=MinimalTabMixin.GetAtlas
function minimal:IsSelected() return self.selected end
function minimal:OnSelected(selected) self.selected=selected end
function minimal:OnEnter() self.Text.preserveColor=true end
function minimal:OnLeave() self.Text.preserveColor=true end
SettingsPanel.CategoryList=frame(SettingsPanel)
local category=frame(SettingsPanel.CategoryList,"Button")
category.Texture,category.Label=texture("Options_List_Active"),font()
category.UpdateStateInternal=SettingsCategoryListButtonMixin.UpdateStateInternal
BarberShopFrame = frame(UIParent)
QuestInfoDescriptionText = font({0,0,0})
SendStationeryBackgroundLeft = texture()

assert(loadfile(root .. "/Tokens.lua"))("vasagoio",V)
assert(loadfile(root .. "/modules/WindowCatalog.lua"))("vasagoio",V)
assert(loadfile(root .. "/modules/NativeWindows.lua"))("vasagoio",V)
assert(loadfile(root .. "/modules/NativeInteriors.lua"))("vasagoio",V)
assert(V.modules.nativeWindows.Apply())
assert(CharacterFrame.TitleText.styledColor==V.Tokens.colors.text, "Native shell text did not use shared color token")
CharacterFrame.skipCount=1
local applied, _, state=V.modules.nativeWindows.Apply()
assert(not applied and state=="pending", "Unreadable native control was reported as completely applied")
CharacterFrame.skipCount=nil
assert(calls[CharacterFrame] and calls[PaperDollFrame], "Character interior roots missing")
assert(V.surfaces[CharacterFrame] and not V.surfaces[PaperDollFrame], "Nested content acquired a duplicate window surface")
assert(not V.surfaces[BarberShopFrame] and calls[BarberShopFrame], "Fullscreen control root must remain scan-only")
assert(V.surfaces[EditModeManagerFrame], "Edit Mode settings dialog must receive its own panel")
assert(not calls[AccountSaveFrame] and not calls[CinematicFrame] and not calls[PlayerFrame], "Boundary or dedicated HUD was skinned")
assert(not calls[HelpBrowser] and HelpBrowser.content=="embedded HTML sentinel", "Embedded browser was treated as a skinnable root")
assert(HelpBrowser.BrowserInset.Bg.alpha==0, "Native browser surrounding inset was not styled")
assert(PaperDollFrame.CharacterModelScene.BackgroundTopLeft.alpha==0 and PaperDollFrame.CharacterModelScene.model=="native model sentinel")
assert(CharacterFrame.regions[1].alpha==0 and CharacterFrame.regions[2].alpha==1, "Atlas whitelist affected semantic art")
assert(row.Background.alpha==0 and row.Icon.alpha==1 and row.Value.color[2]==.9, "Stat row content or semantic values changed")
assert(QuestInfoDescriptionText.preserveColor==false and QuestInfoDescriptionText.size==13, "Dark narrative text was not assigned readable face/color")
assert(SendStationeryBackgroundLeft.alpha==0)
assert(tab.controlKind=="tab" and not tab.markerSelected and tab.LeftActive.alpha==0 and tab.Icon.alpha==1)
tab:SetTabSelected(true)
assert(tab.markerSelected, "Modern tab selection not mirrored")
minimal:OnSelected(true)
assert(minimal.markerSelected and minimal.Left.alpha==0, "Minimal tab selection not mirrored")
minimal:OnEnter()
assert(minimal.Text.preserveColor==false, "Minimal tab hover restored native label color")
minimal:OnLeave()
assert(minimal.Text.preserveColor==false, "Minimal tab leave restored native label color")
PanelTemplates_SelectTab(legacy)
assert(legacy.markerSelected and legacy.LeftActive.alpha==0, "Legacy tab selection not mirrored")
PanelTemplates_DeselectTab(legacy)
assert(not legacy.markerSelected)
PaperDollTitlesPane_SetButtonSelected(titleRow,true)
assert(titleRow.markerSelected and titleRow.SelectedBar.alpha==0 and titleRow.Check.alpha==1 and titleRow.icon.alpha==1,
    "Selected row marker lost native semantic art")
PaperDollSidebarTab1:SetChecked(true)
assert(PaperDollSidebarTab1.markerSelected and PaperDollSidebarTab1.checkedTexture.alpha==0 and PaperDollSidebarTab1.Icon.alpha==1)
assert(category.markerSelected and category.Texture.alpha==0)
category:UpdateStateInternal(false)
assert(not category.markerSelected, "Settings category selection not mirrored")
V.modules.nativeWindows.Apply()
assert(CharacterFrame.hooks==1, "Shared shell/interior watch registered duplicate hooks")
assert(rows[CharacterStatsPaneScrollBox.ScrollBox].count==1, "Scroll callback registered twice")
assert(secureHooks.SetTabSelected==1 and secureHooks.PanelTemplates_SelectTab==1, "Selection hooks registered twice")
local secondRow=frame(CharacterStatsPaneScrollBox);secondRow.Background=texture()
rows[CharacterStatsPaneScrollBox.ScrollBox].callback(V.NativeInteriors,secondRow,{})
assert(secondRow.Background.alpha==0, "New pooled stat row wasn't styled")

local before=V.NativeInteriors.last.roots
combat=true
tab:SetTabSelected(false)
assert(tab.markerSelected, "Native selection must defer cosmetic writes during combat")
local thirdRow=frame(CharacterStatsPaneScrollBox);thirdRow.Background=texture()
rows[CharacterStatsPaneScrollBox.ScrollBox].callback(V.NativeInteriors,thirdRow,{})
assert(thirdRow.Background.alpha==1 and V.refreshes>0, "Protected row update must defer")
tick()
assert(V.NativeInteriors.last.roots==before, "Combat ticker applied native interiors")
combat=false
V.events.PLAYER_REGEN_ENABLED()
local late = frame(UIParent); _G.MerchantFrame = late
tick()
assert(calls[late], "Late native root was not discovered")
assert(not tab.markerSelected, "Deferred tab selection was not reconciled")
CharacterFrame.shown=false
calls[CharacterFrame],calls[PaperDollFrame]=nil,nil
assert(PaperDollFrame:IsShown() and not PaperDollFrame:IsVisible())
tick()
assert(not calls[CharacterFrame] and not calls[PaperDollFrame], "Hidden host's shown child was polled")
CharacterFrame.shown=true
tick()
assert(calls[CharacterFrame] and calls[PaperDollFrame], "Visible native root did not resume polling")

local countBefore=applyCounts[CharacterFrame]
for _=1,20 do tick() end
assert(applyCounts[CharacterFrame]==countBefore, "Stationary visible window was rescanned every ticker pass")
local closed=frame(UIParent); closed.shown=false; _G.TradeFrame=closed
tick()
assert(not calls[closed] and closed.hooks==1, "Closed root traversed before user showed it")
closed.shown=true
tick()
assert(calls[closed], "Previously closed root was not styled on visibility transition")

V.db.modules.nativeWindows=false
local blocked=frame(UIParent); _G.TradeFrame=blocked
tick()
assert(not calls[blocked], "Disabled native module applied a new interior")
tab:SetTabSelected(true)
assert(not tab.markerSelected, "Disabled module repainted selected tab")
V.modules.nativeWindows.Disable()
assert(cancelled and V.InteriorSkin.restored=="nativeWindows", "Disable did not stop discovery/restore primitives")
CharacterFrame.shown=false
V.db.modules.nativeWindows=true
V.modules.nativeWindows.Apply()
assert(V.InteriorSkin.watchClaims[CharacterFrame],"Reenabled closed native root lost its show observer ownership")
print("native_interiors_spec: catalog scope, unchanged layouts, pooled rows, selected tabs/rows, semantic art, browser boundaries, lazy roots and combat cleanup passed")
