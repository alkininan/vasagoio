local _, V = ...
-- Scoped cosmetic primitives. No original frame bounds, scripts, attributes,
-- text contents, values, visibility drivers or gameplay actions are replaced.
local I = {records = setmetatable({}, {__mode = "k"}), watched = setmetatable({}, {__mode = "k"})}
V.InteriorSkin = I
local unpack = unpack
local BACKGROUND = {"Bg", "Background", "TitleBg", "TitleBackground", "TopTileStreaks"}
local NINE = {"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center"}
local INPUT = {"Left", "Middle", "Right", "LeftTexture", "MiddleTexture", "RightTexture", "LeftTex", "MidTex", "RightTex"}

local function available(object)
    if V:IsSecret(object) or (type(object) ~= "table" and type(object) ~= "userdata") then return false end
    if object.__vasagoio then return false end
    if object.IsForbidden then
        local ok, forbidden = pcall(object.IsForbidden, object)
        if not ok or V:IsSecret(forbidden) or forbidden then return false end
    end
    -- Pooled confirmations can become death/recovery dialogs. The exclusion
    -- must also hold when a generic walk enters from an unrelated ancestor.
    local windows=V.WindowSkin
    if windows and windows.NativeRecoveryDialog and windows:NativeRecoveryDialog(object) then return false end
    return true
end
I.Available = available
local function configured(owner)
    if not V.db or not V.db.enabled then return false end
    if owner and V.modules and V.modules[owner] and not V:IsModuleEnabled(owner) then return false end
    return true
end
local function running(owner)
    return not V.profileReloadPending and configured(owner)
end
local function editable(owner)
    return running(owner) and not InCombatLockdown()
end
local function claim(r, owner)
    r.owners = r.owners or {}
    r.owners[owner or false] = true
    r.owner = owner
end
local function activeOwner(r, allowPending)
    local test = allowPending and configured or running
    local current = r.owner or false
    if r.owners and r.owners[current] and test(r.owner) then return true end
    for owner in pairs(r.owners or {}) do
        local candidate = owner ~= false and owner or nil
        if test(candidate) then r.owner = candidate; return true end
    end
    return false
end
local function record(object, owner)
    local r = I.records[object]
    if not r then r = {object = object}; I.records[object] = r end
    claim(r, owner)
    return r
end
local function rgba(object, getter)
    if not object[getter] then return end
    local ok, r, g, b, a = pcall(object[getter], object)
    if not ok then return end
    r, g, b, a = V:SafeNumber(r), V:SafeNumber(g), V:SafeNumber(b), V:SafeNumber(a)
    if r and g and b then return {r, g, b, a or 1} end
end
local function kind(object)
    if not available(object) or not object.GetObjectType then return nil end
    local ok, value = pcall(object.GetObjectType, object)
    if ok and not V:IsSecret(value) and type(value) == "string" then return value end
end
local function path(root, value)
    if type(value) ~= "string" then return available(value) and value or nil end
    local node = root
    for part in value:gmatch("[^.]+") do
        if not available(node) then return nil end
        node = node[tonumber(part) or part]
    end
    return available(node) and node or nil
end
I.Path = path

function I:Hide(object, owner)
    if not editable(owner) or not available(object) or not object.SetAlpha then return false end
    local r = record(object, owner)
    if r.alpha == nil then
        local ok, value = pcall(object.GetAlpha or function() return 1 end, object)
        value = ok and V:SafeNumber(value)
        if not value then return false end
        r.alpha = value
    end
    object:SetAlpha(0)
    return true
end

function I:Text(text, role, preserveColor, owner)
    if not editable(owner) or not available(text) or not text.GetFont then return false end
    -- Gargul exposes a rem-based SetFont wrapper and retains the native method.
    local setter = type(text._SetFont) == "function" and text._SetFont or text.SetFont
    if type(setter) ~= "function" then return false end
    local ok, oldPath, size, flags = pcall(text.GetFont, text)
    if not ok or V:IsSecret(oldPath) or V:IsSecret(flags) then return false end
    size = V:SafeNumber(size)
    if not size or size <= 0 then return false end
    local r = record(text, owner)
    -- A generic region walk follows explicit control styling. Preserve the
    -- numeric/title role chosen by that audited control instead of replacing
    -- Count's Arial Narrow face with the generic body face on the same pass.
    if (not role or role == "body") and r.role then role = r.role end
    r.role = role or "body"
    if not r.font then
        r.font = {oldPath, size, flags or ""}; r.fontSetter = setter
        r.textColor = rgba(text, "GetTextColor")
        r.shadow = rgba(text, "GetShadowColor")
        if text.GetShadowOffset then
            local good, x, y = pcall(text.GetShadowOffset, text)
            x, y = good and V:SafeNumber(x), good and V:SafeNumber(y)
            if x and y then r.shadowOffset = {x,y} end
        end
    end
    local font, _, fontFlags = V:Font(r.role)
    -- SetFont can invalidate owner layout even when the requested face is
    -- already active. Preserve the native size and avoid unchanged writes.
    if oldPath ~= font or (flags or "") ~= fontFlags then
        local loaded, result = pcall(setter, text, font, size, fontFlags)
        if not loaded or result == false then return false end
    end
    -- Neutral black narrative text cannot remain black on a dark panel.
    -- Preserve saturated quality, class, reaction, red requirements and links.
    local color = rgba(text, "GetTextColor")
    local black = color and math.max(color[1],color[2],color[3]) < .25
        and math.max(color[1],color[2],color[3]) - math.min(color[1],color[2],color[3]) < .12
    local nativeGold = false
    if role == "control" and color and text.GetFontObject then
        local good, fontObject = pcall(text.GetFontObject,text)
        if good and available(fontObject) and fontObject.GetName then
            local named, name = pcall(fontObject.GetName,fontObject)
            nativeGold = named and not V:IsSecret(name) and type(name)=="string" and name:match("^GameFontNormal")
                and math.abs(color[1]-1)<.02 and math.abs(color[2]-.82)<.04 and color[3]<.03
        end
    end
    if preserveColor == false or black or nativeGold then
        local c = V.Tokens.colors.text
        if text.SetTextColor then text:SetTextColor(c[1],c[2],c[3],color and color[4] or 1); r.changedColor = true end
    end
    if text.SetShadowColor then text:SetShadowColor(0,0,0,.9) end
    if text.SetShadowOffset then text:SetShadowOffset(V:Pixel(1),-V:Pixel(1)) end
    return true
end

local function hideFields(frame, keys, owner)
    for _, key in ipairs(keys) do I:Hide(frame[key], owner) end
end
local function clearBackdrop(frame, owner)
    if not frame.SetBackdropColor then return end
    local r = record(frame, owner)
    if not r.backdrop then r.backdrop = rgba(frame, "GetBackdropColor") end
    if not r.border then r.border = rgba(frame, "GetBackdropBorderColor") end
    if r.backdrop then frame:SetBackdropColor(0,0,0,0) end
    if r.border and frame.SetBackdropBorderColor then frame:SetBackdropBorderColor(0,0,0,0) end
end

function I:Panel(frame, panelKind, owner)
    if not editable(owner) or not available(frame) or not frame.CreateTexture then return false end
    local r = record(frame, owner)
    r.panelKind = panelKind or "panel"
    clearBackdrop(frame, owner)
    hideFields(frame, BACKGROUND, owner)
    if available(frame.NineSlice) then hideFields(frame.NineSlice, NINE, owner) end
    local colors, alpha = V.Tokens.colors, V.Tokens.alpha
    local color, opacity = colors.panel, alpha.window
    if panelKind == "inset" then color, opacity = colors.deep, .40 end
    if panelKind == "input" then color, opacity = colors.deep, alpha.input end
    if panelKind == "button" then color, opacity = colors.raised, .84 end
    if panelKind == "track" then color, opacity = colors.track, .56 end
    r.baseColor, r.baseAlpha = color, opacity
    r.surface = V:Surface(frame, opacity, V.Tokens.radius, color)
    if frame.TitleText then self:Text(frame.TitleText, "heading", false, owner) end
    return r
end

local function safeBoolean(value)
    if not V:IsSecret(value) and type(value) == "boolean" then return value end
end
local function state(r)
    if not activeOwner(r) or InCombatLockdown() or not available(r.object) then return end
    local frame = r.object
    local enabled = true
    if frame.IsEnabled then
        local ok, value = pcall(frame.IsEnabled, frame)
        if ok then value = safeBoolean(value); if value ~= nil then enabled = value end end
    end
    local selected = r.selected == true
    if r.useChecked and frame.GetChecked then
        local ok, checked = pcall(frame.GetChecked,frame)
        checked = ok and safeBoolean(checked)
        if checked ~= nil then selected = checked end
    end
    local color, alpha = r.baseColor or V.Tokens.colors.raised, r.baseAlpha or .84
    -- Accepted interaction treatment: near-black fill, blue marker only.
    if selected or r.focus then color = V.Tokens.colors.panel
    elseif r.pressed then color, alpha = V.Tokens.colors.deep, V.Tokens.controls.pressedAlpha
    elseif r.hover then color, alpha = V.Tokens.colors.raised, V.Tokens.controls.hoverAlpha end
    -- Native tab systems disable the selected tab to prevent clicking it again.
    -- That selected state must remain legible rather than look unavailable.
    if not enabled and not selected then alpha = alpha * V.Tokens.controls.disabledAlpha end
    if r.surface then r.surface = V:Surface(frame,alpha,V.Tokens.radius,color) end
    if r.signal then
        local c = V.Tokens.colors.information
        r.signal:SetColorTexture(c[1],c[2],c[3],(enabled or selected) and 1 or .4)
        r.signal:SetShown(selected or r.focus == true)
    end
end

function I:SetSelected(frame, selected)
    if not available(frame) then return false end
    selected = safeBoolean(selected)
    if selected == nil then return false end
    local r = self.records[frame]
    if not r then return false end
    r.selected = selected; state(r)
    return true
end
local function hookState(frame, r, event, key, value)
    if not frame.HookScript then return end
    local has = not frame.HasScript or frame:HasScript(event)
    if not has then return end
    pcall(frame.HookScript, frame, event, function()
        if not activeOwner(r) then return end
        r[key] = value
        if event == "OnLeave" then r.pressed = false end
        if InCombatLockdown() then V:Refresh("interior state deferred", r.owner) else state(r) end
    end)
end
local function signal(frame, r)
    if r.signal then return end
    r.signal = frame:CreateTexture(nil,"OVERLAY")
    r.signal.__vasagoio = true
    r.signal.ignoreInLayout = true
    if frame.MarkIgnoreInLayout then pcall(frame.MarkIgnoreInLayout,frame,r.signal) end
    local t = V.Tokens.controls
    r.signal:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",V:Pixel(t.markerInset),V:Pixel(t.markerBottom))
    r.signal:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-V:Pixel(t.markerInset),V:Pixel(t.markerBottom))
    r.signal:SetHeight(V:Pixel(t.markerHeight)); r.signal:Hide()
end
local function bindStates(frame, r)
    if r.stateHooks then return end
    r.stateHooks = true
    hookState(frame,r,"OnEnter","hover",true); hookState(frame,r,"OnLeave","hover",false)
    hookState(frame,r,"OnMouseDown","pressed",true); hookState(frame,r,"OnMouseUp","pressed",false)
    hookState(frame,r,"OnHide","pressed",false)
    hookState(frame,r,"OnEditFocusGained","focus",true); hookState(frame,r,"OnEditFocusLost","focus",false)
    if hooksecurefunc then
        for _, method in ipairs({"Enable","Disable","SetEnabled","SetChecked"}) do
            if type(frame[method]) == "function" then hooksecurefunc(frame,method,function() state(r) end) end
        end
    end
end

local function icon(frame)
    for _, name in ipairs({"Icon","icon","IconTexture","iconTexture"}) do
        if available(frame[name]) and frame[name].SetTexture then return frame[name] end
    end
end
local function buttonText(frame)
    if frame.GetFontString then
        local ok, text = pcall(frame.GetFontString,frame)
        if ok and available(text) then return text end
    end
    for _, key in ipairs({"Text","Label","label","text"}) do
        local value = frame[key]
        if available(value) and value.GetFont and value.SetFont then return value end
    end
end
local function buttonBackground(frame, owner)
    hideFields(frame, INPUT, owner)
    for _, method in ipairs({"GetNormalTexture","GetPushedTexture","GetDisabledTexture","GetHighlightTexture"}) do
        if frame[method] then
            local ok, texture = pcall(frame[method],frame)
            if ok then I:Hide(texture,owner) end
        end
    end
end
local function tintTexture(texture, owner)
    if not available(texture) or not texture.SetVertexColor then return end
    local r = record(texture,owner)
    if not r.vertex then r.vertex = rgba(texture,"GetVertexColor") end
    if texture.IsDesaturated and texture.SetDesaturated then
        local ok, value = pcall(texture.IsDesaturated,texture)
        value = ok and safeBoolean(value)
        if value ~= nil then
            if r.desaturated == nil then r.desaturated = value end
            texture:SetDesaturated(true)
        end
    end
    local c = V.Tokens.colors.information
    texture:SetVertexColor(c[1],c[2],c[3],1)
end

local CHROME_TEXTURES = {
    ["interface\\buttons\\ui-panel-button-up"]=true, ["interface\\buttons\\ui-panel-button-down"]=true,
    ["interface\\buttons\\ui-panel-button-disabled"]=true, ["interface\\buttons\\ui-panel-button-highlight"]=true,
    ["interface\\buttons\\ui-checkbox-up"]=true, ["interface\\buttons\\ui-checkbox-down"]=true,
}
local function chromeTexture(texture)
    if not available(texture) then return false end
    if texture.GetTexture then
        local good, file = pcall(texture.GetTexture,texture)
        if good and not V:IsSecret(file) and type(file)=="string" then
            file = file:lower():gsub("/","\\"):gsub("%.blp$",""):gsub("%.tga$","")
            if CHROME_TEXTURES[file] then return true end
            for _, stateName in ipairs({"up","down","disabled"}) do
                for _, segment in ipairs({"left","middle","right"}) do
                    if file == "interface\\buttons\\ui-dialogbox-goldbutton-"..stateName.."-"..segment then return true end
                end
            end
        end
    end
    if texture.GetAtlas then
        local good, atlas = pcall(texture.GetAtlas,texture)
        if good and not V:IsSecret(atlas) and type(atlas)=="string" then
            return atlas == "common-button-square-gray-up" or atlas == "common-button-square-gray-down"
        end
    end
    return false
end
local function knownChrome(frame)
    -- NormalTexture can be content: e.g. native gold/silver/copper coin buttons.
    if frame.GetNormalTexture then
        local ok, normal = pcall(frame.GetNormalTexture,frame)
        if ok and chromeTexture(normal) then return true end
    end
    -- SecureUIPanelTemplates uses three regions instead of NormalTexture.
    if not (available(frame.Left) and available(frame.Middle) and available(frame.Right)) then return false end
    if chromeTexture(frame.Left) and chromeTexture(frame.Middle) and chromeTexture(frame.Right) then return true end
    -- Clients may return numeric file IDs. The exact native handler identifies
    -- the audited template without treating arbitrary three-part art as chrome.
    if type(UIPanelButton_OnMouseDown)=="function" and frame.GetScript then
        local ok, handler = pcall(frame.GetScript,frame,"OnMouseDown")
        return ok and not V:IsSecret(handler) and handler == UIPanelButton_OnMouseDown
    end
    return false
end

function I:Control(frame, controlKind, owner, options)
    if not editable(owner) or not available(frame) then return false end
    local r = record(frame,owner)
    if controlKind == "icon" then
        local art = icon(frame)
        if art then V:MaskIcon(art,V.Tokens.radius) end
        if frame.Count then self:Text(frame.Count,"count",true,owner) end
        return art ~= nil
    end
    local text = buttonText(frame)
    -- Icon actions, item slots and talent nodes retain their native status art.
    if controlKind == "button" and icon(frame) and not (options and options.skinIconButton) then
        if text then self:Text(text,"body",true,owner) end
        if frame.Count then self:Text(frame.Count,"count",true,owner) end
        return true
    end
    if controlKind == "checkbox" then
        -- Keep the owner's checked/unchecked glyph and its actual state.
        if text then self:Text(text,"body",true,owner) end
        if not (options and options.generic) or knownChrome(frame) then
            self:Panel(frame,"button",owner); buttonBackground(frame,owner)
            r.useChecked = true; bindStates(frame,r); state(r)
        end
        if frame.GetCheckedTexture then
            local ok, texture = pcall(frame.GetCheckedTexture,frame)
            if ok then tintTexture(texture,owner) end
        end
        return true
    end
    if controlKind == "slider" or controlKind == "scrollbar" then
        if not (options and options.generic) then self:Panel(frame,"track",owner) end
        if frame.GetThumbTexture then
            local ok, texture = pcall(frame.GetThumbTexture,frame)
            if ok then tintTexture(texture,owner) end
        end
        if available(frame.Track) then self:Panel(frame.Track,"track",owner) end
        if text then self:Text(text,"body",true,owner) end
        return true
    end
    if controlKind == "editbox" then
        self:Panel(frame,"input",owner); hideFields(frame,INPUT,owner)
        self:Text(frame,"control",true,owner)
        signal(frame,r); bindStates(frame,r); state(r)
        return true
    end
    if controlKind == "button" or controlKind == "tab" or controlKind == "dropdown" then
        -- Arrow-only, close and other icon buttons retain their recognizable art.
        if not text and controlKind == "button" then return false end
        if options and options.generic and controlKind == "button" and not knownChrome(frame) then
            if text then self:Text(text,"control",true,owner) end
            return true
        end
        self:Panel(frame,"button",owner)
        buttonBackground(frame,owner)
        if text then self:Text(text,"control",true,owner) end
        if controlKind == "tab" then signal(frame,r) end
        bindStates(frame,r); state(r)
        return true
    end
    return false
end

function I:Watch(root, opts)
    if not available(root) then return false end
    opts = opts or {}
    local watch = self.watched[root]
    if watch then watch.opts = opts; claim(watch,opts.owner); return true end
    watch = {opts = opts}; claim(watch,opts.owner); self.watched[root] = watch
    if root.HookScript then
        pcall(root.HookScript,root,"OnShow",function()
            if not activeOwner(watch) then return end
            for owner in pairs(watch.owners or {}) do
                local id = owner ~= false and owner or nil
                if running(id) then V:Refresh("window interior shown", id) end
            end
        end)
    end
    return true
end

local function replaceSkinner(frame, owner, visited)
    local replaced = false
    for _, key in ipairs({"sf","sb"}) do
        local decoration = frame[key]
        if available(decoration) and decoration.GetParent and decoration.GetChildren then
            local ok, parent = pcall(decoration.GetParent,decoration)
            local good, children = pcall(function() return {decoration:GetChildren()} end)
            -- Exclude reverse-parent wrappers and decorations with live children.
            if ok and not V:IsSecret(parent) and parent == frame and good and #children == 0 then
                I:Hide(decoration,owner); visited[decoration] = true
                local existing = I.records[frame]
                if key == "sb" and buttonText(frame) and not icon(frame) then
                    I:Control(frame,"button",owner)
                elseif not existing or not existing.surface then I:Panel(frame,"panel",owner) end
                -- Skinner deliberately puts some shells below their owner's
                -- content (notably WorldMapFrame.BorderFrame at LOW strata).
                -- Inheriting the owner's higher strata would darken the map
                -- and its controls with a new foreground panel.
                local record=I.records[frame]
                local surface=record and record.surface
                if surface and decoration.GetFrameStrata and decoration.GetFrameLevel then
                    local read,layer,level=pcall(function() return decoration:GetFrameStrata(),decoration:GetFrameLevel() end)
                    local layers={BACKGROUND=true,LOW=true,MEDIUM=true,HIGH=true,DIALOG=true,FULLSCREEN=true,FULLSCREEN_DIALOG=true,TOOLTIP=true}
                    if read and not V:IsSecret(layer) and type(layer)=="string" and layers[layer]
                        and V:SafeNumber(level) and level>=0 then
                        if surface.SetFrameStrata then surface:SetFrameStrata(layer) end
                        if surface.SetFrameLevel then surface:SetFrameLevel(level) end
                    end
                end
                replaced = true
            end
        end
    end
    return replaced
end

function I:Apply(root, opts)
    opts = opts or {}
    local stats = {nodes=0,controls=0,texts=0,panels=0,skipped=0,deferred=0,limitReached=false}
    if not editable(opts.owner) then stats.deferred=1; return stats end
    if not available(root) then stats.skipped=1; return stats end
    self:Watch(root,opts)
    for _, item in ipairs(opts.art or {}) do self:Hide(path(root,item),opts.owner) end
    for _, item in ipairs(opts.panels or {}) do if self:Panel(path(root,item),"inset",opts.owner) then stats.panels=stats.panels+1 end end
    local atlases = {}
    for key,value in pairs(opts.decorativeAtlases or {}) do
        if type(key)=="number" then atlases[value]=true else atlases[key]=value end
    end
    local metadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local skinner = opts.skinner and metadata and metadata("Skinner","Version") == "beta12.70938.1"
    local visited = opts.visited or {}
    local function visit(frame, depth)
        if not available(frame) or visited[frame] or (opts.skip and opts.skip[frame]) then return end
        if stats.nodes >= (opts.maxNodes or 4096) or depth>32 then stats.limitReached=true; return end
        visited[frame]=true; stats.nodes=stats.nodes+1
        local objectKind = kind(frame)
        if objectKind == "Model" or objectKind == "PlayerModel" or objectKind == "DressUpModel" or objectKind == "ModelScene" then return end
        if objectKind == "HTML" or objectKind == "SimpleHTML" or objectKind == "Browser" then return end
        if objectKind == "FontString" then if self:Text(frame,"body",true,opts.owner) then stats.texts=stats.texts+1 end; return end
        if objectKind == "Texture" then
            if frame.GetAtlas then
                local ok, atlas = pcall(frame.GetAtlas,frame)
                if ok and not V:IsSecret(atlas) and type(atlas)=="string" and atlases[atlas] then self:Hide(frame,opts.owner) end
            end
            return
        end
        if frame ~= root then
            self:Watch(frame,{owner=opts.owner})
            if type(frame.IsVisible) == "function" then
                local ok, visible = pcall(frame.IsVisible, frame)
                if not ok or V:IsSecret(visible) or visible == false then return end
            end
        end
        local controlKind = objectKind == "EditBox" and "editbox" or objectKind == "CheckButton" and "checkbox"
            or objectKind == "Slider" and "slider" or objectKind == "Button" and "button"
        if not controlKind and frame.SetupMenu and frame.GenerateMenu then controlKind="dropdown" end
        if controlKind and self:Control(frame,controlKind,opts.owner,{generic=true}) then stats.controls=stats.controls+1 end
        if skinner and replaceSkinner(frame,opts.owner,visited) then stats.panels=stats.panels+1 end
        if opts.onFrame then
            local ok = pcall(opts.onFrame,frame)
            if not ok then stats.skipped=stats.skipped+1 end
        end
        if frame.GetRegions then
            local ok, list = pcall(function() return {frame:GetRegions()} end)
            if ok then for _, region in ipairs(list) do visit(region,depth+1) end else stats.skipped=stats.skipped+1 end
        end
        if frame.GetChildren then
            local ok, list = pcall(function() return {frame:GetChildren()} end)
            if ok then for _, child in ipairs(list) do visit(child,depth+1) end else stats.skipped=stats.skipped+1 end
        end
    end
    visit(root,0)
    return stats
end

function I:Restore(owner)
    if InCombatLockdown() then return false end
    for _, watch in pairs(self.watched) do
        if owner then watch.owners[owner] = nil else watch.owners = {} end
        activeOwner(watch,true)
    end
    for object,r in pairs(self.records) do
        local held = not owner or (r.owners and r.owners[owner])
        if owner then r.owners[owner] = nil else r.owners = {} end
        if held and not activeOwner(r,true) and available(object) then
            pcall(function()
                if r.surface then r.surface:Hide() end
                if r.signal then r.signal:Hide() end
                if r.alpha ~= nil then object:SetAlpha(r.alpha) end
                if r.font then r.fontSetter(object,unpack(r.font)) end
                if r.changedColor and r.textColor then object:SetTextColor(unpack(r.textColor)) end
                if r.shadow and object.SetShadowColor then object:SetShadowColor(unpack(r.shadow)) end
                if r.shadowOffset and object.SetShadowOffset then object:SetShadowOffset(unpack(r.shadowOffset)) end
                if r.backdrop then object:SetBackdropColor(unpack(r.backdrop)) end
                if r.border and object.SetBackdropBorderColor then object:SetBackdropBorderColor(unpack(r.border)) end
                if r.vertex then object:SetVertexColor(unpack(r.vertex)) end
                if r.desaturated ~= nil and object.SetDesaturated then object:SetDesaturated(r.desaturated) end
            end)
            r.role = nil
        end
    end
    return true
end
