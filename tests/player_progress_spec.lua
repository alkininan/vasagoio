local root=(arg and arg[1]) or "."
local combat,available,current,maximum=false,true,100,1000
local writes,created=0,0
local secret={}
local events={}
local function check(value,message) assert(value,message) end
local function widget(height,points)
    local w={height=height or 0,points=points or {},shown=true}
    function w:GetHeight() return self.height end
    function w:GetNumPoints() return #self.points end
    function w:GetPoint(i) return unpack(self.points[i]) end
    function w:ClearAllPoints() writes=writes+1;self.points={} end
    function w:SetPoint(...) writes=writes+1;self.points[#self.points+1]={...} end
    function w:SetHeight(v) writes=writes+1;self.height=v end
    function w:Show() self.shown=true end
    function w:Hide() self.shown=false end
    function w:SetAllPoints(parent) self.parent=parent end
    function w:SetColorTexture(...) self.color={...} end
    function w:SetStatusBarTexture(v) self.texture=v end
    function w:SetStatusBarColor(...) self.color={...} end
    function w:SetMinMaxValues(a,b) self.minimum,self.maximum=a,b end
    function w:SetValue(v) self.value=v end
    function w:CreateTexture() return widget() end
    return w
end
CreateFrame=function(kind,_,parent)
    check(kind=="StatusBar","Progress created an unexpected frame")
    created=created+1
    local bar=widget();bar.parent=parent;return bar
end
hooksecurefunc=function(target,method,callback)
    local original=target[method]
    target[method]=function(self,...)
        original(self,...);callback(self,...)
    end
end
InCombatLockdown=function()return combat end
GameRulesUtil={CanShowExperienceBar=function()return available end}
UnitXP=function()return current end
UnitXPMax=function()return maximum end
local V={db={enabled=true,modules={},overrides={}}}
local ownerVersion,profileName,profile="0.81.0","vasagoio",{}
function V:GetReviewedUnitProfile()
    if (ownerVersion=="0.81.0" or ownerVersion=="0.79.1") and profileName:match("^vasagoio") then
        return profile,profileName
    end
end
function V:IsSecret(v)return v==secret end
function V:SafeNumber(v)if not self:IsSecret(v) and type(v)=="number" then return v end end
function V:Pixel(v)return v end
function V:IsModuleEnabled(id)return self.db.enabled and self.db.modules[id]~=false end
function V:Report(id,state,detail)self.lastReport={id,state,detail}end
function V:On(event,fn)events[event]=fn end
assert(loadfile(root.."/Tokens.lua"))("vasagoio",V)
V.Tokens.playerProgress=V.Tokens.playerProgress or {health=48,power=16,height=4,gap=2}
assert(loadfile(root.."/modules/PlayerProgress.lua"))("vasagoio",V)
local frame={key="player",height=72,width=304,portrait={height=72}}
function frame:GetHeight()return self.height end
function frame:SetHeight()error("Secure unit size changed")end
function frame:SetPoint()error("Secure unit anchor changed")end
frame.health=widget(54,{{"TOPLEFT",frame,"TOPLEFT",74,0},{"TOPRIGHT",frame,"TOPRIGHT",0,0}})
frame.power=widget(16,{{"BOTTOMLEFT",frame,"BOTTOMLEFT",74,0},{"BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0}})
frame.healthHeight,frame.powerHeight=54,16

V:StylePlayerProgress(frame)
check(created==0,"Progress appeared before explicit setup")
V.db.overrides.playerProgress=true
V:StylePlayerProgress(frame)
local bar=frame.vasagoioProgress
check(created==1 and bar.shown and bar.value==100 and bar.maximum==1000,"Native XP did not populate the strip")
check(frame.health.height==48 and frame.power.height==16 and frame.power.points[1][5]==6 and bar.height==4,
    "48/2/16/2/4 rows were not applied")
check(frame.height==72 and frame.width==304 and frame.portrait.height==72,"Outer frame or portrait changed")
check(bar.points[1][4]==74 and bar.points[1][5]==0,"XP does not align with the existing bar body")

local before=writes
for value=101,120 do current=value;events.PLAYER_XP_UPDATE()end
check(writes==before and created==1 and bar.value==120,"XP updates repeatedly relaid out the unit")
events.UNIT_LEVEL("UNIT_LEVEL","target")
check(writes==before,"Unrelated level update touched player rows")

-- Max-level/XP-disabled state returns the original rows. There is no fallback
-- to a reputation API or another status bar.
available=false;events.UNIT_LEVEL("UNIT_LEVEL","player")
check(not bar.shown and frame.health.height==54 and frame.power.height==16 and frame.power.points[1][5]==0,
    "Capped XP did not reclaim its space")
available=true;events.ENABLE_XP_GAIN()
check(bar.shown and frame.health.height==48,"XP did not return after availability changed")
combat=true;available=false;before=writes;events.PLAYER_LEVEL_UP()
check(writes==before and frame.health.height==48,"Combat level-up reanchored child rows")
combat=false;events.PLAYER_REGEN_ENABLED()
check(frame.health.height==54 and frame.power.height==16 and not bar.shown,"Deferred max-level restoration did not run")

-- Owner relayouts are followed by a scoped correction and retained for later
-- restoration. Do not keep the adapter's own shrunken rows as the baseline.
available=true;events.ENABLE_XP_GAIN()
for i=1,5 do
    frame.power:SetHeight(16)
    check(frame.power.points[1][5]==6 and bar.points[1][5]==0,
        "Height-only writes accumulated the progress offset")
end
V:DisablePlayerProgress()
check(frame.power.points[1][5]==0 and frame.power.height==16,"Height-only writes corrupted restoration")
V:StylePlayerProgress(frame)
frame.health:SetHeight(54)
frame.power:ClearAllPoints()
frame.power:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",74,0)
frame.power:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
frame.power:SetHeight(16)
check(frame.health.height==48 and frame.power.height==16,"Owner relayout lost the compact strip")
V:DisablePlayerProgress()
check(frame.health.height==54 and frame.power.height==16 and frame.power.points[1][5]==0 and not bar.shown,
    "Disabling did not restore native rows")
before=writes;current=400;events.PLAYER_XP_UPDATE()
check(writes==before and not bar.shown,"Disabled progress retained active layout work")
V:StylePlayerProgress(frame)
combat=true;before=writes;V:DisablePlayerProgress()
check(writes==before,"Disable changed layout in combat")
combat=false;events.PLAYER_REGEN_ENABLED()
check(not bar.shown and frame.health.height==54,"Deferred disable did not restore")

V:StylePlayerProgress(frame)
current=secret;events.PLAYER_XP_UPDATE()
check(not bar.shown and frame.health.height==54 and V.lastReport[2]=="unsupported","Restricted XP was inspected or guessed")
current=200;available=secret;events.PLAYER_XP_UPDATE()
check(not bar.shown,"Restricted visibility was guessed")
available=true;current=200;maximum=0;events.PLAYER_XP_UPDATE()
check(not bar.shown,"Zero maximum XP created an invalid range")
maximum=1000;events.PLAYER_XP_UPDATE()
check(bar.shown and bar.value==200,"Progress did not recover from unavailable data")

-- A prior setup flag does not grant permanent ownership of another FUF
-- profile/version. Both XP events and owner sizing hooks must release it.
profileName="Other";events.PLAYER_XP_UPDATE()
check(not bar.shown and frame.health.height==54 and frame.power.height==16 and frame.power.points[1][5]==0,
    "An XP event kept styling another owner profile")
before=writes;frame.power:SetHeight(16)
check(frame.power.height==16 and frame.power.points[1][5]==0,"An owner hook reactivated another profile")
profileName="vasagoio";V:StylePlayerProgress(frame)
check(bar.shown,"Explicit styling did not resume the reviewed profile")
ownerVersion="future";frame.power:SetHeight(16)
check(not bar.shown and frame.health.height==54 and frame.power.height==16 and frame.power.points[1][5]==0,
    "An owner hook retained XP on an unreviewed FUF version")
ownerVersion="0.81.0";V:StylePlayerProgress(frame)
check(bar.shown,"Reviewed owner did not recover")
profileName="Other"
frame.health:SetHeight(50)
check(not bar.shown and frame.health.height==50 and frame.power.points[1][5]==0,
    "Releasing XP overwrote a new owner's health geometry")
frame.health:SetHeight(54)
profileName="vasagoio";V:StylePlayerProgress(frame)
profileName="Other";frame.health:SetHeight(48)
check(frame.health.height==48 and not bar.shown,"Releasing XP overwrote an identical new-owner height")
frame.health:SetHeight(54)
profileName="vasagoio";V:StylePlayerProgress(frame)

local previousProfile=profile
profile={};events.PLAYER_XP_UPDATE()
check(not bar.shown and frame.power.points[1][5]==0,"Replacing the active profile table retained stale ownership")
profile=previousProfile;V:StylePlayerProgress(frame)
V.profileReloadPending=true;events.PLAYER_XP_UPDATE()
check(not bar.shown and frame.health.height==54,"Pending profile reload retained the adapter")
print("player_progress_spec: fixed outer size, XP-only space reclaim, owner relayout, event-only updates, combat and disable passed")
