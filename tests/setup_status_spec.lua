local root=(arg and arg[1]) or "."
CreateFrame=function() return {RegisterEvent=function()end,SetScript=function()end} end
InCombatLockdown=function()return false end
local V={}
for _, path in ipairs({"Core.lua","Tokens.lua","core/Database.lua","core/Profiles.lua","core/SetupStatus.lua"}) do
    assert(loadfile(root.."/"..path))("vasagoio",V)
end
V:InitializeDatabase()
local ids={"unitframes","nameplates","bartender","hudLayout","prat","sexymap","details","skinner","restedxp"}
local modules={unitframes="unitframes",nameplates="nameplates",bartender="actionBars",hudLayout="hud",
    prat="hud",sexymap="hud",details="meter",skinner="nativeWindows",restedxp="questHUD"}
for _, id in ipairs({"unitframes","auras","nameplates","actionBars","hud","meter","nativeWindows","addonWindows","questHUD"}) do
    V:RegisterModule(id,{Apply=function()return true end})
end
SetupHealthFixture={profiles={A={},B={}}}
local selected="A"
local failures, loaded, prepares={},{},{}
C_AddOns={IsAddOnLoaded=function(name)return loaded[name]~=false end}
for _, id in ipairs(ids) do
    local name=id
    SetupHealthFixture.profiles.A[id]={configuration={width=100}}
    SetupHealthFixture.profiles.B[id]={configuration={width=100}}
    V:RegisterProfileAdapter(id,{module=modules[id],Prepare=function()
        prepares[name]=(prepares[name] or 0)+1
        if failures[name] then return nil,failures[name] end
        local target=SetupHealthFixture.profiles[selected][name]
        return {changes={{table=target,path={"SetupHealthFixture","profiles",selected,name},
            key="configuration",value={width=320,height=64}}}}
    end})
end
local function check(value,message)assert(value,message)end
local function row(model,id)
    for _, item in ipairs(model.rows) do if item.id==id then return item end end
    error("Missing status row "..id)
end
local function reload()
    V.profileReloadPending=nil;V.uiReloadPending=nil;V.ready=true;V:ApplyModules()
end
local function unchanged()
    for _,id in ipairs(ids) do check(SetupHealthFixture.profiles.A[id].configuration.width==100,"Rejected setup wrote "..id) end
    check(#V.db.profileBackups==0,"Rejected setup created a snapshot")
end

-- Required owners block both the button and the actual transaction. A cached
-- UI blockers list cannot grant permission to apply a partial HUD.
failures.bartender="Bartender4 schema 3 must be initialized"
loaded.Bartender4=false
local review=V:PrepareSetup()
local model=V:BuildSetupStatus(review)
check(not model.canApply and row(model,"actions").state=="attention","Missing core was marked ready")
check(model.title=="Preset not applied" and model.description=="The full preset has not been applied. Apply is blocked by Action bars.",
    "Required failure hid the unapplied full preset")
check(row(model,"units").state=="ready","A blocked peer was falsely reported as applied")
check(row(model,"actions").detail=="Bartender4 is not loaded. Enable it and reload.","Missing owner explanation is technical")
check(model.rows[1].id=="actions","Problem row did not appear first")
review.blockers={}
check(not V:ApplySetup(review),"UI blockers could be bypassed for a partial HUD")
unchanged()
failures.bartender=nil;loaded.Bartender4=true

-- Adapter-authored geometry reasons keep the precise bar and ordinary
-- dimensions; no generic keyword mapping should erase their remedy.
for _,reason in ipairs({
    "Pet bar: unsupported button geometry (36 x 36, margin 2). Update vasagoio before applying this layout.",
    "Backpack: native size getters are unavailable. Reload Bartender4 and try setup again.",
}) do
    failures.bartender=reason
    review=V:PrepareSetup();model=V:BuildSetupStatus(review)
    check(row(model,"actions").detail==reason,"Bartender geometry reason was replaced")
    check(not model.canApply and not V:ApplySetup(review),"Detailed Bartender failure bypassed the required gate")
    unchanged()
end
failures.bartender=nil

-- Thrown adapter errors and invalid proposals are converted by PrepareSetup;
-- neither a raw exception nor implementation validation text enters the row.
local bartenderPrepare=V.adapters.bartender.Prepare
V.adapters.bartender.Prepare=function()error("private-error-sentinel")end
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(row(model,"actions").detail=="Bartender4's setup check failed in vasagoio. No settings were changed.",
    "Bartender API failure lost its useful fixed explanation")
check(not row(model,"actions").detail:find("private-error-sentinel",1,true),"Adapter exception leaked into setup")
check(not V:ApplySetup(review),"Throwing adapter bypassed the required gate")
unchanged()
V.adapters.bartender.Prepare=function()
    return {changes={{table={},path={"SetupHealthFixture","profiles","A","bartender"},key="configuration",value={width=320}}}}
end
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(row(model,"actions").detail=="Bartender4's preset changes could not be verified. No settings were changed.",
    "Bartender validation failure was reduced to a generic compatibility error")
check(not V:ApplySetup(review),"Invalid Bartender proposal bypassed the required gate")
unchanged()
V.adapters.bartender.Prepare=bartenderPrepare

-- Optional missing skins/guide placement do not prevent a complete HUD.
failures.skinner="Skinner version is unavailable";failures.restedxp="RestedXP version is unavailable"
loaded.Skinner=false;loaded.RXPGuides=false
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(model.canApply and model.title=="Ready to apply","Optional absence blocked the HUD")
check(row(model,"windows").state=="skipped" and row(model,"quests").state=="skipped","Optional absence was treated as success/error")
failures.prat="Prat profile is no longer initialized"
check(not V:ApplySetup(review),"Owner becoming unavailable after review was accepted")
unchanged();failures.prat=nil
failures.prat="Prat Font module is disabled"
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"chat").detail=="Enable Font in Prat, then reload.","Disabled Prat Font lacks an actionable status")
failures.prat=nil
review=V:PrepareSetup()
check(V:ApplySetup(review),"Complete core with optional extras skipped did not apply")
model=V:BuildSetupStatus(nil,"Reload before reviewing again")
check(model.title=="Reload needed" and model.needsReload and not model.canApply,"Saved settings did not require reload")
check(row(model,"windows").state=="skipped" and row(model,"quests").state=="skipped" and row(model,"units").state=="reload",
    "Optional skipped components became pending applications")
reload()
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(model.title=="No issues detected" and not model.canApply,"Matching applied preset was unnecessarily offered again")
for _,id in ipairs({"units","nameplates","actions","chat","minimap","meters"}) do
    check(row(model,id).state=="applied","Current matching component wasn't applied: "..id)
end
check(V.db.profileBackups[1].presetVersion==V.setupPresetVersion,"Preset compatibility version was not recorded")
check(V.setupPresetVersion==5,"Changed HUD/quest/nameplate targets need a new preset version")
failures.bartender="Main bar 1: native button geometry is unavailable. Reload UI and check again."
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(model.title=="Needs attention" and model.description=="Apply is blocked by Action bars. No changes were made by this check.",
    "A new blocker falsely claimed the already-applied preset was reset")
check(row(model,"units").state=="applied" and not model.canApply,"A new blocker invalidated healthy peer snapshots")
local previousBackupCount=#V.db.profileBackups
check(not V:ApplySetup(review) and #V.db.profileBackups==previousBackupCount,"Blocked check changed saved preset state")
V.db.profileBackups[1].presetVersion=V.setupPresetVersion-1
model=V:BuildSetupStatus(V:PrepareSetup())
check(model.title=="Preset not applied" and row(model,"units").state=="ready" and not model.canApply,
    "New installed preset with an older snapshot was confused with an applied preset")
V.db.profileBackups[1].presetVersion=V.setupPresetVersion
failures.bartender=nil
V.db.profileBackups[1].presetVersion=nil
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"units").state=="ready" and model.canApply,"Legacy snapshot hid newer preset corrections")
V.db.profileBackups[1].presetVersion=V.setupPresetVersion+1
check(row(V:BuildSetupStatus(V:PrepareSetup()),"actions").state=="ready","Different preset version was treated as current")
V.db.profileBackups[1].presetVersion=V.setupPresetVersion

-- Owner-added defaults may be harmless. Actual preset changes or switching to
-- another active owner profile must never inherit an old Applied badge.
SetupHealthFixture.profiles.A.unitframes.configuration.ownerDefault=true
check(row(V:BuildSetupStatus(V:PrepareSetup()),"units").state=="applied","Owner-added defaults invalidated the preset")
SetupHealthFixture.profiles.A.unitframes.configuration.width=321
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"units").state=="ready" and model.canApply,"Edited preset was falsely reported as applied")
SetupHealthFixture.profiles.A.unitframes.configuration.width=320
SetupHealthFixture.profiles.B=V:Copy(SetupHealthFixture.profiles.A);selected="B"
check(row(V:BuildSetupStatus(V:PrepareSetup()),"units").state=="ready","Inactive profile snapshot was reported as active")
selected="A"

-- A new unsupported version beats old snapshots. Runtime errors likewise
-- prevent core Apply; they aren't translated into a misleading Ready label.
failures.nameplates="Requires audited Threat Plates 13.3.9"
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"nameplates").state=="attention" and not model.canApply,"Unsupported version inherited Applied")
check(row(model,"nameplates").detail:find("compatibility review",1,true),"Version failure recommends a blind upgrade")
failures.nameplates=nil
V.status.actionBars={state="error",detail="internal technical error"}
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(row(model,"actions").state=="attention" and not model.canApply,"Runtime failure was hidden")
check(not V:ApplySetup(review),"Actual transaction ignored runtime core error")
V.status.actionBars={state="applied"}
V.db.modules.auras=false
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"units").state=="attention" and not model.canApply,"Disabled core aura styling was silently accepted")
V.db.modules.auras=nil
V.status.meter=nil
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"meters").state=="attention" and not model.canApply,"Missing runtime result was fabricated")
V.status.meter={state="applied"}

-- Older partial snapshots and an applied revision alone cannot certify all
-- components. Each component needs its own matching recorded application.
local completeBackups=V.db.profileBackups
local partial={changes={},presetVersion=V.setupPresetVersion}
for _, change in ipairs(completeBackups[1].changes) do
    if change.adapter=="unitframes" then partial.changes[#partial.changes+1]=change end
end
V.db.profileBackups={partial};V.db.appliedRevision=10
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"units").state=="applied" and row(model,"chat").state=="ready" and model.title~="No issues detected",
    "Partial application was reported as a complete preset")
V.db.profileBackups=completeBackups

-- Loaded strict addon skins can be skipped independently of Skinner. Show
-- their review boundary even if another window integration was applied.
local mismatched="Gargul"
V.AddonInteriors={Reviewed=function(_,name)return name~=mismatched end}
loaded.Gargul=true
model=V:BuildSetupStatus(V:PrepareSetup())
check(row(model,"windows").state=="attention" and row(model,"windows").detail:find("Gargul",1,true),
    "Loaded unreviewed addon skin was reported as healthy")
loaded.Gargul=false
check(row(V:BuildSetupStatus(V:PrepareSetup()),"windows").state=="skipped","Absent optional skin caused an error")
V.AddonInteriors=nil

-- Failed optional styling is excluded before its profile is even prepared.
-- A new failure after review rejects the stale transaction instead of quietly
-- changing which settings the user approved.
failures.skinner=nil;failures.restedxp=nil;loaded.Skinner=true;loaded.RXPGuides=true
V.status.nativeWindows={state="error"};V.status.questHUD={state="error"}
local skinPrepares,questPrepares=prepares.skinner,prepares.restedxp
review=V:PrepareSetup();model=V:BuildSetupStatus(review)
check(prepares.skinner==skinPrepares and prepares.restedxp==questPrepares,"Failed optional owner was prepared")
check(#model.blockers==0 and row(model,"windows").state=="attention" and row(model,"quests").state=="attention",
    "Optional errors blocked the core or were hidden")
check(V:ApplySetup(review),"Optional errored owners blocked a complete reviewed HUD")
check(SetupHealthFixture.profiles.A.skinner.configuration.width==100 and SetupHealthFixture.profiles.A.restedxp.configuration.width==100,
    "An optional errored owner received preset writes")
reload()
review=V:PrepareSetup()
local backupCount=#V.db.profileBackups
V.status.nativeWindows={state="error"}
check(not V:ApplySetup(review) and #V.db.profileBackups==backupCount,"New optional error silently changed a reviewed transaction")
V.status.nativeWindows={state="applied"};V.status.addonWindows={state="error"}
review=V:PrepareSetup()
local skinPresent=false
for _, entry in ipairs(review.adapters) do if entry.id=="skinner" then skinPresent=true end end
check(skinPresent,"Independent addon-window error incorrectly blocked Skinner's native palette")
V.status.addonWindows={state="applied"}

-- Generated profile names change on every FUF/Threat Plates review. A fresh
-- name alone is harmless, but scale-derived desired contents must stay current.
for _, fixture in ipairs({
    {id="unitframes",row="units",root="ForeverUnitFramesDB",pointer="active"},
    {id="nameplates",row="nameplates",root="ThreatPlatesDB",pointer="profileKeys"},
}) do
    local savedBackups=V.db.profileBackups
    local owner={profiles={vasagoio={geometry={width=320,height=64},ownerDefault=true}},
        [fixture.pointer]={Example="vasagoio"},raid={Example={r40={cellWidth=96}}}}
    _G[fixture.root]=owner
    local snapshot={presetVersion=V.setupPresetVersion,changes={}}
    review=V:PrepareSetup()
    for i=#review.changes,1,-1 do
        if review.changes[i].adapter==fixture.id then table.remove(review.changes,i) end
    end
    local function add(path,key,oldAfter,newKey,newAfter)
        snapshot.changes[#snapshot.changes+1]={adapter=fixture.id,path=path,key=key,after=oldAfter}
        local proposed={adapter=fixture.id,path=path,key=newKey or key,after=newAfter or oldAfter}
        review.changes[#review.changes+1]=proposed
        return proposed
    end
    local profile=add({fixture.root,"profiles"},"vasagoio",{geometry={width=320,height=64}},
        "vasagoio 2",{geometry={width=320,height=64}})
    add({fixture.root,fixture.pointer},"Example","vasagoio",nil,"vasagoio 2")
    local auxiliary
    if fixture.id=="unitframes" then
        auxiliary=add({fixture.root,"raid","Example"},"r40",{cellWidth=96})
    else
        owner.namespaces={["LibDualSpec-1.0"]={char={Example={[1]="vasagoio"}}}}
        add({fixture.root,"namespaces","LibDualSpec-1.0","char","Example"},1,"vasagoio",nil,"vasagoio 2")
    end
    V.db.profileBackups={}
    for _, backup in ipairs(savedBackups) do V.db.profileBackups[#V.db.profileBackups+1]=backup end
    V.db.profileBackups[#V.db.profileBackups+1]=snapshot
    check(row(V:BuildSetupStatus(review),fixture.row).state=="applied","Fresh generated name/defaults invalidated "..fixture.id)
    profile.after.geometry.width=400
    check(row(V:BuildSetupStatus(review),fixture.row).state=="ready","Changed scale proposal inherited Applied: "..fixture.id)
    profile.after.geometry.width=320
    if auxiliary then
        auxiliary.after={cellWidth=120}
        check(row(V:BuildSetupStatus(review),fixture.row).state=="ready","Changed raid geometry inherited Applied")
        auxiliary.after={cellWidth=96}
    end
    owner[fixture.pointer].Example="Other profile"
    check(row(V:BuildSetupStatus(review),fixture.row).state=="ready","Inactive generated profile inherited Applied")
    V.db.profileBackups=savedBackups
end

V.uiReloadPending=true
check(V:PrepareSetup()==nil and not V:ApplySetup(V.setupReview),"UI enable/disable reload guard was bypassed")
model=V:BuildSetupStatus(nil)
check(model.needsReload and not model.canApply and model.title=="Reload needed","UI reload wasn't prioritized")
V.uiReloadPending=nil;V.db.enabled=false
model=V:BuildSetupStatus(nil)
check(model.title=="Styling is off" and not model.canApply,"Disabled addon offered Apply")
V.readOnly=true
model=V:BuildSetupStatus(nil)
check(model.title=="Needs attention" and row(model,"units").state=="attention" and not model.canApply,"Read-only settings offered Apply")
print("setup_status_spec: required HUD gate, optional skips, truthful applied snapshots, profile/version changes and reload/error states passed")
