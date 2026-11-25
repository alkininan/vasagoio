# vasagoio

A personal World of Warcraft Forever UI built around the Bael design system: neutral black surfaces, restrained blue status colors, native typography, custom HUD geometry, and preserved native window layouts.

**0.2.0-alpha.11 — updated Details compatibility.** Supports the reviewed Details build 20261124.15450.172 and retains the previous build. Source review found compatible meter geometry, profile and menu contracts; the installed AutoPotion 4.1.3 update needs no vasagoio adapter change. Alpha.10 HUD/recovery fixes remain included. Design revision 12 and preset marker 5 stay unchanged. Native acceptance and production aura routing remain open; see [coverage](docs/COVERAGE.md).

## Install

1. Download the **vasagoio-0.2.0-alpha.11.zip** asset from [Releases](https://github.com/alkininan/vasagoio/releases). GitHub's automatically generated source archive is for development.
2. With WoW closed, extract the `vasagoio` folder into `World of Warcraft/_forever_/Interface/AddOns/`. The result must be `AddOns/vasagoio/vasagoio.toc`.
3. Install the desired functional addons separately using CurseForge or their official distribution. The [dependency list](docs/dependencies.json) records the complete selected setup. They are not bundled.
4. Enable vasagoio and those addons in the game's AddOns menu. Log in yourself, let their profiles initialize, and reload once.
5. Type `/vasagoio`, check the Setup component rows and select **Apply preset**. Fix any required HUD issues first. Then select **Reload UI**. Optional unavailable components are shown as Skipped.
6. If testing aura grouping, after reloading open **Tools → Aura test → Show** out of combat. Follow the [aura test guide](docs/AURA_TEST.md), then **Tools → Aura test → Hide**. No separate test addon is needed; the test stays closed until you open it.
7. Follow the [first-run verification](docs/INSTALLATION.md). Keep your previous `WTF` backup until you have checked the setup yourself.

No prebuilt account-specific WTF folder is distributed. vasagoio creates its own `VasagoioDB` SavedVariables and proposes changes to initialized addon profiles in game. It never installs dependencies or edits their source files.

## What is included

- Reviewed profile adapters for Forever Unit Frames, Threat Plates, Bartender4, Prat, SexyMap, Details, Forever Trinket Menu and Skinner.
- Large / Medium / Small / Extra small unit geometry, two-column raid groups, attached party pets where the owner supports them, exact health text and role-aware nameplate colors.
- A 16×3 action grid assembled from four native Bartender bars, with stronger empty-slot placeholders; the left-aligned pet row ends at the eighth main button. Setup hides extra normal bars and disables old gryphon art/extra bag/micro bars and the crossing status strip, preserving slots, binding configuration, paging and special controls.
- A 4px XP strip inside the 304×72 player frame: health 48, gap 2, power 16, gap 2, XP 4. At maximum level or when XP is unavailable, health 54/gap 2/power 16 rows return. Target retains 54/2/16.
- Two 42px native trinket buttons beside the upper/middle main rows and one 42px native bag button beside the bottom row. The combined 842px container is centered; flyouts, swaps, bags and secure actions remain owner-controlled.
- Player combat and party/raid aggro edges, flagged-only 16px badges, own hunter-pet name happiness, and removal of the duplicate Blizzard castbar.
- Reviewed RestedXP v4.11.40 stays 8px from the right edge below the reserved long-aura region. Combat/manual hiding preserves guide progress; Tools and a small reopen tag control visibility. The entire native objective tracker is hidden, including its quest-item/scenario controls. Separate RXP active item/target controls remain usable.
- Full-button cooldown wipes, centered numeric timers, hidden hotkeys during ordinary cooldowns, translucent range feedback and bottom aura signals where supported.
- Neutral translucent window and HUD surfaces with static low-contrast sheen/grain, Friz text roles, Arial Narrow number/chat roles, and original rounded mask artwork.
- Native windows retain their layouts while receiving scoped interior controls, typography, neutral panes and rounded decoration. Selected tabs/rows and focused inputs keep near-black fills with small blue bottom markers.
- Baganator's 19 public skin-region types, including stronger placeholders for empty bag slots, Talents Forever internals, MRT tools, Auctionator panes and Gargul's audited window/widget registries use the same visual primitives while retaining their functionality.
- An optional, closed-by-default native aura experiment with All, Short and Long/permanent comparisons for buffs and debuffs. Exact-60-second classification, permanent effects after button reuse, gaps and combat behavior remain test questions.
- Setup review, persistent snapshots, conflict-aware restoration, module switches and addon-wide disable controls.

The [accepted design](docs/DESIGN.md) lists the full target. [Window coverage](docs/window-coverage.json) tracks all 172 cataloged surfaces without treating source availability as runtime proof. The catalog registers 129 native interior candidates across 112 primary hosts, with three native-recovery boundaries, dedicated HUD owners and non-addon surfaces classified separately. [Window adapters](docs/WINDOW_COVERAGE.md) explain the native and addon integrations.

## Controls

Type **`/vasagoio`**. Setup always opens first. Details contains the current field review; Report contains compatibility problems and addon versions; Performance shows styling timings; Tools contains the aura test, styling on/off, guide visibility and confirmed snapshot restoration. Reload UI is available throughout, outside combat. Select **Copy report**, then press **Cmd+C** on Mac or **Ctrl+C** to copy the selected text. Old commands below remain optional shortcuts.

| Command | Purpose |
| --- | --- |
| `/vasagoio` or `/vsg` | Open the tabbed window, starting at Setup |
| `/vasagoio setup` | Check readiness; no settings change until Apply preset |
| `/vasagoio details` | Select Details for the current setup review |
| `/vasagoio report` | Select the Report tab |
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

Updating from an earlier alpha: with WoW closed, replace only the `vasagoio` folder and keep SavedVariables. Open `/vasagoio`. If Setup already reports Applied, alpha.11 does not require another preset application. If the previous attempt was blocked or settings are Ready to apply, select **Apply preset**, then **Reload UI**. Optional trinket integration accepts reviewed Forever Trinket Menu 1.8.19 and 1.8.20. FUF geometry is rejected at scales where native owner bounds would silently clamp it. The aura experiment remains optional and closed by default; RestedXP and native tracker presentation now require manual combat/restore checks. Long/permanent aura grouping remains unfinished.

## Maintenance and sharing

Only original vasagoio code, masks and documentation are packaged. No other addons, fonts, game art, account settings, chat data or paid guide content are redistributed. Share the release ZIP and installation guide; each person installs dependencies through their own sources.

Updates preserve local settings and do not automatically reapply the preset. Older snapshots without the preset-verification marker show Ready to apply until you explicitly apply this preset and reload once. Alpha.4 bar cleanup, idle-row and quest-panel corrections are included. No settings are reset automatically. Strictly reviewed owner adapters stop on unreviewed versions; other modules continue. After an owner update, inspect `/vasagoio` before applying a new profile. See [maintenance](docs/MAINTENANCE.md).

## Development

Requires Python 3.9+ and Lua 5.1. Run from the repository root:

```sh
python3 tools/check.py --lua lua5.1 --luac luac5.1
python3 tools/package.py
```

Checks cover syntax, profile review/rollback, combat deferral, restricted-value handling, geometry relationships, supported owner schemas, native layout preservation, package contents and reproducible archives. They cannot verify Blizzard taint behavior, protected combat actions, visuals, font availability or real gameplay. No game session is launched by these scripts.

Original code and generated masks: MIT. World of Warcraft and third-party addons remain their owners' property.
