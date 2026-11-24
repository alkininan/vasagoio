local addonName, V = ...
local T, H = V.Tokens, V.Tokens.hud
local black = T.colors.panel[1]
local chatPanel, mapPanel, mapLabel, meterReloadPending
local function mapLeft() return T.reference.width - H.bottom - H.mapWidth end
local function meterLeft() return mapLeft() - H.splitGap - H.meterWidth end
local function mapCrop() return (H.mapWidth-H.height)/2 end
local function meterHeader() return H.padding+H.meterTitle end
local function meterBody() return H.height-meterHeader() end
local function supported(addon, wanted)
    local api = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    if not api then return false end
    local ok, version = pcall(api, addon, "Version")
    return ok and not V:IsSecret(version) and type(version)=="string" and version==wanted
end

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
        if not supported("SexyMap", "v12.1.7") then return nil, "SexyMap version needs compatibility review (reviewed v12.1.7)" end
        local profile, name = sexyProfile()
        if not profile or type(profile.core) ~= "table" or type(profile.borders) ~= "table" or
            type(profile.borders.backdrop) ~= "table" or type(profile.zonetext) ~= "table" or type(profile.clock) ~= "table" then
            return nil, "SexyMap's core, border, zone and clock schemas are not ready"
        end
        local plan = { changes = {}, detail = "216x186 map artwork: square 216 projection cropped 15 at top/bottom, with a 32px bottom label overlay. Native pins/clicks require user verification. Reload required." }
        local path = { "SexyMap2DB", name, "core" }
        local core = profile.core
        local ox, oy = V:CanvasOrigin()
        local scale = V:Pixel(H.mapWidth) / 140
        append(plan, core, path, "scale", scale, "Square map canvas 216")
        append(plan, core, path, "point", "BOTTOMLEFT", "Map anchor")
        append(plan, core, path, "relpoint", "BOTTOMLEFT", "Map relative anchor")
        append(plan, core, path, "x", (ox + V:Pixel(mapLeft()))/scale, "Map viewport x")
        append(plan, core, path, "y", (oy + V:Pixel(H.bottom-mapCrop()))/scale, "Cropped map canvas bottom")
        append(plan, core, path, "shape", V.Media.minimapMask, "Original rectangular crop mask")
        append(plan, core, path, "clamp", false, "Allow the cropped square canvas below the screen edge")
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
            append(plan, config, path, "bgColor", { r = black, g = black, b = black, a = 0 }, module .. " no duplicate backdrop")
            append(plan, config, path, "borderColor", { r = 0, g = 0, b = 0, a = 0 }, module .. " borderless")
        end
        path = { "SexyMap2DB", name, "zonetext" }
        append(plan, profile.zonetext, path, "fontColor", {}, "Preserve native zone relationship colors")
        append(plan, profile.zonetext, path, "width", 0, "Bounded zone label through the scoped adapter")
        append(plan, profile.zonetext, path, "xOffset", V:Pixel(-32)/scale, "Zone label left portion")
        append(plan, profile.zonetext, path, "yOffset", V:Pixel(-H.mapWidth+mapCrop())/scale, "Zone label bottom overlay")
        path = { "SexyMap2DB", name, "clock" }
        append(plan, profile.clock, path, "xOffset", V:Pixel(72)/scale, "Clock right overlay")
        append(plan, profile.clock, path, "yOffset", V:Pixel(mapCrop()+H.labelHeight)/scale, "Clock bottom overlay")
        append(plan, profile.clock, path, "fontColor", { r = T.colors.text[1], g = T.colors.text[2], b = T.colors.text[3], a = 1 }, "Clock white text")
        return plan
    end,
})

local function makePanel(existing, name, width, x, transparent)
    local panel = existing or CreateFrame("Frame", name, UIParent)
    local ox, oy = V:CanvasOrigin()
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", ox + V:Pixel(x), oy + V:Pixel(H.bottom))
    panel:SetSize(V:Pixel(width), V:Pixel(H.height))
    panel:SetFrameStrata("BACKGROUND")
    if not transparent then V:Surface(panel, T.alpha.hud, T.radius) end
    panel:Show()
    return panel
end

V:RegisterProfileAdapter("details", {
    label = "Details: window 1 appearance and placement", addon = "Details",
    Prepare = function()
        if not supported("Details", "#Details.20261109.15410.172") then return nil, "Details version needs compatibility review (reviewed 20261109.15410.172)" end
        local details = _G.Details
        local instance = details and details.GetInstance and details:GetInstance(1)
        if not instance or not details.tabela_instancias or details.tabela_instancias[1] ~= instance or
            type(instance.posicao) ~= "table" or type(instance.posicao.normal) ~= "table" or
            type(instance.libwindow) ~= "table" or type(instance.row_info) ~= "table" or
            type(instance.row_info.space) ~= "table" or type(instance.row_info.row_offsets) ~= "table" or
            type(instance.attribute_text) ~= "table" or type(instance.row_info.texts) ~= "table" or
            type(instance.bg_alpha) ~= "number" then
            return nil, "Details window 1 must already be loaded with the supported instance schema"
        end
        local skin=details.skins and details.skins[instance.skin]
        if type(skin)~="table" then return nil,"Details active skin definition is not ready" end
        local skinRows=skin.instance_cprops and skin.instance_cprops.row_info
        local skinSpace=skinRows and skinRows.space
        -- HideSideBars runs during the owner's rebuild and resets these two
        -- values from the selected skin. Put our insets in the additive offsets
        -- so that reload does not silently remove them.
        local sideLeft=skinSpace and skinSpace.left_noborder or 0
        local sideRight=skinSpace and skinSpace.right_noborder or 0
        if not V:SafeNumber(sideLeft) or not V:SafeNumber(sideRight) then return nil,"Details sidebar spacing needs review" end
        if type(details.class_colors)~="table" or details.class_colors==_G.RAID_CLASS_COLORS or
            details.class_colors==_G.CUSTOM_CLASS_COLORS then return nil,"Details profile class palette is not ready" end
        local path = { "Details", "tabela_instancias", 1 }
        local plan = { changes = {}, detail = "Window 1 total 248x186: 32px title region (8 padding + 24 line), 154px row body, 8px row inset, 24px rows/4px gaps. Neutral fills/class-colored names. The nine class colors update Details' shared profile palette; special threat/arena colors are unchanged. Reload required." }
        for class,color in pairs(T.class) do
            local current=details.class_colors[class]
            if type(current)~="table" or not V:SafeNumber(current[1]) or not V:SafeNumber(current[2]) or not V:SafeNumber(current[3]) then
                return nil,"Details class palette schema needs compatibility review"
            end
            append(plan,details.class_colors,{"Details","class_colors"},class,{unpack(color)},"Shared Details class palette: "..class)
        end
        append(plan, instance, path, "window_scale", 1, "Meter scale")
        append(plan, instance, path, "bg_r", black, "Meter black red")
        append(plan, instance, path, "bg_g", black, "Meter black green")
        append(plan, instance, path, "bg_b", black, "Meter black blue")
        append(plan, instance, path, "bg_alpha", 0, "Use vasagoio translucent outer surface")
        append(plan, instance, path, "fullborder_shown", false, "Meter outer stroke off")
        append(plan, instance, path, "rowareaborder_shown", false, "Meter row-area stroke off")
        append(plan, instance, path, "rounded_corner_enabled", false, "Keep meter fill geometry square")
        append(plan, instance, path, "titlebar_shown", true, "Title included in the outer envelope")
        append(plan, instance, path, "titlebar_height", V:Pixel(meterHeader()), "Title region including top padding")
        append(plan, instance, path, "titlebar_texture_color", {0,0,0,0}, "No duplicate title backing")
        append(plan, instance, path, "toolbar_side", 1, "Toolbar above row body")
        append(plan, instance, path, "show_statusbar", false, "No footer outside the envelope")
        append(plan, instance, path, "show_sidebars", false, "No decorative sidebars")
        append(plan, instance, path, "bars_grow_direction", 1, "Rows descend below title")
        if type(instance.wallpaper)=="table" then
            append(plan,instance.wallpaper,{"Details","tabela_instancias",1,"wallpaper"},"enabled",false,"No secondary wallpaper")
        end
        local position = instance.posicao.normal
        local ox, oy = V:CanvasOrigin()
        path = { "Details", "tabela_instancias", 1, "posicao", "normal" }
        append(plan, position, path, "w", V:Pixel(H.meterWidth), "Meter body width")
        append(plan, position, path, "h", V:Pixel(meterBody()), "Meter body within total envelope")
        append(plan, position, path, "x", ox + V:Pixel(meterLeft()+H.meterWidth/2) - UIParent:GetWidth()/2, "Meter center x")
        append(plan, position, path, "y", oy + V:Pixel(H.bottom+meterBody()/2) - UIParent:GetHeight()/2, "Meter body center y")
        path = { "Details", "tabela_instancias", 1, "libwindow" }
        append(plan, instance.libwindow, path, "point", "BOTTOMLEFT", "Meter anchor")
        append(plan, instance.libwindow, path, "x", ox + V:Pixel(meterLeft()), "Meter x")
        append(plan, instance.libwindow, path, "y", oy + V:Pixel(H.bottom), "Meter bottom gap")
        append(plan, instance.libwindow, path, "scale", 1, "Meter anchor scale")
        path = { "Details", "tabela_instancias", 1, "row_info" }
        local font = V:Font("name")
        append(plan, instance.row_info, path, "font_face", "Friz Quadrata TT", "Meter native font")
        append(plan, instance.row_info, path, "font_face_file", font, "Meter native font file")
        append(plan, instance.row_info, path, "font_size", V:Pixel(T.typography.name.size), "Meter text 16")
        append(plan, instance.row_info, path, "height", V:Pixel(H.rowHeight), "Meter row height")
        append(plan, instance.row_info, path, "texture_class_colors", false, "Neutral bar fills")
        append(plan, instance.row_info, path, "fixed_texture_color", {unpack(T.colors.meter)}, "Neutral meter fill")
        append(plan, instance.row_info, path, "fixed_text_color", {unpack(T.colors.text)}, "Ivory neutral values")
        append(plan, instance.row_info, path, "texture", "Solid", "Flat square fill")
        append(plan, instance.row_info, path, "texture_custom", "", "No overriding bar art")
        append(plan, instance.row_info, path, "texture_background", "Solid", "Flat row track")
        append(plan, instance.row_info, path, "texture_background_class_color", false, "Neutral row track")
        append(plan, instance.row_info, path, "fixed_texture_background_color", {T.colors.meter[1],T.colors.meter[2],T.colors.meter[3],.48}, "Faint empty row track")
        local rowPath={"Details","tabela_instancias",1,"row_info","space"}
        append(plan,instance.row_info.space,rowPath,"left",sideLeft,"Owner's borderless row base")
        append(plan,instance.row_info.space,rowPath,"right",sideRight,"Owner's borderless row width base")
        append(plan,instance.row_info.space,rowPath,"between",V:Pixel(H.rowGap),"Row gap")
        rowPath={"Details","tabela_instancias",1,"row_info","row_offsets"}
        for key,value in pairs({left=V:Pixel(H.padding)-sideLeft,right=-V:Pixel(2*H.padding)-sideRight,top=-V:Pixel(H.padding),bottom=V:Pixel(H.padding)}) do
            append(plan,instance.row_info.row_offsets,rowPath,key,value,"Row bounds: "..key)
        end
        local titlePath={"Details","tabela_instancias",1,"attribute_text"}
        for key,value in pairs({enabled=true,text_face="Friz Quadrata TT",text_size=V:Pixel(16),text_color={unpack(T.colors.text)},shadow=true,side=1}) do
            append(plan,instance.attribute_text,titlePath,key,value,"Meter title: "..key)
        end
        if type(instance.row_info.texts) == "table" then
            for index = 1, 4 do
                local entry = instance.row_info.texts[index]
                if type(entry) == "table" and type(entry.font) == "table" and type(entry.color)=="table" then
                    path = { "Details", "tabela_instancias", 1, "row_info", "texts", index, "font" }
                    append(plan, entry.font, path, "face", nil, "Meter column inherits native font")
                    append(plan, entry.font, path, "size", nil, "Meter column inherits 16px size")
                    append(plan, entry.font, path, "outline", "", "Meter column outline off")
                    path={"Details","tabela_instancias",1,"row_info","texts",index,"color"}
                    append(plan,entry.color,path,"byClass",index==1,"Class color for names only")
                    append(plan,entry.color,path,"fixed",nil,"Use shared neutral value color")
                else
                    return nil,"Details row text/color schema needs compatibility review"
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

-- Bounded, named owner widgets only. These snapshots cover runtime cosmetics;
-- persistent owner geometry is restored separately by Restore profiles/reload.
local saved = {hud={},hudMap={},meter={}}
local hooks, painting, running = {}, {}, {}
local meterSurface
local function active(owner)
    return running[owner] and V.db and V.db.enabled and not V.readOnly and
        not V.profileReloadPending and V:IsModuleEnabled(owner)
end
local function remember(object, owner, field)
    if not object or V:IsSecret(object) then return end
    local records = saved[owner]
    local r = records[object] or {}; records[object]=r
    field=field or "geometry"
    r.captured=r.captured or {}
    if r.captured[field] then return r end
    r.captured[field]=true
    if field=="geometry" and object.GetNumPoints and object.GetPoint then
        r.points={}
        local n=V:SafeNumber(object:GetNumPoints())
        if n and n<=16 then for i=1,n do r.points[i]={object:GetPoint(i)} end end
    end
    if (field=="geometry" or field=="bounds") and not r.width and object.GetWidth and object.GetHeight then
        r.width,r.height=object:GetWidth(),object:GetHeight()
    end
    if field=="font" and object.GetFont then r.font={object:GetFont()} end
    if field=="spacing" and object.GetSpacing then r.spacing=object:GetSpacing() end
    if field=="alpha" and object.GetAlpha then r.alpha=object:GetAlpha() end
    if field=="hit" and object.GetHitRectInsets then r.hit={object:GetHitRectInsets()} end
    if field=="bounds" then
        if object.GetWordWrap then r.wrap=object:GetWordWrap() end
        if object.GetMaxLines then r.lines=object:GetMaxLines() end
    end
    return r
end
local function restore(owner)
    if InCombatLockdown() then return false end
    painting[owner]=true
    local complete,remaining=true,{}
    if V.InteriorSkin then
        local ok,result=pcall(V.InteriorSkin.Restore,V.InteriorSkin,owner)
        if not ok or result==false then complete=false end
    end
    for object,r in pairs(saved[owner]) do
        local ok=pcall(function()
            if r.points then
                object:ClearAllPoints()
                for _,point in ipairs(r.points) do object:SetPoint(unpack(point)) end
            end
            if r.width and r.height then object:SetSize(r.width,r.height) end
            if r.font and r.font[1] then object:SetFont(unpack(r.font)) end
            if r.spacing then object:SetSpacing(r.spacing) end
            if r.alpha then object:SetAlpha(r.alpha) end
            if r.hit then object:SetHitRectInsets(unpack(r.hit)) end
            if r.wrap~=nil then object:SetWordWrap(r.wrap) end
            if r.lines~=nil then object:SetMaxLines(r.lines) end
        end)
        if not ok then remaining[object]=r; complete=false end
    end
    saved[owner]=remaining; painting[owner]=false
    return complete
end
local function hide(object, owner)
    if not object or not object.SetAlpha then return end
    remember(object,owner,"alpha")
    if V.InteriorSkin then V.InteriorSkin:Hide(object,owner) else object:SetAlpha(0) end
end
local function font(text, role, owner, scale, preserveColor)
    if not text or not text.SetFont then return end
    remember(text,owner,"font")
    if V.InteriorSkin then V.InteriorSkin:Text(text,role,preserveColor,owner) end
    local path,size,flags=V:Font(role)
    text:SetFont(path,size/(scale or 1),flags)
    if not preserveColor and text.SetTextColor then text:SetTextColor(unpack(T.colors.text)) end
end
local function observe(object, method, owner)
    if not object or type(object[method])~="function" or not hooksecurefunc then return end
    hooks[object]=hooks[object] or {}
    if hooks[object][method] then return end
    hooks[object][method]=true
    hooksecurefunc(object,method,function()
        if active(owner) and not painting[owner] then V:Refresh("owner HUD geometry",owner) end
    end)
end
local function scaleOf(object)
    if not object or not object.GetEffectiveScale then return 1 end
    local size=V:SafeNumber(object:GetEffectiveScale())
    local parent=V:SafeNumber(UIParent:GetEffectiveScale())
    return size and parent and size>0 and parent>0 and size/parent or 1
end
local function bounded(text, width, owner)
    if not text then return end
    remember(text,owner,"bounds")
    if text.SetWidth then text:SetWidth(width) end
    if text.SetWordWrap then text:SetWordWrap(false) end
    if text.SetMaxLines then text:SetMaxLines(1) end
end
local chatArt={"Background","TopLeftTexture","TopRightTexture","BottomLeftTexture","BottomRightTexture","TopTexture","BottomTexture","LeftTexture","RightTexture"}
local function chatControls()
    local I=V.InteriorSkin
    for i=1,10 do
        local prefix="ChatFrame"..i
        local chat,tab,edit=_G[prefix],_G[prefix.."Tab"],_G[prefix.."EditBox"]
        if chat then for _,suffix in ipairs(chatArt) do hide(_G[prefix..suffix],"hud") end end
        if tab and I then
            I:Control(tab,"tab","hud")
            for _,key in ipairs({"Left","Middle","Right","ActiveLeft","ActiveMiddle","ActiveRight"}) do
                hide(tab[key] or _G[prefix.."Tab"..key],"hud")
            end
            I:SetSelected(tab,chat==_G.SELECTED_DOCK_FRAME)
        end
        if edit then
            if I then I:Control(edit,"editbox","hud") end
            for _,key in ipairs({"Left","Mid","Right","FocusLeft","FocusMid","FocusRight"}) do
                hide(edit[key] or _G[prefix.."EditBox"..key],"hud")
            end
            font(edit,"chat","hud",nil,true)
        end
        local buttons=_G[prefix.."ButtonFrame"]
        if buttons and I then
            -- Keep the scroll/menu icons and native click handlers. Only their
            -- background chrome receives our treatment.
            for _,key in ipairs({"MinimizeButton","BottomButton","UpButton","DownButton"}) do
                if buttons[key] then I:Control(buttons[key],"button","hud") end
            end
        end
    end
    if _G.FCF_SelectDockFrame and not hooks.chatDock and hooksecurefunc then
        hooks.chatDock=true
        hooksecurefunc("FCF_SelectDockFrame",function()
            if active("hud") and not painting.hud then V:Refresh("chat tab selection","hud") end
        end)
    end
end
local function mapPresentation()
    if not _G.SexyMap or not supported("SexyMap","v12.1.7") then return false end
    local profile=sexyProfile()
    if not profile or not profile.core or profile.core.shape~=V.Media.minimapMask then return false end
    local minimap=_G.Minimap
    if not minimap then return false end
    mapPanel=makePanel(mapPanel,"VasagoioMapPanel",H.mapWidth,mapLeft(),true)
    mapPanel:SetFrameStrata("LOW")
    mapLabel=mapLabel or CreateFrame("Frame","VasagoioMapLabel",mapPanel)
    mapLabel:ClearAllPoints(); mapLabel:SetPoint("BOTTOMLEFT",mapPanel,"BOTTOMLEFT",0,0)
    mapLabel:SetSize(V:Pixel(H.mapWidth),V:Pixel(H.labelHeight))
    if mapLabel.SetFrameLevel and minimap.GetFrameLevel then mapLabel:SetFrameLevel(minimap:GetFrameLevel()+1) end
    V:Surface(mapLabel,T.alpha.hud,T.radius); mapLabel:Show()
    -- Native map remains under SexyMap's parent/scale ownership. Only its
    -- documented hit rectangle is cropped; native blips and the owner's
    -- separate right-click overlay still require an in-game acceptance check.
    if minimap.GetHitRectInsets and minimap.SetHitRectInsets then
        remember(minimap,"hudMap","hit")
        local inset=V:Pixel(mapCrop())/scaleOf(minimap)
        minimap:SetHitRectInsets(0,0,inset,inset)
    end
    local zone=_G.SexyMapZoneTextButton
    if zone then
        local scale=scaleOf(zone)
        remember(zone,"hudMap")
        zone:ClearAllPoints(); zone:SetPoint("BOTTOMLEFT",mapPanel,"BOTTOMLEFT",V:Pixel(8)/scale,0)
        zone:SetSize(V:Pixel(136)/scale,V:Pixel(H.labelHeight)/scale)
        if zone.GetRegions then
            for _,region in ipairs({zone:GetRegions()}) do
                if region.GetObjectType and region:GetObjectType()=="FontString" then
                    font(region,"compact","hudMap",scale,true)
                    bounded(region,V:Pixel(136)/scale,"hudMap")
                end
            end
        end
        observe(zone,"SetWidth","hud")
    end
    local clock=_G.TimeManagerClockButton
    if clock then
        local scale=scaleOf(clock)
        remember(clock,"hudMap")
        clock:SetSize(V:Pixel(56)/scale,V:Pixel(H.labelHeight)/scale)
        -- SexyMap's public profile positions this button. Its parent lock and
        -- SetPoint hook remain untouched.
        font(_G.TimeManagerClockTicker,"compact","hudMap",scale,false)
    end
    observe(_G.SexyMap,"ExitHUD","hud")
    return true
end

local meterInstance
local function cleanupHUD()
    running.hud=false
    if InCombatLockdown() then return false end
    local chatOK=restore("hud")
    local mapOK=restore("hudMap")
    if chatPanel then chatPanel:Hide() end
    if mapPanel then mapPanel:Hide() end
    if not chatOK or not mapOK then return false,"Some HUD restoration was refused. Reload UI to finish cleanup." end
    return true
end
local function cleanupMeter()
    running.meter=false
    if InCombatLockdown() then return false end
    local restored=restore("meter")
    if meterSurface then meterSurface:Hide() end
    if not restored then return false,"Some meter restoration was refused. Reload UI to finish cleanup." end
    meterInstance=nil
    return true
end
local function protectedApply(owner, callback)
    local ok,applied,detail=pcall(callback)
    painting[owner]=false
    local cleaned=true
    if not ok or applied==false then
        if owner=="hud" then cleaned=cleanupHUD() else cleaned=cleanupMeter() end
    end
    if not cleaned and not InCombatLockdown() then return false,"HUD restoration is incomplete. Reload UI to finish cleanup and check compatibility." end
    if not ok then return false,"Owner HUD styling failed; presentation was released. Reload and check compatibility." end
    return applied,detail
end

V:RegisterModule("hud", {
    label="Chat and minimap surfaces",defaultEnabled=true,
    description="Native Prat chat controls and a cropped square minimap with one bottom overlay.",
    Apply=function() return protectedApply("hud",function()
        if InCombatLockdown() then return false,"Leave combat before refreshing HUD geometry" end
        if not V.db or not V.db.enabled or V.readOnly or V.profileReloadPending then return false,"HUD presentation is paused" end
        if not V.db.overrides.hudLayout then
            local ok,reason=cleanupHUD(); if not ok then return false,reason end
        end
        running.hud=true; painting.hud=true
        local chat=_G.ChatFrame1
        if chat then
            font(chat,"chat","hud",nil,true)
            if chat.SetSpacing then remember(chat,"hud","spacing"); chat:SetSpacing(V:Pixel(T.typography.chat.line-T.typography.chat.size)) end
        end
        if not V.db.overrides.hudLayout then
            painting.hud=false
            return true,"Chat typography applied. Review setup to place chat and map containers."
        end
        if chat then
            chatPanel=makePanel(chatPanel,"VasagoioChatPanel",H.chatWidth,H.bottom)
            -- Outer186: header32, message viewport106, gap8, input32 and
            -- bottom8. Native chat/history/channel behavior is unchanged.
            remember(chat,"hud")
            chat:ClearAllPoints(); chat:SetPoint("BOTTOMLEFT",chatPanel,"BOTTOMLEFT",V:Pixel(8),V:Pixel(48))
            chat:SetSize(V:Pixel(H.chatWidth-16),V:Pixel(H.height-H.labelHeight-48))
            local edit=_G.ChatFrame1EditBox
            if edit then
                remember(edit,"hud")
                edit:ClearAllPoints(); edit:SetPoint("BOTTOMLEFT",chatPanel,"BOTTOMLEFT",V:Pixel(8),V:Pixel(8))
                edit:SetSize(V:Pixel(H.chatWidth-16),V:Pixel(32))
            end
            chatControls()
        end
        local mapReady=mapPresentation()
        if not mapReady then
            local restored=restore("hudMap")
            if mapPanel then mapPanel:Hide() end
            if not restored then return false,"Map restoration was refused. Reload UI to finish cleanup." end
        end
        painting.hud=false
        return true,mapReady and "Chat and bottom map label applied. Native map pins/clicks need user validation." or "Chat applied; reload the reviewed SexyMap profile to activate the cropped map."
    end) end,
    Disable=cleanupHUD,
})

V:RegisterModule("meter", {
    label="Details cosmetic surface",defaultEnabled=true,
    description="One surface around the complete meter title and row body.",
    Apply=function() return protectedApply("meter",function()
        if InCombatLockdown() then return false,"Leave combat before refreshing meter styling" end
        if meterReloadPending or V.profileReloadPending then return false,"Reload to activate the reviewed Details settings" end
        if not V.db or not V.db.enabled or V.readOnly then return false,"Meter presentation is paused" end
        if not supported("Details","#Details.20261109.15410.172") then return false,"Details version needs compatibility review" end
        local details=_G.Details
        local instance=details and details.GetInstance and details:GetInstance(1)
        local base=instance and instance.baseframe
        if not base or not base.fullWindowFrame then return false,"Details window 1 is not ready" end
        if instance.bg_alpha~=0 or instance.titlebar_height~=V:Pixel(meterHeader()) then
            local ok,reason=cleanupMeter(); if not ok then return false,reason end
            return true,"Details is available; review setup and reload to apply the complete envelope."
        end
        if meterInstance and meterInstance~=instance then
            local ok,reason=cleanupMeter(); if not ok then return false,reason end
        end
        meterInstance=instance
        running.meter=true; painting.meter=true
        meterSurface=V:Surface(base.fullWindowFrame,T.alpha.hud,T.radius)
        for _,part in ipairs({base.cabecalho,base.rodape}) do
            for _,key in ipairs({"ball","ball_r","emenda","top_bg","esquerdo","direita"}) do hide(part[key],"meter") end
        end
        local title=instance.GetTitleBarFontString and instance:GetTitleBarFontString()
        title=title and (title.widget or title)
        if title then
            remember(title,"meter"); font(title,"name","meter",nil,false)
            title:ClearAllPoints(); title:SetPoint("TOPLEFT",base.fullWindowFrame,"TOPLEFT",V:Pixel(8),-V:Pixel(8))
            bounded(title,V:Pixel(128),"meter")
            if title.SetHeight then title:SetHeight(V:Pixel(H.meterTitle)) end
        end
        -- Move the existing six buttons as a group without changing their
        -- handlers, visibility choices or plugin/data behavior.
        local header=base.cabecalho
        if header then
            local x=8
            for _,key in ipairs({"fechar","reset","report","atributo","segmento","modo_selecao"}) do
                local button=header[key]
                if button then
                    local shown=button.IsShown and button:IsShown()
                    if not V:IsSecret(shown) and shown then
                        remember(button,"meter")
                        button:ClearAllPoints(); button:SetPoint("TOPRIGHT",base.fullWindowFrame,"TOPRIGHT",-V:Pixel(x),-V:Pixel(12))
                        button:SetSize(V:Pixel(16),V:Pixel(16)); x=x+16
                    end
                end
            end
            if title then bounded(title,V:Pixel(H.meterWidth-x-16),"meter") end
        end
        for _,method in ipairs({"RefreshTitleBar","ToolbarMenuButtons","AttributeMenu"}) do observe(instance,method,"meter") end
        painting.meter=false
        return true,"Complete 248x186 meter envelope styled; native controls, rows and data retained."
    end) end,
    Disable=cleanupMeter,
})
