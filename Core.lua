local addonName, V = ...
V.name, V.version = addonName, "0.2.0-alpha.1"
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

function V:ApplyModules()
    if not self.ready then return end
    if InCombatLockdown() then self.pending = true; return end
    self.pending = false
    for _, id in ipairs(self.moduleOrder) do
        local spec = self.modules[id]
        if self:IsModuleEnabled(id) and self.profileReloadPending then
            self:Report(id, "pending", "Owner profiles changed; reload before applying cosmetic adapters.")
        elseif self:IsModuleEnabled(id) then
            -- Track attempted applications too: an API error may follow a
            -- partial cosmetic change that still needs its Disable cleanup.
            self.activeModules[id] = true
            local ok, applied, detail, state = pcall(spec.Apply, spec)
            if not ok then
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

function V:Refresh()
    if self.refreshQueued then return end
    self.refreshQueued = true
    local function apply()
        V.refreshQueued = false
        V:ApplyModules()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, apply) else apply() end
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
        if V.pending then V:Refresh() end
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
