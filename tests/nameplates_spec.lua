-- Native owner-shaped fixtures; no game/private API or installed files are used.
local modules,adapters,events={},{},{}
local secret={secret=true}
local combat=false
local function widget()
    local t={alpha=1,shown=true,color={1,1,1,1},scale=1,texture="native-border",slices={6,6,6,6},points={{"TOPLEFT",{},"TOPLEFT",0,0},{"BOTTOMRIGHT",{},"BOTTOMRIGHT",0,0}}}
    function t:IsForbidden() return self.forbidden or false end
    function t:SetTextColor(...) self.color={...} end
    function t:GetTextColor() return unpack(self.color) end
    function t:SetVertexColor(...) self.color={...} end
    function t:SetAlpha(v) self.alpha=v end
    function t:GetAlpha() return self.alpha end
    function t:Hide() self.shown=false end
    function t:Show() self.shown=true end
    function t:SetWordWrap(v) self.wrap=v end
    function t:SetTexture(v) self.texture=v end
    function t:GetTexture() return self.texture end
    function t:GetNumPoints() return #self.points end
    function t:GetPoint(i) return unpack(self.points[i]) end
    function t:GetScale() return self.scale end
    function t:GetVertexColor() return unpack(self.color) end
    function t:IsShown() return self.shown end
    function t:SetTextureSliceMargins(...) self.slices={...} end
    function t:GetTextureSliceMargins() return unpack(self.slices) end
    function t:SetScale(v) self.scale=v end
    function t:ClearAllPoints() self.points={} end
    function t:SetPoint(...) self.points=self.points or {};self.points[#self.points+1]={...} end
    function t:SetHeight(v) self.height=v end
    return t
end
hooksecurefunc=function(object,key,fn)
    local old=assert(object[key]);object[key]=function(self,...) old(self,...);fn(self,...) end
end
InCombatLockdown=function() return combat end
C_AddOns={GetAddOnMetadata=function()return "13.3.9"end}
UnitNameUnmodified=function()return "Tester"end
GetRealmName=function()return "Realm"end
C_Timer={After=function(_,fn)fn()end}
local media={files={}}
function media:Register(kind,key,path) self.files[kind..key]=path end
function media:Fetch(kind,key) return self.files[kind..key] end
LibStub=function(name) if name=="LibSharedMedia-3.0" then return media end end
local V={db={enabled=true,modules={}},reports={}}
function V:RegisterModule(id,m)modules[id]=m end
function V:RegisterProfileAdapter(id,a)adapters[id]=a end
function V:On(e,f)events[e]=f end
function V:IsSecret(v)return v==secret end
function V:SafeNumber(v)if not self:IsSecret(v) and type(v)=="number"then return v end end
function V:Pixel(v)return v end
function V:StyleText(t,role,c)self.textWrites=(self.textWrites or 0)+1;t.role=role;t:SetTextColor(unpack(c))end
function V:Surface(frame,alpha,radius,color)
    frame.surface=frame.surface or widget();frame.surface:Show();frame.surface.alpha,frame.surface.radius,frame.surface.color=alpha,radius,color
    return frame.surface
end
function V:MaskIcon()error("Native aura masks must remain with their initializer")end
function V:Report(id,state,detail)self.reports[id]={state=state,detail=detail}end
assert(loadfile("Tokens.lua"))("vasagoio",V)
assert(loadfile("modules/Nameplates.lua"))("vasagoio",V)
ThreatPlatesDB={profileKeys={["Tester - Realm"]="Default"},profiles={Default={
    optionRoleDetectionAutomatic=false,
    Healthbar={EnemyUnitMode="HEALTH",BackgroundOpacity=.8},
    Name={HealthbarMode={Anchor="RIGHT",InsideAnchor=false}},
    StatusText={HealthbarMode={SubtextColorUseHeadline=true,SubtextColorUseSpecific=true}},
    text={AbsorbsAmount=true,AbsorbsPercentage=true},Scale={PixelPerfectUI=true},Appearance={NameplateSize="NORMAL"},
    nameplate={toggle={TargetS=true,NonTargetS=true,NonTargetA=true},scale={EnemyNPC=.8,Boss=1.4}},
    uniqueSettings={Special={useStyle=false,scale=2,sentinel="retain"}},
    AuraWidget={Debuffs={ShowOnlyMine=true},Buffs={ShowDispellable=true}},
}}}
local old=ThreatPlatesDB.profiles.Default
local plan=assert(adapters.nameplates:Prepare())
assert(old.Healthbar.BackgroundOpacity==.8 and old.text.AbsorbsAmount,"Prepare mutated owner")
for _,c in ipairs(plan.changes)do c.table[c.key]=c.value end
local p=ThreatPlatesDB.profiles[ThreatPlatesDB.profileKeys["Tester - Realm"]]
assert(p.optionRoleDetectionAutomatic==false,"Explicit role intent was overwritten")
assert(p.settings.healthbar.texture=="Vasagoio Flat" and media:Fetch("statusbar","Vasagoio Flat")=="Interface\\Buttons\\WHITE8X8",
    "Missing optional Flat media silently restored glossy nameplates")
assert(p.ColorByReaction.HostileNPC.b==V.Tokens.colors.informationFill[3],"Idle hostile NPC still looks like a danger state")
assert(p.settings.dps.threatcolor.HIGH.r==V.Tokens.colors.dangerFill[1] and p.settings.tank.threatcolor.HIGH.b==V.Tokens.colors.informationFill[3],
    "Calm reaction fallback changed native role-aware aggro meanings")
assert(p.Healthbar.BackgroundOpacity==0 and p.Healthbar.BackgroundColor.r==11/255,"Opaque track used wrong transparency/color")
assert(p.settings.castbar.BackgroundOpacity==0 and p.settings.castbar.y==-28)
assert(not p.StatusText.HealthbarMode.SubtextColorUseHeadline and not p.StatusText.HealthbarMode.SubtextColorUseSpecific)
assert(p.Name.HealthbarMode.Anchor=="LEFT" and p.Name.HealthbarMode.InsideAnchor and p.Name.HealthbarMode.Font.Width==120)
assert(p.settings.healthbar.width==224 and p.settings.castbar.width==224)
assert(p.targetWidget.ON and p.targetWidget.theme=="squarethin" and p.targetWidget.r==V.Tokens.colors.information[1],"Selected nameplate retained its thick white border")
assert(p.settings.level.align=="RIGHT" and p.settings.level.show)
local outerLeft=-p.settings.healthbar.width/2-V.Tokens.nameplate.selectionOutset
assert(outerLeft-(p.settings.level.x+p.settings.level.width/2)==2,"Level lost its 2px gap beside the selected outline")
assert(p.settings.eliteicon.show and p.settings.eliteicon.y==0 and p.settings.eliteicon.x-p.settings.eliteicon.scale/2== -outerLeft+2,
    "Rare/elite indicator is not beside the right edge")
assert(p.Name.HealthbarMode.FriendlyUnitMode=="CUSTOM" and p.Name.HealthbarMode.Font.Size==16)
assert(p.StatusText.HealthbarMode.Font.Size==14 and p.text.amount and p.text.full and not p.text.truncate and not p.text.AbsorbsAmount)
assert(p.Scale.PixelPerfectUI==false and p.Appearance.NameplateSize=="BIG" and p.nameplate.scale.Boss==1 and not p.nameplate.toggle.NonTargetA)
assert(p.settings.castnostop.ShowInterruptShield and not p.settings.castborder.show,"Borderless cast lost native shield")
assert(p.uniqueSettings.Special.sentinel=="retain" and p.AuraWidget.Debuffs.ShowOnlyMine,"Gameplay rules were discarded")
assert(p.AuraWidget.Debuffs.ModeIcon.Duration.Anchor=="BOTTOM" and p.AuraWidget.Debuffs.ModeIcon.Duration.Font.Size==14)
assert(p.AuraWidget.CrowdControl.ModeIcon.Duration.Font.Color.r==240/255 and p.AuraWidget.CrowdControl.ModeIcon.Duration.Font.flags=="")
assert(p.AuraWidget.Buffs.ModeIcon.IconWidth==28 and not p.AuraWidget.FlashWhenExpiring)
local ccLeft=p.settings.healthbar.width/2+p.AuraWidget.CrowdControl.HealthbarMode.HorizontalOffset
assert(ccLeft>=p.settings.eliteicon.x+p.settings.eliteicon.scale/2+8,"Crowd-control icons overlap the rare/elite indicator")
local aura={Icon=widget(),DispelBorder=widget()}
aura.DispelBorder:Hide()
local container={}
function container:GetAuraGroupFrameCount(key)return key=="main" and 1 or 0 end
function container:GetAuraGroupFrame()return aura end
local health=widget();health.Background=widget()
local frame={PlateStyle="HealthbarMode",unit={type="PLAYER",class="MAGE"},
    visual={NameText=widget(),Healthbar=health,SpellText=widget(),Castbar={CastTime=widget()}},
    widgets={Auras={DebuffsAuraContainer=container}}}
local plate={TPFrame=frame}
C_NamePlate={GetNamePlates=function()return{plate}end,GetNamePlateForUnit=function()return plate end}
assert(modules.nameplates:Apply())
assert(frame.visual.NameText.color[1]==V.Tokens.class.MAGE[1],"Player name lacks class color")
modules.nameplates:Disable()
assert(frame.visual.NameText.color[1]==1,"Immediate disable did not restore initial native name ink")
assert(modules.nameplates:Apply())
frame.visual.NameText:SetTextColor(.5,.2,.1,1)
assert(frame.visual.NameText.color[1]==V.Tokens.class.MAGE[1],"Owner threat update recolored player name")
frame.unit.type="NPC";frame.visual.NameText:SetTextColor(.5,.2,.1,1)
assert(frame.visual.NameText.color[1]==V.Tokens.colors.text[1],"NPC name inherited threat/reaction color")
assert(frame.visual.SpellText.color[1]==V.Tokens.colors.text[1] and frame.visual.Castbar.CastTime.role=="compact")
assert(health.surface.alpha==1 and health.surface.radius==10 and health.Background.alpha==0)
assert(aura.DispelBorder.height==3 and aura.DispelBorder.color[1]==V.Tokens.colors.danger[1])
assert(aura.DispelBorder.slices[1]==0,"Bottom marker retained native border slice margins")
assert(aura.DispelBorder.points[1][4]==6 and aura.DispelBorder.points[1][5]==-2,"Bottom marker occupied wrong bounds")
-- Reusing the same pooled native button for a different group must repaint it.
frame.widgets.Auras.DebuffsAuraContainer=nil;frame.widgets.Auras.BuffsAuraContainer=container
local textWrites=V.textWrites
events.UNIT_AURA("UNIT_AURA","nameplate1")
assert(not aura.DispelBorder.shown,"Native pool reuse retained a harmful marker on an ordinary buff")
assert(V.textWrites==textWrites,"Aura event repeated unrelated nameplate font writes")
frame.widgets.Auras.BuffsAuraContainer=nil;frame.widgets.Auras.DebuffsAuraContainer=container
events.UNIT_AURA("UNIT_AURA","nameplate1")
assert(aura.DispelBorder.shown)
local nativeAfter=C_Timer.After
local queued={};C_Timer.After=function(_,fn)queued[#queued+1]=fn end
events.UNIT_AURA("UNIT_AURA","nameplate1");events.UNIT_AURA("UNIT_AURA","nameplate1")
assert(#queued==1,"Repeated aura updates were not coalesced per unit")
events.NAME_PLATE_UNIT_ADDED("NAME_PLATE_UNIT_ADDED","nameplate1")
assert(#queued==1,"Plate creation scheduled a duplicate callback")
queued[1]()
assert(V.textWrites>textWrites,"A full plate update was lost behind an aura-only callback")
C_Timer.After=nativeAfter
local originalColor={};C_ClassColor={GetClassColor=function(value)
    assert(value==secret);return{GetRGBA=function()return secret,secret,secret,1 end}
end}
frame.unit.type,frame.unit.class="PLAYER",secret
frame.visual.NameText:SetTextColor(1,1,1,1)
assert(frame.visual.NameText.color[1]==secret,"Restricted class color was inspected or dropped instead of sent to native text")
frame.unit.class="MAGE"
modules.nameplates:Disable()
assert(not health.surface.shown and health.Background.alpha==1 and not aura.DispelBorder.shown,"Disable left cosmetic surface/signal active")
assert(aura.DispelBorder.texture=="native-border" and aura.DispelBorder.points[1][1]=="TOPLEFT","Disable did not restore native marker geometry/artwork")
assert(aura.DispelBorder.slices[1]==6,"Disable did not restore native slice margins")
frame.visual.NameText:SetTextColor(.2,.3,.4,1)
assert(frame.visual.NameText.color[1]==.2,"Disabled module still repaints")
assert(modules.nameplates:Apply() and aura.DispelBorder.shown,"Re-enable did not restore marker")
p.uniqueSettings.Special.useStyle=true
assert(modules.nameplates:Apply()==false,"Conflicting custom scale reported ready")
p.uniqueSettings.Special.useStyle=false
p.nameplate.scale.Boss=1.2
assert(modules.nameplates:Apply()==false and not health.surface.shown,"Changed owner geometry silently passed")
p.nameplate.scale.Boss=1
assert(modules.nameplates:Apply())
-- A newly pooled aura that refuses cosmetic access remains native and reports a limit.
local forbidden=widget();forbidden.forbidden=true
container.GetAuraGroupFrame=function()return forbidden end
assert(modules.nameplates:Apply()==false and V.reports.nameplateAuras.state=="pending")
container.GetAuraGroupFrame=function()return aura end
assert(modules.nameplates:Apply())
local styleText=V.StyleText
V.StyleText=function()error("native presentation refused")end
assert(not modules.nameplates:Apply() and V.reports.nameplatePresentation.state=="pending","Refused native styling silently reported ready")
V.StyleText=styleText
assert(modules.nameplates:Apply())
local selected=ThreatPlatesDB.profileKeys["Tester - Realm"]
ThreatPlatesDB.profileKeys["Tester - Realm"]="Default"
frame.visual.NameText:SetTextColor(.3,.4,.5,1)
assert(not health.surface.shown and health.Background.alpha==1 and frame.visual.NameText.color[1]==.3,"Owner profile switch retained cosmetics or overwrote new owner ink")
ThreatPlatesDB.profileKeys["Tester - Realm"]=selected
assert(modules.nameplates:Apply())
ThreatPlatesDB.profiles[selected]={}
events.UNIT_AURA("UNIT_AURA","nameplate1")
assert(not health.surface.shown and not aura.DispelBorder.shown,"Same-name profile replacement retained cosmetics")
ThreatPlatesDB.profiles[selected]=p
assert(modules.nameplates:Apply())
combat=true;ThreatPlatesDB.profileKeys["Tester - Realm"]="Default"
frame.visual.NameText:SetTextColor(.6,.4,.5,1)
assert(health.surface.shown,"Combat ownership change rewrote native layout")
combat=false;events.PLAYER_REGEN_ENABLED()
assert(not health.surface.shown and health.Background.alpha==1,"Deferred profile cleanup did not run")
ThreatPlatesDB.profileKeys["Tester - Realm"]=selected
assert(modules.nameplates:Apply())
combat=true;local prior=aura.DispelBorder.color
assert(pcall(events.UNIT_AURA,"UNIT_AURA","nameplate1"))
assert(aura.DispelBorder.color==prior,"Combat aura event rebuilt native cosmetics")
combat=false
V.db.enabled=false
frame.visual.NameText:SetTextColor(.4,.2,.1,1)
assert(frame.visual.NameText.color[1]==.4,"Global off did not guard name hooks")
print("Nameplate tests passed: profile semantics, role intent, native color sinks, scoped cosmetics, owner overrides and restrictions")
