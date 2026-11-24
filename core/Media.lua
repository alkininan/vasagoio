local addonName, V = ...
local root = "Interface\\AddOns\\" .. addonName .. "\\media\\"
V.Media = {corner = root .. "corner.tga", mask42 = root .. "mask42.tga", mask36 = root .. "mask36.tga", mask32 = root .. "mask32.tga", mask28 = root .. "mask28.tga"}
local surfaces, masks, hidden = setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"}), setmetatable({}, {__mode = "k"})

function V:Font(role)
    local token = self.Tokens.typography[role] or self.Tokens.typography.name
    local path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    if token.face == "narrow" or token.face == "narrowBold" then
        path = "Fonts\\ARIALN.TTF"
        -- No proprietary font is shipped. Resolve a genuine licensed Bold face if supplied.
        if token.face == "narrowBold" then
            local configured = self.db and self.db.fonts and self.db.fonts.narrowBold
            local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
            local supplied = lsm and lsm:Fetch("font", "Arial Narrow Bold", true)
            if type(configured) == "string" and configured ~= "" then
                path = configured
                self:Report("boldFont", "applied", "User-provided Arial Narrow Bold font path; verify the face in game.")
            elseif supplied then
                path = supplied
                self:Report("boldFont", "applied", "Arial Narrow Bold supplied by shared media.")
            else
                self:Report("boldFont", "pending", "Native Arial Narrow Regular fallback. Supply a licensed Bold face for exact typography.")
            end
        end
    end
    return path, self:Pixel(token.size), ""
end

function V:StyleText(text, role, color)
    if self:IsSecret(text) then return end
    if not text or not text.SetFont then return end
    local path, size, flags = self:Font(role)
    local ok, result = pcall(text.SetFont, text, path, size, flags)
    if not ok or result == false then
        pcall(text.SetFont, text, STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
        self:Report("boldFont", "pending", "Requested font failed to load; native font retained.")
    end
    color = color or self.Tokens.colors.text
    if text.SetTextColor then text:SetTextColor(color[1] or color.r, color[2] or color.g, color[3] or color.b, color[4] or color.a or 1) end
    if text.SetShadowColor then text:SetShadowColor(0, 0, 0, .9) end
    if text.SetShadowOffset then text:SetShadowOffset(self:Pixel(1), -self:Pixel(1)) end
end

function V:HideArtwork(object)
    if self:IsSecret(object) then return end
    if not object or not object.SetAlpha or InCombatLockdown() then return end
    if hidden[object] == nil then hidden[object] = object.GetAlpha and self:SafeNumber(object:GetAlpha()) or 1 end
    object:SetAlpha(0)
end

function V:RestoreArtwork()
    if InCombatLockdown() then return end
    for object, alpha in pairs(hidden) do pcall(object.SetAlpha, object, alpha) end
    for _, surface in pairs(surfaces) do surface:Hide() end
end

function V:Surface(frame, alpha, radius)
    if self:IsSecret(frame) then return end
    if not frame or not frame.CreateTexture then return end
    if InCombatLockdown() then return surfaces[frame] end
    local surface = surfaces[frame]
    if not surface then
        surface = CreateFrame("Frame", nil, frame)
        surface:SetAllPoints(frame)
        surface:EnableMouse(false)
        local level = frame.GetFrameLevel and self:SafeNumber(frame:GetFrameLevel())
        if level and surface.SetFrameLevel then surface:SetFrameLevel(math.max(0, level - 1)) end
        surface.parts = {}
        for i = 1, 7 do surface.parts[i] = surface:CreateTexture(nil, "BACKGROUND", nil, -8) end
        surfaces[frame] = surface
    end
    local r = self:Pixel(radius or self.Tokens.radius)
    local width, height = self:SafeNumber(frame:GetWidth()), self:SafeNumber(frame:GetHeight())
    if width and width > 0 then r = math.min(r, width / 2) end
    if height and height > 0 then r = math.min(r, height / 2) end
    local c = self.Tokens.colors.panel
    local p = surface.parts
    for i = 1, 7 do
        p[i]:ClearAllPoints()
        if i <= 3 then p[i]:SetColorTexture(c[1], c[2], c[3], alpha or .56)
        else
            p[i]:SetTexture(self.Media.corner)
            p[i]:SetVertexColor(c[1], c[2], c[3], alpha or .56)
            p[i]:SetSize(r, r)
        end
    end
    p[1]:SetPoint("TOPLEFT", r, 0); p[1]:SetPoint("BOTTOMRIGHT", -r, 0)
    p[2]:SetPoint("TOPLEFT", 0, -r); p[2]:SetPoint("BOTTOMLEFT", 0, r); p[2]:SetWidth(r)
    p[3]:SetPoint("TOPRIGHT", 0, -r); p[3]:SetPoint("BOTTOMRIGHT", 0, r); p[3]:SetWidth(r)
    local anchors = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
    local coordinates = {{0,1,0,1}, {1,0,0,1}, {0,1,1,0}, {1,0,1,0}}
    for i = 1, 4 do p[i+3]:SetPoint(anchors[i]); p[i+3]:SetTexCoord(unpack(coordinates[i])) end
    surface:Show()
    return surface
end

function V:MaskIcon(texture, radius)
    if self:IsSecret(texture) then return false end
    if not texture or not texture.AddMaskTexture or InCombatLockdown() then return false end
    local parent = texture:GetParent()
    if not parent or not parent.CreateMaskTexture then return false end
    local mask = masks[texture]
    if not mask then
        mask = parent:CreateMaskTexture()
        mask:SetAllPoints(texture)
        texture:AddMaskTexture(mask)
        masks[texture] = mask
    end
    local width = self:SafeNumber(texture:GetWidth()) or self:Pixel(42)
    local effective = texture.GetEffectiveScale and self:SafeNumber(texture:GetEffectiveScale()) or 1
    local ui = self:SafeNumber(UIParent:GetEffectiveScale()) or 1
    local referenceWidth = width * effective / ui / self:Pixel(1)
    local chosen, best = 42, math.huge
    for _, candidate in ipairs({28,32,36,42}) do
        local distance = math.abs(candidate - referenceWidth)
        if distance < best then chosen, best = candidate, distance end
    end
    mask:SetTexture(self.Media["mask" .. chosen], "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    return true
end
