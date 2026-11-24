local root = (arg and arg[1]) or "."
local combat, queue, errors = false, {}, {}
UIParent = {GetWidth = function() return 2560 end, GetHeight = function() return 1440 end}
CreateFrame = function()
    return {RegisterEvent = function() end, SetScript = function(self, _, fn) self.dispatch = fn end}
end
InCombatLockdown = function() return combat end
C_Timer = {After = function(_, fn) queue[#queue+1] = fn end}
geterrorhandler = function() return function(err) errors[#errors+1] = err end end
local secret = setmetatable({}, {__tostring = function() error("Secret formatted") end,
    __lt = function() error("Secret compared") end, __eq = function() error("Secret compared") end})
issecretvalue = function(v) return rawequal(v, secret) end
local V = {}
for _, file in ipairs({"Core.lua", "Tokens.lua", "core/Database.lua", "core/Profiles.lua"}) do
    assert(loadfile(root .. "/" .. file))("vasagoio", V)
end
local function flush()
    local old = queue; queue = {}
    for _, fn in ipairs(old) do fn() end
end
local function eq(a, b, label) assert(a == b, label or "Unexpected value") end
V:InitializeDatabase()
eq(V.db.schemaVersion, 1)
eq(V:SafeNumber(secret), nil, "Secret value escaped numeric guard")
eq(V:SafeNumber(0/0), nil)
eq(V:SafeNumber(math.huge), nil)
eq(V:SafeNumber(0), 0)
eq(pcall(V.Copy, V, secret), false, "Secret serialized")
local cyclic = {}; cyclic.self = cyclic
eq(pcall(V.Copy, V, cyclic), false)

TestOwner = {profiles = {Example = {width = 100, colors = {.1,.2,.3}, explicit = false}}}
local target = TestOwner.profiles.Example
V:RegisterProfileAdapter("test", {label = "Test owner", Prepare = function()
    return {detail = "Resize and recolor", changes = {
        {table = target, path = {"TestOwner","profiles","Example"}, key = "width", value = 320, label = "Width"},
        {table = target, path = {"TestOwner","profiles","Example"}, key = "colors", value = {.3,.4,.5}, label = "Colors"},
        {table = target, path = {"TestOwner","profiles","Example"}, key = "explicit", value = true},
        {table = target, path = {"TestOwner","profiles","Example"}, key = "added", value = "new"},
    }}
end})
V:RegisterProfileAdapter("unavailable", {Prepare = function() return nil, "Not installed" end})
local review = assert(V:PrepareSetup())
eq(target.width, 100, "Review mutated profile")
eq(#review.unavailable, 1)
target.width = 101
eq(V:ApplySetup(review), false, "Stale review applied")
eq(target.colors[1], .1, "Partial write after stale precondition")
target.width = 100
review = assert(V:PrepareSetup())
combat = true
eq(V:ApplySetup(review), false, "Setup wrote in combat")
eq(target.width, 100)
combat = false
eq(V:ApplySetup(review), true)
eq(target.width, 320)
eq(#V.db.profileBackups, 1)
eq(V.profileReloadPending, true, "Profile application did not require reload")
eq(V:PrepareSetup(), nil, "Second setup allowed before owner reload")
eq(V:ApplySetup(review), false, "Review replayed")
-- Simulate an owner reconstructing its table after /reload.
TestOwner = V:Copy(TestOwner); target = TestOwner.profiles.Example
target.width = 321
eq(V:RollbackProfiles(), false, "Rollback overwrote later user edit")
eq(target.colors[1], .3, "Rollback partially wrote before conflict")
target.width = 320
eq(V:RollbackProfiles(), true)
eq(target.width, 100)
eq(target.explicit, false, "False lost from snapshot")
eq(target.added, nil, "Absent key not restored")
eq(target.colors[1], .1)
eq(V.profileReloadPending, true, "Profile restoration did not require reload")
-- Begin an independent runtime lifecycle, as after a UI reload.
V.profileReloadPending = false

local calls, cleanups = 0, 0
V:RegisterModule("good", {Apply = function() calls = calls + 1; return true, "Applied" end,
    Disable = function() cleanups = cleanups + 1 end})
V:RegisterModule("bad", {Apply = function() error("Expected fixture fault") end})
V:RegisterModule("afterBad", {Apply = function() calls = calls + 1; return true end})
V.ready = true
combat = true
V:Refresh(); V:Refresh(); flush()
eq(calls, 0, "Module ran in combat")
eq(V.pending, true)
combat = false
V.events.dispatch(nil, "PLAYER_REGEN_ENABLED"); flush()
eq(calls, 2, "Deferred modules did not resume")
eq(V.status.bad.state, "error", "Module failure was not isolated")
V.profileReloadPending = true
V:ApplyModules()
eq(calls, 2, "Reload-pending module applied against stale owner state")
eq(V.status.good.state, "pending")
V.db.modules.good = false
V:ApplyModules()
eq(V.status.good.state, "disabled")
eq(cleanups, 1, "Reload-pending state blocked disable cleanup")
V:ApplyModules()
eq(cleanups, 1, "Disable cleanup was repeated")
local previous = calls
V.db.enabled = false
V:ApplyModules()
eq(calls, previous, "Disabled addon changed frames")

VasagoioDB = {schemaVersion = 99, protected = "keep", enabled = true}
V:InitializeDatabase()
eq(V.readOnly, true)
eq(VasagoioDB.protected, "keep")
eq(VasagoioDB.enabled, true, "Downgrade mutated newer settings")
eq(V:PrepareSetup(), nil)

local t = V.Tokens
eq(t.hud.mapWidth + t.hud.splitGap + t.hud.meterWidth, t.hud.chatWidth, "HUD width relationship")
eq(t.action.columns * t.action.size + (t.action.columns - 1) * t.action.gap, t.action.width)
eq(t.action.petCount * t.action.petSize + (t.action.petCount - 1) * t.action.gap, t.action.petWidth)
eq(8 * t.action.size + 7 * t.action.gap, t.action.petWidth, "Pet bar endpoint alignment")
eq(3 * t.action.size + 2 * t.action.gap + t.action.rowGap + t.action.petSize, t.hud.height)
for _, spec in pairs(t.units) do eq(spec.health + spec.power + spec.gap, spec.height, "Unit anatomy") end
print("core_spec: settings, secrets, review, combat, persistent rollback, conflict protection, isolation and geometry passed")
