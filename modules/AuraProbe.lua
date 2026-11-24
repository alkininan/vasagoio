-- Optional manual research display; intentionally not registered as a HUD module.
local _, V = ...
-- No aura reads, hooks, scripts on native aura descendants, or periodic work.
local panel, buildError
local containers = {}
local ICON, GAP, LIMIT, COLUMN = 28, 4, 40, 336
-- Next binary64 value after 60: formatter thresholds are inclusive minima.
-- Whether the engine preserves this precision is part of the manual test.
local AFTER_SIXTY = 60 + 2 ^ -47

local function Say(message)
    V:Print("Aura test: " .. message)
end

local function Label(parent, text, x, y, size)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, size or 12, "OUTLINE")
    label:SetTextColor(0.92, 0.94, 0.96)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(text)
end

local function InitializeButton(button, experiment, formatter, transparent)
    button:SetSize(ICON, ICON)
    button:EnableMouse(false)
    local clip = CreateFrame("Frame", nil, button, "DisableUntrustedLayoutScriptsTemplate")
    clip:SetSize(ICON, ICON)
    clip:SetClipsChildren(true)
    clip:EnableMouse(false)
    local gate
    if experiment then
        -- Only the renderer sees the formatted duration. A wide glyph moves the
        -- clipping rectangle off the icon; an empty glyph leaves it over the icon.
        gate = button:CreateFontString(nil, "BACKGROUND")
        gate:SetFont(STANDARD_TEXT_FONT, 64, "")
        gate:SetPoint("TOPLEFT", button, "TOPLEFT")
        gate:SetWidth(0)
        gate:SetWordWrap(false)
        gate:SetJustifyH("LEFT")
        gate:SetTextColor(0, 0, 0, 0)
        gate:SetText("")
        clip:SetPoint("TOPLEFT", gate, "TOPRIGHT")
    else
        clip:SetPoint("TOPLEFT", button, "TOPLEFT")
    end
    local icon = clip:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    local cooldown = CreateFrame("Cooldown", nil, clip, "CooldownFrameTemplate")
    cooldown:SetAllPoints(button)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:EnableMouse(false)
    local count = clip:CreateFontString(nil, "OVERLAY")
    count:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    -- Declare all geometry before registering widgets with the native owner.
    button:SetIcon(icon)
    button:SetDurationCooldown(cooldown)
    button:SetApplicationCount(count, {})
    if gate then
        button:SetDurationText(gate, {
            textFormat = { formatString = "{}", components = {
                { property = Enum.DurationTextBindingProperty.TotalDuration, formatter = formatter },
            } },
            textColor = { property = Enum.DurationTextBindingProperty.TotalDuration, curve = transparent },
        })
    end
end

local function AddView(column, harmful, mode, formatter, transparent)
    local x, y = 16 + (column - 1) * COLUMN, harmful and -264 or -96
    Label(panel, harmful and "Player debuffs" or "Player buffs", x, y + 20)
    local container = CreateFrame("AuraContainer", nil, panel, "CustomAuraContainerTemplate")
    containers[#containers + 1] = container
    container:SetEnabled(false)
    container:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    container:SetSize(1, 1)
    container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.None)
    container:SetFlowLayoutAxis(AnchorUtil.FlowLayoutAxis.Horizontal)
    container:SetFlowLayoutAnchorPoint("TOPLEFT")
    container:SetFlowLayoutGrowthDirection(AnchorUtil.FlowDirection.Right, AnchorUtil.FlowDirection.Down)
    container:SetFlowLayoutMaximumLineSize(10 * ICON + 9 * GAP)
    container:AddAuraGroup("probe", harmful and "HARMFUL" or "HELPFUL", {
        maxFrameCount = LIMIT,
        candidateFilters = mode == "short" and { maxDuration = 60 } or nil,
        sortMethod = AuraContainerSortMethod.Default,
        sortDirection = AuraContainerSortDirection.Normal,
        layout = { elementWidth = ICON, elementHeight = ICON, elementSpacing = GAP, lineSpacing = GAP },
        initializeFrame = function(button)
            if buildError then return end
            local ok, err = pcall(InitializeButton, button, mode == "long", formatter, transparent)
            if not ok then
                buildError = tostring(err)
                Say("Initializer rejected; stop this test: " .. buildError)
            end
        end,
    })
    container:SetUnit("player")
end

local function Build()
    assert(C_StringUtil and C_StringUtil.CreateNumericRuleFormatter, "native numeric formatter unavailable")
    assert(C_CurveUtil and C_CurveUtil.CreateColorCurve, "native color curve unavailable")
    assert(Enum and Enum.DurationTextBindingProperty and Enum.DurationTextBindingProperty.TotalDuration,
        "native TotalDuration binding unavailable")
    local formatter = C_StringUtil.CreateNumericRuleFormatter()
    formatter:SetBreakpoints({ { threshold = 0, format = "WWWW" }, { threshold = AFTER_SIXTY, format = "" } })
    local transparent = C_CurveUtil.CreateColorCurve()
    transparent:SetType(Enum.LuaCurveType.Step)
    transparent:AddPoint(0, CreateColor(0, 0, 0, 0))
    panel = CreateFrame("Frame", nil, UIParent, "DisableUntrustedLayoutScriptsTemplate")
    panel:SetSize(1024, 416)
    panel:SetPoint("TOP", UIParent, "TOP", 0, -160)
    panel:EnableMouse(false)
    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.02, 0.02, 0.02, 0.88)
    Label(panel, "AURA RESEARCH — experimental; original aura displays stay unchanged", 16, -12, 14)
    Label(panel, "Full duration, not remaining time. Long view may have gaps. /vasagoio auratest hide", 16, -36)
    for column, mode in ipairs({ "all", "short", "long" }) do
        Label(panel, ({ "All — reference", "Short: full duration <= 60s", "Long/permanent — EXPERIMENT" })[column],
            16 + (column - 1) * COLUMN, -56)
        AddView(column, false, mode, formatter, transparent)
        AddView(column, true, mode, formatter, transparent)
    end
    assert(not buildError, buildError)
end

-- These checks read addon metadata only, never aura state. An old standalone
-- install must not run a second copy of this experiment beside the built-in one.
local function AddonLoaded(name)
    local query = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if type(query) ~= "function" then return nil, "addon availability API unavailable" end
    local ok, loaded = pcall(query, name)
    if not ok then return nil, "addon availability check failed: " .. tostring(loaded) end
    return loaded == true
end

local function LoadNative()
    local loaded, reason = AddonLoaded("Blizzard_AuraContainer")
    if loaded then return true end
    local loader = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
    if type(loader) ~= "function" then return nil, reason or "native aura loader unavailable" end
    local ok, success, detail = pcall(loader, "Blizzard_AuraContainer")
    if not ok then return nil, tostring(success) end
    if not success then return nil, "native aura renderer unavailable: " .. tostring(detail or "load refused") end
    return true
end

function V:HideAuraProbe()
    -- Hide is always available, including when settings become disabled/read-only.
    -- Isolate failures so one container cannot keep the outer comparison visible.
    local stopped = true
    for _, container in ipairs(containers) do
        if not pcall(container.SetEnabled, container, false) then stopped = false end
    end
    if panel then panel:Hide() end
    if not stopped then Say("Comparison hidden, but native cleanup was refused. /reload to finish stopping the test.") end
    return stopped
end

function V:AuraProbeCommand(argument)
    local command = (argument or ""):lower():match("^%s*(%S*)")
    if command == "" then command = "show" end
    if command ~= "show" and command ~= "hide" and command ~= "reset" then
        Say("Use /vasagoio auratest show, hide, or reset. Start/reset out of combat; no data is recorded.")
        return
    end
    if command == "hide" then self:HideAuraProbe(); return end
    if not (self.db and self.db.enabled) or self.readOnly then
        self:HideAuraProbe()
        Say("Enable vasagoio with writable settings before starting the test.")
        return
    end
    if InCombatLockdown() then Say("Start or reset out of combat, then compare during combat."); return end
    local standalone, detectionError = AddonLoaded("VasagoioAuraProbe")
    if standalone or SLASH_VASAGOIOAURAPROBE1 then
        self:HideAuraProbe()
        Say("Disable the separate VasagoioAuraProbe addon and reload before using this built-in test.")
        return
    end
    if detectionError then Say(detectionError); return end
    if buildError then Say("Setup failed; /reload before retrying: " .. buildError); return end
    if not panel then
        local available, reason = LoadNative()
        if not available then Say(reason); return end
        local ok, err = pcall(Build)
        if not ok then buildError = tostring(err); self:HideAuraProbe(); Say("Unavailable: " .. buildError); return end
    end
    if command == "reset" then
        self:HideAuraProbe()
        panel:ClearAllPoints()
        panel:SetPoint("TOP", UIParent, "TOP", 0, -160)
    end
    panel:Show()
    for _, container in ipairs(containers) do
        local ok, err = pcall(container.SetEnabled, container, true)
        if not ok then buildError = tostring(err) end
        if buildError then self:HideAuraProbe(); Say("Unavailable: " .. buildError); return end
    end
    Say("Experimental comparison shown. Inspect visually; no in-game success has been established.")
end
