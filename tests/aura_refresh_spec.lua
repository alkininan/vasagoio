-- Aura traffic must not repaint every unit or inspect aura payloads.
local root = (arg and arg[1]) or "."
local events, modules, timers = {}, {}, {}
local combat, enabled, paints, poolTick = false, true, 0
local function check(value, message) assert(value, message) end
local function button()
    local b = {icon={},cooldown={},count={},width=36,height=36,paints=0,reads=0,hooks={}}
    function b:GetWidth() self.reads=self.reads+1; return self.width end
    function b:GetHeight() return self.height end
    function b:HookScript(event,fn) self.hooks[event]=fn end
    return b
end
local function frame(unit, buttons, children)
    local f = {unit=unit,auras={buffs={buttons=buttons or {}}},children=children or {}}
    function f:GetChildren() return unpack(self.children) end
    return f
end
local V = {db={modules={}}}
function V:IsSecret(v) return type(v)=="table" and v.secret==true end
function V:SafeNumber(v) if not self:IsSecret(v) and type(v)=="number" then return v end end
function V:IsModuleEnabled() return enabled end
function V:RegisterModule(id,spec) modules[id]=spec end
function V:On(event,fn) events[event]=fn end
function V:StyleAura(b,style) paints=paints+1; b.paints=b.paints+1; b.signal=style.signal end
function V:HideArtwork() end
function V:Report() end
UnitFullName=function() return "Example","Realm" end
ForeverUnitFramesDB={active={["Example-Realm"]="vasagoio"}}
ForeverUnitFrames={}
local version="0.81.0"
C_AddOns={GetAddOnMetadata=function() return version end}
InCombatLockdown=function() return combat end
C_Timer={After=function(_,fn) timers[#timers+1]=fn end,NewTicker=function(_,fn)
    poolTick=fn;return {Cancel=function() poolTick=nil end}
end}
C_UnitAuras=setmetatable({}, {__index=function() error("Presentation queried aura data") end})
local function flush()
    local work=timers;timers={}
    for _,fn in ipairs(work) do fn() end
end
local player, target, member1, member2, pet = button(),button(),button(),button(),button()
ForeverUnitFrames_player=frame("player",{player})
ForeverUnitFrames_target=frame("target",{target})
local p1,p2,pp=frame("party1",{member1}),frame("party2",{member2}),frame("partypet1",{pet})
ForeverUnitFramesParty=frame(nil,{}, {p1,p2})
ForeverUnitFramesPartyPets=frame(nil,{}, {pp})
assert(loadfile(root.."/modules/Auras.lua"))("vasagoio",V)
check(modules.auras.Apply() and paints==5,"Initial owner pools were not styled")
local before=paints
events.UNIT_AURA("UNIT_AURA","raid1",{})
events.UNIT_AURA("UNIT_AURA","nameplate1",{})
events.UNIT_AURA("UNIT_AURA",{secret=true},{})
check(#timers==0 and paints==before,"Irrelevant or restricted unit events scheduled work")

-- Existing style does not change on ordinary native aura-content updates.
local playerReads,targetReads=player.reads,target.reads
events.UNIT_AURA("UNIT_AURA","party1",{secret=true})
events.UNIT_AURA("UNIT_AURA","party1",{secret=true})
check(#timers==1,"Repeated unit updates were not coalesced")
flush()
check(paints==before and player.reads==playerReads and target.reads==targetReads,
    "Party aura update scanned/repainted unrelated single-unit pools")

-- New buttons are discovered only for the affected unit. FUF's plain aura
-- fallback reapplies native style when its size changes; that needs repainting.
local late=button();p1.auras.buffs.buttons[#p1.auras.buffs.buttons+1]=late
target.width=28
events.UNIT_AURA("UNIT_AURA","party1",{});flush()
check(late.paints==1 and target.paints==1 and paints==before+1,"Unit discovery was not scoped")
events.UNIT_AURA("UNIT_AURA","target",{});flush()
check(target.paints==2 and paints==before+2,"Changed owner icon size was not restyled")

before=paints;playerReads=player.reads
member2.hooks.OnShow();flush()
check(paints==before+1 and member2.paints==2 and player.reads==playerReads,
    "One shown button forced a whole-pool walk")

-- Coalesced units must both be visited, including party pets.
local newPlayer,newPet=button(),button()
table.insert(ForeverUnitFrames_player.auras.buffs.buttons,newPlayer)
table.insert(pp.auras.buffs.buttons,newPet)
events.UNIT_AURA("UNIT_AURA","player",{})
events.UNIT_AURA("UNIT_AURA","partypet1",{})
check(#timers==1,"Different dirty units were not coalesced")
flush();check(newPlayer.paints==1 and newPet.paints==1,"A coalesced unit was lost")

-- The reviewed 0.81 native-container records and detached own-aura pools keep
-- their existing shapes. Presentation reads button references, not aura data.
local nativeDebuff,detachedBuff=button(),button()
ForeverUnitFrames_target.auraContainers={debuffs={buttons={{button=nativeDebuff,aura={secret=true}}}}}
ForeverUnitFrames_player.auras.buffs.free={buttons={detachedBuff}}
events.UNIT_AURA("UNIT_AURA","target",{})
events.UNIT_AURA("UNIT_AURA","player",{});flush()
check(nativeDebuff.paints==1 and nativeDebuff.signal=="danger" and detachedBuff.paints==1 and detachedBuff.signal==nil,
    "Reviewed native or detached aura pool lost its correct presentation")

-- Show + unit event can coincide; each dirty button is painted only once.
before=paints
member1.hooks.OnShow();events.UNIT_AURA("UNIT_AURA","party1",{});flush()
check(paints==before+1,"Dirty button was painted twice in one batch")
before=paints;poolTick();check(paints==before,"Fallback discovery repainted stable pools")

combat=true
events.UNIT_AURA("UNIT_AURA","player",{});member1.hooks.OnShow();poolTick()
check(#timers==0 and paints==before,"Aura presentation ran during combat")
combat=false;events.PLAYER_REGEN_ENABLED();flush()
check(paints>before,"Combat end did not retry owner styling")

events.UNIT_AURA("UNIT_AURA","party1",{})
V.profileReloadPending=true;before=paints;flush()
check(paints==before,"Pending profile reload applied stale queued aura styling")
V.profileReloadPending=nil
modules.auras.Disable();enabled=false
events.UNIT_AURA("UNIT_AURA","player",{});member1.hooks.OnShow()
check(poolTick==nil and #timers==0 and paints==before,"Disabled module left aura work active")
enabled=true;version="0.79.1"
check(modules.auras.Apply(),"Previous reviewed FUF aura version lost support")
before=paints;version="future"
check(modules.auras.Apply()==false and paints==before,"Unreviewed FUF aura version was styled")
events.UNIT_AURA("UNIT_AURA","player",{});poolTick()
check(#timers==0 and paints==before,"Rejected FUF version left aura styling active")
modules.auras.Disable()
print("aura_refresh_spec: scoped units, incremental pools, one-button show, batch coalescing and combat/reload guards passed")
