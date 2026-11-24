-- Native unit states stay event-driven and restricted values use native sinks.
local events,created={},{}
local combat,hunter,mood,threat=false,true,3,0
local secret=setmetatable({},{__lt=function()error("secret comparison")end,
    __add=function()error("secret arithmetic")end,__tostring=function()error("secret formatting")end})
local profile,name={},"vasagoio"
local V={db={enabled=true,modules={}}}
function V:IsSecret(value)return value==secret end
function V:SafeNumber(value)if value~=secret and type(value)=="number" then return value end end
function V:Pixel(value)return value end
function V:Font(role)return "native-friz",self.Tokens.typography[role].size,"" end
function V:IsModuleEnabled(id)return self.db.enabled and self.db.modules[id]~=false end
function V:GetReviewedUnitProfile()if name:match("^vasagoio") then return profile,name end end
function V:On(event,fn)events[event]=fn end
local function fire(event,unit)if events[event]then events[event](event,unit)end end
function hooksecurefunc(object,method,fn)
    local previous=assert(object[method],method)
    object[method]=function(self,...)previous(self,...);fn(self,...)end
end
InCombatLockdown=function()return combat end
HasPetUI=function()return true,hunter end
UnitClass=function()return "Hunter","HUNTER" end
C_PetInfo={GetPetHappiness=function()return mood end}
local threatReads=0
UnitThreatSituation=function(unit)threatReads=threatReads+1;return threat end
local geometry=0
local function widget(kind,parent)
    local w={kind=kind,parent=parent,points={},color={1,1,1,1},font={"owner",16,"OUTLINE"},
        shadow={0,0,0,.4},offset={1,-1},shown=true}
    function w:SetTextColor(...)self.color={...};self.colorWrites=(self.colorWrites or 0)+1 end
    function w:GetTextColor()return unpack(self.color)end
    function w:SetFont(...)self.font={...}end
    function w:GetFont()return unpack(self.font)end
    function w:SetShadowColor(...)self.shadow={...}end
    function w:GetShadowColor()return unpack(self.shadow)end
    function w:SetShadowOffset(...)self.offset={...}end
    function w:GetShadowOffset()return unpack(self.offset)end
    function w:ClearAllPoints()geometry=geometry+1;self.points={}end
    function w:SetPoint(...)geometry=geometry+1;self.points[#self.points+1]={...}end
    function w:SetHeight(value)geometry=geometry+1;self.height=value end
    function w:SetWidth(value)geometry=geometry+1;self.width=value end
    function w:SetAllPoints(frame)geometry=geometry+1;self.anchor=frame end
    function w:SetFrameLevel(value)self.level=value end
    function w:GetFrameLevel()return 3 end
    function w:EnableMouse(value)self.mouse=value end
    function w:CreateTexture()return widget("Texture",self)end
    function w:SetStatusBarTexture(texture)self.texture=texture end
    function w:SetStatusBarColor(...)self.color={...}end
    function w:GetStatusBarColor()return unpack(self.color)end
    function w:SetColorTexture(...)self.color={...}end
    function w:SetMinMaxValues(low,high)self.minimum,self.maximum=low,high end
    function w:SetValue(value)self.value=value end
    function w:SetShown(value)self.shown=value end
    function w:Show()self.shown=true end
    function w:Hide()self.shown=false end
    return w
end
CreateFrame=function(kind,_,parent)local w=widget(kind,parent);created[#created+1]=w;return w end
local function frame(key,unit)
    local f=widget("Unit")
    f.key,f.unit=key,unit
    f.texts={healthLeft=widget("Text"),healthRight=widget("Text"),powerRight=widget("Text")}
    return f
end
local function equal(actual,expected)
    for i,value in ipairs(expected)do assert(actual[i]==value,"color/font differs at "..i)end
end
assert(loadfile("Tokens.lua"))("vasagoio",V)
assert(loadfile("modules/UnitStates.lua"))("vasagoio",V)
local player,party,pet,partyPet,otherPet,target=frame("player","player"),frame("party","party1"),
    frame("pet","pet"),frame("partypet","pet"),frame("partypet","partypet2"),frame("target","target")
local raid=frame("raid","raid1")
raid.raidStates={aggro={bars={}},target=widget("Frame")}
for i=1,4 do local b=widget("StatusBar");b.color={1,0,0,1};b.value=secret;raid.raidStates.aggro.bars[i]=b end
player.castbar={text=widget("Text"),time=widget("Text"),height=21,interruptMarker={}}
local castMarker=player.castbar.interruptMarker
for _,f in ipairs({player,party,pet,partyPet,otherPet,target,raid})do V:StyleUnitStates(f)end
assert(#created==6,"Unexpected frames: only player edge, party edge and four party sinks are needed")
local playerEdge,partyEdge=created[1],created[2]
assert(playerEdge.parent==player and partyEdge.parent==party)
assert(not playerEdge.shown and playerEdge.mouse==false)
equal(playerEdge.parts[1].color,{unpack(V.Tokens.colors.danger)})
assert(playerEdge.parts[1].color[4]==.35 and playerEdge.parts[1].height==2)
for _,bar in ipairs(partyEdge.parts)do assert(bar.minimum==1 and bar.maximum==2 and bar.value==0 and bar.color[4]==.35)end
equal(pet.texts.healthLeft.color,V.Tokens.colors.petHappy)
equal(partyPet.texts.healthLeft.color,V.Tokens.colors.petHappy)
equal(otherPet.texts.healthLeft.color,{1,1,1,1})
assert(partyPet.texts.healthLeft.font[2]==14 and partyPet.texts.healthRight.font[2]==14)
equal(player.texts.healthRight.color,V.Tokens.colors.text)
equal(player.castbar.text.color,V.Tokens.colors.text)
assert(player.castbar.height==21 and player.castbar.interruptMarker==castMarker,"Cast geometry/semantics changed")
for _,bar in ipairs(raid.raidStates.aggro.bars)do
    assert(bar.value==secret and bar.color[4]==.35,"Native raid threat state was replaced")
end
local beforeGeometry,beforeCreated=geometry,#created
combat=true;fire("PLAYER_REGEN_DISABLED")
assert(playerEdge.shown)
threat=secret;fire("UNIT_THREAT_SITUATION_UPDATE","party1")
for _,bar in ipairs(partyEdge.parts)do assert(bar.value==secret,"Restricted threat did not reach its native sink")end
assert(geometry==beforeGeometry and #created==beforeCreated,"State event changed geometry in combat")
local beforeReads=threatReads
fire("UNIT_THREAT_SITUATION_UPDATE","target")
assert(threatReads==beforeReads,"Target acquired an unapproved combat/aggro overlay")
combat=false;fire("PLAYER_REGEN_ENABLED")
assert(not playerEdge.shown)
mood=2;fire("UNIT_HAPPINESS","pet");equal(pet.texts.healthLeft.color,V.Tokens.colors.petContent)
mood=1;fire("UNIT_HAPPINESS","pet");equal(pet.texts.healthLeft.color,V.Tokens.colors.petUnhappy)
mood=secret;fire("UNIT_HAPPINESS","pet");equal(pet.texts.healthLeft.color,V.Tokens.colors.muted)
mood=3;hunter=false;fire("PET_UI_UPDATE");equal(pet.texts.healthLeft.color,{1,1,1,1})
hunter=secret;fire("PET_UI_UPDATE");equal(pet.texts.healthLeft.color,V.Tokens.colors.muted)
hunter=true;mood=3;fire("PET_UI_UPDATE")
pet.texts.healthLeft:SetTextColor(.3,.4,.5,.9)
equal(pet.texts.healthLeft.color,V.Tokens.colors.petHappy)
otherPet.texts.healthLeft:SetTextColor(.6,.7,.8,1)
equal(otherPet.texts.healthLeft.color,{.6,.7,.8,1})
local native=raid.raidStates.aggro.bars[1]
native:SetStatusBarColor(.9,.1,.2,.8)
assert(native.color[4]==.35)
partyPet.texts.healthLeft:SetFont("new-owner",17,"OUTLINE")
partyPet.texts.healthLeft:SetShadowColor(.1,.2,.3,.7)
partyPet.texts.healthLeft:SetShadowOffset(2,-2)
assert(partyPet.texts.healthLeft.font[2]==14)
assert(partyPet.texts.healthLeft.shadow[4]==.9 and partyPet.texts.healthLeft.offset[1]==1)
V:DisableUnitStates()
assert(not playerEdge.shown and not partyEdge.shown)
equal(pet.texts.healthLeft.color,{.3,.4,.5,.9})
equal(native.color,{.9,.1,.2,.8})
equal(partyPet.texts.healthLeft.font,{"new-owner",17,"OUTLINE"})
equal(partyPet.texts.healthLeft.shadow,{.1,.2,.3,.7})
equal(partyPet.texts.healthLeft.offset,{2,-2})
beforeGeometry=geometry
fire("PLAYER_REGEN_DISABLED");fire("UNIT_HAPPINESS","pet")
assert(geometry==beforeGeometry and not playerEdge.shown,"Disabled states kept running")
pet.texts.healthLeft:SetTextColor(.2,.3,.4,1)
equal(pet.texts.healthLeft.color,{.2,.3,.4,1})
V:StyleUnitStates(pet)
name="Other"
fire("UNIT_HAPPINESS","pet")
equal(pet.texts.healthLeft.color,{.2,.3,.4,1})
name="vasagoio";V:StyleUnitStates(pet)
profile={};pet.texts.healthLeft:SetTextColor(.4,.3,.2,1)
equal(pet.texts.healthLeft.color,{.4,.3,.2,1})
V:StyleUnitStates(pet);V.profileReloadPending=true;fire("PET_UI_UPDATE")
equal(pet.texts.healthLeft.color,{.4,.3,.2,1})
print("unit_states_spec: native combat/aggro, opaque threat sinks, pet moods, compact text and owner cleanup passed")
