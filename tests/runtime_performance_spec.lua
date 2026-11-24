-- Reproduce the event amplification that repainted every window during play.
local root = (arg and arg[1]) or "."
local queue, combat = {}, false
CreateFrame = function()
    return {RegisterEvent=function() end, SetScript=function(self, _, fn) self.dispatch=fn end}
end
UIParent = {GetWidth=function() return 2560 end, GetHeight=function() return 1440 end,
    GetEffectiveScale=function() return 1 end}
InCombatLockdown = function() return combat end
C_Timer = {After=function(delay, fn) assert(delay > 0, "Refresh used an immediate per-frame loop");queue[#queue+1]=fn end}
local V = {}
assert(loadfile(root .. "/Core.lua"))("vasagoio", V)
V.ready, V.db = true, {enabled=true,modules={}}
local function flush()
    local pending=queue;queue={}
    for _, fn in ipairs(pending) do fn() end
end
local calls = {actionBars=0,nativeWindows=0,addonWindows=0}
local reentrant, lateWidget, lateStyled
local clock=0
GetTime=function()return 10 end
debugprofilestop=function()return clock end
for _, id in ipairs({"actionBars","nativeWindows","addonWindows"}) do
    local name=id
    V:RegisterModule(name,{Apply=function()
        calls[name]=calls[name]+1
        clock=clock+2
        if reentrant then
            if lateWidget then lateStyled=true else lateWidget=true end
            V:Refresh("fixture owner redraw",name)
        end
        return true
    end})
end
for _=1,100 do V:Refresh("action slots changed","actionBars");flush() end
assert(calls.actionBars==100 and calls.nativeWindows==0 and calls.addonWindows==0,
    "100 action events amplified into native/addon window scans")
assert(#queue==0, "Idle action callback left a refresh queued")
reentrant=true
V:Refresh("owner creates late widget","actionBars");flush()
reentrant=false
assert(calls.actionBars==102 and lateStyled and #queue==0,
    "Late widget was dropped or synchronous owner callbacks created an unbounded loop")
local timing=V.runtimeStats.modules.actionBars
assert(timing.calls==102 and timing.timedCalls==102 and timing.totalMs==204 and timing.maxMs==2 and timing.errors==0,
    "Per-application runtime timings do not match the isolated module work")
for _=1,100 do V:Refresh("burst","nativeWindows") end
V:Refresh("second owner","addonWindows")
assert(#queue==1, "A burst allocated one timer per request")
flush()
assert(calls.nativeWindows==1 and calls.addonWindows==1 and calls.actionBars==102,
    "Coalescing lost an owner or refreshed unrelated modules")
combat=true
V:Refresh("window in combat","nativeWindows");flush()
assert(calls.nativeWindows==1 and V.pending,"Combat refresh was not deferred")
combat=false
V.events.dispatch(nil,"PLAYER_REGEN_ENABLED");flush()
assert(calls.nativeWindows==2 and calls.actionBars==102 and calls.addonWindows==1,
    "Combat resume broadened scoped invalidation")
V:Refresh("manual all-module refresh");flush()
assert(calls.nativeWindows==3 and calls.addonWindows==2 and calls.actionBars==103,
    "Explicit global refresh no longer reached every module")
V.db.modules.nativeWindows=false
V:Refresh("disabled owner","nativeWindows");flush()
assert(calls.nativeWindows==3 and V.status.nativeWindows.state=="disabled")

V:RegisterModule("fault",{Apply=function() clock=clock+3;error("expected runtime fixture error") end})
geterrorhandler=function() return function() end end
V:Refresh("error timing","fault");flush()
assert(V.runtimeStats.modules.fault.calls==1 and V.runtimeStats.modules.fault.errors==1 and V.runtimeStats.modules.fault.totalMs==3,
    "Failed module application was missing from runtime diagnostics")
debugprofilestop=nil
V:Refresh("untimed runtime","actionBars");flush()
assert(V.runtimeStats.modules.actionBars.timedCalls==103,"Missing profiler was treated as a timing sample")

-- Independent combat requests must retain their union; a global request
-- dominates the union without being lost when it arrives later in the burst.
local priorAction,priorAddon=calls.actionBars,calls.addonWindows
combat=true
V:Refresh("combat action","actionBars");flush()
V:Refresh("combat addon window","addonWindows");flush()
combat=false
V.events.dispatch(nil,"PLAYER_REGEN_ENABLED");flush()
assert(calls.actionBars==priorAction+1 and calls.addonWindows==priorAddon+1,"Combat queue lost a requested module")
combat=true
V:Refresh("combat narrow","actionBars");flush()
V:Refresh("combat global");flush()
local priorFault=V.runtimeStats.modules.fault.calls
combat=false
V.events.dispatch(nil,"PLAYER_REGEN_ENABLED");flush()
assert(V.runtimeStats.modules.fault.calls==priorFault+1,"Global combat request was reduced to the narrow queue")

-- Surface updates used to clear/rebuild all 7 texture anchors on every call.
local textureWrites = 0
local function texture()
    local t={}
    for _, method in ipairs({"ClearAllPoints","SetPoint","SetWidth","SetSize","SetTexture","SetColorTexture","SetVertexColor","SetTexCoord"}) do
        t[method]=function() textureWrites=textureWrites+1 end
    end
    return t
end
CreateFrame=function()
    return {SetAllPoints=function() end,EnableMouse=function() end,SetFrameLevel=function() end,
        CreateTexture=texture,Show=function(s) s.shown=true end,Hide=function(s) s.shown=false end,
        IsShown=function(s) return s.shown==true end}
end
assert(loadfile(root .. "/Tokens.lua"))("vasagoio", V)
assert(loadfile(root .. "/core/Media.lua"))("vasagoio", V)
local frame={width=320,height=64,CreateTexture=texture,GetWidth=function(s)return s.width end,
    GetHeight=function(s)return s.height end,GetFrameLevel=function()return 5 end}
local surface=V:Surface(frame,.56,10)
local firstWrites,firstStyle=textureWrites,surface.style
for _=1,100 do V:Surface(frame,.56,10) end
assert(textureWrites==firstWrites and surface.style==firstStyle,"Unchanged surface rebuilt geometry/colors or allocated a new cache")
V:Surface(frame,.80,10)
assert(textureWrites==firstWrites+9,"Opacity update rebuilt geometry instead of only base/material colors")
local afterColor=textureWrites
frame.height=12
V:Surface(frame,.80,10)
assert(textureWrites>afterColor and surface.style.radius==6,"Geometry cache ignored smaller frame bounds")
V:RestoreArtwork()
assert(not surface.shown)
V:Surface(frame,.80,10)
assert(surface.shown,"Cached surface failed to reappear after disable/restore")
print("runtime_performance_spec: 100 action events trigger 0 window passes; 100 unchanged surfaces trigger 0 texture writes; coalescing, combat and self-refresh guards pass")
