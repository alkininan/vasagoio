-- Run from the repository root: lua tests/hud_spec.lua
local root = (arg and arg[1]) or "."
local combat, now, refreshes = false, 100, 0
local modules, adapters, events = {}, {}, {}
local function check(value, message) assert(value, message) end
local function near(a, b) check(math.abs(a-b) < .00001, tostring(a) .. " differs from " .. tostring(b)) end
local function widget()
    local w = { shown = true, alpha = 1, scale = 1, width = 42, height = 42, color = {1,1,1,1} }
    function w:SetAlpha(v) self.alpha = v end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:SetShown(v) self.shown = v end
    function w:IsShown() return self.shown end
    function w:IsVisible() return self.shown end
    function w:SetSize(x,y) self.width,self.height = x,y end
    function w:SetWidth(x) self.width=x end
    function w:GetAlpha() return self.alpha end
    function w:SetHeight(y) self.height = y end
    function w:GetWidth() return self.width end
    function w:GetHeight() return self.height end
    function w:GetEffectiveScale() return self.scale end
    function w:SetPoint(...) self.point = {...} end
    function w:ClearAllPoints() self.point = nil end
    function w:SetAllPoints(target) self.allPoints = target end
    function w:SetColorTexture(...) self.color = {...} end
    function w:SetVertexColor(...) self.color = {...} end
    function w:GetVertexColor() return unpack(self.color) end
    function w:SetFont(path, size, flags) self.font,self.fontSize,self.fontFlags = path,size,flags; self.fontWrites=(self.fontWrites or 0)+1 end
    function w:SetJustifyH(value) self.justify = value end
    function w:SetFrameStrata(value) self.strata = value end
    function w:SetSpacing(value) self.spacing = value end
    function w:SetScript(event, fn) self[event] = fn end
    function w:CreateTexture(_, layer)
        local texture=widget(); texture.drawLayer=layer
        self.textures=self.textures or {}; self.textures[#self.textures+1]=texture
        return texture
    end
    return w
end
CreateFrame = function() return widget() end
InCombatLockdown = function() return combat end
GetTime = function() return now end
UIParent = widget(); UIParent:SetSize(2560,1440)
hooksecurefunc = function(target, method, fn)
    local original = target[method]
    target[method] = function(self, ...) local result = original(self, ...); fn(self, ...); return result end
end
local V = { db = {enabled=true, modules={}, overrides={}}, Media={mask42="original-mask42",mask32="original-mask32",minimapMask="original-map-mask"} }
VasagoioDB = V.db
function V:RegisterModule(id, spec) modules[id] = spec end
function V:RegisterProfileAdapter(id, spec) adapters[id] = spec end
function V:IsModuleEnabled(id) return self.db.enabled and self.db.modules[id] ~= false and modules[id] ~= nil end
function V:On(event, fn) events[event] = fn end
function V:Report(id,state,detail) self.report = {id,state,detail} end
function V:Refresh(_, id) refreshes = refreshes + 1; self.lastRefreshModule = id end
function V:IsSecret(value) return type(value)=="table" and value.secret == true end
function V:SafeNumber(value)
    if not self:IsSecret(value) and type(value)=="number" and value==value and value~=math.huge and value~=-math.huge then return value end
end
function V:Pixel(value) return value end
function V:CanvasOrigin() return (UIParent:GetWidth()-2560)/2,(UIParent:GetHeight()-1440)/2 end
function V:Font(role) return "native.ttf", ({countdown=18,compactCountdown=16,chat=16})[role] or 14, "" end
function V:StyleText(text, role, color) text.role, text.ink = role, color end
function V:MaskIcon(text, radius) text.maskRadius = radius end
function V:HideArtwork(text) text:SetAlpha(0) end
function V:Surface(frame, alpha, radius) frame.surface=frame.surface or widget(); frame.surface.alpha,frame.surface.radius=alpha,radius; frame.surface:Show(); return frame.surface end
assert(loadfile(root .. "/Tokens.lua"))("vasagoio", V)
assert(loadfile(root .. "/modules/ActionBars.lua"))("vasagoio", V)
assert(loadfile(root .. "/modules/HUD.lua"))("vasagoio", V)

check(adapters.bartender.Prepare() == nil, "Missing Bartender must be unavailable")
check(adapters.prat.Prepare() == nil, "Missing Prat must be unavailable")
check(adapters.sexymap.Prepare() == nil, "Missing SexyMap must be unavailable")
check(adapters.details.Prepare() == nil, "Missing Details must be unavailable")

local actionProfiles, runtimes = {}, {}
for _,id in ipairs({1,3,4,5}) do
    actionProfiles[id] = {position={scale=1}, states={sentinel="preserve"}, buttons=12, enabled=true}
    runtimes[id] = {button_width=45,button_height=45,button_margin=0}
end
actionProfiles[6] = {enabled=true, buttons=12, position={point="BOTTOM",x=-570,y=118},
    states={sentinel="extra-page"},visibility={custom=true,customdata="[combat]show;hide",vehicleui=true}}
actionProfiles[11] = {enabled=true,visibility={custom=true,customdata="[possessbar]show;hide"},states={sentinel="special"}}
local actions = {db={profile={actionbars=actionProfiles}},actionbars=runtimes}
local pet = {db={profile={position={scale=1}}},bar={button_width=30,button_height=30,button_margin=0}}
local art = {db={profile={enabled=true, leftCap="DWARF", position={point="BOTTOM",x=-600,y=57}}}}
MainMenuBarBackpackButton = widget(); MainMenuBarBackpackButton:SetSize(48,48)
local bags = {db={profile={enabled=false,onebag=false,keyring=true,onebagreagents=true,position={point="BOTTOM",x=285,y=50}}}}
local micro = {db={profile={enabled=true,position={point="BOTTOM",x=-24,y=48}}}}
local progress = {db={profile={enabled=true,position={point="BOTTOM",x=0,y=70},width=1425,showReputation=true}}}
local vehicle = {db={profile={enabled=true}}}
Bartender4 = {CONFIG_VERSION=3,db={profile={outofrange="button"},keys={profile="Test"}}}
function Bartender4:GetModule(name) return ({ActionBars=actions,PetBar=pet,BlizzardArt=art,BagBar=bags,MicroMenu=micro,StatusTrackingBar=progress,Vehicle=vehicle})[name] end
Bartender4DB = {profiles={Test=Bartender4.db.profile},namespaces={
    ActionBars={profiles={Test=actions.db.profile}},PetBar={profiles={Test=pet.db.profile}},BlizzardArt={profiles={Test=art.db.profile}},
    BagBar={profiles={Test=bags.db.profile}},MicroMenu={profiles={Test=micro.db.profile}},StatusTrackingBar={profiles={Test=progress.db.profile}},Vehicle={profiles={Test=vehicle.db.profile}}
}}
local function validate(plan)
    check(plan and #plan.changes > 0, "No review plan")
    for _, change in ipairs(plan.changes) do
        local target = _G
        for _,part in ipairs(change.path) do target = rawget(target,part) end
        check(target == change.table, "Snapshot path must resolve to exact target")
    end
end
local function commit(plan)
    validate(plan)
    for _, change in ipairs(plan.changes) do change.table[change.key] = change.value end
end
-- A disabled BagBar still has a valid namespace; review must not enable it
-- merely to inspect native geometry, and native float rounding is harmless.
MainMenuBarBackpackButton:SetSize(45,44.999996)
runtimes[1].button_height=44.999996
pet.bar.button_height=30.000004
check(adapters.bartender.Prepare()~=nil,"Tiny native dimension rounding blocked setup")
check(not bags.db.profile.enabled,"Geometry review enabled the native BagBar")
runtimes[1].button_height=45;pet.bar.button_height=30
local function invalidBackpack(width,height,detail)
    MainMenuBarBackpackButton:SetSize(width,height)
    local plan,reason=adapters.bartender.Prepare()
    check(not plan and reason:find(detail,1,true),"Invalid backpack geometry lacked an actionable measurement: "..tostring(reason))
end
invalidBackpack(0,0,"width=0, height=0")
invalidBackpack(45,48,"width=45, height=48")
invalidBackpack(45,45.01,"width=45, height=45.01")
invalidBackpack(math.huge,45,"width=non-finite")
invalidBackpack(45,0/0,"height=non-finite")
invalidBackpack({secret=true},45,"width=restricted")
MainMenuBarBackpackButton:SetSize(48,48)
local getWidth=MainMenuBarBackpackButton.GetWidth
MainMenuBarBackpackButton.GetWidth=function()error("native getter refused")end
local failed,reason=adapters.bartender.Prepare()
check(not failed and reason:find("measurement failed",1,true),"Native getter error escaped setup review")
MainMenuBarBackpackButton.GetWidth=getWidth
local forbiddenReads=0
MainMenuBarBackpackButton.GetWidth=function(self)forbiddenReads=forbiddenReads+1;return getWidth(self)end
for _,flag in ipairs({true,{secret=true}})do
    MainMenuBarBackpackButton.IsForbidden=function()return flag end
    local plan,why=adapters.bartender.Prepare()
    check(not plan and why:find("refused native size access",1,true),"Forbidden geometry was read")
end
MainMenuBarBackpackButton.IsForbidden=function()error("access refused")end
failed,reason=adapters.bartender.Prepare()
check(not failed and reason:find("refused native size access",1,true),"Forbidden getter error escaped setup review")
check(forbiddenReads==0,"Forbidden size getters were invoked")
MainMenuBarBackpackButton.IsForbidden=nil
MainMenuBarBackpackButton.GetWidth=getWidth
local barPlan = adapters.bartender.Prepare()
validate(barPlan)
check(actionProfiles[1].rows == nil and actionProfiles[1].showgrid == nil and Bartender4.db.profile.outofrange == "button", "Review wrote a profile")
check(progress.db.profile.enabled,"Review hid the old progression bar")
check(art.db.profile.enabled, "Review disabled Blizzard artwork before Apply")
check(actionProfiles[6].visibility.custom and actionProfiles[6].visibility.always==nil and not bags.db.profile.enabled,
    "Review changed legacy-bar visibility before Apply")
commit(barPlan)
check(not art.db.profile.enabled and art.db.profile.leftCap=="DWARF" and art.db.profile.position.x==-600,
    "Legacy Blizzard artwork must be disabled through its reversible owner setting only")
check(bags.db.profile.enabled and bags.db.profile.onebag and not bags.db.profile.keyring and not bags.db.profile.onebagreagents and not micro.db.profile.enabled,
    "One backpack must replace the old bag cluster while the micro menu stays hidden")
near(bags.db.profile.position.scale*48,42)
near(bags.db.profile.position.x+5*bags.db.profile.position.scale,1659)
near(bags.db.profile.position.y-3*bags.db.profile.position.scale,-1390)
check(not progress.db.profile.enabled and progress.db.profile.position.y==70 and progress.db.profile.width==1425 and progress.db.profile.showReputation,
    "Old progression strip must hide through its reversible owner flag without changing display options")
check(actionProfiles[6].visibility.always and not actionProfiles[6].visibility.custom
    and actionProfiles[6].visibility.customdata=="[combat]show;hide" and actionProfiles[6].visibility.vehicleui
    and actionProfiles[6].enabled and actionProfiles[6].states.sentinel=="extra-page" and actionProfiles[6].buttons==12,
    "Hiding an extra bar must preserve its actions, saved expression, enabled state and paging")
check(actionProfiles[11].visibility.custom and actionProfiles[11].visibility.always==nil and vehicle.db.profile.enabled,
    "Special action/vehicle controls must not be hidden by ordinary-bar cleanup")
for column,id in ipairs({1,3,4,5}) do
    local bar = actionProfiles[id]
    local scale = bar.position.scale
    near(45*scale,42); near(bar.padding*scale,8)
    near(bar.position.x+5*scale,859+(column-1)*200)
    near(bar.position.y-3*scale,-1290)
    check(bar.rows==3 and bar.buttons==12, "Native twelve-slot bars must form 4x3 blocks")
    check(bar.showgrid,"A main bar did not retain its empty slots")
    check(bar.states.sentinel=="preserve", "Paging changed")
end
near(pet.bar.button_width*pet.db.profile.position.scale,32)
check(pet.db.profile.showgrid==nil and actionProfiles[6].showgrid==nil,"Main grid visibility leaked into pet/extra bars")
near(10*32+9*8,8*42+7*8)
check(Bartender4.db.profile.outofrange=="none", "Old range tint would compound the overlay")
runtimes[1].button_margin = 1
check(adapters.bartender.Prepare() == nil, "Unknown button margins must not get guessed geometry")
runtimes[1].button_margin = 0
UIParent:SetSize(3440,1440)
local widePlan = adapters.bartender.Prepare()
for _,change in ipairs(widePlan.changes) do
    if change.table == actionProfiles[1].position and change.key == "x" then
        near(change.value + 5*actionProfiles[1].position.scale,859+440)
    end
end
UIParent:SetSize(2560,1440)
events.ACTIONBAR_SLOT_CHANGED()
check(V.lastRefreshModule=="actionBars", "Action slot changes must not rescan all window interiors")
events.PET_BAR_UPDATE()
check(V.lastRefreshModule=="actionBars", "Pet action events must not rescan all window interiors")
local savedArt, savedBags, savedMicro = art, bags, micro
art,bags,micro=nil,nil,nil
local noUtilityPlan = adapters.bartender.Prepare()
validate(noUtilityPlan)
for _, change in ipairs(noUtilityPlan.changes) do
    check(change.table~=savedArt.db.profile and change.table~=savedBags.db.profile and change.table~=savedMicro.db.profile,
        "Missing optional utility modules must not block setup or receive guessed writes")
end
art,bags,micro=savedArt,savedBags,savedMicro
local savedMain = actionProfiles[3]
actionProfiles[3]=nil
local missingOK, missingPlan, missingReason = pcall(adapters.bartender.Prepare)
check(missingOK and missingPlan==nil and type(missingReason)=="string",
    "An uninitialized main bar must explain why setup is unavailable without an API error")
actionProfiles[3]=savedMain
local savedVisibility=actionProfiles[6].visibility
actionProfiles[6].visibility=nil
check(adapters.bartender.Prepare()==nil,"An enabled extra bar with unknown visibility must not receive guessed settings")
actionProfiles[6].enabled=false
validate(adapters.bartender.Prepare())
actionProfiles[6].enabled=true; actionProfiles[6].visibility=savedVisibility

Prat = {db={keys={profile="Test"}},Addon={}}
local font = {db={keys={profile="Test"},profile={size={ChatFrame1=12},fontface="Original"}}}
function font:IsEnabled() return true end
function Prat.Addon:GetModule(name, silent) check(silent,"Prat lookup must allow missing modules"); if name=="Font" then return font end end
Prat3DB = {namespaces={Prat_Font={profiles={Test=font.db.profile}}}}
font.db.sv=Prat3DB.namespaces.Prat_Font
local pratPlan = adapters.prat.Prepare(); validate(pratPlan)
check(font.db.profile.fontface=="Original", "Prat review changed font")
commit(pratPlan)
check(font.db.profile.size.ChatFrame1==16 and font.db.profile.fontface=="Arial Narrow", "Native chat font plan")

UnitNameUnmodified = function() return "Example" end
GetRealmName = function() return "Realm" end
C_AddOns={GetAddOnMetadata=function(addon) return ({SexyMap="v12.1.7",Details="#Details.20261109.15410.172"})[addon] end}
SexyMap = {}
SexyMap2DB = {["Example-Realm"]={core={},borders={backdrop={},borders={sentinel=true}},zonetext={},clock={}}}
local mapPlan = adapters.sexymap.Prepare(); validate(mapPlan)
check(SexyMap2DB["Example-Realm"].core.scale==nil, "Map review changed geometry")
commit(mapPlan)
local map = SexyMap2DB["Example-Realm"]
near(map.core.scale*140,216)
near(map.core.x*map.core.scale,2336)
near(map.core.y*map.core.scale,-7)
check(map.core.shape==V.Media.minimapMask and map.core.clamp==false,"Map crop must preserve square projection without owner clamp")
check(map.zonetext.bgColor.a==0 and map.clock.bgColor.a==0,"Map labels must not compound their backdrop")
check(next(map.zonetext.fontColor)==nil, "Zone relationships must retain native colors")
near(216+16+248,480)

local instance = {baseframe=widget(),bg_alpha=.7,posicao={normal={w=300,h=200}},libwindow={},attribute_text={},row_info={texts={},space={},row_offsets={}}}
for i=1,4 do instance.row_info.texts[i]={font={face="Other",size=13,outline="OUTLINE"},color={byClass=true}} end
function instance:ChangeSkin(value) self.refreshed = true; check(value==nil, "Do not replace the owner's skin") end
instance.skin="Test"
Details = {tabela_instancias={instance},skins={Test={instance_cprops={row_info={space={left_noborder=2,right_noborder=-3}}}}}}
Details.class_colors={ENEMY={1,0,0},ARENA_GREEN={0,1,0}}
for class in pairs(V.Tokens.class) do Details.class_colors[class]={1,1,1} end
function Details:GetInstance(id) return self.tabela_instancias[id] end
instance.baseframe.fullWindowFrame=widget()
local originalEnemy=Details.class_colors.ENEMY
local meterPlan = adapters.details.Prepare(); validate(meterPlan)
check(instance.posicao.normal.w==300 and not instance.refreshed, "Meter review caused mutations")
commit(meterPlan)
check(Details.class_colors.MAGE[1]==V.Tokens.class.MAGE[1] and Details.class_colors.ENEMY==originalEnemy,"Details palette must use shared classes and preserve semantic colors")
check(instance.posicao.normal.w==248 and instance.posicao.normal.h==154 and instance.titlebar_height==32, "Meter total envelope must include its title")
check(instance.libwindow.x==2072 and instance.libwindow.y==8, "Meter placement")
check(instance.row_info.space.left+instance.row_info.row_offsets.left==8 and instance.row_info.space.right+instance.row_info.row_offsets.right==-16,"Native sidebar normalization must preserve both row insets")
check(instance.row_info.height==24 and instance.row_info.space.between==4 and instance.row_info.font_size==16,"Meter shared row rhythm")
check(instance.row_info.texts[1].color.byClass and not instance.row_info.texts[2].color.byClass and not instance.row_info.texture_class_colors,"Meter class names with neutral values/fills")
check(instance.bg_alpha==0 and not instance.refreshed, "Meter review must not invoke a broad live skin refresh")
check(instance.row_info.texts[1].font.face==nil and instance.row_info.texts[1].font.outline=="", "Meter typography inheritance")

local function cooldown()
    local cd = widget()
    cd.start,cd.duration,cd.text = 90000,60000,widget()
    function cd:GetCooldownTimes() return self.start,self.duration end
    function cd:GetCountdownFontString() return self.text end
    function cd:SetSwipeColor(...) self.swipe = {...} end
    function cd:SetSwipeTexture(path) self.swipeTexture = path end
    function cd:SetUseCircularEdge(value) self.circular = value end
    function cd:SetDrawEdge(value) self.edge = value end
    function cd:SetDrawBling(value) self.bling = value end
    function cd:SetHideCountdownNumbers(value) self.hideNumbers = value end
    cd.OnCooldownDone = function() end
    return cd
end
local button = widget()
button.icon,button.HotKey,button.Count,button.cooldown = widget(),widget(),widget(),cooldown()
button.NormalTexture,button.SlotBackground,button.Border,button.CheckedTexture,button.SpellActivationAlert=widget(),widget(),widget(),widget(),widget()
local fallbackNormal=widget()
function button:GetNormalTexture() return fallbackNormal end
local originalDone = button.cooldown.OnCooldownDone
BT4Button1 = button
local empty=widget(); empty.icon,empty.HotKey,empty.Count=widget(),widget(),widget();empty.icon:Hide()
BT4Button2=empty
local extra=widget();extra.icon=widget();extra.icon:Hide();BT4Button13=extra
local callbacks={}
local lab={RegisterCallback=function(_, event, callback) callbacks[event]=callback end}
LibStub=function(name) if name=="LibActionButton-1.0" then return lab end end
check(modules.actionBars.Apply(), "Action style did not apply")
local function placeholder(b)
    for _,texture in ipairs(b.textures or {}) do if texture.drawLayer=="BACKGROUND" then return texture end end
end
local emptySlot=placeholder(empty)
check(emptySlot and emptySlot.shown and emptySlot.maskRadius==10 and emptySlot.color[4]==V.Tokens.alpha.emptySlot and emptySlot.color[1]==V.Tokens.colors.emptySlot[1],
    "Empty main slot lacks the faint rounded background")
check(not placeholder(button).shown and placeholder(extra)==nil,"Occupied/extra button gained an empty slot")
check(button.NormalTexture.alpha==0 and button.SlotBackground.alpha==0 and fallbackNormal.alpha==0,
    "Native decorative action chrome remained")
check(button.Border.alpha==1 and button.CheckedTexture.alpha==1 and button.SpellActivationAlert.alpha==1,
    "Equipped/checked/proc feedback was hidden")
local priorRefreshes,priorFonts=refreshes,button.HotKey.fontWrites
empty.icon:Show();callbacks.OnButtonUpdate("OnButtonUpdate",empty)
check(not emptySlot.shown and refreshes==priorRefreshes and button.HotKey.fontWrites==priorFonts,
    "Slot fill update repainted other buttons or refreshed modules")
empty.icon:Hide();callbacks.OnButtonUpdate("OnButtonUpdate",empty)
check(emptySlot.shown,"Emptied slot did not regain its background")
empty.icon.IsShown=function()return {secret=true}end
callbacks.OnButtonUpdate("OnButtonUpdate",empty)
check(not emptySlot.shown,"Restricted visibility was inferred")
empty.icon.IsShown=function(self)return self.shown end
V.profileReloadPending=true;callbacks.OnButtonUpdate("OnButtonUpdate",empty)
check(not emptySlot.shown,"Pending setup refreshed stale owner buttons")
V.profileReloadPending=nil
combat=true;callbacks.OnButtonUpdate("OnButtonUpdate",empty)
check(emptySlot.shown and V.lastRefreshModule=="actionBars","Combat slot update did not defer cosmetic geometry")
combat=false
check(button.HotKey.alpha==0 and button.Count.point[1]=="TOPRIGHT", "Active cooldown placement")
check(button.Count.point[4]==6 and button.Count.point[5]==8, "Active count sits outside the top-right edge")
check(button.cooldown.text.fontSize==18 and button.cooldown.text.point[1]=="CENTER", "Centered cooldown18")
check(button.cooldown.OnCooldownDone==originalDone, "Native cooldown handler replaced")
check(button.cooldown.swipeTexture==V.Media.mask42 and not button.cooldown.circular, "Full-icon rounded swipe")
near(.12+(1-.12)*button.cooldown.swipe[4],.8)
near(button.icon.color[1],.92)
button.cooldown.duration = 1500
V.actionButtonTicker.OnUpdate(nil,.2)
check(button.HotKey.alpha==1 and button.Count.point[1]=="BOTTOMRIGHT", "GCD should not hide keys")
button.cooldown.duration = {secret=true}
V.actionButtonTicker.OnUpdate(nil,.2)
check(button.HotKey.alpha==1, "Restricted cooldown caused derived hotkey state")
button.outOfRange = {secret=true}
V.actionButtonTicker.OnUpdate(nil,.2)
local aura = widget(); aura.icon,aura.Duration,aura.Count = widget(),widget(),widget()
check(V:StyleAura(aura,{}), "Aura presentation unavailable")
check(aura.vasagoioSignal==nil, "Ordinary buff received a harmful signal")
V:StyleAura(aura,{signal="dispel"})
check(aura.vasagoioSignal.shown and aura.vasagoioSignal.height==3, "Known dispel bottom signal")
V:StyleAura(aura,{signal={secret=true}})
check(not aura.vasagoioSignal.shown, "Restricted aura classification received a signal")

ChatFrame1 = widget()
modules.hud.Apply()
check(ChatFrame1.point==nil, "HUD moved before setup review")
commit(adapters.hudLayout.Prepare())
modules.hud.Apply()
check(ChatFrame1.width==464 and ChatFrame1.height==106, "Chat input and header belong inside the 480x186 surface")
local oldPoint = ChatFrame1.point
combat=true; modules.hud.Apply(); modules.actionBars.Apply()
check(ChatFrame1.point==oldPoint, "HUD geometry changed during combat")
combat=false
modules.meter.Apply()
check(instance.baseframe.fullWindowFrame.surface.alpha==.4 and instance.baseframe.fullWindowFrame.surface.radius==10, "Meter outer surface")
modules.actionBars.Disable()
check(button.HotKey.alpha==1, "Disabled module left key hidden")
check(not emptySlot.shown,"Disabled module left placeholders visible")
callbacks.OnButtonUpdate("OnButtonUpdate",empty)
check(not emptySlot.shown,"Owner callback restyled disabled action bars")

-- External utility presentation uses explicit references and its own guard.
modules.utilityBars={defaultEnabled=true}
V.db.modules.actionBars=false
local utility=widget();utility.scale=2
local icon,key,timer,cd=widget(),widget(),widget(),cooldown()
local nativeTextWrites=0
function timer:SetText(value) self.value=value;nativeTextWrites=nativeTextWrites+1 end
local opts={owner="utilityBars",icon=icon,hotkey=key,timer=timer,cooldown=cd}
utility.flashTex,utility.holdBadge,utility.rotationIcon=widget(),widget(),widget()
check(V:StyleActionButton(utility,opts),"Utility styles depended on actionBars being enabled")
check(timer.fontSize==9 and timer.point[1]=="CENTER" and timer.ink==V.Tokens.colors.iconText,"Utility timer is not scale-aware icon text")
check(key.point[4]==-1 and key.point[5]==-1 and utility.icon==nil and utility.HotKey==nil,"Utility styling added aliases or wrong local offsets")
timer:SetText("12m")
check(timer.value=="12m" and nativeTextWrites==1 and key.alpha==0,"Utility styling replaced native timer content or retained a duplicate hotkey")
timer:SetText("");check(key.alpha==1,"Utility hotkey did not return when native timer cleared")
timer:SetText({secret=true});check(key.alpha==1,"Restricted utility timer was inspected")
check(utility.flashTex.alpha==1 and utility.holdBadge.alpha==1 and utility.rotationIcon.alpha==1,"Utility queue/rotation overlays were altered")
V:ClearActionButtonStyle(utility);timer:SetText("2m");check(key.alpha==1,"Suspended utility hook still hid hotkeys")
V.db.modules.utilityBars=false
check(not V:StyleActionButton(utility,opts),"Disabled utility module accepted styling")
V.db.modules.utilityBars=nil;V.db.modules.actionBars=nil
combat=true;check(not V:StyleActionButton(utility,opts),"Utility geometry was changed in combat");combat=false
local isForbidden=utility.IsForbidden
utility.IsForbidden=function()error("native access refused")end
check(not V:StyleActionButton(utility,opts),"Refused native utility access escaped its guard")
utility.IsForbidden=function()return {secret=true}end
check(not V:StyleActionButton(utility,opts),"Restricted forbidden flag was used")
utility.IsForbidden=isForbidden

-- Real FUF integration: owner pools, including native container records.
modules.unitframes = {defaultEnabled=true}
UnitFullName = function() return "Example", "Realm" end
C_AddOns = {GetAddOnMetadata=function() return "0.79.1" end}
ForeverUnitFrames = {}
ForeverUnitFramesDB = {active={["Example-Realm"]="vasagoio"}}
local function auraButton()
    local result = widget()
    result.icon,result.count,result.cooldown,result.border = widget(),widget(),cooldown(),widget()
    result.cooldown.duration = {secret=true}
    return result
end
local plainBuff, harmful, dispel, freeBuff = auraButton(),auraButton(),auraButton(),auraButton()
ForeverUnitFrames_player = widget()
ForeverUnitFrames_player.auras = {buffs={buttons={plainBuff},free={buttons={freeBuff}}}}
ForeverUnitFrames_player.auraContainers = {debuffs={buttons={{button=harmful,own=false}}},dispels={buttons={{button=dispel,own=false}}}}
local poolTick, poolCancelled
C_Timer = {After=function(_,fn) fn() end,NewTicker=function(_,fn) poolTick=fn;return {Cancel=function() poolCancelled=true end} end}
C_UnitAuras = setmetatable({}, {__index=function() error("Aura data must never be queried by presentation") end})
assert(loadfile(root .. "/modules/Auras.lua"))("vasagoio",V)
check(modules.auras.Apply(), "FUF aura adapter failed")
check(plainBuff.vasagoioSignal==nil and freeBuff.vasagoioSignal==nil, "Normal/own buffs marked harmful")
check(harmful.vasagoioSignal.shown and dispel.vasagoioSignal.shown, "Owner harmful/dispel group signals missing")
near(harmful.vasagoioSignal.color[1],V.Tokens.colors.danger[1])
near(dispel.vasagoioSignal.color[1],V.Tokens.colors.information[1])
check(dispel.cooldown.text.point[1]=="BOTTOM" and dispel.cooldown.text.fontSize==14, "Aura countdown must be Friz bottom-inside")
check(dispel.border.alpha==0, "Solid aura outline remained")
local late = auraButton()
table.insert(ForeverUnitFrames_player.auras.buffs.buttons,late)
poolTick()
check(late.icon.maskRadius==10, "New owner pool button not discovered")
local refused = auraButton()
function refused:IsForbidden() return true end
table.insert(ForeverUnitFrames_player.auras.buffs.buttons,refused)
check(not modules.auras.Apply(), "Forbidden aura widget was styled")
check(refused.icon.maskRadius==nil, "Restricted aura widget was mutated")
combat=true
local unstyled = auraButton()
table.insert(ForeverUnitFrames_player.auras.buffs.buttons,unstyled)
poolTick()
check(unstyled.icon.maskRadius==nil, "Aura pool mutated during combat")
combat=false
events.PLAYER_REGEN_ENABLED()
check(unstyled.icon.maskRadius==10, "Aura pool did not restyle after combat")
local pendingButton = auraButton()
table.insert(ForeverUnitFrames_player.auras.buffs.buttons,pendingButton)
V.profileReloadPending = true
poolTick()
check(pendingButton.icon.maskRadius==nil, "Pending profile reload styled stale owner widgets")
V.profileReloadPending = nil
modules.auras.Disable()
check(not harmful.vasagoioSignal.shown, "Disabled aura signals remained")
check(poolCancelled, "Disabled aura module left a discovery ticker active")
print("HUD tests passed: reviewed paths, owner geometry, preserved slots, secret guards, cooldown state and aura semantics")
