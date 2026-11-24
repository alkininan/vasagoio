local addonName, V = ...

-- Audited against ForeverUnitFrames 0.79.1 and 0.81.0. Configuration is applied only
-- through the setup transaction; this file never owns secure unit buttons.
local OWNER = "ForeverUnitFrames"
local VERSIONS = { ["0.79.1"] = true, ["0.81.0"] = true }
local T = V.Tokens
local function rgb(hex, alpha)
    if type(hex) == "table" then return { hex[1], hex[2], hex[3], alpha or hex[4] or 1 } end
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255, alpha or 1 }
end
local design = {
    L = T.units.large, M = T.units.medium, S = T.units.small, XS = T.units.xsmall,
    classes = T.class,
    resources = { Mana = T.resource.MANA, Rage = T.resource.RAGE, Energy = T.resource.ENERGY, Focus = T.resource.FOCUS },
}
V.UnitDesign = design

local function ownerVersion()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local version = get and get(OWNER, "Version")
    if not V:IsSecret(version) and type(version) == "string" then return version end
end
local function versionOK()
    return VERSIONS[ownerVersion()] == true
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copy(child) end
    return result
end
local function characterKey()
    if not UnitFullName then return end
    local name, realm = UnitFullName("player")
    if V:IsSecret(name) or V:IsSecret(realm) then return end
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
    if V:IsSecret(realm) or type(name) ~= "string" or type(realm) ~= "string" then return end
    return name .. "-" .. realm
end
-- Shared ownership check for event-driven child decorations. A stored setup
-- flag alone must not style an unsupported owner version or another profile.
function V:GetReviewedUnitProfile()
    if not versionOK() or not _G.ForeverUnitFrames then return end
    local db,char=_G.ForeverUnitFramesDB,characterKey()
    local active=db and db.active and char and db.active[char]
    if V:IsSecret(active) or type(active)~="string" or not active:match("^vasagoio") then return end
    local profile=type(db.profiles)=="table" and db.profiles[active]
    if type(profile)=="table" then return profile,active end
end
local function px(value) return math.floor(V:Pixel(value) + 0.5) end
local function put(tableValue, values)
    for key, value in pairs(values) do tableValue[key] = copy(value) end
end
local function appearance(scope, scopeKey)
    put(scope, {
        fontFace = "Friz Quadrata", fontSize = px(T.typography.name.size), valueFontSize = px(T.typography.compact.size), fontOutline = "NONE",
        fontShadow = true, titleBackground = false, frameAlpha = 100,
        auraBorder = false,
        borderShow = false, borderPadding = 0, shadowEnabled = false, cornerRadius = 0,
        boxBorderShow = false, boxCornerRadius = 0, spacingFill = false, footerHeight = 0,
        healthColorMode = "STATIC", healthColor = rgb(T.colors.healthHigh), backgroundColor = rgb(T.colors.track, T.alpha.unit),
        healthMissingCustom = false, barTexture = "Flat", barVertical = false, barReverse = false,
        healthBarWidth = 100, powerBarWidth = 100, powerFill = "LEFT_TO_RIGHT", powerMatchesHealth = false,
        powerColorMode = "TYPE", titleColorMode = "CLASS", barNameColorMode = "CLASS",
        textHealthLeft = "NAME", textHealthCenter = "NONE", textHealthRight = "CURRENT",
        textPowerLeft = "NONE", textPowerCenter = "NONE", textPowerRight = "CURRENT",
        titlePercent = 0, spacingTitle = 0, spacingDocked = 0, spacingPower = px(2), spacingPortrait = px(2),
        portraitStyle = "2D", portraitSquare = true, portraitMirror = false,
        powerEnabled = true, castbarAlwaysShow = false,
    })
    if scopeKey ~= "pet" and scopeKey ~= "boss" then scope.titleClassIcon = false end
    if scopeKey ~= "player" and scopeKey ~= "pet" and scopeKey ~= "party" then scope.powerHideEmpty = true end
    for resource, color in pairs(design.resources) do scope["powerColor" .. resource] = rgb(color) end
    for _, group in ipairs({ "buffs", "debuffs" }) do
        scope[group .. "Size"], scope[group .. "OwnSize"] = px(T.aura.size), px(T.aura.size)
        scope[group .. "Spacing"], scope[group .. "RowGap"] = px(T.aura.gap), px(T.aura.wrapGap - T.aura.gap)
    end
end

local function size(scope, sizeName, side, x, y)
    local spec = design[sizeName]
    local gap = px(spec.gap)
    -- FUF adds the power gap to configured height. Percentages apply to the
    -- remaining rows; choose an integer yielding the exact snapped power row.
    local total = px(spec.height)
    local rows = total - gap
    local power = px(spec.power)
    scope.width, scope.height = px(spec.width), rows
    scope.spacingPower, scope.spacingPortrait = gap, gap
    scope.powerPercent = math.ceil(power * 100 / rows)
    scope.healthPercent = 100 - scope.powerPercent
    scope.portraitMode = side
    scope.x, scope.y = px(x + spec.width / 2 - 1280), px(720 - y - spec.height / 2)
end

local reloadPending
local adapter = {
    label = "Forever Unit Frames — vasagoio layout", addon = OWNER,
    AfterApply = function() reloadPending = true end,
    Prepare = function()
        if not versionOK() then return nil, "Requires audited Forever Unit Frames 0.79.1 or 0.81.0; other schemas need review." end
        -- The owner clamps integer settings during load. Validate the actual
        -- resulting dimensions, not an arbitrary monitor/UI-scale ratio.
        local scale = V:SafeNumber(V:Pixel(1))
        if not scale or scale <= 0 then return nil, "Unable to resolve a positive UI scale for FUF." end
        local bounds = {
            { "raid cell width", px(design.XS.width), 30, 200 },
            { "raid cell height", px(design.XS.height), 16, 100 },
            { "raid name font", px(T.typography.name.size), 6, 24 },
            { "raid amount font", px(T.typography.compact.size), 6, 24 },
            { "unit amount font", px(T.typography.amount.size), 6, 32 },
            { "party pet width", px(design.S.width), 0, 300 },
            { "party pet height", px(design.S.height), 10, 60 },
            { "standard/own aura size", px(T.aura.size), 10, 64 },
            { "dispel aura size", px(T.aura.prioritySize), 8, 64 },
            { "aura spacing", px(T.aura.gap), 0, 20 },
            { "additional aura row gap", px(T.aura.wrapGap - T.aura.gap), 0, 30 },
        }
        for _, sizeName in ipairs({ "L", "M", "S" }) do
            local s = design[sizeName]
            bounds[#bounds + 1] = { sizeName .. " unit width", px(s.width), 40, 600 }
            bounds[#bounds + 1] = { sizeName .. " unit row height", px(s.height) - px(s.gap), 8, 200 }
            bounds[#bounds + 1] = { sizeName .. " internal gap", px(s.gap), 0, 8 }
        end
        for _, bound in ipairs(bounds) do
            if bound[2] < bound[3] or bound[2] > bound[4] then
                return nil, ("FUF %s would be %d UI units; supported range is %d–%d. Adjust vasagoio layout scale or UI scale before setup."):format(unpack(bound))
            end
        end
        local db, char = ForeverUnitFramesDB, characterKey()
        if type(db) ~= "table" or type(db.profiles) ~= "table" or type(db.active) ~= "table"
            or type(db.raid) ~= "table" or not char then
            return nil, "Open a character with FUF enabled once, then reload before setup."
        end
        local active = db.active[char] or "Default"
        local old = db.profiles[active]
        if type(old) ~= "table" or type(db.raid[char]) ~= "table" then
            return nil, "FUF profile schema is not initialized; no settings were changed."
        end
        local profile = copy(old)
        profile.general = profile.general or {}
        put(profile.general, { unitFrames = true, theme = "CLASSIC", classColorsCustom = true })
        for class, color in pairs(design.classes) do profile.general["classColor" .. class] = rgb(color) end
        local scopes = { "player", "target", "pet", "targettarget", "party", "focus", "focustarget", "boss" }
        for _, key in ipairs(scopes) do profile[key] = profile[key] or {}; appearance(profile[key], key) end
        local left, right = T.action.x, T.action.x + T.action.width
        local top = T.action.petY - 84 - design.L.height
        local smallTop = top + (design.L.height - design.S.height) / 2
        size(profile.player, "L", "LEFT", left, top)
        size(profile.target, "L", "RIGHT", right - design.L.width, top)
        size(profile.pet, "S", "LEFT", left - 20 - design.S.width, smallTop)
        size(profile.targettarget, "S", "RIGHT", right + 20, smallTop)
        -- Auxiliary positions retain the owner's current choice; only size is unified.
        for _, key in ipairs({ "focus", "boss", "focustarget" }) do
            local oldX, oldY = profile[key].x, profile[key].y
            size(profile[key], key == "focustarget" and "S" or "M", "LEFT", 0, 0)
            profile[key].x, profile[key].y = oldX, oldY
        end
        size(profile.party, "M", "LEFT", 8, 8)
        -- FUF party x/y denote the entire five-member block centre.
        profile.party.x = px(8 + design.M.width / 2 - 1280)
        profile.party.y = px(720 - 8 - (5 * design.M.height + 4 * 12) / 2)
        put(profile.party, { enabled = true, partyOrientation = "VERTICAL", partyGrowReverse = false,
            partyGrowCenter = false, partySortRole = false, partyShowPlayer = true, partyHideInRaid = true,
            partySpacing = px(12), partyShowPets = true, partyPetLayout = "BESIDE", partyPetSide = "RIGHT",
            partyPetWidth = px(design.S.width), partyPetHeight = px(design.S.height), partyPetGap = px(12),
            partyPetsX = 0, partyPetsY = -px((design.M.height - design.S.height) / 2), partyPetTextLeft = "NAME", partyPetTextCenter = "NONE",
            partyPetTextRight = "CURRENT", castbarEnabled = false })
        -- Newer party grids also wrap attached pets/targets. The agreed layout
        -- remains one column of five members, with each pet beside its owner.
        if ownerVersion() == "0.81.0" then profile.party.partyPerLine = 5 end
        profile.party.dispelsSize, profile.party.dispelsSpacing, profile.party.dispelsRowGap = px(T.aura.prioritySize), px(T.aura.gap), px(T.aura.wrapGap - T.aura.gap)
        profile.player.valueFontSize, profile.target.valueFontSize = px(T.typography.amount.size), px(T.typography.amount.size)
        profile.player.buffsEnabled, profile.player.hideBlizzardAuras, profile.player.cancelBuffs = true, true, true
        -- The Classic preset otherwise retains an empty cast/threat row under
        -- the player frame. Keep actual casts; TinyThreat owns the threat meter.
        profile.player.threatBar = false
        for _, key in ipairs({ "player", "target", "pet", "targettarget" }) do profile[key].enabled = true end
        -- Never replace a profile that FUF may still flush from its private
        -- in-memory copy at logout. A fresh name survives that save safely.
        local index, name = 1, "vasagoio"
        while db.profiles[name] ~= nil do index = index + 1; name = "vasagoio " .. index end
        local changes = {
            { table = db.profiles, path = { "ForeverUnitFramesDB", "profiles" }, key = name, value = profile, label = "Create a separate vasagoio unit profile" },
            { table = db.active, path = { "ForeverUnitFramesDB", "active" }, key = char, value = name, label = "Select vasagoio unit profile after reload" },
        }
        local raid = db.raid[char]
        local general = copy(raid.general or {})
        put(general, { enabled = true, showInParty = false, cellTheme = "OWN", frameAlpha = 100 })
        changes[#changes + 1] = { table = raid, path = { "ForeverUnitFramesDB", "raid", char }, key = "general", value = general, label = "Raid appearance ownership" }
        for _, key in ipairs({ "r10", "r20", "r40" }) do
            local r = copy(raid[key] or {})
            put(r, { x = px(8 - 1280), y = px(720 - 8), groupBy = "GROUP", sortBy = "INDEX",
                blockDirection = "HORIZONTAL", blocksPerLine = 2, cellsPerLine = 5, cellGrowth = "DOWN",
                cellWidth = px(design.XS.width), cellHeight = px(design.XS.height), cellSpacing = px(6), blockSpacing = px(16),
                blockTitles = false, panelBorder = false, blockBorder = false, cellBorder = false,
                cellCornerRadius = 0, healthColorMode = "STATIC", healthColor = rgb(T.colors.healthHigh),
                backgroundColor = rgb(T.colors.track, T.alpha.unit), barTexture = "Flat", fillVertical = false,
                fillReverse = false, powerStrip = "ALL", powerStripHeight = math.ceil(100 * px(design.XS.power) / px(design.XS.height)), nameClassColor = true,
                nameFontSize = px(T.typography.name.size), secondFontSize = px(T.typography.compact.size), fontFace = "Friz Quadrata", fontOutline = "NONE",
                fontShadow = true, secondLine = "PERCENT", secondLineColor = rgb(T.colors.text) })
            if ownerVersion() == "0.81.0" then
                -- 0.81 exposes these colors per raid profile. Configure the
                -- owner directly as well as retaining the older runtime hook.
                r.healthMissingCustom, r.powerColorMode = false, "TYPE"
                for resource, color in pairs(design.resources) do r["powerColor" .. resource] = rgb(color) end
            end
            changes[#changes + 1] = { table = raid, path = { "ForeverUnitFramesDB", "raid", char }, key = key, value = r, label = "Two-column XS raid layout " .. key }
        end
        if not V.db or type(V.db.overrides)~="table" then return nil,"vasagoio settings are not initialized" end
        changes[#changes+1]={table=V.db.overrides,path={"VasagoioDB","overrides"},key="playerProgress",value=true,
            label="Enable compact player XP strip; restore full rows at maximum level"}
        return { changes = changes, detail = "Creates a new FUF profile; reload required. Keeps the 320x64 player frame while showing XP below power; normal rows return at maximum level. The adapter decorates existing party pet buttons and supplies 12×16 raid block spacing." }
    end,
}
V:RegisterProfileAdapter("unitframes", adapter)

local hooked = setmetatable({}, { __mode = "k" })
local partyPetDecor = setmetatable({}, { __mode = "k" })
local tintCurve, publicHooks
local powerColors = { [0] = rgb(design.resources.Mana), [1] = rgb(design.resources.Rage),
    [2] = rgb(design.resources.Focus), [3] = rgb(design.resources.Energy) }
local function running()
    return V.db and V.db.enabled ~= false and (not V.db.modules or V.db.modules.unitframes ~= false)
end
local function ordinaryUnit(frame)
    local unit = frame.unit
    if not V:IsSecret(unit) and type(unit) == "string" then return unit end
end
local function petData(frame, portraitChanged)
    local decor = partyPetDecor[frame]
    if not decor then return end
    if not running() then decor.portrait:Hide(); decor.resource:Hide(); return end
    local unit = ordinaryUnit(frame)
    if not unit then decor.portrait:Hide(); decor.resource:Hide(); return end
    local exists = UnitExists and UnitExists(unit)
    if not V:IsSecret(exists) and exists == false then
        decor.portrait:Hide(); decor.resource:Hide(); return
    end
    decor.portrait:Show(); decor.resource:Show()
    if portraitChanged and SetPortraitTexture then
        if decor.portrait.SetTexture then decor.portrait:SetTexture(nil) end
        pcall(SetPortraitTexture, decor.portrait, unit)
    end
    -- Native sinks handle restricted values without Lua arithmetic. The
    -- existing FUF button remains responsible for clicks and unit visibility.
    decor.resource:SetMinMaxValues(0, UnitPowerMax(unit))
    decor.resource:SetValue(UnitPower(unit))
    decor.amount:SetFormattedText("%d", UnitPower(unit))
    local kind = UnitPowerType and V:SafeNumber(UnitPowerType(unit))
    local c = kind and powerColors[kind]
    if c then decor.resource:SetStatusBarColor(c[1], c[2], c[3], T.alpha.unit)
    else decor.resource:SetStatusBarColor(0.35, 0.35, 0.35, T.alpha.unit) end
end
local function petLayout(frame)
    local decor = partyPetDecor[frame]
    if not decor or decor.layoutBusy or not running() then return end
    if InCombatLockdown and InCombatLockdown() then V:Refresh("party pet layout after combat", "unitframes"); return end
    decor.layoutBusy = true
    -- Decorate the same 192×32 secure button:32px picture,2px gap,
    --158px content; health22, gap2, resource8. No click-unit attributes change.
    decor.portrait:ClearAllPoints()
    decor.portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    local spec = design.S
    local inset, body = spec.portrait + spec.gap, spec.width - spec.portrait - spec.gap
    decor.portrait:SetSize(V:Pixel(spec.portrait), V:Pixel(spec.portrait))
    frame.health:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", V:Pixel(inset), 0)
    frame.health:SetSize(V:Pixel(body), V:Pixel(spec.health))
    decor.resource:ClearAllPoints()
    decor.resource:SetPoint("TOPLEFT", frame, "TOPLEFT", V:Pixel(inset), -V:Pixel(spec.health + spec.gap))
    decor.resource:SetSize(V:Pixel(body), V:Pixel(spec.power))
    decor.layoutBusy = false
end
local function stylePartyPet(frame)
    if frame.key ~= "partypet" or not frame.CreateTexture or not CreateFrame then return end
    local decor = partyPetDecor[frame]
    if not decor then
        decor = { portrait = frame:CreateTexture(nil, "ARTWORK"), resource = CreateFrame("StatusBar", nil, frame) }
        partyPetDecor[frame] = decor
        decor.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        decor.resource:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        decor.resource:EnableMouse(false)
        decor.resource:SetStatusBarColor(0.35, 0.35, 0.35, T.alpha.unit)
        decor.track = decor.resource:CreateTexture(nil, "BACKGROUND")
        decor.track:SetAllPoints(decor.resource)
        decor.track:SetColorTexture(T.colors.track[1], T.colors.track[2], T.colors.track[3], T.alpha.unit)
        decor.amount = decor.resource:CreateFontString(nil, "OVERLAY")
        decor.amount:SetPoint("RIGHT", decor.resource, "RIGHT", -V:Pixel(4), 0)
        if hooksecurefunc then
            for _, method in ipairs({ "SetPoint", "SetHeight", "SetWidth", "SetSize" }) do
                hooksecurefunc(frame.health, method, function() petLayout(frame) end)
            end
        end
    end
    petLayout(frame)
    V:StyleText(decor.amount, "compact")
    if V.MaskIcon then V:MaskIcon(decor.portrait, T.radius) end
    petData(frame, true)
end
local function updatePartyPets(portraitChanged)
    for frame in pairs(partyPetDecor) do petData(frame, portraitChanged) end
end
local function tint(frame)
    if not running() or not tintCurve or hooked[frame].painting then return end
    local unit = ordinaryUnit(frame)
    if not unit then return end
    -- The native color curve evaluates restricted HP. Lua neither reads nor
    -- compares its components: the result goes directly to the StatusBar.
    local ok, color = pcall(UnitHealthPercent, unit, true, tintCurve)
    if not ok or not color then return end
    hooked[frame].painting = true
    local good = pcall(function() frame.health:SetStatusBarColor(color:GetRGBA()) end)
    hooked[frame].painting = false
    return good
end
local function exact(frame, field, getter)
    local fs = frame.texts and frame.texts[field]
    if not fs or not fs.SetFormattedText or not getter then return end
    local function update()
        if not running() or V:IsSecret(frame.textWord) or frame.textWord then return end
        local unit = ordinaryUnit(frame)
        if unit then fs:SetFormattedText("%d", getter(unit)) end
    end
    hooksecurefunc(fs, "SetText", update)
    update()
end
local function tintRaidPower(frame)
    local state = hooked[frame]
    if not running() or state.paintingPower or not UnitPowerType then return end
    local unit = ordinaryUnit(frame)
    if not unit or V:IsSecret(frame.textWord) or frame.textWord then return end
    local kind = V:SafeNumber(UnitPowerType(unit))
    local c = kind and powerColors[kind]
    if not c then return end -- Keep the owner's color for a restricted/unknown type.
    state.paintingPower = true
    frame.power:SetStatusBarColor(c[1], c[2], c[3])
    state.paintingPower = false
end
local function style(frame)
    if not frame or not frame.health or not frame.health.SetStatusBarColor then return end
    V:Surface(frame, T.alpha.unit, T.radius)
    stylePartyPet(frame)
    if frame.key=="player" and V.StylePlayerProgress then V:StylePlayerProgress(frame) end
    if frame.key == "raid" and frame.texts then
        -- The owner's profile exposes two stacked text lines only. Re-anchor
        -- those same FontStrings; status rendering and click areas stay owned.
        local name, amount = frame.texts.healthLeft, frame.texts.healthRight
        if name and amount then
            name:ClearAllPoints(); name:SetPoint("LEFT", frame.health, "LEFT", V:Pixel(8), 0)
            name:SetWidth(V:Pixel(68)); name:SetJustifyH("LEFT")
            amount:ClearAllPoints(); amount:SetPoint("RIGHT", frame.health, "RIGHT", -V:Pixel(8), 0)
            amount:SetWidth(V:Pixel(40)); amount:SetJustifyH("RIGHT")
        end
    end
    if hooked[frame] or not hooksecurefunc then return end
    hooked[frame] = {}
    hooksecurefunc(frame.health, "SetStatusBarColor", function() tint(frame) end)
    tint(frame)
    if (frame.key == "raid" or frame.key == "raidpet") and frame.power and frame.power.SetStatusBarColor then
        hooksecurefunc(frame.power, "SetStatusBarColor", function() tintRaidPower(frame) end)
        tintRaidPower(frame)
    end
    -- Raid retains its compact percentages and owner status text. Only the
    -- current-value slots selected in our unit profile receive raw amounts.
    if frame.key ~= "raid" and frame.key ~= "raidpet" then
        exact(frame, "healthRight", UnitHealth)
        exact(frame, "powerRight", UnitPower)
    end
end
local function walk(frame, depth)
    if not frame or depth > 3 then return end
    style(frame)
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do walk(child, depth + 1) end
    end
end
V:RegisterModule("unitframes", {
    label = "Unit frames", defaultEnabled = true,
    description = "FUF-owned frames with neutral glass surfaces and a native health color curve.",
    Apply = function()
        if InCombatLockdown and InCombatLockdown() then return false, "Unit styling waits until combat ends." end
        if reloadPending then
            if V.DisablePlayerProgress then V:DisablePlayerProgress() end
            return false, "Reload to activate the newly selected FUF profile."
        end
        if not versionOK() or not ForeverUnitFrames then
            if V.DisablePlayerProgress then V:DisablePlayerProgress() end
            return false, "Audited FUF 0.79.1 or 0.81.0 is required."
        end
        if not V:GetReviewedUnitProfile() then
            if V.DisablePlayerProgress then V:DisablePlayerProgress() end
            return false, "Run setup to select the reviewed unit profile, then reload."
        end
        if not tintCurve and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor and UnitHealthPercent then
            tintCurve = C_CurveUtil.CreateColorCurve()
            tintCurve:AddPoint(0, CreateColor(T.colors.healthLow[1], T.colors.healthLow[2], T.colors.healthLow[3], T.alpha.unit))
            tintCurve:AddPoint(1, CreateColor(T.colors.healthHigh[1], T.colors.healthHigh[2], T.colors.healthHigh[3], T.alpha.unit))
        end
        if not publicHooks and hooksecurefunc then
            for _, api in ipairs({ "PartyButtonOnLoad", "PartyPetButtonOnLoad", "PartyPetBesideOnLoad", "RaidButtonOnLoad" }) do
                if type(ForeverUnitFrames[api]) == "function" then
                    hooksecurefunc(ForeverUnitFrames, api, function() V:Refresh("new FUF unit", "unitframes") end)
                end
            end
            if type(ForeverUnitFrames.PartyPetButtonOnAttributeChanged) == "function" then
                hooksecurefunc(ForeverUnitFrames, "PartyPetButtonOnAttributeChanged", function() updatePartyPets(true) end)
            end
            publicHooks = true
        end
        for _, key in ipairs({ "player", "target", "pet", "targettarget", "focus", "focustarget", "boss1", "boss2", "boss3", "boss4", "boss5" }) do
            style(_G["ForeverUnitFrames_" .. key])
        end
        walk(_G.ForeverUnitFramesParty, 0)
        walk(_G.ForeverUnitFramesPartyPets, 0)
        for i = 1, 8 do
            local block = _G["ForeverUnitFramesRaidBlock" .. i]
            if block then
                -- Existing secure group headers, out of combat. FUF still
                -- creates, filters, sorts and shows its own member buttons.
                block:ClearAllPoints()
                block:SetPoint("TOPLEFT", UIParent, "CENTER", V:Pixel(8 + ((i - 1) % 2) * (design.XS.width + 12) - 1280),
                    V:Pixel(720 - 8 - math.floor((i - 1) / 2) * (5 * design.XS.height + 4 * 6 + 16)))
                walk(block, 0)
            end
        end
        return true, tintCurve and "FUF surfaces, party pet portrait/resources and native HP curve active; native validation remains pending."
            or "FUF surfaces active; HP curve unavailable on this client (solid dark fallback)."
    end,
    Disable = function()
        if V.DisablePlayerProgress then V:DisablePlayerProgress() end
        for _, decor in pairs(partyPetDecor) do decor.portrait:Hide(); decor.resource:Hide() end
    end,
})
V:On("GROUP_ROSTER_UPDATE", function() V:Refresh("unit roster changed", "unitframes") end)
for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
    V:On(event, function() updatePartyPets(false) end)
end
for _, event in ipairs({ "UNIT_PORTRAIT_UPDATE", "UNIT_PET" }) do
    V:On(event, function() updatePartyPets(true) end)
end
