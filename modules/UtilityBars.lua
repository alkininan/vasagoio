local _, V = ...
local T, A = V.Tokens, V.Tokens.action
local MODULE = "utilityBars"
-- Both releases retain the two named 36px slot widgets and layoutVersion 3.
local VERSIONS = {["1.8.19"]=true,["1.8.20"]=true}
local records, hooked = setmetatable({}, {__mode="k"}), setmetatable({}, {__mode="k"})
local applying, pending

local function reviewed()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = get and get("ForeverTrinketMenu", "Version")
    return not V:IsSecret(version) and type(version)=="string" and VERSIONS[version]==true
end
local function usable(frame)
    if V:IsSecret(frame) or not frame or not frame.SetPoint or not frame.GetNumPoints then return false end
    if frame.IsForbidden then
        local ok, value = pcall(frame.IsForbidden, frame)
        if not ok or V:IsSecret(value) or value then return false end
    end
    return true
end
local function widgets()
    local frame, first, second = _G.ForeverTrinketMenuFrame, _G.ForeverTrinketMenuSlot1, _G.ForeverTrinketMenuSlot2
    if not usable(frame) or not usable(first) or not usable(second) then return end
    if first:GetParent() ~= frame or second:GetParent() ~= frame then return end
    return frame, first, second
end
local function position()
    local scale = V:Pixel(A.size) / 36
    if scale <= 0 then return end
    local ox, oy = V:CanvasOrigin()
    return scale, {point="TOPLEFT", relativePoint="BOTTOMLEFT",
        x=(ox+V:Pixel(A.utilityX))/scale, y=(oy+V:Pixel(T.reference.height-A.y))/scale}
end
local function active()
    if not V.db or not V.db.overrides.utilityLayout or not V:IsModuleEnabled(MODULE)
        or V.profileReloadPending or pending or not reviewed() then return false end
    local db = _G.TrinketMenuDB
    local scale, anchor = position()
    if not scale or type(db) ~= "table" or type(db.windowPosition) ~= "table" then return false end
    if db.horizontal ~= false or db.locked ~= true or db.showSlot13 ~= true or db.showSlot14 ~= true
        or db.skin ~= "flat" or db.hideFrameBorder ~= true or db.gearBar ~= false
        or db.layoutVersion ~= 3 or V:SafeNumber(db.scale) ~= scale then return false end
    for key, value in pairs(anchor) do
        if V:IsSecret(db.windowPosition[key]) or db.windowPosition[key] ~= value then return false end
    end
    return true
end
local function capture(frame)
    local value = {points={}, width=V:SafeNumber(frame:GetWidth()), height=V:SafeNumber(frame:GetHeight())}
    local count = V:SafeNumber(frame:GetNumPoints())
    assert(count and count >= 0 and count <= 9 and value.width and value.height, "Trinket layout is unavailable")
    for i=1,count do
        local point, relative, relativePoint, x, y = frame:GetPoint(i)
        assert(not V:IsSecret(point) and not V:IsSecret(relative) and not V:IsSecret(relativePoint)
            and V:SafeNumber(x) and V:SafeNumber(y), "Trinket layout is restricted")
        value.points[i] = {point, relative, relativePoint, x, y}
    end
    return value
end
local function equal(a,b)
    if not a or not b or a.width~=b.width or a.height~=b.height or #a.points~=#b.points then return false end
    for i, point in ipairs(a.points) do
        for j=1,5 do if point[j]~=b.points[i][j] then return false end end
    end
    return true
end
local function write(frame, geometry)
    frame:SetSize(geometry.width, geometry.height)
    frame:ClearAllPoints()
    for _, p in ipairs(geometry.points) do frame:SetPoint(unpack(p)) end
end
local function restore()
    if InCombatLockdown() then return false end
    applying = true
    local recovered = true
    for frame, record in pairs(records) do
        local ok, current = pcall(capture, frame)
        local restored = ok
        if ok and equal(current, record.last) then
            restored = pcall(write, frame, record.before)
            if not restored then
                local captured, partial = pcall(capture, frame)
                if captured then record.last = partial end
            end
        end
        if V.ClearActionButtonStyle then
            local cleared = pcall(V.ClearActionButtonStyle,V,frame)
            restored = restored and cleared
        end
        if restored then records[frame] = nil else recovered = false end
    end
    applying = nil
    if not recovered and V.Report then V:Report(MODULE,"pending","Trinket geometry recovery was refused; reload before continuing.") end
    return recovered
end
local function request()
    if applying or not V.db or not V:IsModuleEnabled(MODULE) then return end
    V:Refresh("trinket owner layout", MODULE)
end
local function watch(frame)
    if hooked[frame] then return end
    hooked[frame] = true
    if hooksecurefunc then
        hooksecurefunc(frame, "SetSize", request)
        hooksecurefunc(frame, "SetPoint", request)
    end
    if frame.HookScript then frame:HookScript("OnShow", request) end
end

V:RegisterProfileAdapter("trinkets", {
    label="Forever Trinket Menu: aligned utility column", addon="ForeverTrinketMenu", module=MODULE,
    Prepare=function()
        if not reviewed() then return nil, "Reviewed Forever Trinket Menu 1.8.19 or 1.8.20 is required" end
        if InCombatLockdown() then return nil, "Leave combat before reviewing trinket placement" end
        if type(_G.TrinketMenuDB) ~= "table" or not widgets() then return nil, "Initialize Forever Trinket Menu and reload once" end
        local scale, anchor = position()
        if not scale then return nil, "Trinket scale is unavailable" end
        local changes = {}
        local function add(key, value, label)
            changes[#changes+1] = {table=TrinketMenuDB,path={"TrinketMenuDB"},key=key,value=value,label=label}
        end
        add("horizontal",false,"Vertical trinket buttons")
        add("scale",scale,"Trinket buttons match main actions")
        add("windowPosition",anchor,"Trinket column beside main rows")
        add("layoutVersion",3,"Reviewed owner anchor format")
        add("showSlot13",true,"First equipped trinket")
        add("showSlot14",true,"Second equipped trinket")
        add("locked",true,"Lock aligned trinkets")
        add("skin","flat","Flat trinket artwork")
        add("hideFrameBorder",true,"No trinket window outline")
        add("gearBar",false,"Keep the agreed two-trinket column")
        changes[#changes+1] = {table=V.db.overrides,path={"VasagoioDB","overrides"},key="utilityLayout",value=true,label="Enable utility column geometry"}
        return {changes=changes,detail="Two 42px trinkets with 8px gap beside the top and middle main rows. Bartender owns the bag button below. Native flyouts, swaps and queue behavior remain intact."}
    end,
    AfterApply=function() pending=true end,
    AfterRestore=function() pending=true; assert(restore(),"Reload to finish trinket geometry restoration") end,
})

V:RegisterModule(MODULE, {
    label="Trinket column", defaultEnabled=true,
    description="Aligns native equipped trinkets without changing their actions or queue logic.",
    Apply=function()
        if InCombatLockdown() then return false,"Trinket layout waits until combat ends" end
        if pending then return false,"Reload to activate reviewed trinket placement","pending" end
        if not active() then
            if not restore() then return false,"Reload to finish trinket geometry restoration","pending" end
            return false,"Apply the reviewed trinket preset or restore its settings","pending"
        end
        local frame, first, second = widgets()
        if not frame then return false,"Native trinket buttons are not available" end
        local scale = V:SafeNumber(frame:GetScale())
        local expected, anchor = position()
        if not scale or math.abs(scale-expected)>.00001 then return false,"Reload the trinket owner to apply its scale","pending" end
        local gap = V:Pixel(A.gap)/scale
        local targets = {
            {frame=frame, value={width=36,height=72+gap,points={{"TOPLEFT",UIParent,"BOTTOMLEFT",anchor.x,anchor.y}}}},
            {frame=first, value={width=36,height=36,points={{"TOPLEFT",frame,"TOPLEFT",0,0}}}},
            {frame=second,value={width=36,height=36,points={{"TOPLEFT",frame,"TOPLEFT",0,-36-gap}}}},
        }
        -- Capture everything before mutation, and roll back a partially refused layout.
        for _, target in ipairs(targets) do target.before = capture(target.frame) end
        applying = true
        local touched=0
        local ok, reason = pcall(function()
            for i, target in ipairs(targets) do
                touched=i
                if not equal(target.before,target.value) then write(target.frame,target.value) end
            end
        end)
        if not ok then
            for i=touched,1,-1 do
                local target=targets[i]
                local restored=pcall(write,target.frame,target.before)
                if not restored then
                    local record=records[target.frame] or {before=target.before}
                    records[target.frame]=record
                    local captured, partial=pcall(capture,target.frame)
                    record.last=captured and partial or target.value
                end
            end
            applying=nil
            error(reason)
        end
        local complete = V.StyleActionButton ~= nil
        local styled, styleReason = pcall(function()
        for _, target in ipairs(targets) do
            local record=records[target.frame] or {before=target.before}
            records[target.frame]=record; record.last=target.value
        end
        for _, target in ipairs(targets) do watch(target.frame) end
        if V.StyleActionButton then
            for _, button in ipairs({first,second}) do
                local applied=V:StyleActionButton(button,{owner=MODULE,icon=button.icon,cooldown=button.cooldown,
                    timer=button.timeText,hotkey=button.hotkey,compact=false})
                if not applied then complete=false end
                if button.flatBorder then V:HideArtwork(button.flatBorder) end
                if button.rankText then V:StyleText(button.rankText,"count",T.colors.attention) end
            end
        end
        end)
        applying=nil
        if not styled then restore(); error(styleReason) end
        if not complete then return false,"Trinkets aligned; native button styling was refused. Reload and inspect the utility column.","pending" end
        return true,"Native trinket column aligned with the main grid; gameplay validation remains pending."
    end,
    Disable=function() assert(restore(),"Reload to finish trinket geometry restoration") end,
})
