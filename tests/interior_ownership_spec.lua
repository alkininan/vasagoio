local root = (arg and arg[1]) or "."
local combat, refreshes = false, 0
InCombatLockdown = function() return combat end
local V = {db = {enabled = true, modules = {}}, modules = {nativeInteriors = {}, addonWindows = {}}}
function V:IsSecret(value) return type(value) == "table" and value.secret == true end
function V:SafeNumber(value) if type(value) == "number" then return value end end
function V:IsModuleEnabled(id) return self.db.enabled and self.db.modules[id] ~= false end
function V:Pixel(n) return n end
function V:Font(role) return role == "count" and "narrow.ttf" or "friz.ttf", 16, "" end
function V:Refresh() refreshes = refreshes + 1 end
assert(loadfile(root .. "/Tokens.lua"))("vasagoio", V)
local function texture()
    return {alpha = 1,
        SetAlpha = function(self,a) self.alpha = a end, GetAlpha = function(self) return self.alpha end,
        SetPoint = function() end, SetHeight = function() end, SetColorTexture = function(self,...) self.color = {...} end,
        Show = function(self) self.shown = true end, Hide = function(self) self.shown = false end,
        SetShown = function(self,b) self.shown = b end,
    }
end
local function font()
    return {path = "original.ttf", size = 13, flags = "OUTLINE", color = {.8,.3,.2,1},
        GetObjectType = function() return "FontString" end,
        GetFont = function(self) return self.path,self.size,self.flags end,
        SetFont = function(self,path,size,flags) self.path,self.size,self.flags = path,size,flags; return true end,
        GetTextColor = function(self) return unpack(self.color) end,
        SetTextColor = function(self,...) self.color = {...} end,
        SetShadowColor = function() end, SetShadowOffset = function() end,
        GetShadowColor = function() return 0,0,0,0 end, GetShadowOffset = function() return 0,0 end,
    }
end
local function frame()
    local f = {Bg = texture(), label = font(), hooks = {}, enabled = true,
        backdrop = {.1,.2,.3,1}, border = {.4,.5,.6,1}}
    function f:GetObjectType() return "Button" end
    function f:GetFontString() return self.label end
    function f:GetRegions() return self.label end
    function f:GetChildren() end
    function f:CreateTexture() return texture() end
    function f:MarkIgnoreInLayout(object) object.layoutIgnored = true end
    function f:GetBackdropColor() return unpack(self.backdrop) end
    function f:GetBackdropBorderColor() return unpack(self.border) end
    function f:SetBackdropColor(...) self.backdrop = {...} end
    function f:SetBackdropBorderColor(...) self.border = {...} end
    function f:IsEnabled() return self.enabled end
    function f:HasScript() return true end
    function f:HookScript(event,fn)
        self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event],fn)
    end
    function f:Fire(event) for _, fn in ipairs(self.hooks[event] or {}) do fn(self) end end
    return f
end
function V:Surface(target,alpha,radius,color)
    target.surface = target.surface or texture()
    target.surface.alpha, target.surface.color = alpha,color
    target.surface:Show()
    return target.surface
end
assert(loadfile(root .. "/core/Interiors.lua"))("vasagoio", V)
local I = V.InteriorSkin
local shared = frame()
I:Control(shared,"tab","nativeInteriors")
I:Control(shared,"tab","addonWindows")
I:Watch(shared,{owner="nativeInteriors"})
I:Watch(shared,{owner="addonWindows"})
assert(#shared.hooks.OnEnter == 1 and #shared.hooks.OnShow == 1, "Shared owners added duplicate hooks")
local marker = I.records[shared].signal
assert(marker.ignoreInLayout and marker.layoutIgnored, "Marker participated in native layout")
V.db.modules.addonWindows = false
assert(I:Restore("addonWindows"))
assert(shared.Bg.alpha == 0 and shared.surface.shown, "Disabling addon skins reverted the active native owner")
assert(shared.label.path == "friz.ttf", "Shared text was restored despite an active owner")
shared:Fire("OnEnter")
assert(shared.surface.alpha == V.Tokens.controls.hoverAlpha, "State hook still followed disabled last owner")
shared:Fire("OnShow")
assert(refreshes == 1, "Shared watcher did not transfer to active owner")
shared:Fire("OnMouseDown"); shared:Fire("OnLeave")
assert(not I.records[shared].pressed, "Mouse release outside left pressed state stuck")
shared.enabled = false
I:SetSelected(shared,true)
assert(marker.color[4] == 1, "Native selected-disabled tab marker was dimmed")
V.db.modules.nativeInteriors = false
assert(I:Restore("nativeInteriors"))
assert(shared.Bg.alpha == 1 and not shared.surface.shown and not marker.shown)
assert(shared.label.path == "original.ttf" and shared.label.size == 13)
local before = refreshes
shared:Fire("OnShow")
assert(refreshes == before, "Restored watcher retained a removed ownership claim")

V.db.modules.addonWindows = true
I:Control(shared,"tab","addonWindows")
I:Watch(shared,{owner="addonWindows"})
assert(shared.surface.shown and #shared.hooks.OnEnter == 1, "Reenable duplicated or lost hooks")
combat = true
assert(I:Restore("addonWindows") == false)
assert(I.records[shared].owners.addonWindows, "Combat restore dropped a claim before deferral")
combat = false
V.profileReloadPending = true
V.db.modules.nativeInteriors = nil
-- A configured owner remains a claimant while layout awaits reload.
I.records[shared].owners.nativeInteriors = true
I:Restore("addonWindows")
assert(shared.surface.shown, "Pending reload incorrectly discarded another configured owner's style")
V.profileReloadPending = false
I:Restore()
assert(not shared.surface.shown)

local count = font()
I:Text(count,"count",true,"nativeInteriors")
I:Text(count,"body",true,"nativeInteriors")
assert(count.path == "narrow.ttf" and count.size == 13, "Generic traversal replaced an explicit count role")
local child = frame()
child.Count = count
local calls = 0
local stats = I:Apply(child,{owner="nativeInteriors",onFrame=function(f)
    if f == child then calls = calls+1; error("fixture callback error") end
end})
assert(calls == 1 and stats.skipped == 1, "Scoped callback errors were not isolated")
assert(count.path == "narrow.ttf")

-- Load the actual shell adapter over the actual primitive service. Legacy
-- pre-styling must not overwrite the snapshots or bypass ownership claims.
local legacyCalls = 0
function V:RegisterModule(id,spec) self.modules[id] = spec end
function V:RegisterProfileAdapter() end
function V:On() end
function V:HideArtwork(object) legacyCalls = legacyCalls+1; object:SetAlpha(0) end
function V:StyleText(text,role,color)
    legacyCalls = legacyCalls+1
    text:SetFont(self:Font(role))
    text:SetTextColor(unpack(color))
end
assert(loadfile(root .. "/modules/NativeWindows.lua"))("vasagoio", V)
local W = V.WindowSkin
local shell = frame()
shell.TitleText, shell.TitleContainer, shell.ExtraTitle = font(), {TitleText=font()}, font()
shell.Inner = {Decoration=texture()}
shell.Bg.alpha, shell.Inner.Decoration.alpha = .8,.6
local extraArt = texture()
extraArt.alpha = .7
V.db.modules.nativeWindows, V.db.modules.addonWindows = true,true
for _, owner in ipairs({"nativeWindows","addonWindows"}) do
    assert(W:Shell(shell,{"Inner.Decoration"},{"ExtraTitle"},owner))
    W:Hide(extraArt,owner)
    W:Hook(shell,owner)
end
assert(legacyCalls == 0, "Shell bypassed ownership-aware primitives before their snapshots")
assert(#shell.hooks.OnShow == 1, "Shell owners installed duplicate discovery hooks")
assert(shell.Bg.alpha == 0 and shell.Inner.Decoration.alpha == 0 and extraArt.alpha == 0)
assert(shell.backdrop[4] == 0 and shell.border[4] == 0 and shell.surface.shown)
for _, text in ipairs({shell.TitleText,shell.TitleContainer.TitleText,shell.ExtraTitle}) do
    assert(text.path == "friz.ttf" and text.size == 13 and text.flags == "", "Shell title missed interior typography")
end

-- Remove the owner that first captured the shell. A legacy backdrop snapshot
-- used to restore here even while the later addon owner remained enabled.
V.db.modules.nativeWindows = false
I:Restore("nativeWindows")
W:RestoreBackdrops("nativeWindows")
assert(shell.backdrop[4] == 0 and shell.border[4] == 0, "Shell backdrop restoration overrode the active addon owner")
assert(shell.Bg.alpha == 0 and extraArt.alpha == 0 and shell.surface.shown)
assert(shell.TitleText.path == "friz.ttf", "Shell title restored while another owner remained")
local shellRefreshes = refreshes
shell:Fire("OnShow")
assert(refreshes == shellRefreshes+1, "Shell watcher did not follow its surviving owner")

V.db.modules.addonWindows = false
I:Restore("addonWindows")
W:RestoreBackdrops("addonWindows")
assert(shell.backdrop[1] == .1 and shell.backdrop[2] == .2 and shell.backdrop[3] == .3 and shell.backdrop[4] == 1,
    "Shell backdrop snapshot captured previously styled colors")
assert(shell.border[1] == .4 and shell.border[2] == .5 and shell.border[3] == .6 and shell.border[4] == 1)
assert(shell.Bg.alpha == .8 and shell.Inner.Decoration.alpha == .6 and extraArt.alpha == .7 and not shell.surface.shown,
    "Final shell owner did not restore original artwork and surface")
for _, text in ipairs({shell.TitleText,shell.TitleContainer.TitleText,shell.ExtraTitle}) do
    assert(text.path == "original.ttf" and text.size == 13 and text.flags == "OUTLINE", "Shell font snapshot was already themed")
    assert(text.color[1] == .8 and text.color[2] == .3 and text.color[3] == .2 and text.color[4] == 1,
        "Final shell owner did not restore original title color")
end
shellRefreshes = refreshes
shell:Fire("OnShow")
assert(refreshes == shellRefreshes, "Disabled shell watcher retained an owner")
print("interior_ownership_spec: shared controls/shells, watcher transfer, combat cleanup, selection, callbacks and explicit font roles passed")
