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
    function w:SetFont(path, size, flags) self.font,self.fontSize,self.fontFlags = path,size,flags end
    function w:SetJustifyH(value) self.justify = value end
    function w:SetFrameStrata(value) self.strata = value end
    function w:SetSpacing(value) self.spacing = value end
    function w:SetScript(event, fn) self[event] = fn end
    function w:CreateTexture() return widget() end
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
local V = { db = {enabled=true, modules={}, overrides={}}, Media={mask42="original-mask42",mask32="original-mask32"} }
VasagoioDB = V.db
function V:RegisterModule(id, spec) modules[id] = spec end
function V:RegisterProfileAdapter(id, spec) adapters[id] = spec end
function V:IsModuleEnabled(id) return self.db.enabled and self.db.modules[id] ~= false and modules[id] ~= nil end
function V:On(event, fn) events[event] = fn end
function V:Report(id,state,detail) self.report = {id,state,detail} end
function V:Refresh() refreshes = refreshes + 1 end
function V:IsSecret(value) return type(value)=="table" and value.secret == true end
function V:SafeNumber(value) if not self:IsSecret(value) and type(value)=="number" then return value end end
function V:Pixel(value) return value end
function V:CanvasOrigin() return (UIParent:GetWidth()-2560)/2,(UIParent:GetHeight()-1440)/2 end
function V:Font(role) return "native.ttf", ({countdown=18,compactCountdown=16,chat=16})[role] or 14, "" end
function V:StyleText(text, role) text.role = role end
function V:MaskIcon(text, radius) text.maskRadius = radius end
function V:HideArtwork(text) text:SetAlpha(0) end
function V:Surface(frame, alpha, radius) frame.surface={alpha=alpha,radius=radius} end
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
local actions = {db={profile={actionbars=actionProfiles}},actionbars=runtimes}
local pet = {db={profile={position={scale=1}}},bar={button_width=30,button_height=30,button_margin=0}}
Bartender4 = {CONFIG_VERSION=3,db={profile={outofrange="button"},keys={profile="Test"}}}
function Bartender4:GetModule(name) return ({ActionBars=actions,PetBar=pet})[name] end
Bartender4DB = {profiles={Test=Bartender4.db.profile},namespaces={
    ActionBars={profiles={Test=actions.db.profile}},PetBar={profiles={Test=pet.db.profile}}
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
local barPlan = adapters.bartender.Prepare()
validate(barPlan)
check(actionProfiles[1].rows == nil and Bartender4.db.profile.outofrange == "button", "Review wrote a profile")
commit(barPlan)
for column,id in ipairs({1,3,4,5}) do
    local bar = actionProfiles[id]
    local scale = bar.position.scale
    near(45*scale,42); near(bar.padding*scale,8)
    near(bar.position.x+5*scale,884+(column-1)*200)
    near(bar.position.y-3*scale,-1290)
    check(bar.rows==3 and bar.buttons==12, "Native twelve-slot bars must form 4x3 blocks")
    check(bar.states.sentinel=="preserve", "Paging changed")
end
near(pet.bar.button_width*pet.db.profile.position.scale,32)
near(10*32+9*8,8*42+7*8)
check(Bartender4.db.profile.outofrange=="none", "Old range tint would compound the overlay")
runtimes[1].button_margin = 1
check(adapters.bartender.Prepare() == nil, "Unknown button margins must not get guessed geometry")
runtimes[1].button_margin = 0
UIParent:SetSize(3440,1440)
local widePlan = adapters.bartender.Prepare()
for _,change in ipairs(widePlan.changes) do
    if change.table == actionProfiles[1].position and change.key == "x" then
        near(change.value + 5*actionProfiles[1].position.scale,884+440)
    end
end
UIParent:SetSize(2560,1440)

Prat = {db={keys={profile="Test"}}}
local font = {db={profile={size={ChatFrame1=12},fontface="Original"}}}
function Prat:GetModule(name) if name=="Font" then return font end end
Prat3DB = {namespaces={Font={profiles={Test=font.db.profile}}}}
local pratPlan = adapters.prat.Prepare(); validate(pratPlan)
check(font.db.profile.fontface=="Original", "Prat review changed font")
commit(pratPlan)
check(font.db.profile.size.ChatFrame1==16 and font.db.profile.fontface=="Arial Narrow", "Native chat font plan")

UnitNameUnmodified = function() return "Example" end
GetRealmName = function() return "Realm" end
SexyMap = {}
SexyMap2DB = {["Example-Realm"]={core={},borders={backdrop={},borders={sentinel=true}},zonetext={},clock={}}}
local mapPlan = adapters.sexymap.Prepare(); validate(mapPlan)
check(SexyMap2DB["Example-Realm"].core.scale==nil, "Map review changed geometry")
commit(mapPlan)
local map = SexyMap2DB["Example-Realm"]
near(map.core.scale*140,154)
near(map.core.x*map.core.scale,2367)
check(next(map.zonetext.fontColor)==nil, "Zone relationships must retain native colors")
near(216+16+248,480)

local instance = {baseframe=widget(),bg_alpha=.7,posicao={normal={w=300,h=200}},libwindow={},row_info={texts={}}}
for i=1,4 do instance.row_info.texts[i]={font={face="Other",size=13,outline="OUTLINE"}} end
function instance:ChangeSkin(value) self.refreshed = true; check(value==nil, "Do not replace the owner's skin") end
Details = {tabela_instancias={instance}}
function Details:GetInstance(id) return self.tabela_instancias[id] end
local meterPlan = adapters.details.Prepare(); validate(meterPlan)
check(instance.posicao.normal.w==300 and not instance.refreshed, "Meter review caused mutations")
commit(meterPlan)
check(instance.posicao.normal.w==248 and instance.posicao.normal.h==186, "Meter body geometry")
check(instance.libwindow.x==2072 and instance.libwindow.y==8, "Meter placement")
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
local originalDone = button.cooldown.OnCooldownDone
BT4Button1 = button
check(modules.actionBars.Apply(), "Action style did not apply")
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
check(ChatFrame1.width==464 and ChatFrame1.height==146, "Chat inset within 480x186 surface")
local oldPoint = ChatFrame1.point
combat=true; modules.hud.Apply(); modules.actionBars.Apply()
check(ChatFrame1.point==oldPoint, "HUD geometry changed during combat")
combat=false
modules.meter.Apply()
check(instance.baseframe.surface.alpha==.4 and instance.baseframe.surface.radius==10, "Meter outer surface")
modules.actionBars.Disable()
check(button.HotKey.alpha==1, "Disabled module left key hidden")

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
