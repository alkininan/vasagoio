local root = (arg and arg[1]) or "."
local combat, version, positionWrites = false, "v4.11.40", 0
local function check(value, message) assert(value, message) end
local function widget(points)
    local frame = { points=points, scale=1, width=220, height=88 }
    function frame:ClearAllPoints() positionWrites=positionWrites+1; self.points={} end
    function frame:SetPoint(point, relative, relativePoint, x, y)
        positionWrites=positionWrites+1
        self.points[#self.points+1]={point, relative, relativePoint, x, y}
    end
    function frame:GetEffectiveScale() return self.scale end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index],1,5) end
    function frame:IsForbidden() return self.forbidden or false end
    return frame
end
UIParent = widget({}); UIParent.scale=1
InCombatLockdown=function() return combat end
GetAddOnMetadata=function(name) if name=="RXPGuides" then return version end end
local V={db={enabled=true,modules={},profileBackups={}}, modules={}, adapters={}, adapterOrder={}, Tokens={revision=10}}
function V:IsSecret(value) return type(value)=="table" and value.secret==true end
function V:SafeNumber(value) if type(value)=="number" and value==value and value~=math.huge and value~=-math.huge then return value end end
function V:Pixel(value) return value end
function V:IsModuleEnabled(id) return self.db.modules[id]~=false and self.db.enabled end
function V:RegisterModule(id,spec) self.modules[id]=spec end
function V:RegisterProfileAdapter(id,spec) self.adapters[id]=spec; self.adapterOrder[#self.adapterOrder+1]=id end
function V:Refresh() end
assert(loadfile(root.."/core/Database.lua"))("vasagoio",V)
assert(loadfile(root.."/core/Profiles.lua"))("vasagoio",V)
assert(loadfile(root.."/modules/QuestHUD.lua"))("vasagoio",V)
local adapter=V.adapters.restedxp
check(adapter.Prepare()==nil,"missing RXP owner must be unavailable")
local original={{"TOPRIGHT",nil,"TOPRIGHT",0,-56}}
local guide=widget({{"TOPRIGHT",UIParent,"TOPRIGHT",0,-56}})
local profile={framePositions={RXPFrame=V:Copy(original)}, frameSizes={RXPFrame={220,88}}, enableQuestAutomation=false}
local key="Test"
RXPSettings={profiles={Test=profile}}
local settings={profile=profile,GetSettingsDB=function() return key end}
local rxp={enabledFrames={RXPFrame=guide}}
function rxp:GetModule(name) if name=="Settings" then return settings end end
LibStub=function(name)
    if name=="AceAddon-3.0" then return {GetAddon=function(_,addon) if addon=="RXPGuides" then return rxp end end} end
end
local function ownerSavesPositions()
    for name,frame in pairs(rxp.enabledFrames) do
        local saved={}
        for i,point in ipairs(frame.points) do
            saved[i]={point[1],point[2]==UIParent and "UIParent" or point[2],point[3],point[4],point[5]}
        end
        settings.profile.framePositions[name]=saved
    end
end
local review=V:PrepareSetup()
check(#review.changes==1 and #review.unavailable==0,"initialized RXP guide not reviewed")
check(positionWrites==0 and V:Equal(profile.framePositions.RXPFrame,original),"review changed guide position")
for _=1,20 do V.modules.questHUD.Apply() end
check(positionWrites==0,"cosmetic refresh moved the guide without explicit setup")
check(V:ApplySetup(review),"RXP setup failed")
check(guide.points[1][4]==-384 and guide.points[1][5]==-64,"setup did not synchronize the live guide")
check(guide.width==220 and guide.height==88 and profile.enableQuestAutomation==false,"guide size or behavior changed")
local applied=V:Copy(profile.framePositions.RXPFrame)
ownerSavesPositions()
check(V:Equal(profile.framePositions.RXPFrame,applied),"owner logout overwrote the reviewed guide anchor")
check(V:RollbackProfiles(),"RXP restoration failed")
check(guide.points[1][4]==0 and guide.points[1][5]==-56,"restoration left the live guide at its new anchor")
ownerSavesPositions()
check(profile.framePositions.RXPFrame[1][4]==0 and profile.framePositions.RXPFrame[1][5]==-56,
    "owner logout overwrote restored guide position")
V.profileReloadPending=nil

-- Uninitialized, restricted and unknown owners cannot acquire a partial plan.
local oldPositions=profile.framePositions.RXPFrame
profile.framePositions.RXPFrame=nil
check(adapter.Prepare()==nil,"uninitialized anchors were guessed")
profile.framePositions.RXPFrame=oldPositions
version="v4.11.41"; check(adapter.Prepare()==nil,"future RXP version accepted")
version="v4.11.40"; guide.forbidden=true
check(adapter.Prepare()==nil,"forbidden guide frame accepted")
guide.forbidden=false; combat=true
check(adapter.Prepare()==nil,"combat guide layout accepted")
combat=false
local v2=widget({{"LEFT",UIParent,"LEFT",0,35}})
rxp.enabledFrames.RXPV2GuideWindow=v2
check(adapter.Prepare()==nil,"lazy V2 anchor was invented before owner initialization")
profile.framePositions.RXPV2GuideWindow={{"LEFT","UIParent","LEFT",0,35}}
v2.scale=2
local plan=assert(adapter.Prepare())
check(#plan.changes==2 and plan.changes[2].value[1][4]==-192 and plan.changes[2].value[1][5]==-32,
    "guide scale was not accounted for")
local basePixel=V.Pixel
function V:Pixel(value) return value*5/6 end
UIParent.scale=5/6; v2.scale=(5/6)*0.8
plan=assert(adapter.Prepare())
check(math.abs(plan.changes[2].value[1][4]+400)<.00001 and
    math.abs(plan.changes[2].value[1][5]+(200/3))<.00001,
    "UI scale and guide-local scale were combined incorrectly")
V.Pixel=basePixel; UIParent.scale=1
rxp.enabledFrames.RXPV2GuideWindow=nil
profile.framePositions.RXPV2GuideWindow=nil

-- A user drag is saved by RXP and must stop rollback instead of being lost.
review=V:PrepareSetup(); check(V:ApplySetup(review),"second setup failed")
guide.points={{"TOPRIGHT",UIParent,"TOPRIGHT",-500,-100}}
ownerSavesPositions()
local before=positionWrites
check(not V:RollbackProfiles(),"later user position was overwritten")
check(positionWrites==before and guide.points[1][4]==-500,"conflicting restoration touched live guide")
-- Return the saved/live fields to the snapshot's after value for the next check.
profile.framePositions.RXPFrame=V:Copy(applied)
guide.points={{"TOPRIGHT",UIParent,"TOPRIGHT",-384,-64}}
guide.forbidden=true
check(not V:RollbackProfiles(),"restore preflight allowed an unwritable active guide")
check(V:Equal(profile.framePositions.RXPFrame,applied),"failed restore preflight changed saved position")
guide.forbidden=false

-- Restoring a now-inactive profile must not reposition the user's current one.
local other={framePositions={RXPFrame={{"LEFT","UIParent","LEFT",200,100}}}}
RXPSettings.profiles.Other=other; key="Other"; settings.profile=other
guide.points={{"LEFT",UIParent,"LEFT",200,100}}
before=positionWrites; version="v4.11.41"
check(V:RollbackProfiles(),"inactive RXP profile could not be restored")
check(positionWrites==before and guide.points[1][4]==200,"inactive-profile restore moved active guide")
check(profile.framePositions.RXPFrame[1][4]==0,"inactive saved profile was not restored")
-- A live callback failure keeps the snapshot and repairs the live/saved pair.
key="Test"; settings.profile=profile; version="v4.11.40"; V.profileReloadPending=nil
guide.points={{"TOPRIGHT",UIParent,"TOPRIGHT",0,-56}}
review=V:PrepareSetup(); check(V:ApplySetup(review),"failure-recovery setup failed")
local baseSetPoint=guide.SetPoint
local failOnce=true
function guide:SetPoint(point,relative,relativePoint,x,y)
    if failOnce and x==0 then failOnce=false; error("simulated native anchor error") end
    return baseSetPoint(self,point,relative,relativePoint,x,y)
end
local backupCount=#V.db.profileBackups
check(not V:RollbackProfiles(),"native restore error was ignored")
check(#V.db.profileBackups==backupCount and V:Equal(profile.framePositions.RXPFrame,applied),
    "failed live restoration lost its saved settings or snapshot")
check(guide.points[1][4]==-384,"failed live restoration did not recover applied anchor")
check(V:RollbackProfiles(),"restoration could not be retried after native error")
guide.SetPoint=baseSetPoint

-- Recovery of an inactive profile must also leave the active live frame alone.
V.profileReloadPending=nil
review=V:PrepareSetup(); check(V:ApplySetup(review),"inactive failure-recovery setup failed")
key="Other"; settings.profile=other; guide.points={{"LEFT",UIParent,"LEFT",200,100}}
local afterRestore=adapter.AfterRestore
adapter.AfterRestore=function() error("simulated callback failure") end
before=positionWrites
check(not V:RollbackProfiles(),"simulated callback failure was ignored")
check(positionWrites==before and guide.points[1][4]==200,"failure recovery moved a different active profile")
adapter.AfterRestore=afterRestore
check(V:RollbackProfiles(),"inactive profile recovery retry failed")
-- Initial apply is also transactional: a native SetPoint error must not leave
-- blank live anchors for RXP's logout save or claim a successful new snapshot.
key="Test"; settings.profile=profile; V.profileReloadPending=nil; version="v4.11.40"
guide.points={{"TOPRIGHT",UIParent,"TOPRIGHT",0,-56}}
local initialSaved=V:Copy(profile.framePositions.RXPFrame)
V.db.appliedRevision=73
review=V:PrepareSetup(); backupCount=#V.db.profileBackups
failOnce=true
function guide:SetPoint(point,relative,relativePoint,x,y)
    if failOnce and x==-384 then failOnce=false; error("simulated initial apply anchor error") end
    return baseSetPoint(self,point,relative,relativePoint,x,y)
end
check(not V:ApplySetup(review),"initial native anchor failure was reported as a successful setup")
check(V:Equal(profile.framePositions.RXPFrame,initialSaved) and guide.points[1][4]==0 and guide.points[1][5]==-56,
    "failed initial apply did not preserve saved and live anchors")
check(#V.db.profileBackups==backupCount and V.db.appliedRevision==73,"failed initial apply changed snapshot/revision history")
ownerSavesPositions()
check(profile.framePositions.RXPFrame[1][4]==0,"owner logout persisted a failed initial anchor")
guide.SetPoint=baseSetPoint

-- A failure on a later guide must undo the first guide too, after all original
-- live anchors were captured before either guide was touched.
V.profileReloadPending=nil
v2=widget({{"LEFT",UIParent,"LEFT",0,35}})
rxp.enabledFrames.RXPV2GuideWindow=v2
profile.framePositions.RXPV2GuideWindow={{"LEFT","UIParent","LEFT",0,35}}
local baseV2SetPoint=v2.SetPoint
failOnce=true
function v2:SetPoint(point,relative,relativePoint,x,y)
    if failOnce and x==-384 then failOnce=false; error("simulated second-guide anchor error") end
    return baseV2SetPoint(self,point,relative,relativePoint,x,y)
end
review=V:PrepareSetup(); backupCount=#V.db.profileBackups
check(not V:ApplySetup(review),"second guide failure was ignored")
check(guide.points[1][4]==0 and v2.points[1][1]=="LEFT" and v2.points[1][5]==35,
    "multi-guide failure did not restore all touched live anchors")
check(profile.framePositions.RXPFrame[1][4]==0 and profile.framePositions.RXPV2GuideWindow[1][1]=="LEFT" and
    #V.db.profileBackups==backupCount,"multi-guide failure left partial saved anchors or a new snapshot")
print("quest_hud_spec: explicit review, scale-aware anchors, owner logout persistence, active/inactive restore and conflict guards passed")
