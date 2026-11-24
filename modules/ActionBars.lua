local addonName, V = ...
local T, A = V.Tokens, V.Tokens.action

-- Bartender owns actions, state drivers, cooldown values, bindings and usability.
-- This module only proposes profile geometry and decorates existing widgets.
local bars = { 1, 3, 4, 5 }
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

local function layoutBar(plan, profile, runtime, x, y, size, rows, label)
    if type(profile) ~= "table" or type(profile.position) ~= "table" then
        return false, label .. ": unsupported position schema"
    end
    local width = runtime and V:SafeNumber(runtime.button_width)
    local height = runtime and V:SafeNumber(runtime.button_height)
    local margin = runtime and V:SafeNumber(runtime.button_margin)
    if not width or not height or width <= 0 or width ~= height or margin ~= 0 then
        return false, label .. ": native square button geometry must be available"
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
        local plan = { changes = {}, targetPaths = {}, detail = "Four native 12-button bars (1,3,4,5), each 4x3, form 16x3. Pet: 10x1. Actions, bindings, paging and other bars are preserved. Reload after applying." }
        for column, id in ipairs(bars) do
            local profile = actions.db.profile.actionbars[id]
            local runtime = actions.actionbars[id] or actions.actionbars[1]
            plan.targetPaths[profile] = { "Bartender4DB", "namespaces", "ActionBars", "profiles", profileName, "actionbars", id }
            local blockStride = (A.columns / #bars) * (A.size + A.gap)
            local ok, reason = layoutBar(plan, profile, runtime, A.x + (column-1)*blockStride, A.y, A.size, A.rows, "Bar " .. id)
            if not ok then return nil, reason end
            change(plan, profile, "buttons", 12, "Bar " .. id .. " buttons")
        end
        plan.targetPaths[pet.db.profile] = { "Bartender4DB", "namespaces", "PetBar", "profiles", profileName }
        local ok, reason = layoutBar(plan, pet.db.profile, pet.bar, A.x, A.petY, A.petSize, 1, "Pet bar")
        if not ok then return nil, reason end
        -- LAB still calculates outOfRange when its tint mode is none. Its original
        -- usability/mana coloring remains; our separate 30% layer shows range.
        plan.targetPaths[owner.db.profile] = { "Bartender4DB", "profiles", profileName }
        change(plan, owner.db.profile, "outofrange", "none", "Use vasagoio's translucent range layer")
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
    V:StyleText(text, role)
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

local function styleButton(button, compact)
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
        if hooksecurefunc then
            -- Preserve owner's usability/desaturation state; multiply only
            -- ordinary RGB values, never inspect restricted colors.
            hooksecurefunc(button.icon, "SetVertexColor", function(icon, r, g, b, a)
                if not enabled() or state.tinting then return end
                r, g, b = V:SafeNumber(r), V:SafeNumber(g), V:SafeNumber(b)
                if not r or not g or not b or V:IsSecret(a) then return end
                state.tinting = true
                icon:SetVertexColor(r*A.brightness, g*A.brightness, b*A.brightness, a)
                state.tinting = nil
            end)
            if button.icon.GetVertexColor then
                local r, g, b, a = button.icon:GetVertexColor()
                if not V:IsSecret(r) and not V:IsSecret(g) and not V:IsSecret(b) and not V:IsSecret(a) then
                    button.icon:SetVertexColor(r, g, b, a)
                end
            end
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
    if V.MaskIcon then
        V:MaskIcon(button.icon, T.radius)
        V:MaskIcon(state.elapsed, T.radius)
        V:MaskIcon(state.range, T.radius)
    end
    styleFont(button, button.HotKey, "hotkey")
    styleFont(button, button.Count, "count")
    if button.HotKey then
        button.HotKey:ClearAllPoints()
        button.HotKey:SetPoint("TOPRIGHT", button, "TOPRIGHT", localPixels(button, -2), localPixels(button, -2))
    end
    for _, field in ipairs({ "NormalTexture", "SlotBackground", "Border" }) do
        if button[field] then V:HideArtwork(button[field]) end
    end
    styleCooldown(button, button.cooldown, compact)
    styleCooldown(button, button.chargeCooldown, compact)
    -- Loss-of-control's native danger treatment must remain recognizable.
    if button.lossOfControlCooldown then
        local text = countdownText(button.lossOfControlCooldown)
        if text then styleFont(button, text, compact and "compactCountdown" or "countdown") end
    end
    paintState(button, state)
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
            if button then styleButton(button, false); count = count + 1 end
        end
        for id = 1, 10 do styleButton(_G["BT4PetButton" .. id], true) end
        if LibStub and not V.actionButtonCallbacks then
            local lab = LibStub("LibActionButton-1.0", true)
            if lab and lab.RegisterCallback then
                lab.RegisterCallback(V, "OnButtonCreated", function() V:Refresh("new action button") end)
                lab.RegisterCallback(V, "OnKeybindingChanged", function() V:Refresh("action key labels") end)
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
        for button, state in pairs(styled) do
            state.elapsed:Hide(); state.range:Hide()
            if button.HotKey then button.HotKey:SetAlpha(1) end
        end
    end,
})

V:On("ACTIONBAR_SLOT_CHANGED", function() V:Refresh("action buttons") end)
V:On("PET_BAR_UPDATE", function() V:Refresh("pet buttons") end)
