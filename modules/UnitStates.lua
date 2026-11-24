local _, V = ...

-- Plain decorations only. FUF retains secure buttons, native flag/FFA logic,
-- raid threat-value sinks, unit visibility and all cast/interrupt behavior.
local states = setmetatable({}, {__mode="k"})
local fighting = false
local happiness,happinessApplies
local function configured(s)
    if not s.active or V.profileReloadPending or not V:IsModuleEnabled("unitframes") then return false end
    local profile, name = V:GetReviewedUnitProfile()
    return profile == s.profile and name == s.profileName
end
local function unitOf(frame)
    local unit = frame.unit
    if not V:IsSecret(unit) and type(unit) == "string" then return unit end
end
local function callValues(object, method)
    if not object or type(object[method]) ~= "function" then return end
    local ok, a,b,c,d = pcall(object[method],object)
    if ok then return {a,b,c,d} end
end
local function ownPet(s)
    return (s.frame.key == "pet" or s.frame.key == "partypet") and unitOf(s.frame) == "pet"
end
local function readHappiness()
    if not C_PetInfo or type(C_PetInfo.GetPetHappiness) ~= "function" or type(HasPetUI) ~= "function" then return end
    local ok, _, hunter = pcall(HasPetUI)
    if not ok or V:IsSecret(hunter) then return end
    if hunter ~= true then return nil,false end
    if UnitClass then
        local known, _, class = pcall(UnitClass,"player")
        if known and not V:IsSecret(class) and class and class ~= "HUNTER" then return nil,false end
    end
    local got, value = pcall(C_PetInfo.GetPetHappiness)
    value = got and V:SafeNumber(value)
    if value == 1 or value == 2 or value == 3 then return value,true end
    return nil,true
end
local function wantedColor(s, text)
    if text.role == "amount" then return V.Tokens.colors.text end
    if text.role == "petName" and ownPet(s) and happinessApplies~=false then
        local c = V.Tokens.colors
        return happiness == 3 and c.petHappy or happiness == 2 and c.petContent or happiness == 1 and c.petUnhappy or c.muted
    end
end
local function restore(s)
    if not s.active then return end
    s.active = false
    s.busy = true
    if s.edge then s.edge:Hide() end
    for fs, text in pairs(s.texts) do
        if text.color and fs.SetTextColor then fs:SetTextColor(unpack(text.color)) end
        if text.font and fs.SetFont then fs:SetFont(unpack(text.font)) end
        if text.shadow and fs.SetShadowColor then fs:SetShadowColor(unpack(text.shadow)) end
        if text.offset and fs.SetShadowOffset then fs:SetShadowOffset(unpack(text.offset)) end
    end
    for bar, color in pairs(s.raidColors) do bar:SetStatusBarColor(unpack(color)) end
    s.busy = false
end
local function paintText(s, fs, text)
    if s.busy or not s.active then return end
    if not configured(s) then restore(s);return end
    local c = wantedColor(s,text)
    s.busy = true
    if c then fs:SetTextColor(c[1],c[2],c[3],c[4] or 1)
    elseif text.color then fs:SetTextColor(unpack(text.color)) end
    if text.fontRole and fs.SetFont then
        fs:SetFont(V:Font(text.fontRole))
        if fs.SetShadowColor then fs:SetShadowColor(0,0,0,.9) end
        if fs.SetShadowOffset then fs:SetShadowOffset(V:Pixel(1),-V:Pixel(1)) end
    end
    s.busy = false
end
local function text(s, fs, role, fontRole)
    if not fs or not fs.SetTextColor then return end
    local entry = s.texts[fs]
    if not entry then
        entry = {color=callValues(fs,"GetTextColor"),role=role,fontRole=fontRole}
        if fontRole then
            entry.font,entry.shadow,entry.offset = callValues(fs,"GetFont"),callValues(fs,"GetShadowColor"),callValues(fs,"GetShadowOffset")
        end
        s.texts[fs] = entry
        hooksecurefunc(fs,"SetTextColor",function(_,r,g,b,a)
            if s.busy then return end
            if type(a)=="nil" then a=1 end
            entry.color = {r,g,b,a}
            paintText(s,fs,entry)
        end)
        if fontRole and fs.SetFont then
            hooksecurefunc(fs,"SetFont",function(_,path,size,flags)
                if s.busy then return end
                entry.font = {path,size,flags or ""}
                paintText(s,fs,entry)
            end)
            if fs.SetShadowColor then
                hooksecurefunc(fs,"SetShadowColor",function(_,r,g,b,a)
                    if s.busy then return end
                    if type(a)=="nil" then a=1 end
                    entry.shadow={r,g,b,a};paintText(s,fs,entry)
                end)
            end
            if fs.SetShadowOffset then
                hooksecurefunc(fs,"SetShadowOffset",function(_,x,y)
                    if s.busy then return end
                    entry.offset={x,y};paintText(s,fs,entry)
                end)
            end
        end
    end
    paintText(s,fs,entry)
end
local function paintRaid(s, bar)
    if s.busy or not s.active then return end
    if not configured(s) then restore(s);return end
    s.busy = true
    local c = V.Tokens.colors.danger
    bar:SetStatusBarColor(c[1],c[2],c[3],V.Tokens.unitState.opacity)
    s.busy = false
end
local function raidEdges(s)
    local native = s.frame.raidStates and s.frame.raidStates.aggro
    if not native or not native.bars then return end
    for _,bar in ipairs(native.bars) do
        if not s.raidColors[bar] then
            local color = callValues(bar,"GetStatusBarColor")
            if color then
                s.raidColors[bar] = color
                hooksecurefunc(bar,"SetStatusBarColor",function(_,r,g,b,a)
                    if s.busy then return end
                    if type(a)=="nil" then a=1 end
                    s.raidColors[bar] = {r,g,b,a}
                    paintRaid(s,bar)
                end)
            end
        end
        if s.raidColors[bar] then paintRaid(s,bar) end
    end
end
local function makeEdge(s, aggro)
    local holder = CreateFrame("Frame",nil,s.frame)
    holder.__vasagoio,holder.ignoreInLayout = true,true
    holder:SetAllPoints(s.frame)
    holder:EnableMouse(false)
    local level = s.frame.GetFrameLevel and V:SafeNumber(s.frame:GetFrameLevel()) or 0
    holder:SetFrameLevel((level or 0)+11)
    holder.parts = {}
    local c, opacity = V.Tokens.colors.danger,V.Tokens.unitState.opacity
    for i=1,4 do
        local edge
        if aggro then
            edge = CreateFrame("StatusBar",nil,holder)
            edge:EnableMouse(false)
            edge:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
            edge:SetStatusBarColor(c[1],c[2],c[3],opacity)
            edge:SetMinMaxValues(1,2)
            edge:SetValue(0)
        else
            edge = holder:CreateTexture(nil,"OVERLAY")
            edge:SetColorTexture(c[1],c[2],c[3],opacity)
        end
        holder.parts[i] = edge
    end
    s.edge,s.aggro = holder,aggro
    holder:Hide()
end
local function layoutEdge(s)
    if not s.edge then return end
    local thick = V:Pixel(V.Tokens.unitState.edgeWidth)
    if s.edgeWidth == thick then return end
    local top,bottom,left,right = unpack(s.edge.parts)
    for _,edge in ipairs(s.edge.parts) do edge:ClearAllPoints() end
    top:SetPoint("TOPLEFT",s.edge,"TOPLEFT",0,0);top:SetPoint("TOPRIGHT",s.edge,"TOPRIGHT",0,0);top:SetHeight(thick)
    bottom:SetPoint("BOTTOMLEFT",s.edge,"BOTTOMLEFT",0,0);bottom:SetPoint("BOTTOMRIGHT",s.edge,"BOTTOMRIGHT",0,0);bottom:SetHeight(thick)
    left:SetPoint("TOPLEFT",s.edge,"TOPLEFT",0,-thick);left:SetPoint("BOTTOMLEFT",s.edge,"BOTTOMLEFT",0,thick);left:SetWidth(thick)
    right:SetPoint("TOPRIGHT",s.edge,"TOPRIGHT",0,-thick);right:SetPoint("BOTTOMRIGHT",s.edge,"BOTTOMRIGHT",0,thick);right:SetWidth(thick)
    s.edgeWidth = thick
end
local function updateEdge(s)
    if not configured(s) then restore(s);return end
    if not s.edge then return end
    if not s.aggro then s.edge:SetShown(fighting);return end
    local unit = unitOf(s.frame)
    local value = 0
    if unit and UnitThreatSituation then
        local ok, result = pcall(UnitThreatSituation,unit)
        if ok and (V:IsSecret(result) or type(result)=="number") then value=result end
    end
    -- Status values 2/3 fill the native edges, 0/1 leave them empty. Never
    -- compare, format or calculate with a restricted threat value.
    for _,bar in ipairs(s.edge.parts) do bar:SetValue(value) end
    s.edge:SetShown(unit~=nil)
end

function V:StyleUnitStates(frame)
    if not frame or not hooksecurefunc or InCombatLockdown() then return end
    local profile,name = self:GetReviewedUnitProfile()
    if not profile or self.profileReloadPending or not self:IsModuleEnabled("unitframes") then return end
    local s = states[frame]
    if not s then
        s={frame=frame,texts={},raidColors={}}
        states[frame]=s
    elseif s.profile~=profile or s.profileName~=name then restore(s) end
    s.profile,s.profileName,s.active=profile,name,true
    local t=frame.texts or {}
    local small=frame.key=="partypet" and "compact" or nil
    text(s,t.healthRight,"amount",small)
    text(s,t.powerRight,"amount")
    if frame.key=="pet" or frame.key=="partypet" then
        happiness,happinessApplies=readHappiness()
        text(s,t.healthLeft,"petName",small)
    end
    if frame.castbar then
        text(s,frame.castbar.text,"amount")
        text(s,frame.castbar.time,"amount")
    end
    if frame.key=="raid" or frame.key=="raidpet" then raidEdges(s)
    elseif frame.key=="player" or frame.key=="party" then
        if not s.edge then makeEdge(s,frame.key=="party") end
        layoutEdge(s)
        updateEdge(s)
    end
end
function V:DisableUnitStates()
    for _,s in pairs(states) do restore(s) end
end
local function updateAllEdges(_,unit)
    local known=not V:IsSecret(unit) and type(unit)=="string" and unit or nil
    for _,s in pairs(states) do
        if s.active and (not known or unitOf(s.frame)==known) then updateEdge(s) end
    end
end
local function updateNames()
    happiness,happinessApplies=readHappiness()
    for _,s in pairs(states) do
        if s.active then
            if not configured(s) then restore(s)
            else
                for fs,entry in pairs(s.texts) do
                    if entry.role=="petName" then paintText(s,fs,entry) end
                end
            end
        end
    end
end
V:On("PLAYER_REGEN_DISABLED",function() fighting=true;updateAllEdges() end)
V:On("PLAYER_REGEN_ENABLED",function() fighting=false;updateAllEdges() end)
V:On("PLAYER_ENTERING_WORLD",function()
    -- FUF unit geometry is only installed out of combat. On a combat reload
    -- the next normal module application waits for regen enabled.
    fighting=InCombatLockdown()==true
    updateNames();updateAllEdges()
end)
V:On("UNIT_THREAT_SITUATION_UPDATE",updateAllEdges)
for _,event in ipairs({"UNIT_HAPPINESS","UNIT_PET","PET_UI_UPDATE"}) do V:On(event,updateNames) end
V:On("GROUP_ROSTER_UPDATE",function()updateNames();updateAllEdges()end)
