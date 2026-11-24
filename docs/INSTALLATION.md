# Fresh installation and first run

1. **Close WoW and back up settings.** If this is an existing installation, copy its `WTF` and `Interface/AddOns` folders somewhere safe. vasagoio does not create or overwrite account folders from outside the game.
2. **Select Forever in CurseForge.** Verify the game directory ends in `_forever_`. Install the selected addons yourself using the list below. Do not install Retail or Classic variants just because their names match.
3. **Keep functional ownership clear.** FUF owns units, Threat Plates owns nameplates, Bartender4 owns actions, Prat owns chat, SexyMap owns the minimap, Baganator/Syndicator own inventory, Skinner owns broad native window skins. Avoid enabling another full UI replacement over them.
4. **Install the release ZIP.** Extract its single `vasagoio` folder into `_forever_/Interface/AddOns/`. Check that the TOC is directly inside it; avoid `vasagoio/vasagoio/` nesting.
5. **Start the game yourself.** Enable the addons you want. For first-time owners, enter the world and reload once so their native profiles exist. vasagoio's cosmetic defaults can load without all optional dependencies.
6. **Review setup.** Type `/vasagoio setup`. Supported loaded owners appear with proposed fields; missing/unreviewed owners explain why they are skipped. Review the exact changes before Apply. It does not rearrange spell slots or keybindings.
7. **Apply and reload.** Apply only out of combat. A local snapshot is stored before changes. FUF gets a separately named vasagoio profile. Other supported adapters adjust their active settings. Reload immediately to make private owner state consistent.
8. **Check the interface manually.** Test Character, talents, bags, spellbook, map, vendor, mail, professions, settings and Help. Confirm unchanged structure, readable labels, working scroll/keyboard focus, tooltips and addon features. Test units with a pet, no pet, a party and raid, then each resource type you use. Check action paging, keybindings, range, cooldowns and aura signals. Finally test combat yourself; report the first BugSack error with game/addon versions, stripping character/account/chat details.
9. **Inspect limitations before calling the setup finished.** `/vasagoio` shows runtime adapter status. COVERAGE.md records visual and feature gaps. This release was built without launching or controlling WoW; it has no native visual, combat or taint validation yet.

## Selected functional packages

| Area | Packages |
| --- | --- |
| HUD | Forever Unit Frames; Threat Plates; Bartender4; Prat 3.0; SexyMap; OpenMap |
| Encounters | DBM Core; DBM Forever and Vanilla; DBM Dungeons; Capping |
| Meters and leading | Details; ThreatClassic2; Method Raid Tools; Gargul |
| PvP and utility | BattleGroundEnemiesFixed; Forever Trinket Menu; AutoPotion |
| Inventory/economy | Baganator; Syndicator; Auctionator |
| Progression | RestedXP; Attune; What's Training; Talents Forever |
| Skin and diagnostics | Skinner; BugGrabber; BugSack |

These are selected dependencies, not embedded downloads. Use each publisher's supported release. vasagoio does not require paid RestedXP content and does not distribute it. Whether to enable Details/ThreatClassic2 collection in your game context stays with you and their native options.

## Disable and recover

- **Temporarily disable visuals:** `/vasagoio off`, then `/reload`, or uncheck vasagoio in the game's AddOns screen.
- **Restore applied owner settings:** open `/vasagoio`, click Restore profiles twice, read its result, and reload immediately. The second click confirms the concrete latest snapshot restoration. All affected owners must be loaded; any later field edit stops the entire restore.
- **If a restore conflicts:** use the owner's profile menu or restore your external WTF backup with the game closed. Never copy another person's full account-specific WTF folder.
- **If an addon update breaks one adapter:** disable that module using its ID from Status, reload, and report versions. The functional addon remains usable; its files were never patched.

## Share with someone else

Send the GitHub release link and this guide. They install the functional packages separately, then apply the portable preset to their own initialized profiles. Their bindings, identity and account files are not shared. The release ZIP contains only vasagoio.
