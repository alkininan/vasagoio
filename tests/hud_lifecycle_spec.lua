-- Offline owner-widget contract: geometry, scoped callbacks and reversible art.
local root=(arg and arg[1]) or "."
local combat,writes,refreshes=false,0,0
local modules,adapters,named={},{},{}
local function eq(a,b,msg) assert(a==b,msg or (tostring(a).." ~= "..tostring(b))) end
local function near(a,b) assert(math.abs(a-b)<.00001) end
local function widget(parent,kind)
    local o={parent=parent,kind=kind or "Frame",width=140,height=140,alpha=1,scale=1,shown=true,
        points={},font={"original.ttf",12,"OUTLINE"},wrap=true,lines=0,hit={1,2,3,4},color={.2,.8,.3,1},
        backdrop={.1,.2,.3,.7},border={.2,.3,.4,.8}}
    function o:SetSize(w,h) writes=writes+1;self.width,self.height=w,h end
    function o:SetWidth(w) writes=writes+1;self.width=w end
    function o:SetHeight(h) writes=writes+1;self.height=h end
    function o:GetWidth() return self.width end
    function o:GetHeight() return self.height end
    function o:SetPoint(...) writes=writes+1;self.points[#self.points+1]={...} end
    function o:ClearAllPoints() writes=writes+1;self.points={} end
    function o:GetPoint(i) return unpack(self.points[i or 1]) end
    function o:GetNumPoints() return #self.points end
    function o:SetAlpha(v) writes=writes+1;self.alpha=v end
    function o:GetAlpha() return self.alpha end
    function o:GetEffectiveScale() return self.scale end
    function o:GetParent() return self.parent end
    function o:GetName() return self.name end
    function o:GetFrameLevel() return 3 end
    function o:SetFrameLevel(v) self.level=v end
    function o:SetFrameStrata(v) self.strata=v end
    function o:Show() self.shown=true end
    function o:Hide() self.shown=false end
    function o:IsShown() return self.shown end
    function o:SetFont(...) writes=writes+1;self.font={...} end
    function o:GetFont() return unpack(self.font) end
    function o:SetTextColor(...) self.color={...} end
    function o:SetSpacing(v) self.spacing=v end
    function o:GetSpacing() return self.spacing or 2 end
    function o:SetWordWrap(v) self.wrap=v end
    function o:GetWordWrap() return self.wrap end
    function o:SetMaxLines(v) self.lines=v end
    function o:GetMaxLines() return self.lines end
    function o:GetObjectType() return self.kind end
    function o:GetRegions() return unpack(self.regions or {}) end
    function o:GetHitRectInsets() return unpack(self.hit) end
    function o:SetHitRectInsets(...) self.hit={...} end
    function o:GetBackdropColor()return unpack(self.backdrop)end
    function o:GetBackdropBorderColor()return unpack(self.border)end
    function o:SetBackdropColor(...)self.backdrop={...}end
    function o:SetBackdropBorderColor(...)self.border={...}end
    return o
end
UIParent=widget();UIParent.width,UIParent.height=2560,1440
CreateFrame=function(_,name,parent) local o=widget(parent);if name then named[name]=o end;return o end
InCombatLockdown=function()return combat end
local hookCount=0
hooksecurefunc=function(object,method,callback)
    if type(object)=="string" then callback,method,object=method,object,_G end
    local original=object[method];hookCount=hookCount+1
    object[method]=function(...)local result=original(...);callback(...);return result end
end
local versions={SexyMap="v12.1.7",Details="#Details.20261109.15410.172",["Prat-3.0"]="3.9.117",ForeverUnitFrames="0.81.1"}
C_AddOns={GetAddOnMetadata=function(addon)return versions[addon]end}
UnitNameUnmodified=function()return "Example"end
GetRealmName=function()return "Realm"end
local V={db={enabled=true,modules={},overrides={hudLayout=true}},Media={minimapMask="own-map-mask"}}
function V:RegisterModule(id,spec)modules[id]=spec end
function V:RegisterProfileAdapter(id,spec)adapters[id]=spec end
function V:IsModuleEnabled(id)return self.db.enabled and self.db.modules[id]~=false end
function V:IsSecret(v)return type(v)=="table" and v.secret end
function V:SafeNumber(v)if type(v)=="number" then return v end end
function V:Pixel(v)return v end
function V:CanvasOrigin()return 0,0 end
function V:Font(role)return "native.ttf",self.Tokens.typography[role].size,"" end
function V:Refresh(_,id)refreshes=refreshes+1;self.lastRefresh=id end
function V:Surface(frame,alpha,radius)
    frame.surface=frame.surface or widget(frame)
    frame.surface.alpha,frame.surface.radius=alpha,radius;frame.surface:Show();return frame.surface
end
local controls={}
V.InteriorSkin={}
function V.InteriorSkin:Hide(object) object:SetAlpha(0) end
function V.InteriorSkin:Text() end
function V.InteriorSkin:Control(frame,kind) controls[frame]=kind end
function V.InteriorSkin:SetSelected(frame,value) frame.selected=value end
function V.InteriorSkin:Restore() end
SexyMap={ExitHUD=function()end,zonetext={UpdateLayout=function()end},clock={UpdateLayout=function()end}}
SexyMap2DB={["Example-Realm"]={core={shape=V.Media.minimapMask},buttons={visibilitySettings={LibDBIcon10_Test="always"}}}}
SexyMap.buttons={db=SexyMap2DB["Example-Realm"].buttons,NewFrame=function()end}
local hiddenParent=widget()
function SexyMap.buttons:ChangeFrameVisibility(frame,visibility)
    frame.parent=visibility=="never" and hiddenParent or Minimap
    frame.visibility=visibility
end
Minimap=widget(UIParent);Minimap.scale=216/140
Minimap:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",2336,-7)
local originalMapParent=Minimap.parent
local addonIcon=widget(Minimap);addonIcon.name="LibDBIcon10_Test"
_G["Forever Unit Frames"]=widget(Minimap)
local nativeMail=widget(Minimap)
MiniMapMailFrame=nativeMail
local registry={Test=addonIcon}
local dbIcon={GetButtonList=function()local result={};for name in pairs(registry)do result[#result+1]=name end;return result end,
    GetMinimapButton=function(_,name)return registry[name]end}
LibStub=function(name)if name=="LibDBIcon-1.0"then return dbIcon end end
SexyMapZoneTextButton=widget(Minimap);SexyMapZoneTextButton.scale=216/140
SexyMapZoneTextButton:SetPoint("BOTTOM",Minimap,"TOP",0,0)
local zoneText=widget(SexyMapZoneTextButton,"FontString");SexyMapZoneTextButton.regions={zoneText}
TimeManagerClockButton=widget(Minimap);TimeManagerClockButton.scale=216/140
TimeManagerClockTicker=widget(TimeManagerClockButton,"FontString")
ChatFrame1=widget(UIParent);ChatFrame1:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",20,30)
ChatFrame1EditBox=widget(ChatFrame1);ChatFrame1EditBox:SetPoint("TOPLEFT",ChatFrame1,"BOTTOMLEFT",0,0)
ChatFrame1EditBox.pratFrame=widget(ChatFrame1EditBox);ChatFrame1EditBox.pratFrame.alpha=.9
ChatFrame1Background=widget(ChatFrame1);ChatFrame1Background.alpha=.7
ChatFrame1.PratTextures={widget(ChatFrame1),widget(ChatFrame1)}
ChatFrame1.PratTextures[1].alpha=.35
ChatFrame1.sf=widget(ChatFrame1);ChatFrame1.sf.alpha=.8
local pratFrames={RestorePratTextures=function()ChatFrame1.PratTextures[1]:SetAlpha(.65)end}
Prat={Addon={GetModule=function(_,name)if name=="Frames"then return pratFrames end end}}
ChatFrame1Tab=widget(UIParent);ChatFrame1Tab.Left=widget();ChatFrame1Tab.glow=widget()
SELECTED_DOCK_FRAME=ChatFrame1
FCF_SelectDockFrame=function(frame)SELECTED_DOCK_FRAME=frame end
local nativeClick=function()end;ChatFrame1Tab.OnClick=nativeClick;ChatFrame1EditBox.OnEnterPressed=nativeClick
local instance={bg_alpha=0,titlebar_height=0,titlebar_shown=false,baseframe=widget()}
instance.baseframe.fullWindowFrame=widget(instance.baseframe)
local oldTitleFrame=widget(instance.baseframe)
instance.baseframe.fullWindowFrame:SetPoint("TOPLEFT",oldTitleFrame,"TOPLEFT",0,0)
instance.baseframe.sf=widget(instance.baseframe);instance.baseframe.sf.alpha=.85
instance.baseframe.cabecalho={ball=widget(),modo_selecao=widget(),report=widget(),reset=widget()}
instance.baseframe.rodape={esquerdo=widget()}
local title=widget(instance.baseframe,"FontString")
function instance:GetTitleBarFontString()return {widget=title}end
function instance:RefreshTitleBar()end
function instance:ToolbarMenuButtons()end
function instance:AttributeMenu()end
Details={GetInstance=function()return instance end}
assert(loadfile(root.."/Tokens.lua"))("vasagoio",V)
assert(loadfile(root.."/modules/HUD.lua"))("vasagoio",V)
local baseline=writes
combat=true;eq(modules.hud.Apply(),false);eq(modules.meter.Apply(),false);eq(writes,baseline,"Combat geometry mutation")
combat=false
assert(modules.hud.Apply());assert(modules.meter.Apply())
eq(named.VasagoioMapPanel.width,216);eq(named.VasagoioMapPanel.height,186)
eq(named.VasagoioMapPanel.surface,nil,"Whole map received a second dark surface")
eq(named.VasagoioMapLabel.height,32);eq(named.VasagoioMapLabel.surface.alpha,.4)
eq(named.VasagoioMapLabel.level,Minimap:GetFrameLevel()+2,"Glass surface would render under native map artwork")
eq(SexyMapZoneTextButton.backdrop[4],0);eq(TimeManagerClockButton.backdrop[4],0)
eq(SexyMapZoneTextButton.border[4],0);eq(TimeManagerClockButton.border[4],0)
eq(addonIcon.parent,hiddenParent,"Addon map icon remained visible or clickable")
eq(_G["Forever Unit Frames"].parent,hiddenParent,"Custom FUF launcher escaped registry-only suppression")
eq(nativeMail.parent,Minimap,"Native mail indicator was mistaken for an addon launcher")
eq(Minimap.parent,originalMapParent,"Minimap parent lock was bypassed")
near(Minimap.hit[3],15/(216/140));eq(Minimap.hit[1],0)
near(SexyMapZoneTextButton.width*Minimap.scale,136);near(SexyMapZoneTextButton.height*Minimap.scale,32)
near(zoneText.width*Minimap.scale,136);near(zoneText.font[2]*Minimap.scale,14)
eq(zoneText.wrap,false);eq(zoneText.lines,1);eq(zoneText.color[2],.8,"Zone relationship color changed")
eq(ChatFrame1.shown,true);eq(ChatFrame1.width,464);eq(ChatFrame1.height,106)
eq(ChatFrame1EditBox.height,32);eq(ChatFrame1EditBox.points[1][5],8)
eq(controls[ChatFrame1Tab],"tab");eq(ChatFrame1Tab.selected,true)
eq(ChatFrame1Tab.glow.alpha,1,"New-message notification was removed")
eq(ChatFrame1Tab.OnClick,nativeClick);eq(ChatFrame1EditBox.OnEnterPressed,nativeClick)
eq(ChatFrame1Background.alpha,0)
eq(ChatFrame1.PratTextures[1].alpha,0);eq(ChatFrame1.PratTextures[2].alpha,0);eq(ChatFrame1.sf.alpha,0)
eq(controls[ChatFrame1EditBox],"editbox");eq(ChatFrame1EditBox.pratFrame.alpha,0,"Prat's separate editbox skin remained")
eq(instance.baseframe.surface,nil);eq(instance.baseframe.fullWindowFrame.surface.alpha,.4)
eq(instance.baseframe.sf.alpha,0,"Skinner's extended meter shell remained")
eq(instance.baseframe.fullWindowFrame.points[1][2],instance.baseframe,"Hidden title frame extended meter surface")
eq(title.font[2],12,"Headerless meter restyled a hidden title")
local installedHooks=hookCount
modules.hud.Apply();modules.meter.Apply();eq(hookCount,installedHooks,"Repeated hooks accumulated")
local prior=refreshes
SexyMapZoneTextButton:SetWidth(900);eq(refreshes,prior+1);eq(V.lastRefresh,"hud")
instance:ToolbarMenuButtons();eq(refreshes,prior+2);eq(V.lastRefresh,"meter")
prior=refreshes;pratFrames:RestorePratTextures();eq(refreshes,prior+1,"Prat background replacement was not observed")
assert(modules.hud.Apply());eq(ChatFrame1.PratTextures[1].alpha,0)
local late=widget(Minimap);late.name="LibDBIcon10_Late";registry.Late=late
prior=refreshes;SexyMap.buttons:NewFrame(late);eq(refreshes,prior+1,"Late minimap icon did not request a scoped refresh")
assert(modules.hud.Apply());eq(late.parent,hiddenParent);eq(SexyMap.buttons.db.visibilitySettings[late.name],nil,"Runtime icon suppression wrote an unreviewed owner profile")
-- Callback defers work to the scoped dispatcher; it never relayouts in combat.
combat=true;baseline=writes;instance:RefreshTitleBar();eq(writes,baseline)
combat=false
V.profileReloadPending=true;prior=refreshes;SexyMapZoneTextButton:SetWidth(900);eq(refreshes,prior)
eq(modules.hud.Apply(),false);eq(modules.meter.Apply(),false);V.profileReloadPending=nil
V.readOnly=true;prior=refreshes;instance:RefreshTitleBar();eq(refreshes,prior);eq(modules.hud.Apply(),false);V.readOnly=nil
V.db.modules.hud=false;V.db.modules.meter=false
assert(modules.hud.Disable());assert(modules.meter.Disable())
eq(ChatFrame1.width,140);eq(ChatFrame1.height,140);eq(ChatFrame1.points[1][4],20);eq(ChatFrame1.points[1][5],30)
eq(ChatFrame1.font[1],"original.ttf");eq(ChatFrame1.spacing,2);eq(ChatFrame1Background.alpha,.7)
eq(ChatFrame1.PratTextures[1].alpha,.35);eq(ChatFrame1.sf.alpha,.8)
eq(ChatFrame1EditBox.backdrop[4],.7)
eq(ChatFrame1EditBox.pratFrame.alpha,.9)
eq(SexyMapZoneTextButton.backdrop[4],.7);eq(TimeManagerClockButton.border[4],.8)
eq(addonIcon.parent,Minimap);eq(addonIcon.visibility,"always");eq(late.visibility,"hover")
eq(_G["Forever Unit Frames"].parent,Minimap)
eq(instance.baseframe.sf.alpha,.85);eq(instance.baseframe.fullWindowFrame.points[1][2],oldTitleFrame)
eq(zoneText.width,140);eq(zoneText.wrap,true);eq(zoneText.lines,0)
eq(Minimap.hit[3],3);eq(Minimap.parent,originalMapParent)
eq(named.VasagoioChatPanel.shown,false);eq(named.VasagoioMapPanel.shown,false)
eq(instance.baseframe.fullWindowFrame.surface.shown,false)
prior=refreshes;SexyMapZoneTextButton:SetWidth(777);instance:ToolbarMenuButtons();eq(refreshes,prior,"Disabled callbacks still refresh")
-- A new activation records the then-current owner geometry, not an old baseline.
ChatFrame1:SetSize(333,222);V.db.modules.hud=true;V.db.modules.meter=true
modules.hud.Apply();modules.meter.Apply();modules.hud.Disable();modules.meter.Disable()
eq(ChatFrame1.width,333);eq(ChatFrame1.height,222)
-- A failing owner method releases partial cosmetics and never strands a paint guard.
local originalRegions=SexyMapZoneTextButton.GetRegions
SexyMapZoneTextButton.GetRegions=function()error("owner failure")end
eq(modules.hud.Apply(),false);eq(named.VasagoioChatPanel.shown,false)
SexyMapZoneTextButton.GetRegions=originalRegions
assert(modules.hud.Apply());prior=refreshes
SexyMapZoneTextButton:SetWidth(999);eq(refreshes,prior+1,"Failed apply stranded the HUD painting guard")
assert(modules.meter.Apply());instance.bg_alpha=.7
assert(modules.meter.Apply());eq(instance.baseframe.fullWindowFrame.surface.shown,false,"Profile change left old meter cosmetics")
instance.bg_alpha=0;assert(modules.meter.Apply())
local originalTitle=instance.GetTitleBarFontString
instance.GetTitleBarFontString=function()error("owner failure")end
eq(modules.meter.Apply(),false);eq(instance.baseframe.fullWindowFrame.surface.shown,false)
instance.GetTitleBarFontString=originalTitle;assert(modules.meter.Apply())
prior=refreshes;instance:ToolbarMenuButtons();eq(refreshes,prior+1,"Failed apply stranded the meter painting guard")
SexyMap2DB["Example-Realm"].core.shape="owner-other-shape"
assert(modules.hud.Apply());eq(named.VasagoioMapPanel.shown,false);eq(Minimap.hit[3],3,"Stale map hit crop survived profile change")
-- A refused native restore retains its recovery record for a later safe retry.
assert(modules.hud.Apply())
local nativeSize=ChatFrame1.SetSize
local failOnce=true
ChatFrame1.SetSize=function(self,w,h)
    if failOnce and w==333 then failOnce=false;error("restore temporarily refused")end
    return nativeSize(self,w,h)
end
local stopped,reason=modules.hud.Disable()
eq(stopped,false);assert(reason:find("Reload UI",1,true),"Restoration failure must request truthful cleanup")
assert(modules.hud.Disable());eq(ChatFrame1.width,333,"Failed restoration snapshot was discarded")
ChatFrame1.SetSize=nativeSize
-- Icon restoration uses the owner's public method and retains failed recovery.
SexyMap2DB["Example-Realm"].core.shape=V.Media.minimapMask
assert(modules.hud.Apply())
local visibilitySetter=SexyMap.buttons.ChangeFrameVisibility
local failVisibility=true
SexyMap.buttons.ChangeFrameVisibility=function(self,frame,visibility)
    if frame==addonIcon and visibility~="never" and failVisibility then failVisibility=false;error("owner unavailable")end
    return visibilitySetter(self,frame,visibility)
end
local restored,restoreReason=modules.hud.Disable()
eq(restored,false);assert(restoreReason:find("Reload UI",1,true));eq(addonIcon.parent,hiddenParent)
assert(modules.hud.Disable());eq(addonIcon.parent,Minimap,"Failed icon restoration record was discarded")
SexyMap.buttons.ChangeFrameVisibility=visibilitySetter
-- Both source-reviewed builds preserve the same headerless runtime envelope
-- and reversible native anchors. A newer number alone must not grant support.
for _,version in ipairs({"#Details.20261124.15450.172","#Details.20261109.15410.172"}) do
    versions.Details=version
    assert(modules.meter.Apply(),"Reviewed Details build failed runtime presentation")
    eq(instance.baseframe.fullWindowFrame.points[1][2],instance.baseframe)
    eq(instance.baseframe.fullWindowFrame.surface.alpha,.4)
    assert(modules.meter.Disable())
    eq(instance.baseframe.fullWindowFrame.points[1][2],oldTitleFrame,"Reviewed build failed native anchor restoration")
end
versions.Details="#Details.20261125.15451.172"
eq(modules.meter.Apply(),false,"Unreviewed newer Details build passed runtime gate")
eq(instance.baseframe.fullWindowFrame.surface.shown,false)
versions.SexyMap="unreviewed";versions.Details="unreviewed"
eq(adapters.sexymap.Prepare(),nil);eq(adapters.details.Prepare(),nil)
modules.hud.Apply();eq(named.VasagoioMapPanel.shown,false,"Unreviewed map retained our runtime surface")
eq(modules.meter.Apply(),false)
print("HUD lifecycle tests passed: native geometry, single overlays, bounded labels, callbacks, combat guards and restoration")
