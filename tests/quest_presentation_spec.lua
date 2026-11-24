local root=(arg and arg[1]) or "."
local combat, version=false,"v4.11.40"
local function check(v,m) assert(v,m) end
local hooks,callbacks={},{}
local childReads,refreshes=0,0
local function widget(name,parent)
    local f={name=name,parent=parent,children={},points={{"TOPRIGHT",nil,"TOPRIGHT",0,-56}},alpha=.8,
        shown=true,click=true,motion=true,wheel=false,scale=1,parentWrites=0,hideCalls=0}
    if parent then parent.children[#parent.children+1]=f end
    function f:GetName() return self.name end
    function f:GetParent() return self.parent end
    function f:SetParent(p)
        assert(not (combat and self.protected),"protected parent write in combat")
        assert(not self.refuseParent,"owner refused parent restoration")
        self.parentWrites=self.parentWrites+1;self.parent=p
    end
    function f:GetChildren() childReads=childReads+1;return unpack(self.children) end
    function f:GetNumPoints() return #self.points end
    function f:GetPoint(i) return unpack(self.points[i]) end
    function f:ClearAllPoints() self.points={} end
    function f:SetPoint(...) self.points[#self.points+1]={...} end
    function f:SetAllPoints() end
    function f:SetSize(w,h) self.width=w;self.height=h end
    function f:GetEffectiveScale() return self.scale end
    function f:IsForbidden() return self.forbidden or false end
    function f:IsProtected() return self.protected or false end
    function f:SetAlpha(a) assert(not (self.refuseAlpha and a~=0),"owner refused alpha restoration");self.alpha=a end
    function f:GetAlpha() return self.alpha end
    function f:Show() self.shown=true end
    function f:Hide() self.shown=false;self.hideCalls=self.hideCalls+1;if self.onHide then self.onHide() end end
    function f:IsShown() return self.shown end
    function f:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function f:SetShown(v) self.shown=v end
    function f:SetEnabled(v) self.enabled=v end
    function f:SetFrameStrata() end
    function f:SetScript(k,v) self[k]=v end
    function f:HookScript(k,v) self[k]=v end
    function f:CreateFontString()
        return {SetAllPoints=function()end,SetText=function(self,t)self.text=t end}
    end
    local function input(self,key,v)
        assert(not (combat and self.protected),"protected mouse write in combat")
        assert(not (self.refuseInput and v),"owner refused input restoration")
        self[key]=v
    end
    function f:IsMouseClickEnabled() return self.click end
    function f:IsMouseMotionEnabled() return self.motion end
    function f:IsMouseWheelEnabled() return self.wheel end
    function f:SetMouseClickEnabled(v) input(self,"click",v) end
    function f:SetMouseMotionEnabled(v) input(self,"motion",v) end
    function f:EnableMouseWheel(v) input(self,"wheel",v) end
    function f:EnableMouse(v) input(self,"click",v);input(self,"motion",v) end
    function f:EnableMouseMotion(v) input(self,"motion",v) end
    return f
end
UIParent=widget("UIParent");UIParent.alpha=1
CreateFrame=function(_,name,parent)local f=widget(name,parent);if name then _G[name]=f end;return f end
hooksecurefunc=function(object,method,hook)
    hooks[object]=hooks[object] or {}
    hooks[object][method]=(hooks[object][method] or 0)+1
    local original=object[method]
    object[method]=function(...)local result={original(...)};hook(...);return unpack(result)end
end
local timers={}
C_Timer={After=function(_,fn)timers[#timers+1]=fn end}
local function drain()local queued=timers;timers={};for _,fn in ipairs(queued)do fn()end end
InCombatLockdown=function()return combat end
GetBuildInfo=function()return "1.60.1","70938" end
GetAddOnMetadata=function()return version end
local V={db={enabled=true,modules={},overrides={}},modules={},adapters={},Tokens={quest={right=8,top=128},alpha={hud=.4},radius=10},reports={}}
VasagoioDB=V.db
function V:IsSecret(v)return type(v)=="table" and v.secret==true end
function V:SafeNumber(v)if type(v)=="number" and v==v and v~=math.huge and v~=-math.huge then return v end end
function V:Pixel(v)return v end
function V:IsModuleEnabled(id)return self.db.enabled and self.db.modules[id]~=false end
function V:RegisterModule(id,spec)self.modules[id]=spec end
function V:RegisterProfileAdapter(id,spec)self.adapters[id]=spec end
function V:On(event,fn)callbacks[event]=fn end
function V:Refresh()refreshes=refreshes+1 end
function V:Surface()end
function V:StyleText()end
function V:Report(id,state,detail)self.reports[id]={state=state,detail=detail}end
local key="Test"
local profile={framePositions={RXPFrame={{"TOPRIGHT","UIParent","TOPRIGHT",0,-56}}},showEnabled=true,hideGuideWindow=false}
RXPSettings={profiles={Test=profile}}
local settings={profile=profile,GetSettingsDB=function()return key end,LoadFramePositions=function()end}
local guide=widget("RXPFrame",UIParent)
guide.BottomFrame=widget("BottomFrame",guide)
guide.BottomFrame.UpdateFrame=function()end -- Native periodic inactive-step maintenance.
local step=widget("Step",guide);step.wheel=true
local checkbox=widget("Skip",step);checkbox.motion=false
local rxp={RXPFrame=guide,enabledFrames={RXPFrame=guide},player={name="Tester"},isHidden=false,progress=0}
guide.onHide=function()rxp.isHidden=true end
function rxp:GetModule()return settings end
function rxp:SetStep()self.progress=self.progress+1 end
function rxp:SetupGuideWindow()end
function rxp:LoadGuide()end
LibStub=function()return {GetAddon=function()return rxp end}end
local activeItem=widget("ActiveItem",UIParent);activeItem.protected=true
local activeTarget=widget("ActiveTarget",UIParent);activeTarget.protected=true
rxp.enabledFrames.RXPActiveItems=activeItem;rxp.enabledFrames.RXPActiveTargets=activeTarget
ObjectiveTrackerFrame=widget("ObjectiveTrackerFrame",UIParent);ObjectiveTrackerFrame.protected=true
local questItem=widget("QuestItem",ObjectiveTrackerFrame);questItem.protected=true
assert(loadfile(root.."/modules/QuestHUD.lua"))("vasagoio",V)
local module=V.modules.questHUD
check(module.Apply()==false and ObjectiveTrackerFrame.parent==UIParent,"unapplied addon claimed quest presentation")
V.db.overrides.questGuideProfile=key
check(module.Apply(),"reviewed quest presentation did not initialize")
check(not ObjectiveTrackerFrame:IsVisible() and ObjectiveTrackerFrame:IsShown(),"entire native tracker was not hidden through its ancestor")
check(not questItem:IsVisible(),"native quest item remained visible despite explicit entire-tracker hide")
local beforeReads,beforeRefreshes=childReads,refreshes
for _=1,1000 do guide.BottomFrame.UpdateFrame(nil,12) end
check(childReads==beforeReads and refreshes==beforeRefreshes and #timers==0,
    "Periodic inactive-step updates triggered guide traversal or styling")
for _=1,100 do rxp:SetStep();checkbox:SetMouseClickEnabled(true) end
check(#timers==0,"visible guide changes unnecessarily queued visibility traversals")
rxp.progress=0
local parentWrites=ObjectiveTrackerFrame.parentWrites
for _=1,10 do module.Apply()end
check(ObjectiveTrackerFrame.parentWrites==parentWrites,"unchanged setup repeatedly reparented native tracker")
combat=true;callbacks.PLAYER_REGEN_DISABLED()
check(guide.alpha==0 and guide:IsShown() and not rxp.isHidden and guide.hideCalls==0,"combat hiding paused RXP or called Hide")
check(not step.click and not step.motion and not step.wheel and not checkbox.click,"invisible guide controls still intercept mouse")
check(activeItem:IsVisible() and activeItem.click and activeTarget:IsVisible(),"RXP secure items/targets were hidden or changed")
beforeReads,beforeRefreshes=childReads,refreshes
for _=1,1000 do guide.BottomFrame.UpdateFrame(nil,12) end
check(childReads==beforeReads and refreshes==beforeRefreshes and #timers==0,
    "Hidden-guide inactive-step maintenance queued repeated scans")
rxp:SetStep();drain()
check(rxp.progress==1 and not rxp.isHidden,"guide callbacks stopped while hidden")
check(not V:ToggleQuestGuide(),"manual toggle bypassed combat hiding")
-- Native owner writes while hidden must be remembered independently by field.
checkbox:SetMouseClickEnabled(true)
step:EnableMouseWheel(false)
guide:SetAlpha(.65)
check(not checkbox.click and guide.alpha==0,"owner writes exposed hidden presentation")
local new=widget("New step",guide)
rxp:SetStep();rxp:SetStep()
check(#timers==1,"guide callbacks were not coalesced")
drain();check(not new.click and not new.motion,"new invisible step intercepted mouse")
local loaded=widget("New guide control",guide)
rxp:SetupGuideWindow();rxp:LoadGuide();rxp:SetupGuideWindow()
check(#timers==1,"Guide construction callbacks did not coalesce")
drain();check(not loaded.click and not loaded.motion,"New guide controls remained interactive while invisible")
combat=false;callbacks.PLAYER_REGEN_ENABLED()
check(guide.alpha==.65 and guide:IsShown() and not rxp.isHidden,"guide alpha/engine state was not restored")
check(checkbox.click and not checkbox.motion and step.click and step.motion and not step.wheel,"latest owner input states were lost")
check(new.click and new.motion,"new step inputs did not restore")
check(V:ToggleQuestGuide() and V:IsQuestGuideHidden() and guide.alpha==0,"manual guide hiding failed")
check(VasagoioQuestGuideToggle:IsShown(),"hidden guide had no reopen control")
check(V:ToggleQuestGuide() and not V:IsQuestGuideHidden() and guide.alpha==.65,"manual guide reopening failed")
check(not VasagoioQuestGuideToggle:IsShown(),"reopen tag remained over visible guide")
-- Disable is reversible and repeat enable does not install duplicate hooks.
local hookCount=hooks[checkbox].SetMouseClickEnabled
module.Disable()
check(ObjectiveTrackerFrame.parent==UIParent and ObjectiveTrackerFrame:IsVisible(),"disable did not restore native parent/visibility")
check(guide.alpha==.65 and guide:IsShown(),"disable changed guide owner visibility")
checkbox:SetMouseMotionEnabled(true)
check(module.Apply(),"re-enable failed")
check(hooks[checkbox].SetMouseClickEnabled==hookCount,"re-enable duplicated setter hooks")
combat=true;callbacks.PLAYER_REGEN_DISABLED();combat=false;callbacks.PLAYER_REGEN_ENABLED()
check(checkbox.motion,"disabled-time owner change was lost")
-- A profile change during combat restores ordinary presentation immediately,
-- but waits to restore protected native hierarchy until combat ends.
combat=true;callbacks.PLAYER_REGEN_DISABLED()
local other={framePositions={},showEnabled=true}
key="Other";settings.profile=other;RXPSettings.profiles.Other=other
settings:LoadFramePositions();drain()
check(guide.alpha==.65 and guide.click,"profile change left RXP invisible")
check(ObjectiveTrackerFrame.parent~=UIParent,"protected native parent changed in combat")
combat=false;callbacks.PLAYER_REGEN_ENABLED()
check(ObjectiveTrackerFrame.parent==UIParent,"native cleanup did not resume after combat")
-- Unsupported/secure descendants fail open instead of becoming invisible
-- with active click targets; no script/event handlers are replaced.
key="Test";settings.profile=profile;V.db.overrides.questGuideProfile=key
local protected=widget("Unexpected secure guide child",guide);protected.protected=true
check(module.Apply()==false and guide.alpha==.65,"unsupported guide was invisibly retained")
check(protected.click and guide.hideCalls==0,"protected guide controls were modified")
-- Stale queued callbacks from an old profile cannot restore over a new claim.
protected.protected=false
check(module.Apply(),"guide could not recover after unsupported child was removed")
check(V:ToggleQuestGuide(),"manual hide for stale callback test failed")
rxp:SetStep()
key="Other";settings.profile=other;V.db.overrides.questGuideProfile="Other"
check(module.Apply(),"new reviewed profile could not claim presentation")
drain()
check(guide.alpha==0 and not ObjectiveTrackerFrame:IsVisible(),"stale profile callback restored over the active new profile")
module.Disable()
check(guide.alpha==.65 and ObjectiveTrackerFrame.parent==UIParent,"final cleanup did not restore original presentation")
-- Owner restoration failures must retain the old profile claim. Otherwise
-- re-capture would silently treat our zero alpha / disabled input as native.
V.db.overrides.questGuideHidden=false
check(module.Apply(),"restoration fixture could not start")
check(V:ToggleQuestGuide(),"restoration fixture could not hide")
guide.refuseAlpha=true
key="Test";settings.profile=profile;V.db.overrides.questGuideProfile=key
local alphaHooks=hooks[guide].SetAlpha
local restored,reason,state=module.Apply()
check(not restored and state=="pending" and reason:find("Reload UI",1,true),"Failed profile cleanup was not reported")
check(guide.alpha==0 and hooks[guide].SetAlpha==alphaHooks,"Failed cleanup discarded the old presentation claim")
guide.refuseAlpha=false
check(module.Apply(),"Retained alpha restoration could not retry")
check(V:ToggleQuestGuide() and guide.alpha==.65 and guide.click,"Retry adopted hidden alpha or input as the new baseline")
check(V:ToggleQuestGuide(),"input cleanup fixture could not hide")
checkbox.refuseInput=true
key="Other";settings.profile=other;V.db.overrides.questGuideProfile=key
restored,reason,state=module.Apply()
check(not restored and state=="pending" and not checkbox.click,"Failed input cleanup was discarded")
checkbox.refuseInput=false
check(module.Apply() and V:ToggleQuestGuide() and checkbox.click,"Input restoration baseline was lost across retry")
-- Removing a guide root while hidden must not discard its failed alpha restore.
check(V:ToggleQuestGuide(),"retired root fixture could not hide")
guide.refuseAlpha=true
local replacement=widget("ReplacementGuide",UIParent)
rxp.RXPFrame=replacement;rxp.enabledFrames.RXPFrame=replacement
rxp:SetupGuideWindow();drain()
check(guide.alpha==0 and replacement.alpha==.8,"Retired-root failure affected the replacement guide")
guide.refuseAlpha=false
check(module.Apply() and guide.alpha==.65,"Retired root alpha was not retained for retry")
check(V:ToggleQuestGuide() and replacement.alpha==.8,"Replacement root captured an invalid baseline")
-- Native-parent restore is also retained, and cannot be reported as successful.
ObjectiveTrackerFrame.refuseParent=true
restored,reason=module.Disable()
check(not restored and reason:find("Reload UI",1,true) and ObjectiveTrackerFrame.parent~=UIParent,
    "Failed native parent cleanup was reported as complete")
ObjectiveTrackerFrame.refuseParent=false
check(module.Disable() and ObjectiveTrackerFrame.parent==UIParent,"Native parent cleanup could not retry")
print("quest_presentation_spec: guide progress, combat/manual hide, mouse restoration, secure separation, native tracker restore and profile guards passed")
