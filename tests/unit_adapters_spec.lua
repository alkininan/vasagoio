-- Run from the repository root with Lua 5.1 or newer.
local adapters, modules, events = {}, {}, {}
local secret = setmetatable({}, {
    __add = function() error("secret arithmetic") end,
    __lt = function() error("secret comparison") end,
    __concat = function() error("secret concatenation") end,
    __tostring = function() error("secret formatting") end,
})
local versions = { ForeverUnitFrames = "0.79.1", TidyPlates_ThreatPlates = "13.3.9" }
C_AddOns = { GetAddOnMetadata = function(name) return versions[name] end }
UnitFullName = function() return "Example", "TestRealm" end
UnitNameUnmodified = function() return "Example", "Surname" end
GetRealmName = function() return "Test Realm" end
GetNormalizedRealmName = function() return "TestRealm" end
RegionalUniqueNamesEnabled = function() return false end
UnitHealth, UnitPower = function() return secret end, function() return secret end
UIParent = {}
local V = { db = { enabled = true, modules = {} } }
function V:RegisterProfileAdapter(id, adapter) adapters[id] = adapter end
function V:RegisterModule(id, module) modules[id] = module end
function V:On(event, fn) events[event] = fn end
function V:Refresh() end
function V:IsSecret(value) return value == secret end
function V:SafeNumber(value) if not self:IsSecret(value) and type(value) == "number" then return value end end
function V:Pixel(value) return value end
function V:Surface(frame) frame.surfaceApplied = true end
local function clone(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do result[k] = clone(v) end
    return result
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
ForeverUnitFramesDB = {
    profiles = { Default = { general = {}, party = { partySortRole = true }, target = { keepUserBehavior = true } } },
    active = { ["Example-TestRealm"] = "Default" },
    raid = { ["Example-TestRealm"] = { general = { raidClickBinding = "preserved" }, r40 = { customValue = 42 } } },
}
ThreatPlatesDB = { profileKeys = { ["Example - Test Realm"] = "Default" }, profiles = {
    Default = { uniqueSettings = { SpecialUnit = { custom = true } }, text = { AbsorbsAmount = true } },
} }
assert(loadfile("Tokens.lua"))("vasagoio", V)
assert(loadfile("modules/UnitFrames.lua"))("vasagoio", V)
assert(loadfile("modules/Nameplates.lua"))("vasagoio", V)

local function applyPlan(plan)
    for _, change in ipairs(plan.changes) do
        assert(type(change.path) == "table", "rollback path missing")
        local target = _G
        for _, key in ipairs(change.path) do target = target[key] end
        assert(target == change.table, "rollback path does not match mutation target")
        target[change.key] = clone(change.value)
    end
end

-- Preview is read-only, preserves user behavior, and creates a fresh profile
-- so FUF's delayed flush cannot overwrite the proposed appearance.
local before = clone(ForeverUnitFramesDB)
local unitPlan = assert(adapters.unitframes:Prepare())
assert(same(before, ForeverUnitFramesDB), "preparing unit plan wrote to owner data")
local profile = unitPlan.changes[1].value
assert(profile.target.keepUserBehavior)
assert(profile.player.width == 320 and profile.player.height + profile.player.spacingPower == 64)
assert(math.floor(profile.player.height * profile.player.powerPercent / 100) == 16)
assert(math.floor(profile.party.height * profile.party.powerPercent / 100) == 12)
assert(math.floor(profile.pet.height * profile.pet.powerPercent / 100) == 8)
assert(profile.player.x == -236 and profile.player.y == -410)
assert(profile.target.x + 1280 + 160 == 1676)
assert(profile.player.portraitMode == "LEFT" and profile.target.portraitMode == "RIGHT")
assert(profile.party.partyPetWidth == 192 and profile.party.partyPetsY == -8)
assert(profile.party.partyShowPets and profile.party.partyPetLayout == "BESIDE")
assert(profile.party.partyPetTextRight == "CURRENT")
assert(profile.player.cornerRadius == 0 and profile.player.boxCornerRadius == 0)
assert(profile.player.titleBackground == false and profile.player.frameAlpha == 100)
applyPlan(unitPlan)
assert(ForeverUnitFramesDB.raid["Example-TestRealm"].r40.customValue == 42)
assert(ForeverUnitFramesDB.raid["Example-TestRealm"].r40.blocksPerLine == 2)
assert(ForeverUnitFramesDB.raid["Example-TestRealm"].r40.blockTitles == false)
assert(adapters.unitframes:Prepare().changes[1].key == "vasagoio 2")

before = clone(ThreatPlatesDB)
local namePlan = assert(adapters.nameplates:Prepare())
assert(same(before, ThreatPlatesDB), "preparing nameplates wrote to owner data")
assert(modules.nameplates:Apply() == false, "unconfigured nameplates reported applied")
applyPlan(namePlan)
assert(same(before.profiles.Default, ThreatPlatesDB.profiles.Default), "live AceDB profile was replaced")
profile = ThreatPlatesDB.profiles[ThreatPlatesDB.profileKeys["Example - Test Realm"]]
assert(profile.uniqueSettings.SpecialUnit.custom and profile.text.AbsorbsAmount)
assert(profile.settings.healthbar.width == 192 and profile.settings.healthbar.height == 24)
assert(profile.settings.castbar.height == 16 and profile.settings.castbar.y == -28)
assert(profile.text.amount and profile.text.full and not profile.text.truncate and not profile.text.percent)
assert(profile.settings.dps.threatcolor.LOW.b == 137 / 255)
assert(profile.settings.tank.threatcolor.HIGH.b == 137 / 255)
assert(profile.settings.tank.threatcolor.LOW.r == 139 / 255)
assert(profile.settings.dps.threatcolor.MEDIUM.r == 134 / 255)
assert(profile.threat.UseHeuristicInInstances == false and profile.threat.toggle.OffTank == false)
RegionalUniqueNamesEnabled = function() return true end
ThreatPlatesDB.profileKeys["Example Surname"] = "Default"
ThreatPlatesDB.namespaces = { ["LibDualSpec-1.0"] = { char = { ["Example Surname"] = { enabled = true, [1] = "Default", [2] = "Raid" } } } }
local regionalPlan = assert(adapters.nameplates:Prepare(), "Forever regional identity was not handled")
applyPlan(regionalPlan)
local specBindings = ThreatPlatesDB.namespaces["LibDualSpec-1.0"].char["Example Surname"]
assert(specBindings[1] == "vasagoio 2" and specBindings[2] == "Raid", "dual-spec profile choices were not preserved")
assert(modules.nameplates:Apply())

-- Unknown versions, missing state and restricted identities never produce a
-- write plan. Tests do not load or modify any installed addon data.
versions.ForeverUnitFrames = "future"
assert(adapters.unitframes:Prepare() == nil)
versions.ForeverUnitFrames = "0.79.1"
local normalPixel = V.Pixel
function V:Pixel(n) return n * 2 end
assert(adapters.unitframes:Prepare() == nil, "owner-clamped scale produced an invalid snapshot")
function V:Pixel(n) return n * 0.4 end
assert(adapters.unitframes:Prepare() == nil, "below-minimum raid dimensions were accepted")
V.Pixel = normalPixel
versions.TidyPlates_ThreatPlates = "future"
assert(adapters.nameplates:Prepare() == nil)
versions.TidyPlates_ThreatPlates = "13.3.9"
UnitNameUnmodified = function() return secret end
assert(adapters.nameplates:Prepare() == nil)
UnitNameUnmodified = function() return "Example", "Surname" end

-- Native rendering receives opaque HP and color components unchanged. The
-- callback never formats, compares or derives these values in Lua.
function hooksecurefunc(obj, method, callback)
    local old = obj[method]
    obj[method] = function(self, ...)
        old(self, ...)
        callback(self, ...)
    end
end
local function text()
    return {
        SetText = function(self, value) self.text = value end,
        SetFormattedText = function(self, fmt, value) self.format, self.value = fmt, value end,
    }
end
local frame = { unit = "player", key = "player", textWord = false, texts = { healthRight = text(), powerRight = text() } }
frame.health = { SetStatusBarColor = function(self, ...) self.colors = { ... } end }
ForeverUnitFrames_player = frame
ForeverUnitFrames = {}
CreateColor = function(...) return { ... } end
C_CurveUtil = { CreateColorCurve = function() return { AddPoint = function() end } end }
UnitHealthPercent = function()
    return { GetRGBA = function() return secret, secret, secret, secret end }
end
assert(modules.unitframes:Apply())
assert(frame.surfaceApplied and frame.health.colors[1] == secret)
assert(frame.texts.healthRight.value == secret and frame.texts.healthRight.format == "%d")
frame.textWord = "Offline"
frame.texts.healthRight.value = nil
frame.texts.healthRight:SetText("Offline")
assert(frame.texts.healthRight.value == nil, "owner offline status was replaced")
V.db.enabled = false
frame.textWord = false
frame.texts.healthRight:SetText("owner")
assert(frame.texts.healthRight.value == nil, "disabled hook still changed text")
-- Party pets decorate the existing owner button. No secure button, unit
-- attribute, tooltip or aura is replaced. All geometry remains out of combat.
V.db.enabled = true
local refreshes, portraitUnit, createdBars = 0, nil, {}
function V:Refresh() refreshes = refreshes + 1 end
function V:StyleText(fs, role) fs.styleRole = role end
local function region()
    return {
        ClearAllPoints = function(self) self.points = {} end,
        SetPoint = function(self, ...) self.point = { ... } end,
        SetSize = function(self, w, h) self.width, self.height = w, h; self.resizes = (self.resizes or 0) + 1 end,
        SetWidth = function(self, w) self.width = w end,
        SetHeight = function(self, h) self.height = h end,
        SetTexCoord = function() end,
        SetStatusBarTexture = function() end,
        SetStatusBarColor = function(self, ...) self.colors = { ... } end,
        SetColorTexture = function() end,
        SetAllPoints = function() end,
        EnableMouse = function(self, enabled) self.mouse = enabled end,
        Hide = function(self) self.shown = false end,
        Show = function(self) self.shown = true end,
        SetMinMaxValues = function(self, minimum, maximum) self.minimum, self.maximum = minimum, maximum end,
        SetValue = function(self, value) self.value = value; self.updates = (self.updates or 0) + 1 end,
        SetText = function(self, value) self.text = value end,
        SetFormattedText = function(self, fmt, value) self.format, self.number = fmt, value end,
    }
end
CreateFrame = function(kind)
    local widget = region()
    widget.CreateTexture = function() return region() end
    widget.CreateFontString = function() return region() end
    if kind == "StatusBar" then createdBars[#createdBars + 1] = widget end
    return widget
end
local pet = { unit = "partypet1", key = "partypet", textWord = false, health = region(),
    texts = { healthRight = text(), powerRight = text() }, auraMarker = {}, tooltipMarker = {} }
pet.CreateTexture = function(self)
    local picture = region(); self.decorativePortrait = picture; return picture
end
ForeverUnitFramesParty = { GetChildren = function() return pet end }
local exists, combat = true, false
UnitExists = function() return exists end
UnitPowerMax = function() return secret end
UnitPowerType = function() return secret end
SetPortraitTexture = function(texture, unit) portraitUnit = unit end
InCombatLockdown = function() return combat end
local auraMarker, tooltipMarker = pet.auraMarker, pet.tooltipMarker
assert(modules.unitframes:Apply())
local resource = createdBars[#createdBars]
assert(resource and resource.width == 158 and resource.height == 8)
assert(pet.health.width == 158 and pet.health.height == 22)
assert(pet.decorativePortrait.width == 32 and pet.decorativePortrait.height == 32)
assert(pet.health.point[4] - pet.decorativePortrait.width == 2)
assert(-resource.point[5] - pet.health.height == 2)
assert(resource.point[4] == 34 and resource.point[5] == -24)
assert(resource.minimum == 0 and resource.maximum == secret and resource.value == secret)
assert(resource.mouse == false and portraitUnit == "partypet1")
assert(pet.unit == "partypet1" and pet.auraMarker == auraMarker and pet.tooltipMarker == tooltipMarker)
local updates = resource.updates
events.UNIT_POWER_FREQUENT("UNIT_POWER_FREQUENT", secret)
assert(resource.updates == updates + 1, "native resource event did not update existing pet")
pet.unit = nil
events.UNIT_PET("UNIT_PET", secret)
assert(not resource.shown and not pet.decorativePortrait.shown)
assert(resource.updates == updates + 1, "nil pet still queried resources")
pet.unit, exists = "partypet1", false
events.UNIT_PET("UNIT_PET", secret)
assert(not resource.shown and resource.updates == updates + 1)
exists = secret
events.UNIT_PORTRAIT_UPDATE("UNIT_PORTRAIT_UPDATE", secret)
assert(resource.shown, "restricted existence was incorrectly inferred as absent")
combat = true
local beforeResize = pet.health.resizes
pet.health:SetSize(192, 32) -- owner changed its widget; our hook must only queue
assert(pet.health.resizes == beforeResize + 1 and refreshes > 0)
assert(modules.unitframes:Apply() == false, "combat apply changed geometry")
combat, exists = false, true
assert(modules.unitframes:Apply())
assert(pet.health.width == 158 and pet.health.height == 22)
modules.unitframes:Disable()
assert(not resource.shown and not pet.decorativePortrait.shown)
adapters.unitframes:AfterApply()
assert(modules.unitframes:Apply() == false, "new saved profile styled old live owner before reload")
print("unit/nameplate adapter tests passed")
