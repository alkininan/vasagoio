# vasagoio

A personal World of Warcraft Forever UI built around the Bael design system: neutral black surfaces, restrained blue status colors, native typography, custom HUD geometry, and preserved native window layouts.

**0.2.0-alpha.1 — window interiors implemented and tested offline; not yet tested in WoW.** The design now extends through native and selected-addon controls, panes, labels and selection states. See [coverage and boundaries](docs/COVERAGE.md) for exact scope and the remaining native validation.

## Install

1. Download the **vasagoio-0.2.0-alpha.1.zip** asset from [Releases](https://github.com/alkininan/vasagoio/releases). GitHub's automatically generated source archive is for development.
2. With WoW closed, extract the `vasagoio` folder into `World of Warcraft/_forever_/Interface/AddOns/`. The result must be `AddOns/vasagoio/vasagoio.toc`.
3. Install the desired functional addons separately using CurseForge or their official distribution. The [dependency list](docs/dependencies.json) records the complete selected setup. They are not bundled.
4. Enable vasagoio and those addons in the game's AddOns menu. Log in yourself, let their profiles initialize, and reload once.
5. Type `/vasagoio setup`, review the changes and unavailable adapters, and select **Apply reviewed setup**. Then reload.
6. Follow the [first-run verification](docs/INSTALLATION.md). Keep your previous `WTF` backup until you have checked the setup yourself.

No prebuilt account-specific WTF folder is distributed. vasagoio creates its own `VasagoioDB` SavedVariables and proposes changes to initialized addon profiles in game. It never installs dependencies or edits their source files.

## What is included

- Reviewed profile adapters for Forever Unit Frames, Threat Plates, Bartender4, Prat, SexyMap, Details and Skinner.
- Large / Medium / Small / Extra small unit geometry, two-column raid groups, attached party pets where the owner supports them, exact health text and role-aware nameplate colors.
- A 16×3 action grid assembled from four native Bartender bars; the left-aligned pet row ends at the eighth main button. No action slots, bindings or paging are rewritten.
- Full-button cooldown wipes, centered numeric timers, hidden hotkeys during ordinary cooldowns, translucent range feedback and bottom aura signals where supported.
- Neutral translucent window and HUD surfaces, Friz text roles, Arial Narrow number/chat roles, and original rounded mask artwork.
- Native windows retain their layouts while receiving scoped interior controls, typography, neutral panes and rounded decoration. Selected tabs/rows and focused inputs keep near-black fills with small blue bottom markers.
- Baganator's 19 public skin-region types, Talents Forever internals, MRT tools, Auctionator panes and Gargul's audited window/widget registries use the same visual primitives while retaining their functionality.
- Setup review, persistent snapshots, conflict-aware restoration, module switches and addon-wide disable controls.

The [accepted design](docs/DESIGN.md) lists the full target. [Window coverage](docs/window-coverage.json) tracks all 172 cataloged surfaces without treating source availability as runtime proof. The catalog registers 132 native interior candidates across 115 primary hosts, with dedicated HUD owners and non-addon surfaces classified separately. [Window adapters](docs/WINDOW_COVERAGE.md) explain the native and addon integrations.

## Controls

| Command | Purpose |
| --- | --- |
| `/vasagoio` or `/vsg` | Status and setup window |
| `/vasagoio setup` | Prepare a fresh review; no changes until Apply |
| `/vasagoio off` | Disable styling; reload to remove hooks |
| `/vasagoio on` | Enable styling; reload for consistent owner state |
| `/vasagoio module <id> off` | Disable one module using its status ID |
| `/vasagoio refresh` | Reapply available cosmetic modules out of combat |
| `/vasagoio font <path>` | Use a locally supplied, licensed Arial Narrow Bold file |
| `/vasagoio font reset` | Return to shared-media/native font resolution |

You can also uncheck **vasagoio** in the WoW AddOns menu. Applied settings belong to their functional addons and remain after vasagoio is disabled. To undo those too, use **Restore profiles** before disabling, then reload immediately. Restoration stops if a saved field has changed since setup, preserving later edits. A full pre-install WTF backup remains the recovery option for conflicts.

## Maintenance and sharing

Only original vasagoio code, masks and documentation are packaged. No other addons, fonts, game art, account settings, chat data or paid guide content are redistributed. Share the release ZIP and installation guide; each person installs dependencies through their own sources.

Updates preserve local settings and do not automatically reapply the preset. Strictly reviewed owner adapters stop on unreviewed versions; other modules continue. After an owner update, inspect `/vasagoio` before applying a new profile. See [maintenance](docs/MAINTENANCE.md).

## Development

Requires Python 3.9+ and Lua 5.1. Run from the repository root:

```sh
python3 tools/check.py --lua lua5.1 --luac luac5.1
python3 tools/package.py
```

Checks cover syntax, profile review/rollback, combat deferral, restricted-value handling, geometry relationships, supported owner schemas, native layout preservation, package contents and reproducible archives. They cannot verify Blizzard taint behavior, protected combat actions, visuals, font availability or real gameplay. No game session is launched by these scripts.

Original code and generated masks: MIT. World of Warcraft and third-party addons remain their owners' property.
