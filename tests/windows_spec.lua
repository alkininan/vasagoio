-- Run from the repository root with Lua 5.1+ (or a Lua runtime harness).
unpack = unpack or table.unpack
local root = (arg and arg[1]) or "."
local combat, mutations, refreshes = false, 0, 0
local versions = {Skinner = "beta12.70938.1", MRT = "5335", Auctionator = "352", TalentsForeverBook = "0.38.28.20261116"}
local modules, adapters, events = {}, {}, {}
local function check(value, message) assert(value, message) end
local function texture()
    return {alpha = 1, SetAlpha = function(self, value) mutations = mutations + 1; self.alpha = value end}
end
local function font()
    return {GetFont = function() return "original.ttf", 13, "" end,
        SetFont = function(self, path, size) self.path, self.size = path, size end}
end
local function frame()
    return {
        Bg = texture(), TitleText = font(), hooks = 0,
        CreateTexture = function() return texture() end,
        HookScript = function(self, event, fn) self.hooks = self.hooks + 1; self[event] = fn end,
        SetSize = function() error("Native geometry must not change") end,
        SetPoint = function() error("Native anchors must not change") end,
        GetBackdropColor = function() return .2, .3, .4, 1 end,
        GetBackdropBorderColor = function() return .4, .5, .6, 1 end,
        SetBackdropColor = function(self, ...) self.color = {...}; mutations = mutations + 1 end,
        SetBackdropBorderColor = function(self, ...) self.border = {...}; mutations = mutations + 1 end,
    }
end
local V = {db = {enabled = true, modules = {}}, surfaces = {}}
function V:RegisterModule(id, spec) modules[id] = spec end
function V:RegisterProfileAdapter(id, spec) adapters[id] = spec end
function V:On(event, fn) events[event] = events[event] or {}; table.insert(events[event], fn) end
function V:Refresh() refreshes = refreshes + 1 end
function V:IsSecret(v) return type(v) == "table" and v.secret == true end
function V:SafeNumber(v) return type(v) == "number" and v or nil end
function V:Font() return "Fonts\\FRIZQT__.TTF", 16, "" end
function V:StyleText(text, role) text.role = role end
function V:HideArtwork(object) object:SetAlpha(0) end
function V:Surface(object) self.surfaces[object] = true; mutations = mutations + 1 end
function V:Print() end
InCombatLockdown = function() return combat end
C_AddOns = {GetAddOnMetadata = function(addon) return versions[addon] end}
local tick, cancelled
C_Timer = {NewTicker = function(_, callback) tick = callback; return {Cancel = function() cancelled = true end} end}
assert(loadfile(root .. "/Tokens.lua"))("vasagoio", V)
assert(loadfile(root .. "/modules/NativeWindows.lua"))("vasagoio", V)
assert(loadfile(root .. "/modules/AddonWindows.lua"))("vasagoio", V)

CharacterFrame = frame()
CharacterFrame.ModelScene = {sentinel = "native model"}
CharacterFrame.EquipmentSlots = {sentinel = "native equipment"}
CharacterFrame.NineSlice = {TopEdge = texture()}
CharacterFrame.LeftPaneHost = {StoneBg = texture()}
GameMenuFrame = frame()
GameMenuFrame.IsForbidden = function() return true end
StaticPopup1, GhostFrame = frame(),frame()
local recoveryClick=function()end
StaticPopup1.OnClick,GhostFrame.OnClick=recoveryClick,recoveryClick
check(modules.nativeWindows.Apply(), "native fallback failed")
check(CharacterFrame.Bg.alpha == 0 and CharacterFrame.NineSlice.TopEdge.alpha == 0, "native artwork not replaced")
check(CharacterFrame.TitleText.size == 13, "native text geometry changed")
check(CharacterFrame.ModelScene.sentinel == "native model" and CharacterFrame.EquipmentSlots.sentinel == "native equipment", "native structure changed")
check(not V.surfaces[GameMenuFrame], "forbidden frame was modified")
check(not V.surfaces[StaticPopup1] and not V.surfaces[GhostFrame] and StaticPopup1.hooks==0 and GhostFrame.hooks==0,
    "Native recovery dialogs acquired fallback skins or script hooks")
check(StaticPopup1.Bg.alpha==1 and StaticPopup1.OnClick==recoveryClick and GhostFrame.OnClick==recoveryClick,
    "Native recovery appearance or callbacks changed")
modules.nativeWindows.Apply()
check(CharacterFrame.hooks == 1, "duplicate native OnShow hooks")
local before = mutations
combat = true
modules.nativeWindows.Apply()
check(mutations == before, "native mutation in combat")
combat = false
modules.nativeWindows.Disable()
check(CharacterFrame.color[1] == .2, "original backdrop not restored")

local profile = {
    FrameBorders = true, ClassClrBd = true, ClassClrBg = false, ClassClrGr = false,
    BgUseTex = false, DisableAllNPC = true, DisableAllP = true, DisableAllUI = true, DisableAllAS = false,
    ChatButtons = true, ChatFrames = true, ChatTabs = true, Gradient = {enable = true},
    StaticPopups=true,GhostFrame=true,DeathRecap=true,
    CastingBar = {skin = true}, CompactFrames = {skin = true}, CharacterFrames = true,
    Backdrop = {r = 0, g = 0, b = 0, a = .9}, HeadText = {r = .8, g = .8, b = 0, a = 1},
}
SkinnerDB = {profiles = {Test = profile}}
Skinner = {db = {profile = profile, GetCurrentProfile = function() return "Test" end}}
local plan = adapters.skinner.Prepare()
check(plan and #plan.changes > 10, "reviewed Skinner plan missing")
check(profile.FrameBorders == true and profile.Backdrop.a == .9, "Prepare mutated Skinner profile")
local recoveryFlags={}
for _, change in ipairs(plan.changes) do
    local target = _G
    for _, part in ipairs(change.path) do target = target[part] end
    check(target == change.table, "profile rollback path does not resolve to changed table")
    if change.key=="StaticPopups" or change.key=="GhostFrame" or change.key=="DeathRecap" then recoveryFlags[change.key]=change.value end
end
check(recoveryFlags.StaticPopups==false and recoveryFlags.GhostFrame==false and recoveryFlags.DeathRecap==false,
    "Reviewed Skinner preset retained recovery-dialog takeover")
check(profile.StaticPopups and profile.GhostFrame and profile.DeathRecap,"Recovery skin review wrote settings before Apply")
before = mutations
modules.nativeWindows.Apply()
check(mutations == before, "Skinner and fallback both own native windows")
versions.Skinner = "future-unreviewed"
check(adapters.skinner.Prepare() == nil, "unknown Skinner version was modified")
Skinner = nil

local bag, item, listener, registrations = frame(), {Count = font()}, nil, 0
Baganator = {API = {Skins = {
    RegisterListener = function(fn) listener = fn; registrations = registrations + 1 end,
    GetAllFrames = function() return {{region = bag, regionType = "ButtonFrame"}, {region = item, regionType = "ItemButton"}} end,
}}}
MRTOptionsFrame = frame()
TalentsForeverBookFrame = frame()
TalentsForeverBookFrame.cover = {texture(), texture()}
modules.addonWindows.Apply()
modules.addonWindows.Apply()
check(registrations == 1 and bag.hooks == 1, "Baganator skin listener/hook duplicated")
check(V.surfaces[bag] and item.Count.role == "count", "Baganator API types not skinned")
check(TalentsForeverBookFrame.cover[1].alpha == 0, "reviewed Talents cover not hidden")
versions.TalentsForeverBook = "0.38.33.20261123"
TalentsForeverBookFrame = frame()
local currentTalents = TalentsForeverBookFrame
modules.addonWindows.Apply()
check(V.surfaces[currentTalents], "current reviewed Talents shell was skipped")
versions.TalentsForeverBook = "0.38.33.20261124"
TalentsForeverBookFrame = frame()
modules.addonWindows.Apply()
check(V.surfaces[TalentsForeverBookFrame], "updated reviewed Talents shell was skipped")

for _, unreviewed in ipairs({"0.38.34.20261124", {secret=true}}) do
    versions.TalentsForeverBook = unreviewed
    TalentsForeverBookFrame = frame()
    modules.addonWindows.Apply()
    check(not V.surfaces[TalentsForeverBookFrame], "unreviewed or restricted Talents shell was styled")
end
versions.TalentsForeverBook = "0.38.33.20261123"
TalentsForeverBookFrame = currentTalents
before = mutations
combat = true
listener({region = frame(), regionType = "ButtonFrame"})
check(mutations == before and refreshes > 0, "Baganator combat callback must defer")
combat = false
local unknown = frame()
listener({region = unknown, regionType = "UnknownFutureType"})
check(not V.surfaces[unknown], "unreviewed Baganator region modified")
local secret = frame(); secret.secret = true
listener({region = secret, regionType = "ButtonFrame"})
check(not V.surfaces[secret], "secret object modified")
local late = frame()
AuctionatorFullScanFrame = late
before = refreshes
tick()
check(refreshes > before and not V.surfaces[late], "lazy discovery must schedule through core")
modules.addonWindows.Apply()
check(V.surfaces[late], "lazy addon root not styled")
V.db.modules.addonWindows = false
before = mutations
listener({region = frame(), regionType = "ButtonFrame"})
check(mutations == before, "disabled Baganator callback mutated frame")
modules.addonWindows.Disable()
check(cancelled, "lazy discovery timer not cancelled")
print("windows_spec: native structure, combat, secrets, rollback paths, ownership and lazy API hooks passed")
