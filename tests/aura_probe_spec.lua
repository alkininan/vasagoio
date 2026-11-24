-- Native rendering is not simulated here: these checks cover ownership,
-- admission, failure cleanup, and declarative group/clip configuration only.
local root = (arg and arg[1]) or "."
local function check(value, message) assert(value, message) end
local function fixture()
    local s = {frames={}, containers={}, messages={}, loads=0, queries=0, loaded={}}
    local env = setmetatable({}, {__index=_G})
    env._G = env
    env.InCombatLockdown = function() return s.combat end
    env.STANDARD_TEXT_FONT = "native.ttf"
    env.Enum = {DurationTextBindingProperty={TotalDuration=4}, LuaCurveType={Step=1}}
    env.AnchorUtil = {FlowLayoutAxis={Horizontal=0}, FlowDirection={Right=1, Down=-1}}
    env.CustomAuraContainerAuraProcessingPolicy = {None=0}
    env.AuraContainerSortMethod, env.AuraContainerSortDirection = {Default=0}, {Normal=0}
    env.CreateColor = function(...) return {...} end
    env.C_StringUtil = {CreateNumericRuleFormatter=function()
        local value={}; function value:SetBreakpoints(points) self.points=points end
        s.formatter=value; return value
    end}
    env.C_CurveUtil = {CreateColorCurve=function()
        return {SetType=function() end, AddPoint=function() end}
    end}
    env.C_DurationUtil={CreateDurationTextBinding=function()
        local t={}
        function t:SetZeroDurationText(value) self.zero=value end
        function t:SetExpiredText(value) self.expired=value end
        s.bindingTemplate=t;return t
    end}
    env.C_AddOns = {
        IsAddOnLoaded=function(name) s.queries=s.queries+1; return s.loaded[name] == true end,
        LoadAddOn=function(name)
            s.loads=s.loads+1; check(name=="Blizzard_AuraContainer", "Wrong native addon loaded")
            if s.loadFailure then return false, "MISSING" end
            s.loaded[name]=true; return true
        end,
    }
    local function widget(kind, parent, template)
        local w = {kind=kind, parent=parent, template=template, shown=true}
        for _,method in ipairs({"SetFont","SetTextColor","SetColorTexture","SetDrawEdge",
            "SetHideCountdownNumbers","SetWordWrap","SetJustifyH","SetAuraProcessingPolicy",
            "SetFlowLayoutAnchorPoint","SetFlowLayoutGrowthDirection","SetFlowLayoutMaximumLineSize"}) do
            w[method]=function(self, ...) self[method .. "Args"]={...} end
        end
        function w:SetSize(width,height) self.width,self.height=width,height end
        function w:SetWidth(width) self.width=width end
        function w:SetPoint(...) self.point={...} end
        function w:ClearAllPoints() self.point=nil end
        function w:SetAllPoints(target) self.allPoints=target end
        function w:SetClipsChildren(value) self.clips=value end
        function w:EnableMouse(value) self.mouse=value end
        function w:SetText(text) self.text=text end
        function w:Show() self.shown=true end
        function w:Hide() self.shown=false end
        function w:CreateTexture() return widget("Texture",self) end
        function w:CreateFontString() return widget("FontString",self) end
        function w:SetFlowLayoutAxis(axis) check(axis==0,"Native flow axis must be enum"); self.axis=axis end
        function w:SetUnit(unit) self.unit=unit end
        function w:SetIcon(icon) self.icon=icon end
        function w:SetDurationCooldown(cooldown) self.cooldown=cooldown end
        function w:SetApplicationCount(count) self.count=count end
        function w:SetDurationText(text,options)
            if s.failGate then error("native binding refused") end
            self.gate,self.binding=text,options
        end
        function w:AddAuraGroup(key,filter,options) self.key,self.filter,self.options=key,filter,options end
        function w:InitializeOne()
            local button=widget("NativeButton",self)
            self.buttons=self.buttons or {}; self.buttons[#self.buttons+1]=button
            self.options.initializeFrame(button)
        end
        function w:SetEnabled(enabled)
            if enabled and s.failEnable then error("native enable refused") end
            if not enabled and s.failHide==self then error("native hide refused") end
            self.enabled=enabled
            if enabled and self.options and not self.buttons then self:InitializeOne() end
        end
        return w
    end
    env.UIParent = widget("Frame")
    env.CreateFrame = function(kind,_,parent,template)
        if kind=="AuraContainer" and s.noTemplate then error("unknown template") end
        local w=widget(kind,parent,template); s.frames[#s.frames+1]=w
        if kind=="AuraContainer" then s.containers[#s.containers+1]=w end
        return w
    end
    env.SlashCmdList=setmetatable({}, {__newindex=function() error("Standalone slash registered") end})
    env.C_UnitAuras=setmetatable({}, {__index=function() error("Aura API queried") end})
    env.hooksecurefunc=function() error("Hook installed") end
    local V={db={enabled=true}}
    function V:Print(message) s.messages[#s.messages+1]=message end
    function V:RegisterModule() error("Probe registered as normal HUD") end
    function V:RegisterProfileAdapter() error("Probe registered as owner") end
    local chunk=assert(loadfile(root .. "/modules/AuraProbe.lua")); setfenv(chunk,env); chunk("vasagoio",V)
    s.V,s.env=V,env
    function s:hasMessage(text)
        for _,message in ipairs(self.messages) do if message:find(text,1,true) then return true end end
    end
    return s
end

local s=fixture()
check(#s.frames==0 and s.loads==0 and s.queries==0,"Module startup performed work")
s.V:AuraProbeCommand("help"); s.V:HideAuraProbe()
check(#s.frames==0 and s.loads==0,"Help/hide allocated the experiment")
s.V:AuraProbeCommand("")
check(s.loads==1 and #s.containers==6,"Manual bare command must load six native views once")
check(s.env.SLASH_VASAGOIOAURAPROBE1==nil,"Standalone alias leaked")
local panel=s.frames[1]
check(panel.template=="DisableUntrustedLayoutScriptsTemplate" and not panel.mouse,"Unsafe outer panel")
for i,c in ipairs(s.containers) do
    check(c.unit=="player" and c.options.maxFrameCount==40,"Wrong unit or unbounded group")
    check(c.filter==(i%2==0 and "HARMFUL" or "HELPFUL"),"Missing helpful/harmful comparison")
    check(c.template=="CustomAuraContainerTemplate","Native container not used")
    local short=i==3 or i==4
    check(short and c.options.candidateFilters.maxDuration==60 or not short and c.options.candidateFilters==nil,
        "Reference/long candidates narrowed or short bound incorrect")
    local b=c.buttons[1]; local clip=b.icon.parent
    check(not b.mouse and not clip.mouse and clip.clips,"Experimental icons accept gameplay clicks or lack clipping")
    check(clip.template=="DisableUntrustedLayoutScriptsTemplate","Clip lacks native layout protection")
    check(b.count.parent==clip and b.icon.allPoints==b and b.cooldown.allPoints==b,"Original icon/count anchors changed")
    if i>=5 then
        check(clip.point[2]==b.gate and clip.point[3]=="TOPRIGHT","Long clipping must follow native glyph")
        check(b.binding.textFormat.formatString=="{}" and b.binding.textFormat.components[1].property==4,
            "Gate must use full native duration binding")
        check(b.binding.binding==s.bindingTemplate and b.binding.binding.zero=="" and b.binding.binding.expired=="",
            "Long test omitted declarative empty zero/expired defaults")
    else check(not b.gate,"Reference/short unexpectedly use experimental clipping") end
end
check(s.formatter.points[2].threshold>60 and s.formatter.points[2].threshold-60==2^-47,"Wrong exact-60 test boundary")
local allocations=#s.frames
s.V:HideAuraProbe(); check(not panel.shown,"Hide left comparison visible")
for _,c in ipairs(s.containers) do check(not c.enabled,"Hide left native processing enabled") end
s.V:AuraProbeCommand("show"); s.V:AuraProbeCommand("reset")
check(#s.frames==allocations and s.loads==1,"Repeated commands recreate native pools")
s.combat=true; s.V:AuraProbeCommand("reset")
check(#s.frames==allocations and s:hasMessage("out of combat"),"Combat reset was not guarded")
s.V.db.enabled=false; s.V.readOnly=true; s.V:AuraProbeCommand("hide")
check(not panel.shown,"Hide unavailable when settings disabled/read-only or in combat")

for _,guard in ipairs({"disabled","readOnly","combat","standalone","alias"}) do
    local f=fixture()
    if guard=="disabled" then f.V.db.enabled=false
    elseif guard=="readOnly" then f.V.readOnly=true
    elseif guard=="combat" then f.combat=true
    elseif guard=="standalone" then f.loaded.VasagoioAuraProbe=true
    else f.env.SLASH_VASAGOIOAURAPROBE1="/vasauraprobe" end
    f.V:AuraProbeCommand("show")
    check(#f.frames==0 and f.loads==0,"Guard permitted native allocation: " .. guard)
end
local f=fixture(); f.loadFailure=true; f.V:AuraProbeCommand("show")
check(#f.frames==0 and f:hasMessage("MISSING"),"Absent native addon not handled")
f.loadFailure=false; f.V:AuraProbeCommand("show")
check(#f.containers==6,"Native load failure was not retryable")
f=fixture(); f.env.C_AddOns.LoadAddOn=nil; f.V:AuraProbeCommand("show")
check(#f.frames==0 and f:hasMessage("loader unavailable"),"Missing client loader not handled")
for _,failure in ipairs({"noTemplate","failGate","failEnable"}) do
    f=fixture(); f[failure]=true; f.V:AuraProbeCommand("show")
    check(f:hasMessage("Unavailable") and not f:hasMessage("comparison shown"),"Failed build reported success: " .. failure)
    check(not f.frames[1].shown,"Failed comparison remained visible: " .. failure)
    local before=#f.frames; f.V:AuraProbeCommand("show")
    check(#f.frames==before and f:hasMessage("/reload"),"Failed build allocated another pool")
end
f=fixture(); f.V:AuraProbeCommand("show"); f.failGate=true
f.containers[5]:InitializeOne()
check(f:hasMessage("Initializer rejected"),"Later lazy initializer failed silently")
f.failHide=f.containers[1]; f.V:HideAuraProbe()
check(not f.frames[1].shown and not f.containers[6].enabled,"One cleanup failure prevented remaining cleanup")
check(f:hasMessage("native cleanup was refused"),"Partial native cleanup failure was silent")
print("aura_probe_spec: ok (native rendering remains unverified)")
