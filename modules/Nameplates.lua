local addonName, V = ...

-- Threat Plates is the sole nameplate owner. The profile supplies geometry
-- and colors; the owner's restriction-aware widgets supply health and threat.
local OWNER, VERSION = "TidyPlates_ThreatPlates", "13.3.9"
local T = V.Tokens
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
local reloadPending
V:RegisterProfileAdapter("nameplates", {
    label = "Threat Plates — vasagoio nameplates", addon = OWNER,
    AfterApply = function() reloadPending = true end,
    Prepare = function()
        if not versionOK() then return nil, "Requires audited Threat Plates 13.3.9; newer schemas need review." end
        local target, oldName, char = currentProfile()
        if not target then return nil, "Threat Plates profile is not initialized; enable it and reload before setup." end
        local profile = copy(target)
        local settings = ensure(profile, "settings")
        local health = ensure(settings, "healthbar")
        health.width, health.widthFriend = px(T.nameplate.width), px(T.nameplate.width)
        health.height, health.heightFriend = px(T.nameplate.health), px(T.nameplate.health)
        health.texture, health.backdrop = "Blizzard", "Blizzard"
        -- Use the owner's flat statusbar media when available. The guaranteed
        -- native fallback above is not redistributed by vasagoio.
        if LibStub then
            local media = LibStub("LibSharedMedia-3.0", true)
            if media and media:Fetch("statusbar", "Flat", true) then health.texture, health.backdrop = "Flat", "Flat" end
        end
        ensure(settings, "healthborder").show = false
        ensure(settings, "elitehealthborder").show = false
        ensure(settings, "threatborder").show = false
        local cast = ensure(settings, "castbar")
        cast.width, cast.height, cast.x, cast.y, cast.show = px(T.nameplate.width), px(T.nameplate.cast), 0,
            -px(T.nameplate.health / 2 + T.nameplate.castGap + T.nameplate.cast / 2), true
        cast.texture, cast.backdrop = health.texture, health.backdrop
        cast.BackgroundOpacity, cast.BackgroundColor = T.alpha.unit, color(T.colors.track)
        ensure(settings, "castborder").show = false
        local spelltext = ensure(settings, "spelltext")
        spelltext.typeface, spelltext.size, spelltext.flags, spelltext.shadow = "Friz Quadrata TT", px(T.typography.compact.size), "", true
        spelltext.width, spelltext.height = px(T.nameplate.width), px(T.nameplate.cast)
        local background = ensure(profile, "Healthbar")
        background.BackgroundUseForegroundColor, background.BackgroundOpacity = false, T.alpha.unit
        background.BackgroundColor, background.UseRaidMarkColoring = color(T.colors.track), false
        local classes = ensure(ensure(profile, "Colors"), "Classes")
        for class, hex in pairs(V.UnitDesign and V.UnitDesign.classes or {}) do
            classes[class] = color(hex)
            local c = classes[class]
            c.colorStr = string.format("ff%02x%02x%02x", math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
        end
        -- Reaction/class handling remains the owner's policy outside valid
        -- hostile-NPC threat contexts; never paint friendly players as danger.
        local colors = { dps = { LOW = T.colors.informationFill, MEDIUM = T.colors.attentionFill, HIGH = T.colors.dangerFill },
            tank = { LOW = T.colors.dangerFill, MEDIUM = T.colors.attentionFill, HIGH = T.colors.informationFill, OFFTANK = T.colors.dangerFill } }
        for role, values in pairs(colors) do
            local entries = ensure(ensure(settings, role), "threatcolor")
            for level, value in pairs(values) do entries[level] = color(value) end
        end
        local threat = ensure(profile, "threat")
        threat.UseThreatTable, threat.UseHeuristicInInstances, threat.useType = true, false, true
        threat.useHPColor, threat.useScale = true, false
        ensure(threat, "art").ON = false
        local toggle = ensure(threat, "toggle")
        toggle.OffTank = false
        for _, kind in ipairs({ "Boss", "Elite", "Normal", "Neutral", "Minus", "Tapped" }) do toggle[kind] = true end
        profile.optionRoleDetectionAutomatic = true
        local text = ensure(profile, "text")
        text.amount, text.full, text.percent, text.max, text.deficit, text.truncate = true, true, false, false, false, false
        local status = ensure(ensure(profile, "StatusText"), "HealthbarMode")
        status.FriendlySubtext, status.EnemySubtext = "HEALTH", "HEALTH"
        status.Anchor, status.InsideAnchor = "RIGHT", true
        status.HorizontalOffset, status.VerticalOffset = -px(8), 0
        status.SubtextColorUseSpecific, status.SubtextColor = true, color(T.colors.text)
        font(ensure(status, "Font"), T.nameplate.amountSize, 80)
        status.Font.HorizontalAlignment, status.Font.Height = "RIGHT", px(20)
        local title = ensure(ensure(profile, "Name"), "HealthbarMode")
        title.Enabled, title.HorizontalOffset, title.VerticalOffset = true, -px(44), 0
        title.FriendlyUnitMode, title.EnemyUnitMode = "CLASS", "CLASS"
        font(ensure(title, "Font"), T.typography.name.size, T.nameplate.width - 104)
        title.Font.Height, title.Font.HorizontalAlignment = px(T.nameplate.health), "LEFT"
        local aura = ensure(profile, "AuraWidget")
        aura.ShowCooldownSpiral = true
        for _, group in ipairs({ "Buffs", "Debuffs", "CrowdControl" }) do
            local groupSettings = ensure(aura, group)
            local icons = ensure(groupSettings, "ModeIcon")
            icons.Style, icons.IconWidth, icons.IconHeight, icons.ShowBorder = "square", px(T.nameplate.aura), px(T.nameplate.aura), false
            icons.ColumnSpacing, icons.RowSpacing = px(T.aura.gap), px(T.aura.wrapGap)
        end
        -- One aura row above health and the cast below it form the 84px
        -- reference envelope. Additional owner-filtered aura rows can grow.
        local debuffs = aura.Debuffs
        debuffs.AnchorTo = "Healthbar"
        local anchor = ensure(debuffs, "HealthbarMode")
        anchor.Anchor, anchor.InsideAnchor, anchor.VerticalOffset = "TOP", false, px(T.nameplate.auraGap)
        ensure(profile, "Scale").IgnoreUIScale = false
        ensure(profile, "Appearance").UseBorderlessIcons = true
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
        return { changes = changes, detail = "192×24 health, 16px cast with 8px gap, exact HP, 28px auras, and native role-aware blue/amber/red. Reload required; custom nameplate overrides remain owner-controlled." }
    end,
})
V:RegisterModule("nameplates", {
    label = "Nameplates", defaultEnabled = true,
    description = "Audited Threat Plates profile; no competing combat renderer.",
    Apply = function()
        if not versionOK() then return false, "Audited Threat Plates 13.3.9 is required." end
        if reloadPending then return false, "Reload to activate the newly selected nameplate profile.", "pending" end
        local profile = currentProfile()
        if not profile then return false, "Initialize Threat Plates, then run setup." end
        local health = profile.settings and profile.settings.healthbar
        local text = profile.text
        if not health or health.width ~= px(T.nameplate.width) or health.height ~= px(T.nameplate.health)
            or not text or not text.amount or text.percent or text.truncate then
            return false, "Nameplate setup has not been applied, or the owner profile was changed.", "pending"
        end
        return true, "Reviewed Threat Plates dimensions and exact-HP settings are configured; native validation pending."
    end,
})
