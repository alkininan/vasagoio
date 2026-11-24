local _, V = ...
local adapterModules = {
    unitframes = "unitframes", nameplates = "nameplates", bartender = "actionBars",
    hudLayout = "hud", prat = "hud", sexymap = "hud", details = "meter", skinner = "nativeWindows",
}
local function adapterEnabled(self, id, spec)
    local module = spec.module or adapterModules[id]
    if not module then return true end
    return self.modules[module] and self:IsModuleEnabled(module), module
end
local function resolve(path)
    if type(path) ~= "table" or #path == 0 or type(path[1]) ~= "string" then return nil end
    local target = _G
    for _, key in ipairs(path) do
        if type(target) ~= "table" then return nil end
        target = rawget(target, key)
    end
    return type(target) == "table" and target or nil
end
V.ResolveProfilePath = resolve

function V:PrepareSetup()
    if not self.db or self.readOnly then return nil, "Settings are not writable." end
    if not self.db.enabled then return nil, "Enable vasagoio before setup." end
    if InCombatLockdown() then return nil, "Leave combat before preparing setup." end
    if self.profileReloadPending then return nil, "Reload before preparing another owner-profile setup." end
    local review = {changes = {}, adapters = {}, unavailable = {}, revision = self.Tokens.revision}
    for _, id in ipairs(self.adapterOrder) do
        local spec = self.adapters[id]
        local enabled, module = adapterEnabled(self, id, spec)
        local ok, plan, reason
        if enabled then ok, plan, reason = pcall(spec.Prepare, spec)
        else ok, reason = true, "Associated module " .. module .. " is disabled or unavailable." end
        if ok and plan and type(plan.changes) == "table" then
            local validated = {}
            local valid, failure = pcall(function()
                for _, change in ipairs(plan.changes) do
                    assert(resolve(change.path) == change.table, "Unresolvable saved-variable path")
                    assert(type(change.key) == "string" or type(change.key) == "number", "Invalid profile key")
                    validated[#validated + 1] = {path = self:Copy(change.path), key = change.key,
                        before = self:Copy(change.table[change.key]), after = self:Copy(change.value),
                        label = change.label or tostring(change.key), adapter = id}
                end
            end)
            if valid then
                review.adapters[#review.adapters + 1] = {id = id, label = spec.label or id, detail = plan.detail or ""}
                for _, change in ipairs(validated) do review.changes[#review.changes + 1] = change end
            else
                review.unavailable[#review.unavailable + 1] = {id = id, reason = "Profile snapshot failed validation."}
            end
        else
            review.unavailable[#review.unavailable + 1] = {id = id, reason = ok and (reason or "Owner not ready.") or "Profile adapter API error."}
        end
    end
    -- A review is ephemeral. Do not silently regenerate it when the user clicks Apply.
    self.setupReview = review
    return review
end

function V:ApplySetup(review)
    if not review or review ~= self.setupReview then return false, "Prepare a fresh setup review first." end
    if self.readOnly or not self.db.enabled then return false, "Settings are disabled." end
    if self.profileReloadPending then return false, "Reload before applying another owner-profile setup." end
    if InCombatLockdown() then return false, "Leave combat before applying setup." end
    if #review.changes == 0 then return false, "No supported, loaded addon profiles were found." end
    for _, entry in ipairs(review.adapters) do
        local spec = self.adapters[entry.id]
        if not spec or not adapterEnabled(self, entry.id, spec) then
            return false, "A reviewed module is now disabled or unavailable. Prepare setup again."
        end
        -- A profile switch can leave the old table and values unchanged.
        -- Re-prepare without writes so the owner's current target identity and
        -- scale-derived proposal must still match what was actually reviewed.
        local ok, fresh = pcall(spec.Prepare, spec)
        if not ok or not fresh or type(fresh.changes) ~= "table" then
            return false, "An addon setup target is no longer available. Prepare setup again."
        end
        local valid = pcall(function()
            local expected = {}
            for _, change in ipairs(review.changes) do
                if change.adapter == entry.id then expected[#expected + 1] = change end
            end
            assert(#fresh.changes == #expected, "Changed proposal size")
            local matched = {}
            for _, change in ipairs(fresh.changes) do
                assert(not self:IsSecret(change.key), "Restricted profile key")
                assert(type(change.key) == "string" or type(change.key) == "number", "Invalid profile key")
                assert(resolve(change.path) == change.table, "Changed target identity")
                local after = self:Copy(change.value)
                local found
                for index, previous in ipairs(expected) do
                    if not matched[index] and change.key == previous.key and self:Equal(change.path, previous.path)
                        and self:Equal(after, previous.after) then
                        matched[index], found = true, true
                        break
                    end
                end
                assert(found, "Changed proposal or active profile")
            end
        end)
        if not valid then
            return false, "An active profile, setup target or layout scale changed since review. Prepare setup again."
        end
    end
    local targets = {}
    -- Validate every precondition before the first write; do not overwrite intervening user edits.
    for i, change in ipairs(review.changes) do
        local target = resolve(change.path)
        if not target or not self:Equal(target[change.key], change.before) then
            return false, "An addon profile changed since review. Prepare setup again."
        end
        targets[i] = target
    end
    local backup = {revision = review.revision, changes = self:Copy(review.changes), time = time and time() or 0}
    self.db.profileBackups[#self.db.profileBackups + 1] = backup
    local written = 0
    local ok = pcall(function()
        for i, change in ipairs(review.changes) do
            targets[i][change.key] = self:Copy(change.after)
            written = i
        end
    end)
    if not ok then
        for i = written, 1, -1 do targets[i][review.changes[i].key] = self:Copy(review.changes[i].before) end
        table.remove(self.db.profileBackups)
        return false, "Setup failed; the changes were rolled back."
    end
    self.setupReview = nil
    local previousRevision = self.db.appliedRevision
    self.db.appliedRevision = review.revision
    self.profileReloadPending = true
    local callbackFailed = false
    for _, entry in ipairs(review.adapters) do
        local spec = self.adapters[entry.id]
        if spec.AfterApply then
            local success, result = pcall(spec.AfterApply, spec)
            if not success or result == false then callbackFailed = true; break end
        end
    end
    if callbackFailed then
        -- A live-anchor owner can overwrite saved positions during reload.
        -- Failed activation is not a successful setup: restore saved values
        -- and synchronize only the reviewed owners back to their before state.
        for i = #review.changes, 1, -1 do targets[i][review.changes[i].key] = self:Copy(review.changes[i].before) end
        local recovered = true
        for _, entry in ipairs(review.adapters) do
            local spec = self.adapters[entry.id]
            if spec.AfterRestore then
                local changes = {}
                for _, change in ipairs(review.changes) do
                    if change.adapter == entry.id then changes[#changes + 1] = change end
                end
                local success, result = pcall(spec.AfterRestore, spec, changes)
                if not success or result == false then recovered = false end
            end
        end
        table.remove(self.db.profileBackups)
        self.db.appliedRevision = previousRevision
        self:Refresh()
        return false, recovered and "An owner refresh failed. Setup was rolled back; reload before trying again."
            or "An owner refresh failed. Saved settings were rolled back, but live-window recovery failed; inspect the affected owner before reloading."
    end
    self:Refresh()
    return true, "Profiles saved and backed up. Reload to activate all owner profiles."
end

function V:RollbackProfiles()
    if self.readOnly then return false, "Settings are not writable." end
    if InCombatLockdown() then return false, "Leave combat before restoring profiles." end
    local backups = self.db.profileBackups
    local backup = backups[#backups]
    if not backup then return false, "There is no setup snapshot to restore." end
    local targets, byAdapter = {}, {}
    for i, change in ipairs(backup.changes) do
        local target = resolve(change.path)
        if not target then return false, "Load the affected addon before restoring its profile." end
        if not self:Equal(target[change.key], change.after) then
            return false, "A setting changed after setup. Automatic rollback stopped to preserve your edits. Restore using the owner's profile menu or your WTF backup."
        end
        targets[i] = target
        if type(change.adapter) == "string" then
            byAdapter[change.adapter] = byAdapter[change.adapter] or {}
            table.insert(byAdapter[change.adapter], change)
        end
    end
    -- Some owners save live window anchors at logout. Validate their ability
    -- to restore those anchors before any saved settings are changed.
    for id, changes in pairs(byAdapter) do
        local spec = self.adapters[id]
        if spec and spec.ValidateRestore then
            local ok, valid, reason = pcall(spec.ValidateRestore, spec, changes)
            if not ok or valid ~= true then
                return false, ok and reason or "An owner could not validate profile restoration. No settings were changed."
            end
        end
    end
    for i = #backup.changes, 1, -1 do
        local change = backup.changes[i]
        targets[i][change.key] = self:Copy(change.before)
    end
    local callbackFailed = false
    for id, changes in pairs(byAdapter) do
        local spec = self.adapters[id]
        if spec and spec.AfterRestore then
            local ok, result = pcall(spec.AfterRestore, spec, changes)
            if not ok or result == false then callbackFailed = true end
        end
    end
    if callbackFailed then
        -- Keep the snapshot and saved values as they were before this attempt.
        -- Reconcile the few adapters with live restore callbacks to that state.
        for i, change in ipairs(backup.changes) do targets[i][change.key] = self:Copy(change.after) end
        for id in pairs(byAdapter) do
            local spec = self.adapters[id]
            if spec and spec.AfterRestore and spec.AfterApply then pcall(spec.AfterApply, spec, byAdapter[id]) end
        end
        self.profileReloadPending = true
        return false, "An owner window could not be restored. Saved settings and the snapshot were retained; reload and inspect the owner before retrying."
    end
    table.remove(backups)
    self.db.appliedRevision = nil
    self.profileReloadPending = true
    self:Refresh()
    return true, "Previous saved settings restored. Reload now; owner runtime settings may otherwise overwrite them."
end
