local root = (arg and arg[1]) or "."
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
InCombatLockdown = function() return false end
local V = {}
for _, file in ipairs({"Core.lua", "Tokens.lua", "core/Database.lua", "core/Profiles.lua"}) do
    assert(loadfile(root .. "/" .. file))("vasagoio", V)
end
V:InitializeDatabase()
SetupModuleFixture = {width = 100}
local calls = 0
V:RegisterModule("unitframes", {defaultEnabled = true, Apply = function() return true end})
V:RegisterProfileAdapter("unitframes", {Prepare = function()
    calls = calls + 1
    return {changes = {{table = SetupModuleFixture, path = {"SetupModuleFixture"}, key = "width", value = 320}}}
end})
V.db.modules.unitframes = false
local review = assert(V:PrepareSetup())
assert(calls == 0 and #review.changes == 0 and #review.unavailable == 1, "Disabled module was prepared")
V.db.modules.unitframes = true
review = assert(V:PrepareSetup())
assert(calls == 1 and #review.changes == 1)
V.db.modules.unitframes = false
assert(V:ApplySetup(review) == false, "Module disabled after review still applied")
assert(SetupModuleFixture.width == 100 and #V.db.profileBackups == 0, "Rejected review performed writes")
V:RegisterProfileAdapter("custom", {module = "unitframes", Prepare = function() error("Disabled custom mapping must skip Prepare") end})
review = assert(V:PrepareSetup())
assert(#review.changes == 0 and #review.unavailable == 2, "Explicit module mapping ignored")
-- Switching the selected owner profile must invalidate a review even though
-- every value in the previously selected profile remains unchanged.
ProfileSelectionFixture = {profiles = {A = {width = 100}, B = {width = 100}}}
local selected, proposed, reverse = "A", 320, false
V:RegisterProfileAdapter("selection", {Prepare = function()
    local target = ProfileSelectionFixture.profiles[selected]
    local changes = {
        {table = target, path = {"ProfileSelectionFixture", "profiles", selected}, key = "width", value = proposed},
        {table = target, path = {"ProfileSelectionFixture", "profiles", selected}, key = "height", value = 64},
    }
    if reverse then changes[1], changes[2] = changes[2], changes[1] end
    return {changes = changes}
end})
review = assert(V:PrepareSetup())
selected = "B"
assert(V:ApplySetup(review) == false, "Active owner profile changed without invalidating review")
assert(ProfileSelectionFixture.profiles.A.width == 100 and ProfileSelectionFixture.profiles.B.width == 100)
selected = "A"
review = assert(V:PrepareSetup())
proposed = 640
assert(V:ApplySetup(review) == false, "Changed scale-derived proposal applied without review")
proposed = 320
review = assert(V:PrepareSetup())
reverse = true
assert(V:ApplySetup(review) == true, "Equivalent reordered proposal was rejected")
assert(ProfileSelectionFixture.profiles.A.width == 320 and ProfileSelectionFixture.profiles.A.height == 64)
print("setup_modules_spec: disabled modules excluded and stale enabled state rejected before writes")
