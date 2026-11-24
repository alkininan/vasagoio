local addonName, V = ...

-- RXP v4.11.40 saves live frame points on PLAYER_LOGOUT. Updating only its
-- SavedVariables would therefore be overwritten during the requested reload.
-- Keep reviewed saved anchors and the corresponding live frame in sync, without
-- changing guide sizes, progress callbacks, secure item/target controls or automation settings.
local OWNER, ADAPTER = "questHUD", "restedxp"
local presentationDisable
local function questInsets()
    local q = V.Tokens.quest or {}
    return q.right or 8, q.top or 128
end
local names = { "RXPFrame", "RXPV2GuideWindow" }
local knownNames = { RXPFrame = true, RXPV2GuideWindow = true }
local anchors = { TOPLEFT=true, TOP=true, TOPRIGHT=true, LEFT=true, CENTER=true,
    RIGHT=true, BOTTOMLEFT=true, BOTTOM=true, BOTTOMRIGHT=true }

local function reviewed()
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = metadata and metadata("RXPGuides", "Version")
    return not V:IsSecret(version) and version == "v4.11.40"
end

local function owner()
    if not LibStub then return end
    local ok, ace = pcall(function() return LibStub("AceAddon-3.0", true) end)
    if not ok or not ace or type(ace.GetAddon) ~= "function" then return end
    local found, rxp = pcall(ace.GetAddon, ace, "RXPGuides", true)
    if not found or not rxp or type(rxp.GetModule) ~= "function" then return end
    local loaded, settings = pcall(rxp.GetModule, rxp, "Settings", true)
    if not loaded or not settings or type(settings.GetSettingsDB) ~= "function" then return end
    local got, key = pcall(settings.GetSettingsDB, settings)
    if not got or V:IsSecret(key) or type(key) ~= "string" then return end
    local profiles = _G.RXPSettings and _G.RXPSettings.profiles
    local profile = type(profiles) == "table" and rawget(profiles, key)
    if type(profile) ~= "table" or profile ~= settings.profile or
        type(profile.framePositions) ~= "table" or type(rxp.enabledFrames) ~= "table" then return end
    return rxp, profile, key
end

local function usable(frame)
    if V:IsSecret(frame) or (type(frame) ~= "table" and type(frame) ~= "userdata") then return false end
    if type(frame.ClearAllPoints) ~= "function" or type(frame.SetPoint) ~= "function" or
        type(frame.GetEffectiveScale) ~= "function" or type(frame.GetNumPoints) ~= "function" or
        type(frame.GetPoint) ~= "function" then return false end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or V:IsSecret(forbidden) or forbidden then return false end
    end
    return true
end

local function validPoints(points)
    if V:IsSecret(points) or type(points) ~= "table" or #points == 0 or #points > 9 then return false end
    for _, point in ipairs(points) do
        if V:IsSecret(point) or type(point) ~= "table" then return false end
        local anchor, relative, relativePoint, x, y = point[1], point[2], point[3], point[4], point[5]
        if V:IsSecret(anchor) or V:IsSecret(relative) or V:IsSecret(relativePoint) or
            not anchors[anchor] or not anchors[relativePoint] or not V:SafeNumber(x) or not V:SafeNumber(y) then return false end
        if relative ~= nil and (type(relative) ~= "string" or not usable(_G[relative])) then return false end
    end
    return true
end

local function capturePoints(frame)
    local count = V:SafeNumber(frame:GetNumPoints())
    assert(count and count >= 1 and count <= 9 and count % 1 == 0, "RXP live guide anchors are unavailable")
    local points = {}
    for i = 1, count do
        local anchor, relative, relativePoint, x, y = frame:GetPoint(i)
        assert(not V:IsSecret(anchor) and not V:IsSecret(relative) and not V:IsSecret(relativePoint) and
            anchors[anchor] and anchors[relativePoint] and V:SafeNumber(x) and V:SafeNumber(y) and
            (relative == nil or usable(relative)), "RXP live guide anchor is restricted or unsupported")
        points[i] = {anchor, relative, relativePoint, x, y}
    end
    return points
end

local function writeLivePoints(frame, points)
    frame:ClearAllPoints()
    for _, point in ipairs(points) do frame:SetPoint(point[1], point[2], point[3], point[4], point[5]) end
end

local function matchesSaved(live, saved)
    if #live ~= #saved then return false end
    for i, point in ipairs(live) do
        local other = saved[i]
        if point[1] ~= other[1] or point[3] ~= other[3] or
            (point[2] or UIParent) ~= (other[2] and _G[other[2]] or UIParent) or
            math.abs(point[4] - other[4]) > .01 or math.abs(point[5] - other[5]) > .01 then return false end
    end
    return true
end

local function synchronize(targets)
    assert(not InCombatLockdown(), "RXP guide anchors cannot change in combat")
    -- Capture every target before the first write. RXP saves live points on
    -- logout, so a partial ClearAllPoints/SetPoint failure must not persist an
    -- empty guide anchor or leave an earlier guide at the proposed position.
    for _, target in ipairs(targets) do
        assert(usable(target.frame) and validPoints(target.points), "RXP guide anchor is not writable")
        target.before = capturePoints(target.frame)
        target.after = {}
        for i, point in ipairs(target.points) do
            target.after[i] = {point[1], point[2] and _G[point[2]] or UIParent, point[3], point[4], point[5]}
        end
    end
    local touched = 0
    local ok, failure = pcall(function()
        for i, target in ipairs(targets) do
            touched = i
            writeLivePoints(target.frame, target.after)
        end
    end)
    if not ok then
        local recovered = true
        for i = touched, 1, -1 do
            if not pcall(writeLivePoints, targets[i].frame, targets[i].before) then recovered = false end
        end
        if not recovered then error("RXP live anchor recovery failed; reload and inspect the guide") end
        error(failure)
    end
end

local function isActiveChange(change, profile, key)
    local path = change.path
    return type(path) == "table" and #path == 4 and path[1] == "RXPSettings" and
        path[2] == "profiles" and path[3] == key and path[4] == "framePositions" and
        knownNames[change.key] and _G.RXPSettings.profiles[key].framePositions == profile.framePositions
end

V:RegisterProfileAdapter(ADAPTER, {
    label = "RestedXP: guide below long auras", addon = "RXPGuides", module = OWNER,
    Prepare = function()
        if not reviewed() then return nil, "RestedXP v4.11.40 is required for the reviewed guide anchor" end
        local rxp, profile, key = owner()
        if not rxp then return nil, "RestedXP's active Settings profile must be initialized; log in and reload once" end
        if InCombatLockdown() then return nil, "Leave combat before changing guide anchors" end
        local guide=rxp.RXPFrame or rxp.enabledFrames.RXPFrame
        if not guide or type(guide.SetStepFrameAnchor)~="function" then
            return nil,"RestedXP's active-step anchor API is unavailable; reload once before setup"
        end
        local plan = { changes = {}, detail = "Place RestedXP at the reviewed right-edge anchor below long auras. Enable presentation-only combat hiding and a manual guide toggle. Preserve guide callbacks, sizes, active items/targets and automation settings. Apply/Restore synchronize saved and live anchors." }
        local right, top = questInsets()
        local uiScale = V:SafeNumber(UIParent:GetEffectiveScale())
        if not uiScale or uiScale <= 0 then return nil, "UI scale is unavailable" end
        for _, name in ipairs(names) do
            local frame = rxp.enabledFrames[name]
            if frame then
                if not usable(frame) or frame.savePosition == false or not validPoints(profile.framePositions[name]) then
                    return nil, "RestedXP guide anchors are not initialized or supported; reload once before setup"
                end
                local captured, live = pcall(capturePoints, frame)
                if not captured then return nil, "RestedXP live guide anchors are not ready; reload once before setup" end
                if not matchesSaved(live, profile.framePositions[name]) then
                    return nil, "RestedXP has an unsaved guide position; reload once before reviewing setup"
                end
                local scale = V:SafeNumber(frame:GetEffectiveScale())
                if not scale or scale <= 0 then return nil, "RestedXP guide scale is unavailable" end
                local ratio = uiScale / scale
                plan.changes[#plan.changes+1] = {
                    table = profile.framePositions,
                    path = {"RXPSettings", "profiles", key, "framePositions"}, key = name,
                    value = {{"TOPRIGHT", "UIParent", "TOPRIGHT", -V:Pixel(right)*ratio, -V:Pixel(top)*ratio}},
                    label = name .. " below long auras",
                }
            end
        end
        if #plan.changes == 0 then return nil, "RestedXP guide window is not initialized" end
        plan.changes[#plan.changes+1] = {table=profile,path={"RXPSettings","profiles",key},
            key="anchorOrientation",value="bottom",label="RestedXP active steps below guide"}
        if type(V.db.overrides) ~= "table" then return nil, "vasagoio settings need initialization" end
        plan.changes[#plan.changes+1] = {table=V.db.overrides, path={"VasagoioDB","overrides"},
            key="questGuideProfile", value=key, label="RestedXP presentation ownership"}
        return plan
    end,
    AfterApply = function(_, changes)
        local rxp, profile, key = owner()
        assert(rxp, "RestedXP active profile is unavailable")
        local targets = {}
        if changes then
            -- Failed restoration recovery supplies the snapshot's exact paths.
            -- Do not reconcile a different active profile to unrelated data.
            for _, change in ipairs(changes) do
                if isActiveChange(change, profile, key) then
                    assert(reviewed(), "RestedXP version changed after review")
                    targets[#targets+1] = {frame=rxp.enabledFrames[change.key], points=profile.framePositions[change.key]}
                end
            end
        else
            assert(reviewed(), "RestedXP version changed after review")
            for _, name in ipairs(names) do
                local frame = rxp.enabledFrames[name]
                if frame then targets[#targets+1] = {frame=frame, points=profile.framePositions[name]} end
            end
        end
        synchronize(targets)
        if #targets>0 then
            local guide=rxp.RXPFrame or rxp.enabledFrames.RXPFrame
            assert(guide and type(guide.SetStepFrameAnchor)=="function","RestedXP active-step anchor API is unavailable")
            guide.SetStepFrameAnchor()
        end
    end,
    ValidateRestore = function(_, changes)
        local rxp, profile, key = owner()
        -- The restored path may belong to a different, currently inactive
        -- profile. RXP's logout callback cannot overwrite that profile.
        if not rxp then return false, "Load RestedXP's Settings profile before restoring its guide anchor" end
        for _, change in ipairs(changes) do
            if isActiveChange(change, profile, key) then
                local frame = rxp.enabledFrames[change.key]
                if not reviewed() or InCombatLockdown() or not usable(frame) or frame.savePosition == false or not validPoints(change.before) then
                    return false, "The active RestedXP guide anchor cannot be safely restored; use the reviewed version out of combat"
                end
                if not pcall(capturePoints, frame) then return false, "The active RestedXP live anchor cannot be captured for safe restoration" end
                local guide=rxp.RXPFrame or rxp.enabledFrames.RXPFrame
                if not guide or type(guide.SetStepFrameAnchor)~="function" then
                    return false,"RestedXP active-step anchors cannot be restored; reload the reviewed owner first"
                end
            end
        end
        return true
    end,
    AfterRestore = function(_, changes)
        local rxp, profile, key = owner()
        if not rxp then return end
        local targets = {}
        for _, change in ipairs(changes) do
            if isActiveChange(change, profile, key) then
                targets[#targets+1] = {frame=rxp.enabledFrames[change.key], points=profile.framePositions[change.key]}
            end
        end
        synchronize(targets)
        if #targets>0 then
            local guide=rxp.RXPFrame or rxp.enabledFrames.RXPFrame
            assert(guide and type(guide.SetStepFrameAnchor)=="function","RestedXP active-step anchor API is unavailable")
            guide.SetStepFrameAnchor()
        end
        if presentationDisable then presentationDisable() end
    end,
})

-- Do not Hide() the legacy RXPFrame: its OnHide pauses guide progress. Keep
-- its owner callbacks running and change only alpha and ordinary mouse input.
-- The separate secure Active Items/Active Targets windows are never traversed.
local presentation, toggle, native
local inputMethods = {
    click={get="IsMouseClickEnabled",set="SetMouseClickEnabled"},
    motion={get="IsMouseMotionEnabled",set="SetMouseMotionEnabled"},
    wheel={get="IsMouseWheelEnabled",set="EnableMouseWheel"},
}
local syncPresentation, queuePresentation, restoreNative
local function plain(frame)
    if not usable(frame) or type(frame.IsProtected)~="function" then return false end
    local ok, protected = pcall(frame.IsProtected,frame)
    return ok and not V:IsSecret(protected) and protected==false
end
local function value(frame, method, kind)
    if type(frame[method])~="function" then return end
    local ok, result=pcall(frame[method],frame)
    if not ok or V:IsSecret(result) or type(result)~=kind then return end
    if kind=="number" then return V:SafeNumber(result) end
    return result
end
local function active(s)
    if not s or not s.enabled or s~=presentation or not V:IsModuleEnabled(OWNER) or V.profileReloadPending or not reviewed() then return false end
    local rxp,profile,key=owner()
    return rxp==s.rxp and profile==s.profile and key==s.key and
        V.db.overrides and V.db.overrides.questGuideProfile==key
end
local function rootsFor(rxp)
    local roots,seen={},{}
    local function add(object)
        if V:IsSecret(object) or (type(object)~="table" and type(object)~="userdata") then return end
        local frame=object.frame or object
        if frame and not seen[frame] then roots[#roots+1]=frame;seen[frame]=true end
    end
    add(rxp.enabledFrames.RXPFrame)
    add(rxp.enabledFrames.RXPV2GuideWindow)
    -- The optional V2 player steps are a sibling, not a child of its guide.
    -- Never enable beta/V2, or include party steps, item or target controls.
    if type(rxp.player)=="table" and type(rxp.player.name)=="string" and not V:IsSecret(rxp.player.name) then
        add(rxp.enabledFrames["RXPActiveStepsFrame"..rxp.player.name])
    end
    return roots
end
local function belongs(s,frame)
    for _=1,24 do
        if s.roots[frame] then return true end
        if not frame or type(frame.GetParent)~="function" then return false end
        local ok,parent=pcall(frame.GetParent,frame)
        if not ok or V:IsSecret(parent) then return false end
        frame=parent
    end
    return false
end
local function writeInputs(s,frame,record,hide,restoring)
    if not plain(frame) and not (restoring and not InCombatLockdown() and usable(frame)) then return false end
    s.busy=true
    local ok=pcall(function()
        for key,method in pairs(inputMethods) do
            local desired=record[key]
            if hide then desired=false end
            if desired~=nil and value(frame,method.get,"boolean")~=desired then frame[method.set](frame,desired) end
        end
    end)
    s.busy=false
    return ok
end
local cleanupDetail="Guide restoration is incomplete. Reload UI to finish cleanup before changing its presentation."
local function restoreRoot(s,frame,record)
    local alpha=value(frame,"GetAlpha","number")
    if alpha==nil then return false end
    -- Preserve a later owner alpha; only undo our hidden presentation.
    if alpha~=0 or record.alpha==0 then return true end
    if not plain(frame) and not (not InCombatLockdown() and usable(frame)) then return false end
    s.busy=true
    local ok=pcall(frame.SetAlpha,frame,record.alpha)
    s.busy=false
    return ok
end
local function restorePresentation(s)
    if not s then return true end
    s.hidden=false;s.busy=true;s.restorePending=nil
    for frame,record in pairs(s.inputs) do
        if not writeInputs(s,frame,record,false,true) then s.restorePending=true end
    end
    for frame,record in pairs(s.roots) do
        if not restoreRoot(s,frame,record) then s.restorePending=true end
    end
    s.busy=false
    if toggle then toggle:Hide() end
    return not s.restorePending
end
local function captureInput(s,frame)
    if s.inputs[frame] then
        if not s.hidden then
            for key,method in pairs(inputMethods) do
                local current=value(frame,method.get,"boolean")
                if current==nil then return false end
                s.inputs[frame][key]=current
            end
        end
        return true
    end
    local record={}
    for key,method in pairs(inputMethods) do
        if type(frame[method.set])~="function" then return false end
        record[key]=value(frame,method.get,"boolean")
        if record[key]==nil then return false end
    end
    s.inputs[frame]=record
    local setters={EnableMouse={"click","motion"},EnableMouseMotion={"motion"},
        SetMouseClickEnabled={"click"},SetMouseMotionEnabled={"motion"},EnableMouseWheel={"wheel"}}
    for method,keys in pairs(setters) do
        if type(frame[method])=="function" then
            local fields=keys
            hooksecurefunc(frame,method,function()
                if s.busy or s~=presentation or not s.hidden then return end
                -- Read only the fields changed by this setter. Other fields
                -- are currently forced false and are not the owner's intent.
                for _,key in ipairs(fields) do
                    local current=value(frame,inputMethods[key].get,"boolean")
                    if current~=nil then record[key]=current end
                end
                if s.hidden then writeInputs(s,frame,record,active(s) and belongs(s,frame),true) end
            end)
        end
    end
    if frame.HookScript then frame:HookScript("OnShow",function() if active(s) and s.hidden then queuePresentation(s) end end) end
    return true
end
local function collect(s)
    local roots=rootsFor(s.rxp)
    local present={}
    for _,frame in ipairs(roots) do present[frame]=true end
    for frame,record in pairs(s.roots) do
        if not present[frame] then
            if not restoreRoot(s,frame,record) then s.restorePending=true;return false end
            s.roots[frame]=nil
        end
    end
    local visited,budget={},1024
    local function visit(frame,depth)
        if visited[frame] then return true end
        if depth>24 or budget<=0 or not plain(frame) then return false end
        visited[frame]=true;budget=budget-1
        if not captureInput(s,frame) then return false end
        if type(frame.GetChildren)~="function" then return false end
        local ok,children=pcall(function() return {frame:GetChildren()} end)
        if not ok then return false end
        for _,child in ipairs(children) do
            if V:IsSecret(child) or (type(child)~="table" and type(child)~="userdata") then return false end
            if not child.__vasagoio and not visit(child,depth+1) then return false end
        end
        return true
    end
    for _,frame in ipairs(roots) do
        if not plain(frame) then return false end
        if not s.roots[frame] then
            local alpha=value(frame,"GetAlpha","number")
            if not alpha or type(frame.SetAlpha)~="function" then return false end
            local record={alpha=alpha};s.roots[frame]=record
            hooksecurefunc(frame,"SetAlpha",function(_,new)
                if s.busy or s~=presentation then return end
                new=V:SafeNumber(new)
                if new then record.alpha=new end
                if active(s) and s.hidden and s.roots[frame]==record and plain(frame) then
                    s.busy=true;pcall(frame.SetAlpha,frame,0);s.busy=false
                end
            end)
        end
        if not visit(frame,0) then return false end
    end
    return #roots>0,visited
end
local function layoutToggle()
    if not CreateFrame or InCombatLockdown() then return end
    if not toggle then
        toggle=CreateFrame("Button","VasagoioQuestGuideToggle",UIParent)
        toggle.__vasagoio=true
        toggle:SetFrameStrata("MEDIUM")
        toggle.text=toggle:CreateFontString(nil,"OVERLAY")
        toggle.text:SetAllPoints(toggle)
        toggle.text:SetText("Guide")
        toggle:SetScript("OnClick",function() V:ToggleQuestGuide() end)
    end
    local right,top=questInsets()
    local x,y,width,height=V:Pixel(right),V:Pixel(top),V:Pixel(96),V:Pixel(24)
    local geometry=table.concat({x,y,width,height},":")
    if toggle.geometry~=geometry then
        toggle:ClearAllPoints();toggle:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-x,-y)
        toggle:SetSize(width,height);toggle.geometry=geometry
    end
    if V.Surface then V:Surface(toggle,V.Tokens.alpha.hud,V.Tokens.radius) end
    if V.StyleText then V:StyleText(toggle.text,"compact") end
end
syncPresentation=function(s)
    if s~=presentation then return false end
    if s.restorePending and not restorePresentation(s) then
        if V.Report then V:Report(OWNER,"pending",cleanupDetail) end
        return false
    end
    if not active(s) then
        local restored=restorePresentation(s);if s then s.enabled=false end
        if restoreNative and not restoreNative() then restored=false end
        if not restored and V.Report then V:Report(OWNER,"pending",cleanupDetail) end
        if V.InteriorSkin and not InCombatLockdown() then V.InteriorSkin:Restore(OWNER) end
        return false
    end
    local ok,visited=collect(s)
    if not ok then
        local restored=restorePresentation(s)
        if restoreNative and not restoreNative() then restored=false end
        if V.Report then
            V:Report(OWNER,restored and "unsupported" or "pending",restored and
                "RXP contains protected or unsupported guide controls; presentation hiding was not applied." or cleanupDetail)
        end
        return false
    end
    local hide=InCombatLockdown() or (V.db.overrides.questGuideHidden==true)
    s.hidden=hide
    for frame,record in pairs(s.inputs) do
        if not writeInputs(s,frame,record,hide and visited[frame]) then restorePresentation(s);return false end
    end
    s.busy=true
    for frame,record in pairs(s.roots) do
        local desired=hide and 0 or record.alpha
        if value(frame,"GetAlpha","number")~=desired then
            local good=pcall(frame.SetAlpha,frame,desired)
            if not good then s.busy=false;restorePresentation(s);return false end
        end
    end
    s.busy=false
    if toggle then
        toggle:SetShown(hide and s.profile.showEnabled~=false and s.profile.hideGuideWindow~=true)
        toggle:SetEnabled(not InCombatLockdown())
    end
    return true
end
queuePresentation=function(s)
    if not s or s.queued then return end
    s.queued=true
    local function run() s.queued=false;syncPresentation(s) end
    if C_Timer and C_Timer.After then C_Timer.After(0,run) else run() end
end
local function installOwnerHooks(s)
    local function refresh()
        if s==presentation and (s.hidden or not active(s)) then queuePresentation(s) end
        if s==presentation and active(s) and not s.hidden and not InCombatLockdown() then
            V:Refresh("RXP panels changed",OWNER)
        end
    end
    -- Legacy pools grow in SetStep and LoadGuide. BottomFrame.UpdateFrame
    -- also runs for periodic inactive-step maintenance and must not trigger
    -- whole-guide traversal or styling on every owner update.
    for _,name in ipairs({"SetStep","LoadGuide","SetupGuideWindow","UpdateTheme"}) do
        if type(s.rxp[name])=="function" then hooksecurefunc(s.rxp,name,refresh) end
    end
    local settings=s.rxp:GetModule("Settings",true)
    if settings and type(settings.LoadFramePositions)=="function" then
        hooksecurefunc(settings,"LoadFramePositions",function() if s==presentation then queuePresentation(s) end end)
    end
    if s.rxp.v2 and type(s.rxp.v2.UpdateActiveStepsFrame)=="function" then hooksecurefunc(s.rxp.v2,"UpdateActiveStepsFrame",refresh) end
end
restoreNative=function()
    if not native then return true end
    if InCombatLockdown() then native.restorePending=true;return false end
    local f=native.frame
    local got,parent=pcall(f.GetParent,f)
    if not usable(f) or not got or V:IsSecret(parent) then native.restorePending=true;return false end
    if parent==native.holder then
        native.busy=true;local ok=pcall(f.SetParent,f,native.parent);native.busy=false
        if not ok then native.restorePending=true;return false end
    end
    native.restorePending=nil
    return true
end
local function hideNative()
    if InCombatLockdown() then return false end
    local f=_G.ObjectiveTrackerFrame
    if not usable(f) or type(f.GetParent)~="function" or type(f.SetParent)~="function" then return false end
    if type(GetBuildInfo)~="function" then return false end
    local ok,version,build=pcall(GetBuildInfo)
    if not ok or V:IsSecret(version) or V:IsSecret(build) or version~="1.60.1" or build~="70938" then return false end
    if native and native.frame~=f then if not restoreNative() then return false end;native=nil end
    if not native then
        local got,parent=pcall(f.GetParent,f)
        if not got or V:IsSecret(parent) or not parent then return false end
        local holder=CreateFrame("Frame","VasagoioHiddenObjectives",UIParent)
        holder.__vasagoio=true;holder:SetAllPoints(UIParent);holder:Hide()
        native={frame=f,parent=parent,holder=holder}
        local record=native
        hooksecurefunc(f,"SetParent",function(_,parent)
            if record.busy or native~=record then return end
            if not V:IsSecret(parent) and parent~=record.holder then record.parent=parent end
            if presentation and active(presentation) and not InCombatLockdown() then
                record.busy=true;pcall(f.SetParent,f,record.holder);record.busy=false
            end
        end)
    end
    local got,current=pcall(f.GetParent,f)
    if got and not V:IsSecret(current) and current==native.holder then return true end
    native.busy=true;ok=pcall(f.SetParent,f,native.holder);native.busy=false
    return ok
end
presentationDisable=function()
    if presentation then presentation.enabled=false end
    local restored=restorePresentation(presentation)
    local nativeRestored=restoreNative()
    if V.InteriorSkin and not InCombatLockdown() then
        local ok,result=pcall(V.InteriorSkin.Restore,V.InteriorSkin,OWNER)
        if not ok or result==false then restored=false end
    end
    if not restored or not nativeRestored then
        if V.Report then V:Report(OWNER,"pending",cleanupDetail) end
        return false,cleanupDetail
    end
    return true
end
function V:IsQuestGuideHidden()
    return self.db and self.db.overrides and self.db.overrides.questGuideHidden==true or false
end
function V:ToggleQuestGuide()
    if not presentation or not active(presentation) then return false,"Apply the reviewed RestedXP preset first." end
    if InCombatLockdown() then return false,"The guide stays hidden during combat." end
    self.db.overrides.questGuideHidden=not self:IsQuestGuideHidden()
    if not syncPresentation(presentation) then return false,"Guide presentation could not be changed safely." end
    if not self:IsQuestGuideHidden() then self:Refresh("guide manually shown",OWNER) end
    return true,self:IsQuestGuideHidden() and "Guide hidden; progress and active item/target controls continue." or "Guide presentation restored."
end
local function styleGuide(rxp)
    local I=V.InteriorSkin
    if not I or InCombatLockdown() then return end
    local frame=rxp.RXPFrame or rxp.enabledFrames.RXPFrame
    if not plain(frame) then return end
    -- Reviewed legacy panels only. Keep step content, semantic text colors,
    -- checkboxes, logos, guide controls and all owner geometry intact.
    for _,panel in ipairs({frame.GuideName,frame.Footer,frame.BottomFrame}) do
        if plain(panel) then
            I:Panel(panel,"inset",OWNER)
            I:Hide(panel.bg,OWNER)
            I:Text(panel.text,"body",true,OWNER)
        end
    end
    local pool=frame.CurrentStepFrame and frame.CurrentStepFrame.framePool
    if type(pool)=="table" then
        for i=1,64 do
            local step=pool[i]
            if not step then break end
            if plain(step) then I:Panel(step,"inset",OWNER) end
        end
    end
end
local function applyPresentation()
    local rxp,profile,key=owner()
    if not rxp or not reviewed() or not V.db.overrides or V.db.overrides.questGuideProfile~=key then
        local restored,detail=presentationDisable()
        if not restored then return false,detail,"pending" end
        return false,"Apply the reviewed RestedXP preset to enable guide placement and presentation."
    end
    if not hooksecurefunc or not CreateFrame then return false,"Guide presentation APIs are unavailable." end
    if presentation and (presentation.rxp~=rxp or presentation.profile~=profile or presentation.key~=key) then
        local restored,detail=presentationDisable()
        if not restored then return false,detail,"pending" end
        presentation=nil
    end
    if not presentation then
        presentation={rxp=rxp,profile=profile,key=key,inputs={},roots={},enabled=true}
        installOwnerHooks(presentation)
    end
    if presentation.restorePending and not restorePresentation(presentation) then return false,cleanupDetail,"pending" end
    presentation.enabled=true
    layoutToggle()
    styleGuide(rxp)
    if not syncPresentation(presentation) then
        if presentation.restorePending or (native and native.restorePending) then return false,cleanupDetail,"pending" end
        return false,"RXP presentation is not supported by the current guide controls."
    end
    if not hideNative() then return false,"Guide presentation is ready; the native tracker could not be hidden safely on this client.","pending" end
    return true,"Guide below long auras; combat/manual presentation hiding preserves guide progress. Entire native tracker hidden; its quest-item/scenario controls are intentionally unavailable. RXP active items/targets remain usable."
end
V:RegisterModule(OWNER, {
    label = "Quest HUD", defaultEnabled = true,
    description = "Reviewed right-edge RXP guide, presentation-only hiding, and reversible native tracker suppression.",
    Apply = applyPresentation,
    Disable = presentationDisable,
})
if V.On then
    V:On("PLAYER_REGEN_DISABLED",function() if presentation then syncPresentation(presentation) end end)
    V:On("PLAYER_REGEN_ENABLED",function()
        if native and native.restorePending then restoreNative() end
        if presentation then syncPresentation(presentation) end
        if V:IsModuleEnabled(OWNER) then V:Refresh("quest combat ended",OWNER) end
    end)
    V:On("ADDON_LOADED",function(_,name)
        if name=="Blizzard_ObjectiveTracker" or name=="RXPGuides" then V:Refresh("quest owner loaded",OWNER) end
    end)
end
