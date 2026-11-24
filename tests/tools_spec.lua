-- Exercise Tools callbacks and guards without loading WoW or native owners.
local root=(arg and arg[1])or"."
local combat=false
local widgets={}
local methods={}
local function widget(kind,_,parent,template)
    assert(template==nil,"Tools added a native/gold control template")
    local f=setmetatable({kind=kind,parent=parent,enabled=true,shown=true,scripts={},points={}}, {__index=methods})
    widgets[#widgets+1]=f;return f
end
function methods:SetAllPoints(target)self.allPoints=target end
function methods:SetPoint(...)self.points[#self.points+1]={...}end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:SetWidth(w)self.width=w end
function methods:SetHeight(h)self.height=h end
function methods:SetText(t)self.text=t end
function methods:SetTextColor(...)self.color={...}end
function methods:SetColorTexture(...)self.color={...}end
function methods:SetAlpha(a)self.alpha=a end
function methods:SetJustifyH(v)self.justify=v end
function methods:SetJustifyV(v)self.vertical=v end
function methods:SetWordWrap(v)self.wrap=v end
function methods:SetEnabled(v)assert(type(v)=="boolean");self.enabled=v end
function methods:IsEnabled()return self.enabled end
function methods:SetShown(v)self.shown=v end
function methods:SetScript(event,fn)assert(event~="OnUpdate","Tools installed polling");self.scripts[event]=fn end
function methods:CreateFontString()return widget("FontString",nil,self)end
function methods:CreateTexture()return widget("Texture",nil,self)end
CreateFrame=widget
InCombatLockdown=function()return combat end
ReloadUI=function()error("Tools reloaded without the global Reload control")end
C_Timer={After=function()error("Tools scheduled a timer")end,NewTicker=function()error("Tools installed a ticker")end}
local V={db={enabled=true,profileBackups={{changes={}}}},reports={},calls={aura={},styling={},restore=0}}
function V:Pixel(n)return n end
function V:IsSecret(v)return type(v)=="table"and v.secret end
function V:StyleText(fs,role,c)fs.role,fs.color=role,c end
function V:Surface(frame,alpha,radius,c)frame.surface={alpha=alpha,radius=radius,color=c}end
function V:Report(id,state,detail)self.reports[id]={state=state,detail=detail}end
function V:AuraProbeCommand(command)table.insert(self.calls.aura,command)end
function V:IsQuestGuideHidden()return self.guideHidden==true end
function V:ToggleQuestGuide()
    assert(not combat and not self.readOnly)
    self.calls.guide=(self.calls.guide or 0)+1;self.guideHidden=not self:IsQuestGuideHidden()
    return true,self.guideHidden and "Guide hidden." or "Guide restored."
end
function V:SetEnabled(value)
    assert(not self.readOnly and not combat)
    self.calls.styling[#self.calls.styling+1]=value
    self.db.enabled=value;self.uiReloadPending=true
end
local restoreResult,restoreMessage=true,"Previous settings restored. Reload to finish."
function V:RollbackProfiles()
    assert(not self.readOnly and not combat)
    self.calls.restore=self.calls.restore+1
    if restoreResult=="throw"then error("raw private exception")end
    if restoreResult then table.remove(self.db.profileBackups);self.profileReloadPending=true end
    return restoreResult,restoreMessage
end
assert(loadfile(root.."/Tokens.lua"))("vasagoio",V)
assert(loadfile(root.."/core/Tools.lua"))("vasagoio",V)
assert(#widgets==0,"Loading Tools created a window")
local parent=widget("Frame");local view=V:CreateToolsView(parent)
assert(view.allPoints==parent and type(view.Refresh)=="function"and type(view.CancelConfirmation)=="function")
local function click(key)view.buttons[key].scripts.OnClick(view.buttons[key])end
for _,b in pairs(view.buttons)do
    local p=b.points[1]
    assert(p[1]=="TOPLEFT"and p[2]>=24 and p[2]+b.width<=616 and -p[3]>=120 and -p[3]+b.height<=592,"Tool button exceeds the assigned content bounds")
end
click("auraShow");click("auraReset");click("auraHide")
assert(table.concat(V.calls.aura,",")=="show,reset,hide","Aura buttons did not call the direct API")
assert(view.message.text=="Aura test hide requested.")
click("guide");assert(V.calls.guide==1 and V.guideHidden and view.buttons.guide.label.text=="Show guide")
click("guide");assert(V.calls.guide==2 and not V.guideHidden and view.buttons.guide.label.text=="Hide guide")
-- Confirmation is a separate, visible step and Cancel never mutates settings.
click("restore")
assert(V.calls.restore==0 and view.confirmSnapshot==V.db.profileBackups[1]and view.buttons.restore.label.text=="Confirm restore")
click("cancel");assert(V.calls.restore==0 and not view.confirmSnapshot)
click("restore");click("restore")
assert(V.calls.restore==1 and #V.db.profileBackups==0 and view.message.text==restoreMessage and not view.buttons.restore:IsEnabled())
-- Snapshot replacement between clicks must require another review.
V.db.profileBackups={{changes={}}};view:Refresh();click("restore")
V.db.profileBackups[1]={changes={}}
click("restore")
assert(V.calls.restore==1 and not view.confirmSnapshot and view.message.text:find("snapshot changed",1,true))
click("restore");view.scripts.OnHide();assert(not view.confirmSnapshot)
view.scripts.OnShow();click("restore");view:CancelConfirmation();assert(not view.confirmSnapshot)
-- Combat after the first click is checked again at invocation, not only paint.
view:Refresh();click("restore");combat=true;click("restore")
assert(V.calls.restore==1 and not view.confirmSnapshot)
assert(not view.buttons.auraShow:IsEnabled()and not view.buttons.auraReset:IsEnabled()and not view.buttons.restore:IsEnabled())
click("guide");assert(V.calls.guide==2 and not view.buttons.guide:IsEnabled(),"Guide toggle ignored combat guard")
local auraCount=#V.calls.aura;click("auraHide")
assert(#V.calls.aura==auraCount+1 and V.calls.aura[#V.calls.aura]=="hide","Hide was blocked in combat")
combat=false;V.readOnly=true;view:Refresh()
assert(not view.buttons.stylingOn:IsEnabled()and not view.buttons.stylingOff:IsEnabled()and not view.buttons.restore:IsEnabled())
click("auraShow");click("stylingOff");click("restore")
assert(#V.calls.styling==0 and V.calls.restore==1)
click("auraHide");assert(V.calls.aura[#V.calls.aura]=="hide","Read-only mode blocked Hide")
V.readOnly=false;view:Refresh();click("stylingOff")
assert(V.db.enabled==false and V.calls.styling[1]==false and not view.buttons.auraShow:IsEnabled())
assert(view.buttons.stylingOn:IsEnabled()and view.buttons.restore:IsEnabled(),"Disabled styling blocked recovery controls")
click("stylingOn");assert(V.db.enabled and V.calls.styling[2]==true)
-- Engine conflict/error results remain visible; Tools does not bypass them.
restoreResult=false;restoreMessage="A setting changed after setup. Later edits were preserved."
view:Refresh();click("restore");click("restore")
assert(V.calls.restore==2 and #V.db.profileBackups==1 and view.message.text==restoreMessage and view.failed)
restoreResult="throw";click("restore");click("restore")
assert(V.calls.restore==3 and #V.db.profileBackups==1 and not view.message.text:find("private",1,true))
assert(V.reports.tools.state=="error")
V.AuraProbeCommand=function()error("private native failure")end
click("auraShow");assert(view.message.text:find("request failed",1,true))
V.SetEnabled=function()error("private native failure")end
click("stylingOff");assert(view.message.text:find("could not finish",1,true))
V.db=nil;view:Refresh()
assert(not view.buttons.stylingOn:IsEnabled()and not view.buttons.restore:IsEnabled()and view.buttons.auraHide:IsEnabled())
print("tools_spec: direct callbacks, explicit snapshot confirmation, stale/combat/read-only guards and failure reporting passed")
