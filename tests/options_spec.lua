local root = (arg and arg[1]) or "."
local combat = false
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
InCombatLockdown = function() return combat end
SlashCmdList = {}
local V = {}
for _, file in ipairs({"Core.lua", "Tokens.lua", "core/Database.lua", "core/Options.lua"}) do
    assert(loadfile(root .. "/" .. file))("vasagoio", V)
end
local text = V:ReviewText({
    adapters = {{id = "test", label = "Reviewed owner", detail = "Changes appearance"}}, unavailable = {},
    changes = {
        {adapter = "test", label = "Width", before = 100, after = 320},
        {adapter = "test", label = "Enabled", before = false, after = true},
        {adapter = "test", label = "Font", before = "|cffffffffunsafe|r", after = "native"},
        {adapter = "test", label = "Profile", before = nil, after = {width = 320, height = 64, PrivateCharacterRealm = "do not render"}},
    },
})
assert(text:find("4 reviewed fields across 1 adapters", 1, true))
assert(text:find("Width: 100 → 320", 1, true))
assert(text:find("Enabled: off → on", 1, true))
assert(text:find("||cffffffffunsafe||r", 1, true), "WoW markup not escaped")
assert(text:find("3 fields: height, width", 1, true), "Table keys not summarized")
assert(not text:find("PrivateCharacterRealm", 1, true), "Private table key exposed")
assert(not text:find("do not render", 1, true), "Nested profile content exposed")

V:InitializeDatabase()
V.ready = true
local applications, cleanups = 0, 0
V:RegisterModule("lifecycle", {
    Apply = function() applications = applications + 1; return true end,
    Disable = function() cleanups = cleanups + 1 end,
})
V:ApplyModules()
assert(applications == 1)
combat = true
V.db.modules.lifecycle = false
V:ApplyModules()
assert(cleanups == 0 and V.pending, "Cleanup occurred in combat")
combat = false
V:ApplyModules(); V:ApplyModules()
assert(cleanups == 1, "Disable cleanup must run once per active period")
V:RegisterModule("partial", {
    Apply = function() error("simulated partial Apply") end,
    Disable = function() cleanups = cleanups + 1 end,
})
V:ApplyModules()
V.db.modules.partial = false
V:ApplyModules()
assert(cleanups == 2, "Partially applied module was not cleaned up")
print("options_spec: safe before/after review, table privacy and module cleanup lifecycle passed")
