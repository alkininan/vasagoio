-- Source-backed unit lifecycle checks; no client or installed-addon state.
local modules,events={},{}
local combat=false
local secret={}
local V={db={enabled=true,modules={}}}
function V:RegisterProfileAdapter() end
function V:RegisterModule(id,module)modules[id]=module end
function V:On(event,fn)events[event]=fn end
function V:Refresh() end
function V:IsModuleEnabled()return self.db.enabled end
function V:IsSecret(value)return value==secret end
function V:SafeNumber(value)if not self:IsSecret(value) and type(value)=="number"then return value end end
function V:Pixel(value)return value end
function V:Surface()return {Hide=function()end} end
function hooksecurefunc(object,method,callback)
    local native=assert(object[method])
    object[method]=function(self,...)native(self,...);callback(self,...)end
end
UIParent={}
ForeverUnitFrames={}
ForeverUnitFramesDB={active={["Test-Realm"]="vasagoio"},profiles={vasagoio={},Default={}}}
C_AddOns={GetAddOnMetadata=function()return "0.81.1"end}
UnitFullName=function()return "Test","Realm"end
InCombatLockdown=function()return combat end
local dead,ghost,connected=false,false,true
UnitIsDeadOrGhost=function()return dead end
UnitIsGhost=function()return ghost end
UnitIsConnected=function()return connected end
UnitIsPlayer=function()return true end
UnitHealth,UnitPower=function()return secret end,function()return secret end
UnitPowerType=function()return 0 end
CreateColor=function(...)return {...}end
C_CurveUtil={CreateColorCurve=function()return {AddPoint=function()end}end}
UnitHealthPercent=function()return {GetRGBA=function()return secret,secret,secret,secret end}end
local function region()
    return {points={},width=120,height=20,justify="CENTER",color={.3,.4,.5,1},writes=0,
        GetNumPoints=function(self)return #self.points end,
        GetPoint=function(self,i)return unpack(self.points[i])end,
        ClearAllPoints=function(self)assert(not combat);self.points={};self.writes=self.writes+1 end,
        SetPoint=function(self,...)
            assert(not combat)
            if self.failPoint then error("native anchor setter temporarily unavailable")end
            self.points[#self.points+1]={...};self.writes=self.writes+1
        end,
        GetWidth=function(self)return self.width end,GetHeight=function(self)return self.height end,
        SetWidth=function(self,width)assert(not combat);self.width=width end,
        GetJustifyH=function(self)return self.justify end,SetJustifyH=function(self,value)assert(not combat);self.justify=value end,
        GetStatusBarColor=function(self)return unpack(self.color)end,
        SetStatusBarColor=function(self,...)self.color={...}end,
        SetText=function(self,value)self.text=value;self.raw=nil end,
        SetFormattedText=function(self,fmt,value)self.raw=value end,
    }
end
local unit={key="player",unit="player",health=region(),power=region(),textWord=false,
    texts={healthRight=region(),powerRight=region()},Hide=function()error("unit visibility changed")end,
    Show=function()error("unit visibility changed")end}
ForeverUnitFrames_player=unit
local raid={key="raid",unit="raid1",health=region(),power=region(),textWord=false,
    texts={healthLeft=region(),healthRight=region()}}
local block=region()
block.GetChildren=function()return raid end
block:SetPoint("TOPLEFT",UIParent,"TOPLEFT",24,-96)
ForeverUnitFramesRaidBlock1=block
for _,fs in pairs(raid.texts)do
    fs:SetPoint("LEFT",raid.health,"LEFT",2,8)
    fs:SetPoint("RIGHT",raid.health,"RIGHT",-2,8)
end
assert(loadfile("Tokens.lua"))("vasagoio",V)
assert(loadfile("modules/UnitFrames.lua"))("vasagoio",V)
assert(modules.unitframes:Apply())
assert(unit.health.color[1]==secret)
assert(block.points[1][4]==-1272)
assert(raid.texts.healthLeft.width==68 and raid.texts.healthRight.width==40)

-- FUF Health runs before Texts updates textWord. The current unit API state
-- must retain native grey on that first death/ghost/offline paint.
for _,status in ipairs({"Dead","Ghost","Offline"})do
    unit.textWord,raid.textWord=false,false
    dead,ghost,connected=status=="Dead",status=="Ghost",status~="Offline"
    for _,frame in ipairs({unit,raid})do
        frame.health:SetStatusBarColor(.5,.5,.5,1)
        frame.power:SetStatusBarColor(.5,.5,.5,1)
        assert(frame.health.color[1]==.5 and frame.health.color[4]==1,"native status health grey was overridden")
        assert(frame.power.color[1]==.5 and frame.power.color[4]==1,"native status resource grey was overridden")
        frame.textWord=status;frame.texts.healthRight:SetText(status)
        assert(frame.texts.healthRight.text==status and frame.texts.healthRight.raw==nil,"status word was replaced by HP")
    end
end
dead,ghost,connected=false,false,true
unit.textWord=false
unit.health:SetStatusBarColor(.1,.2,.3,1)
assert(unit.health.color[1]==secret,"living health curve did not resume")
dead=secret
unit.health:SetStatusBarColor(.4,.4,.4,1)
assert(unit.health.color[1]==.4,"unknown status overwrote owner rendering")
dead=false
unit.statusSample="DEAD"
unit.health:SetStatusBarColor(.5,.5,.5,1)
assert(unit.health.color[1]==.5,"owner test-mode status was lost")
unit.statusSample=nil

-- Repeated application keeps the original owner layout rather than taking
-- our own single-line/grid anchors as the restoration baseline.
assert(modules.unitframes:Apply());assert(modules.unitframes:Apply())
modules.unitframes:Disable()
assert(block.points[1][4]==24 and block.points[1][5]==-96)
for _,fs in pairs(raid.texts)do
    assert(#fs.points==2 and fs.points[1][4]==2 and fs.points[2][4]==-2)
    assert(fs.width==120 and fs.justify=="CENTER")
end
assert(modules.unitframes:Apply())
local writes=block.writes
combat=true;modules.unitframes:Disable()
assert(block.writes==writes,"combat disable changed secure header anchors")
combat=false;events.PLAYER_REGEN_ENABLED()
assert(block.points[1][4]==24 and raid.texts.healthRight.width==120)

-- A later owner layout wins, even a write equal to our last width, and is
-- captured for restoration if styling is applied again before disabling.
assert(modules.unitframes:Apply())
block:ClearAllPoints();block:SetPoint("CENTER",UIParent,"CENTER",70,80)
raid.texts.healthLeft:SetWidth(68)
raid.texts.healthRight:ClearAllPoints()
raid.texts.healthRight:SetPoint("BOTTOM",raid.health,"BOTTOM",0,3)
raid.texts.healthRight:SetJustifyH("LEFT")
assert(modules.unitframes:Apply())
modules.unitframes:Disable()
assert(block.points[1][1]=="CENTER" and block.points[1][4]==70)
assert(raid.texts.healthLeft.width==68,"identical owner width was reverted")
assert(raid.texts.healthRight.points[1][1]=="BOTTOM" and raid.texts.healthRight.justify=="LEFT")

-- Native setters may fail after ClearAllPoints already succeeded. Keep a
-- recovery record, clear the busy guard, and retry without losing the owner
-- baseline or propagating the failure out of module cleanup.
assert(modules.unitframes:Apply())
block.failPoint=true
assert(pcall(modules.unitframes.Disable))
assert(#block.points==0)
block.failPoint=false
events.PLAYER_REGEN_ENABLED()
assert(block.points[1][1]=="CENTER" and block.points[1][4]==70,"failed restore was discarded")
-- The same failure during application rolls back immediately if possible,
-- otherwise it remains recoverable at the next safe boundary.
block.failPoint=true
assert(pcall(modules.unitframes.Apply))
block.failPoint=false
events.PLAYER_REGEN_ENABLED()
assert(block.points[1][1]=="CENTER" and block.points[1][4]==70,"partial application lost native anchors")
assert(modules.unitframes:Apply())
block:ClearAllPoints();block:SetPoint("CENTER",UIParent,"CENTER",90,100)
modules.unitframes:Disable()
assert(block.points[1][4]==90,"failure left the owner-write guard stuck")
assert(modules.unitframes:Apply())
ForeverUnitFramesDB.active["Test-Realm"]="Default"
unit.health:SetStatusBarColor(.2,.2,.2,1)
assert(block.points[1][1]=="CENTER" and block.points[1][4]==90 and raid.texts.healthLeft.width==68,"profile loss retained raid geometry")
assert(unit.health.color[1]==.2)
print("unit visibility/status/restore tests passed")
