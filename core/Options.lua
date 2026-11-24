local _, V = ...
local function textLine(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY")
    V:StyleText(label, "body")
    label:SetPoint("TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end
local function button(parent, label, x, y, width, callback)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 28); b:SetPoint("BOTTOMLEFT", x, y); b:SetText(label)
    b:SetScript("OnClick", callback)
    return b
end

local summaryKeys = {}
for _, key in ipairs({"width", "height", "size", "scale", "enabled", "enable", "font", "fontSize", "color", "colors",
    "alpha", "opacity", "texture", "border", "background", "position", "point", "anchor", "x", "y", "gap", "spacing",
    "rows", "columns", "buttons", "numButtons", "padding", "general", "player", "target", "pet", "party", "raid",
    "focus", "targettarget", "focustarget", "health", "power", "portrait", "r", "g", "b", "a"}) do summaryKeys[key] = true end

local function reviewedValue(value)
    if V:IsSecret(value) then return "restricted" end
    local kind = type(value)
    if kind == "nil" then return "unset" end
    if kind == "boolean" then return value and "on" or "off" end
    if kind == "number" then return V:SafeNumber(value) and string.format("%.5g", value) or "invalid number" end
    if kind == "string" then
        local text = value:gsub("%c", " ")
        if #text > 80 then
            local last = 80
            while last > 0 do
                local byte = text:byte(last + 1)
                if not byte or byte < 128 or byte > 191 then break end
                last = last - 1
            end
            text = text:sub(1, last) .. "…"
        end
        -- Pipe escaping prevents imported profile names or text settings from
        -- becoming WoW color, texture, hyperlink or other markup in the review.
        return '"' .. text:gsub("|", "||") .. '"'
    end
    if kind == "table" then
        local count, keys = 0, {}
        for key in pairs(value) do
            count = count + 1
            -- Unknown keys can contain account/character identifiers. Show
            -- only a fixed vocabulary of cosmetic keys, never nested contents.
            if type(key) == "string" and summaryKeys[key] then keys[#keys+1] = key end
        end
        table.sort(keys)
        local shown = {}
        for i = 1, math.min(5, #keys) do shown[#shown+1] = keys[i] end
        return "{" .. count .. " fields" .. (#shown > 0 and ": " .. table.concat(shown, ", ") or "") .. (#keys > 5 and ", …" or "") .. "}"
    end
    return "unsupported value"
end

function V:ReviewText(review)
    if not review then return "No setup review prepared." end
    local counts = {}
    for _, change in ipairs(review.changes) do counts[change.adapter] = (counts[change.adapter] or 0) + 1 end
    local lines = {"Setup changes loaded addon profiles only. A snapshot is saved first. Reload after applying.",
        tostring(#review.changes) .. " reviewed fields across " .. tostring(#review.adapters) .. " adapters.", ""}
    for _, adapter in ipairs(review.adapters) do
        lines[#lines+1] = (adapter.label or adapter.id) .. " (" .. tostring(counts[adapter.id] or 0) .. " fields): " .. adapter.detail
    end
    for _, entry in ipairs(review.unavailable) do lines[#lines+1] = "Unavailable: " .. entry.id .. " — " .. entry.reason end
    lines[#lines+1] = ""
    lines[#lines+1] = "Reviewed fields (current profile values are never sent anywhere):"
    for _, change in ipairs(review.changes) do
        lines[#lines+1] = "• " .. change.label .. ": " .. reviewedValue(change.before) .. " → " .. reviewedValue(change.after)
    end
    return table.concat(lines, "\n")
end

function V:StatusText()
    local lines = {"vasagoio " .. self.version .. " — native validation pending", "",
        "Preserves native window layouts. Selected addons retain features. No other addon files are modified.",
        "Rounded dark translucent surfaces approximate the Frosted prototype; native scene blur is unavailable.", ""}
    local keys = {}
    for key in pairs(self.status) do keys[#keys+1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local item = self.status[key]
        lines[#lines+1] = key .. " [" .. item.state .. "]: " .. item.detail
    end
    lines[#lines+1] = ""
    lines[#lines+1] = "Disabling vasagoio removes its runtime styling after reload. Applied owner profiles remain until restored separately."
    return table.concat(lines, "\n")
end

function V:OpenOptions(mode)
    if InCombatLockdown() then self:Print("Leave combat before opening setup."); return end
    if not self.options then
        local frame = CreateFrame("Frame", "VasagoioOptions", UIParent)
        frame:SetSize(760, 600); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        self:Surface(frame, .97, 10)
        textLine(frame, "vasagoio", 24, -20, 650)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 24, -56); scroll:SetPoint("BOTTOMRIGHT", -48, 100)
        local body = CreateFrame("Frame", nil, scroll)
        body:SetSize(680, 600); scroll:SetScrollChild(body)
        frame.content = textLine(body, "", 0, 0, 670)
        frame.body = body
        button(frame, "Review setup", 24, 56, 130, function() V:OpenOptions("setup") end)
        frame.apply = button(frame, "Apply reviewed setup", 166, 56, 178, function()
            local ok, message = V:ApplySetup(V.setupReview)
            V:Print(message)
            if ok then V:OpenOptions("status") end
        end)
        button(frame, "Restore profiles", 356, 56, 140, function()
            V.restoreArmed = not V.restoreArmed
            if V.restoreArmed then
                V:Print("Click Restore profiles again to restore the latest snapshot, only if no saved fields changed since setup.")
            else
                local _, message = V:RollbackProfiles(); V:Print(message)
            end
        end)
        button(frame, "Status", 508, 56, 90, function() V:OpenOptions("status") end)
        button(frame, "Reload UI", 610, 56, 126, function() if not InCombatLockdown() then ReloadUI() end end)
        button(frame, "Disable styling", 24, 16, 140, function() V:SetEnabled(false) end)
        button(frame, "Enable styling", 176, 16, 140, function() V:SetEnabled(true) end)
        textLine(frame, "Setup snapshots stay in your local SavedVariables.", 332, -556, 400)
        self.options = frame
        UISpecialFrames = UISpecialFrames or {}; table.insert(UISpecialFrames, "VasagoioOptions")
    end
    local content
    if mode == "setup" then
        local review, reason = self:PrepareSetup()
        content = review and self:ReviewText(review) or reason
    elseif mode == "perf" then content = self:PerformanceText()
    else content = self:StatusText() end
    self.options.content:SetText(content)
    self.options.body:SetHeight(math.max(420, self.options.content:GetStringHeight() + 24))
    self.options.apply:SetEnabled(self.setupReview ~= nil and #self.setupReview.changes > 0)
    self:Surface(self.options, .97, 10)
    self.options:Show()
end

function V:PerformanceText()
    local lines = {"vasagoio " .. self.version .. " — module application timings",
        "Since this UI load. These measure styling passes, not FPS or total addon CPU.",
        "Direct widget callbacks and other addons are outside these timings.", ""}
    local stats = self.runtimeStats and self.runtimeStats.modules or {}
    for _, id in ipairs(self.moduleOrder) do
        local s = stats[id]
        if s then
            local timing = s.timedCalls > 0 and ("%.2f ms total; %.2f ms average; %.2f ms max"):format(
                s.totalMs, s.totalMs / s.timedCalls, s.maxMs) or "Timing unavailable on this client"
            lines[#lines + 1] = ("%s: %d calls; %d errors; %s"):format(id, s.calls, s.errors, timing)
        end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Reopen /vasagoio perf to update this snapshot. Compare FPS in the same scene with styling on/off and reload between tests."
    return table.concat(lines, "\n")
end

function V:SetEnabled(enabled)
    if self.readOnly then self:Print("Settings are not writable."); return end
    if InCombatLockdown() then self:Print("Leave combat before changing enabled state."); return end
    self.db.enabled = enabled
    if enabled then self:Refresh()
    else
        self:ApplyModules() -- Runs each active module's cleanup once, out of combat.
        self:RestoreArtwork()
        -- Keep this addon's own enable/restore controls legible while styling
        -- is disabled. This surface does not affect gameplay frames.
        if self.options then self:Surface(self.options, .97, 10) end
    end
    self:Print(enabled and "Enabled. Reload for consistent owner state." or "Disabled. Reload to remove all existing hooks and styling; owner profiles remain unchanged.")
end

SLASH_VASAGOIO1 = "/vasagoio"
SLASH_VASAGOIO2 = "/vsg"
SlashCmdList.VASAGOIO = function(message)
    local command, argument = (message or ""):match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "off" then V:SetEnabled(false)
    elseif command == "on" then V:SetEnabled(true)
    elseif command == "refresh" then V:Refresh()
    elseif command == "module" then
        local id, choice = argument:match("^(%S+)%s+(%S+)$")
        if id and V.modules[id] and (choice == "on" or choice == "off") and not V.readOnly and not InCombatLockdown() then
            V.db.modules[id] = choice == "on"; V:Refresh(); V:Print("Module preference saved. Reload to fully remove existing styling.")
        else V:Print("Usage: /vasagoio module <module id from Status> on|off (out of combat)") end
    elseif command == "font" then
        if argument ~= "" and not V.readOnly and not InCombatLockdown() then
            V.db.fonts.narrowBold = argument == "reset" and nil or argument
            V:Refresh(); V:Print("Bold font preference saved. Use only a font you are licensed to use; reload and check it visually.")
        else V:Print("Usage: /vasagoio font Interface\\AddOns\\YourMedia\\ArialNarrowBold.ttf, or /vasagoio font reset") end
    else V:OpenOptions(command == "setup" and "setup" or command == "perf" and "perf" or "status") end
end
