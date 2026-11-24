local root = (arg and arg[1]) or "."
local queue, errors = {}, {}
UIParent = {GetWidth = function() return 2560 end, GetHeight = function() return 1440 end}
CreateFrame = function()
    return {RegisterEvent = function() end, SetScript = function(self, _, fn) self.dispatch = fn end}
end
InCombatLockdown = function() return false end
C_Timer = {After = function(_, fn) queue[#queue + 1] = fn end,
    NewTicker = function() return {Cancel = function() end} end}
geterrorhandler = function() return function(message) errors[#errors + 1] = message end end
SlashCmdList = {}
local V, count = {}, 0
for line in io.lines(root .. "/vasagoio.toc") do
    if line ~= "" and not line:match("^#") then
        assert(loadfile(root .. "/" .. line))("vasagoio", V)
        count = count + 1
    end
end
assert(count >= 12, "Incomplete distribution TOC")
V.events.dispatch(nil, "ADDON_LOADED", "vasagoio")
V.events.dispatch(nil, "PLAYER_LOGIN")
local current = queue; queue = {}
for _, callback in ipairs(current) do callback() end
assert(#errors == 0, "Fresh load with no optional addons raised: " .. tostring(errors[1]))
assert(V.db and V.db.enabled and V.db.schemaVersion == 1)
assert(#V.moduleOrder >= 7 and #V.adapterOrder >= 7)
for _, id in ipairs(V.moduleOrder) do
    assert(V.status[id], "Missing status for " .. id)
    assert(V.status[id].state ~= "error", "Missing dependency crashed " .. id)
end
local review = assert(V:PrepareSetup())
assert(#review.unavailable >= 6, "Missing owners should be reported, not silently accepted")
assert(#review.changes == 1, "Only vasagoio's own HUD plan should be available")
assert(V.db.overrides.hudLayout == nil, "Review changed first-run settings")
assert(V:ApplySetup(review) == false, "A missing core HUD allowed partial setup")
assert(V.db.overrides.hudLayout == nil and #V.db.profileBackups == 0, "Blocked setup changed settings")
print("load_spec: packaged TOC loads and initializes with every optional dependency absent")
