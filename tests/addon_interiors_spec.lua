-- Contract tests for reviewed owner APIs; no WoW client is started.
unpack = unpack or table.unpack
local root = (arg and arg[1]) or "."
local combat, refreshes, restores, writes = false, 0, 0, 0
local versions = {Baganator = "868", MRT = "5335", Auctionator = "352", TalentsForeverBook = "0.38.28.20261116", Gargul = "8.1.0"}
local V = {db = {enabled = true, modules = {}}, WindowSkin = {}, InteriorSkin = {}}
local I, W, calls, hooked = V.InteriorSkin, V.WindowSkin, {}, {}
local function check(value, message) assert(value, message) end
local function texture()
    return {alpha = 1, color = {1,.8,0,1}, shown=true, GetAlpha = function(s) return s.alpha end,
        SetAlpha = function(s,v) writes = writes + 1; s.alpha = v end,
        SetAllPoints = function(s,target) s.target=target; writes=writes+1 end,
        SetColorTexture = function(s,...) s.fill={...}; writes=writes+1 end,
        Show = function(s) s.shown=true; writes=writes+1 end,
        Hide = function(s) s.shown=false; writes=writes+1 end,
        GetVertexColor = function(s) return unpack(s.color) end,
        SetVertexColor = function(s,...) writes = writes + 1; s.color = {...} end}
end
local function frame(children)
    return {children = children or {}, scripts = {}, createdTextures={},
        CreateTexture = function(s) local t=texture(); s.createdTextures[#s.createdTextures+1]=t; return t end,
        GetChildren = function(s) return unpack(s.children) end,
        GetRegions = function() return end,
        HookScript = function(s,event,fn) s.scripts[event] = fn; writes = writes + 1 end,
        SetSize = function() error("Owner size changed") end,
        SetPoint = function() error("Owner anchor changed") end,
        SetScript = function() error("Owner handler replaced") end}
end
function W:Available(o) return type(o) == "table" and not o.secret and not o.forbidden end
function W:Visible(o) return self:Available(o) and o.shown ~= false end
function W:Enabled() return V.db.enabled and V.db.modules.addonWindows ~= false end
function W:Hook() end
function W:Path(o,path)
    for key in path:gmatch("[^.]+") do if not self:Available(o) then return end; o = o[key] end
    return o
end
function V:Refresh() refreshes = refreshes + 1 end
function V:IsSecret(v) return type(v) == "table" and v.secret end
function V:SafeNumber(v) return type(v) == "number" and v or nil end
function V:MaskIcon(region,radius) region.maskRadius=radius; writes=writes+1 end
function I:Control(f,kind,owner,opts) calls[f] = {kind=kind,owner=owner,opts=opts}; writes = writes + 1; return true end
function I:Panel(f,kind,owner) calls[f] = {panel=kind,owner=owner}; writes = writes + 1; return {} end
function I:Text(f,role,preserve,owner) f.role, f.preserve, f.owner = role,preserve,owner; writes = writes + 1; return true end
function I:SetSelected(f,selected) f.selected = selected; writes = writes + 1 end
function I:Apply(f,opts) f.applied = opts; writes = writes + 1; return {nodes=1} end
function I:Restore(owner) check(owner == "addonWindows", "wrong restore owner"); restores = restores + 1 end
InCombatLockdown = function() return combat end
C_AddOns = {GetAddOnMetadata = function(addon) return versions[addon] end}
hooksecurefunc = function(object,method,callback)
    hooked[object] = hooked[object] or {}
    check(not hooked[object][method], "duplicate post-hook")
    hooked[object][method] = callback
end
assert(loadfile(root .. "/Tokens.lua"))("vasagoio", V)
assert(loadfile(root .. "/modules/AddonInteriors.lua"))("vasagoio", V)
local A = V.AddonInteriors

-- All API types are handled, while future region types are left alone.
check(#A.BaganatorTypes == 19, "missing Baganator API type")
for _, kind in ipairs(A.BaganatorTypes) do
    local f = frame(); f.Count = {}; f.IsEnabled = function() return true end
    if kind == "Divider" then f = texture() end
    check(A:Bag({region=f,regionType=kind}), "unhandled region " .. kind)
end
local item = frame(); item.Count = {}; item.IconBorder = texture(); item.searchOverlay = texture(); item.Cooldown = {value=21}
A:Bag({region=item,regionType="ItemButton"})
check(item.Count.role == "count" and item.IconBorder.alpha == 1 and item.searchOverlay.alpha == 1 and item.Cooldown.value == 21, "item semantics changed")
local function bagButton()
    local b=frame(); b.icon,b.SlotBackground,b.normal,b.widgetContainer=texture(),texture(),texture(),texture()
    b.SlotBackground.alpha=.7; b.normal.alpha=.6
    b.IconBorder,b.searchOverlay,b.NewItemTexture,b.QuestTexture=texture(),texture(),texture(),texture()
    b.Count={};b.Cooldown={value=21};b.BGR={}
    b.GetNormalTexture=function(s)return s.normal end
    b.SetItemDetails=function()end;b.UpdateTextures=function()end
    return b
end
local bag=bagButton()
A:Bag({region=bag,regionType="ItemButton"})
local empty=bag.createdTextures[1]
check(empty and empty.shown and empty.target==bag.icon and empty.maskRadius==10,"Empty bag slot lacks a rounded placeholder")
check(empty.fill[1]==V.Tokens.colors.emptySlot[1] and empty.fill[4]==V.Tokens.alpha.emptySlot,"Empty bag slot differs from the shared theme")
check(bag.SlotBackground.alpha==0 and bag.normal.alpha==0,"Empty slot retained decorative border")
check(bag.IconBorder.alpha==1 and bag.searchOverlay.alpha==1 and bag.NewItemTexture.alpha==1 and bag.QuestTexture.alpha==1 and bag.Cooldown.value==21,
    "Placeholder changed item status art")
bag.widgetContainer:SetAlpha(.4);hooked[bag.widgetContainer].SetAlpha()
check(empty.alpha==.4 and bag.searchOverlay.alpha==1,"Placeholder ignored owner search/context fading")
bag.BGR={itemID=123,itemLink="item:123"};hooked[bag].SetItemDetails()
check(not empty.shown and bag.SlotBackground.alpha==.7 and bag.normal.alpha==.6,"Filled pooled slot retained an empty placeholder or lost its native decoration")
bag.BGR={};bag.widgetContainer:SetAlpha(1);hooked[bag].SetItemDetails()
check(empty.shown and empty.alpha==1 and #bag.createdTextures==1,"Reused empty slot lost or duplicated its placeholder")
bag.BGR={itemID={secret=true}};hooked[bag].SetItemDetails()
check(not empty.shown and bag.SlotBackground.alpha==.7,"Restricted item identity was treated as an empty slot")
bag.BGR={};bag.dummyType="add";hooked[bag].SetItemDetails()
check(not empty.shown,"Category editor control was treated as an empty slot")
bag.dummyType=nil;hooked[bag].UpdateTextures()
local bagSelector=bagButton()
A:Bag({region=bagSelector,regionType="ItemButton",tags={"containerBag"}})
check(#bagSelector.createdTextures==0 and not hooked[bagSelector],"Container selector was treated as an inventory slot")
local notInitialized=bagButton();notInitialized.BGR=nil
A:Bag({region=notInitialized,regionType="ItemButton"})
check(#notInitialized.createdTextures==0,"Uninitialized item button was assumed empty")
versions.Baganator="future"
local futureBag=bagButton()
A:Bag({region=futureBag,regionType="ItemButton"})
check(#futureBag.createdTextures==0 and not hooked[futureBag],"Unreviewed Baganator empty-state schema was used")
versions.Baganator="868"
local unknown = frame()
check(not A:Bag({region=unknown,regionType="FutureWidget"}) and not calls[unknown], "unknown API type skinned")
local secretTab=frame(); secretTab.IsEnabled=function() return {secret=true} end
A:Bag({region=secretTab,regionType="TabButton"}); check(secretTab.selected==nil,"secret enabled state evaluated")
local tab = frame(); tab.IsEnabled = function() return false end
A:Bag({region=tab,regionType="TabButton"}); check(tab.selected, "selected tab lost")
tab.scripts.OnEnable(); check(tab.selected == false, "tab selection did not follow owner")

-- Custom talent plates use own controls, but talent-node state/art is excluded.
local node = frame(); node.icon, node.slot, node.rank, node.ring = texture(),texture(),{},texture()
local button = frame(); button.plate = {body=texture(),edges={texture()},kind="gold"}; button.text = {}
button.SetSelected = function() end
local leading = frame(); leading.plate = {body=texture(),edges={texture()}}; leading.icon=texture(); leading.label={}
local tree = frame({node,button,leading}); tree.art={texture()}; tree.shade=texture(); tree.title={}; tree.edge={texture()}
A:Apply(tree,"TalentsForeverBook")
check(tree.applied.skip[node] and node.ring.alpha == 1 and node.slot.alpha == 1, "node state art flattened")
check(node.rank.role == "count" and node.rank.preserve, "node text role/meaning changed")
check(tree.art[1].alpha == 1 and tree.edge[1].alpha == 0, "tree illustration or trim incorrect")
check(button.plate.body.alpha == 0 and calls[button].kind == "tab" and button.selected, "custom plate not replaced")
check(calls[leading].kind=="button" and calls[leading].opts.skinIconButton and leading.icon.alpha==1,"leading-icon text button not explicitly styled")
check(not calls[item].opts,"item icon received text-button override")
hooked[button].SetSelected(button,false); check(button.selected == false, "talent selection hook not applied")

-- MRT lazy tools, external popup handles and list selection use exact owner paths.
local row = frame(); row.index=2; row.PushedTexture=texture(); row.HighlightTexture=texture()
local list=frame({row}); list.L={"one","two"}; list.List={row}; list.selected=2; list.Update=function() end
local popup=frame(); local page=frame({list}); page.OtherIconsFrame=popup
local tab1,tab2=frame(),frame(); tab1.LeftDisabled=texture(); tab2.LeftDisabled=texture()
local tabs=frame(); tabs.tabs={{button=tab1},{button=tab2}}; tabs.selected=2; tabs.UpdateTabs=function() end
page.children[#page.children+1]=tabs
local options=frame({page}); options.Frames={page}; options.SetPage=function() end
GMRT={Options={Frame=options,Add=function() end},lib={Popup=function() end}}
TalentsForeverBook={UI={Refresh=function() end,Layout=function() end,SetTab=function() end,LayoutTabs=function() end}}
local unknownGlobal=frame(); FutureUnrelatedWindow=unknownGlobal
A:Discover(); check(popup.applied and row.selected and not unknownGlobal.applied,"MRT scope/popup/selection wrong")
check(tab2.selected and not tab1.selected and tab2.LeftDisabled.alpha==0,"MRT tab chrome/state wrong")
tabs.selected=1; hooked[tabs].UpdateTabs(tabs); check(tab1.selected and not tab2.selected,"MRT tab update stale")
list.selected=1; hooked[list].Update(list); check(row.selected == false,"MRT selection stale")
A:Discover() -- existing hooks must not multiply

-- Reviewed 0.38.33 adds lazy order/plans panels without changing node contracts.
versions.TalentsForeverBook="0.38.33.20261123"
check(A:Reviewed("TalentsForeverBook"),"current audited Talents release rejected")
local tf=TalentsForeverBook.UI
tf.OpenOrder=function() end; tf.OpenPlans=function() end
A:Discover()
local function orderRow(done)
    local r=frame(); r.icon,r.check,r.bg=texture(),texture(),texture()
    r.rank,r.lv,r.name={},{},{}
    r.icon.alpha=done and .45 or 1; r.icon.desaturated=done
    r.check.shown=done; r.rank.shown=not done; r.bg.alpha=done and 0 or .18
    return r
end
local nextRow,doneRow=orderRow(false),orderRow(true)
local order=frame({nextRow,doneRow}); order.top,order.topEdge=texture(),{texture()}; order.inset=frame()
local planTick=texture(); local planRow=frame(); planRow.tick=planTick
local card=frame({planRow}); card.solid,card.page,card.vignette=texture(),texture(),texture()
tf.orderDrawer,tf.planCard=order,card
local queued=refreshes
hooked[tf].OpenOrder(); hooked[tf].OpenPlans()
check(refreshes==queued+2 and not order.applied,"lazy creation was invoked or painted inside owner hook")
A:Discover()
check(order.applied and card.applied and order.top.alpha==0 and order.topEdge[1].alpha==0,"new drawer/card chrome missed")
check(order.applied.skip[nextRow] and order.applied.skip[doneRow],"level-order semantic rows entered generic styling")
check(nextRow.bg.alpha==.18 and doneRow.bg.alpha==0 and doneRow.icon.alpha==.45 and doneRow.icon.desaturated,
    "next-point/completed row appearance changed")
check(doneRow.check.shown and not nextRow.check.shown and planTick.alpha==1,"completed or saved tick lost")
check(card.solid.color[1]==V.Tokens.colors.panel[1] and card.solid.color[4]==.96,"plan editor lost its opaque neutral backing")
check(nextRow.lv.role=="count" and nextRow.lv.preserve and nextRow.name.preserve,"row typography lost native state colors")

-- Named shell and interior discovery must agree on exact supported versions.
V.modules={}
function V:RegisterModule(id,spec) self.modules[id]=spec end
function V:On() end
function W:Shell(f) f.shell=true; return true end
function W:Hide(t) if t then t:SetAlpha(0) end end
TalentsForeverBookFrame=tree
assert(loadfile(root.."/modules/AddonWindows.lua"))("vasagoio",V)
check(V.modules.addonWindows.Apply() and tree.shell,"current Talents shell skipped")
versions.TalentsForeverBook="0.38.28.20261116"
check(A:Reviewed("TalentsForeverBook"),"previous audited Talents release rejected")
local oldShell=frame(); TalentsForeverBookFrame=oldShell
V.modules.addonWindows.Apply(); check(oldShell.shell,"previous Talents shell skipped")
versions.TalentsForeverBook="0.38.34.20261124"
local future,futureOrder=frame(),frame()
TalentsForeverBookFrame,tf.orderDrawer=future,futureOrder
V.modules.addonWindows.Apply()
check(not A:Reviewed("TalentsForeverBook") and not future.shell and not futureOrder.applied,"unreviewed future Talents release accepted")
versions.TalentsForeverBook="0.38.33.20261123"; tf.orderDrawer=order

-- Gargul's real Interface API returns AceGUI wrappers or native named frames.
check(A:Reviewed("Gargul"),"previous audited Gargul release rejected")
local award=frame()
Gargul={Interface={set=function() end,createWindow=function() end,Award={Award={InterfaceItems={Frame={Window={frame=award}}}}}},UI={components={},createFrame=function() end}}
A:Discover(); check(award.applied,"Gargul published window registry ignored")
local late=frame(); local scope={}
hooked[Gargul.Interface].set(Gargul.Interface,scope,"Window",{frame=late})
A:Discover(); check(late.applied,"lazy Gargul window missed")
local named=frame(); _G["Gargul.TestWindow"]=named
hooked[Gargul.Interface].createWindow(Gargul.Interface,{name="Gargul.TestWindow"})
A:Discover(); check(named.applied,"Gargul named createWindow callback missed")

-- 8.1.1 keeps registries and lazy constructors through its timer/init refactor.
versions.Gargul="8.1.1"
check(A:Reviewed("Gargul"),"current audited Gargul release rejected")
local currentAward,registeredButton,currentNamed=frame(),frame(),frame()
Gargul.Interface.Award.Award.InterfaceItems.Frame.Window={frame=currentAward}
Gargul.UI.components.CurrentSettingsButton=registeredButton
_G["Gargul.Interface.GDKP.MultiAuction.Client.Window"]=currentNamed
A:Discover()
check(currentAward.applied and currentNamed.applied and calls[registeredButton].kind=="button",
    "current Gargul owner registries were missed")
local currentLazy=frame(); local beforeLazy=refreshes
hooked[Gargul.Interface].set(Gargul.Interface,scope,"Window",{frame=currentLazy})
check(refreshes==beforeLazy+1 and not currentLazy.applied,"Gargul hook painted inside owner creation")
A:Discover(); check(currentLazy.applied,"current Gargul lazy window missed")
local rejected=frame(); versions.Gargul="8.1.2"; Gargul.Interface.Award.Award.InterfaceItems.Frame.Window={frame=rejected}
check(not A:Reviewed("Gargul"),"future Gargul release accepted by version prefix")
A:Discover(); check(not rejected.applied,"unreviewed Gargul release accepted")
versions.Gargul="8.1.1"

local hiddenWindow=frame(); hiddenWindow.shown=false
A:Register(hiddenWindow,"Gargul")
A:Discover()
check(not hiddenWindow.applied and hiddenWindow.scripts.OnShow,"Closed addon root was traversed or not watched")
hiddenWindow.shown=true
hiddenWindow.scripts.OnShow()
A:Discover()
check(hiddenWindow.applied,"Newly shown addon root was not styled")

local before=writes; combat=true
A:Apply(tree,"TalentsForeverBook"); A:Bag({region=item,regionType="ItemButton"}); A:Discover()
hooked[bag].SetItemDetails()
check(writes==before,"interior mutation during combat")
local combatLate=frame(); hooked[Gargul.Interface].set(Gargul.Interface,scope,"Window",{frame=combatLate})
check(writes==before,"combat creation callback mutated UI")
combat=false; V.db.modules.addonWindows=false; before=writes
A:Bag({region=item,regionType="ItemButton"}); A:Discover(); hooked[button].SetSelected(button,true)
hooked[bag].SetItemDetails()
check(writes==before,"disabled callback still styled UI")
V.db.modules.addonWindows=true; V.profileReloadPending=true; before=writes
A:Bag({region=item,regionType="ItemButton"}); A:Discover(); hooked[button].SetSelected(button,true)
check(writes==before,"pending reload allowed cosmetic mutation")
A:Disable(); check(restores==1 and button.plate.body.alpha==1 and tree.edge[1].alpha==1,"disable did not restore decorative state")
check(not empty.shown and bag.SlotBackground.alpha==.7 and bag.normal.alpha==.6,"Disable left empty-slot decoration behind")
check(order.top.alpha==1 and order.topEdge[1].alpha==1 and card.solid.color[1]==1,"new Talents decorative state not restored")
print("addon_interiors_spec: 19 API regions, owner registries, exact Talents/Gargul versions, lazy drawers, semantic states, combat and disable passed")
