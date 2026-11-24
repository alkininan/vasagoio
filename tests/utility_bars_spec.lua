local root=(arg and arg[1]) or "."
local combat,version,writes,refreshes=false,"1.8.19",0,0
UIParent={}
InCombatLockdown=function() return combat end
GetAddOnMetadata=function(name) if name=="ForeverTrinketMenu" then return version end end
hooksecurefunc=function(object,key,callback)
    local original=object[key]
    object[key]=function(...) local result=original(...);callback(...);return result end
end
local function widget(parent,width,height,x,y)
    local f={parent=parent,width=width,height=height,scale=1,points={{"TOPLEFT",parent,"TOPLEFT",x,y}}}
    function f:GetParent()return self.parent end
    function f:GetWidth()return self.width end
    function f:GetHeight()return self.height end
    function f:GetScale()return self.scale end
    function f:GetNumPoints()return #self.points end
    function f:GetPoint(i)return unpack(self.points[i],1,5)end
    function f:SetSize(w,h)writes=writes+1;self.width=w;self.height=h end
    function f:ClearAllPoints()writes=writes+1;self.points={}end
    function f:SetPoint(...)writes=writes+1;self.points[#self.points+1]={...}end
    function f:IsForbidden()return self.forbidden end
    function f:HookScript(event,callback)self[event]=callback end
    return f
end
local bar=widget(UIParent,44,84,50,-100)
local first,second=widget(bar,36,36,4,-4),widget(bar,36,36,4,-44)
ForeverTrinketMenuFrame,ForeverTrinketMenuSlot1,ForeverTrinketMenuSlot2=bar,first,second
TrinketMenuDB={horizontal=true,scale=1,locked=false,showSlot13=true,showSlot14=true,
    windowPosition={point="TOPLEFT",relativePoint="TOPLEFT",x=50,y=-100}}
local V={db={enabled=true,overrides={},modules={}},modules={},adapters={}}
function V:IsSecret(v)return type(v)=="table" and v.secret end
function V:SafeNumber(v)if type(v)=="number" and v==v and math.abs(v)<math.huge then return v end end
function V:Pixel(v)return v end
function V:CanvasOrigin()return 0,0 end
function V:IsModuleEnabled(id)return self.db.enabled and self.db.modules[id]~=false end
function V:RegisterModule(id,spec)self.modules[id]=spec end
function V:RegisterProfileAdapter(id,spec)self.adapters[id]=spec end
function V:Refresh(_,id)assert(id=="utilityBars");refreshes=refreshes+1 end
function V:StyleActionButton(button,options)assert(options.owner=="utilityBars");button.styled=true;return true end
function V:ClearActionButtonStyle(button)button.styled=false end
assert(loadfile(root.."/Tokens.lua"))("vasagoio",V)
local function reload()assert(loadfile(root.."/modules/UtilityBars.lua"))("vasagoio",V)end
reload()
local adapter=V.adapters.trinkets
local plan=assert(adapter.Prepare())
assert(writes==0 and not V.db.overrides.utilityLayout,"Review changed live settings")
assert(not V.modules.utilityBars.Apply() and writes==0,"Applied without reviewed setup")
for _,change in ipairs(plan.changes)do change.table[change.key]=change.value end
adapter.AfterApply()
assert(not V.modules.utilityBars.Apply() and writes==0,"Applied geometry before owner reload")
bar.scale=TrinketMenuDB.scale;reload()
assert(V.modules.utilityBars.Apply())
assert(bar.width*bar.scale==42 and math.abs(bar.height*bar.scale-92)<.00001)
assert(math.abs(bar.points[1][4]*bar.scale-1659)<.00001 and math.abs(bar.points[1][5]*bar.scale-150)<.00001)
assert(second.points[1][4]==0 and math.abs(second.points[1][5]*bar.scale+50)<.00001)
assert(first.styled and second.styled and refreshes==0,"Layout recursively invalidated itself")
local before=writes
for _=1,100 do assert(V.modules.utilityBars.Apply())end
assert(writes==before,"Unchanged utilities repeatedly wrote geometry")
-- Lua saved-number formatting and native float geometry need not round identically.
-- A correctly applied preset must not fall back to the owner's 4px inset/gap.
local savedScale,savedX=TrinketMenuDB.scale,TrinketMenuDB.windowPosition.x
TrinketMenuDB.scale=savedScale+4e-8
TrinketMenuDB.windowPosition.x=savedX+2e-5
bar.scale=bar.scale+3e-8
bar.width=bar.width+2e-6;bar.height=bar.height-3e-6
first.points[1][4]=2e-6;second.points[1][5]=second.points[1][5]+3e-6
for _=1,100 do assert(V.modules.utilityBars.Apply(),"Native rounding rejected an aligned utility preset") end
assert(writes==before,"Native rounding caused repeated geometry writes")
TrinketMenuDB.scale=savedScale;TrinketMenuDB.windowPosition.x=savedX
bar.scale=savedScale
-- 1.8.20 retains the same appearance/layout contract. Updating this owner must
-- accept a fresh review without changing unrelated mount/rotation settings.
version="1.8.20"
TrinketMenuDB.autoQueueEnabled,TrinketMenuDB.charClick=true,true
local reviewed=assert(V.adapters.trinkets.Prepare())
assert(writes==before,"Updated-owner review mutated native widgets")
for _,change in ipairs(reviewed.changes)do
    assert(change.key~="autoQueueEnabled" and change.key~="charClick","Cosmetic update changed owner features")
end
assert(V.modules.utilityBars.Apply() and writes==before,"Updated owner failed or rewrote unchanged geometry")
assert(TrinketMenuDB.autoQueueEnabled and TrinketMenuDB.charClick,"Updated owner feature settings were overwritten")

combat=true;assert(not V.modules.utilityBars.Apply() and writes==before)
combat=false;V.modules.utilityBars.Disable()
assert(bar.width==44 and bar.height==84 and first.points[1][4]==4 and second.points[1][5]==-44)
assert(not first.styled and not second.styled)
assert(V.modules.utilityBars.Apply())
local acceptedScale=TrinketMenuDB.scale
TrinketMenuDB.scale=acceptedScale+.01
assert(not V.modules.utilityBars.Apply() and bar.width==44,"A real user scale override was accepted as rounding")
TrinketMenuDB.scale=acceptedScale
assert(V.modules.utilityBars.Apply())
bar:SetPoint("BOTTOM",UIParent,"BOTTOM",0,20)
V.modules.utilityBars.Disable()
assert(#bar.points==2,"Disable overwrote a later user/owner position")
-- Restore a clean owner layout for rollback and failure tests.
bar.points={{"TOPLEFT",UIParent,"TOPLEFT",50,-100}};bar.width=44;bar.height=84
local original=second.SetPoint
local failed=false
second.SetPoint=function(self,...)
    if not failed then failed=true;error("native write refused")end
    return original(self,...)
end
assert(not pcall(V.modules.utilityBars.Apply))
assert(bar.width==44 and first.points[1][4]==4 and second.points[1][5]==-44,"Partial failure did not roll back")
second.SetPoint=original
-- Both an initial write and its rollback can fail. Retain original geometry
-- before any successful full application so Disable can retry safely.
local firstSize=bar.SetSize
bar.SetSize=function(self,w,h)if w==44 then error("initial rollback refused")end;return firstSize(self,w,h)end
failed=false
second.SetPoint=function(self,...)
    if not failed then failed=true;error("initial write refused")end
    return original(self,...)
end
assert(not pcall(V.modules.utilityBars.Apply) and bar.width==36)
bar.SetSize,second.SetPoint=firstSize,original
V.modules.utilityBars.Disable()
assert(bar.width==44 and bar.height==84,"Initial double failure lost recoverable geometry")
local style=V.StyleActionButton
V.StyleActionButton=function()error("native font unavailable")end
assert(not pcall(V.modules.utilityBars.Apply) and bar.width==44,"Style failure retained geometry or an applying lock")
V.StyleActionButton=style
assert(V.modules.utilityBars.Apply())
V.StyleActionButton=function()return false end
local applied,_,state=V.modules.utilityBars.Apply()
assert(not applied and state=="pending","Rejected presentation reported complete")
V.StyleActionButton=style
-- A refused cleanup retains enough state to retry; it is not silently lost.
local nativeSize=bar.SetSize
bar.SetSize=function(self,w,h) if w==44 then error("cleanup refused")end;return nativeSize(self,w,h)end
assert(not pcall(V.modules.utilityBars.Disable),"Refused cleanup reported success")
bar.SetSize=nativeSize
V.modules.utilityBars.Disable()
assert(bar.width==44 and bar.height==84,"Cleanup retry lost the original geometry")
assert(V.modules.utilityBars.Apply())
version="future";before=writes
assert(not V.modules.utilityBars.Apply() and bar.width==44,"Unknown owner retained our geometry")
assert(V.adapters.trinkets.Prepare()==nil,"Unknown version accepted")
version="1.8.19";first.forbidden=true
assert(V.adapters.trinkets.Prepare()==nil,"Forbidden native widget accepted")
first.forbidden=false;combat=true
assert(V.adapters.trinkets.Prepare()==nil,"Combat review accepted")
print("utility_bars_spec: native geometry, review/reload, no idle writes, conflict preservation and partial-failure restoration passed")
