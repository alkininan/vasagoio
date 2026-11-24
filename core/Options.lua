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
local function px(n) return V:Pixel(n) end
local function plainText(parent, role)
    local text = parent:CreateFontString(nil, "OVERLAY")
    V:StyleText(text, role or "body")
    text:SetJustifyH("LEFT")
    return text
end
local function safeText(value)
    return not V:IsSecret(value) and type(value) == "string" and value:gsub("|", "||") or ""
end
local function colorText(text, role)
    local c = V.Tokens.colors[role] or V.Tokens.colors.text
    text:SetTextColor(c[1], c[2], c[3], 1)
end
local function paintButton(b)
    local enabled = b:IsEnabled()
    V:Surface(b, b.hovered and enabled and .96 or .84, 10, V.Tokens.colors.raised or V.Tokens.colors.panel)
    b:SetAlpha(enabled and 1 or .45)
    b.marker:SetShown(enabled and b.primary == true)
end
local function actionButton(parent, label, x, callback)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(px(288), px(40)); b:SetPoint("BOTTOMLEFT", px(x), px(24))
    b.label = plainText(b, "body"); b.label:SetPoint("CENTER"); b.label:SetText(label)
    b.marker = b:CreateTexture(nil, "OVERLAY")
    local c = V.Tokens.colors.information
    b.marker:SetColorTexture(c[1], c[2], c[3], 1)
    b.marker:SetPoint("BOTTOMLEFT", px(8), px(2)); b.marker:SetPoint("BOTTOMRIGHT", -px(8), px(2)); b.marker:SetHeight(px(2))
    b:SetScript("OnEnter", function() b.hovered=true; paintButton(b) end)
    b:SetScript("OnLeave", function() b.hovered=false; paintButton(b) end)
    b:SetScript("OnClick", function() if b:IsEnabled() then callback() end end)
    return b
end
local function closeButton(frame)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(px(24), px(24)); close:SetPoint("TOPRIGHT", -px(16), -px(16))
    close.label=plainText(close,"heading"); close.label:SetPoint("CENTER"); close.label:SetText("×")
    close:SetScript("OnClick",function() frame:Hide() end)
    return close
end
local function makeScroll(frame, top, bottom)
    local scroll=CreateFrame("ScrollFrame",nil,frame)
    scroll:SetPoint("TOPLEFT",px(24),-px(top)); scroll:SetPoint("BOTTOMRIGHT",-px(40),px(bottom))
    scroll:EnableMouseWheel(true)
    local body=CreateFrame("Frame",nil,scroll); body:SetSize(px(576),px(1)); scroll:SetScrollChild(body)
    local slider=CreateFrame("Slider",nil,frame)
    slider:SetPoint("TOPRIGHT",-px(24),-px(top)); slider:SetPoint("BOTTOMRIGHT",-px(24),px(bottom)); slider:SetWidth(px(8))
    slider:SetOrientation("VERTICAL"); slider:SetMinMaxValues(0,0); slider:SetValueStep(px(24))
    local thumb=slider:CreateTexture(nil,"OVERLAY"); thumb:SetSize(px(8),px(32))
    local c=V.Tokens.colors.information; thumb:SetColorTexture(c[1],c[2],c[3],.55); slider:SetThumbTexture(thumb)
    slider:SetScript("OnValueChanged",function(_,value) scroll:SetVerticalScroll(value) end)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        slider:SetValue(math.max(0,math.min(slider.maximum or 0,slider:GetValue()-delta*px(32))))
    end)
    frame.scroll,frame.body,frame.slider=scroll,body,slider
end
local function fitScroll(frame, contentHeight, viewportHeight)
    frame.body:SetHeight(math.max(contentHeight,viewportHeight))
    local max=math.max(0,contentHeight-viewportHeight)
    frame.slider.maximum=max; frame.slider:SetMinMaxValues(0,max)
    frame.slider:SetValue(math.min(frame.slider:GetValue() or 0,max)); frame.slider:SetShown(max>0)
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

local stateLabels={ready="Ready",applied="Applied",reload="Reload needed",attention="Needs attention",skipped="Skipped",off="Off"}
local stateColors={ready="information",applied="information",reload="information",attention="attention",skipped="muted",off="muted"}

function V:RenderSetup()
    local frame=self.options
    if not frame then return end
    local model=self:BuildSetupStatus(frame.review,frame.reason)
    frame.model=model
    frame.summary:SetText(safeText(frame.messageTitle or model.title))
    frame.description:SetText(safeText(frame.message or model.description))
    colorText(frame.summary,(frame.messageFailed or model.title=="Needs attention") and "attention" or "information")
    local rows,order={},{}
    for i,row in ipairs(model.rows) do rows[i]=row; order[row]=i end
    table.sort(rows,function(a,b)
        local aa,bb=a.state=="attention",b.state=="attention"
        if aa~=bb then return aa end
        return order[a]<order[b]
    end)
    local y=0
    for i,item in ipairs(rows) do
        local row=frame.rows[i]
        if not row then
            row=CreateFrame("Frame",nil,frame.body)
            row.label=plainText(row,"body"); row.label:SetPoint("TOPLEFT",px(12),-px(8)); row.label:SetWidth(px(332))
            row.status=plainText(row,"compact"); row.status:SetPoint("TOPRIGHT",-px(12),-px(8)); row.status:SetWidth(px(196)); row.status:SetJustifyH("RIGHT")
            row.detail=plainText(row,"compact"); row.detail:SetPoint("TOPLEFT",px(12),-px(32)); row.detail:SetWidth(px(544))
            frame.rows[i]=row
        end
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y); row:SetWidth(px(576))
        row.label:SetText(safeText(item.label)); row.status:SetText(stateLabels[item.state] or "Needs attention")
        colorText(row.status,stateColors[item.state] or "attention"); colorText(row.detail,"muted")
        local explain=item.state=="attention" or item.state=="skipped" or item.state=="off"
        row.detail:SetText(explain and safeText(item.detail) or ""); row.detail:SetShown(explain)
        local height=px(32)
        if explain then height=px(40)+math.ceil((row.detail:GetStringHeight() or px(16))/px(8))*px(8) end
        row:SetHeight(height); V:Surface(row,.40,10); row:Show()
        y=y+height+px(8)
    end
    for i=#rows+1,#frame.rows do frame.rows[i]:Hide() end
    fitScroll(frame,math.max(0,y-px(8)),px(368))
    local combat=InCombatLockdown()
    frame.apply:SetEnabled(model.canApply and not combat)
    frame.reload:SetEnabled(model.needsReload and not combat)
    frame.apply.primary=model.canApply and not model.needsReload
    frame.reload.primary=model.needsReload
    paintButton(frame.apply); paintButton(frame.reload)
    if combat then frame.description:SetText("Leave combat to apply the preset or reload.") end
end

function V:OpenDiagnostics(mode)
    if InCombatLockdown() then self:Print("Leave combat before opening diagnostics."); return end
    if not self.diagnostics then
        local f=CreateFrame("Frame","VasagoioDiagnostics",UIParent)
        f:SetSize(px(720),px(608)); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:EnableMouse(true)
        f.close=closeButton(f); makeScroll(f,64,24)
        f.content=plainText(f.body,"compact"); f.content:SetPoint("TOPLEFT"); f.content:SetWidth(px(568))
        self.diagnostics=f
        UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"VasagoioDiagnostics")
    end
    local f=self.diagnostics
    local content=mode=="perf" and self:PerformanceText() or mode=="details" and self:ReviewText(self.setupReview) or self:StatusText()
    f.content:SetText(content); fitScroll(f,f.content:GetStringHeight()+px(16),px(520))
    V:Surface(f,.97,10); f:Show()
end

function V:OpenOptions(mode)
    if mode=="perf" or mode=="details" or mode=="report" then return self:OpenDiagnostics(mode) end
    if InCombatLockdown() then self:Print("Leave combat before opening setup."); return end
    if not self.options then
        local frame=CreateFrame("Frame","VasagoioOptions",UIParent)
        frame:SetSize(px(640),px(608)); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
        frame:SetClampedToScreen(true); frame:EnableMouse(true); frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton"); frame:SetScript("OnDragStart",frame.StartMoving); frame:SetScript("OnDragStop",frame.StopMovingOrSizing)
        frame.close=closeButton(frame)
        frame.title=plainText(frame,"title"); frame.title:SetPoint("TOPLEFT",px(24),-px(24)); frame.title:SetText("vasagoio")
        local version=plainText(frame,"compact"); version:SetPoint("TOPRIGHT",-px(56),-px(28)); version:SetText(self.version); colorText(version,"muted")
        frame.summary=plainText(frame,"heading"); frame.summary:SetPoint("TOPLEFT",px(24),-px(64)); frame.summary:SetWidth(px(592))
        frame.description=plainText(frame,"compact"); frame.description:SetPoint("TOPLEFT",px(24),-px(96)); frame.description:SetWidth(px(592)); frame.description:SetHeight(px(40))
        makeScroll(frame,144,96); frame.rows={}
        frame.note=plainText(frame,"compact"); frame.note:SetPoint("BOTTOMLEFT",px(24),px(72)); frame.note:SetWidth(px(592)); frame.note:SetText("Checks cover addons, settings and reported errors."); colorText(frame.note,"muted")
        frame.apply=actionButton(frame,"Apply preset",24,function()
            if InCombatLockdown() then self:RenderSetup(); return end
            local ok,message=self:ApplySetup(frame.review)
            frame.messageTitle=ok and "Reload needed" or "Needs attention"
            frame.message=ok and "Preset applied. Reload UI to activate the changes." or message
            frame.messageFailed=not ok
            if self.profileReloadPending then frame.review=nil; frame.reason=nil
            else frame.review,frame.reason=self:PrepareSetup() end
            self:RenderSetup()
        end)
        frame.reload=actionButton(frame,"Reload UI",328,function()
            if not InCombatLockdown() and frame.model and frame.model.needsReload then ReloadUI() end
        end)
        self.options=frame
        UISpecialFrames=UISpecialFrames or {}; table.insert(UISpecialFrames,"VasagoioOptions")
    end
    local frame=self.options
    frame.message,frame.messageTitle,frame.messageFailed=nil,nil,nil
    if self.profileReloadPending then frame.review,frame.reason=nil,nil
    else frame.review,frame.reason=self:PrepareSetup() end
    V:Surface(frame,.97,10); self:RenderSetup(); frame:Show()
end

for _,event in ipairs({"PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED"}) do
    V:On(event,function()
        if V.options and V.options:IsShown() then V:RenderSetup() end
    end)
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
    self.uiReloadPending = true
    if enabled then self:Refresh()
    else
        self:ApplyModules() -- Runs each active module's cleanup once, out of combat.
        self:RestoreArtwork()
        -- Keep this addon's own enable/restore controls legible while styling
        -- is disabled. This surface does not affect gameplay frames.
        if self.options then self:Surface(self.options, .97, 10) end
    end
    if self.options and self.options:IsShown() then self:RenderSetup() end
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
    elseif command == "restore" then
        if argument ~= "confirm" then V:Print("To restore the latest setup snapshot, type /vasagoio restore confirm. Later edits are preserved by conflict checks.")
        else
            local ok,message=V:RollbackProfiles(); V:Print(message)
            if V.options and V.options:IsShown() then
                V.options.messageTitle=ok and "Reload needed" or "Needs attention"
                V.options.message=message; V.options.messageFailed=not ok; V:RenderSetup()
            end
        end
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
    else V:OpenOptions((command == "perf" or command == "details" or command == "report") and command or "setup") end
end
