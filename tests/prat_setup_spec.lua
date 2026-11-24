local root=(arg and arg[1]) or "."
CreateFrame=function() return {RegisterEvent=function()end,SetScript=function()end} end
InCombatLockdown=function()return false end
UIParent={GetWidth=function()return 2560 end,GetHeight=function()return 1440 end}
NUM_CHAT_WINDOWS=2
local V={}
for _,path in ipairs({"Core.lua","Tokens.lua","core/Database.lua","core/Profiles.lua","modules/HUD.lua"}) do
    assert(loadfile(root.."/"..path))("vasagoio",V)
end
V:InitializeDatabase()
local function check(value,message) assert(value,message) end
local profile={on=true,size={ChatFrame1=12,ChatFrame2=14},fontface="Original",outlinemode="OUTLINE",monochrome=true,slug=true}
local namespace={profiles={Default=profile,Other=V:Copy(profile)}}
local enabled,present,lookupError=true,true,false
local font={name="Prat_Font",db={profile=profile,keys={profile="Default"},sv=namespace}}
function font:IsEnabled() return enabled end
Prat={db={keys={profile="Default"}},Addon={}}
function Prat.Addon:GetModule(name,silent)
    check(name=="Font" and silent==true,"Unsafe module lookup")
    if lookupError then error("Owner module unavailable") end
    return present and font or nil
end
function Prat:GetModule() error("Prat wrapper must not be used for missing-module checks") end
Prat3DB={namespaces={Prat_Font=namespace},profiles={Default={channelColorSentinel=true}}}
local saved=V:Copy(Prat3DB)
local function unavailable(review)
    for _,entry in ipairs(review.unavailable) do if entry.id=="prat" then return entry.reason end end
end
local function noWrites()
    check(V:Equal(Prat3DB,saved),"Review/failure changed Prat settings")
    check(#V.db.profileBackups==0 and V.db.overrides.hudLayout==nil,"Failure created a partial preset")
end

-- Use the real full AceAddon namespace through actual snapshot validation.
local review=V:PrepareSetup()
check(not unavailable(review),"Prat_Font did not pass actual snapshot validation")
local count=0
for _,change in ipairs(review.changes) do
    if change.adapter=="prat" then
        count=count+1
        check(change.path[3]=="Prat_Font","Incorrect namespace entered the snapshot")
    end
end
check(count==8,"Expected four font fields and four chat-window sizes")
noWrites()

-- Never guess another namespace, use a detached runtime profile or ignore a
-- disabled owner module merely to make the setup status green.
Prat3DB.namespaces={Font=namespace}
check(unavailable(V:PrepareSetup()),"A guessed legacy namespace was accepted")
Prat3DB.namespaces={Prat_Font=namespace}
font.db.sv={}
check(unavailable(V:PrepareSetup()),"Detached namespace identity was accepted")
font.db.sv=namespace
font.db.keys.profile="Other"
check(unavailable(V:PrepareSetup()),"Different active namespace profile was accepted")
font.db.keys.profile="Default"
enabled=false
check(unavailable(V:PrepareSetup())=="Prat Font module is disabled","Disabled Font lacked an actionable reason")
enabled=true;present=false
check(unavailable(V:PrepareSetup()):find("initialized",1,true),"Missing Font became an adapter exception")
present=true;lookupError=true
check(unavailable(V:PrepareSetup()):find("initialized",1,true),"Owner lookup failure escaped setup")
lookupError=false
noWrites()

review=V:PrepareSetup();enabled=false
check(not V:ApplySetup(review),"Disabling Font after review did not reject stale apply")
enabled=true;noWrites()
review=V:PrepareSetup()
Prat.db.keys.profile="Other";font.db.keys.profile="Other";font.db.profile=namespace.profiles.Other
check(not V:ApplySetup(review),"Switching Prat profile did not reject stale apply")
Prat.db.keys.profile="Default";font.db.keys.profile="Default";font.db.profile=profile
noWrites()

review=V:PrepareSetup()
check(V:ApplySetup(review),"Prat_Font preset did not apply")
check(profile.fontface=="Arial Narrow" and profile.size.ChatFrame1==16 and profile.size.ChatFrame2==16,
    "Applied font settings missed active namespace")
check(profile.outlinemode=="" and not profile.monochrome and not profile.slug,"Font modes were not applied")
check(Prat3DB.namespaces.Font==nil and V:Equal(namespace.profiles.Other,saved.namespaces.Prat_Font.profiles.Other),
    "Apply created a fake namespace or changed another profile")
check(Prat3DB.profiles.Default.channelColorSentinel,"Unrelated chat settings changed")
check(#V.db.profileBackups==1 and V.profileReloadPending,"Successful apply did not snapshot and require reload")
check(V:RollbackProfiles(),"Prat_Font snapshot did not restore")
noWrites()
print("prat_setup_spec: real namespace, safe lookup, profile identity, stale review, apply and restoration passed")
