local root = arg and arg[1] or "."
local combat, refreshes = false, 0
local function widget(objectType, original, parent)
    local w={objectType=objectType or "Frame", original=original, parent=parent, children={}, regions={},
        hooks={},width=120,height=28,alpha=1,shown=true,color={1,1,1,1},textColor={1,1,1,1},
        font={"Original.ttf",13,"OUTLINE"},shadow={0,0,0,0},offset={0,0},enabled=true}
    function w:GetObjectType() return self.objectType end
    function w:IsForbidden() return false end
    function w:GetParent() return self.parent end
    function w:GetChildren() return unpack(self.children) end
    function w:GetRegions() return unpack(self.regions) end
    function w:GetWidth() return self.width end
    function w:GetHeight() return self.height end
    function w:GetFrameLevel() return 4 end
    function w:GetEffectiveScale() return 1 end
    function w:SetSize(x,y) assert(not self.original,"Original control resized"); self.width,self.height=x,y end
    function w:SetWidth(x) assert(not self.original,"Original control resized"); self.width=x end
    function w:SetHeight(y) assert(not self.original,"Original control resized"); self.height=y end
    function w:SetPoint(...) assert(not self.original,"Original control moved"); self.point={...} end
    function w:SetAllPoints(target) assert(not self.original,"Original control moved"); self.anchor=target end
    function w:ClearAllPoints() assert(not self.original,"Original control moved") end
    function w:SetFrameLevel(level) assert(not self.original,"Original frame layer changed"); self.level=level end
    function w:SetAttribute() error("Secure attributes changed") end
    function w:SetParent() error("Original control reparented") end
    function w:SetScript() error("Native script replaced") end
    function w:SetText() error("Native content replaced") end
    function w:GetText() error("Native content unnecessarily read") end
    function w:SetAlpha(value) self.alpha=value end
    function w:GetAlpha() return self.alpha end
    function w:SetColorTexture(...) self.color={...} end
    function w:SetVertexColor(...) self.color={...} end
    function w:GetVertexColor() return unpack(self.color) end
    function w:SetTexture(value) self.texture=value end
    function w:GetTexture() return self.texture end
    function w:GetAtlas() return self.atlas end
    function w:SetTexCoord(...) self.coords={...} end
    function w:GetFont() return unpack(self.font) end
    function w:SetFont(...) self.font={...}; return true end
    function w:GetTextColor() return unpack(self.textColor) end
    function w:SetTextColor(...) self.textColor={...} end
    function w:GetShadowColor() return unpack(self.shadow) end
    function w:SetShadowColor(...) self.shadow={...} end
    function w:GetShadowOffset() return unpack(self.offset) end
    function w:SetShadowOffset(...) self.offset={...} end
    function w:GetFontString() return self.Text end
    function w:GetNormalTexture() return self.normal end
    function w:GetPushedTexture() return self.pushed end
    function w:GetDisabledTexture() return self.disabled end
    function w:GetHighlightTexture() return self.highlight end
    function w:IsEnabled() return self.enabled end
    function w:EnableMouse() assert(not self.original,"Native mouse handling changed") end
    function w:Show() self.shown=true end
    function w:Hide() self.shown=false end
    function w:SetShown(value) self.shown=value end
    function w:HasScript() return true end
    function w:HookScript(event,fn) self.hooks[event]=self.hooks[event] or {}; table.insert(self.hooks[event],fn) end
    function w:Trigger(event) for _,fn in ipairs(self.hooks[event] or {}) do fn(self) end end
    function w:MarkIgnoreInLayout(child) assert(child.ignoreInLayout,"Decorative child entered native auto layout"); self.ignored=(self.ignored or 0)+1 end
    function w:CreateTexture()
        local texture=widget("Texture",false,self); table.insert(self.regions,texture); return texture
    end
    if parent then
        local list=(objectType=="Texture" or objectType=="FontString") and parent.regions or parent.children
        if original then table.insert(list,w) end
    end
    return w
end
CreateFrame=function(_,_,parent)
    local f=widget("Frame",false,parent)
    if parent then table.insert(parent.children,f) end
    return f
end
InCombatLockdown=function() return combat end
UIParent=widget("Frame",true); UIParent.width,UIParent.height=2560,1440
local V={db={enabled=true,modules={},fonts={}},modules={nativeWindows={},addonWindows={}}}
function V:IsSecret(value) return type(value)=="table" and value.secret==true end
function V:SafeNumber(value) if not self:IsSecret(value) and type(value)=="number" then return value end end
function V:IsModuleEnabled(id) return self.db.enabled and self.db.modules[id]~=false end
function V:Pixel(value) return value end
function V:Report() end
function V:Refresh() refreshes=refreshes+1 end
assert(loadfile(root.."/Tokens.lua"))("vasagoio",V)
assert(loadfile(root.."/core/Media.lua"))("vasagoio",V)
assert(loadfile(root.."/core/Interiors.lua"))("vasagoio",V)
local I=V.InteriorSkin
local window=widget("Frame",true)
local title=widget("FontString",true,window); title.textColor={0,0,0,1}
local danger=widget("FontString",true,window); danger.textColor={1,.12,.08,1}
local rarity=widget("FontString",true,window); rarity.textColor={.64,.21,.93,1}
local currency=widget("Button",true,window)
currency.Text=widget("FontString",true,currency)
currency.normal=widget("Texture",true,currency); currency.normal.atlas="coin-gold"
local body=widget("Texture",true,window); body.atlas="audited-decoration"
local unknown=widget("Texture",true,window); unknown.atlas="meaningful-item-art"
local coinTextColor=currency.Text.textColor
local stats=I:Apply(window,{owner="nativeWindows",decorativeAtlases={"audited-decoration"}})
assert(stats.texts>0 and stats.controls>0)
assert(title.textColor[1]==V.Tokens.colors.text[1],"Black narrative text stayed black on dark")
assert(danger.textColor[1]==1 and danger.textColor[2]==.12,"Warning color lost")
assert(rarity.textColor[1]==.64 and rarity.textColor[3]==.93,"Item quality color lost")
assert(currency.normal.alpha==1,"Currency icon mistaken for button chrome")
assert(body.alpha==0 and unknown.alpha==1,"Non-whitelisted content texture hidden")
assert(title.font[2]==13 and title.font[1]=="Fonts\\FRIZQT__.TTF","Native font metrics changed")
local originalNodes=stats.nodes
I:Apply(window,{owner="nativeWindows",decorativeAtlases={"audited-decoration"}})
assert(#window.hooks.OnShow==1,"Duplicate discovery hook")

local button=widget("Button",true,window)
button.label=widget("FontString",true,button)
button.normal=widget("Texture",true,button); button.normal.texture="Interface\\Buttons\\UI-Panel-Button-Up"
assert(I:Control(button,"tab","nativeWindows"))
assert(button.normal.alpha==0 and button.ignored>=1,"Audited button not reskinned or entered auto layout")
local r=I.records[button]
I:SetSelected(button,true)
assert(r.signal.shown,"Selected state lacks marker")
assert(r.surface.parts[1].color[1]==V.Tokens.colors.panel[1],"Selection used blue fill instead of agreed near-black")
button:Trigger("OnEnter")
assert(r.surface.parts[1].color[1]==V.Tokens.colors.panel[1],"Hover replaced selected state")
I:SetSelected(button,false); button:Trigger("OnLeave")
assert(not r.signal.shown)
local input=widget("EditBox",true,window)
I:Control(input,"editbox","nativeWindows")
input:Trigger("OnEditFocusGained")
assert(I.records[input].signal.shown,"Keyboard focus lacks marker")
input:Trigger("OnEditFocusLost")
assert(not I.records[input].signal.shown)

-- Native segmented controls have no NormalTexture, and can expose file IDs.
local segmented=widget("Button",true,window)
segmented.Text=widget("FontString",true,segmented)
for _,key in ipairs({"Left","Middle","Right"}) do
    segmented[key]=widget("Texture",true,segmented)
    segmented[key].texture="Interface\\Buttons\\UI-Panel-Button-Up"
end
I:Apply(segmented,{owner="nativeWindows"})
assert(I.records[segmented].surface and segmented.Left.alpha==0 and segmented.Right.alpha==0,
    "Segmented native button chrome not replaced")
local numeric=widget("Button",true,window)
numeric.Text=widget("FontString",true,numeric)
for _,key in ipairs({"Left","Middle","Right"}) do
    numeric[key]=widget("Texture",true,numeric); numeric[key].texture=12345
end
UIPanelButton_OnMouseDown=function() end
numeric.GetScript=function(_,event) if event=="OnMouseDown" then return UIPanelButton_OnMouseDown end end
I:Apply(numeric,{owner="nativeWindows"})
assert(I.records[numeric].surface and numeric.Middle.alpha==0,"Native file-ID template not recognized")

GetAddOnMetadata=function(addon,key) if addon=="Skinner" and key=="Version" then return "beta12.70938.1" end end
local skinned=widget("Button",true,window)
skinned.Text=widget("FontString",true,skinned)
skinned.sb=widget("Button",true,skinned)
local wrapped=widget("Button",true,window)
wrapped.Text=widget("FontString",true,wrapped)
wrapped.sb=widget("Button",true,window) -- reverse-parent wrapper must survive
local populated=widget("Frame",true,window)
populated.sf=widget("Frame",true,populated)
widget("Button",true,populated.sf)
I:Apply(window,{owner="nativeWindows",skinner=true})
assert(skinned.sb.alpha==0 and I.records[skinned].surface,"Skinner standard button decoration remains")
assert(not I.watched[skinned.sb],"Hidden Skinner decoration entered traversal")
assert(wrapped.sb.alpha==1 and populated.sf.alpha==1,"Content-bearing Skinner wrapper hidden")
assert(currency.normal.alpha==1,"Currency artwork lost after Skinner replacement pass")

-- A rem-based addon wrapper must not receive a filename as a rem value.
local custom=widget("FontString",true)
custom._SetFont=custom.SetFont
custom.SetFont=function() error("Invoked owner rem wrapper") end
assert(I:Text(custom,"count",true,"addonWindows"))
assert(custom.font[1]=="Fonts\\ARIALN.TTF" and custom.font[2]==13)
I:Text(custom,"body",true,"addonWindows")
assert(custom.font[1]=="Fonts\\ARIALN.TTF","Generic walk overwrote explicit numeric face")

local before=#window.children
combat=true
local deferred=I:Apply(window,{owner="nativeWindows"})
assert(deferred.deferred==1 and #window.children==before,"Interior work occurred in combat")
assert(not I:Control(widget("Button",true),"button","nativeWindows"))
combat=false
local forbidden=widget("Frame",true)
forbidden.IsForbidden=function() return true end
forbidden.GetChildren=function() error("Forbidden tree traversed") end
assert(I:Apply(forbidden,{owner="nativeWindows"}).skipped==1)
assert(I:SetSelected(button,{secret=true})==false,"Secret selection was branched on")
V.profileReloadPending=true
assert(I:Apply(window,{owner="nativeWindows"}).deferred==1)
V.profileReloadPending=nil
V.db.modules.nativeWindows=false
I:Restore("nativeWindows")
assert(title.font[1]=="Original.ttf" and title.textColor[1]==0,"Original typography not restored")
assert(body.alpha==1 and button.normal.alpha==1 and not r.surface.shown,"Original art not restored")
assert(segmented.Left.alpha==1 and skinned.sb.alpha==1,"Segmented or Skinner button chrome not restored")
button:Trigger("OnEnter")
assert(not r.surface.shown,"Disabled hook revived presentation")
print("interiors_spec: geometry, native content/colors, layout exclusion, selected/focus states, font wrappers, combat and restoration passed")
