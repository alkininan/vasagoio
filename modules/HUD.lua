local addonName, V = ...
local T, H = V.Tokens, V.Tokens.hud
local black = T.colors.panel[1]
local chatPanel, mapPanel, meterReloadPending
local function mapLeft() return T.reference.width - H.bottom - H.mapWidth end
local function meterLeft() return mapLeft() - H.splitGap - H.meterWidth end
local function viewportSize() return H.height - H.labelHeight end

local function append(plan, target, path, key, value, label)
    plan.changes[#plan.changes + 1] = { table = target, path = path, key = key, value = value, label = label }
end

V:RegisterProfileAdapter("hudLayout", {
    label = "vasagoio: chat and map containers", addon = "vasagoio",
    Prepare = function()
        if not V.db or type(V.db.overrides) ~= "table" then return nil, "vasagoio settings are not ready" end
        local plan = { changes = {}, detail = "Enable the 480x186 chat container and 216x186 map container at the bottom. Owner widgets keep their controls."
        }
        append(plan, V.db.overrides, { "VasagoioDB", "overrides" }, "hudLayout", true, "Enable agreed HUD container placement")
        return plan
    end,
})

V:RegisterProfileAdapter("prat", {
    label = "Prat: native Arial Narrow chat", addon = "Prat-3.0",
    Prepare = function()
        local prat = _G.Prat
        local addon = prat and prat.Addon
        -- Prat's wrapper dereferences a missing module. AceAddon's silent
        -- lookup lets an unloaded Font module produce an actionable status.
        local ok, font
        if addon and type(addon.GetModule) == "function" then ok, font = pcall(addon.GetModule, addon, "Font", true) end
        if not ok or not font then return nil, "Prat's Font module is not initialized; reload once" end
        if type(font.IsEnabled) ~= "function" then return nil, "Prat Font module schema needs compatibility review" end
        local enabledOK, enabled = pcall(font.IsEnabled, font)
        if not enabledOK or V:IsSecret(enabled) or enabled ~= true then return nil, "Prat Font module is disabled" end
        local name = prat and prat.db and prat.db.keys and prat.db.keys.profile
        if not font.db or type(font.db.profile) ~= "table" or type(font.db.profile.size) ~= "table" or
            V:IsSecret(name) or type(name) ~= "string" then
            return nil, "Prat's Font profile is not initialized; reload once"
        end
        -- Prat registers module namespaces with the AceAddon full name, e.g.
        -- Prat_Font, rather than the short GetModule("Font") lookup name.
        local namespaces = type(_G.Prat3DB) == "table" and rawget(_G.Prat3DB, "namespaces")
        local namespace = type(namespaces) == "table" and rawget(namespaces, "Prat_Font")
        local profiles = type(namespace) == "table" and rawget(namespace, "profiles")
        local profile = font.db.profile
        if type(profiles) ~= "table" or rawget(profiles, name) ~= profile or font.db.sv ~= namespace or
            not font.db.keys or V:IsSecret(font.db.keys.profile) or font.db.keys.profile ~= name then
            return nil, "Prat Font profile schema needs compatibility review"
        end
        if profile.on == false then return nil, "Prat Font module is disabled" end
        local path = { "Prat3DB", "namespaces", "Prat_Font", "profiles", name }
        local plan = { changes = {}, detail = "Native Arial Narrow Regular, 16px at design scale, no outline. Channel colors and chat content are preserved." }
        append(plan, profile, path, "fontface", "Arial Narrow", "Chat font")
        append(plan, profile, path, "outlinemode", "", "Chat outline off")
        append(plan, profile, path, "monochrome", false, "Chat antialiasing")
        append(plan, profile, path, "slug", false, "Native font rendering")
        local sizePath = { "Prat3DB", "namespaces", "Prat_Font", "profiles", name, "size" }
        local keys = { "WhisperTabs", "PetBattleTab" }
        local frameCount = V:SafeNumber(_G.NUM_CHAT_WINDOWS) or 10
        for i = 1, math.min(frameCount, 50) do keys[#keys+1] = "ChatFrame" .. i end
        for _, key in ipairs(keys) do
            append(plan, profile.size, sizePath, key, V:Pixel(T.typography.chat.size), "Chat text: " .. key)
        end
        return plan
    end,
})

local function sexyProfile()
    if not _G.SexyMap or type(_G.SexyMap2DB) ~= "table" or not UnitNameUnmodified then return end
    local first, second = UnitNameUnmodified("player")
    if V:IsSecret(first) or type(first) ~= "string" then return end
    local regional = RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled()
    if V:IsSecret(regional) then return end
    local key
    if regional then
        if V:IsSecret(second) or type(second) ~= "string" then return end
        key = first .. " " .. second
    else
        local realm = GetRealmName()
        if V:IsSecret(realm) or type(realm) ~= "string" then return end
        key = first .. "-" .. realm
    end
    if type(SexyMap2DB[key]) == "string" then key = "global" end
    local profile = SexyMap2DB[key]
    if type(profile) ~= "table" then return end
    return profile, key
end

V:RegisterProfileAdapter("sexymap", {
    label = "SexyMap: borderless map and native zone colors", addon = "SexyMap",
    Prepare = function()
        local profile, name = sexyProfile()
        if not profile or type(profile.core) ~= "table" or type(profile.borders) ~= "table" or
            type(profile.borders.backdrop) ~= "table" or type(profile.zonetext) ~= "table" or type(profile.clock) ~= "table" then
            return nil, "SexyMap's core, border, zone and clock schemas are not ready"
        end
        local plan = { changes = {}, detail = "216x186 outer footprint with a centered 154x154 native map and 32px header. The native square map remains square; zone colors retain their friendly/hostile meanings. Reload required." }
        local path = { "SexyMap2DB", name, "core" }
        local core = profile.core
        local ox, oy = V:CanvasOrigin()
        local scale = V:Pixel(viewportSize()) / 140
        append(plan, core, path, "scale", scale, "Map viewport size 154")
        append(plan, core, path, "point", "BOTTOMLEFT", "Map anchor")
        append(plan, core, path, "relpoint", "BOTTOMLEFT", "Map relative anchor")
        append(plan, core, path, "x", (ox + V:Pixel(mapLeft() + (H.mapWidth-viewportSize())/2))/scale, "Map viewport x")
        append(plan, core, path, "y", (oy + V:Pixel(H.bottom))/scale, "Map bottom gap")
        append(plan, core, path, "shape", 130871, "Native square map shape")
        append(plan, core, path, "lock", true, "Lock map placement")
        path = { "SexyMap2DB", name, "borders" }
        append(plan, profile.borders, path, "borders", {}, "Remove decorative map outlines")
        append(plan, profile.borders, path, "applyPreset", nil, "Do not reapply rune preset")
        append(plan, profile.borders, path, "hideBlizzard", true, "Remove original map rim")
        append(plan, profile.borders.backdrop, { "SexyMap2DB", name, "borders", "backdrop" }, "show", false, "No secondary map backdrop")
        for _, module in ipairs({ "zonetext", "clock" }) do
            local config = profile[module]
            path = { "SexyMap2DB", name, module }
            append(plan, config, path, "font", "Friz Quadrata TT", module .. " native font")
            append(plan, config, path, "fontsize", V:Pixel(T.typography.compact.size)/scale, module .. " compact text")
            append(plan, config, path, "outline", "NONE", module .. " outline off")
            append(plan, config, path, "monochrome", false, module .. " antialiasing")
            append(plan, config, path, "bgColor", { r = black, g = black, b = black, a = T.alpha.hud }, module .. " neutral black")
            append(plan, config, path, "borderColor", { r = 0, g = 0, b = 0, a = 0 }, module .. " borderless")
        end
        path = { "SexyMap2DB", name, "zonetext" }
        append(plan, profile.zonetext, path, "fontColor", {}, "Preserve native zone relationship colors")
        append(plan, profile.zonetext, path, "width", V:Pixel(144)/scale, "Zone label minimum width")
        append(plan, profile.zonetext, path, "xOffset", V:Pixel(-36)/scale, "Zone label left header")
        append(plan, profile.zonetext, path, "yOffset", V:Pixel(4)/scale, "Zone label header gap")
        path = { "SexyMap2DB", name, "clock" }
        append(plan, profile.clock, path, "xOffset", V:Pixel(72)/scale, "Clock right header")
        append(plan, profile.clock, path, "yOffset", V:Pixel(H.height-2)/scale, "Clock top header")
        append(plan, profile.clock, path, "fontColor", { r = T.colors.text[1], g = T.colors.text[2], b = T.colors.text[3], a = 1 }, "Clock white text")
        return plan
    end,
})

local function makePanel(existing, name, width, x)
    local panel = existing or CreateFrame("Frame", name, UIParent)
    local ox, oy = V:CanvasOrigin()
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ox + V:Pixel(x), oy + V:Pixel(H.bottom))
    panel:SetSize(V:Pixel(width), V:Pixel(H.height))
    panel:SetFrameStrata("BACKGROUND")
    V:Surface(panel, T.alpha.hud, T.radius)
    panel:Show()
    return panel
end

V:RegisterProfileAdapter("details", {
    label = "Details: window 1 appearance and placement", addon = "Details",
    Prepare = function()
        local details = _G.Details
        local instance = details and details.GetInstance and details:GetInstance(1)
        if not instance or not details.tabela_instancias or details.tabela_instancias[1] ~= instance or
            type(instance.posicao) ~= "table" or type(instance.posicao.normal) ~= "table" or
            type(instance.libwindow) ~= "table" or type(instance.row_info) ~= "table" or
            type(instance.bg_alpha) ~= "number" then
            return nil, "Details window 1 must already be loaded with the supported instance schema"
        end
        local path = { "Details", "tabela_instancias", 1 }
        local plan = { changes = {}, detail = "Backs up live window-1 configuration (Details serializes it into its profile). Reload after apply or restore; no live skin refresh is invoked. 248x186 body at x2072/bottom8; native toolbar can extend above it. No collection or combat-access settings change." }
        append(plan, instance, path, "window_scale", 1, "Meter scale")
        append(plan, instance, path, "bg_r", black, "Meter black red")
        append(plan, instance, path, "bg_g", black, "Meter black green")
        append(plan, instance, path, "bg_b", black, "Meter black blue")
        append(plan, instance, path, "bg_alpha", 0, "Use vasagoio translucent outer surface")
        append(plan, instance, path, "fullborder_shown", false, "Meter outer stroke off")
        append(plan, instance, path, "rowareaborder_shown", false, "Meter row-area stroke off")
        append(plan, instance, path, "rounded_corner_enabled", false, "Keep meter fill geometry square")
        local position = instance.posicao.normal
        local ox, oy = V:CanvasOrigin()
        path = { "Details", "tabela_instancias", 1, "posicao", "normal" }
        append(plan, position, path, "w", V:Pixel(H.meterWidth), "Meter body width")
        append(plan, position, path, "h", V:Pixel(H.height), "Meter body height")
        append(plan, position, path, "x", ox + V:Pixel(meterLeft()+H.meterWidth/2) - UIParent:GetWidth()/2, "Meter center x")
        append(plan, position, path, "y", oy + V:Pixel(H.bottom+H.height/2) - UIParent:GetHeight()/2, "Meter center y")
        path = { "Details", "tabela_instancias", 1, "libwindow" }
        append(plan, instance.libwindow, path, "point", "BOTTOMLEFT", "Meter anchor")
        append(plan, instance.libwindow, path, "x", ox + V:Pixel(meterLeft()), "Meter x")
        append(plan, instance.libwindow, path, "y", oy + V:Pixel(H.bottom), "Meter bottom gap")
        append(plan, instance.libwindow, path, "scale", 1, "Meter anchor scale")
        path = { "Details", "tabela_instancias", 1, "row_info" }
        local font = V:Font("compact")
        append(plan, instance.row_info, path, "font_face", "Friz Quadrata TT", "Meter native font")
        append(plan, instance.row_info, path, "font_face_file", font, "Meter native font file")
        append(plan, instance.row_info, path, "font_size", V:Pixel(T.typography.compact.size), "Meter compact text")
        append(plan, instance.row_info, path, "height", V:Pixel(T.typography.name.line), "Meter row height")
        if type(instance.row_info.texts) == "table" then
            for index = 1, 4 do
                local entry = instance.row_info.texts[index]
                if type(entry) == "table" and type(entry.font) == "table" then
                    path = { "Details", "tabela_instancias", 1, "row_info", "texts", index, "font" }
                    append(plan, entry.font, path, "face", nil, "Meter column inherits native font")
                    append(plan, entry.font, path, "size", nil, "Meter column inherits compact size")
                    append(plan, entry.font, path, "outline", "", "Meter column outline off")
                end
            end
        end
        return plan
    end,
    AfterApply = function()
        -- ChangeSkin(nil) can normalize additional profile fields. Let Details
        -- rebuild from its own saved profile after reload so review stays exact.
        meterReloadPending = true
    end,
})

V:RegisterModule("hud", {
    label = "Chat and minimap surfaces", defaultEnabled = true,
    description = "Neutral translucent panels; native channel and zone color semantics.",
    Apply = function()
        if InCombatLockdown() then return false, "Leave combat before refreshing HUD geometry" end
        local chat = _G.ChatFrame1
        if chat then
            V:StyleText(chat, "chat")
            if chat.SetSpacing then chat:SetSpacing(V:Pixel(T.typography.chat.line-T.typography.chat.size)) end
        end
        if not V.db.overrides.hudLayout then
            return true, "Chat typography applied. Review setup to place chat and map containers."
        end
        if chat then
            chatPanel = makePanel(chatPanel, "VasagoioChatPanel", H.chatWidth, H.bottom)
            local ox, oy = V:CanvasOrigin()
            -- Reserve header/padding inside the overall footprint for native tabs.
            -- Never save native chat positions or modify message/channel settings.
            chat:ClearAllPoints()
            chat:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ox + V:Pixel(H.bottom+8), oy + V:Pixel(H.bottom+8))
            chat:SetSize(V:Pixel(H.chatWidth-16), V:Pixel(H.height-H.labelHeight-8))
            for _, suffix in ipairs({ "Background", "TopLeftTexture", "TopRightTexture", "BottomLeftTexture", "BottomRightTexture", "TopTexture", "BottomTexture", "LeftTexture", "RightTexture" }) do
                local artwork = _G["ChatFrame1" .. suffix]
                if artwork then V:HideArtwork(artwork) end
            end
        end
        if _G.SexyMap then mapPanel = makePanel(mapPanel, "VasagoioMapPanel", H.mapWidth, mapLeft()) end
        return true, "Chat/map containers applied; map owner profile requires setup and reload. Long native zone labels may exceed the header."
    end,
    Disable = function()
        if chatPanel then chatPanel:Hide() end
        if mapPanel then mapPanel:Hide() end
    end,
})

V:RegisterModule("meter", {
    label = "Details cosmetic surface", defaultEnabled = true,
    description = "Styles an already loaded meter without enabling collection or changing combat data.",
    Apply = function()
        if InCombatLockdown() then return false, "Leave combat before refreshing meter styling" end
        if meterReloadPending then return false, "Reload to activate the reviewed Details settings" end
        local details = _G.Details
        if not details or not details.GetInstance then
            return false, "Details is not loaded. vasagoio does not enable it or its combat-data access."
        end
        local instance = details:GetInstance(1)
        if not instance or not instance.baseframe then return false, "Details window 1 is not ready" end
        -- Until explicit setup removes the owner's background, adding another
        -- translucent surface would incorrectly make the window more opaque.
        if instance.bg_alpha == 0 then
            V:Surface(instance.baseframe, T.alpha.hud, T.radius)
            return true, "Neutral outer surface applied; square meter rows and data remain owned by Details."
        end
        return true, "Details is available; review setup to apply its appearance and geometry."
    end,
})
