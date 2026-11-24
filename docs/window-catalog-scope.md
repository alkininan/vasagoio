# Native window scope

The source catalog contains **172 surface/state records**, not 172 independent live windows. The runtime registry groups children under their native hosts and watches explicitly listed repeated dialogs. A source name is a candidate only: the game, character, realm, load-on-demand state or feature gates can make it unavailable.

| Classification | Records | Handling |
| --- | --- | --- |
| Native interior candidates | 132 | 115 primary hosts, with child panels and 15 source-confirmed repeated frame aliases; apply the scoped interior renderer when present |
| Dedicated HUD/functional owners | 29 | Keep unit, action, aura, minimap, meter and overlay ownership separate from window-control traversal |
| Glue/front-end | 8 | Outside normal in-game addon execution; no styling attempted |
| Embedded support webpage | 1 | HelpBrowser content is outside the addon renderer; HelpFrame remains a separate native candidate |
| Media/world-capture overlays | 2 | CinematicFrame and ReportScreenshotModeFrame retain their media/world rendering; no generic black panel is added |

The eighth front-end record is **AccountSaveFrame**. It was previously grouped with shared popups, but its own TOC explicitly specifies `AllowLoad: Glue`, depends on `Blizzard_GlueXML`, and its XML parents it to CharacterSelect. The boundary is source-confirmed, not inferred from the frame's name. [Source TOC](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_AccountSaveUI/Blizzard_AccountSaveUI.toc)

Character's Reputation, Skills and PvP rank panels retain CharacterFrame as their host. Collections children retain CollectionsJournal; LFG subviews retain LFGParentFrame. QuestMapFrame is attached to WorldMapFrame by its source layout code. These mappings prevent adding independent opaque outer windows over nested native panels. BarberShopFrame and AlertFrame are control-discovery hosts only, with no whole-canvas backdrop. The fixed-width Edit Mode dialog remains a native window; its full-screen Grid and MagnetismPreviewLinesContainer children retain their overlay behavior.

Repeated native bags, loot rolls, static popups, comparison tooltips and dropdown levels use explicit aliases from the reviewed source. No addon calls a global frame enumeration function, opens a window, reparents a control or changes an existing window's dimensions to discover these surfaces.

## What registration means

Registration identifies where eligible controls and explicitly known artwork can be styled. It does **not** mean that every pixel or every dynamic widget under that frame has a custom replacement. Content textures, models, maps, item/spell art, text values, semantic colors and protected/forbidden content remain with their functional owner. Native visual acceptance is a separate user-run step and remains untested in the ledger.

`docs/window-coverage.json` is the portable source of the registry. Run `python3 tools/window_catalog.py` after changing its host/boundary data; `--check` verifies the generated Lua is current. The ordinary offline check runs that consistency check and the Lua boundary fixture.
