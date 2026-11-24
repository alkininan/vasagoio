local _, V = ...
local function px(n) return V:Pixel(n) end
local function safeText(value)
    if V:IsSecret(value) or type(value)~="string" then return "" end
    return value:gsub("|","||")
end
local function label(parent,text,role,x,y,width,height,color)
    local fs=parent:CreateFontString(nil,"OVERLAY")
    V:StyleText(fs,role or "body",color)
    fs:SetPoint("TOPLEFT",px(x),-px(y));fs:SetWidth(px(width))
    if height then fs:SetHeight(px(height)) end
    fs:SetJustifyH("LEFT");fs:SetJustifyV("TOP");fs:SetWordWrap(true)
    fs:SetText(text)
    return fs
end
local function paint(button)
    local enabled=button:IsEnabled()
    local T=V.Tokens
    V:Surface(button,button.hovered and enabled and T.controls.hoverAlpha or T.alpha.window,T.radius,T.colors.raised)
    button:SetAlpha(enabled and 1 or T.controls.disabledAlpha)
    button.marker:SetShown(enabled and (button.selected or button.hovered) and true or false)
end
local function button(view,key,text,x,y,width,callback)
    local b=CreateFrame("Button",nil,view)
    b:SetPoint("TOPLEFT",px(x),-px(y));b:SetSize(px(width),px(32))
    b.label=label(b,text,"body",8,7,width-16,24);b.label:SetJustifyH("CENTER")
    b.marker=b:CreateTexture(nil,"OVERLAY")
    local c=V.Tokens.colors.information
    b.marker:SetColorTexture(c[1],c[2],c[3],1)
    b.marker:SetPoint("BOTTOMLEFT",px(8),px(2));b.marker:SetPoint("BOTTOMRIGHT",-px(8),px(2));b.marker:SetHeight(px(2))
    b:SetScript("OnEnter",function()b.hovered=true;paint(b)end)
    b:SetScript("OnLeave",function()b.hovered=false;paint(b)end)
    b:SetScript("OnClick",function()
        if not b:IsEnabled() then return end
        callback();view:Refresh()
        if V.options and V.RenderSetup then V:RenderSetup() end
    end)
    view.buttons[key]=b
    return b
end
local function snapshot()
    local backups=V.db and V.db.profileBackups
    if type(backups)~="table" then return end
    local last=backups[#backups]
    if type(last)=="table" and type(last.changes)=="table" then return last,#backups end
end
local function writable()
    if not V.db or V.readOnly then return false,"Settings are not writable in this session." end
    if InCombatLockdown() then return false,"Leave combat to change styling, start a test or restore settings." end
    return true
end

function V:CreateToolsView(parent)
    local view=CreateFrame("Frame",nil,parent)
    view:SetAllPoints(parent);view.buttons={};view.cards={}
    local T=self.Tokens
    label(view,"Testing and recovery","heading",24,120,592,24)
    local function card(y,height,title,description)
        local f=CreateFrame("Frame",nil,view)
        f:SetPoint("TOPLEFT",px(24),-px(y));f:SetSize(px(592),px(height))
        V:Surface(f,T.alpha.hud,T.radius)
        view.cards[#view.cards+1]=f
        label(view,title,"body",40,y+16,560,24)
        return label(view,description,"compact",40,y+40,560,40,T.colors.muted)
    end
    card(160,112,"Aura test","Start/reset outside combat. Hide remains available during combat.")
    card(288,112,"Styling and guide","Reload after styling changes. The guide hides during combat.")
    view.restoreDescription=card(416,176,"Restore last snapshot","Restore the most recent preset changes. Later edits are protected by the restore check.")
    view.message=label(view,"","compact",40,544,560,48,T.colors.muted)
    local function message(text,failed)
        view.result,view.failed=text,failed
    end
    local function failure(text)
        message(text,true)
        if V.Report then V:Report("tools","error",text) end
    end
    function view:CancelConfirmation()
        if self.confirmSnapshot then self.result,self.failed=nil,nil end
        self.confirmSnapshot,self.confirmCount=nil,nil
    end
    local function cancelConfirmation()
        view:CancelConfirmation()
    end
    local function guard()
        local ok,reason=writable()
        if not ok then cancelConfirmation();message(reason,true) end
        return ok
    end
    local function aura(command)
        if command~="hide" then
            if not guard() then return end
            if not V.db.enabled then message("Turn styling on before starting the aura test.",true);return end
        end
        if type(V.AuraProbeCommand)~="function" then message("The aura test is unavailable in this build.",true);return end
        local ok=pcall(V.AuraProbeCommand,V,command)
        if not ok then failure("The aura test request failed. Check Report and reload before retrying.");return end
        message(command=="hide" and "Aura test hide requested." or "Aura test requested. Its result appears in chat.")
    end
    button(view,"auraShow","Show",40,224,176,function()aura("show")end)
    button(view,"auraHide","Hide",232,224,176,function()aura("hide")end)
    button(view,"auraReset","Reset position",424,224,176,function()aura("reset")end)
    local function styling(enabled)
        if not guard() then return end
        cancelConfirmation()
        if type(V.SetEnabled)~="function" then message("Styling controls are unavailable in this build.",true);return end
        local ok=pcall(V.SetEnabled,V,enabled)
        if not ok then failure("Styling could not finish updating. Check Report and reload before retrying.");return end
        if V.db.enabled~=enabled then message("Styling was not changed. Check Report before retrying.",true);return end
        message(enabled and "Styling is on. Reload for consistent addon state." or "Styling is off. Reload to finish cleanup; applied profiles are kept.")
    end
    button(view,"stylingOn","Styling on",40,352,176,function()styling(true)end)
    button(view,"stylingOff","Styling off",232,352,176,function()styling(false)end)
    button(view,"guide","Hide guide",424,352,176,function()
        if not guard() then return end
        if type(V.ToggleQuestGuide)~="function" then message("Guide presentation is unavailable.",true);return end
        local ok,changed,reason=pcall(V.ToggleQuestGuide,V)
        if not ok then failure("Guide presentation could not be changed. Check Report before retrying.");return end
        message(type(reason)=="string" and reason or "Guide presentation requested.",changed~=true)
    end)
    button(view,"restore","Restore last snapshot",40,504,360,function()
        if not guard() then return end
        local last,count=snapshot()
        if not last then cancelConfirmation();message("There is no setup snapshot to restore.",true);return end
        if not view.confirmSnapshot then
            view.confirmSnapshot,view.confirmCount=last,count
            message("Confirm to restore this snapshot, or cancel to keep current settings.")
            return
        end
        if last~=view.confirmSnapshot or count~=view.confirmCount then
            cancelConfirmation();message("The latest snapshot changed. Review Restore again.",true);return
        end
        cancelConfirmation()
        if type(V.RollbackProfiles)~="function" then message("Profile restoration is unavailable in this build.",true);return end
        local ok,restored,reason=pcall(V.RollbackProfiles,V)
        if not ok then failure("Profile restoration failed. Check Report and reload before retrying.");return end
        message(type(reason)=="string" and reason or (restored and "Snapshot restored. Reload to finish." or "The snapshot was not restored."),restored~=true)
    end)
    button(view,"cancel","Cancel",416,504,184,function()
        cancelConfirmation();message("Restoration cancelled. Settings are unchanged.")
    end)
    function view:Refresh()
        local canWrite,blocked=writable()
        local on=V.db and V.db.enabled==true or false
        local last,count=snapshot()
        if self.confirmSnapshot and (not canWrite or last~=self.confirmSnapshot or count~=self.confirmCount) then
            cancelConfirmation()
            message(canWrite and "The latest snapshot changed. Review Restore again." or blocked,true)
        end
        local auraAvailable=type(V.AuraProbeCommand)=="function"
        self.buttons.auraShow:SetEnabled(canWrite and on and auraAvailable)
        self.buttons.auraReset:SetEnabled(canWrite and on and auraAvailable)
        self.buttons.auraHide:SetEnabled(auraAvailable)
        local stylingAvailable=canWrite and type(V.SetEnabled)=="function"
        self.buttons.stylingOn:SetEnabled(stylingAvailable and not on)
        self.buttons.stylingOff:SetEnabled(stylingAvailable and on)
        self.buttons.stylingOn.selected=on
        self.buttons.stylingOff.selected=not on
        self.buttons.guide:SetEnabled(canWrite and on and type(V.ToggleQuestGuide)=="function")
        local guideHidden=type(V.IsQuestGuideHidden)=="function" and V:IsQuestGuideHidden()
        self.buttons.guide.label:SetText(guideHidden and "Show guide" or "Hide guide")
        self.buttons.restore:SetEnabled(canWrite and last~=nil and type(V.RollbackProfiles)=="function")
        self.buttons.restore.label:SetText(self.confirmSnapshot and "Confirm restore" or "Restore last snapshot")
        self.buttons.restore.selected=self.confirmSnapshot~=nil
        self.buttons.cancel:SetEnabled(self.confirmSnapshot~=nil)
        self.buttons.cancel:SetShown(self.confirmSnapshot~=nil)
        self.restoreDescription:SetText(self.confirmSnapshot and "Restore the most recent preset snapshot? Current addon settings will be checked before anything changes."
            or "Restore the most recent preset changes. Later edits are protected by the restore check.")
        local text=not canWrite and blocked or self.result or (not last and "There is no setup snapshot to restore." or "")
        self.message:SetText(safeText(text))
        local c=(not canWrite or self.failed) and T.colors.attention or T.colors.muted
        self.message:SetTextColor(c[1],c[2],c[3],1)
        for _,panel in ipairs(self.cards)do V:Surface(panel,T.alpha.hud,T.radius)end
        for _,control in pairs(self.buttons)do paint(control)end
    end
    view:SetScript("OnShow",function()view:Refresh()end)
    view:SetScript("OnHide",function()cancelConfirmation()end)
    view:Refresh()
    return view
end
