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
V.runtimeStats = {modules = {
    lifecycle = {calls=4, errors=0, timedCalls=4, totalMs=8, maxMs=3},
    partial = {calls=1, errors=1, timedCalls=0, totalMs=0, maxMs=0},
}}
local perf = V:PerformanceText()
assert(perf:find("not FPS or total addon CPU",1,true))
assert(perf:find("4 calls; 0 errors; 8.00 ms total; 2.00 ms average; 3.00 ms max",1,true))
assert(perf:find("1 calls; 1 errors; Timing unavailable",1,true))
local opened
V.OpenOptions=function(_,mode) opened=mode end
SlashCmdList.VASAGOIO("perf")
assert(opened=="perf", "Performance command did not select diagnostics")
local restored=0
V.Print=function() end
V.RollbackProfiles=function() restored=restored+1; return true,"Restored" end
SlashCmdList.VASAGOIO("restore")
assert(restored==0,"Restore instructions changed settings without explicit confirmation")
SlashCmdList.VASAGOIO("restore confirm")
assert(restored==1,"Confirmed restore command did not use the existing recovery engine")
local auraArgument, auraHides
V.AuraProbeCommand=function(_,argument) auraArgument=argument end
V.HideAuraProbe=function() auraHides=(auraHides or 0)+1 end
SlashCmdList.VASAGOIO("auratest hide")
assert(auraArgument=="hide","Aura test command did not route to the optional probe")
SlashCmdList.VASAGOIO("auratest")
assert(auraArgument=="","Bare aura test command did not reach the probe")
V.RestoreArtwork=function() end
SlashCmdList.VASAGOIO("off")
assert(auraHides==1 and not V.db.enabled,"Global disable left the aura experiment active")
print("options_spec: review privacy, lifecycle and scoped performance diagnostics passed")
