local addonName, V = ...
local T, A = V.Tokens, V.Tokens.action

-- Bartender owns actions, state drivers, cooldown values, bindings and usability.
-- This module only proposes profile geometry and decorates existing widgets.
local bars = { 1, 3, 4, 5 }
local mainSlots = {}
for _, id in ipairs(bars) do
    for slot = 1, 12 do mainSlots[(id - 1) * 12 + slot] = true end
end
-- Source-reviewed normal action pages only. 11/12 and separate stance,
-- possess, vehicle and extra-action controls are not ordinary extra bars.
local extraBars = { 2, 6, 7, 8, 9, 10, 13, 14, 15 }
local styled, active = setmetatable({}, { __mode = "k" }), false
local signalColors = {
    danger = T.colors.danger, dispel = T.colors.information, attention = T.colors.attention,
}

local function enabled()
    return active and not V.profileReloadPending and V.db and V.db.enabled ~= false and V.db.modules.actionBars ~= false
end

local function getModule(name)
    local owner = _G.Bartender4
    if not owner or type(owner.GetModule) ~= "function" then return end
    return owner:GetModule(name, true)
end

local function change(plan, target, key, value, label)
    plan.changes[#plan.changes + 1] = { table = target, path = plan.targetPaths[target], key = key, value = value, label = label }
end

local function geometryValue(value)
    if V:IsSecret(value) then return "restricted" end
    if type(value) ~= "number" then return "unavailable" end
    if value ~= value or value == math.huge or value == -math.huge then return "non-finite" end
    return string.format("%.6f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function backpackGeometry()
    local button = _G.MainMenuBarBackpackButton
    if V:IsSecret(button) then return nil, "Backpack: the client restricted access to the native button. Reload and try setup again." end
    if (type(button) ~= "table" and type(button) ~= "userdata") or not button.GetWidth or not button.GetHeight then
        return nil, "Backpack: native size getters are unavailable. Reload Bartender4 and try setup again."
    end
    if button.IsForbidden then
        local ok, forbidden = pcall(button.IsForbidden, button)
        if not ok or V:IsSecret(forbidden) or forbidden then
            return nil, "Backpack: the client refused native size access. Leave combat, reload and try setup again."
        end
    end
    local ok, width, height = pcall(function() return button:GetWidth(), button:GetHeight() end)
    if not ok then return nil, "Backpack: native size measurement failed. Reload Bartender4 and try setup again." end
    return {button_width=width, button_height=height, button_margin=0}
end

local function layoutBar(plan, profile, runtime, x, y, size, rows, label)
    if type(profile) ~= "table" or type(profile.position) ~= "table" then
        return false, label .. ": unsupported position schema"
    end
    if V:IsSecret(runtime) then return false, label .. ": native button geometry is restricted. Reload and try setup again." end
    local rawWidth, rawHeight, rawMargin = runtime and runtime.button_width, runtime and runtime.button_height, runtime and runtime.button_margin
    local width, height, margin = V:SafeNumber(rawWidth), V:SafeNumber(rawHeight), V:SafeNumber(rawMargin)
    -- Native width/height getters can differ by floating-point rounding.
    -- One thousandth of a UI unit is imperceptible; a real rectangle is not.
    if not width or not height or width <= 0 or height <= 0 or math.abs(width-height) > .001 or margin ~= 0 then
        return false, label .. ": native square button geometry is unavailable (width=" .. geometryValue(rawWidth)
            .. ", height=" .. geometryValue(rawHeight) .. ", margin=" .. geometryValue(rawMargin)
            .. "). Reload Bartender4 and try setup again; if it persists, include these measurements in the report."
    end
    local scale = V:Pixel(size) / width
    change(plan, profile, "enabled", true, label .. " enabled")
    change(plan, profile, "version", 3, label .. " schema")
    change(plan, profile, "rows", rows, label .. " rows")
    change(plan, profile, "padding", V:Pixel(A.gap) / scale, label .. " gap " .. A.gap)
    change(plan, profile, "hideborder", true, label .. " borderless")
    change(plan, profile, "hidemacrotext", true, label .. " icon labels")
    change(plan, profile, "hidehotkey", false, label .. " hotkeys")
    change(plan, profile, "WoW10Layout", true, label .. " geometry version")
    local position = profile.position
    local ox, oy = V:CanvasOrigin()
    local path = {}
    for i, part in ipairs(plan.targetPaths[profile]) do path[i] = part end
    path[#path + 1] = "position"
    plan.targetPaths[position] = path
    change(plan, position, "point", "TOPLEFT", label .. " anchor")
    -- LibWindow stores offsets in UIParent units, then divides by bar scale.
    -- ButtonBar places its first button +5/-3 inside its 1x1 anchor frame.
    change(plan, position, "x", ox + V:Pixel(x) - 5 * scale, label .. " x")
    change(plan, position, "y", -oy - V:Pixel(y) + 3 * scale, label .. " y")
    change(plan, position, "scale", scale, label .. " button size " .. size)
    change(plan, position, "growHorizontal", "RIGHT", label .. " horizontal flow")
    change(plan, position, "growVertical", "DOWN", label .. " vertical flow")
    return true
end

V:RegisterProfileAdapter("bartender", {
    label = "Bartender4: action layout", addon = "Bartender4",
    Prepare = function()
        local actions, pet = getModule("ActionBars"), getModule("PetBar")
        local owner = _G.Bartender4
        if not actions or not actions.db or not actions.db.profile or
            type(actions.db.profile.actionbars) ~= "table" or not actions.actionbars or
            not pet or not pet.db or not pet.db.profile or not pet.bar or
            not owner.db or not owner.db.profile or owner.CONFIG_VERSION ~= 3 then
            return nil, "Bartender4 schema 3 and its enabled ActionBars/PetBar modules are required"
        end
        local profileName = owner.db.keys and owner.db.keys.profile
        if type(profileName) ~= "string" or V:IsSecret(profileName) then return nil, "Bartender active profile could not be resolved" end
        if A.columns ~= 16 or A.rows ~= 3 or A.petCount ~= 10 then return nil, "The native action-slot adapter requires 16x3 main and 10 pet buttons" end
        local plan = { changes = {}, targetPaths = {}, detail = "Four native 12-button bars (1,3,4,5), each 4x3, form 16x3 with visible empty slots. Pet: 10x1. One backpack button occupies the bottom utility slot. Extra normal bars, decorative artwork, Micro Menu and the old Status Tracking Bar are hidden. Slots, bindings, paging and special action controls are not rewritten. Reload after applying." }
        for column, id in ipairs(bars) do
            local profile = actions.db.profile.actionbars[id]
            if type(profile) ~= "table" then
                return nil, "Bar " .. id .. ": initialize its Bartender profile before setup"
            end
            local runtime = actions.actionbars[id] or actions.actionbars[1]
            plan.targetPaths[profile] = { "Bartender4DB", "namespaces", "ActionBars", "profiles", profileName, "actionbars", id }
            local blockStride = (A.columns / #bars) * (A.size + A.gap)
            local ok, reason = layoutBar(plan, profile, runtime, A.x + (column-1)*blockStride, A.y, A.size, A.rows, "Bar " .. id)
            if not ok then return nil, reason end
            change(plan, profile, "buttons", 12, "Bar " .. id .. " buttons")
            change(plan, profile, "showgrid", true, "Bar " .. id .. " faint empty slots")
        end
        plan.targetPaths[pet.db.profile] = { "Bartender4DB", "namespaces", "PetBar", "profiles", profileName }
        local ok, reason = layoutBar(plan, pet.db.profile, pet.bar, A.x, A.petY, A.petSize, 1, "Pet bar")
        if not ok then return nil, reason end
        local bags = getModule("BagBar")
        if bags and bags.db and type(bags.db.profile) == "table" then
            -- BagBar measures its cells from CharacterBag0Slot, but the actual
            -- backpack can be larger. One-bag geometry must use the backpack.
            local geometry, unavailable = backpackGeometry()
            if not geometry then return nil, unavailable end
            plan.targetPaths[bags.db.profile] = { "Bartender4DB", "namespaces", "BagBar", "profiles", profileName }
            ok, reason = layoutBar(plan, bags.db.profile, geometry, A.utilityX, A.bagY, A.size, 1, "Backpack")
            if not ok then return nil, reason end
            change(plan, bags.db.profile, "onebag", true, "One backpack button")
            change(plan, bags.db.profile, "onebagreagents", false, "No separate reagent-bag button")
            change(plan, bags.db.profile, "keyring", false, "No separate keyring button")
            if type(bags.db.profile.visibility) == "table" then
                plan.targetPaths[bags.db.profile.visibility] = { "Bartender4DB", "namespaces", "BagBar", "profiles", profileName, "visibility" }
                change(plan, bags.db.profile.visibility, "always", false, "Backpack visible")
                change(plan, bags.db.profile.visibility, "custom", false, "Backpack uses native visibility")
            end
        end
        -- LAB still calculates outOfRange when its tint mode is none. Its original
        -- usability/mana coloring remains; our separate 30% layer shows range.
        plan.targetPaths[owner.db.profile] = { "Bartender4DB", "profiles", profileName }
        change(plan, owner.db.profile, "outofrange", "none", "Use vasagoio's translucent range layer")
        -- Hide extra normal rows through the owner's visibility driver, keeping
        -- their existing action/page data and enabled state intact. A prior
        -- custom visibility expression overrides Always Hide, so temporarily
        -- turn off that toggle but preserve its expression for restoration.
        for _, id in ipairs(extraBars) do
            local profile = actions.db.profile.actionbars[id]
            if type(profile) == "table" and profile.enabled ~= false then
                if type(profile.visibility) ~= "table" then
                    return nil, "Bar " .. id .. ": unsupported visibility schema"
                end
                plan.targetPaths[profile.visibility] = { "Bartender4DB", "namespaces", "ActionBars", "profiles", profileName, "actionbars", id, "visibility" }
                change(plan, profile.visibility, "custom", false, "Bar " .. id .. " use standard visibility")
                change(plan, profile.visibility, "always", true, "Hide extra bar " .. id .. "; keep its slots and paging")
            end
        end
        -- Bartender's Blizzard preset enables this independent artwork module.
        -- Hiding native MainMenuBar is insufficient: these are owner-created
        -- gryphons and slot textures, with a persistent, reversible owner flag.
        for _, name in ipairs({"BlizzardArt", "MicroMenu", "StatusTrackingBar"}) do
            local module = getModule(name)
            if module and module.db and type(module.db.profile) == "table" then
                plan.targetPaths[module.db.profile] = { "Bartender4DB", "namespaces", name, "profiles", profileName }
                change(plan, module.db.profile, "enabled", false, "Hide obsolete " .. name .. " alongside the agreed grid")
            end
        end
        plan.targetPaths = nil
        return plan
    end,
})

local function localPixels(button, pixels)
    local scale = V:SafeNumber(button:GetEffectiveScale())
    local uiScale = V:SafeNumber(UIParent:GetEffectiveScale())
    if not scale or scale <= 0 or not uiScale then return pixels end
    return V:Pixel(pixels) * uiScale / scale
end

local function styleFont(button, text, role)
    if V:IsSecret(text) or (type(text) ~= "table" and type(text) ~= "userdata") or not text.SetFont then return end
    V:StyleText(text, role, T.colors.iconText)
    local font, size, flags = V:Font(role)
    local scale = V:SafeNumber(button:GetEffectiveScale())
    local uiScale = V:SafeNumber(UIParent:GetEffectiveScale())
    if scale and scale > 0 and uiScale then text:SetFont(font, size * uiScale / scale, flags) end
end

local function countdownText(cooldown)
    if cooldown.GetCountdownFontString then return cooldown:GetCountdownFontString() end
    if not cooldown.GetRegions then return end
    for _, region in ipairs({ cooldown:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") then return region end
    end
end

local function styleCooldown(button, cooldown, compact)
    if not cooldown then return end
    local kind = cooldown.currentCooldownType
    local loss = not V:IsSecret(kind) and _G.COOLDOWN_TYPE_LOSS_OF_CONTROL ~= nil and kind == _G.COOLDOWN_TYPE_LOSS_OF_CONTROL
    -- A .12 elapsed underlay plus this swipe composites to .80 remaining.
    if cooldown.SetSwipeColor and not loss then cooldown:SetSwipeColor(0, 0, 0, (A.cooldownRemaining-A.cooldownElapsed)/(1-A.cooldownElapsed)) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    local mask = V.Media and (compact and V.Media.mask32 or V.Media.mask42)
    if cooldown.SetSwipeTexture then cooldown:SetSwipeTexture(mask or "Interface\\Buttons\\WHITE8X8") end
    if cooldown.SetUseCircularEdge then cooldown:SetUseCircularEdge(false) end
    if cooldown.SetHideCountdownNumbers then cooldown:SetHideCountdownNumbers(false) end
    local text = countdownText(cooldown)
    if text then
        styleFont(button, text, compact and "compactCountdown" or "countdown")
        text:ClearAllPoints()
        text:SetPoint("CENTER", button, "CENTER", 0, 0)
        text:SetJustifyH("CENTER")
    end
end

local function hasCooldown(cooldown)
    if not cooldown or not cooldown.GetCooldownTimes then return false end
    local shown = cooldown:IsShown()
    if V:IsSecret(shown) then return nil end
    if not shown then return false end
    local start, duration = cooldown:GetCooldownTimes()
    start, duration = V:SafeNumber(start), V:SafeNumber(duration)
    if not start or not duration then return nil end
    -- Do not obscure hotkeys for the ordinary global cooldown alone.
    return duration > 1500 and start + duration > GetTime()*1000
end

local function paintState(button, state)
    if not enabled() then return end
    local normal = hasCooldown(button.cooldown)
    local charge = hasCooldown(button.chargeCooldown)
    local loss = hasCooldown(button.lossOfControlCooldown)
    local cooling = normal == true or charge == true or loss == true
    local known = cooling or (normal ~= nil and charge ~= nil and loss ~= nil)
    if known then
        if button.HotKey then button.HotKey:SetAlpha(cooling and 0 or 1) end
        if button.Count and state.cooling ~= cooling then
            button.Count:ClearAllPoints()
            if cooling then
                button.Count:SetPoint("TOPRIGHT", button, "TOPRIGHT", localPixels(button, 6), localPixels(button, 8))
            else
                button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", localPixels(button, -2), localPixels(button, 2))
            end
        end
        state.cooling = cooling
        state.elapsed:SetShown(cooling)
    else
        -- Let native widgets present restricted cooldown information unchanged.
        if button.HotKey then button.HotKey:SetAlpha(1) end
        state.elapsed:Hide()
        state.cooling = nil
    end
    local outOfRange = button.outOfRange
    if not V:IsSecret(outOfRange) and type(outOfRange) == "boolean" then
        state.range:SetShown(outOfRange)
    else
        state.range:Hide()
    end
end

local function updateEmptySlot(button, state)
    if not state.empty then return end
    -- The owner already chooses whether icon art exists for the active page.
    -- Read only its presentation state, never action/charge/usable payloads.
    local shown = button.icon:IsShown()
    state.empty:SetShown(enabled() and not V:IsSecret(shown) and shown == false)
end

local function hideButtonArtwork(button)
    -- Normal/slot art is decorative. Border is the owner's equipped-item
    -- signal; checked/highlight/proc/autocast regions also retain their state.
    for _, field in ipairs({ "NormalTexture", "SlotBackground" }) do
        if button[field] then V:HideArtwork(button[field]) end
    end
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal and normal ~= button.NormalTexture then V:HideArtwork(normal) end
end

-- Bartender's optional zoom and FTM's flat skin otherwise use different crops.
-- Match the reviewed flat-item crop while keeping the actual button hitbox and
-- native state overlays intact. Remember owner writes for a reversible release.
local appearances = setmetatable({}, {__mode="k"})
local function ordinaryNumbers(...)
    if select("#",...)==0 then return end
    local values = {...}
    for i=1,select("#",...) do
        if not V:SafeNumber(values[i]) then return end
    end
    return values
end
local function ordinaryColor(r,g,b,a)
    if V:IsSecret(a) then return end
    if a==nil then a=1 end
    return ordinaryNumbers(r,g,b,a)
end
local function appearanceActive(record)
    return record.live and not record.releasing and record.allowed()
end
local function applyCrop(record)
    record.writing = true
    record.icon:SetTexCoord(.08,.92,.08,.92)
    record.writing = nil
end
local function applyTint(record)
    if not record.tint then return end
    record.writing = true
    local c=record.tint
    record.icon:SetVertexColor(c[1]*A.brightness,c[2]*A.brightness,c[3]*A.brightness,c[4])
    record.writing = nil
end
local function removeSkinnerBackdrop(record, border)
    -- Skinner reparents hotkeys, counts and proc/autocast regions into sbb.
    -- Hiding that frame would hide gameplay feedback: clear its backdrop only.
    if not border or V:IsSecret(border) or not border.GetBackdrop or not border.SetBackdrop then return end
    if border.IsForbidden then
        local ok, forbidden=pcall(border.IsForbidden,border)
        if not ok or V:IsSecret(forbidden) or forbidden then return end
    end
    local chrome=record.chrome
    if not chrome then
        chrome={frame=border}; record.chrome=chrome
        if hooksecurefunc then
            hooksecurefunc(border,"SetBackdrop",function(_,value)
                if chrome.writing or not appearanceActive(record) or V:IsSecret(value) then return end
                chrome.backdrop=value
                if InCombatLockdown() then V:Refresh("action artwork after combat",record.owner); return end
                chrome.writing=true; border:SetBackdrop(nil); chrome.writing=nil
            end)
            for _,property in ipairs({{"SetBackdropColor","fill"},{"SetBackdropBorderColor","edge"}}) do
                if border[property[1]] then
                    local key=property[2]
                    hooksecurefunc(border,property[1],function(_,r,g,b,a)
                        if not chrome.writing and appearanceActive(record) then chrome[key]=ordinaryColor(r,g,b,a) end
                    end)
                end
            end
        end
    end
    if chrome.frame~=border then return end
    if not chrome.live then
        chrome.backdrop=border:GetBackdrop()
        chrome.fill=border.GetBackdropColor and ordinaryNumbers(border:GetBackdropColor())
        chrome.edge=border.GetBackdropBorderColor and ordinaryNumbers(border:GetBackdropBorderColor())
        chrome.live=true
    end
    if border:GetBackdrop() then
        chrome.writing=true; border:SetBackdrop(nil); chrome.writing=nil
    end
end
local function polishButton(button,icon,allowed,owner)
    local record=appearances[button]
    if not record then
        record={icon=icon}; appearances[button]=record
        if hooksecurefunc then
            if icon.SetTexCoord and icon.GetTexCoord then
                hooksecurefunc(icon,"SetTexCoord",function(_, ...)
                    if record.writing or not appearanceActive(record) then return end
                    local coords=ordinaryNumbers(...)
                    if not coords then return end
                    record.coords=coords
                    if InCombatLockdown() then V:Refresh("action artwork after combat",record.owner); return end
                    applyCrop(record)
                end)
            end
            if icon.SetVertexColor and icon.GetVertexColor then
                hooksecurefunc(icon,"SetVertexColor",function(_,r,g,b,a)
                    if record.writing or not appearanceActive(record) then return end
                    record.tint=ordinaryColor(r,g,b,a); applyTint(record)
                end)
            end
        end
    end
    record.allowed,record.owner=allowed,owner
    if not record.live then
        record.coords=icon.GetTexCoord and ordinaryNumbers(icon:GetTexCoord())
        record.tint=icon.GetVertexColor and ordinaryNumbers(icon:GetVertexColor())
        record.live=true
    end
    if record.coords and icon.SetTexCoord then applyCrop(record) end
    if icon.SetVertexColor then applyTint(record) end
    removeSkinnerBackdrop(record,button.sbb)
    if button.flatBorder and not V:IsSecret(button.flatBorder) and button.flatBorder.GetAlpha then
        if record.flatAlpha==nil then record.flatAlpha=V:SafeNumber(button.flatBorder:GetAlpha()) end
        if record.flatAlpha then button.flatBorder:SetAlpha(0) end
    end
end
local function releaseAppearance(button)
    local record=appearances[button]
    if not record or not record.live or InCombatLockdown() then return end
    local chrome=record.chrome
    record.releasing=true
    local ok,reason=pcall(function()
        if record.coords then record.icon:SetTexCoord(unpack(record.coords)) end
        if record.tint then record.icon:SetVertexColor(unpack(record.tint)) end
        if record.flatAlpha and button.flatBorder then button.flatBorder:SetAlpha(record.flatAlpha) end
        if chrome and chrome.live then
            chrome.frame:SetBackdrop(chrome.backdrop)
            if chrome.fill then chrome.frame:SetBackdropColor(unpack(chrome.fill)) end
            if chrome.edge then chrome.frame:SetBackdropBorderColor(unpack(chrome.edge)) end
        end
    end)
    record.releasing=nil
    if not ok then error(reason) end -- Keep the captured appearance for a retry.
    record.live,record.flatAlpha=false,nil
    if chrome then chrome.live=false end
end

local function styleButton(button, compact, mainSlot)
    if not button or not button.icon or not button.CreateTexture then return end
    local state = styled[button]
    if not state then
        state = { compact = compact }
        styled[button] = state
        state.elapsed = button:CreateTexture(nil, "ARTWORK", nil, 1)
        state.elapsed:SetAllPoints(button.icon)
        state.elapsed:SetColorTexture(0, 0, 0, A.cooldownElapsed)
        state.elapsed:Hide()
        state.range = button:CreateTexture(nil, "ARTWORK", nil, 2)
        state.range:SetAllPoints(button.icon)
        state.range:SetColorTexture(T.colors.range[1], T.colors.range[2], T.colors.range[3], T.alpha.range)
        state.range:Hide()
        if mainSlot then
            state.empty = button:CreateTexture(nil, "BACKGROUND", nil, -8)
            state.empty.__vasagoio, state.empty.ignoreInLayout = true, true
            state.empty:SetAllPoints(button.icon)
            local color = T.colors.emptySlot
            state.empty:SetColorTexture(color[1], color[2], color[3], T.alpha.emptySlot)
            state.empty:Hide()
        end
        if hooksecurefunc then
            for _, field in ipairs({ "cooldown", "chargeCooldown" }) do
                local cd = button[field]
                if cd and cd.SetSwipeColor then
                    hooksecurefunc(cd, "SetSwipeColor", function(widget, r, g, b)
                        if not enabled() or state.swipeTinting then return end
                        r, g, b = V:SafeNumber(r), V:SafeNumber(g), V:SafeNumber(b)
                        if r ~= 0 or g ~= 0 or b ~= 0 then return end
                        state.swipeTinting = true
                        widget:SetSwipeColor(0, 0, 0, (A.cooldownRemaining-A.cooldownElapsed)/(1-A.cooldownElapsed))
                        state.swipeTinting = nil
                    end)
                end
            end
        end
    end
    polishButton(button,button.icon,enabled,"actionBars")
    if V.MaskIcon then
        V:MaskIcon(button.icon, T.radius)
        V:MaskIcon(state.elapsed, T.radius)
        V:MaskIcon(state.range, T.radius)
        if state.empty then V:MaskIcon(state.empty, T.radius) end
    end
    styleFont(button, button.HotKey, "hotkey")
    styleFont(button, button.Count, "count")
    if button.HotKey then
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", localPixels(button, -2), localPixels(button, -2))
    end
    hideButtonArtwork(button)
    styleCooldown(button, button.cooldown, compact)
    styleCooldown(button, button.chargeCooldown, compact)
    -- Loss-of-control's native danger treatment must remain recognizable.
    if button.lossOfControlCooldown then
        local text = countdownText(button.lossOfControlCooldown)
        if text then styleFont(button, text, compact and "compactCountdown" or "countdown") end
    end
    paintState(button, state)
    updateEmptySlot(button, state)
end

-- Presentation for owner-provided utility buttons. References are explicit;
-- never alias native fields or replace the owner's cooldown/text calculation.
local utilityStyles = setmetatable({}, {__mode="k"})
local function utilityEnabled(state)
    return state and not state.suspended and V.db and V.db.enabled ~= false and not V.readOnly
        and not V.profileReloadPending and V:IsModuleEnabled(state.owner)
end
local function rememberCountPosition(state,count)
    if state.countPosition then return state.countPosition.region==count end
    if not count or not count.GetNumPoints or not count.GetPoint then return false end
    local ok,position=pcall(function()
        local result={region=count,points={}}
        local n=V:SafeNumber(count:GetNumPoints())
        if not n or n<0 or n>9 then return end
        for i=1,n do
            local point,relative,relativePoint,x,y=count:GetPoint(i)
            if V:IsSecret(point) or V:IsSecret(relative) or V:IsSecret(relativePoint)
                or not V:SafeNumber(x) or not V:SafeNumber(y) then return end
            result.points[i]={point,relative,relativePoint,x,y}
        end
        return result
    end)
    if ok then state.countPosition=position end
    return ok and position~=nil
end
function V:StyleActionButton(button, options)
    options = options or {}
    if V:IsSecret(button) or not button or (InCombatLockdown and InCombatLockdown()) then return false end
    local owner = options.owner or "actionBars"
    if not V.db or V.db.enabled == false or V.readOnly or V.profileReloadPending or not V:IsModuleEnabled(owner) then return false end
    if button.IsForbidden then
        local ok,forbidden=pcall(button.IsForbidden,button)
        if not ok or V:IsSecret(forbidden) or forbidden then return false end
    end
    local icon = options.icon or button.icon or button.Icon
    if not icon or V:IsSecret(icon) then return false end
    local state = utilityStyles[button] or {}
    utilityStyles[button] = state
    state.owner, state.suspended = owner, false
    state.hotkey = options.hotkey or button.HotKey or button.hotkey
    state.timer = options.timer
    local count = options.count or button.Count or button.count
    if V:IsSecret(state.hotkey) or V:IsSecret(state.timer) or V:IsSecret(count) then return false end
    if V.MaskIcon then V:MaskIcon(icon, T.radius) end
    state.allowed=state.allowed or function() return utilityEnabled(state) end
    polishButton(button,icon,state.allowed,owner)
    hideButtonArtwork(button)
    styleFont(button, state.hotkey, "hotkey")
    styleFont(button, count, "count")
    if rememberCountPosition(state,count) then
        count:ClearAllPoints()
        count:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",localPixels(button,-2),localPixels(button,2))
    end
    if state.hotkey then
        state.hotkey:ClearAllPoints()
        state.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", localPixels(button,-2), localPixels(button,-2))
    end
    local cd = options.cooldown or button.cooldown or button.Cooldown
    if cd and not V:IsSecret(cd) then
        if cd.SetSwipeColor then cd:SetSwipeColor(0,0,0,A.cooldownRemaining) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetUseCircularEdge then cd:SetUseCircularEdge(false) end
        local mask = V.Media and V.Media[options.compact and "mask32" or "mask42"]
        if mask and cd.SetSwipeTexture then cd:SetSwipeTexture(mask) end
    end
    local timer = state.timer or (cd and countdownText(cd))
    if timer then
        styleFont(button, timer, options.compact and "compactCountdown" or "countdown")
        timer:ClearAllPoints(); timer:SetPoint("CENTER",button,"CENTER",0,0)
        timer:SetJustifyH("CENTER")
        -- FTM already produces plain formatted timer strings. Observing that
        -- public presentation avoids another timer or reading cooldown values.
        if state.timer and hooksecurefunc and state.timerHook ~= timer then
            state.timerHook = timer
            hooksecurefunc(timer,"SetText",function(_,value)
                if state.timer ~= timer or not utilityEnabled(state) or not state.hotkey then return end
                if V:IsSecret(value) then state.hotkey:SetAlpha(1); return end
                if type(value)=="string" then state.hotkey:SetAlpha(value~="" and 0 or 1) end
            end)
        end
    end
    return true
end
function V:ClearActionButtonStyle(button)
    local state = utilityStyles[button]
    if state then
        state.suspended = true
        if state.hotkey then state.hotkey:SetAlpha(1) end
        if state.countPosition and not InCombatLockdown() then
            local saved=state.countPosition
            saved.region:ClearAllPoints()
            for _,point in ipairs(saved.points) do saved.region:SetPoint(unpack(point)) end
            state.countPosition=nil
        end
    end
    releaseAppearance(button)
end

-- Owner adapters must provide a semantic signal; normal buffs receive none.
-- No aura querying, dispel inference, priority guessing or protected positioning.
function V:StyleAura(button, options)
    if not button then return false end
    options = options or {}
    local icon = button.Icon or button.icon
    if not icon then return false end
    if V.MaskIcon then V:MaskIcon(icon, T.radius) end
    if icon.SetVertexColor then icon:SetVertexColor(A.brightness, A.brightness, A.brightness, A.opacity) end
    local duration = button.Duration or button.duration
    if not V:IsSecret(duration) and duration == nil and button.cooldown then duration = countdownText(button.cooldown) end
    local count = button.Count or button.count
    if not V:IsSecret(duration) and (type(duration) == "table" or type(duration) == "userdata") and duration.SetFont then
        styleFont(button, duration, "aura")
        duration:ClearAllPoints()
        duration:SetPoint("BOTTOM", button, "BOTTOM", 0, localPixels(button, 2))
    end
    if count then styleFont(button, count, "count") end
    if not V:IsSecret(options.signal) and options.signal and signalColors[options.signal] then
        local signal = button.vasagoioSignal
        if not signal then
            signal = button:CreateTexture(nil, "OVERLAY")
            button.vasagoioSignal = signal
        end
        local color = signalColors[options.signal]
        signal:SetColorTexture(color[1], color[2], color[3], 1)
        signal:ClearAllPoints()
        signal:SetPoint("TOPLEFT", button, "BOTTOMLEFT", localPixels(button, A.signalInset), localPixels(button, -A.signalGap))
        signal:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", localPixels(button, -A.signalInset), localPixels(button, -A.signalGap))
        signal:SetHeight(localPixels(button, A.signalHeight))
        signal:Show()
    elseif button.vasagoioSignal then
        button.vasagoioSignal:Hide()
    end
    return true
end

V:RegisterModule("actionBars", {
    label = "Action buttons and aura presentation", defaultEnabled = true,
    description = "Borderless icons, native cooldown widgets, readable counts and translucent range feedback.",
    Apply = function()
        if InCombatLockdown() then return false, "Leave combat before refreshing action-button styling" end
        if not _G.Bartender4 then return false, "Bartender4 is not loaded; native action bars are unchanged" end
        active = true
        local count = 0
        for id = 1, 180 do
            local button = _G["BT4Button" .. id]
            if button then styleButton(button, false, mainSlots[id]); count = count + 1 end
        end
        for id = 1, 10 do styleButton(_G["BT4PetButton" .. id], true) end
        if _G.MainMenuBarBackpackButton then
            V:StyleActionButton(_G.MainMenuBarBackpackButton, {owner="actionBars",count=_G.MainMenuBarBackpackButton.FreeSlots})
        end
        if LibStub and not V.actionButtonCallbacks then
            local lab = LibStub("LibActionButton-1.0", true)
            if lab and lab.RegisterCallback then
                lab.RegisterCallback(V, "OnButtonCreated", function() V:Refresh("new action button", "actionBars") end)
                lab.RegisterCallback(V, "OnKeybindingChanged", function() V:Refresh("action key labels", "actionBars") end)
                -- LAB resets decorative art when its active page/action
                -- changes. This callback updates only the changed button's
                -- empty/art state, not fonts, geometry or the whole HUD.
                lab.RegisterCallback(V, "OnButtonUpdate", function(_, button)
                    if V:IsSecret(button) or not enabled() then return end
                    local state = styled[button]
                    if not state then return end
                    updateEmptySlot(button, state)
                    if InCombatLockdown() then
                        V:Refresh("action styling after combat", "actionBars")
                        return
                    end
                    hideButtonArtwork(button)
                    local appearance=appearances[button]
                    if appearance then removeSkinnerBackdrop(appearance,button.sbb) end
                end)
                V.actionButtonCallbacks = true
            end
        end
        if not V.actionButtonTicker then
            local elapsed = 0
            local ticker = CreateFrame("Frame")
            ticker:SetScript("OnUpdate", function(_, delta)
                if not enabled() then return end
                elapsed = elapsed + delta
                if elapsed < .15 then return end
                elapsed = 0
                for button, state in pairs(styled) do
                    local visible = button:IsVisible()
                    if not V:IsSecret(visible) and visible then paintState(button, state) end
                end
            end)
            V.actionButtonTicker = ticker
        end
        return count > 0, "Styled existing Bartender buttons; apply reviewed setup for layout. Restricted cooldown transitions stay native."
    end,
    Disable = function()
        active = false
        for button, state in pairs(utilityStyles) do
            if state.owner == "actionBars" then V:ClearActionButtonStyle(button) end
        end
        for button, state in pairs(styled) do
            releaseAppearance(button)
            state.elapsed:Hide(); state.range:Hide()
            if state.empty then state.empty:Hide() end
            if button.HotKey then button.HotKey:SetAlpha(1) end
        end
    end,
})

V:On("ACTIONBAR_SLOT_CHANGED", function() V:Refresh("action buttons", "actionBars") end)
V:On("PET_BAR_UPDATE", function() V:Refresh("pet buttons", "actionBars") end)
