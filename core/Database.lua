local _, V = ...
V.schemaVersion = 1
function V:Copy(value, seen)
    if self:IsSecret(value) then error("Restricted value cannot be saved") end
    local kind = type(value)
    if kind ~= "table" then
        if kind == "function" or kind == "userdata" or kind == "thread" then error("Nonserializable value") end
        if kind == "number" and not self:SafeNumber(value) then error("Invalid number") end
        return value
    end
    seen = seen or {}
    if seen[value] then error("Cyclic table cannot be saved") end
    seen[value] = true
    local out = {}
    for key, item in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then error("Invalid key") end
        out[key] = self:Copy(item, seen)
    end
    seen[value] = nil
    return out
end

function V:Equal(a, b)
    if self:IsSecret(a) or self:IsSecret(b) then return false end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not self:Equal(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

function V:InitializeDatabase()
    local saved = _G.VasagoioDB
    if type(saved) ~= "table" then saved = {} end
    if type(saved.schemaVersion) == "number" and saved.schemaVersion > self.schemaVersion then
        self.readOnly = true
        self.db = {enabled = false, modules = {}, overrides = {}, profileBackups = {}}
        self:Print("A newer version saved your settings. This build is disabled to preserve them.")
        return
    end
    saved.schemaVersion = self.schemaVersion
    if type(saved.enabled) ~= "boolean" then saved.enabled = true end
    for _, key in ipairs({"modules", "overrides", "profileBackups", "fonts"}) do
        if type(saved[key]) ~= "table" then saved[key] = {} end
    end
    if not self:SafeNumber(saved.layoutScale) or saved.layoutScale < .5 or saved.layoutScale > 2 then saved.layoutScale = 1 end
    saved.presetRevision = saved.presetRevision or self.Tokens.revision
    _G.VasagoioDB, self.db = saved, saved
end
