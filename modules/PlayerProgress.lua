local _, V = ...
local state

local function number(value) return V:SafeNumber(value) end
local function px(value) return math.floor(V:Pixel(value) + .5) end
local function configured()
    if not (state and state.enabled and not V.profileReloadPending and V.db and V.db.overrides and
        V.db.overrides.playerProgress == true and V:IsModuleEnabled("unitframes")) then return false end
    local profile,name=V:GetReviewedUnitProfile()
    return profile==state.profile and name==state.profileName
end
local function report(kind, detail)
    if V.Report then V:Report("playerProgress", kind, detail) end
end
local function capture(widget)
    if not widget or not widget.GetHeight or not widget.GetNumPoints or not widget.GetPoint then return end
    local height, count = number(widget:GetHeight()), number(widget:GetNumPoints())
    if not height or not count or count < 1 or count > 4 then return end
    local points = {}
    for i=1,count do
        local a,r,b,x,y = widget:GetPoint(i)
        if V:IsSecret(a) or V:IsSecret(r) or V:IsSecret(b) or type(a)~="string" or type(b)~="string" or
            not number(x) or not number(y) then return end
        points[i]={a,r,b,x,y}
    end
    return {height=height,points=points}
end
local function samePoints(a,b)
    if not a or not b or #a~=#b then return false end
    for i,point in ipairs(a) do
        for j=1,5 do if point[j]~=b[i][j] then return false end end
    end
    return true
end
local function restoreWidget(widget,saved,applied)
    local current=capture(widget)
    if not current or not applied then return end
    -- An owner/profile change may already have laid out the bar. Undo only
    -- the geometry that still matches our last write, preserving newer work.
    if samePoints(current.points,applied.points) then
        widget:ClearAllPoints()
        for _,point in ipairs(saved.points) do widget:SetPoint(unpack(point)) end
    end
    if current.height==applied.height then widget:SetHeight(saved.height) end
end
local function restore()
    if not state then return end
    if InCombatLockdown() then state.pending=true;return end
    state.busy=true
    if state.layoutActive then
        restoreWidget(state.frame.health,state.health,state.applied.health)
        restoreWidget(state.frame.power,state.power,state.applied.power)
        state.frame.healthHeight=number(state.frame.health:GetHeight()) or state.health.height
        state.frame.powerHeight=number(state.frame.power:GetHeight()) or state.power.height
    end
    state.bar:Hide()
    state.layoutActive,state.geometryKey,state.pending,state.applied=false,nil,nil,nil
    state.busy=false
end
local function xpData()
    -- Use the same visibility rule as the client's XP bar. At maximum level
    -- (or with XP disabled) there is no substitute reputation/honor display.
    if not GameRulesUtil or type(GameRulesUtil.CanShowExperienceBar)~="function" then return end
    local ok,visible=pcall(GameRulesUtil.CanShowExperienceBar)
    if not ok or V:IsSecret(visible) or type(visible)~="boolean" then return end
    if not visible then return false end
    if type(UnitXP)~="function" or type(UnitXPMax)~="function" then return end
    local got,current=pcall(UnitXP,"player")
    local gotMax,maximum=pcall(UnitXPMax,"player")
    current,maximum=got and number(current),gotMax and number(maximum)
    if not current or not maximum or current<0 or maximum<=0 then return end
    return true,math.min(current,maximum),maximum
end
local function layout()
    if InCombatLockdown() then state.pending=true;return end
    local frame=state.frame
    local spec=V.Tokens.playerProgress
    local total=frame.GetHeight and number(frame:GetHeight())
    if not spec or not total or math.abs(total-px(V.Tokens.units.large.height))>1 then
        restore();report("unsupported","Player progress requires the reviewed unit-frame height.");return
    end
    local health,gap,progress=px(spec.health),px(spec.gap),px(spec.height)
    local power=total-health-2*gap-progress
    if health<1 or power<1 or progress<1 then restore();return end
    local key=table.concat({health,gap,power,progress,total},":")
    if state.layoutActive and not state.dirty and state.geometryKey==key then return end
    -- Only FUF's plain StatusBars move. Never resize/reanchor its secure unit
    -- button, portrait or click area. Both owner power anchors are reviewed.
    for _,point in ipairs(state.power.points) do
        if (point[1]~="BOTTOMLEFT" and point[1]~="BOTTOMRIGHT") or point[2]~=frame or
            point[3]~=point[1] then
            restore();report("unsupported","Player resource anchors need compatibility review.");return
        end
    end
    state.busy=true
    frame.health:SetHeight(health)
    frame.power:ClearAllPoints()
    state.bar:ClearAllPoints()
    for _,point in ipairs(state.power.points) do
        frame.power:SetPoint(point[1],frame,point[3],point[4],point[5]+gap+progress)
        state.bar:SetPoint(point[1],frame,point[3],point[4],point[5])
    end
    frame.power:SetHeight(power)
    state.bar:SetHeight(progress)
    frame.healthHeight,frame.powerHeight=health,power
    state.applied={health=capture(frame.health),power=capture(frame.power)}
    state.bar:Show()
    state.layoutActive,state.geometryKey,state.dirty,state.pending=true,key,nil,nil
    state.busy=false
end
local function update()
    if not state then return end
    if not configured() then state.enabled=false;restore();return end
    local show,current,maximum=xpData()
    if show==nil then
        restore();report("unsupported","Native XP information is unavailable; normal unit rows retained.");return
    end
    if not show then
        restore();report("applied","XP unavailable or capped; normal health/resource rows retained.");return
    end
    if state.maximum~=maximum then state.bar:SetMinMaxValues(0,maximum);state.maximum=maximum end
    if state.current~=current then state.bar:SetValue(current);state.current=current end
    layout()
    if state.layoutActive then report("applied","XP below player power; normal rows return at maximum level.") end
end

function V:StylePlayerProgress(frame)
    if not frame or frame.key~="player" then return end
    if InCombatLockdown() then return end
    if not self.db.overrides or self.db.overrides.playerProgress~=true then
        if state then state.enabled=false;restore() end
        return
    end
    local profile,name=self:GetReviewedUnitProfile()
    if not profile then
        if state then state.enabled=false;restore() end
        return
    end
    if state and (state.frame~=frame or state.profile~=profile or state.profileName~=name) then
        state.enabled=false;restore();state=nil
    end
    if not state then
        local health,power=capture(frame.health),capture(frame.power)
        if not health or not power or not hooksecurefunc then
            report("unsupported","Player progress requires initialized FUF health/resource widgets.");return
        end
        local bar=CreateFrame("StatusBar",nil,frame)
        bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        local color=self.Tokens.colors.informationFill
        bar:SetStatusBarColor(color[1],color[2],color[3],self.Tokens.alpha.unit)
        local bg=bar:CreateTexture(nil,"BACKGROUND")
        bg:SetAllPoints(bar)
        local track=self.Tokens.colors.track
        bg:SetColorTexture(track[1],track[2],track[3],0)
        bar:Hide()
        state={frame=frame,bar=bar,health=health,power=power,enabled=true,profile=profile,profileName=name}
        frame.vasagoioProgress=bar
        local ownState=state
        for _,field in ipairs({"health","power"}) do
            local slot=field
            hooksecurefunc(frame[slot],"SetHeight",function()
                if state~=ownState or state.busy then return end
                if not configured() and state.applied and state.applied[slot] then
                    -- Preserve a deliberate new-owner height even when its
                    -- value happens to equal our compact row's height.
                    state.applied[slot].height=nil
                end
                local baseline=capture(frame[slot])
                if baseline then
                    local applied=state.layoutActive and state.applied and state.applied[slot]
                    if applied then
                        -- A height-only owner write leaves our shifted points
                        -- in place. They must never become the next baseline.
                        if samePoints(baseline.points,applied.points) then baseline.points=state[slot].points end
                        if baseline.height==applied.height then baseline.height=state[slot].height end
                    end
                    state[slot]=baseline
                end
                state.dirty=true
                update()
            end)
        end
    end
    state.enabled=true
    update()
end

function V:DisablePlayerProgress()
    if state then state.enabled=false;restore() end
end

for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_XP_UPDATE","PLAYER_LEVEL_UP","PLAYER_MAX_LEVEL_UPDATE",
    "UPDATE_EXPANSION_LEVEL","ENABLE_XP_GAIN","DISABLE_XP_GAIN","PLAYER_REGEN_ENABLED"}) do
    V:On(event,update)
end
V:On("UNIT_LEVEL",function(_,unit) if not V:IsSecret(unit) and unit=="player" then update() end end)
