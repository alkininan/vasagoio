local addonName, V = ...

-- Threat Plates is the sole nameplate owner. The profile supplies geometry
-- and colors; the owner's restriction-aware widgets supply health and threat.
local OWNER, VERSION = "TidyPlates_ThreatPlates", "13.3.9"
local T = V.Tokens
local function flatMediaReady()
    local media=LibStub and LibStub("LibSharedMedia-3.0",true)
    if not media or type(media.Register)~="function" or type(media.Fetch)~="function" then return false end
    local texture="Interface\\Buttons\\WHITE8X8"
    local ok,value=pcall(function()
        media:Register("statusbar","Vasagoio Flat",texture)
        return media:Fetch("statusbar","Vasagoio Flat",true)
    end)
    return ok and not V:IsSecret(value) and value==texture
end
-- Threat Plates listens for shared-media registration and rebuilds its theme.
flatMediaReady()
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function color(hex)
    if type(hex) == "table" then return { r = hex[1], g = hex[2], b = hex[3], a = hex[4] or 1 } end
    return { r = tonumber(hex:sub(1, 2), 16) / 255, g = tonumber(hex:sub(3, 4), 16) / 255,
        b = tonumber(hex:sub(5, 6), 16) / 255, a = 1 }
end
local function ensure(t, key) t[key] = t[key] or {}; return t[key] end
local function px(n) return V:Pixel(n) end
local function versionOK()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    return get and get(OWNER, "Version") == VERSION
end
local function plain(value) return not V:IsSecret(value) and type(value) == "string" end
local function currentProfile()
    local db = ThreatPlatesDB
    if type(db) ~= "table" or type(db.profileKeys) ~= "table" or type(db.profiles) ~= "table" then return end
    if not UnitNameUnmodified then return end
    local name, surname = UnitNameUnmodified("player")
    if not plain(name) or V:IsSecret(surname) then return end
    local regional = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
    if V:IsSecret(regional) then return end
    local key
    -- These are the two AceDB 3.0 identity schemes shipped with this exact
    -- Forever build. No identity is recorded in diagnostics or the package.
    if regional then
        if surname and not plain(surname) then return end
        key = surname and name .. " " .. surname or name
    else
        local realm = GetRealmName and GetRealmName()
        if not plain(realm) then return end
        key = name .. " - " .. realm
    end
    local profile = db.profileKeys[key]
    if not plain(profile) or type(db.profiles[profile]) ~= "table" then return end
    return db.profiles[profile], profile, key
end
local function font(t, size, width)
    t.Typeface, t.Size, t.flags, t.Shadow = "Friz Quadrata TT", px(size), "", true
    if width then t.Width = px(width) end
end
local function configure(profile)
    local settings = ensure(profile, "settings")
    local health = ensure(settings, "healthbar")
    health.width, health.widthFriend = px(T.nameplate.width), px(T.nameplate.width)
    health.height, health.heightFriend = px(T.nameplate.health), px(T.nameplate.health)
    local media = LibStub and LibStub("LibSharedMedia-3.0", true)
    -- "Flat" is not shipped by every dependency. Register an explicit native
    -- white texture so the design never silently falls back to a glossy bar.
    health.texture, health.backdrop = "Vasagoio Flat", "Vasagoio Flat"
    for _, key in ipairs({"healthborder","elitehealthborder","threatborder","castborder"}) do ensure(settings,key).show=false end
    local background = ensure(profile,"Healthbar")
    background.FriendlyUnitMode, background.EnemyUnitMode = "REACTION", "REACTION"
    -- Threat Plates stores transparency under the misleading Opacity name.
    background.BackgroundUseForegroundColor, background.BackgroundOpacity = false, 0
    background.BackgroundColor, background.UseRaidMarkColoring = color(T.colors.panel), false
    -- Reaction is the owner's fallback when an NPC has no threat table. Leaving
    -- its stock HostileNPC color red made an idle, safe DPS target look like an
    -- aggro warning even though the combat-threat colors were configured.
    local reaction=ensure(profile,"ColorByReaction")
    for key,value in pairs({FriendlyPlayer=T.colors.informationFill,FriendlyNPC=T.colors.informationFill,
        FriendlyPlayerPvPOn=T.colors.informationFill,HostileNPC=T.colors.informationFill,
        HostilePlayer=T.colors.dangerFill,NeutralUnit=T.colors.attentionFill,
        HostilePlayerPvPOnSelfPvPOff=T.colors.attentionFill,UnfriendlyFaction=T.colors.attentionFill,
        TappedUnit=T.colors.healthLow,DisconnectedUnit=T.colors.healthLow}) do reaction[key]=color(value) end
    local cast = ensure(settings,"castbar")
    cast.width, cast.height, cast.x, cast.y, cast.show = px(T.nameplate.width), px(T.nameplate.cast), 0,
        -px(T.nameplate.health/2 + T.nameplate.castGap + T.nameplate.cast/2), true
    cast.texture, cast.backdrop = health.texture, health.backdrop
    cast.BackgroundUseForegroundColor, cast.BackgroundOpacity, cast.BackgroundColor = false, 0, color(T.colors.panel)
    cast.ShowSpark, cast.ShowCastTime = false, true
    local spellAnchor, timeAnchor = ensure(cast,"SpellNameText"), ensure(cast,"CastTimeText")
    spellAnchor.HorizontalOffset, spellAnchor.VerticalOffset = -px(24), 0
    timeAnchor.HorizontalOffset, timeAnchor.VerticalOffset = -px(8), 0
    local timeFont=ensure(timeAnchor,"Font")
    timeFont.HorizontalAlignment,timeFont.VerticalAlignment="RIGHT","MIDDLE"
    -- The native cast target remains available, with explicit neutral styling;
    -- it is an owner-selected extra line outside the baseline 84px envelope.
    local castTarget=ensure(cast,"CastTarget")
    font(ensure(castTarget,"Font"),T.typography.compact.size,T.nameplate.width)
    castTarget.Font.Color=color(T.colors.muted)
    local interrupt=ensure(settings,"castnostop")
    interrupt.ShowOverlay,interrupt.ShowInterruptShield=true,true
    profile.castbarColor,profile.castbarColorShield,profile.castbarColorInterrupted=
        color(T.colors.informationFill),color(T.colors.attentionFill),color(T.colors.dangerFill)
    local spell=ensure(settings,"spelltext")
    spell.typeface,spell.size,spell.flags,spell.shadow="Friz Quadrata TT",px(T.typography.compact.size),"",true
    spell.width,spell.height,spell.align,spell.vertical,spell.show=px(128),px(T.nameplate.cast),"LEFT","MIDDLE",true
    -- Move native status icons out of the two text lanes; never remove markers.
    local level=ensure(settings,"level")
    level.typeface,level.size,level.flags,level.shadow="Friz Quadrata TT",px(T.typography.compact.size),"",true
    -- Leave two pixels from the selected outline, rather than overlapping it.
    local side=T.nameplate.width/2+T.nameplate.selectionOutset+T.nameplate.indicatorGap
    level.x,level.y,level.width,level.height=-px(side+T.nameplate.levelWidth/2),0,px(T.nameplate.levelWidth),px(16)
    level.align,level.vertical,level.show="RIGHT","MIDDLE",true
    for key,xy in pairs({raidicon={-side-T.nameplate.levelWidth-8-T.nameplate.indicatorSize/2,0},
        eliteicon={side+T.nameplate.indicatorSize/2,0},skullicon={-side-T.nameplate.indicatorSize/2,0},
        spellicon={-T.nameplate.width/2-8-T.nameplate.indicatorSize/2,-28}}) do
        local icon=ensure(settings,key);icon.x,icon.y,icon.scale=px(xy[1]),px(xy[2]),px(T.nameplate.indicatorSize)
        icon.show=true
    end
    local classes=ensure(ensure(profile,"Colors"),"Classes")
    for class,hex in pairs(T.class) do
        local c=color(hex); classes[class]=c
        c.colorStr=string.format("ff%02x%02x%02x",math.floor(c.r*255+.5),math.floor(c.g*255+.5),math.floor(c.b*255+.5))
    end
    local threatColors={dps={LOW=T.colors.informationFill,MEDIUM=T.colors.attentionFill,HIGH=T.colors.dangerFill},
        tank={LOW=T.colors.dangerFill,MEDIUM=T.colors.attentionFill,HIGH=T.colors.informationFill,OFFTANK=T.colors.dangerFill}}
    for role,values in pairs(threatColors) do
        local entries=ensure(ensure(settings,role),"threatcolor")
        for level,value in pairs(values) do entries[level]=color(value) end
    end
    local threat=ensure(profile,"threat")
    threat.UseThreatTable,threat.UseHeuristicInInstances,threat.useType=true,false,true
    threat.useHPColor,threat.useScale,threat.useAlpha=true,false,false
    ensure(threat,"art").ON=false
    local toggle=ensure(threat,"toggle");toggle.OffTank,toggle.InstancesOnly=false,false
    for _,kind in ipairs({"Boss","Elite","Normal","Neutral","Minus","Tapped"}) do toggle[kind]=true end
    if profile.optionRoleDetectionAutomatic==nil then profile.optionRoleDetectionAutomatic=true end
    local text=ensure(profile,"text")
    text.amount,text.full,text.percent,text.max,text.deficit,text.truncate=true,true,false,false,false,false
    text.AbsorbsAmount,text.AbsorbsPercentage=false,false
    local status=ensure(ensure(profile,"StatusText"),"HealthbarMode")
    status.FriendlySubtext,status.EnemySubtext="HEALTH","HEALTH"
    status.Anchor,status.InsideAnchor,status.HorizontalOffset,status.VerticalOffset="RIGHT",true,-px(8),0
    status.SubtextColorUseSpecific,status.SubtextColorUseHeadline,status.SubtextColor=false,false,color(T.colors.text)
    font(ensure(status,"Font"),T.nameplate.amountSize,80)
    status.Font.HorizontalAlignment,status.Font.VerticalAlignment,status.Font.Height="RIGHT","MIDDLE",px(20)
    local title=ensure(ensure(profile,"Name"),"HealthbarMode")
    title.Enabled,title.Anchor,title.InsideAnchor=true,"LEFT",true
    title.HorizontalOffset,title.VerticalOffset=px(8),0
    title.FriendlyUnitMode,title.EnemyUnitMode="CUSTOM","CUSTOM"
    title.FriendlyTextColor,title.EnemyTextColor=color(T.colors.text),color(T.colors.text)
    title.UseRaidMarkColoring=false
    font(ensure(title,"Font"),T.typography.name.size,T.nameplate.width-104)
    title.Font.Height,title.Font.HorizontalAlignment,title.Font.VerticalAlignment=px(T.nameplate.health),"LEFT","MIDDLE"
    -- Threat Plates' squarethin theme supplies its native 1px outline. Keep
    -- selection separate from the native role-aware health/threat fill.
    for _,key in ipairs({"targetWidget","FocusWidget"}) do
        local widget=ensure(profile,key);widget.ModeNames,widget.ModeHPBar=false,false
    end
    local selection=ensure(profile,"targetWidget")
    selection.ON,selection.theme=true,"squarethin"
    selection.r,selection.g,selection.b,selection.a=T.colors.information[1],T.colors.information[2],T.colors.information[3],.85
    local aura=ensure(profile,"AuraWidget")
    aura.ShowCooldownSpiral,aura.ShowDuration,aura.ShowStackCount=true,true,true
    aura.ShowOmniCC,aura.FlashWhenExpiring,aura.SwitchAreaByReaction=false,false,false
    for _,group in ipairs({"Buffs","Debuffs","CrowdControl"}) do
        local cfg=ensure(aura,group);local icons=ensure(cfg,"ModeIcon")
        icons.Style,icons.IconWidth,icons.IconHeight,icons.ShowBorder="square",px(T.nameplate.aura),px(T.nameplate.aura),false
        icons.ColumnSpacing,icons.RowSpacing=px(T.aura.gap),px(T.aura.wrapGap)
        local duration,count=ensure(icons,"Duration"),ensure(icons,"StackCount")
        duration.Anchor,duration.InsideAnchor,duration.HorizontalOffset,duration.VerticalOffset="BOTTOM",true,0,px(2)
        count.Anchor,count.InsideAnchor,count.HorizontalOffset,count.VerticalOffset="TOPRIGHT",true,0,px(8)
        font(ensure(duration,"Font"),T.typography.aura.size)
        font(ensure(count,"Font"),T.typography.count.size)
        count.Font.Typeface=(media and media:Fetch("font","Arial Narrow Bold",true)) and "Arial Narrow Bold" or "Arial Narrow"
        for _,slot in ipairs({duration,count}) do
            slot.Font.Color,slot.Font.Transparency=color(T.colors.iconText),1
            slot.Font.HorizontalAlignment,slot.Font.VerticalAlignment="CENTER","MIDDLE"
        end
        count.Font.HorizontalAlignment="RIGHT"
        cfg.AlignmentH,cfg.AlignmentV,cfg.CenterAuras="LEFT","BOTTOM",true
    end
    -- Explicitly separate the owner's three groups; none inherits old offsets.
    for group,position in pairs({Debuffs={"Healthbar","TOP",0,T.nameplate.auraGap},
        Buffs={"Debuffs","TOP",0,T.aura.wrapGap},CrowdControl={"Healthbar","RIGHT",48,0}}) do
        local cfg=aura[group];cfg.AnchorTo=position[1]
        local anchor=ensure(cfg,"HealthbarMode")
        anchor.Anchor,anchor.InsideAnchor,anchor.HorizontalOffset,anchor.VerticalOffset=position[2],false,px(position[3]),px(position[4])
    end
    local scale=ensure(profile,"Scale");scale.IgnoreUIScale,scale.PixelPerfectUI=false,false
    local appearance=ensure(profile,"Appearance");appearance.NameplateSize,appearance.UseBorderlessIcons="BIG",true
    local np=ensure(profile,"nameplate");local toggles=ensure(np,"toggle")
    for _,key in ipairs({"TargetS","NonTargetS","NoTargetS","MarkedS","CastingUnitScale","CastingEnemyUnitScale","MouseoverUnitScale",
        "TargetA","NonTargetA","NoTargetA","MarkedA","CastingUnitAlpha","CastingEnemyUnitAlpha","MouseoverUnitAlpha","OccludedUnits"}) do toggles[key]=false end
    for _,key in ipairs({"FriendlyPlayer","FriendlyNPC","Neutral","EnemyPlayer","EnemyNPC","Elite","Boss","Guardian","Pet","Totem","Minus","Tapped"}) do
        ensure(np,"scale")[key],ensure(np,"alpha")[key]=1,1
    end
end

local reloadPending
V:RegisterProfileAdapter("nameplates", {
    label = "Threat Plates — vasagoio nameplates", addon = OWNER,
    AfterApply = function() reloadPending = true end,
    Prepare = function()
        if not versionOK() then return nil, "Requires audited Threat Plates 13.3.9; newer schemas need review." end
        if not flatMediaReady() then return nil,"Nameplate flat texture is unavailable in shared media; reload before setup." end
        local target, oldName, char = currentProfile()
        if not target then return nil, "Threat Plates profile is not initialized; enable it and reload before setup." end
        local profile = copy(target)
        configure(profile)
        local index, name = 1, "vasagoio"
        while ThreatPlatesDB.profiles[name] ~= nil do index = index + 1; name = "vasagoio " .. index end
        -- Keep AceDB's live profile and default metatables intact. Its audited
        -- logout handler strips defaults but does not reset profileKeys.
        local changes = {
            { table = ThreatPlatesDB.profiles, path = { "ThreatPlatesDB", "profiles" }, key = name,
                value = profile, label = "Create a separate vasagoio nameplate profile" },
            { table = ThreatPlatesDB.profileKeys, path = { "ThreatPlatesDB", "profileKeys" }, key = char,
                value = name, label = "Select vasagoio nameplates after reload" },
        }
        -- Preserve dual-spec switching. Any slots that shared the old profile
        -- now share its themed copy; independently chosen profiles stay intact.
        local namespace = ThreatPlatesDB.namespaces and ThreatPlatesDB.namespaces["LibDualSpec-1.0"]
        local specChar = namespace and namespace.char and namespace.char[char]
        if specChar and specChar.enabled then
            for spec, assigned in pairs(specChar) do
                if type(spec) == "number" and assigned == oldName then
                    changes[#changes + 1] = { table = specChar,
                        path = { "ThreatPlatesDB", "namespaces", "LibDualSpec-1.0", "char", char },
                        key = spec, value = name, label = "Preserve shared specialization profile " .. spec }
                end
            end
        end
        return { changes = changes, detail = "224×24 flat health, 1px blue target outline, level left / rare-elite icon right, exact HP, 16px cast with 8px gap and native role-aware blue/amber/red. Reload required; custom nameplate overrides remain owner-controlled." }
    end,
})
local active, selectedName, selectedKey, selectedProfile, cleanupPending
local deactivate
local decorated=setmetatable({}, {__mode="k"})
local auraDecorated=setmetatable({}, {__mode="k"})
local pending={}
local auraLimited, presentationLimited
local function limitedAuras()
    if auraLimited then return end
    auraLimited=true
    if V.Report then V:Report("nameplateAuras","pending","The client refused an aura presentation update; native icons/timers remain owned by Threat Plates. Bottom-marker appearance needs an unrestricted refresh.") end
end
local function running()
    if not active then return false end
    local key=ThreatPlatesDB and ThreatPlatesDB.profileKeys and ThreatPlatesDB.profileKeys[selectedKey]
    local profile=ThreatPlatesDB and ThreatPlatesDB.profiles and ThreatPlatesDB.profiles[selectedName]
    local enabled=V.db and V.db.enabled~=false and not V.readOnly and not V.profileReloadPending and not reloadPending
        and not (V.db.modules and V.db.modules.nameplates==false)
    if not enabled or V:IsSecret(key) or key~=selectedName or profile~=selectedProfile then
        deactivate()
        return false
    end
    return true
end
local function available(object)
    if V:IsSecret(object) or (type(object)~="table" and type(object)~="userdata") then return false end
    if object.IsForbidden then
        local ok,forbidden=pcall(object.IsForbidden,object)
        if not ok or V:IsSecret(forbidden) or forbidden then return false end
    end
    return true
end
local function applyName(frame,state)
    if not running() or state.painting or not available(frame) or not available(frame.visual.NameText) then return end
    local unit=frame.unit
    if not available(unit) then return end
    local c=T.colors.text
    if not V:IsSecret(unit.type) and unit.type=="PLAYER" then
        local class=unit.class
        if not V:IsSecret(class) and type(class)=="string" then
            c=T.class[class] or c
        elseif C_ClassColor and C_ClassColor.GetClassColor then
            -- Native class-color rendering accepts a restricted token directly.
            -- Do not inspect/index/compare the returned color channels.
            state.painting=true
            pcall(function()
                local native=C_ClassColor.GetClassColor(class)
                frame.visual.NameText:SetTextColor(native:GetRGBA())
            end)
            state.painting=false
            return
        end
    end
    state.painting=true
    frame.visual.NameText:SetTextColor(c[1],c[2],c[3],1)
    state.painting=false
end
local auraGroups={
    Buffs={"main","canapply","bigdefensive","dispellable","magic","boss","dispeltype"},
    Debuffs={"main","important","importantpersonal","boss","priority","dispellable","dispeltype","canapply","bigdefensive"},
    CrowdControl={"main"},
}
local function captureMarker(mark)
    if not available(mark) or not mark.GetTexture or not mark.GetNumPoints or not mark.GetPoint
        or not mark.GetScale or not mark.GetVertexColor or not mark.IsShown
        or not mark.GetTextureSliceMargins or not mark.SetTextureSliceMargins then return end
    local ok,record=pcall(function()
        local result={texture=mark:GetTexture(),scale=mark:GetScale(),shown=mark:IsShown(),color={mark:GetVertexColor()},points={},slices={mark:GetTextureSliceMargins()}}
        if V:IsSecret(result.texture) or not V:SafeNumber(result.scale) or V:IsSecret(result.shown) then return end
        for _,channel in ipairs(result.color) do if not V:SafeNumber(channel) then return end end
        if #result.slices~=4 then return end
        for _,margin in ipairs(result.slices) do if not V:SafeNumber(margin) then return end end
        local n=V:SafeNumber(mark:GetNumPoints());if not n or n>8 then return end
        for i=1,n do
            local point={mark:GetPoint(i)}
            for _,value in ipairs(point) do if V:IsSecret(value) then return end end
            result.points[i]=point
        end
        return result
    end)
    return ok and record or nil
end
local function restoreMarker(record)
    local mark,old=record.marker,record.original
    return pcall(function()
        mark:SetTexture(old.texture);mark:SetTextureSliceMargins(unpack(old.slices));mark:SetScale(old.scale);mark:ClearAllPoints()
        for _,point in ipairs(old.points) do mark:SetPoint(unpack(point)) end
        mark:SetVertexColor(unpack(old.color))
        if old.shown then mark:Show() else mark:Hide() end
    end)
end
local function decorateAuras(frame)
    if not running() or (InCombatLockdown and InCombatLockdown()) then return end
    if not available(frame) or V:IsSecret(frame.PlateStyle) or frame.PlateStyle~="HealthbarMode" then return end
    local widget=frame.widgets and frame.widgets.Auras
    if not available(widget) then return end
    for kind,groups in pairs(auraGroups) do
        local container=widget[kind.."AuraContainer"]
        if available(container) and container.GetAuraGroupFrameCount and container.GetAuraGroupFrame then
            for _,key in ipairs(groups) do
                local ok,n=pcall(container.GetAuraGroupFrameCount,container,key)
                n=ok and V:SafeNumber(n)
                if not n then limitedAuras() end
                if n then for index=1,math.min(n,40) do
                    local found,button=pcall(container.GetAuraGroupFrame,container,key,index)
                    if not found or not available(button) then limitedAuras() end
                    local prior=found and available(button) and auraDecorated[button]
                    if found and available(button) and (not prior or prior.kind~=kind or prior.key~=key) then
                        local signal=(key=="dispellable" or key=="dispeltype") and T.colors.information
                            or (key=="priority" or key=="important") and T.colors.attention
                            or kind~="Buffs" and T.colors.danger or nil
                        local success=pcall(function()
                            -- The owner creates this texture in its native initializer.
                            -- Reuse it; never create/rebind a restricted aura region.
                            local mark=button.DispelBorder
                            if available(mark) then
                                local original=prior and prior.original or captureMarker(mark)
                                if not original then error("Native aura marker cannot be restored") end
                                auraDecorated[button]={kind=kind,key=key,marker=mark,original=original}
                                if signal then
                                    mark:SetTexture("Interface\\Buttons\\WHITE8X8")
                                    mark:SetTextureSliceMargins(0,0,0,0)
                                    mark:SetScale(1);mark:ClearAllPoints()
                                    mark:SetPoint("TOPLEFT",button,"BOTTOMLEFT",px(T.action.signalInset),-px(T.action.signalGap))
                                    mark:SetPoint("TOPRIGHT",button,"BOTTOMRIGHT",-px(T.action.signalInset),-px(T.action.signalGap))
                                    mark:SetHeight(px(T.action.signalHeight))
                                    mark:SetVertexColor(signal[1],signal[2],signal[3],1);mark:Show()
                                else mark:Hide() end
                            end
                            -- Retain the owner's initializer-created SquareMask.
                            -- Adding a MaskTexture here would cross the native
                            -- restricted initialization boundary.
                        end)
                        if not success then
                            local record=auraDecorated[button]
                            if record and restoreMarker(record) then auraDecorated[button]=nil end
                            limitedAuras()
                        end
                    end
                end end
            end
        end
    end
end
local function decorate(frame)
    if not running() or not available(frame) or not available(frame.visual) then return end
    if V:IsSecret(frame.PlateStyle) or frame.PlateStyle~="HealthbarMode" then return end
    local visual=frame.visual
    if not available(visual.NameText) then return end
    local state=decorated[frame]
    if not state then
        state={};decorated[frame]=state
        if hooksecurefunc and visual.NameText.SetTextColor then
            hooksecurefunc(visual.NameText,"SetTextColor",function(_,r,g,b,a)
                if state.painting then return end
                if not V:IsSecret(r) and not V:IsSecret(g) and not V:IsSecret(b) and not V:IsSecret(a) then state.ownerInk={r,g,b,a or 1} end
                if not running() then return end
                applyName(frame,state)
            end)
        end
    end
    if not state.owned then
        if visual.NameText.GetTextColor then
            local ok,r,g,b,a=pcall(visual.NameText.GetTextColor,visual.NameText)
            if ok and not V:IsSecret(r) and not V:IsSecret(g) and not V:IsSecret(b) and not V:IsSecret(a) then state.ownerInk={r,g,b,a or 1} end
        end
        state.owned=true
    end
    if V.StyleText then
        state.painting=true;V:StyleText(visual.NameText,"name",T.colors.text);state.painting=false
        if visual.SpellText then V:StyleText(visual.SpellText,"compact",T.colors.text) end
        if visual.Castbar and visual.Castbar.CastTime then V:StyleText(visual.Castbar.CastTime,"compact",T.colors.text) end
    end
    if visual.NameText.SetWordWrap then visual.NameText:SetWordWrap(false) end
    applyName(frame,state)
    if not (InCombatLockdown and InCombatLockdown()) and available(visual.Healthbar) and V.Surface then
        state.surface=V:Surface(visual.Healthbar,1,T.radius,T.colors.panel)
        local background=visual.Healthbar.Background
        if state.surface and available(background) then
            if state.backgroundAlpha==nil and background.GetAlpha then state.backgroundAlpha=V:SafeNumber(background:GetAlpha()) end
            if state.backgroundAlpha~=nil then background:SetAlpha(0);state.background=background end
        end
    end
    decorateAuras(frame)
end
local function paintPlate(frame,aurasOnly)
    local ok=pcall(aurasOnly and decorateAuras or decorate,frame)
    if not ok then
        presentationLimited=true
        if V.Report then V:Report("nameplatePresentation","pending","The client refused a native nameplate presentation update. Threat Plates remains the owner; appearance needs an unrestricted refresh.") end
    end
end
local function eachPlate()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
        if available(plate) then paintPlate(plate.TPFrame) end
    end
end
local function same(a,b)
    if V:IsSecret(a) or V:IsSecret(b) or type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function hasOverrides(profile)
    for _,style in pairs(profile.uniqueSettings or {}) do
        if type(style)=="table" and style.useStyle~=false and
            (style.useColor==true or (type(style.scale)=="number" and style.scale~=1)
            or (type(style.alpha)=="number" and style.alpha~=1)) then return true end
    end
    return false
end
deactivate=function()
    active=false
    if InCombatLockdown and InCombatLockdown() then cleanupPending=true;return end
    cleanupPending=false
    for frame,state in pairs(decorated) do
        if state.surface and state.surface.Hide then state.surface:Hide() end
        if state.background then pcall(state.background.SetAlpha,state.background,state.backgroundAlpha) end
        if state.ownerInk and available(frame.visual.NameText) then pcall(frame.visual.NameText.SetTextColor,frame.visual.NameText,unpack(state.ownerInk)) end
        state.owned=false
    end
    for button,record in pairs(auraDecorated) do
        if restoreMarker(record) then auraDecorated[button]=nil
        elseif V.Report then V:Report("nameplateAuras","pending","A native aura marker could not be restored now. Reload to complete presentation cleanup.") end
    end
end
V:RegisterModule("nameplates", {
    label="Nameplates",defaultEnabled=true,
    description="Threat Plates owns health/threat; the reviewed profile and scoped presentation apply the design.",
    Apply=function()
        deactivate()
        if not versionOK() then return false,"Audited Threat Plates 13.3.9 is required." end
        if not flatMediaReady() then return false,"Nameplate flat texture is unavailable; reload before setup.","pending" end
        if reloadPending then return false,"Reload to activate the newly selected nameplate profile.","pending" end
        local profile,name,key=currentProfile()
        if not profile then return false,"Initialize Threat Plates, then run setup." end
        local expected=copy(profile);configure(expected)
        if not same(profile,expected) then return false,"Nameplate design settings differ from the reviewed preset; apply setup and reload.","pending" end
        selectedName,selectedKey,selectedProfile,active=name,key,profile,true
        auraLimited,presentationLimited=false,false
        eachPlate()
        if hasOverrides(profile) then return false,"Custom Threat Plates color/scale rules remain enabled and may override the design. Review those rules in Threat Plates.","pending" end
        if auraLimited then return false,"Nameplate settings applied; the client refused an aura cosmetic update. Native aura appearance is preserved.","pending" end
        if presentationLimited then return false,"Nameplate settings applied; the client refused a native presentation update.","pending" end
        return true,"Reviewed nameplate settings applied. Native aura/combat rendering and restricted-frame appearance still need in-game validation."
    end,
    Disable=deactivate,
})
local function schedule(unit,aurasOnly)
    if not running() or not plain(unit) or not unit:match("^nameplate%d+$") then return end
    if pending[unit] then
        if not aurasOnly then pending[unit]="full" end
        return
    end
    pending[unit]=aurasOnly and "auras" or "full"
    local function run()
        local onlyAuras=pending[unit]=="auras"
        pending[unit]=nil
        if not running() or not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
        local plate=C_NamePlate.GetNamePlateForUnit(unit)
        if available(plate) then paintPlate(plate.TPFrame,onlyAuras) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0,run) else run() end
end
V:On("NAME_PLATE_UNIT_ADDED",function(_,unit) schedule(unit) end)
V:On("UNIT_AURA",function(_,unit) if not (InCombatLockdown and InCombatLockdown()) then schedule(unit,true) end end)
V:On("PLAYER_REGEN_ENABLED",function()
    if cleanupPending then deactivate() end
    if running() then eachPlate() end
end)
