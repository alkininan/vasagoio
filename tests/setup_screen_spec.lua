-- Exercise the actual setup window's user interactions without opening WoW.
-- Geometry checks use simulated font metrics, not native pixel-rendering proof.
local root = (arg and arg[1]) or "."
local combat, preparations, applications, reloads = false, 0, 0, 0
local widgets, callbacks, messages = {}, {}, {}
local methods = {}
local function widget(kind, name, parent, template)
    local object = setmetatable({kind=kind, name=name, parent=parent, template=template,
        shown=true, enabled=true, width=0, height=0, points={}, scripts={}, children={}, text="", fontSize=16}, {__index=methods})
    widgets[#widgets+1]=object
    if parent then parent.children[#parent.children+1]=object end
    return object
end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:SetPoint(point, relative, relativePoint, x, y)
    if type(relative)=="number" then x,y,relative,relativePoint=relative,relativePoint,self.parent,point end
    self.points[#self.points+1]={point,relative or self.parent,relativePoint or point,x or 0,y or 0}
end
function methods:ClearAllPoints() self.points={} end
function methods:SetAllPoints(target) self.allPoints=target or self.parent end
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event,fn)
    local original=self.scripts[event]
    self.scripts[event]=function(...) if original then original(...) end;fn(...) end
end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:SetShown(v) self.shown=v end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetEnabled(v) self.enabled=v end
function methods:IsEnabled() return self.enabled end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:GetParent() return self.parent end
function methods:GetName() return self.name end
function methods:GetEffectiveScale() return 1 end
function methods:SetText(value) self.text=value or "" end
function methods:GetText() return self.text end
function methods:SetAutoFocus(value) self.autoFocus=value end
function methods:SetMultiLine(value) self.multiline=value end
function methods:SetMaxLetters(value) self.maxLetters=value end
function methods:SetFocus() self.focused=true end
function methods:ClearFocus() self.focused=false end
function methods:HighlightText() self.highlighted=self.text end
function methods:SetFont(path,size,flags) self.font,self.fontSize,self.fontFlags=path,size,flags end
function methods:GetFont() return self.font or "native.ttf",self.fontSize,self.fontFlags or "" end
function methods:SetTextColor(...) self.color={...} end
function methods:SetAlpha(value) self.alpha=value end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetVertexColor(...) self.color={...} end
function methods:SetTexture(path) self.texture=path end
function methods:SetTexCoord(...) self.texCoords={...} end
function methods:SetJustifyH(value) self.justify=value end
function methods:SetJustifyV(value) self.justifyV=value end
function methods:SetWordWrap(value) self.wordWrap=value end
function methods:SetNonSpaceWrap(value) self.nonSpaceWrap=value end
function methods:SetMaxLines(value) self.maxLines=value end
function methods:SetSpacing(value) self.spacing=value end
function methods:GetStringHeight()
    local columns=math.max(1,math.floor(self.width/(self.fontSize*.5)))
    local lines=0
    for line in (self.text.."\n"):gmatch("([^\n]*)\n") do
        lines=lines+math.max(1,math.ceil(#line/columns))
    end
    return lines*(self.fontSize+(self.spacing or 0))
end
function methods:GetStringWidth() return #self.text*self.fontSize*.5 end
function methods:CreateFontString(name,layer,template) return widget("FontString",name,self,template) end
function methods:CreateTexture(name,layer,template) return widget("Texture",name,self,template) end
function methods:SetScrollChild(body) self.scrollChild=body end
function methods:GetScrollChild() return self.scrollChild end
function methods:SetVerticalScroll(value) self.verticalScroll=value end
function methods:GetVerticalScroll() return self.verticalScroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild.height or 0)-self.height) end
function methods:SetMinMaxValues(low,high) self.minimum,self.maximum=low,high end
function methods:GetMinMaxValues() return self.minimum,self.maximum end
function methods:SetValue(value)
    self.value=value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end
end
function methods:GetValue() return self.value or 0 end
function methods:SetValueStep(value) self.valueStep=value end
function methods:SetObeyStepOnDrag(value) self.obeyStep=value end
function methods:SetOrientation(value) self.orientation=value end
function methods:SetThumbTexture(value) self.thumb=value end
function methods:GetThumbTexture() return self.thumb end
function methods:SetFrameStrata(value) self.strata=value end
function methods:SetFrameLevel(value) self.frameLevel=value end
function methods:GetFrameLevel() return self.frameLevel or 1 end
for _, name in ipairs({"SetClampedToScreen","EnableMouse","EnableMouseWheel","SetMovable","RegisterForDrag",
    "StartMoving","StopMovingOrSizing","SetShadowColor","SetShadowOffset","SetClipsChildren","RegisterForClicks","RegisterEvent"}) do
    methods[name]=function() end
end
CreateFrame=widget
UIParent=widget("Frame","UIParent");UIParent:SetSize(1280,800)
InCombatLockdown=function() return combat end
ReloadUI=function() reloads=reloads+1 end
SlashCmdList={}
C_Timer={After=function() error("Setup screen scheduled a timer") end,
    NewTicker=function() error("Setup screen installed polling") end}
local V={version="test",db={enabled=true,modules={},profileBackups={}},moduleOrder={},status={}}
assert(loadfile(root.."/Tokens.lua"))("vasagoio",V)
function V:IsSecret() return false end
function V:SafeNumber(value) return type(value)=="number" and value or nil end
function V:Pixel(value) return value end
function V:Font() return "native.ttf",16,"" end
function V:StyleText(object,role,color)
    object:SetFont("native.ttf",16,"")
    if color then object:SetTextColor(unpack(color)) end
end
function V:Surface(frame,alpha,radius,color) frame.surface={alpha=alpha,radius=radius,color=color};return frame end
function V:Print(message) messages[#messages+1]=message end
function V:On(event,fn) callbacks[event]=callbacks[event] or {};table.insert(callbacks[event],fn) end
function V:Refresh() error("Setup view started runtime styling") end
function V:CreateToolsView(parent)
    local view=widget("Frame",nil,parent)
    function view:Refresh() self.refreshes=(self.refreshes or 0)+1 end
    return view
end
local blocked, applySucceeds, lastApplied = false, false, nil
local longDetail=string.rep("A readable explanation of an optional component. ",14)
function V:PrepareSetup()
    preparations=preparations+1
    local review={changes={{label="Private internal setting",before="not displayed",after="not displayed"}},adapters={},unavailable={}}
    self.setupReview=review
    return review
end
function V:BuildSetupStatus(review,reason)
    local pending=self.profileReloadPending==true
    return {title=pending and "Reload needed" or blocked and "Needs attention" or "Ready to apply",
        state=pending and "reload" or blocked and "attention" or "ready",
        description=pending and "Changes saved. Reload to activate." or "Check the components, then apply the preset.",
        canApply=not blocked and not pending and review~=nil,
        needsReload=pending,
        rows={{id="units",label="Unit frames",state=blocked and "attention" or "ready",detail=blocked and "Enable FUF and reload." or ""},
            {id="actions",label="Action bars",state="ready",detail=""},
            {id="windows",label="Window skins",state="skipped",detail=longDetail}}}
end
function V:ApplySetup(review)
    applications=applications+1;lastApplied=review
    if applySucceeds then
        self.profileReloadPending=true;self.setupReview=nil
        return true,"Changes saved. Reload to activate."
    end
    return false,"Bartender changed. Review the preset again."
end
assert(loadfile(root.."/core/Options.lua"))("vasagoio",V)
local function check(condition,message) assert(condition,message) end
local function fire(event)
    for _, callback in ipairs(callbacks[event] or {}) do callback(event) end
end
local function click(button)
    local callback=button.scripts.OnClick
    check(type(callback)=="function","Missing button click handler")
    callback(button)
end
V:OpenOptions("setup")
local window=V.options
local screen=window.setup
check(screen and screen:IsShown() and preparations==1,"Opening setup did not prepare one visible review")
check(screen.apply.label:GetText()=="Apply preset" and screen.reload.label:GetText()=="Reload UI","Main actions were not simplified")
local important=0
for _, child in ipairs(screen.children) do
    if child.kind=="Button" and child~=screen.close then
        local label=child.label and child.label:GetText() or child:GetText()
        if label~="" and label~="×" and label~="X" and label~="Close" then important=important+1 end
    end
end
check(important==1 and window.reload.label:GetText()=="Reload UI","Setup contains actions beyond Apply and the shared Reload")
for _, object in ipairs(widgets) do
    check(not object.template or not object.template:find("UIPanel"),"Setup imported native gold panel/button chrome")
end
check(window.surface and window.surface.radius==10,"Setup does not use the shared rounded material")
check(screen.apply:IsEnabled() and screen.reload:IsEnabled(),"Ready state buttons do not allow apply or a manual reload")
check(screen.rows[1].status:GetText()=="Ready to apply","Unapplied component was presented as already applied")
check(screen.summary:GetText():find("Ready",1,true),"Overall readiness was not rendered")
check(screen.rows[3].detail:GetText()==longDetail,"Long actionable explanation was discarded")
check(screen.rows[3]:GetHeight()>=screen.rows[3].detail:GetStringHeight()+24,"Long detail overlaps the next row")
check(screen.body:GetHeight()>=screen.rows[3]:GetHeight(),"Scrollable body does not include expanded rows")
local function anchor(object,name)
    for _, point in ipairs(object.points) do if point[1]==name then return point end end
    error("Missing "..name.." anchor")
end
local scrollBottom=anchor(screen.scroll,"BOTTOMRIGHT")[5]
for _, control in ipairs({screen.apply,screen.reload}) do
    check(anchor(control,"BOTTOMLEFT")[5]+control:GetHeight()<scrollBottom,"Scrollable rows overlap fixed action buttons")
end
local row=screen.rows[1]
check(anchor(row.label,"TOPLEFT")[4]+row.label:GetWidth()+8<=
    row:GetWidth()+anchor(row.status,"TOPRIGHT")[4]-row.status:GetWidth(),"Component label collides with status text")
check(not screen.summary:GetText():find("Private internal",1,true),"Main view leaked individual profile values")
local oldPreparations=preparations
V:RenderSetup()
check(preparations==oldPreparations,"Rendering status re-prepared all profiles")
local shownReview=screen.review
click(screen.apply)
check(applications==1 and lastApplied==shownReview,"Apply replaced the user's reviewed snapshot before writing")
check(screen.description:GetText():find("Bartender changed",1,true),"Apply failure was only reported in chat")
check(reloads==0,"Apply failure reloaded the game")
blocked=true;V:OpenOptions("status")
check(not screen.apply:IsEnabled(),"Missing required HUD still permits Apply")
check(screen.reload:IsEnabled(),"Blocked setup cannot reload to recover an uninitialized owner")
local previousApplications=applications
click(screen.apply)
check(applications==previousApplications,"Disabled Apply handler bypassed readiness gate")
blocked=false;V:OpenOptions("setup")
check(screen.apply:IsEnabled(),"Optional skipped component blocked the core HUD")
combat=true;fire("PLAYER_REGEN_DISABLED")
check(not screen.apply:IsEnabled() and not screen.reload:IsEnabled(),"Entering combat left setup actions enabled")
previousApplications=applications
click(screen.apply);click(screen.reload)
check(applications==previousApplications and reloads==0,"Combat click handlers changed profiles or reloaded")
combat=false;fire("PLAYER_REGEN_ENABLED")
applySucceeds=true
shownReview=screen.review;oldPreparations=preparations
click(screen.apply)
check(lastApplied==shownReview and V.profileReloadPending,"Successful Apply did not retain the reviewed transaction")
check(reloads==0 and not screen.apply:IsEnabled() and screen.reload:IsEnabled(),"Saved state did not require an explicit reload")
check(screen.summary:GetText():find("Reload",1,true),"Saved state did not show reload instruction")
check(preparations==oldPreparations,"Saved state re-prepared profiles before reload")
V:OpenOptions("setup")
check(preparations==oldPreparations,"Reopening pending setup prepared a second transaction")
click(screen.reload)
check(reloads==1,"Explicit Reload UI action did not invoke ReloadUI")
for _, object in ipairs(widgets) do check(not object.scripts.OnUpdate,"Setup introduced an update loop") end

-- Integrate the real policy/transaction/model with the actual window, using
-- harmless initialized owner plans rather than installed game databases.
local queue, missingBartender={},false
C_Timer={After=function(_,fn) queue[#queue+1]=fn end}
local Live={}
for _, file in ipairs({"Core.lua","Tokens.lua","core/Database.lua","core/Profiles.lua","core/SetupStatus.lua","core/Tools.lua","core/Options.lua"}) do
    assert(loadfile(root.."/"..file))("vasagoio",Live)
end
Live.Surface,Live.StyleText,Live.Font=V.Surface,V.StyleText,V.Font
Live.Print=function(_,message) messages[#messages+1]=message end
Live:InitializeDatabase();Live.ready=true
SetupScreenOwnerFixture={}
for _, section in ipairs(Live.SetupSections) do
    for _, moduleId in ipairs(section.modules) do
        if not Live.modules[moduleId] then Live:RegisterModule(moduleId,{Apply=function()return true end}) end
    end
    if section.required then
        for _, adapterId in ipairs(section.adapters) do
            local id=adapterId
            SetupScreenOwnerFixture[id]={value=0}
            Live:RegisterProfileAdapter(id,{Prepare=function()
                if id=="bartender" and missingBartender then return nil,"Bartender profile is not initialized; reload" end
                return {changes={{table=SetupScreenOwnerFixture[id],path={"SetupScreenOwnerFixture",id},key="value",value=1}}}
            end})
        end
    end
end
Live:ApplyModules();Live:OpenOptions("setup")
local liveWindow=Live.options
local liveScreen=liveWindow.setup
check(liveScreen.apply:IsEnabled() and liveScreen.summary:GetText()=="Ready to apply","Real model did not allow complete core with optional integrations skipped")
click(liveScreen.apply)
check(Live.profileReloadPending and liveScreen.reload:IsEnabled() and not liveScreen.apply:IsEnabled(),"Real Apply did not transition the screen to reload state")
check(#Live.db.profileBackups==1,"Real Apply did not preserve a setup snapshot")
Live.profileReloadPending=nil -- Simulate the next UI load for status checks.
Live:ApplyModules();Live:OpenOptions("status")
check(liveScreen.summary:GetText()=="No issues detected" and not liveScreen.apply:IsEnabled(),"Matching saved profiles and active styling were not reported after reload")
missingBartender=true;Live:OpenOptions("setup")
check(liveScreen.summary:GetText()=="Needs attention" and not liveScreen.apply:IsEnabled(),"Real missing-core state was not reflected in the window")
local count=#Live.db.profileBackups
click(liveScreen.apply)
check(#Live.db.profileBackups==count,"Blocked real screen wrote another snapshot")

-- Copy is a native text selection, not a clipboard API or profile mutation.
local originalReview=Live.setupReview
Live:OpenDiagnostics("details")
local diagnostic=liveWindow.diagnostics
check(Live.options==liveWindow and liveWindow.activeTab=="details","Details opened a separate top-level window")
check(diagnostic.copy and diagnostic.copy.label:GetText()=="Copy report","Diagnostics lack a copy entry point")
check(not diagnostic.copyText:IsShown() and not diagnostic.copyText.focused,"Diagnostics captured keyboard focus before copy")
click(diagnostic.copy)
check(diagnostic.copyText:IsShown() and not diagnostic.content:IsShown(),"Copy did not open selectable report text")
check(diagnostic.copyText.multiline and diagnostic.copyText.autoFocus==false,"Copy text does not use a multiline native edit box")
check(diagnostic.copyText.focused and diagnostic.copyText.highlighted==diagnostic.copyText:GetText(),"Copy did not select the full report")
check(diagnostic.copyText:GetText():find("Unavailable: bartender",1,true),"Copy omitted the actual setup blocker")
check(diagnostic.note:GetText():find("Cmd+C",1,true) and not diagnostic.note:GetText():find("Copied",1,true),"Copy falsely claimed clipboard access")
check(Live.setupReview==originalReview and #Live.db.profileBackups==count,"Copy invalidated the reviewed transaction or wrote settings")
diagnostic.copyText.scripts.OnEscapePressed()
check(not liveWindow:IsShown() and not diagnostic.copyText.focused,"Closing copy report retained keyboard focus")
Live:OpenDiagnostics("report")
check(not diagnostic.copyText:IsShown() and diagnostic.content:IsShown(),"Reopening diagnostics retained editable mode")
check(liveWindow.activeTab=="report","Report alias did not select its tab")
local beforeTab=Live.setupReview
click(liveWindow.tabs.perf)
check(liveWindow.activeTab=="perf" and diagnostic.content:GetText():find("not FPS",1,true),"Performance tab omitted timing limitations")
check(Live.setupReview==beforeTab,"Reading Performance invalidated the reviewed Apply transaction")
click(liveWindow.tabs.tools)
check(liveWindow.tools:IsShown() and not diagnostic:IsShown() and not liveScreen:IsShown(),"Tools tab left another pane visible")
click(liveWindow.tools.buttons.restore)
check(liveWindow.tools.confirmSnapshot and #Live.db.profileBackups==count,"First restore click changed settings instead of requesting confirmation")
Live:OpenOptions()
check(not liveWindow.tools.confirmSnapshot,"Leaving Tools retained a restore confirmation")
check(liveWindow.activeTab=="setup" and liveScreen:IsShown() and not liveWindow.tools:IsShown(),"Bare command did not default to Setup")
for _,id in ipairs({"setup","details","report","perf","tools"}) do
    check(liveWindow.tabs[id]~=nil,"Missing navigation tab "..id)
    local tab=liveWindow.tabs[id]
    check(anchor(tab,"TOPLEFT")[4]+tab:GetWidth()<=liveWindow:GetWidth()-Live:Pixel(24)+.001,"Tabs exceed the window edge")
    check(tab.primary==(id=="setup"),"Selected tab marker does not track the visible pane")
end
check(not Live.diagnostics,"Separate diagnostics window was retained")
click(liveScreen.reload)
check(reloads==2,"Blocked setup's explicit Reload action did not invoke ReloadUI")

-- A review shown in Details must remain the transaction used by Apply.
missingBartender=false;SetupScreenOwnerFixture.unitframes.value=0
Live:OpenOptions()
local inspected=Live.setupReview
check(liveScreen.apply:IsEnabled(),"Modified fixture did not offer reviewed setup")
click(liveWindow.tabs.details)
SetupScreenOwnerFixture.unitframes.value=9
click(liveWindow.tabs.setup)
check(Live.setupReview==inspected and liveScreen.review==inspected,"Returning from Details silently replaced the inspected review")
local snapshots=#Live.db.profileBackups
click(liveScreen.apply)
check(#Live.db.profileBackups==snapshots and SetupScreenOwnerFixture.unitframes.value==9,"Apply accepted an intervening owner change after tab navigation")
check(liveScreen.messageFailed and liveScreen.description:GetText():find("changed since review",1,true),"Stale review failure was hidden")
for _,object in ipairs(widgets) do check(not object.scripts.OnUpdate,"Diagnostics introduced polling") end
print("setup_screen_spec: two actions, cached status, combat guards, real setup policy and selectable diagnostics passed")
