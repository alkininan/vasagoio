# Fresh installation and first run

1. **Close WoW and back up settings.** If this is an existing installation, copy its `WTF` and `Interface/AddOns` folders somewhere safe. vasagoio does not create or overwrite account folders from outside the game.
2. **Select Forever in CurseForge.** Verify the game directory ends in `_forever_`. Install the selected addons yourself using the list below. Do not install Retail or Classic variants just because their names match.
3. **Keep functional ownership clear.** FUF owns units, Threat Plates owns nameplates, Bartender4 owns actions, Prat owns chat, SexyMap owns the minimap, Baganator/Syndicator own inventory, Skinner owns broad native window skins. Avoid enabling another full UI replacement over them.
4. **Install the release ZIP.** Extract its single `vasagoio` folder into `_forever_/Interface/AddOns/`. Check that the TOC is directly inside it; avoid `vasagoio/vasagoio/` nesting.
5. **Start the game yourself.** Enable the addons you want. For first-time owners, enter the world and reload once so their native profiles exist. vasagoio's cosmetic defaults can load without all optional dependencies.
6. **Review setup.** Type `/vasagoio setup`. Supported loaded owners appear with proposed fields; missing/unreviewed owners explain why they are skipped. Review the exact changes before Apply. It does not rearrange spell slots or keybindings.
7. **Apply and reload.** Apply only out of combat. A local snapshot is stored before changes. FUF and Threat Plates get separately named vasagoio profiles. Other supported adapters adjust reviewed fields in their active settings. Reload immediately to make private owner state consistent.
8. **Check the interface manually.** Test Character, talents, bags, spellbook, map, vendor, mail, professions, settings and Help. Confirm unchanged structure, readable labels, working scroll/keyboard focus, tooltips and addon features. Test units with a pet, no pet, a party and raid, then each resource type you use. Check action paging, keybindings, range, cooldowns and aura signals. Finally test combat yourself; report the first BugSack error with game/addon versions, stripping character/account/chat details.
9. **Inspect limitations before calling the setup finished.** `/vasagoio` shows runtime adapter status. COVERAGE.md records visual and feature gaps. This release was built without launching or controlling WoW; it has no native visual, combat or taint validation yet.

## Selected functional packages

| Area | Packages |
| --- | --- |
| HUD | Forever Unit Frames; Threat Plates; Bartender4; Prat 3.0; SexyMap; OpenMap |
| Encounters | DBM Core; DBM Forever and Vanilla; DBM Dungeons; Capping |
| Meters and leading | Details with its bundled TinyThreat plugin; Method Raid Tools; Gargul |
| PvP and utility | BattleGroundEnemiesFixed; Forever Trinket Menu; AutoPotion |
| Inventory/economy | Baganator; Syndicator; Auctionator |
| Progression | RestedXP; Attune; What's Training; Talents Forever |
| Skin and diagnostics | Skinner; BugGrabber; BugSack |

These 26 packages are selected dependencies, not embedded downloads. TinyThreat is bundled with Details and is not a separate package to download. Keep **Details!: Tiny Threat (plugin)** (`Details_TinyThreat`) enabled in the game's AddOns list. In Details window 1, use the orange cogwheel's **Plugin menu → Tiny Threat** to select its threat view. ThreatClassic2 is not needed. Use each publisher's supported release. vasagoio does not require paid RestedXP content and does not distribute it. Collection settings and display selection remain under Details' native controls.

TinyThreat inherits the hosting Details window's row fonts and dimensions. vasagoio styles window 1 only; a second simultaneous damage/threat window is not positioned or styled by this preset. TinyThreat retains its own threat logic and signal colors, while Threat Plates independently handles the agreed nameplate threat colors. For the alpha pass, inspect TinyThreat in window 1 during manually played grouped combat, switch back to damage, and check appearance and selection after reloading.

## Disable and recover

- **Temporarily disable visuals:** `/vasagoio off`, then `/reload`, or uncheck vasagoio in the game's AddOns screen.
- **Restore applied owner settings:** open `/vasagoio`, click Restore profiles twice, read its result, and reload immediately. The second click confirms the concrete latest snapshot restoration. All affected owners must be loaded; any later field edit stops the entire restore.
- **If a restore conflicts:** use the owner's profile menu or restore your external WTF backup with the game closed. Never copy another person's full account-specific WTF folder.
- **If an addon update breaks one adapter:** disable that module using its ID from Status, reload, and report versions. The functional addon remains usable; its files were never patched.

## Share with someone else

Send the GitHub release link and this guide. They install the functional packages separately, then apply the portable preset to their own initialized profiles. Their bindings, identity and account files are not shared. The release ZIP contains only vasagoio.

## Updating from 0.1

With WoW closed, replace only the `vasagoio` addon folder with the 0.2 release folder. Keep `VasagoioDB` and your existing functional-addon settings. Interior styling activates with the existing nativeWindows/addonWindows module preferences; no new profile reset is needed. If Skinner has not yet received the reviewed palette, use setup and reload. The new selected/focus state uses a near-black fill and a small blue bottom marker, as agreed.

## Alpha acceptance

The first alpha.3 user test confirmed an FPS drop from roughly 90–120 to 30 with vasagoio enabled, plus leftover action-bar artwork and overlapping quest panels. Alpha.4 contains a performance and layout correction; native acceptance has **not** passed.

To update, close WoW and replace only the `vasagoio` folder, keeping SavedVariables and functional-addon profiles. Enable it in the AddOns list. If previously disabled using `/vasagoio off`, use `/vasagoio on` and reload. Open `/vasagoio setup`, review the bar cleanup, FUF idle-row correction and RestedXP guide-column changes, apply and reload. The performance fixes load automatically with the code; the profile layout corrections require this explicit setup. Hidden extra bars retain their slots and binding configuration; test the bindings you use, including stance, vehicle and special actions.

Leave Skinner enabled and compare FPS with vasagoio on/off in the same scene, camera and graphics settings, reloading between runs and allowing loading to settle. Include idle gameplay, action/aura changes and opening/closing Character or other windows. `/vasagoio perf` provides a snapshot of styling-module application counts and timings, not total addon CPU or FPS; reopen it for a fresh snapshot. If the slowdown persists, disable vasagoio and report the two FPS readings, its performance snapshot and the first relevant BugSack error.

For the first manual pass, check the **Unavailable** entries in `/vasagoio setup` before applying. An enabled Apply button can represent a partial proposal, including only the addon-owned HUD placement. Missing or unreviewed functional owners must not be treated as a completed setup. After a complete review, apply, reload immediately, and inspect status and the first relevant BugSack error.

Proceed through windows/HUD, party/raid/PvP, combat, and persistence/recovery checks from step 8 and [coverage](COVERAGE.md). Record PASS, FAIL or NOT RUN for each actual context; unresolved failures need fixes and retesting. Current Alpha labels remain until native results support advancing to Beta. Updating between 0.2 alpha builds preserves SavedVariables. Reapply setup only when the release changes owner profiles, as alpha.4 does.
