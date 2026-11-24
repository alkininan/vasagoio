local addonName, V = ...
V.name, V.version = addonName, "0.2.0-alpha.5"
V.modules, V.moduleOrder, V.listeners, V.status = {}, {}, {}, {}
V.adapters, V.adapterOrder = {}, {}
V.activeModules = {}
V.ready, V.pending = false, false
local events = CreateFrame("Frame")
V.events = events

function V:Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffA8D7EBvasagoio|r: " .. message) end
end

function V:IsSecret(value)
    if type(issecretvalue) ~= "function" then return false end
    local ok, result = pcall(issecretvalue, value)
    return not ok or result == true
end

function V:SafeNumber(value)
    if self:IsSecret(value) then return nil end
    if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then return nil end
    return value
end

function V:Report(id, state, detail)
    self.status[id] = { state = state, detail = detail or "" }
end

function V:On(event, fn)
    self.listeners[event] = self.listeners[event] or {}
    table.insert(self.listeners[event], fn)
    pcall(events.RegisterEvent, events, event)
end

function V:RegisterModule(id, spec)
    assert(not self.modules[id], "Duplicate module: " .. id)
    self.modules[id] = spec
    table.insert(self.moduleOrder, id)
end

function V:RegisterProfileAdapter(id, spec)
    assert(not self.adapters[id], "Duplicate profile adapter: " .. id)
    self.adapters[id] = spec
    table.insert(self.adapterOrder, id)
end

function V:Pixel(value)
    local width = self:SafeNumber(UIParent:GetWidth()) or 2560
    local height = self:SafeNumber(UIParent:GetHeight()) or 1440
    local scale = self.db and self:SafeNumber(self.db.layoutScale) or 1
    return value * math.min(width / 2560, height / 1440) * (scale or 1)
end

-- Absolute TOPLEFT/BOTTOMLEFT profile anchors and center-based owner anchors
-- share this centered design canvas, including on non-16:9 displays.
function V:CanvasOrigin()
    local width = self:SafeNumber(UIParent:GetWidth()) or 2560
    local height = self:SafeNumber(UIParent:GetHeight()) or 1440
    return (width - self:Pixel(2560)) / 2, (height - self:Pixel(1440)) / 2
end

function V:IsModuleEnabled(id)
    if not self.db or not self.db.enabled or self.readOnly then return false end
    local choice = self.db.modules[id]
    if choice == nil then return self.modules[id].defaultEnabled ~= false end
    return choice == true
end

local function safeClock(fn)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn)
    return ok and V:SafeNumber(value) or nil
end

function V:ApplyModules(only, followup)
    if not self.ready or self.applyingModules then return end
    if InCombatLockdown() then
        self.pending = true
        if not only then self.pendingAll = true
        else
            self.pendingModules = self.pendingModules or {}
            for id in pairs(only) do self.pendingModules[id] = true end
        end
        return
    end
    self.pending = false
    self.applyingModules, self.followupPass = true, followup
    self.refreshDuringApply = {}
    self.runtimeStats = self.runtimeStats or {startedAt = safeClock(GetTime), modules = {}}
    for _, id in ipairs(self.moduleOrder) do
      if not only or only[id] then
        self.applyingModule = id
        local spec = self.modules[id]
        if self:IsModuleEnabled(id) and self.profileReloadPending then
            self:Report(id, "pending", "Owner profiles changed; reload before applying cosmetic adapters.")
        elseif self:IsModuleEnabled(id) then
            -- Track attempted applications too: an API error may follow a
            -- partial cosmetic change that still needs its Disable cleanup.
            self.activeModules[id] = true
            local stats = self.runtimeStats.modules[id]
            if not stats then
                stats = {calls=0,errors=0,timedCalls=0,totalMs=0,maxMs=0}
                self.runtimeStats.modules[id] = stats
            end
            stats.calls = stats.calls + 1
            local start = safeClock(debugprofilestop)
            local ok, applied, detail, state = pcall(spec.Apply, spec)
            local stop = start and safeClock(debugprofilestop)
            if stop and stop >= start then
                local elapsed = stop - start
                stats.timedCalls = stats.timedCalls + 1
                stats.totalMs, stats.maxMs = stats.totalMs + elapsed, math.max(stats.maxMs, elapsed)
            end
            if not ok then
                stats.errors = stats.errors + 1
                self:Report(id, "error", "Module stopped after an API error; other modules continue.")
                if geterrorhandler then geterrorhandler()(applied) end
            elseif applied then self:Report(id, "applied", detail)
            else self:Report(id, state == "pending" and "pending" or "unsupported", detail) end
        else
            local cleanupOK = true
            if self.activeModules[id] then
                if spec.Disable then cleanupOK = pcall(spec.Disable, spec) end
                self.activeModules[id] = nil
            end
            self:Report(id, "disabled", cleanupOK and "Disabled; reload to remove existing hooks and styling." or "Disabled; cleanup needs a reload to finish.")
        end
      end
    end
    local again = self.refreshDuringApply
    self.applyingModule, self.applyingModules, self.followupPass, self.refreshDuringApply = nil, nil, nil, nil
    -- Owner layouts can allocate a legitimate late widget during styling.
    -- Permit one follow-up for those callbacks, but never an unbounded chain
    -- when an owner's setter keeps notifying us on every cosmetic pass.
    if not followup and next(again) then self:ApplyModules(again, true) end
end

-- Owner callbacks invalidate only their module. A bar update must not traverse
-- every hidden native/addon window. Reentrant callbacks from our own cosmetic
-- writes receive at most one follow-up instead of an endless repaint chain.
function V:Refresh(_, moduleId)
    if moduleId and not self.modules[moduleId] then return end
    if self.applyingModules then
        if not self.followupPass then
            if moduleId then self.refreshDuringApply[moduleId] = true
            else for _, id in ipairs(self.moduleOrder) do self.refreshDuringApply[id] = true end end
        end
        return
    end
    if moduleId then
        self.refreshModules = self.refreshModules or {}
        self.refreshModules[moduleId] = true
    else self.refreshAll = true end
    if self.refreshQueued then return end
    self.refreshQueued = true
    local function apply()
        local only = not V.refreshAll and V.refreshModules or nil
        V.refreshQueued, V.refreshAll, V.refreshModules = false, nil, nil
        V:ApplyModules(only)
    end
    if C_Timer and C_Timer.After then C_Timer.After(.05, apply) else apply() end
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then V:InitializeDatabase() end
        if V.ready then V:Refresh() end
    elseif event == "PLAYER_LOGIN" then
        V.ready = true
        if not V.db then V:InitializeDatabase() end
        V:Refresh()
        if V.db.enabled then V:Print("Alpha build. Type /vasagoio for setup, coverage and disable controls.") end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if V.pending then
            if V.pendingAll then V:Refresh()
            else for id in pairs(V.pendingModules or {}) do V:Refresh("combat ended", id) end end
            V.pendingAll, V.pendingModules = nil, nil
        end
    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        V:Refresh()
    end
    for _, fn in ipairs(V.listeners[event] or {}) do
        local ok, err = pcall(fn, event, ...)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end
end)
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED"}) do
    events:RegisterEvent(event)
end
