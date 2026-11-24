local _, V = ...

-- UI policy stays separate from the profile transaction engine. A complete
-- core HUD is required; optional window/quest integrations may be skipped.
local sections = {
    {id="units", label="Unit frames", adapters={"unitframes"}, modules={"unitframes","auras"}, required=true},
    {id="nameplates", label="Nameplates", adapters={"nameplates"}, modules={"nameplates"}, required=true},
    {id="actions", label="Action bars", adapters={"bartender"}, modules={"actionBars"}, required=true},
    {id="trinkets", label="Trinkets", adapters={"trinkets"}, modules={"utilityBars"}},
    {id="chat", label="Chat", adapters={"hudLayout","prat"}, modules={"hud"}, required=true},
    {id="minimap", label="Minimap", adapters={"sexymap"}, modules={"hud"}, required=true},
    {id="meters", label="Meters", adapters={"details"}, modules={"meter"}, required=true},
    {id="windows", label="Window skins", adapters={"skinner"}, modules={"nativeWindows","addonWindows"}},
    {id="quests", label="Quest panels", adapters={"restedxp"}, modules={"questHUD"}},
}
local owners = {
    unitframes={"Forever Unit Frames","ForeverUnitFrames","unitframes"},
    nameplates={"Threat Plates","TidyPlates_ThreatPlates","nameplates"},
    bartender={"Bartender4","Bartender4","actionBars"},
    trinkets={"Forever Trinket Menu","ForeverTrinketMenu","utilityBars"},
    hudLayout={"HUD placement",nil,"hud"}, prat={"Prat","Prat-3.0","hud"},
    sexymap={"SexyMap","SexyMap","hud"}, details={"Details","Details","meter"},
    skinner={"Skinner","Skinner","nativeWindows"}, restedxp={"RestedXP","RXPGuides","questHUD"},
}
V.SetupSections = sections
-- Increment when functional preset targets change. Cosmetic/UI-only releases
-- keep this value; unmarked legacy snapshots require one reviewed application.
V.setupPresetVersion = 4

local function indexReview(review)
    local available, unavailable = {}, {}
    for _, item in ipairs(review and review.adapters or {}) do available[item.id] = true end
    for _, item in ipairs(review and review.unavailable or {}) do unavailable[item.id] = item.reason end
    return available, unavailable
end

function V:SetupAdapterIssue(id)
    local module = id=="skinner" and "nativeWindows" or id=="restedxp" and "questHUD"
    local state = module and self.status[module]
    if state and state.state=="error" then
        return "Styling reported an error. Reload and check again."
    end
end

local function moduleEnabled(id)
    local owner = owners[id]
    return owner and V.modules[owner[3]] and V:IsModuleEnabled(owner[3])
end

local function friendlyReason(id, reason)
    local owner = owners[id] or {"This component"}
    if not moduleEnabled(id) then return "This part of vasagoio is turned off." end
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if owner[2] and type(loaded) == "function" then
        local ok, value = pcall(loaded, owner[2])
        if ok and not V:IsSecret(value) and value == false then
            return owner[1] .. " is not loaded. Enable it and reload."
        end
    end
    -- Bartender's reviewed adapter already names the affected bar and the
    -- actionable geometry problem. Do not replace that with a guessed version
    -- error or generic compatibility message. The transaction engine replaces
    -- thrown errors and validation failures with these fixed reason codes.
    if id=="bartender" then
        if V:IsSecret(reason) or type(reason)~="string" or reason=="" then
            return "Bartender4 could not be checked. Reopen setup."
        elseif reason=="Profile adapter API error." then
            return "Bartender4's setup check failed in vasagoio. No settings were changed."
        elseif reason=="Profile snapshot failed validation." then
            return "Bartender4's preset changes could not be verified. No settings were changed."
        end
        return reason
    end
    local text = not V:IsSecret(reason) and type(reason) == "string" and reason:lower() or ""
    if id == "prat" and text:find("font module is disabled",1,true) then
        return "Enable Font in Prat, then reload."
    elseif text:find("reported an error",1,true) then
        return "Styling reported an error. Reload and check again."
    elseif text:find("version",1,true) or text:find("audited",1,true) or text:find("reviewed",1,true) then
        return "This " .. owner[1] .. " version needs compatibility review."
    elseif text:find("unsaved",1,true) then
        return "Reload once to save the guide position, then reopen setup."
    elseif id == "details" and (text:find("window 1",1,true) or text:find("initialized",1,true)) then
        return "Open Details window 1, then reload."
    elseif text:find("initial",1,true) or text:find("reload",1,true) or text:find("ready",1,true) then
        return "Open " .. owner[1] .. " once, then reload."
    elseif text:find("combat",1,true) then
        return "Leave combat, then reopen setup."
    elseif text:find("scale",1,true) then
        return "The current UI scale needs a compatible preset layout."
    end
    return owner[1] .. " needs a setup compatibility check."
end


local function samePath(a,b)
    if type(a)~="table" or type(b)~="table" or #a~=#b then return false end
    for i,value in ipairs(a) do if value~=b[i] then return false end end
    return true
end

-- Owners can add default fields on reload. Every recorded preset value must
-- still match, but additional owner fields do not make the preset unhealthy.
local function matchesValue(actual, expected, budget, depth)
    budget.left = budget.left - 1
    if budget.left < 0 or depth > 24 or V:IsSecret(actual) or V:IsSecret(expected) then return false end
    if type(actual) ~= type(expected) then return false end
    if type(expected) ~= "table" then return actual == expected end
    for key,value in pairs(expected) do
        if not matchesValue(actual[key],value,budget,depth+1) then return false end
    end
    return true
end

local function snapshotMatches(id, review)
    local snapshots = V.db and V.db.profileBackups or {}
    local changes
    -- A newer partial setup does not erase the last recorded application of a
    -- different component. Never infer coverage from appliedRevision alone.
    for i=#snapshots,1,-1 do
        local found = {}
        for _, change in ipairs(snapshots[i].changes or {}) do
            if change.adapter == id then found[#found+1] = change end
        end
        if #found>0 then
            if V:IsSecret(snapshots[i].presetVersion) or snapshots[i].presetVersion~=V.setupPresetVersion then return false end
            changes=found; break
        end
    end
    if not changes then return false end
    local currentPaths = {}
    for _, change in ipairs(review.changes or {}) do
        if change.adapter==id then currentPaths[#currentPaths+1]=change.path end
    end
    local budget={left=20000}
    for _, change in ipairs(changes) do
        local activePath=false
        for _, path in ipairs(currentPaths) do if samePath(path,change.path) then activePath=true;break end end
        if not activePath then return false end
        local target=V.ResolveProfilePath(change.path)
        if not target or not matchesValue(target[change.key],change.after,budget,0) then return false end
    end
    -- FUF/Threat Plates propose a fresh profile name on every review. Compare
    -- its desired contents against the applied profile, normalizing only the
    -- generated name and its pointers. Geometry must still match today's scale.
    local profileRoot=id=="unitframes" and "ForeverUnitFramesDB" or id=="nameplates" and "ThreatPlatesDB"
    local proposedProfile, recordedProfile
    if profileRoot then
        local path={profileRoot,"profiles"}
        for _, proposed in ipairs(review.changes or {}) do
            if proposed.adapter==id and samePath(proposed.path,path) then proposedProfile=proposed end
        end
        for _, change in ipairs(changes) do
            if samePath(change.path,path) then recordedProfile=change end
        end
        if (proposedProfile~=nil)~=(recordedProfile~=nil) then return false end
    end
    for _, proposed in ipairs(review.changes or {}) do
        if proposed.adapter==id then
            local key, expected=proposed.key,proposed.after
            if proposedProfile then
                if proposed==proposedProfile then key=recordedProfile.key
                elseif expected==proposedProfile.key then expected=recordedProfile.key end
            end
            local recorded=false
            for _, change in ipairs(changes) do
                if key==change.key and samePath(proposed.path,change.path) then recorded=true;break end
            end
            local target=V.ResolveProfilePath(proposed.path)
            if not recorded or not target or not matchesValue(target[key],expected,budget,0) then return false end
        end
    end
    return true
end

local function addonWindowIssue()
    local loaded=C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    local interiors=V.AddonInteriors
    if type(loaded)~="function" or not interiors or type(interiors.Reviewed)~="function" then return end
    for _, owner in ipairs({{"MRT","MRT"},{"Auctionator","Auctionator"},{"Gargul","Gargul"},{"TalentsForeverBook","Talents Forever"}}) do
        local ok, active=pcall(loaded,owner[1])
        if ok and not V:IsSecret(active) and active==true then
            local checked, compatible=pcall(interiors.Reviewed,interiors,owner[1])
            if not checked or V:IsSecret(compatible) or compatible~=true then
                return owner[2] .. "'s skin needs compatibility review."
            end
        end
    end
end

local function runtimeIssue(section)
    for _, id in ipairs(section.modules) do
        local item=V.status[id]
        if item and item.state=="error" then return "Styling reported an error. Reload and check again." end
    end
end

local function runtimeApplied(section)
    for _, id in ipairs(section.modules) do
        if not V.modules[id] or not V:IsModuleEnabled(id) then return false,"This part of vasagoio is turned off." end
        local item=V.status[id]
        if not item then return false,"Checks are still starting. Reopen setup after loading." end
        if item.state~="applied" then
            if id=="addonWindows" and item.state=="pending" then
                return false,"Open an addon window, then reopen setup to check its skin."
            end
            return false,"Styling needs another check. Reload and reopen setup."
        end
    end
    return true
end

function V:GetSetupBlockers(review)
    local available, unavailable = indexReview(review)
    local blockers, seen = {}, {}
    for _, section in ipairs(sections) do
        if section.required then
            for _, id in ipairs(section.adapters) do
                if not self.adapters[id] or not available[id] or not moduleEnabled(id) then
                    if not seen[section.id] then
                        blockers[#blockers+1] = {id=section.id,label=section.label,reason=friendlyReason(id,unavailable[id])}
                        seen[section.id] = true
                    end
                end
            end
            for _, id in ipairs(section.modules) do
                local state = self.status[id]
                if not self.modules[id] or not self:IsModuleEnabled(id) then
                    if not seen[section.id] then
                        blockers[#blockers+1] = {id=section.id,label=section.label,reason="This part of vasagoio is turned off."}
                        seen[section.id] = true
                    end
                elseif state and state.state == "error" and not seen[section.id] then
                    blockers[#blockers+1] = {id=section.id,label=section.label,reason="Styling reported an error. Reload and check again."}
                    seen[section.id] = true
                end
            end
            if not seen[section.id] and review then
                local matched=true
                for _, id in ipairs(section.adapters) do if not snapshotMatches(id,review) then matched=false;break end end
                if matched then
                    local healthy, detail=runtimeApplied(section)
                    if not healthy then blockers[#blockers+1]={id=section.id,label=section.label,reason=detail} end
                end
            end
        end
    end
    return blockers
end


function V:BuildSetupStatus(review, reason)
    local model={rows={},canApply=false,needsReload=self.profileReloadPending==true or self.uiReloadPending==true}
    local statusReview=review or (model.needsReload and self.pendingSetupReview)
    local available, unavailable=indexReview(statusReview)
    model.blockers=review and self:GetSetupBlockers(review) or {}
    local blocked={}
    for _, issue in ipairs(model.blockers) do blocked[issue.id]=issue.reason end
    local disabled=not self.db or not self.db.enabled
    local ready, attention, applied, skipped=0,0,0,0
    for index, section in ipairs(sections) do
        local row={id=section.id,label=section.label,required=section.required==true,order=index}
        local missing
        for _, id in ipairs(section.adapters) do
            if not available[id] or not moduleEnabled(id) then missing=id;break end
        end
        if self.readOnly then row.state,row.detail="attention","Update vasagoio before changing these settings."
        elseif disabled then row.state,row.detail="off","Enable vasagoio with /vasagoio on, then reload."
        elseif model.needsReload then
            if statusReview and missing and not section.required then
                row.state,row.detail="skipped",friendlyReason(missing,unavailable[missing])
            else row.state,row.detail="reload","Reload UI to finish checking this component." end
        elseif not review then row.state,row.detail="attention","Reopen setup out of combat to run its checks."
        elseif blocked[section.id] then row.state,row.detail="attention",blocked[section.id]
        elseif runtimeIssue(section) then row.state,row.detail="attention",runtimeIssue(section)
        elseif section.id=="windows" and addonWindowIssue() then row.state,row.detail="attention",addonWindowIssue()
        elseif missing then
            row.state=section.required and "attention" or "skipped"
            row.detail=friendlyReason(missing,unavailable[missing])
        else
            local matched=true
            for _, id in ipairs(section.adapters) do if not snapshotMatches(id,review) then matched=false;break end end
            if matched then
                local healthy, detail=runtimeApplied(section)
                row.state=healthy and "applied" or "attention"
                row.detail=healthy and "Preset settings match; available styling checks passed." or detail
            else
                row.state,row.detail="ready","Ready to apply the preset."
            end
        end
        if row.state=="ready" then ready=ready+1
        elseif row.state=="attention" then attention=attention+1
        elseif row.state=="applied" then applied=applied+1
        elseif row.state=="skipped" then skipped=skipped+1 end
        model.rows[#model.rows+1]=row
    end
    table.sort(model.rows,function(a,b)
        if (a.state=="attention")~=(b.state=="attention") then return a.state=="attention" end
        return a.order<b.order
    end)
    if self.readOnly then
        model.title,model.description="Needs attention","Your saved settings need a newer vasagoio version."
    elseif model.needsReload then
        model.title,model.description="Reload needed","Reload UI to activate saved settings and finish the checks."
    elseif disabled then
        model.title,model.description="Styling is off","Use /vasagoio on, then reload to check the preset."
    elseif not review then
        model.title,model.description="Needs attention",type(reason)=="string" and reason or "Reopen setup to run its checks."
    elseif #model.blockers>0 then
        local blockedBy="Apply is blocked by " .. model.blockers[1].label .. "."
        if ready>0 then
            model.title,model.description="Preset not applied","The full preset has not been applied. " .. blockedBy
        else
            model.title,model.description="Needs attention",blockedBy .. " No changes were made by this check."
        end
    elseif attention>0 then
        model.title,model.description="Needs attention",attention .. (attention==1 and " component needs a check." or " components need a check.") .. " Optional extras may be skipped."
    elseif ready>0 then
        model.title,model.description="Ready to apply",ready .. (ready==1 and " component ready" or " components ready") .. (skipped>0 and "; " .. skipped .. " optional skipped." or ".")
    else
        model.title,model.description="No issues detected","Available checks passed" .. (skipped>0 and "; " .. skipped .. " optional skipped." or ".")
    end
    model.canApply=not disabled and not self.readOnly and not model.needsReload and review~=nil and
        #model.blockers==0 and #review.changes>0 and ready>0
    return model
end
