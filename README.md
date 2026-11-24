# vasagoio

A personal World of Warcraft Forever UI built around the Bael design system: neutral black surfaces, restrained blue status colors, native typography, custom HUD geometry, and preserved native window layouts.

**0.2.0-alpha.8 — revised unit geometry, aligned utilities and clearer HUD presentation.** Large 304×72, Medium 224×56 and Small 176×40 use shared 16px resource bars. The centered main grid includes two trinkets and one bag button. This update corrects map/meter bounds, nameplate settings, unit indicators and stacked backgrounds, and strengthens empty slots. Reapply the preset and reload. Native visual/combat acceptance remains pending; automatic aura routing and the RestedXP redesign are still separate unfinished work. See [coverage](docs/COVERAGE.md).

## Install

1. Download the **vasagoio-0.2.0-alpha.8.zip** asset from [Releases](https://github.com/alkininan/vasagoio/releases). GitHub's automatically generated source archive is for development.
2. With WoW closed, extract the `vasagoio` folder into `World of Warcraft/_forever_/Interface/AddOns/`. The result must be `AddOns/vasagoio/vasagoio.toc`.
3. Install the desired functional addons separately using CurseForge or their official distribution. The [dependency list](docs/dependencies.json) records the complete selected setup. They are not bundled.
4. Enable vasagoio and those addons in the game's AddOns menu. Log in yourself, let their profiles initialize, and reload once.
5. Type `/vasagoio setup`, check the component rows and select **Apply preset**. Fix any required HUD issues first. Then select **Reload UI**. Optional unavailable components are shown as Skipped.
6. If testing aura grouping, after reloading use `/vasagoio auratest show` out of combat. Follow the [aura test guide](docs/AURA_TEST.md), then `/vasagoio auratest hide`. No separate test addon is needed; the test stays closed until you open it.
7. Follow the [first-run verification](docs/INSTALLATION.md). Keep your previous `WTF` backup until you have checked the setup yourself.

No prebuilt account-specific WTF folder is distributed. vasagoio creates its own `VasagoioDB` SavedVariables and proposes changes to initialized addon profiles in game. It never installs dependencies or edits their source files.

## What is included

- Reviewed profile adapters for Forever Unit Frames, Threat Plates, Bartender4, Prat, SexyMap, Details, Forever Trinket Menu and Skinner.
- Large / Medium / Small / Extra small unit geometry, two-column raid groups, attached party pets where the owner supports them, exact health text and role-aware nameplate colors.
- A 16×3 action grid assembled from four native Bartender bars, with stronger empty-slot placeholders; the left-aligned pet row ends at the eighth main button. Setup hides extra normal bars and disables old gryphon art/extra bag/micro bars and the crossing status strip, preserving slots, binding configuration, paging and special controls.
- A 4px XP strip inside the 304×72 player frame: health 48, gap 2, power 16, gap 2, XP 4. At maximum level or when XP is unavailable, health 54/gap 2/power 16 rows return. Target retains 54/2/16.
- Two 42px native trinket buttons beside the upper/middle main rows and one 42px native bag button beside the bottom row. The combined 842px container is centered; flyouts, swaps, bags and secure actions remain owner-controlled.
- Player combat and party/raid aggro edges, flagged-only 16px badges, own hunter-pet name happiness, and removal of the duplicate Blizzard castbar.
- Reviewed RestedXP v4.11.40 guide placement separates it from native objectives without changing guide contents or dimensions.
- Full-button cooldown wipes, centered numeric timers, hidden hotkeys during ordinary cooldowns, translucent range feedback and bottom aura signals where supported.
- Neutral translucent window and HUD surfaces with static low-contrast sheen/grain, Friz text roles, Arial Narrow number/chat roles, and original rounded mask artwork.
- Native windows retain their layouts while receiving scoped interior controls, typography, neutral panes and rounded decoration. Selected tabs/rows and focused inputs keep near-black fills with small blue bottom markers.
- Baganator's 19 public skin-region types, including stronger placeholders for empty bag slots, Talents Forever internals, MRT tools, Auctionator panes and Gargul's audited window/widget registries use the same visual primitives while retaining their functionality.
- An optional, closed-by-default native aura experiment with All, Short and Long/permanent comparisons for buffs and debuffs. Exact-60-second classification, permanent effects after button reuse, gaps and combat behavior remain test questions.
- Setup review, persistent snapshots, conflict-aware restoration, module switches and addon-wide disable controls.

The [accepted design](docs/DESIGN.md) lists the full target. [Window coverage](docs/window-coverage.json) tracks all 172 cataloged surfaces without treating source availability as runtime proof. The catalog registers 132 native interior candidates across 115 primary hosts, with dedicated HUD owners and non-addon surfaces classified separately. [Window adapters](docs/WINDOW_COVERAGE.md) explain the native and addon integrations.

## Controls

| Command | Purpose |
| --- | --- |
| `/vasagoio` or `/vsg` | Simple preset and component-status screen |
| `/vasagoio setup` | Check readiness; no settings change until Apply preset |
| `/vasagoio details` | Detailed fields from the current setup review |
| `/vasagoio report` | Technical module status outside the main screen |
| `/vasagoio restore` | Explain restoring the latest snapshot; `restore confirm` performs it |
| `/vasagoio perf` | Snapshot of styling-module calls and timings; not total addon CPU or FPS |
| `/vasagoio auratest show` | Open the optional native aura comparison out of combat; no production layout change |
| `/vasagoio auratest hide` | Close the test and stop its native aura processing |
| `/vasagoio auratest reset` | Reposition and refresh existing test containers out of combat; retains their pools |
| `/vasagoio off` | Disable styling; reload to remove hooks |
| `/vasagoio on` | Enable styling; reload for consistent owner state |
| `/vasagoio module <id> off` | Disable one module using its ID from `/vasagoio report` |
| `/vasagoio refresh` | Reapply available cosmetic modules out of combat |
| `/vasagoio font <path>` | Use a locally supplied, licensed Arial Narrow Bold file |
| `/vasagoio font reset` | Return to shared-media/native font resolution |

You can also uncheck **vasagoio** in the WoW AddOns menu. Applied settings belong to their functional addons and remain after vasagoio is disabled. To undo those too, use `/vasagoio restore`, then `/vasagoio restore confirm` before disabling, then reload immediately. Restoration stops if a saved field has changed since setup, preserving later edits. A full pre-install WTF backup remains the recovery option for conflicts.

Updating from an earlier alpha: with WoW closed, replace only the `vasagoio` folder and keep SavedVariables. Open `/vasagoio setup`, select **Apply preset**, then **Reload UI** for the revised owner settings. Optional trinket integration requires reviewed Forever Trinket Menu 1.8.19. FUF geometry is rejected at scales where native owner bounds would silently clamp it. The aura experiment remains optional and closed by default; the existing RestedXP/native-tracker arrangement is still a documented implementation gap.

## Maintenance and sharing

Only original vasagoio code, masks and documentation are packaged. No other addons, fonts, game art, account settings, chat data or paid guide content are redistributed. Share the release ZIP and installation guide; each person installs dependencies through their own sources.

Updates preserve local settings and do not automatically reapply the preset. Older snapshots without the preset-verification marker show Ready until you explicitly apply this preset and reload once. Alpha.4 bar cleanup, idle-row and quest-panel corrections are included. No settings are reset automatically. Strictly reviewed owner adapters stop on unreviewed versions; other modules continue. After an owner update, inspect `/vasagoio` before applying a new profile. See [maintenance](docs/MAINTENANCE.md).

## Development

Requires Python 3.9+ and Lua 5.1. Run from the repository root:

```sh
python3 tools/check.py --lua lua5.1 --luac luac5.1
python3 tools/package.py
```

Checks cover syntax, profile review/rollback, combat deferral, restricted-value handling, geometry relationships, supported owner schemas, native layout preservation, package contents and reproducible archives. They cannot verify Blizzard taint behavior, protected combat actions, visuals, font availability or real gameplay. No game session is launched by these scripts.

Original code and generated masks: MIT. World of Warcraft and third-party addons remain their owners' property.
