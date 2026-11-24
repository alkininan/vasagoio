local root = (arg and arg[1]) or "."
local V = {}
assert(loadfile(root .. "/modules/WindowCatalog.lua"))("vasagoio", V)
assert(#V.WindowCatalog == 172, "The complete source scope must remain represented")
local byID, boundaries = {}, {}
for _, row in ipairs(V.WindowCatalog) do
    assert(not byID[row.id], "Duplicate catalog identifier")
    byID[row.id] = row
    assert(type(row.frame) == "string" and type(row.host) == "string")
    if row.boundary then boundaries[row.boundary] = (boundaries[row.boundary] or 0) + 1 end
end
assert(boundaries["front-end"] == 8, "Glue-only AccountSaveFrame must remain excluded")
assert(byID["account-save-status"].boundary == "front-end")
assert(byID["support-browser-content"].boundary == "embedded-web")
assert(not byID["support-submit-ticket"].boundary, "The Help outer window remains eligible")
assert(byID["reputation"].host == "CharacterFrame")
assert(byID["skills"].host == "CharacterFrame")
assert(byID["quest-pane"].host == "WorldMapFrame")
assert(byID["mounts"].host == "CollectionsJournal")
assert(byID["group-browse"].host == "LFGParentFrame")
assert(byID["barbershop"].scanOnly and byID["alert-toasts"].scanOnly,
    "Full-canvas hosts must not receive an opaque panel")
assert(not byID["edit-mode"].scanOnly, "The fixed-width Edit Mode dialog remains a native window")
assert(byID["report-screenshot-mode"].boundary == "media-overlay")
assert(byID["player-unit-frame"].boundary == "dedicated-hud")
assert(byID["damage-meter"].boundary == "dedicated-hud")
assert(not byID["gamepad-bar-editor"].boundary, "The action bar editor is a configuration window")
assert(#byID["separate-bags"].aliases == 6)
assert(#byID["confirmation-dialogs"].aliases == 3)
assert(boundaries["native-recovery"]==3 and byID["confirmation-dialogs"].boundary=="native-recovery"
    and byID["ghost-return-to-graveyard"].boundary=="native-recovery" and byID["death-recap"].boundary=="native-recovery",
    "Death and pooled recovery dialogs became generic skin targets")
print("window_catalog_spec:172 records, parent hosts, repeated dialogs and non-window boundaries preserved")
