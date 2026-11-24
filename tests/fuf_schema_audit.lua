-- Optional source-only audit, excluded from portable *_spec.lua fixtures.
-- Run from the repository root: lua tests/fuf_schema_audit.lua <FUF source directory>
-- Loads the owner's pure registries; does not launch WoW or read/write WTF.
local source=assert(arg and arg[1],"Provide an audited FUF source directory").."/"
local toc=assert(io.open(source.."ForeverUnitFrames.toc","r"))
local version=toc:read("*a"):match("## Version:%s*([^\r\n]+)");toc:close()
assert(version=="0.81.0" or version=="0.81.1","This audit covers the reviewed 0.81 schemas only")
local ns={On=function()end}
for _,file in ipairs({"Core/AuraBlocklist.lua","Core/Registry.lua","Core/Settings.lua","Core/Config.lua",
    "Raid/BuffData.lua","Raid/Settings.lua","Core/Layout.lua"})do
    assert(loadfile(source..file))("ForeverUnitFrames",ns)
end
local adapters,scale={},1
local V={db={enabled=true,modules={},overrides={}}}
function V:RegisterProfileAdapter(id,spec)adapters[id]=spec end
function V:RegisterModule()end
function V:On()end
function V:IsSecret()return false end
function V:SafeNumber(v)if type(v)=="number" and v==v and math.abs(v)<math.huge then return v end end
function V:Pixel(v)return v*scale end
C_AddOns={GetAddOnMetadata=function()return version end}
UnitFullName=function()return "Fixture","TestRealm"end
ForeverUnitFramesDB={profiles={Default={general={}}},active={["Fixture-TestRealm"]="Default"},raid={["Fixture-TestRealm"]={}}}
assert(loadfile("Tokens.lua"))("vasagoio",V)
assert(loadfile("modules/UnitFrames.lua"))("vasagoio",V)
local function same(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k,v in pairs(b)do if not same(v,a[k])then return false end end
    return true
end
local function check(registry,scope,values)
    local count=0
    for key,value in pairs(values)do
        local def=assert(registry.Get(key),scope.."."..key.." unknown")
        assert(registry.AppliesTo(def,scope),scope.."."..key.." wrong scope")
        assert(same(registry.Validate(def,value),value),scope.."."..key.." clamped/rejected")
        count=count+1
    end
    return count
end
for _,factor in ipairs({.625,1,1.4})do
    scale=factor
    local plan=assert(adapters.unitframes.Prepare())
    local count=0
    for scope,values in pairs(plan.changes[1].value)do count=count+check(ns.Settings,scope,values)end
    for _,change in ipairs(plan.changes)do
        if change.path[2]=="raid"then count=count+check(ns.RaidSettings,change.key,change.value)end
    end
    assert(plan.changes[1].value.party.partyPerLine==5,"Reviewed party wrapping field was omitted")
    print(("FUF %s: %d proposed settings accepted at scale %.3f without clamping"):format(version,count,scale))
end
for _,factor in ipairs({.5,1.5})do
    scale=factor
    local plan,reason=adapters.unitframes.Prepare()
    assert(not plan and reason:find("supported range",1,true),"Out-of-range geometry was not refused before writing")
end
print("Source schema audit passed; native secure rendering, clicks and combat remain untested.")
